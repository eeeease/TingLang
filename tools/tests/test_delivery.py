from pathlib import Path
import copy
import importlib.util
import json
import plistlib
import re
import shutil
import struct
import subprocess
import tempfile
import unittest
import wave

ROOT = Path(__file__).resolve().parents[2]

def module_at(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f'Cannot load module {name} from {path}')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

validator = module_at('validate_course', ROOT / 'tools/validate_course.py')
config = module_at('configure_macos', ROOT / 'scripts/configure_macos.py')

class CourseChecks(unittest.TestCase):
    def setUp(self):
        self.course = json.loads((ROOT / 'assets/demo/course.json').read_text())

    def test_original_demo_validates(self):
        self.assertEqual(validator.validate(self.course), [])

    def test_millisecond_timestamp(self):
        self.assertEqual(validator.timestamp('01:02:03.045'), 3723045)
        self.assertEqual(validator.timestamp('02:03,45'), 123450)
        self.assertEqual(validator.timestamp(1.125), 1125)

    def test_invalid_timestamp_rejected(self):
        for value in ('00:60:00', -1, 'abc', True, float('inf')):
            with self.assertRaises(ValueError): validator.timestamp(value)

    def test_duplicate_clip_rejected(self):
        self.course['clips'].append(copy.deepcopy(self.course['clips'][0]))
        self.assertTrue(validator.validate(self.course))

    def test_future_version_rejected(self):
        self.course['schema_version'] = 9
        self.assertTrue(validator.validate(self.course))

    def test_non_reversible_blind_rejected(self):
        self.course['clips'][0]['blind_listening']['blanks'][0]['answer'] = 'fabricated'
        self.assertTrue(validator.validate(self.course))

    def test_out_of_source_examples_rejected(self):
        self.course['clips'][0]['learning']['phrases'][0]['original_example'] = 'This is fabricated evidence.'
        self.assertTrue(validator.validate(self.course))

    def test_invalid_subtitle_bounds_rejected(self):
        self.course['clips'][0]['tinglang_cues'][0]['startTime'] = -1
        self.assertTrue(validator.validate(self.course))

    def test_audio_covers_all_clips_and_cues(self):
        with wave.open(str(ROOT / 'assets/demo/consistency.wav')) as audio:
            duration_ms = audio.getnframes() / audio.getframerate() * 1000
            self.assertEqual(audio.getnchannels(), 1)
            self.assertGreater(audio.getnframes(), 0)
        for clip in self.course['clips']:
            self.assertLessEqual(validator.timestamp(clip['end']), duration_ms + 1)
            for cue in clip['tinglang_cues']:
                self.assertIn(cue['text'], clip['transcript'])

