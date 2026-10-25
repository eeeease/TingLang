import 'dart:typed_data';

import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';
import 'package:tinglang_platform_interface/testing.dart';
import 'package:test/test.dart';

const sonoma142 = OsVersion(14, 2);
const tahoe26 = OsVersion(26);
const xasr = 'xasr-zh-en-480ms-int8';
const vad = 'silero-vad';

void main() {
  group('OsVersion', () {
    test('parses macOS and Windows strings', () {
      expect(OsVersion.parse('14.2'), const OsVersion(14, 2));
      expect(OsVersion.parse('Version 26.0.1 (Build 25A354)'), const OsVersion(26, 0, 1));
      expect(OsVersion.parse('10.0.26100'), const OsVersion(10, 0, 26100));
      expect(() => OsVersion.parse('unknown'), throwsFormatException);
    });
    test('compares every component', () {
      expect(const OsVersion(14, 1, 9) < sonoma142, isTrue);
      expect(const OsVersion(14, 2, 1) >= sonoma142, isTrue);
      expect(const OsVersion(10, 0, 19041) < const OsVersion(10, 0, 20348), isTrue);
    });
  });

  group('macOS 14.2 vs 26', () {
    test('system audio prefers the Core Audio tap on 14.2 and 26', () {
      for (final version in [sonoma142, tahoe26]) {
        final probe = FakeProbes.macos(version, permissions: FakeProbes.allGranted);
        expect(
          fakeTinglangPlatform(probe).systemAudio.pick(probe).id,
          'coreaudio_tap',
          reason: '$version',
        );
      }
    });
    test('before 14.2 the tap is unsupported and ScreenCaptureKit is used', () {
      final probe = FakeProbes.macos(const OsVersion(14, 1), permissions: FakeProbes.allGranted);
      final choice = fakeTinglangPlatform(probe).systemAudio.pick(probe);
      expect(choice.id, 'screencapturekit');
      expect(choice.candidates.first.availability, isA<Unsupported>());
    });
    test('SpeechTranscriber is only offered on 26+', () {
      final old = FakeProbes.macos(sonoma142);
      final oldChoice = fakeTinglangPlatform(old).liveAsr.pick(old);
      expect(
        oldChoice.hasSelection,
        isFalse,
        reason: 'no model downloaded and no SpeechTranscriber',
      );
      expect(oldChoice.blocker, isA<NeedsDownload>());

      final current = FakeProbes.macos(tahoe26);
      expect(fakeTinglangPlatform(current).liveAsr.pick(current).id, 'speech_transcriber');
    });
    test('SpeechTranscriber outranks a downloaded sherpa model on 26 (M0 benchmark)', () {
      final probe = FakeProbes.macos(tahoe26, installedAssets: {xasr, vad});
      expect(fakeTinglangPlatform(probe).liveAsr.pick(probe).id, 'speech_transcriber');
      final old = FakeProbes.macos(sonoma142, installedAssets: {xasr, vad});
      expect(fakeTinglangPlatform(old).liveAsr.pick(old).id, 'sherpa.xasr_zh_en_480');
    });
    test('native pipeline is the default on 26; portable below', () {
      final old = FakeProbes.macos(sonoma142);
      final registry = fakeTinglangPlatform(old).pipelines;
      expect(registry.pick(old).id, 'pipeline.portable');
      final native = registry.pick(old, 'pipeline.native_macos');
      expect(native.id, 'pipeline.portable');
      expect(native.preferredAvailability, isA<Unsupported>());

      final current = FakeProbes.macos(tahoe26);
      expect(fakeTinglangPlatform(current).pipelines.pick(current).id, 'pipeline.native_macos');
    });
    test('Apple Translation needs macOS 15 and falls through on 14.2', () {
      final old = FakeProbes.macos(sonoma142);
      final choice = fakeTinglangPlatform(old).translators.pick(old);
      expect(choice.hasSelection, isFalse, reason: 'BYOK LLM is cloud and never auto-selected');
      expect(choice.blocker, isA<NeedsOptIn>());
      final current = FakeProbes.macos(tahoe26);
      expect(fakeTinglangPlatform(current).translators.pick(current).id, 'apple_translation');
    });
  });

  group('Windows 19041 vs 26100', () {
    test('19041 lacks process loopback and uses endpoint loopback', () {
      final probe = FakeProbes.windows(19041);
      final choice = fakeTinglangPlatform(probe).systemAudio.pick(probe);
      expect(choice.id, 'endpoint_loopback');
      expect(choice.candidates.first.factory.id, 'process_loopback');
      expect(choice.candidates.first.availability, isA<Unsupported>());
    });
    test('26100 uses per-process loopback', () {
      final probe = FakeProbes.windows(26100);
      expect(fakeTinglangPlatform(probe).systemAudio.pick(probe).id, 'process_loopback');
    });
    test('macOS-only backends are never candidates on Windows', () {
      final probe = FakeProbes.windows(26100);
      final platform = fakeTinglangPlatform(probe);
      final ids = platform.liveAsr.pick(probe).candidates.map((c) => c.factory.id);
      expect(ids, isNot(contains('speech_transcriber')));
      expect(platform.overlays.pick(probe).id, 'layered_dwrite');
      expect(platform.translators.pick(probe).id, 'bergamot');
      expect(platform.shells.pick(probe).id, 'win32_shell');
    });
    test('Voice Memos are read on every supported macOS and nowhere else', () {
      for (final version in [sonoma142, tahoe26]) {
        final probe = FakeProbes.macos(version);
        expect(fakeTinglangPlatform(probe).voiceMemos.pick(probe).id, 'apple_voice_memos');
      }
      final windows = FakeProbes.windows(26100);
      final choice = fakeTinglangPlatform(windows).voiceMemos.pick(windows);
      expect(choice.hasSelection, isFalse);
      expect(choice.blocker, isA<Unsupported>());
    });
    test('iCloud Drive support exists on every supported macOS and nowhere else', () {
      for (final version in [sonoma142, tahoe26]) {
        final probe = FakeProbes.macos(version);
        final choice = fakeTinglangPlatform(probe).cloudDrive.pick(probe);
        expect(choice.id, 'icloud_drive');
        // macOS syncs the folder; the app itself sends nothing anywhere.
        expect(choice.selected!.spec.cloud, isFalse);
      }
      final windows = FakeProbes.windows(26100);
      final choice = fakeTinglangPlatform(windows).cloudDrive.pick(windows);
      expect(choice.hasSelection, isFalse);
      expect(choice.blocker, isA<Unsupported>());
    });
    test('cloud sign-in uses the system browser session on macOS and nothing on Windows yet', () {
      for (final version in [sonoma142, tahoe26]) {
        final probe = FakeProbes.macos(version);
        final choice = fakeTinglangPlatform(probe).webAuth.pick(probe);
        expect(choice.id, 'web_authentication_session');
        // A sign-in mechanism, not a cloud backend: the account feature that
        // uses it is what the user turns on.
        expect(choice.selected!.spec.cloud, isFalse);
      }
      final windows = FakeProbes.windows(26100);
      expect(fakeTinglangPlatform(windows).webAuth.pick(windows).hasSelection, isFalse);
    });
    test('the AppKit shell drives the main window on every supported macOS', () {
      for (final version in [sonoma142, tahoe26]) {
        final probe = FakeProbes.macos(version);
        expect(fakeTinglangPlatform(probe).shells.pick(probe).id, 'appkit_shell');
      }
    });
  });

  group('permission and download states', () {
    test('undetermined permission asks; denied permission links to Settings', () {
      final asked = FakeProbes.macos(sonoma142);
      final platform = fakeTinglangPlatform(asked);
      final pending = platform.systemAudio.pick(asked);
      expect(pending.hasSelection, isFalse);
      expect(
        pending.blocker,
        isA<NeedsPermission>()
            .having((b) => b.permission, 'permission', PermissionKind.systemAudio)
            .having((b) => b.denied, 'denied', isFalse),
      );

      final denied = FakeProbes.macos(
        sonoma142,
        permissions: {
          PermissionKind.systemAudio: PermissionState.denied,
          PermissionKind.screenCapture: PermissionState.denied,
        },
      );
      expect(
        platform.systemAudio.pick(denied).blocker,
        isA<NeedsPermission>().having((b) => b.denied, 'denied', isTrue),
      );
    });
    test('a denied tap falls back to a granted ScreenCaptureKit', () {
      final probe = FakeProbes.macos(
        tahoe26,
        permissions: {
          PermissionKind.systemAudio: PermissionState.denied,
          PermissionKind.screenCapture: PermissionState.granted,
        },
      );
      expect(fakeTinglangPlatform(probe).systemAudio.pick(probe).id, 'screencapturekit');
    });
    test('restricted microphone is treated as denied', () {
      final probe = FakeProbes.windows(
        26100,
        permissions: {PermissionKind.microphone: PermissionState.restricted},
      );
      expect(
        fakeTinglangPlatform(probe).microphone.pick(probe).blocker,
        isA<NeedsPermission>().having((b) => b.denied, 'denied', isTrue),
      );
    });
    test('missing model pack reports the asset to download', () {
      final probe = FakeProbes.windows(26100);
      final choice = fakeTinglangPlatform(probe).fileAsr.pick(probe);
      expect(
        choice.blocker,
        isA<NeedsDownload>().having((b) => b.assetId, 'asset', 'xasr-zh-en-offline-punct-int8'),
      );
      final installed = probe.copyWith(installedAssets: {'parakeet-tdt-0.6b-v2-int8', vad});
      expect(fakeTinglangPlatform(installed).fileAsr.pick(installed).id, 'sherpa.parakeet_tdt_v2');
    });
    test('re-probing after a grant changes the choice', () {
      final before = FakeProbes.macos(sonoma142);
      final platform = fakeTinglangPlatform(before);
      expect(platform.microphone.pick(before).hasSelection, isFalse);
      final after = before.copyWith(
        permissions: {PermissionKind.microphone: PermissionState.granted},
      );
      expect(platform.microphone.pick(after).id, 'avaudioengine_mic');
    });
  });

  group('user preference and cloud opt-in', () {
    test('an available preferred backend wins over platform order', () {
      final probe = FakeProbes.macos(tahoe26, permissions: FakeProbes.allGranted);
      final choice = fakeTinglangPlatform(probe).systemAudio.pick(probe, 'screencapturekit');
      expect(choice.id, 'screencapturekit');
      expect(choice.usedPreference, isTrue);
      expect(choice.preferredAvailability, isNull);
    });
    test('an unavailable preference falls back and says why', () {
      final probe = FakeProbes.macos(tahoe26);
      final choice = fakeTinglangPlatform(probe).liveAsr.pick(probe, 'sherpa.xasr_zh_en_480');
      expect(choice.id, 'speech_transcriber');
      expect(choice.usedPreference, isFalse);
      expect(choice.preferredAvailability, isA<NeedsDownload>());
    });
    test('unknown preferred id is reported, not thrown', () {
      final probe = FakeProbes.windows(26100);
      final choice = fakeTinglangPlatform(probe).systemAudio.pick(probe, 'removed_backend');
      expect(choice.id, 'process_loopback');
      expect(choice.preferredAvailability, isA<Unsupported>());
    });
    test('cloud is never auto-selected, even when enabled', () {
      final probe = FakeProbes.macos(sonoma142, enabledCloudBackends: {'cloud.soniox'});
      final choice = fakeTinglangPlatform(probe).liveAsr.pick(probe);
      expect(choice.hasSelection, isFalse);
      expect(
        choice.candidates.map((c) => c.factory.id),
        containsAll(['cloud.soniox', 'cloud.dashscope']),
      );
    });
    test('cloud needs both opt-in and preference', () {
      final notEnabled = FakeProbes.macos(sonoma142);
      final platform = fakeTinglangPlatform(notEnabled);
      final refused = platform.liveAsr.pick(notEnabled, 'cloud.soniox');
      expect(refused.hasSelection, isFalse);
      expect(refused.preferredAvailability, isA<NeedsOptIn>());

      final enabled = notEnabled.copyWith(enabledCloudBackends: {'cloud.soniox'});
      expect(platform.liveAsr.pick(enabled, 'cloud.soniox').id, 'cloud.soniox');
    });
    test('every cloud speech service is a live and a file backend', () {
      final ids = [for (final s in BackendCatalog.cloudAsr) s.id];
      expect(ids, [
        'cloud.tencent',
        'cloud.dashscope',
        'cloud.xfyun',
        'cloud.soniox',
        'cloud.assemblyai',
        'cloud.azure',
      ]);
      for (final capability in ['liveAsr', 'fileAsr']) {
        final specs = BackendCatalog.byCapability[capability]!;
        for (final spec in BackendCatalog.cloudAsr) {
          expect(specs, contains(spec), reason: '$capability ${spec.id}');
          expect(spec.cloud, isTrue);
        }
      }
    });
    test('a file backend in the cloud needs opt-in and preference too', () {
      final probe = FakeProbes.macos(sonoma142);
      final platform = fakeTinglangPlatform(probe);
      expect(platform.fileAsr.pick(probe, 'cloud.azure').preferredAvailability, isA<NeedsOptIn>());
      final enabled = probe.copyWith(enabledCloudBackends: {'cloud.azure'});
      expect(platform.fileAsr.pick(enabled).id, isNot('cloud.azure'));
      expect(platform.fileAsr.pick(enabled, 'cloud.azure').id, 'cloud.azure');
    });
    test('the platform adds the cloud backends the app enabled', () async {
      final platform = fakeTinglangPlatform(FakeProbes.macos(sonoma142));
      expect((await platform.probe()).enabledCloudBackends, isEmpty);
      platform.enabledCloudBackends = {'cloud.tencent'};
      expect((await platform.probe()).enabledCloudBackends, {'cloud.tencent'});
    });
  });

  group('registry mechanics', () {
    BackendFactory<String> factory(String id, {bool cloud = false}) =>
        BackendFactory(BackendSpec(id: id, platforms: {HostOs.macos}, cloud: cloud), () => id);

    test('wildcards keep registration order; unlisted backends come last', () {
      final registry =
          BackendRegistry<String>(
              'demo',
              preferences: {
                HostOs.macos: ['b', 'sherpa.*'],
              },
            )
            ..register(factory('z'))
            ..register(factory('sherpa.two'))
            ..register(factory('b'))
            ..register(factory('sherpa.one'));
      expect(registry.ordered(HostOs.macos).map((f) => f.id), [
        'b',
        'sherpa.two',
        'sherpa.one',
        'z',
      ]);
      expect(registry.ordered(HostOs.windows), isEmpty);
    });
    test('re-registering an id replaces the factory in place', () {
      final registry = BackendRegistry<String>('demo')
        ..register(factory('a'))
        ..register(factory('b'))
        ..register(
          BackendFactory(const BackendSpec(id: 'a', platforms: {HostOs.macos}), () => 'native a'),
        );
      expect(registry.all.map((f) => f.id), ['a', 'b']);
      expect(registry.pick(FakeProbes.macos(tahoe26)).create(), 'native a');
    });
    test('extra runtime checks run after static gates', () {
      final registry = BackendRegistry<String>('demo')
        ..register(
          BackendFactory(
            const BackendSpec(id: 'gated', platforms: {HostOs.macos}),
            () => 'gated',
            check: (_) => const Unsupported('locale missing'),
          ),
        )
        ..register(factory('plain'));
      final choice = registry.pick(FakeProbes.macos(tahoe26));
      expect(choice.id, 'plain');
      expect(choice.candidates.first.availability, isA<Unsupported>());
    });
    test('nothing selectable: create throws with the blocker', () {
      final registry = BackendRegistry<String>('demo');
      final choice = registry.pick(FakeProbes.macos(tahoe26));
      expect(choice.blocker, isA<Unsupported>());
      expect(choice.create, throwsStateError);
    });
    test('every catalog spec is registered exactly once by the fake platform', () {
      final platform = fakeTinglangPlatform(FakeProbes.macos(tahoe26));
      for (final entry in BackendCatalog.byCapability.entries) {
        expect(
          platform.registries[entry.key]!.all.map((f) => f.id),
          entry.value.map((s) => s.id),
          reason: entry.key,
        );
      }
    });
  });

  group('TinglangPlatform and fakes', () {
    test('instance must be installed before use', () {
      if (!TinglangPlatform.isInstalled) {
        expect(() => TinglangPlatform.instance, throwsStateError);
      }
      final platform = fakeTinglangPlatform(FakeProbes.macos(tahoe26));
      TinglangPlatform.instance = platform;
      expect(TinglangPlatform.instance, same(platform));
    });
    test('probe comes from the probe source', () async {
      final probe = FakeProbes.windows(26100);
      expect(await fakeTinglangPlatform(probe).probe(), same(probe));
    });
    test('fake capture → fake ASR produces partial then final', () async {
      final probe = FakeProbes.macos(
        tahoe26,
        permissions: FakeProbes.allGranted,
        installedAssets: {xasr, vad},
      );
      final platform = fakeTinglangPlatform(probe);
      final capture = platform.systemAudio.pick(probe).create();
      final source = await capture.open(const AudioCaptureRequest()) as FakeNativeAudioSource;
      final session = await platform.liveAsr
          .pick(probe)
          .create()
          .start(AsrSessionConfig(language: 'en', source: source));
      final events = <AsrEvent>[];
      final done = session.events.listen(events.add).asFuture<void>();
      source.debugBlocks.listen((b) => session.acceptWaveform(b, 16000));
      await source.start();
      source.emit(Float32List(source.format.samplesPerBlock));
      await Future<void>.delayed(Duration.zero);
      await session.stop();
      await done;
      expect(events.first, isA<AsrPartial>());
      expect(events.last, isA<AsrFinal>().having((e) => e.endMs, 'end', 100));
    });
    test('caption styles compare by value, so unchanged pushes can be skipped', () {
      const style = CaptionStyle();
      expect(style.copyWith(), style);
      expect(style.copyWith(mode: CaptionMode.text), isNot(style));
      expect(
        const OverlayState(phase: OverlayPhase.idle, dueCount: 2),
        const OverlayState(phase: OverlayPhase.idle, dueCount: 2),
      );
    });
    test('fake overlay enforces the 30-line tail limit', () async {
      final overlay = FakeCaptionOverlay();
      final lines = [for (var i = 0; i < 31; i++) CaptionLine(segmentId: '$i', text: 'line $i')];
      await expectLater(overlay.pushTail(lines), throwsArgumentError);
      await overlay.pushTail(lines.take(30).toList());
      expect(overlay.pushes.single, hasLength(30));
    });
  });

  group('pickCapture', () {
    BackendRegistry<Object> registry() =>
        BackendRegistry<Object>('microphone')
          ..register(BackendFactory<Object>(BackendCatalog.avAudioEngineMic, Object.new));
    PlatformProbe probe(PermissionState? microphone) => FakeProbes.macos(
      const OsVersion(15),
      permissions: {PermissionKind.microphone: ?microphone},
    );

    test('allowed, or never asked (macOS asks when capture opens)', () {
      expect(pickCapture(registry(), probe(PermissionState.granted)).id, 'avaudioengine_mic');
      expect(pickCapture(registry(), probe(PermissionState.notDetermined)).id, 'avaudioengine_mic');
      expect(pickCapture(registry(), probe(null)).id, 'avaudioengine_mic');
    });

    test('a refusal is its own error; nothing that can run is a state error', () {
      expect(
        () => pickCapture(registry(), probe(PermissionState.denied)),
        throwsA(isA<CapturePermissionDenied>()),
      );
      expect(
        () => pickCapture(registry(), probe(PermissionState.restricted)),
        throwsA(isA<CapturePermissionDenied>()),
      );
      expect(
        () => pickCapture(BackendRegistry<Object>('microphone'), probe(PermissionState.granted)),
        throwsStateError,
      );
    });
  });
}
