import 'dart:io';

import 'package:path/path.dart' as p;

/// The bundle identifier every TingLang build carries.
const tinglangBundleId = 'dev.eeeease.tinglang';

/// What went wrong while updating, in terms the UI can explain.
enum UpdateProblem {
  /// The connection failed, timed out or a download answered with an error.
  network,

  /// The archive did not match its `.sha256` file or its listed size; it has
  /// been deleted.
  checksum,

  /// The archive does not hold a TingLang app of the release's version.
  badPackage,

  /// Writing the download failed (for instance, the disk is full).
  disk,

  /// A recording is running or not saved yet; the app may not quit.
  busy,

  /// The app was asked to quit but stayed open (the exit guard refused).
  quitRefused,

  /// The new app could not be put next to the old one.
  install,

  /// The app does not run from an app bundle (for instance `flutter run`).
  notBundle,

  /// macOS runs the app from a randomised read-only copy (App
  /// Translocation), so the installed app cannot be found or replaced.
  translocated,

  /// The app's disk is read-only (a disk image, for instance).
  readOnly,

  /// The current user may not change the folder that holds the app.
  notWritable;

  /// Whether the user can only get the new version from the release page.
  bool get needsReleasePage => switch (this) {
    notBundle || translocated || readOnly || notWritable || badPackage || install => true,
    network || checksum || disk || busy || quitRefused => false,
  };
}

/// An update step failed; [detail] is safe to show (a folder, never a URL).
final class UpdateFailure implements Exception {
  const UpdateFailure(this.problem, [this.detail]);
  final UpdateProblem problem;
  final String? detail;

  @override
  String toString() => 'UpdateFailure: ${problem.name}${detail == null ? '' : ' ($detail)'}';
}

/// The installed app the updater replaces.
final class InstallLocation {
  const InstallLocation(this.bundle);

  /// For example `/Applications/Tinglang.app`.
  final String bundle;

  /// The folder that holds [bundle]; the new app is staged there so that the
  /// final swap is a rename on one volume.
  String get folder => p.dirname(bundle);
}

/// `…/Tinglang.app/Contents/MacOS/Tinglang` → `…/Tinglang.app`; null when
/// [executable] is not inside an app bundle.
String? bundleOfExecutable(String executable) {
  final macos = p.dirname(p.normalize(executable));
  final contents = p.dirname(macos);
  final bundle = p.dirname(contents);
  if (p.basename(macos) != 'MacOS' ||
      p.basename(contents) != 'Contents' ||
      p.extension(bundle) != '.app' ||
      !p.isAbsolute(bundle)) {
    return null;
  }
  return bundle;
}

/// Why writing a file next to the app failed: EROFS is a read-only disk,
/// anything else counts as a folder the user may not change.
UpdateProblem problemForWriteError(FileSystemException error) =>
    error.osError?.errorCode == 30 ? UpdateProblem.readOnly : UpdateProblem.notWritable;

/// Finds the running app's bundle from [executable] (normally
/// `Platform.resolvedExecutable`) and checks that it can be replaced in
/// place. Throws [UpdateFailure] with [UpdateProblem.notBundle],
/// [UpdateProblem.translocated], [UpdateProblem.readOnly] or
/// [UpdateProblem.notWritable].
Future<InstallLocation> locateInstall(String executable) async {
  final bundle = bundleOfExecutable(executable);
  if (bundle == null) throw const UpdateFailure(UpdateProblem.notBundle);
  // A quarantined app opened from Downloads runs from a read-only random
  // path; replacing that copy would change nothing the user can see.
  if (bundle.contains('/AppTranslocation/')) {
    throw const UpdateFailure(UpdateProblem.translocated);
  }
  if (!await Directory(bundle).exists()) throw const UpdateFailure(UpdateProblem.notBundle);
  final folder = p.dirname(bundle);
  // Moving the bundle needs a writable folder: try it with an empty file.
  final probe = File(p.join(folder, '.tinglang-update-probe-$pid'));
  try {
    await probe.writeAsString('', flush: true);
  } on FileSystemException catch (error) {
    throw UpdateFailure(problemForWriteError(error), folder);
  }
  try {
    await probe.delete();
  } on FileSystemException {
    // Created but not deletable: still a folder we cannot rely on.
    throw UpdateFailure(UpdateProblem.notWritable, folder);
  }
  // The old bundle is renamed and later deleted, so it must be ours too.
  for (final path in [bundle, p.join(bundle, 'Contents')]) {
    if (!await _writable(path)) throw UpdateFailure(UpdateProblem.notWritable, folder);
  }
  return InstallLocation(bundle);
}

/// access(2) with W_OK through `test -w`, which also says no on a read-only
/// volume.
Future<bool> _writable(String path) async =>
    (await Process.run('/bin/test', ['-w', path])).exitCode == 0;

