#!/usr/bin/env bash
# Sets a new version everywhere it lives, commits it and tags it:
#   pubspec.yaml   version: X.Y.Z+<build>  (the build number goes up by one)
#   lib/app.dart   const appVersion = 'X.Y.Z';   (shown in the app)
#   git            commit "release: X.Y.Z" and annotated tag vX.Y.Z
#
#   bash scripts/bump_version.sh minor        # 0.4.0 → 0.5.0
#   bash scripts/bump_version.sh patch        # 0.5.0 → 0.5.1
#   bash scripts/bump_version.sh major|X.Y.Z
#
# Then push the commit and the tag together (printed at the end). On GitHub,
# .github/workflows/release.yml publishes a Release for X.Y.0 versions;
# patch versions (X.Y.Z, Z > 0) get the tag only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -ne 1 ]]; then
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 64
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo 'Commit or stash your changes first: the version commit holds only the version.' >&2
  exit 1
fi

current="$(sed -n 's/^version: *\([0-9][0-9.]*\)+\{0,1\}\([0-9]*\).*/\1 \2/p' pubspec.yaml)"
read -r old build <<<"$current"
[[ "$old" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "pubspec.yaml version '$old' is not X.Y.Z" >&2; exit 1; }
IFS=. read -r major minor patch <<<"$old"
case "$1" in
  major) new="$((major + 1)).0.0" ;;
  minor) new="$major.$((minor + 1)).0" ;;
  patch) new="$major.$minor.$((patch + 1))" ;;
  *)
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Not a version or major/minor/patch: $1" >&2; exit 64; }
    new="$1"
    ;;
esac
newer="$(printf '%s\n%s\n' "$old" "$new" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
if [[ "$new" == "$old" || "$newer" != "$new" ]]; then
  echo "$new is not newer than $old" >&2
  exit 1
fi
tag="v$new"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "Tag $tag already exists" >&2
  exit 1
fi
build="$(( ${build:-0} + 1 ))"

python3 - "$new" "$build" <<'PY'
import re, sys
new, build = sys.argv[1], sys.argv[2]
def edit(path, pattern, repl):
    text = open(path, encoding='utf-8').read()
    out, n = re.subn(pattern, repl, text, count=1, flags=re.M)
    if n != 1:
        sys.exit(f'{path}: version line not found')
    open(path, 'w', encoding='utf-8').write(out)
edit('pubspec.yaml', r'^version: .*$', f'version: {new}+{build}')
edit('lib/app.dart', r"^const appVersion = '[^']*';$", f"const appVersion = '{new}';")
PY

git add pubspec.yaml lib/app.dart
git commit -q -m "release: $new"
git tag -a "$tag" -m "Tinglang $new"
branch="$(git branch --show-current)"
echo "Version $old → $new (build $build), committed and tagged $tag on ${branch:-a detached HEAD}."
if [[ "$new" == *.0 ]]; then
  echo 'Pushing it publishes a GitHub Release (release.yml).'
else
  echo 'Patch version: pushing it adds the tag only, no GitHub Release.'
fi
echo "Push with:  git push --atomic origin ${branch:-main} $tag"
