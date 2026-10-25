# Architecture · TingLang 0.6

## Scope and provenance

TingLang (听浪) is an independent Flutter application (AGPL-3.0, or a commercial licence; see NOTICE.md). Bundle id `dev.eeeease.tinglang`, data folder `Tinglang`, Keychain service `dev.eeeease.tinglang`, packages `tinglang_*`. It shares the media_kit playback approach with Echo-Loop and accepts English V3-designed courses, but contains no Echo-Loop code since M1 (see NOTICE.md). macOS is the first platform; Windows follows in M8 behind the same Dart interfaces.

## Repository layout (pub workspace)

```text
lib/                              The app (root workspace package)
├── main.dart                     Startup: TinglangNative.install(), SQLite store, panel, licences
├── app.dart                      MaterialApp (locale/theme from settings), sidebar shell
├── l10n/                         gen-l10n: app_en.arb, app_zh.arb (+ generated Dart)
├── core/
│   ├── course_codec.dart         Course import, timestamp and SRT/VTT parsing
│   ├── sentence.dart             Timed cue value object (independent implementation)
│   ├── models.dart               Area, course, clip, learning item, attempt
│   ├── json_helpers.dart         Strict external-data reads, stable composite keys
│   ├── library_store.dart        App-owned media, paths, LibraryState, legacy JSON store
│   ├── review.dart               Explicit self-reported recall schedule
│   ├── share_package.dart        `.tinglang` share files (export/import)
│   └── db/                       drift schema, TinglangDatabase, SqliteLibraryStore
├── services/                     AppController, LiveController, PanelCoordinator, TranscriptionController,
│                                 VoiceMemoService, PlaybackHub, RecordingService, SyncService + SyncEngine,
│                                 UpdateService (GitHub Releases)
└── ui/                           History (captions · review · speak), Library (mine · discover · shared),
                                  Settings, Session, Learn, Voice Memos list
packages/
├── tinglang_platform_interface/   Pure Dart: capability interfaces, registry, probe, fakes
├── tinglang_cloud_asr/            Pure Dart: cloud speech services behind CloudAsrProvider
├── tinglang_native/               App-facing: TinglangNative.install(); shared Dart backends (stubs)
├── tinglang_native_macos/         Swift plugin (SPM + podspec), Pigeon host API
├── tinglang_native_windows/       C++ plugin skeleton (M8)
├── tinglang_ui/                   Design tokens (light/dark), theme, shared surfaces
└── tinglang_api/                 Pure Dart: client for the cloud API contract (models, ApiClient, OAuth + PKCE)
api/                              The cloud API contract: OpenAPI 3.1, JSON Schemas, examples (docs/CLOUD.md)
scripts/configure_macos.py        Native runner configuration (macos/ is generated)
drift_schemas/                    Committed schema snapshots for migration tests
integration_test/                 Runs on a real Mac (Pigeon probe + shell)
```

All local packages are `publish_to: none` with `resolution: workspace`; one `pubspec.lock` at the root.

## Native capabilities: factory per capability

`TinglangPlatform` (in `tinglang_platform_interface`) exposes one `BackendRegistry<T>` per capability: `systemAudio`, `microphone`, `liveAsr`, `fileAsr`, `decoders`, `translators`, `overlays`, `hotkeys`, `shells`, `secrets`, `youtube`, `voiceMemos`, `pipelines`. Interfaces: `AudioCaptureBackend`/`NativeAudioSource`, `StreamingAsrBackend`/`AsrSession` (Partial/Final/Gap events + 1 Hz `AsrStats`), `FileTranscriber`, `MediaDecoder`, `TranslatorBackend`, `CaptionOverlay` (the floating panel), `GlobalHotkeys`, `DesktopShell` (main window, appearance, System Settings links), `SecretStore`, `YouTubePlayer`, `VoiceMemoLibrary`, `LivePipelineHost`.

Each backend is a `BackendSpec` in `BackendCatalog` (id, platforms, minimum OS per platform, permissions, model assets, `cloud`) plus a lazy factory. `spec.evaluate(probe)` returns a sealed `Availability`: `Available`, `NeedsPermission` (with `denied`), `NeedsDownload`, `NeedsOptIn` (cloud not enabled) or `Unsupported`. `pick(probe, userPreferredId)`:

1. the user's preferred backend if it is registered and `Available` (the only way a cloud backend is chosen);
2. otherwise the first `Available` non-cloud backend in the platform's preference order (`sherpa.*` wildcards allowed);
3. otherwise no selection, with `blocker` naming the most actionable fix and `preferredAvailability` explaining an ignored preference.

`PlatformProbe` carries OS, version (Windows as `10.0.<build>`), architecture, ANE, speech locales, translation pairs, permission states, installed assets and user-enabled cloud backends. On macOS it comes from Swift over Pigeon (`TinglangHostApi.probe()`); elsewhere `DartIoProvider` uses dart:io. Each OS package registers itself as `NativeBackendProvider.current` from its `dartPluginClass`; `TinglangNative.install()` builds the platform, registers shared Dart backends, then native ones (which replace shared stubs by id).

Fakes for every catalog spec (`package:tinglang_platform_interface/testing.dart`) drive the selection tests (macOS 14.2 vs 26, Windows 19041 vs 26100, permission, download and opt-in states).

Default engines follow the measured M0 benchmark (`docs/perf/asr-bench-2026-10.md`): on macOS 26+ the native pipeline with Apple SpeechTranscriber comes first; elsewhere sherpa-onnx X-ASR in the portable pipeline (macOS 14.2–15 since 0.4; Windows at M8). The user can choose another model (see "Speech models and latency").

## Live captions on macOS
Everything with real-time audio stays in Swift (`packages/tinglang_native_macos`); Dart sends Pigeon control calls and receives one event stream (`TinglangEvents.liveEvents`).

```text
Core Audio process tap (exclude own PID)  ─┐            ┌─> caption panel (NSPanel, scrolls back, 10 Hz)
  └ ScreenCaptureKit fallback (silent tap) ├─> convert ─┤
AVAudioEngine microphone                  ─┘  to the    └─> SpeechAnalyzer + SpeechTranscriber
                                              analyzer       (timeIndexedProgressive, out of process)
                                              format          │ volatile → partial (coalesced 10 Hz)
                                                              │ final    → final ─> Apple Translation
                                                              ▼                      (finals only, serial)
                                                  LiveEvent stream ─> LiveController (Dart)
                                                                        ├ lines (one ChangeNotifier each)
                                                                        └ SQLite: session/segment/translation
                                                                          (batched every 2 s, partials never stored)
```