/// One value of a property list (XML or binary) through `plutil`; null when
/// the key is missing or the file is not a property list.
Future<String?> plistValue(String plist, String key) async {
  final result = await Process.run('/usr/bin/plutil', ['-extract', key, 'raw', '-o', '-', plist]);
  if (result.exitCode != 0) return null;
  final value = '${result.stdout}'.trim();
  return value.isEmpty ? null : value;
}

/// Checks an unpacked app before it may replace the installed one: the
/// bundle identifier is TingLang's, the version is [version], and the
/// executable it names is there. Throws [UpdateFailure] with
/// [UpdateProblem.badPackage] otherwise.
Future<void> checkUpdateBundle(String bundle, {required String version}) async {
  const bad = UpdateFailure(UpdateProblem.badPackage);
  final plist = p.join(bundle, 'Contents', 'Info.plist');
  if (await FileSystemEntity.type(plist, followLinks: false) != FileSystemEntityType.file) {
    throw bad;
  }
  if (await plistValue(plist, 'CFBundleIdentifier') != tinglangBundleId) throw bad;
  if (await plistValue(plist, 'CFBundleShortVersionString') != version) throw bad;
  final executable = await plistValue(plist, 'CFBundleExecutable');
  if (executable == null || executable.contains('/') || executable.startsWith('.')) throw bad;
  final binary = await FileStat.stat(p.join(bundle, 'Contents', 'MacOS', executable));
  // Some execute bit must be set (0o111).
  if (binary.type != FileSystemEntityType.file || binary.mode & 0x49 == 0) throw bad;
}

/// The arguments [updateInstallScript] reads, in order.
List<String> updateScriptArguments({
  required int appPid,
  required String target,
  required String staged,
  required String backup,
  required String work,
  required Duration quitTimeout,
  required String opener,
  required String log,
}) => [
  '$appPid',
  target,
  staged,
  backup,
  work,
  '${quitTimeout.inSeconds < 1 ? 1 : quitTimeout.inSeconds}',
  opener,
  log,
];

/// The shell script that swaps the app once it has quit. It is run as
/// `/bin/sh -c <script> tinglang-update <arguments>`; every path comes in as
/// a positional parameter ([updateScriptArguments]), never inside the text.
///
/// 1. Waits for the app's process to exit (at most `$6` seconds; then it
///    deletes the staged copy and changes nothing).
/// 2. Moves the installed app aside (`$2` → `$4`, same folder).
/// 3. Moves the verified new app into place (`$3` → `$2`); if that fails it
///    moves the old one back.
/// 4. Removes `com.apple.quarantine` from the new app and opens it with
///    `$7` (`/usr/bin/open`); if it does not open, the old one comes back.
/// 5. Only then deletes the old app and the download folder (`$5`).
///
/// Everything it does is appended to the log file `$8`.
String updateInstallScript() => r'''
pid="$1"; target="$2"; staged="$3"; backup="$4"; work="$5"; wait_s="$6"; opener="$7"; log="$8"
touch "$log" 2>/dev/null || log=/dev/null
exec >>"$log" 2>&1
say() { printf '%s tinglang-update: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
discard() { rm -rf "$staged" "$work"; }
say "waiting for TingLang (process $pid) to quit"
tries=0
while kill -0 "$pid" 2>/dev/null; do
  tries=$((tries + 1))
  if [ "$tries" -gt $((wait_s * 10)) ]; then
    say "TingLang did not quit; nothing was changed"
    discard
    exit 1
  fi
  sleep 0.1
done
if [ ! -d "$staged" ] || [ ! -d "$target" ] || [ -e "$backup" ]; then
  say "the new or the installed app is missing; nothing was changed"
  discard
  [ -d "$target" ] && "$opener" "$target"
  exit 1
fi
if ! mv "$target" "$backup"; then
  say "could not move the installed app aside; nothing was changed"
  discard
  "$opener" "$target"
  exit 1
fi
if [ -e "$target" ] || ! mv "$staged" "$target"; then
  say "could not move the new app into place; putting the old one back"
  if [ ! -e "$target" ] && mv "$backup" "$target"; then
    discard
    "$opener" "$target"
  else
    say "could not put the old app back; it is at $backup"
  fi
  exit 1
fi
xattr -dr com.apple.quarantine "$target" 2>/dev/null || true
if ! "$opener" "$target"; then
  say "the new app did not open; putting the old one back"
  if mv "$target" "$staged" && mv "$backup" "$target"; then
    discard
    "$opener" "$target"
  else
    say "could not put the old app back; it is at $backup"
  fi
  exit 1
fi
rm -rf "$backup" "$work"
say "updated"
''';
