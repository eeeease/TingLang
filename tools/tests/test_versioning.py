from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/bump_version.sh'


class BumpVersion(unittest.TestCase):
    """scripts/bump_version.sh in a throwaway repository holding copies of
    the two files that carry the version."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        (self.dir / 'scripts').mkdir()
        (self.dir / 'lib').mkdir()
        shutil.copy(SCRIPT, self.dir / 'scripts/bump_version.sh')
        (self.dir / 'pubspec.yaml').write_text('name: tinglang\nversion: 0.4.0+4\nenvironment:\n')
        (self.dir / 'lib/app.dart').write_text("library;\n\nconst appVersion = '0.4.0';\n")
        self.git('init', '-q', '-b', 'main')
        self.git('config', 'user.name', 'test')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('add', '.')
        self.git('commit', '-q', '-m', 'start')

    def tearDown(self):
        shutil.rmtree(self.dir)

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.dir, check=True,
                              capture_output=True, text=True).stdout

    def bump(self, arg):
        return subprocess.run(['bash', 'scripts/bump_version.sh', arg], cwd=self.dir,
                              capture_output=True, text=True)

    def versions(self):
        pubspec = re.search(r'^version: (.*)$', (self.dir / 'pubspec.yaml').read_text(), re.M)[1]
        app = re.search(r"appVersion = '(.*)'", (self.dir / 'lib/app.dart').read_text())[1]
        return pubspec, app

    def test_minor_sets_both_files_commits_and_tags(self):
        result = self.bump('minor')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.versions(), ('0.5.0+5', '0.5.0'))
        self.assertEqual(self.git('log', '-1', '--format=%s').strip(), 'release: 0.5.0')
        self.assertEqual(self.git('tag', '--points-at', 'HEAD').strip(), 'v0.5.0')
        self.assertEqual(self.git('cat-file', '-t', 'v0.5.0').strip(), 'tag')  # annotated
        self.assertIn('publishes a GitHub Release', result.stdout)
        self.assertIn('git push --atomic origin main v0.5.0', result.stdout)

    def test_patch_is_tag_only(self):
        result = self.bump('patch')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.versions(), ('0.4.1+5', '0.4.1'))
        self.assertIn('tag only', result.stdout)

    def test_major_and_explicit(self):
        self.assertEqual(self.bump('major').returncode, 0)
        self.assertEqual(self.versions(), ('1.0.0+5', '1.0.0'))
        self.assertEqual(self.bump('1.2.10').returncode, 0)
        self.assertEqual(self.versions(), ('1.2.10+6', '1.2.10'))

    def test_refuses_older_same_or_malformed(self):
        for arg in ('0.4.0', '0.3.9', '0.10', 'next'):
            result = self.bump(arg)
            self.assertNotEqual(result.returncode, 0, arg)
        self.assertEqual(self.versions(), ('0.4.0+4', '0.4.0'))
        self.assertEqual(self.git('tag').strip(), '')

    def test_numeric_not_text_order(self):
        (self.dir / 'pubspec.yaml').write_text('version: 0.9.0+9\n')
        (self.dir / 'lib/app.dart').write_text("const appVersion = '0.9.0';\n")
        self.git('commit', '-qam', 'nine')
        result = self.bump('minor')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.versions(), ('0.10.0+10', '0.10.0'))

    def test_refuses_a_dirty_tree_or_an_existing_tag(self):
        (self.dir / 'notes.txt').write_text('x')
        self.git('add', 'notes.txt')
        self.assertNotEqual(self.bump('minor').returncode, 0)
        self.git('commit', '-qm', 'notes')
        self.git('tag', 'v0.5.0')
        self.assertNotEqual(self.bump('minor').returncode, 0)
        self.assertEqual(self.versions(), ('0.4.0+4', '0.4.0'))


class ReleaseWorkflow(unittest.TestCase):
    def test_release_rules_match_the_script(self):
        text = (ROOT / '.github/workflows/release.yml').read_text()
        # Triggered by version changes on main, not by tag pushes.
        self.assertIn('branches: [main]', text)
        self.assertIn('paths: [pubspec.yaml]', text)
        self.assertNotIn('tags:', text)
        # Patch versions are tagged but not released.
        self.assertIn('"$version" != *.0', text)
        self.assertIn('git/refs', text)


if __name__ == '__main__':
    unittest.main()