class MacConfigurationChecks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        runner = self.root / 'macos/Runner'
        (runner / 'Configs').mkdir(parents=True)
        (self.root / 'macos/Runner.xcodeproj').mkdir()
        for name, value in [('Info.plist', {'CFBundleName': 'tinglang'}),
            ('DebugProfile.entitlements', {'com.apple.security.app-sandbox': True,
                'com.apple.security.cs.allow-jit': True,
                'com.apple.security.network.server': True}),
            ('Release.entitlements', {'com.apple.security.app-sandbox': True,
                'com.apple.security.files.user-selected.read-only': True})]:
            with (runner / name).open('wb') as f: plistlib.dump(value, f)
        # Unmodified project file from `flutter create` (Flutter 3.47.7).
        shutil.copyfile(ROOT / 'tools/tests/fixtures/flutter-3.47.7-macos-project.pbxproj',
            self.root / 'macos/Runner.xcodeproj/project.pbxproj')
        (self.root / 'macos/Podfile').write_text("platform :osx, '10.15'\n")
        (runner / 'Base.lproj').mkdir()
        shutil.copyfile(ROOT / 'tools/tests/fixtures/flutter-3.47.7-MainMenu.xib',
            runner / 'Base.lproj/MainMenu.xib')
        shutil.copytree(ROOT / 'assets/brand', self.root / 'assets/brand')
        shutil.copytree(ROOT / 'scripts/native', self.root / 'scripts/native')

    def tearDown(self): self.tmp.cleanup()

    def plist(self, name):
        with (self.root / 'macos/Runner' / name).open('rb') as f: return plistlib.load(f)

    def test_permissions_brand_and_native_target(self):
        config.configure(self.root)
        runner = self.root / 'macos/Runner'
        info = self.plist('Info.plist')
        self.assertEqual(info['CFBundleName'], 'TingLang')
        # Literal strings, not $(...) build-setting references.
        for key in ('NSMicrophoneUsageDescription', 'NSAudioCaptureUsageDescription'):
            self.assertIn('TingLang', info[key])
            self.assertNotIn('$(', info[key])
        self.assertEqual(info['CFBundleLocalizations'], ['en', 'zh-Hans'])
        for name in ['DebugProfile.entitlements', 'Release.entitlements']:
            ent = self.plist(name)
            self.assertFalse(ent['com.apple.security.app-sandbox'])
            self.assertTrue(ent['com.apple.security.device.audio-input'])
            self.assertTrue(ent['com.apple.security.network.client'])
            self.assertTrue(ent['com.apple.security.cs.disable-library-validation'])
            # file_picker refuses to open dialogs without it (ENTITLEMENT_NOT_FOUND).
            self.assertTrue(ent['com.apple.security.files.user-selected.read-write'])
            self.assertNotIn('com.apple.security.files.user-selected.read-only', ent)
        debug = self.plist('DebugProfile.entitlements')
        self.assertTrue(debug['com.apple.security.cs.allow-jit'])
        self.assertTrue(debug['com.apple.security.network.server'])
        self.assertIn("'14.2'", (self.root / 'macos/Podfile').read_text())
        self.assertIn('TingLang', (runner / 'MainFlutterWindow.swift').read_text())
        # The floating panel is the front door: no window at launch, and the app
        # keeps running when the main window closes.
        xib = (runner / 'Base.lproj/MainMenu.xib').read_text()
        self.assertEqual(xib.count('visibleAtLaunch="NO"'), 1)
        delegate = (runner / 'AppDelegate.swift').read_text()
        self.assertIn('applicationShouldHandleReopen', delegate)
        self.assertIn('return false', delegate)
        config.configure(self.root)  # idempotent
        self.assertEqual((runner / 'Base.lproj/MainMenu.xib').read_text().count('visibleAtLaunch'), 1)

    def test_tinglang_files_open_the_app(self):
        config.configure(self.root)
        config.configure(self.root)  # declared once, however often it runs
        info = self.plist('Info.plist')
        exported = [t for t in info['UTExportedTypeDeclarations']
                    if t['UTTypeIdentifier'] == 'dev.eeeease.tinglang.package']
        self.assertEqual(len(exported), 1)
        self.assertEqual(exported[0]['UTTypeConformsTo'], ['public.zip-archive', 'public.data'])
        self.assertEqual(exported[0]['UTTypeTagSpecification'],
            {'public.filename-extension': ['tinglang']})
        documents = [d for d in info['CFBundleDocumentTypes']
                     if 'dev.eeeease.tinglang.package' in d['LSItemContentTypes']]
        self.assertEqual(len(documents), 1)
        self.assertEqual(documents[0]['CFBundleTypeRole'], 'Viewer')
        self.assertEqual(documents[0]['LSHandlerRank'], 'Owner')
        self.assertEqual(documents[0]['CFBundleTypeIconSystemGenerated'], 1)
        zh = (self.root / 'macos/Runner/zh-Hans.lproj/InfoPlist.strings').read_text(encoding='utf-8')
        self.assertIn('"TingLang Package" = "听浪学习包";', zh)
        # Sync asks for the iCloud Drive folder with a reason, in both languages.
        self.assertIn('iCloud Drive', info['NSFileProviderDomainUsageDescription'])
        self.assertIn('"NSFileProviderDomainUsageDescription" = "', zh)

    def test_hardened_runtime_target_and_optional_local_signing(self):
        config.configure(self.root)
        app_info = (self.root / 'macos/Runner/Configs/AppInfo.xcconfig').read_text()
        self.assertIn('ENABLE_HARDENED_RUNTIME = YES', app_info)
        self.assertIn('MACOSX_DEPLOYMENT_TARGET = 14.2', app_info)
        self.assertIn('CODE_SIGN_IDENTITY = -', app_info)
        # Optional include: builds without Local.xcconfig; path resolves to the repo root.
        self.assertIn('#include? "../../../Local.xcconfig"', app_info)
        self.assertEqual((self.root / 'macos/Runner/Configs/../../../Local.xcconfig').resolve(),
            (self.root / 'Local.xcconfig').resolve())
        pbxproj = (self.root / 'macos/Runner.xcodeproj/project.pbxproj').read_text()
        targets = set(re.findall(r'MACOSX_DEPLOYMENT_TARGET = ([^;]+);', pbxproj))
        self.assertEqual(targets, {'14.2'})

    def test_localized_usage_strings_are_bundled(self):
        config.configure(self.root)
        runner = self.root / 'macos/Runner'
        for lang in ('en', 'zh-Hans'):
            text = (runner / f'{lang}.lproj/InfoPlist.strings').read_text(encoding='utf-8')
            self.assertIn('"NSAudioCaptureUsageDescription" = "', text)
            self.assertIn('"NSMicrophoneUsageDescription" = "', text)
        zh_strings = (runner / 'zh-Hans.lproj/InfoPlist.strings').read_text(encoding='utf-8')
        self.assertIn('Mac 上', zh_strings)
        # Chinese users see 听浪 in the Dock, Finder and permission prompts.
        self.assertIn('"CFBundleDisplayName" = "听浪";', zh_strings)
        self.assertIn('"CFBundleDisplayName" = "TingLang";',
            (runner / 'en.lproj/InfoPlist.strings').read_text(encoding='utf-8'))
        pbxproj = (self.root / 'macos/Runner.xcodeproj/project.pbxproj').read_text()
        self.assertIn('/* InfoPlist.strings in Resources */,', pbxproj)
        self.assertIn('path = zh-Hans.lproj/InfoPlist.strings;', pbxproj)
        self.assertIn('name = InfoPlist.strings;', pbxproj)
        self.assertIn('"zh-Hans",', pbxproj)
        # Every object id the script adds is defined exactly once.
        for oid in ('5A7100000000000000000001', '5A7100000000000000000002',
                    '5A7100000000000000000003', '5A7100000000000000000004'):
            self.assertEqual(len(re.findall(oid + r' /\* [^*]+ \*/ = \{', pbxproj)), 1, oid)
        if shutil.which('plutil'):
            subprocess.run(['plutil', '-lint', str(self.root / 'macos/Runner.xcodeproj/project.pbxproj')],
                check=True, capture_output=True)

    def test_unexpected_project_layout_fails_loudly(self):
        (self.root / 'macos/Runner.xcodeproj/project.pbxproj').write_text('MACOSX_DEPLOYMENT_TARGET = 10.15;')
        with self.assertRaises(SystemExit): config.configure(self.root)

    def test_configuration_is_idempotent(self):
        config.configure(self.root)
        before = {str(p.relative_to(self.root)): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        config.configure(self.root)
        after = {str(p.relative_to(self.root)): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        self.assertEqual(before, after)

    def test_local_signing_file_is_ignored_and_example_committed(self):
        self.assertIn('/Local.xcconfig', (ROOT / '.gitignore').read_text().splitlines())
        example = (ROOT / 'Local.xcconfig.example').read_text()
        self.assertIn('DEVELOPMENT_TEAM', example)

class MockCloudServerChecks(unittest.TestCase):
    """tools/mock_cloud_server.py answers with the contract fixtures."""

    def setUp(self):
        import threading
        from http.server import ThreadingHTTPServer
        mock = module_at('mock_cloud_server', ROOT / 'tools/mock_cloud_server.py')
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), mock.Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.origin = f'http://127.0.0.1:{self.server.server_address[1]}'

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()

    def request(self, path, method='GET', data=None, headers=None):
        import urllib.error, urllib.request
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, *args): return None
        opener = urllib.request.build_opener(NoRedirect)
        req = urllib.request.Request(self.origin + path, data=data, method=method, headers=headers or {})
        try:
            with opener.open(req) as r:
                return r.status, dict(r.headers), r.read()
        except urllib.error.HTTPError as e:
            return e.code, dict(e.headers), e.read()

    def test_sign_in_flow_and_account(self):
        status, _, body = self.request('/v1/meta')
        meta = json.loads(body)
        self.assertEqual(status, 200)
        self.assertEqual(meta['auth']['token_endpoint'], self.origin + '/oauth/token')
        status, headers, _ = self.request('/oauth/authorize?redirect_uri=tinglang://oauth/callback'
                                          '&code_challenge_method=S256&state=s1')
        self.assertEqual(status, 302)
        self.assertEqual(headers['Location'], 'tinglang://oauth/callback?code=mock-code&state=s1')
        self.assertEqual(self.request('/v1/account')[0], 401)
        _, _, body = self.request('/oauth/token', 'POST', b'grant_type=authorization_code&code=mock-code',
                                  {'Content-Type': 'application/x-www-form-urlencoded'})
        token = json.loads(body)
        status, _, body = self.request('/v1/account', headers={'Authorization': 'Bearer ' + token['access_token']})
        self.assertEqual((status, json.loads(body)['email']), (200, 'learner@example.com'))
        self.request('/v1/auth/revoke', 'POST', f"token={token['refresh_token']}".encode(),
                     {'Content-Type': 'application/x-www-form-urlencoded'})
        self.assertEqual(self.request('/v1/account', headers={'Authorization': 'Bearer ' + token['access_token']})[0], 401)