- `LiveCaptionEngine.swift`: speech assets via `AssetInventory` (a nil install request means nothing to download, even when `status` says "supported"), level meter and app CPU (`getrusage`) at 10 Hz / 1 Hz, silent-tap watchdog (no non-zero sample for 4 s while the output device is running → ScreenCaptureKit).
- `AudioSources.swift`: tap → private aggregate device → IOProc; mic; SCK at 1 fps 2×2 video. The first tap creation shows the "record system audio" prompt with `NSAudioCaptureUsageDescription`.
- `CaptionOverlay.swift` + `CapturePanelView.swift`: the floating panel (see below; started from SubFlow's MIT panel); Carbon `RegisterEventHotKey` for ⌘⇧T (no Accessibility permission).
- `LanguagePackWindow.swift`: hosts `.translationTask` so macOS can download a translation pack; asked for explicitly in the UI.
- Dart: `MacNativePipelineHost` (also `LiveSetupSupport` for asset/pack checks), `LiveController` (toggle, setup needs, batching, crash → `interrupted` on next launch), `LiveRepository`, `transcript_export.dart` (SRT/VTT/TXT; times relative to capture start).

## Speech models and latency
### Choices

`SpeechModels` (`tinglang_platform_interface/lib/src/speech_models.dart`) lists the recommended models; each id is a backend id in `liveAsr` and/or `fileAsr` (Apple engines register live and file backends separately: `speech_transcriber`/`speech_analyzer_file`, `dictation_transcriber`/`dictation_file`).

| Model | Use | Engine | Download | Notes |
|---|---|---|---|---|
| Apple Speech | live, files | SpeechTranscriber (macOS 26+) | system asset per accent | most accurate, ~3% CPU |
| Apple Dictation | live, files | DictationTranscriber (macOS 26+) | system asset per accent | far-field / short-form hints; ~11% CPU, less accurate |
| X-ASR zh-en 480 ms int8 | live | sherpa online transducer | 135 MB archive → 169 MB | en + zh, punctuation, ~15% CPU |
| Zipformer English 20M | live | sherpa online transducer | 45 MB | smallest, earliest words; no punctuation (shown sentence-cased) |
| Zipformer English 66M | live | sherpa online transducer | 73 MB | 320 ms chunks; no punctuation (shown sentence-cased) |
| X-ASR zh-en offline int8 | files | sherpa offline transducer + VAD | 137 MB archive → 175 MB | en + zh, punctuation |
| Parakeet TDT 0.6B v2 int8 | files | sherpa offline NeMo transducer + VAD | 661 MB | most accurate English, ~22% CPU |

Every sherpa backend also needs Silero VAD (`silero-vad`, 0.6 MB); its `BackendSpec.assets` lists both, so `pick` reports `NeedsDownload` for whichever is missing. Settings keys (`app_meta`): `asr_live_model`, `asr_file_model` (`auto` or a model id), `asr_latency`, `asr_accent_en`, `asr_dictation_far_field`, `asr_dictation_short_form`. `BackendCatalog.pipelineFor(asrId)` maps Apple ids to `pipeline.native_macos`, `sherpa.*` to `pipeline.portable`.

### Latency tiers

`LatencyTiers.apple()` / `.sherpa()` map Settings → Recognition latency:

| Tier | Apple (SpeechAnalyzer / transcriber) | sherpa-onnx |
|---|---|---|
| Power saver | priority `.utility`, retention `.whileInUse`, partials every 250 ms, Dictation `frequentFinalization` | 1 thread, 200 ms feeds, line ends after 1.0 s silence, partials ≤ 4 Hz |
| Balanced (default) | `.userInitiated`, `.lingering`, 100 ms (10 Hz), Dictation `frequentFinalization` | 1 thread, 100 ms feeds, 0.8 s, ≤ 10 Hz |
| Lowest latency | `fastResults`, `.high`, `.processLifetime`, `ignoresResourceLimits` (macOS 27+), Dictation `frequentFinalization`, 50 ms | 1 thread, 50 ms feeds, 0.5 s (X-ASR: 0.8 s, shorter drops words), ≤ 10 Hz |

`prepareToAnalyze` warms the Apple model on every tier. Measured cost per tier: docs/perf/asr-latency-2026-10.md.

### Ready before recording

Nothing downloads at start any more: Swift throws `assetsMissing` if a speech asset is not installed. `LiveController.checkSetup` resolves the chosen (or automatic) recogniser with `liveAsr.pick` before any capture: a sherpa model without its files becomes `ModelDownloadNeeded(model, bytes)` (an explicit choice is never silently replaced), a missing Apple asset `SpeechModelNeeded(locale, engine)`, a model that cannot recognise the learning language `ModelLanguageUnsupported`. The panel's existing `needsSetup` state shows the message with the size and one action (`install`); pressing it is the consent. While downloading the panel is `preparing` with `progress` and a `cancel` action (`OverlayAction.cancel`); when the download finishes, capture starts. `start()` itself re-checks, so ⌘⇧T cannot record before the model is there. `TranscriptionController` refuses an import before copying (`ImportProblem.modelMissing` / `speechAssetMissing`).

### Downloads (`ModelStore`, `ModelDownloader`)

Packs live in `<data>/models/<pack id>/` with a `.receipt.json` (file sizes and SHA-256); a pack counts as installed when the receipt exists and every file has its size. `ModelDownloader.start(pack, consent: DownloadConsent)` refuses without a consent for that pack and byte total, creating no `HttpClient`; the client is made per job (so `offline_guarantees_test` sees none at startup). Files are fetched over https only (k2-fsa GitHub releases, Hugging Face pinned to a commit), redirects checked hop by hop, resumed with `Range` from `<name>.part`, hashed while streaming and renamed into place; a mismatch deletes the part. The two X-ASR packs exist only as `.tar.bz2` release archives: the archive is verified, only the listed files are extracted with the system `tar` into `.staging`, each is verified, then moved. Cancel keeps partial files for resume. Apple assets go through `SpeechAssetSupport` (`AssetInventory` install with progress, cancel, `release(reservedLocale:)`).

### sherpa-onnx runtime: Dart package in worker isolates

Two ways were weighed: calling the sherpa-onnx C API from Swift (like topology A, everything in Swift), or the Dart `sherpa_onnx` package (1.13.8, the version benchmarked) in worker isolates. Both load the same `libsherpa-onnx-c-api.dylib` (onnxruntime linked in; the pub package ships it as an xcframework through SPM). The Dart package was chosen: the measured runtime is exactly what ships, the recogniser code is shared with Windows (M8) behind the same interfaces, model configs are testable with fakes, and no C bindings or second binary are maintained in Swift. The cost is a PCM bridge from Swift capture to the worker isolate and caption text going to the panel over Pigeon (text only, ≤ 10 Hz).

```text
Swift: tap / mic / SCK ─▶ 16 kHz mono f32 ─▶ PcmRing (native, 30 s) ──FFI read──▶ Dart worker isolate
        └ AAC .m4a on the same clock          └ wake(available) via NativeCallable.listener   ├ Silero VAD gate
                                                                                               ├ OnlineRecognizer (tier)
root isolate ◀── partial/final text (SendPort) ◀──────────────────────────────────────────────┘
   ├ LiveController (lines, SQLite)   └ CaptionOverlay.pushTail ─Pigeon─▶ panel   └ Apple Translation (finals, macOS 26)
```

- **Ring (`PcmRing.swift`, `pcm_ring.dart`):** one per capture; Pigeon returns only its address. The header (magic `TLPR`, version 1) holds C function pointers `read`, `setWake`, `release`, `dropped`, the sample rate and capacity, so Dart needs no exported symbols. Single producer (capture thread), single consumer (worker isolate); overflow drops the oldest samples and counts them (`FramesDropped`). Swift calls the wake callback under the ring lock after ≥ 50 ms of new audio; the worker clears it before closing its `NativeCallable`. Memory is freed after both sides released it.
- **Live (`sherpa_streaming_asr.dart`, `portable_pipeline.dart`):** `PortablePipelineHost` opens the capture backend (`pickCapture`: a permission macOS was never asked about does not stop a backend, because macOS asks when capture opens and system audio recording cannot be queried at all; a refusal throws `CapturePermissionDenied`, which `LiveController` shows as `CapturePermissionNeeded` with a button to the System Settings pane; captions from the microphone ask macOS first through `LiveController.requestMicrophone`), starts `SherpaStreamingAsr` on the ring, translates finals serially and pushes the visible tail to the panel. The worker feeds the recogniser only while Silero VAD (threshold 0.4) hears speech, with 1 s of pre-roll, and keeps feeding for the endpoint pause plus 1 s after speech (Silero drops out mid-speech for up to ~0.75 s) so lines end at sherpa's rule-2 endpoint; rule 1 is off. Long silences cost only the VAD. For the LibriSpeech zipformers each new stream starts with 640 ms of silence and quiet audio is boosted (towards a 0.3 peak, at most 30×) — without these they dropped the first second and produced almost nothing on quiet clips; their upper-case text is shown sentence-cased. Times are capture-clock offsets, i.e. offsets into the recorded `.m4a`.
- **Files (`sherpa_file_transcriber.dart`):** Swift decodes the first audio track to a temporary headerless 16 kHz f32 file (`decodeToPcmFile`); the worker reads it, splits it with the VAD and runs the offline recogniser per segment. Only the path crosses Pigeon.

## Cloud speech services
For Macs that cannot run the local models, or users who prefer a service, speech can be recognised by a cloud API with the user's own key. The app still calls one interface: the services are backends in the same `liveAsr` / `fileAsr` registries as Apple's engines and sherpa-onnx.

```text
Settings → Speech recognition: [ On this Mac | Cloud API ]
                                      │ asr_mode, asr_cloud_provider (app_meta); keys: Keychain asr:<id>
SpeechModelService ── modelFor(use) = cloud.<id> ── TinglangPlatform.enabledCloudBackends = {cloud.<id>} (only with saved keys)
        │
liveAsr / fileAsr registries ── cloud.<id> specs (cloud: true, never auto-picked)
        │                                  │
CloudStreamingAsr (tinglang_native)    CloudFileTranscriber (tinglang_native)
  worker isolate reads the capture ring    decoder → f32 file → worker isolate → WAV pieces
        │                                  │
        └──────── CloudAsrProvider (packages/tinglang_cloud_asr, pure Dart) ────────┘
                   tencent · dashscope · xfyun · soniox · assemblyai · azure
```

- **Interface** (`tinglang_cloud_asr`): `CloudAsrProvider` with `openStream` (16 kHz mono PCM16 in, partial/final `CloudSegment`s out, times from the stream's first sample), `transcribeFile` (one WAV within `CloudAsrInfo.maxFileMs` / `maxFileBytes`), `verify` (the cheapest call that proves the key) and `hosts` (for the consent line). Fields are named by `CloudFieldKeys`; labels are in the app's .arb files. Errors are `CloudAsrError` with a kind; messages never contain credentials. No socket or `HttpClient` exists before a call. Each service's endpoints, signing, limits and language mapping are in `packages/tinglang_cloud_asr/doc/<id>.md`; tests run against loopback servers only.
- **Live** (`CloudStreamingAsr`, `CloudLiveRelay`): runs in the portable pipeline like sherpa-onnx (`pipelineFor('cloud.*')` is `pipeline.portable`). A worker isolate reads the native ring (PCM never enters the root isolate), converts to 16-bit and sends 100 ms pieces. Every connection keeps its own time base (the capture sample index of its first sample), so times stay offsets into the capture: a stream the service ends at its time limit (`sessionEnded`, or an unasked close) is replaced at once; network and server failures are retried with backoff (0.5 s doubling, six attempts; a stream that worked for a minute resets the count) while up to 30 s of audio waits; older audio becomes an `AsrGap`. Lost ring frames finish the stream and start a new one after the gap. The last partial of a dropped stream is kept as a final. A refused key, an exhausted quota or giving up ends the session with `AsrFailure` → `RecognizerFailed`; `LiveController` stops and shows the reason in the user's language.
- **Files** (`CloudFileTranscriber`): the platform decoder writes the audio to a temporary f32 file; a worker isolate cuts it into pieces of at most the service's limit (and 30 min), each at the quietest 200 ms in the last 10 s before the limit, sends them as WAV, retries pieces that failed for reasons that may pass (three attempts) and shifts the times by the piece's offset. Translation works as for the local models. The temporary file is always deleted.
- **Choice and consent**: cloud mode applies to live captions and files where the service offers them (otherwise the local choice applies). A cloud choice never falls back to a local model, or the other way round: without saved keys, start and import stop with `CloudSetupNeeded` / `ImportProblem.cloudNotSetUp`; a language the service does not list stops with `CloudLanguageUnsupported`. The settings form shows `SlBadge.cloud` and the hosts audio goes to; while captions run in the cloud the panel says "Cloud · <service>".
- **First start**: until the user has chosen a mode or a model (`SpeechModelService.setupChosen`), pressing start without a ready recogniser shows `RecognizerChoiceNeeded` on the panel and opens Settings → Speech recognition, which starts with a two-way choice (models on this Mac / cloud API). A recogniser that is ready (e.g. Apple's model already installed) starts without asking. The first-start guide (below) offers the same choice earlier.

## First-start guide
`ui/onboarding_dialog.dart`: a dialog in three steps — permissions, the speech model, how to use the panel — with Skip, Back and Next. It opens by itself once, for a new library: `main.dart` sees that the data folder does not exist yet, writes `onboarding = pending` to `app_meta` and shows the main window (normally hidden at launch); the shell opens the guide after its first frame. However the guide closes, the value becomes `done`. Libraries from before 0.7 have no value and never see it unless the user opens it from Settings → General (Show again).

- **Permissions:** system audio recording (required; macOS has no way to ask before the first Core Audio tap, so the row says it is asked on first use and links to the Screen & System Audio Recording pane), the microphone (state from the probe; Allow calls the `record` plugin's `hasPermission`, which shows macOS's question once, afterwards a link to the pane), screen recording (optional fallback; `CGPreflightScreenCaptureAccess` only tells "allowed") and Full Disk Access (optional, for Voice Memos; no state). The links go through `DesktopShell.openSystemSettings`. The probe is read again whenever the app comes back to the front (`AppLifecycleListener.onResume`).
- **Speech model:** the two-way choice (local / cloud) and the model "automatic" uses for live captions on this Mac (`SpeechModelService.automaticModel`: the one that runs, else the first local one that only needs a download), with its ratings and either Ready or its download — Apple's asset through `installApple`, a sherpa model through the same size, host and licence question as Settings (`confirmSpeechDownload`). Nothing is chosen until the user presses an option or a download. Finishing with the cloud chosen and no key opens Settings → Speech recognition.
- **How to use:** start (the panel's button or ⌘⇧T), placing and locking the panel, History and courses, dropping files.

## Settings
Settings is one page with tabs (`SettingsTab`): General (interface and learning languages, appearance, the first-start guide), Live captions (panel, layout, scroll-back, keeping system audio), Speech recognition (local models or cloud API, latency, accents), AI services, Sync & data (iCloud Drive sync, the data folder, exports) and About; General also holds the update check. The account is not in Settings: it sits at the bottom of the sidebar. The shell keeps the selected tab; `OpenSettings(speech: true)` from the panel opens Speech recognition.

## Floating panel and main window
The panel is the app's front door: a non-activating `NSPanel` hosting SwiftUI, on every Space and above full-screen apps. Its states are idle (a pill: record button, source menu, today's new Voice Memos, History, and the mark at the right end, which opens the app menu; the two ends are round 36 pt buttons, the record button in the accent colour and the mark on paper like the app icon, with a hover ring and a pressed look while its menu is open), preparing, needs setup, listening (a caption card of fixed size, or text only like desktop lyrics, with a hover toolbar), stopping, saved (length, words, View / Make course), error and notice. Dart sends `OverlayConfig` (look and strings) and `PanelState` (phase, counts, message, one action) over Pigeon; captions and the level meter go from `LiveCaptionEngine` straight to the panel at 10 Hz. Button presses, dropped files and looks chosen on the panel come back on the live event stream (`panel`, `drop`, `panelStyle`).

- **Look:** mode, layout (stacked, or side by side: recognised text left, translation right, row by row; `SideBySideRow` puts a translation no taller than its line on the line's last baseline, so a short Chinese line sits next to the end of a long English one, while a taller one starts at the top and the row grows; the recognised text never moves), background (clear / glass / solid + opacity), text and translation colours, size, weight, outline, visible rows, alignment, translation on/off, lines kept for scrolling back and the click-through lock. Saved as `overlay_*` settings; `panel_settings.dart` maps them both ways. Layout and scroll-back are also in Settings → Live captions; `PanelCoordinator` pushes a changed look to the panel.
- **Captions:** the caption area has a fixed height (visible rows × the current type size), so the panel never grows or shrinks with the lines, and it scrolls. The engine sends only its newest 30 lines; `CaptionOverlayController` merges them into a `CaptionBuffer` that keeps up to `scrollbackLines` of the session (50/100/200/500, default 100). Older lines leave the panel; the database keeps everything. While the reader has scrolled back the drawn list stops growing (lines already shown still get their translations) and a "Back to latest · n new" chip appears; the chip or scrolling to the bottom follows the newest line again. Following uses the macOS 15 scroll APIs (`onScrollGeometryChange`, `ScrollPosition`): a change of content height is new text, a move at the same height is the reader. On 14.x the panel only follows (live captions need macOS 26 anyway). Side by side has its own remembered width (default 880 pt).
- **Lock:** `clickThrough` makes the panel ignore the mouse only while captions run; the idle pill always takes clicks. When locked the header shows "Locked · clicks pass through" instead of its buttons, and a 0.2 s pointer watch (the panel itself sees no hover) shows the text-only chrome and an unlock chip above the panel. The chip, the Dock menu and the Appearance toggle unlock.
- **Hints:** SwiftUI's `.help` uses AppKit tooltips, which do not appear while the app is in the background (`allowsToolTipsWhenApplicationIsInactive` is off by default), and the panel is mostly used while another app is in front. So the panel's controls (record/stop, History, the mark, the header's icon buttons) show their own hint: a `PanelHintWindow` above the panel (below it at the top of the screen) that never takes the mouse, 0.5 s after the pointer rests on a control; moving on to the next control changes it at once, a click hides it until the pointer leaves, moving or hiding the panel hides it. Hover still works in the background because SwiftUI's tracking area is active always. The texts come from Dart (`hintRecord` / `hintStop` with ⌘⇧T, `hintMenu`, and the existing labels).
- **Moving:** "movable by window background" does not reach SwiftUI content in a borderless window, so a drag gesture on the panel moves it, following the pointer in screen coordinates; drags that start on the captions are handled in `CapturePanelWindow.sendEvent`, because the scroll view keeps them to itself. Every move saves the anchor (bottom centre); a wider look is kept on its screen.
- **Who decides what:** `LiveController` owns the caption phases; `PanelCoordinator` handles the rest (open History, a session or the Voice Memos list in the main window, transcribe dropped files, save the look and source, follow the "show panel" and theme settings, keep strings in the interface language).
- **Main window:** hidden at launch (`visibleAtLaunch="NO"`). `MainFlutterWindow` creates and runs a headless-capable `FlutterEngine` itself (a view controller would not start Dart until its window shows) and ignores show requests until `reveal()`: the Dock icon, a panel button, no panel, or a failed start (Dart reports `appReady`; after 20 s without it the window shows anyway). The title bar is transparent (`fullSizeContentView`); Flutter keeps the top 28 pt free. Closing the window keeps the app and panel running; ⌘Q quits through the exit guard. Files dropped on the window are forwarded to Dart like panel drops.
- **Sections:** History (captions and imports grouped by day and previewed by their first line, with Review and Speak as tabs), Library (Mine, Discover placeholder, Shared) and Settings.

## Voice Memos
`VoiceMemoLibrary` (backend `apple_voice_memos`, macOS) copies `CloudRecordings.db` (+ `-wal`/`-shm`) from `~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings` (or the pre-macOS 12 Application Support folder) to a temporary folder and reads `ZCLOUDRECORDING` with sqlite3: `ZPATH`, `ZDATE` (Core Data seconds since 2001), `ZDURATION`, the title (`ZCUSTOMLABEL`, else `ZENCRYPTEDTITLE`), `ZUNIQUEID`, `ZEVICTIONDATE`; optional columns are looked up with `PRAGMA table_info`. Recordings only in iCloud (no path), recently deleted (eviction date), missing, not `.m4a`/`.qta`, or pointing outside the folder are skipped. The library itself is never written.

The folder is protected: without Full Disk Access every read fails with `EPERM`, reported as `needsFullDiskAccess` (macOS has no API to ask first). `VoiceMemoService` reads nothing until the user opens the list; once a listing has worked (`voice_memos_enabled`), launches and returning to the app (at most once a minute) look for today's recordings that are not imported yet, shown as a banner in History and a chip on the panel. Imports go through `TranscriptionController` with origin `voice_memo`, the memo's title and recording time, and `session.source_ref = voicememo:<id>`, which marks it imported.

## Share packages
A `.tinglang` file is a zip: `manifest.json` (format `tinglang.share`, version, kind, title, language, dates, media entry), `transcript.json` (lines with times, word timings, the translation and, since 0.4, every translation per language) or `course.json` (the English V3 document), and optionally `media/media.<ext>`. Media is stored, not deflated (it is already compressed), so writing streams the file instead of compressing it in memory; zip work runs in a background isolate (`Isolate.run`), and a package is written to a temporary file and then moved into place, so a half-written package never appears (this matters in iCloud Drive). Import trusts no names inside the zip: only those entries are read, media must be the manifest's entry under `media/` with an allowed extension, sizes are capped (20 MB JSON, 4 GB media), a newer format version is refused. A recording becomes a `shared` session; a course is upserted like any import, keeping learner records. There is no sharing server yet; the Shared tab says so.

- **Export from where people look:** a course from its card's ⋯ menu in Library and from the course page; a recording or import from its ⋯ menu in History and from the session page (also when it has media but no lines yet). A course with local media includes the media; YouTube courses have none.
- **macOS knows the type:** `configure_macos.py` exports the UTI `dev.eeeease.tinglang.package` (conforms to `public.zip-archive` and `public.data`, extension `tinglang`, Finder kind "Tinglang Package" / "听浪学习包") and declares a document type (Viewer, `LSHandlerRank` Owner) whose icon macOS draws from the app icon (`CFBundleTypeIconSystemGenerated`, as Apple's Shortcuts and Notes do). A double-click in Finder, Open With or a drop on the Dock icon reaches `application(_:open:)`; `FlutterAppDelegate` forwards it to the plugin (`registrar.addApplicationDelegate`, `handleOpen(_:)`), which keeps the paths until Dart takes them (`takeOpenedFiles`) and sends a `filesOpened` nudge. The plugin is registered while the main window loads, before AppKit opens documents, so a cold launch by a double-click is not lost: `PanelCoordinator.start` takes whatever is waiting once Dart is ready. Opened or dropped (panel or window) `.tinglang` files become an `ImportPackages` request; the main window opens and imports them one by one through the same flow as Library → Shared (`importSharedPath`: the update confirmation for a known course, the "Imported." message). Media files opened the same way are transcribed like drops.
- **Sync packages** (next section) are the same format with additive fields that version-1 readers ignore: a `sync` stamp (kind, key, content hash, time, device), the session's own ids, origin, status, times and source reference, line ids, and a course's source label and import time.

## iCloud Drive sync (opt-in)

Off by default (`app_meta` `setting.sync_icloud`). When on, Tinglang reads and writes a plain folder, `~/Library/Mobile Documents/com~apple~CloudDocs/Tinglang/`, and macOS syncs it between Macs signed in to the same Apple Account. Tinglang has no iCloud container entitlement (no paid developer account; see Known limitations), uses no CloudKit and makes no network request for sync: `test/sync/sync_engine_test.dart` runs passes under an `HttpOverrides` that fails on any `HttpClient`.

```text
Tinglang/
├── sync.json                      {"format": "tinglang.sync", "version": 1}
└── devices/<device id>/           one folder per Mac, written only by that Mac
    ├── state.json                 its versions: items (with their package) and learner values, tombstones
    ├── items/<kind>-<key hash>-<content hash>.tinglang   courses and sessions (content + media)
    └── recordings/<kind>-<key hash>.<ext>                 recordings of speaking-practice attempts
```

- **What is synced:** courses (package with media); finished sessions shown in History (`live_*`, `file`, `shared`, `voice_memo`; completed or interrupted; package with media, same session and line ids, source reference, so a Voice Memo counts as imported on every Mac); and the learner records: progress (one record per course, clip and step), drafts, review cards with their FSRS history, practice attempts (with their recording) and dictation answers. Not synced: settings, provider configs and keys (Keychain), the LLM cache, podcast tables, the panel's look, models. The SQLite database never goes to iCloud.
- **Records:** each Mac writes only its own folder, so iCloud never sees two writers of one file. `state.json` (format `tinglang.sync.state`, version 1) lists the versions this Mac made: `{kind, key, at (ms UTC), device, hash, deleted?, value?, file?}`; learner values travel inline, items and recordings by file name. A package's name contains its content hash: a changed item gets a new file and the old one is removed by its owner after the new state is written, so a reader never mistakes an old package for the new version (it waits instead).
- **Ledger:** `sync_record` (schema v4, on this Mac only) keeps per `(kind, key)` the version this Mac has (time, device, deleted, published hash) and the hash of the local copy when it matched. A pass (`SyncEngine.run`): (1) reads the other Macs' state files; (2) compares a snapshot of the library with the ledger: a new or different local hash is a change made here and gets a new version stamped with the time it was noticed (always later than the version it replaces); a record in the ledger that is gone locally gets a tombstone; (3) applies every other Mac's version that is newer than the ledger's: courses like an import (learner records stay; media already attached is kept when the package has none), sessions in place by id (`LiveRepository.importSessionCopy`, so dictation answers stay), learner records in one `AppController.change`, dictation answers through the repository once their session exists; the ledger then stores the local hash computed from what was applied, so a round trip that is not byte-identical never comes back as a change; (4) writes this Mac's missing packages and recordings, then `state.json` (only when it changed), then deletes its own unreferenced files. Hashes are cheap: courses, cards and attempts are hashed once per (immutable) object, sessions from a SQL aggregate (title, status, times, line and translation counts and lengths).
- **Conflicts:** last writer wins per record: the newer `(at, device id)` wins on every Mac. Two Macs editing the same draft keep the later edit; a card reviewed on both keeps the later review (the other review history is not merged). A library synced for the first time gives way to the versions other Macs already have, unless the record itself says it changed later (a card's last review, a course's import time, a recording's end): its first versions are stamped just before theirs.
- **Deletions** travel only as tombstones (kept in the deleting Mac's state). A missing file, a missing state file, an unreadable package or a not-yet-downloaded file never deletes anything; a tombstone older than a later change loses like any version.
- **Not downloaded yet:** an old-style placeholder (`.<name>.icloud`) or a file the `cloudDrive` capability reports as not downloaded (`URLResourceValues.ubiquitousItemDownloadingStatus`) is not read; the pass asks macOS to download it (`FileManager.startDownloadingUbiquitousItem`, `brctl download` as a fallback) and counts it as waiting ("Waiting for iCloud to download n item(s)"). A package listed before it arrives also waits.
- **Problems are reported, not fatal:** a corrupt package or recording, or a package or state file from a newer Tinglang, is skipped with a `SyncProblem` and the rest syncs; the same broken package is not read again in that run. A `sync.json` with a newer version stops the pass before anything is written.
- **Device id:** a random id in `app_meta` (`sync.device`) with a hash of the Mac's IOPlatformUUID (`sync.machine`, never written to iCloud); a library copied to another Mac gets a new id, so two Macs never share a folder.
- **When:** `SyncService` runs a pass when sync is turned on, at launch, 3 s after a change to synced content (`AppController` notifications filtered by a cheap fingerprint, so settings such as the panel's position do not count; drift table updates for sessions, lines, translations and dictation answers), on folder changes (`Directory.watch`, FSEvents) and every 2 minutes while the app is in front. One pass at a time; a trigger during a pass runs another after it. iCloud Drive off or not set up (no `com~apple~CloudDocs` folder) is a state in Settings and nothing is written; sync never creates that folder. A folder macOS refuses (Files and Folders privacy) shows how to allow it.
- **UI:** `lib/ui/sync_panel.dart` (`SyncPanel(sync:)`): the switch, iCloud Drive status, the folder and Show in Finder, the last sync, counts, other Macs, waiting and problems; labelled `SlBadge.cloud`, because files leave the Mac through Apple's iCloud.
- **Native:** capability `cloudDrive` (`CloudDriveSupport`, spec `icloud_drive`, macOS, not a cloud backend) → `MacCloudDrive` → Pigeon `cloudItemStates`, `cloudDownload`, `machineIdentifier` (`CloudDrive.swift`). Info.plist has `NSFileProviderDomainUsageDescription` for macOS's iCloud Drive access prompt.

## Recording, import, player and dictation
- **Kept audio:** a live session with `recordAudio` (always for the microphone, opt-in “Keep audio” for system audio) gets `recordPath`; Swift writes AAC from the already-converted analyzer buffers, so caption times are offsets into `media/live-<id>.m4a`. On stop the file becomes a `media` row and the session switches to `time_base = media`.
- **Import:** `TranscriptionController` copies the file into the content-addressed `media/` folder, inspects it (AVURLAsset), creates a `file` session and runs the platform `FileTranscriber`. On macOS 26+ that is `MacFileTranscriber`: AVAssetReader decodes the first audio track to 16 kHz mono, SpeechAnalyzer transcribes with `audioTimeRange` word timings, Apple Translation translates each line. Segments and translations are written in batches as events arrive. MKV/WebM/Ogg are refused before copying (AVFoundation cannot read them).
- **Session page:** media_kit player (video when the media has a video track), ±5 s, 0.6–1.5× speed, A–B loop (manual or per sentence ±200 ms), tap a line to seek.
- **Dictation:** lines are split into sentences by word timings (`dictationItems`), each played with ±200 ms padding; grading matches the English V3 course player (normalise, exact → correct, character-LCS ≥ 0.85 → close) plus a word-level diff (CJK per character). Attempts go to `dictation_attempt` (schema v2).

## English V3 courses, Learn modes and review
- **Codec:** quotes (original examples, shadowing passages, retelling evidence) are checked like the English V3 course validator — case-insensitive, quotes folded, whitespace collapsed. `CourseCodec(strictSource: true)` keeps the 0.1 behaviour. All V3 fields are kept: CEFR, subtype, why-useful, patterns, memory-aid type/note, blank type and linked item, shadowing reasons, retelling targets/evidence, clip topic/difficulty.
- **YouTube clips:** official IFrame API in a WKWebView loaded from `https://eeeease.github.io/` (Referer), clip bounds enforced in JS every 200 ms, captions unloaded, navigation away refused, nothing drawn over the player; errors 101/150/153 offer “Open on YouTube”. No media is downloaded.
- **Learn:** inline blind listening (English V3 colours, correct/close/incorrect via the dictation grader, all-correct marks the step done, misses → review), shadowing with passages highlighted in the transcript, retelling with a “try to use” list, and a deterministic quiz step (cloze from the exact source sentence, recall from the meaning; misses → review).
- **Review:** FSRS-6 (`core/fsrs.dart`) with default parameters; cards keep stability/difficulty (`card.scheduler = 'fsrs6'`), each rating logs s/d; buttons show the interval each rating would give.

## BYOK providers and course generation
- **Providers:** `core/providers/` — presets and models come from `assets/providers/catalog.v1.json`, built from LiteLLM's model catalog (MIT) by `tools/build_provider_catalog.py`: 18 presets (Anthropic, OpenAI, DeepSeek, DashScope/Qwen, Moonshot/Kimi, Z.ai/GLM, Volcengine/Doubao, MiniMax, Gemini, xAI, Mistral, Groq, Together, Fireworks, OpenRouter, LiteLLM Proxy, Ollama, LM Studio) plus custom, 628 models with context, $/MTok and JSON-schema support. Base URLs follow LiteLLM's defaults. Settings live in `provider_config` (`secret_ref` only records that a key exists); keys go to the platform `SecretStore` under `provider:<id>` (Keychain on macOS: generic password, service `dev.eeeease.tinglang`, accessible after first unlock). `feature_route('course_generation')` names the default. Endpoints on localhost are labelled local; everything else is labelled cloud, and a cloud run needs a per-run consent tick naming the host.
- **Protocols** (`LlmClient`, `dart:io` only, 5-minute request timeout):
  - *OpenAI-compatible* `POST /chat/completions` with `response_format: json_schema`, falling back to `json_object` and then none when a server rejects it (remembered per client). Bearer auth.
  - *Anthropic* `POST /v1/messages` with `x-api-key` + `anthropic-version: 2023-06-01`, `max_tokens` 16000, structured output via `output_config.format` (JSON schema). On `api.anthropic.com`, models that support it (Opus 5.5/5, Fable 5.1, Sonnet 5.5) send `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`), dropped if the server rejects it. `stop_reason: refusal` / `max_tokens` become soft per-clip failures.
  - Both report token usage; replies are parsed from text blocks, ``` fences or chatter tolerated; `GET /models` is "Test connection". Errors carry status and server message, never key or prompt.
- **Cost:** `CostEstimate.forCourse` estimates calls and tokens from the windows before a run and prices them from the catalog; after a run the dialog shows the provider-reported tokens priced the same way. Local endpoints are free; unlisted models show "no price data".
- **LiteLLM Proxy:** a preset for `http://localhost:4000/v1`. Users who run LiteLLM themselves reach Bedrock, Vertex, Azure and 100+ providers through it; Tinglang embeds no Python.
- **Pipeline** (`core/generation/`, orchestrated by `services/course_generation.dart`):
  - D1 sentences from saved lines, split by word timings (never invented times).
  - D2 contiguous 30–120 s windows; score = above-level word density.
  - L1 (AI only) the model picks ~1 clip per 6 min (1–25) and writes a summary; out-of-range picks are ignored, failure falls back to the rule-based pick.
  - D3 candidates from the ECDICT lexicon (`assets/lexicon/en.v1.json.gz`, built by `tools/build_lexicon.py`): words ranked ≥ the learner band (B2 → COCA rank 3000+), inflections resolved to lemmas, proper nouns and known lemmas skipped; lexicon phrases including phrasal verbs with inflected heads ("kept showing up"); 8–25-word sentences.
  - L2 (AI only) one call per clip → `clip_plan` JSON (prompt asks for reusable everyday language over names and technical terms, and passes the learner profile's `prefer_*`/`avoid_*` flags as plain phrases — fixed-shape keys only); quotes not found verbatim (case and quote style aside) trigger one repair call; remaining bad quotes are dropped by the compiler; a clip whose reply is unusable gets Basic content. Unreachable servers, 401/403, 429 and 5xx stop the run.
  - Basic (no LLM): dictionary glosses and approximate CEFR from frequency, lexicon phrases, one sentence, two shadowing passages, a generic retelling. Memory aids are left empty rather than made up.
  - D4 compile to English V3 (`podcast_id gen-<session>`, area personal, media = the session's media): ids, timings, exact quotes, blank template (sentences → phrases → words, non-overlapping, whole-word) and `tinglang_cues` are produced in code, then validated with `CourseCodec(strictSource: true)` before saving.
  - D5 the existing quiz and dictation work on the result unchanged.
- **Prompt-injection boundary:** transcript text is sent inside a `<transcript>` fence with a system rule that it is data; fence tags inside the text are neutralised. The model's output is only used where it can be checked (quotes) or is display text.
- **Cache:** `llm_cache` keyed by sha256(provider, model, prompt version, system, user); regenerating the same session makes no requests.

## Content versus learner state

Course objects carry a typed runtime view and the original raw JSON (including unknown fields). Completion, drafts, attempts and review history live separately, keyed by stable course/clip/item references. Updating course content does not replace those learner records.

`AppController.change` is the only normal persistent mutation entry: clone state, edit, save, publish new state. Failed saves expose an error rather than publishing a successful-looking state. The queue continues after failures so the user can retry. A stopped recording pending an index save is retained for retry; the UI blocks switching/exit while that pending attempt exists.

## Storage (SQLite)

`SqliteLibraryStore` (a `LibraryStore` subclass) keeps state in `tinglang.sqlite` via drift + sqlite3 (bundled SQLite from the sqlite3 build hook). `save` runs one transaction per `change`, writing only entities that differ from the last committed state (immutable entities are compared by identity, which `LibraryState.clone` preserves). A failed transaction rolls back completely and leaves the comparison base untouched. Course `raw_json` is the source of truth; `clip`/`item` rows are a queryable projection. Learner tables (`progress`, `attempt`, `card`, `review_log`, `draft`) have no foreign keys to course content.

Schema v1 tables: `media`, `session` (origin, time base, status; v3 adds `source_ref`), `time_anchor`, `segment` (+ `words_json`), `translation` (per language and quality), `course`, `clip`, `item`, `exercise`, `progress`, `attempt`, `card`, `review_log`, `provider_config`, `feature_route`, `llm_cache`, `podcast_feed`, `episode`, `draft`, `app_meta`. `segment_fts` is an FTS5 external-content table with the trigram tokenizer (works for CJK; queries under 3 characters fall back to LIKE), kept in sync by triggers. v2 added `dictation_attempt`; v3 added `session.source_ref`; v4 added `sync_record` (the iCloud Drive sync ledger, see "iCloud Drive sync"). Migrations: bump `schemaVersion`, add an `if (from < N)` step, run `dart run drift_dev make-migrations`; a database from a newer app is refused, never downgraded.

On first start, an existing `library.json` (0.1 format) is imported once inside a transaction and left untouched as a backup; a corrupt file aborts startup without writing. The JSON `LibraryStore` remains for that import and its tests.


## Time contract

All clip and cue times are integer milliseconds referenced to the **full original media**. External numeric times are seconds; colon-separated strings accept fractional milliseconds. `endMs == null` is only for newly imported untranscribed local media and is replaced in playback by the probed duration, not a guessed transcript length. Live sessions record their own time base (`session.time_base`) and `time_anchor` rows map session time to media time.

The parser never fabricates word timing. Courses with only clip transcripts work at clip granularity. `tinglang_cues` is an optional extension of `Sentence` JSON objects with `index`, `text`, `startTime`, `endTime`, `isBookmarked` (times in milliseconds). Local SRT/VTT imports use real cue boundaries.

A–B loops use media position/completion events. Accuracy and race behavior need native device testing; they are not sample-accurate transport guarantees. A file that ends before the course's referenced clip displays a mismatch message.

## Import boundary

The file picker is the only way the UI selects external media/course files. Media are stream-hashed, copied to controlled relative paths and checked after copying. External JSON never dictates which local file to open, never triggers a URL download, and never executes transcript text as instructions.

## Audio lifecycle

Two media-kit sessions (created on first use) handle original content and practice recordings. PlaybackHub pauses the other player when one is selected, and pauses both before a microphone session. RecordingService locks navigation before awaiting permissions and capture startup. WAV capture is mono, 44.1 kHz.

## UI, i18n and design system

`tinglang_ui` provides `TinglangColors` (a `ThemeExtension`, light and dark): paper and ink neutrals with one orange accent (`#BD5520` light, `#FF8A4C` dark; brand `#D9642A`), hairline edges and whisper shadows. Spacing, radius (8/12/20/28) and a fixed system-font type scale with CJK fallbacks; shared surfaces `SlPanel`, `SlPageHeader`, `SlTabs`, `SlNotice`, `SlEmptyState`, `SlBadge.cloud`. No fonts are bundled. Identity and design principles: `docs/BRAND.md`. The mark is drawn as vectors, not loaded as an image: `tools/brand_mark_geometry.py` turns the SVGs in `assets/brand/svg/` into `lib/ui/brand_mark_geometry.dart` (Flutter `Path`, arcs via `arcToPoint`) and `BrandMarkGeometry.swift` (SwiftUI, arcs as cubic Béziers); `BrandMark` uses the small-size drawing below 48 pt and follows the theme, the panel always uses the on-dark colours. The Dock icon PNGs (`assets/brand/app_icon_*.png`) are copied into the runner by `configure_macos.py`. All UI strings are in `lib/l10n/app_{en,zh}.arb`. Settings keep interface language, theme, learning language and native (translation) language separately in `app_meta`.

## Native runner

`scripts/bootstrap_macos.sh` generates a standard runner in a temporary folder with the `.fvmrc` Flutter, copies `macos/`, and `scripts/configure_macos.py` applies: App Sandbox off, Hardened Runtime on, `network.client`, `device.audio-input`, library validation disabled (media_kit embeds frameworks signed by another team), literal `NSAudioCaptureUsageDescription`/`NSMicrophoneUsageDescription`/`NSFileProviderDomainUsageDescription` plus en/zh-Hans `InfoPlist.strings`, the `.tinglang` exported type and document type (see "Share packages"), deployment target 14.2, ad-hoc signing unless a gitignored `Local.xcconfig` sets `DEVELOPMENT_TEAM`. Plugins resolve through Swift Package Manager; CocoaPods is still used for plugins that ship podspecs only.

## Updates
`services/update_service.dart` (`UpdateService`, a `ChangeNotifier` built in `main.dart`) with the file and script helpers in `services/update_install.dart`; the UI is `ui/update_banner.dart`: `UpdateBanner` (top of the main window: "TingLang X.Y.Z is available · What's new · Update and restart", then progress, Cancel, errors), `UpdateBadge` (a green arrow on the corner of the sidebar's mark while a newer version is known, also after the banner was put off; it opens `UpdateDialog` with the versions, What's new, Update and restart and the same progress and errors) and `UpdateSettingsTile` (Settings → General: the switch, this version, Check now, the last result).

- **Check:** `GET https://api.github.com/repos/eeeease/TingLang/releases/latest`, unauthenticated, no cookies, `Accept: application/vnd.github+json`, `User-Agent: Tinglang/<version> (macos)`. Automatic checks (`update_auto_check` in `app_meta`, on by default) start a minute after launch at the earliest and then come at most once per 24 h (`update_last_check`, also kept in memory so a failed save cannot cause a loop); Check now asks whenever pressed, also with the switch off. `start()` only sets a timer, so nothing is sent at startup; the timer is injectable and cancelled on `dispose`. A non-200 answer (404 while the repository is private, 403/429 rate limits), a network error, malformed JSON, a draft or prerelease, a tag that is not `vX.Y.Z`, or a missing asset all mean "no update", silently. Versions compare by number (0.10.0 > 0.9.0). A newer release is cached (`update_release`) so the banner returns after a restart without asking again. The release page is built from the tag, not taken from the answer.
- **Download** (only after Update and restart): `Tinglang-X.Y.Z-macOS.zip.sha256`, then `Tinglang-X.Y.Z-macOS.zip`, both from the release's asset list. Only https on `github.com` or `*.githubusercontent.com`; redirects are followed by hand and every hop is checked (as in `ModelDownloader`). The zip streams into a new temporary folder with progress and Cancel; its size must equal the asset size and its SHA-256 the `.sha256` file, or it is deleted.
- **Install:** the running bundle is found from `Platform.resolvedExecutable` (`…/Tinglang.app/Contents/MacOS/…`). Refused, with a link to the release page, under App Translocation (`/AppTranslocation/` in the path), on a read-only volume (EROFS) and when the folder or the bundle is not writable. `ditto -x -k` unpacks the zip; the one `.app` inside must have `CFBundleIdentifier` `dev.eeeease.tinglang`, `CFBundleShortVersionString` equal to the release and an executable (`plutil -extract … raw`). It is moved next to the installed app under a hidden name, so the swap is a rename on one volume. A detached `/bin/sh -c` script (`updateInstallScript()`; every path is a positional parameter) waits for the app's process to exit (two minutes at most, otherwise it deletes the copy and changes nothing), renames the old bundle aside, renames the new one into place (the old one comes back if that fails), removes `com.apple.quarantine`, opens it with `open` (the old one comes back if it does not open) and only then deletes the old bundle and the download. It logs to `tinglang-update.log` in the temporary folder. The app quits through `handleExitRequest`: `exitBlockedByRecording` (a recording runs or is unsaved) refuses the update before downloading and again before the hand-over, and if the exit handler still says no, the script is stopped and the copy removed.
- **Tests:** `test/update/`: versions, release JSON, host checks, checksum lines, bundle paths and the script's text; a loopback fake GitHub for answers, refusals and headers; download → verify → unpack → stage with fake bundles packed by `ditto` (checksum and size mismatches, wrong bundle, refused redirects, translocated and unwritable locations, a recording, a refused quit, Cancel); the script run against fake folders only (swap, roll-back, give-up); the schedule (nothing at startup, nothing with the switch off, once a day); the banner, the settings tile, the arrow and the dialog in English and Chinese.

## Cloud API contract
Optional cloud services (accounts, entitlements, cloud jobs, an LLM gateway) are defined by the contract in `api/`, not by any server's internals; the design and the decisions are in `docs/CLOUD.md`. `openapi.yaml` (OpenAPI 3.1) references one JSON Schema (draft 2020-12) per type in `api/schemas/`; `api/examples/<operationId>/` holds request and response examples that both sides use as fixtures. Embedded documents keep their formats: job results are the `.tinglang` `transcript.json` or an English V3 `course.json`.

`packages/tinglang_api` (pure Dart) is the client side: models read leniently (unknown fields ignored, unknown enum values kept and reported as unknown) and write back exactly, `TinglangApi` for the `/v1` endpoints (bearer token from a `TokenSource`, one retry with a fresh token after 401, problem details → `ProblemCode`, Retry-After kept, uploads to presigned URLs without the account token), OAuth 2.1 with PKCE (`signIn` through an `AuthorizationAgent`, `OAuthClient`, `AuthSession` with rotating refresh tokens in a `TokenStore`), and `ServerUrl`, which only accepts https except on this machine. `tool/validate_api.dart` checks the contract itself: the document against the vendored OpenAPI 3.1 schema, `$ref`s, operation ids and path parameters, every schema compiles, every operation has examples and every example validates (formats included); `scripts/check.sh` and CI run it.

### The optional cloud account in the app

- **Native sign-in:** capability `webAuth` (`WebAuthenticator`, spec `web_authentication_session`, macOS only, not a cloud backend itself): `MacWebAuthenticator` → Pigeon `authenticate` → `WebAuthentication.swift` (ASWebAuthenticationSession, shared browser cookies, https or http on this machine only; closing the window becomes `WebAuthCanceled`). `DesktopShell.openUrl` opens website pages in the default browser.
- **Services:** `services/cloud/cloud_services.dart` defines `AccountService` and `CloudJobService`; `CloudClient` implements both over `tinglang_api` for one server, keeps the refresh token in the platform `SecretStore` under `account:<origin>` and signs in through `BrowserAgent` (the system browser session). Creating it sends nothing.
- **State:** `CloudController` reads only cached settings (`cloud_signed_in`, `cloud_meta`, `cloud_account`, `cloud_entitlements` in `app_meta`; never tokens). It contacts the server only when the user signs in, refreshes or signs out — not at startup. Features are on only when signed in and the cached `/v1/meta` says so. Offline, the cached plan stays visible until `grace_until`. The server is the official API, `https://api.tinglang.app` (`CloudController.official`; a development build can use `--dart-define=TINGLANG_SERVER=…`); there is no server field in the app. A session on a server typed into earlier builds is forgotten locally at startup.
- **UI:** the account is at the bottom of the sidebar (`AccountEntry`: "Sign in", or the name and plan) and opens `AccountPanel` in a dialog, labelled `SlBadge.cloud`: sign in in the browser, plan and usage, refresh, manage on the website, upgrade (opens the website's pricing page), sign out. The app takes no payment; buying and managing happen on the website. Errors map from problem codes to the user's language (`describeCloudError`).
- **Tests:** `test/cloud/offline_guarantees_test.dart` runs the whole app with an `HttpOverrides` that counts every `HttpClient` and fails on use: startup, every page and opening the account create none, signed out or with a cached sign-in; with the server unreachable the account shows its cached plan and local work (sample import, settings) goes on. Plus controller, client (local HTTP server, browser fake, Keychain fake, a full job), LLM gateway against the contract examples, and en/zh string parity.

## Network policy

The app makes no network requests in M1. From M5 the only requests are to AI providers the user added and chose for a run (and "Test connection"); local endpoints stay on this Mac. Share packages are files the user exports and sends themselves; there is no sharing server. iCloud Drive sync (opt-in) only reads and writes a local folder; macOS uploads and downloads it. `network.client` is granted for later features (model downloads, YouTube, user-enabled cloud providers); each must ask first or be explicitly enabled, and cloud features are labelled where they run. From 0.4 a Tinglang server is contacted only after the user signs in to it (or signs in, refreshes, signs out); see "The optional cloud account in the app". From 0.5 the app asks GitHub's API for the latest release of `eeeease/TingLang` once a day, starting a minute after launch (on by default; Settings → General says so and turns it off; Check now asks once); the request carries the app version and nothing else. A new version is downloaded, from GitHub only, after the user presses Update and restart; see "Updates".
