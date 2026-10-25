import 'package:test/test.dart';
import 'package:tinglang_platform_interface/testing.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

const sonoma142 = OsVersion(14, 2);
const tahoe26 = OsVersion(26);

final class _Inventory implements ModelInventory {
  _Inventory(this.installed);
  @override
  final Set<String> installed;
  @override
  String directoryOf(String packId) => '/models/$packId';
}

void main() {
  group('catalog', () {
    test('ids are unique and every model has a backend spec', () {
      final ids = SpeechModels.all.map((m) => m.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      final live = BackendCatalog.byCapability['liveAsr']!.map((s) => s.id).toSet();
      final file = BackendCatalog.byCapability['fileAsr']!.map((s) => s.id).toSet();
      for (final model in SpeechModels.all) {
        if (model.uses.contains(SpeechUse.live)) expect(live, contains(model.id));
        if (model.uses.contains(SpeechUse.file)) {
          expect(file, contains(model.backendId(SpeechUse.file)));
        }
      }
    });

    test('sherpa backends need their pack and the VAD; Apple ones need nothing', () {
      final specs = {
        for (final spec in BackendCatalog.byCapability.values.expand((s) => s)) spec.id: spec,
      };
      for (final model in SpeechModels.all) {
        for (final use in model.uses) {
          final spec = specs[model.backendId(use)]!;
          expect(spec.assets, model.requiredAssets, reason: model.id);
        }
        expect(model.isApple, model.pack == null, reason: model.id);
        expect(model.isSherpa, model.sherpaFiles != null, reason: model.id);
      }
    });

    test('every download is pinned: https, size and SHA-256', () {
      final hex = RegExp(r'^[0-9a-f]{64}$');
      for (final pack in SpeechModels.packs) {
        expect(pack.files, isNotEmpty, reason: pack.id);
        final archive = pack.archive;
        if (archive != null) {
          expect(archive.url, startsWith('https://github.com/k2-fsa/'));
          expect(archive.sha256, matches(hex));
          expect(archive.bytes, greaterThan(0));
        }
        for (final file in pack.files) {
          expect(file.sha256, matches(hex), reason: '${pack.id}/${file.name}');
          expect(file.bytes, greaterThan(0));
          expect(file.name, isNot(contains('/')));
          if (archive == null) {
            expect(
              file.url,
              anyOf(
                startsWith('https://github.com/k2-fsa/'),
                startsWith('https://huggingface.co/csukuangfj/'),
              ),
            );
            // Hugging Face files are pinned to a commit, never `main`.
            if (file.url.contains('huggingface.co')) {
              expect(file.url, matches(RegExp(r'/resolve/[0-9a-f]{40}/')));
            }
          } else {
            expect(file.url, isEmpty);
          }
        }
        expect(pack.license.url, startsWith('https://'));
      }
    });

    test('sizes shown in Settings match the benchmark notes', () {
      expect(SpeechModels.xasrStreaming.pack!.bytes, 169227953);
      expect(SpeechModels.xasrOffline.pack!.bytes, 174965025);
      expect(SpeechModels.parakeet.pack!.bytes, 661190513);
      expect(
        SpeechModels.xasrStreaming.downloadBytes,
        133895136 + SpeechModels.vad.bytes,
        reason: 'the archive is downloaded, not the extracted files',
      );
      expect(SpeechModels.appleSpeech.downloadBytes, 0);
    });

    test('Parakeet is credited (CC-BY-4.0)', () {
      expect(SpeechModels.parakeet.license!.name, 'CC-BY-4.0');
      expect(SpeechModels.parakeet.license!.attribution, contains('NVIDIA'));
    });
  });

  group('latency tiers', () {
    test('Apple: fastResults and lingering models only where promised', () {
      final saver = LatencyTiers.apple(LatencyTier.powerSaver);
      final balanced = LatencyTiers.apple(LatencyTier.balanced);
      final fastest = LatencyTiers.apple(LatencyTier.fastest);
      expect([saver.fastResults, balanced.fastResults, fastest.fastResults], [false, false, true]);
      expect(
        [saver.priority, balanced.priority, fastest.priority],
        ['utility', 'userInitiated', 'high'],
      );
      expect(
        [saver.modelRetention, balanced.modelRetention, fastest.modelRetention],
        ['whileInUse', 'lingering', 'processLifetime'],
      );
      expect(fastest.ignoresResourceLimits, isTrue);
      expect(balanced.ignoresResourceLimits, isFalse);
      expect(
        [saver.partialIntervalMs, balanced.partialIntervalMs, fastest.partialIntervalMs],
        [250, 100, 50],
      );
      expect(
        LatencyTier.values.map((t) => LatencyTiers.apple(t).frequentFinalization),
        everyElement(isTrue),
        reason: 'measured: Dictation lines end ~15 s late without it',
      );
    });

    test('sherpa: smaller feeds and shorter pauses as the tier rises', () {
      final tiers = LatencyTier.values.map(LatencyTiers.sherpa).toList();
      expect(tiers.map((t) => t.numThreads), [
        1,
        1,
        1,
      ], reason: 'measured: a 2nd thread only adds CPU');
      expect(tiers.map((t) => t.feedMs), [200, 100, 50]);
      expect(tiers.map((t) => t.endpointSilenceMs), [1000, 800, 500]);
      // The panel takes at most 10 updates a second.
      for (final t in tiers) {
        expect(t.partialIntervalMs, greaterThanOrEqualTo(1000 ~/ CaptionOverlay.maxPushHz));
      }
    });
  });

  group('model selection with fake probes', () {
    PlatformProbe mac(OsVersion version, {Set<String> assets = const {}}) =>
        FakeProbes.macos(version, installedAssets: assets);

    test('macOS 26: Apple first; a chosen Dictation or sherpa model is honoured', () {
      final probe = mac(tahoe26);
      final platform = fakeTinglangPlatform(probe);
      expect(platform.liveAsr.pick(probe).id, 'speech_transcriber');
      expect(platform.fileAsr.pick(probe).id, 'speech_analyzer_file');
      expect(
        platform.liveAsr.pick(probe, SpeechModels.appleDictation.id).id,
        'dictation_transcriber',
      );
      expect(
        platform.fileAsr.pick(probe, SpeechModels.appleDictation.backendId(SpeechUse.file)).id,
        'dictation_file',
      );
      final withSmall = mac(tahoe26, assets: SpeechModels.smallEnglishStreaming.requiredAssets);
      expect(
        fakeTinglangPlatform(withSmall).liveAsr.pick(withSmall, 'sherpa.zipformer_en_small').id,
        'sherpa.zipformer_en_small',
      );
    });

    test('macOS 26: a chosen sherpa model without its files says what to download', () {
      final probe = mac(tahoe26, assets: {SpeechModels.parakeet.pack!.id});
      final choice = fakeTinglangPlatform(probe).fileAsr.pick(probe, 'sherpa.parakeet_tdt_v2');
      expect(choice.id, 'speech_analyzer_file', reason: 'falls back while the VAD is missing');
      expect(
        choice.preferredAvailability,
        isA<NeedsDownload>().having((n) => n.assetId, 'asset', 'silero-vad'),
      );
    });

    test('macOS 14.2: no Apple engines; nothing runs until a pack is downloaded', () {
      final probe = mac(sonoma142);
      final platform = fakeTinglangPlatform(probe);
      final live = platform.liveAsr.pick(probe, SpeechModels.appleSpeech.id);
      expect(live.hasSelection, isFalse);
      expect(live.preferredAvailability, isA<Unsupported>());
      expect(
        live.blocker,
        isA<NeedsDownload>().having((n) => n.assetId, 'asset', 'xasr-zh-en-480ms-int8'),
      );
      expect(
        platform.fileAsr.pick(probe).blocker,
        isA<NeedsDownload>().having((n) => n.assetId, 'asset', 'xasr-zh-en-offline-punct-int8'),
      );
    });

    test('macOS 14.2: downloaded packs make sherpa live and file models available', () {
      final probe = mac(
        sonoma142,
        assets: {
          ...SpeechModels.xasrStreaming.requiredAssets,
          ...SpeechModels.mediumEnglishStreaming.requiredAssets,
          ...SpeechModels.xasrOffline.requiredAssets,
        },
      );
      final platform = fakeTinglangPlatform(probe);
      expect(platform.liveAsr.pick(probe).id, 'sherpa.xasr_zh_en_480');
      expect(
        platform.liveAsr.pick(probe, 'sherpa.zipformer_en_medium').id,
        'sherpa.zipformer_en_medium',
      );
      expect(platform.fileAsr.pick(probe).id, 'sherpa.xasr_zh_en_offline');
    });

    test('the pipeline follows the recogniser', () {
      expect(BackendCatalog.pipelineFor('speech_transcriber'), 'pipeline.native_macos');
      expect(BackendCatalog.pipelineFor('dictation_transcriber'), 'pipeline.native_macos');
      expect(BackendCatalog.pipelineFor('sherpa.xasr_zh_en_480'), 'pipeline.portable');
      // Cloud services share capture and the ring with sherpa-onnx.
      expect(BackendCatalog.pipelineFor('cloud.soniox'), 'pipeline.portable');
      expect(BackendCatalog.isCloudAsr('cloud.tencent'), isTrue);
      expect(BackendCatalog.isCloudAsr('sherpa.parakeet_tdt_v2'), isFalse);
    });

    test('the platform adds downloaded packs to every probe', () async {
      final platform = fakeTinglangPlatform(mac(sonoma142))
        ..models = _Inventory(SpeechModels.xasrStreaming.requiredAssets);
      final probe = await platform.probe();
      expect(probe.installedAssets, containsAll(SpeechModels.xasrStreaming.requiredAssets));
      expect(platform.liveAsr.pick(probe).id, 'sherpa.xasr_zh_en_480');
    });
  });
}