class SourceChecks(unittest.TestCase):
    def test_png_icon_sizes(self):
        for size in (16, 32, 64, 128, 256, 512, 1024):
            data = (ROOT / f'assets/brand/app_icon_{size}.png').read_bytes()
            self.assertEqual(data[:8], b'\x89PNG\r\n\x1a\n')
            self.assertEqual(struct.unpack('>II', data[16:24]), (size, size))

    def test_brand_sources_replace_the_interim_artwork(self):
        brand = ROOT / 'assets/brand'
        for name in ('tinglang-mark', 'tinglang-mark-dark', 'tinglang-mark-small',
                     'tinglang-mark-small-dark', 'tinglang-mark-ink', 'tinglang-mark-paper',
                     'mark-square', 'app-icon', 'app-icon-dark', 'app-icon-16', 'app-icon-32',
                     'app-icon-64'):
            self.assertTrue((brand / f'svg/{name}.svg').is_file(), name)
        # Layers for building the macOS 26 Liquid Glass icon in Icon Composer.
        for name in ('background-light', 'background-dark', 'mark-light', 'mark-dark'):
            self.assertTrue((brand / f'icon-composer/{name}.svg').is_file(), name)
        # The Tinglang ribbon, its wordmark and their generator are gone.
        for name in ('mark.svg', 'mark.png', 'wordmark.svg', 'wordmark.png', 'app-icon.svg',
                     'app-icon-1024.png'):
            self.assertFalse((brand / name).exists(), name)
        self.assertFalse((ROOT / 'tools/create_brand_assets.py').exists())
        # The app draws the mark as vectors; nothing loads the brand files at runtime.
        self.assertNotIn('assets/brand', (ROOT / 'pubspec.yaml').read_text())

    def test_brand_mark_code_matches_the_svgs(self):
        geometry = module_at('brand_mark_geometry', ROOT / 'tools/brand_mark_geometry.py')
        try:
            geometry.main(['--check'])
        except SystemExit as error:
            self.fail(str(error))
        # Arcs become cubics for SwiftUI; a quarter circle keeps its midpoint on the circle.
        (c1, c2, end), = geometry.arc_to_cubics(1, 0, 1, 1, 0, 0, 1, 0, 1)
        self.assertEqual(end, (0, 1))
        self.assertAlmostEqual(c1[0], 1)
        self.assertAlmostEqual(c1[1], 0.5523, places=4)
        self.assertEqual(len(geometry.arc_to_cubics(1, 0, 1, 1, 0, 1, 0, -1, 0)), 2)

    def test_earlier_name_only_in_migration_code(self):
        # The app's name before 0.4, spelled in two parts so this file does not
        # contain it. Only the code that moves earlier data may mention it.
        earlier = 'say' + 'loom'
        allowed = {'lib/core/legacy.dart', 'test/legacy_test.dart',
                   'packages/tinglang_native_macos/macos/tinglang_native_macos/Sources/'
                   'tinglang_native_macos/Keychain.swift'}
        files = subprocess.run(['git', 'ls-files', '--cached', '--others', '--exclude-standard'],
            cwd=ROOT, check=True, capture_output=True, text=True).stdout.splitlines()
        for name in files:
            path = ROOT / name
            if name in allowed or not path.is_file():
                continue
            self.assertNotIn(earlier, name.lower(), name)
            try:
                text = path.read_text(encoding='utf-8')
            except UnicodeDecodeError:
                continue
            self.assertNotIn(earlier, text.lower(), name)

    def test_no_fonts_or_private_records_bundled(self):
        generated = {'.git', '.dart_tool', '.fvm', '.pi', 'build'}
        for path in ROOT.rglob('*'):
            if generated & set(path.parts) or not path.is_file(): continue
            self.assertNotIn(path.suffix.lower(), {'.ttf', '.otf', '.woff', '.woff2'})
            self.assertNotIn('daily', path.relative_to(ROOT).parts)
            self.assertNotIn('weekly', path.relative_to(ROOT).parts)
        self.assertFalse((ROOT / '.env').exists())

    def test_app_has_no_upstream_backend_or_analytics_clients(self):
        pubspec = (ROOT / 'pubspec.yaml').read_text()
        for package in ['supabase_flutter:', 'firebase_analytics:', 'posthog_flutter:',
                        'purchases_flutter:', 'in_app_purchase:', 'umeng_common_sdk:']:
            self.assertNotIn(package, pubspec)
        # BYOK provider presets (M5) live in the bundled catalog asset, the
        # only place cloud LLM hosts appear; it carries no key and is used
        # only after the user adds a provider.
        presets = ROOT / 'lib/core/providers/provider_repository.dart'
        runtime = '\n'.join(path.read_text() for path in (ROOT / 'lib').rglob('*.dart') if path != presets)
        self.assertNotIn('https://api.echo', runtime)
        self.assertNotIn('api.openai.com', runtime)
        self.assertNotRegex(presets.read_text(), r'sk-[A-Za-z0-9]{8,}')
        catalog = (ROOT / 'assets/providers/catalog.v1.json').read_text()
        self.assertNotRegex(catalog, r'sk-[A-Za-z0-9-]{8,}|api_key|Bearer')

    def test_agpl_full_license_available_in_app(self):
        license = (ROOT / 'LICENSE').read_text()
        self.assertGreater(len(license), 30000)
        self.assertIn('13. Remote Network Interaction', license)
        self.assertIn('17. Interpretation of Sections 15 and 16.', license)
        self.assertEqual(license, (ROOT / 'assets/legal/AGPL-3.0.txt').read_text())

    def test_relative_dart_imports_resolve(self):
        for path in (ROOT / 'lib').rglob('*.dart'):
            # Directives only (doc comments in generated l10n code show example imports).
            for reference in re.findall(r"^(?:import|export|part)\s+'([^']+)'", path.read_text(), re.M):
                if reference.startswith(('dart:', 'package:')): continue
                self.assertTrue((path.parent / reference).is_file(), (path, reference))

    def test_shell_scripts_have_valid_syntax(self):
        for path in (ROOT/'scripts').glob('*.sh'):
            subprocess.run(['bash', '-n', str(path)], check=True)

if __name__ == '__main__': unittest.main()
