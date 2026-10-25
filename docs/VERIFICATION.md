# Verification record

What has actually been run, on which machine, and what has not. A check is listed here only after it ran; anything not run says so. Add an entry for every change that needs checking, with the exact command and its outcome.

Machine: MacBook Pro, Apple M4 Pro, macOS 27.0.1; Xcode 27.1; Flutter 3.47.7 through fvm; Python 3.12. Builds are signed ad-hoc (no Apple team), so macOS asks for permissions again after rebuilds.

## 0.6.0 · full check

| Command | Outcome |
| --- | --- |
| `bash scripts/check.sh --build` | Python delivery checks 33 OK; `flutter analyze --no-fatal-infos` no issues; app tests 266 passed; `tinglang_platform_interface` 51; `tinglang_api` 66 plus the contract check; `tinglang_cloud_asr` 118; `tinglang_ui` 4; `tinglang_native` 73 (9 skipped: real-model, real-archive and network tests need opt-in); `tinglang_native_macos` 27; release build `Tinglang.app` 172.3 MB, version 0.6.0, `CFBundleName` TingLang, literal usage strings, `codesign --verify` (ad-hoc) |
| `fvm flutter test integration_test/app_test.dart -d macos` | 1 passed in the real app process (Pigeon probe; on macOS 26+ the native pipeline is the default; the shell renders; the sample course loads), 2 skipped (they need local speech models and the test capture flag) |
| `fvm flutter test integration_test/screenshots_test.dart -d macos --dart-define=TINGLANG_SCREENSHOTS=$PWD/docs/screenshots` | 1 passed: the README screenshots (`docs/screenshots/{en,zh}`) rendered by the app from a temporary library; no layout errors |

## By feature

| Feature | Checked on a real Mac | Not checked yet |
| --- | --- | --- |
| Live captions (system audio, macOS 26+) | Core Audio tap → SpeechTranscriber → Apple Translation → panel and SQLite with a 520-word synthetic speech file played for 120 s: 23 final lines with Chinese translations, WER 2.4 % against the source text; about 14.5 % of one core in total (app, speech service, translation, Core Audio) | Microphone source with a real voice; the ScreenCaptureKit fallback; a 60-minute session; headphone and device switches |
| Downloaded speech models (macOS 14.2+) | In the real app process: Swift decoded a WAV and Parakeet transcribed it in a worker isolate; the live path played a WAV in real time into the native PCM ring and X-ASR produced partials and finals; downloads, checksums, resume and archives against a local server; Silero VAD over the network | Live captions from a downloaded model with real system audio; the large packs through the app's downloader; macOS 14.2–15 hardware |
| Cloud speech services | Tests only, against loopback servers that follow each service's documentation (signatures against the documentation's examples where it gives them): Tencent Cloud, Alibaba Cloud Model Studio, iFlytek, Soniox, AssemblyAI, Azure AI Speech; the live relay (reconnects, buffered audio, gaps, refused keys) and file pieces in worker isolates; Settings, Keychain storage and "never fall back silently" in the app's tests | Any real service (needs a key); see each `packages/tinglang_cloud_asr/doc/<id>.md` |
| Floating panel | States, appearance, text-only mode, fixed-size scrolling captions, scroll-back, side by side (short translations aligned with the last English line), the lock, moving the panel, the round menu button and hover hints that show while another app is in front — driven by a harness around the panel's Swift code (own process and windows, simulated hover, captured to images; the real pointer was never moved) | A real mouse or trackpad on the running app; a second display; VoiceOver |
| File import and transcription | A 126 s podcast excerpt (MP4) transcribed in 5 s: 15 lines with word timings and translations, WER 4.6 % | Cancel during a long import; a 60-minute file |
| Session page and dictation | Video and player, speed, A–B loop per sentence; dictation with real keyboard input (word diff, advancing, attempts saved); the volume slider and mute rendered in the screenshots | Changing the volume by hand while playing |
| Courses | Basic course from a 126 s session in under 1 s; AI course with Anthropic Claude (cost matching the estimate, consent required, key only in the Keychain) | The other provider presets against their services |
| Learn and review | Blind listening, quiz → review, FSRS-6 ratings stored with stability and difficulty; FSRS matches py-fsrs 6.3.2 on four sequences (unit test) | Again → relearning in the app |
| Voice Memos | Reader tested against generated `CloudRecordings.db` files; without Full Disk Access the app explains how to grant it and reads nothing | Listing and importing real recordings |
| TingLang packages (`.tinglang`) | Round trips and refusals in tests; the built app declares the type and the document type; opened files are queued and imported in tests | Opening a package from Finder, Open With or the Dock; the generated document icon; export through the system dialog |
| iCloud Drive sync (opt-in) | Tests only: two simulated Macs sharing one folder (add, update, conflict, tombstone, placeholder and not-downloaded files, corrupt and newer packages, no network), the service's triggers and states, the Settings panel | Real iCloud Drive between two Macs; the iCloud Drive access prompt; folder watching on iCloud |
| In-app updates | Tests only: release parsing, versions, host checks; a loopback fake GitHub (404/403/429/5xx, no connection, bad JSON, prereleases: silently nothing); download → size and SHA-256 → `ditto -x -k` → Info.plist check; the install script against fake folders (swap, roll-back, give-up); nothing requested at startup. The real endpoint answers 404 while the repository is private, and the app shows nothing | A real update: downloading from GitHub, replacing the running app and reopening it |
| TingLang account | Tests only: the contract and client, sign-in against a local server with a fake browser, the sidebar entry and dialog, and the whole app proving it opens no connection before sign-in | Signing in to `api.tinglang.app` through the system sign-in window; plans and usage from the real server |
| Main window and Settings | Sections, grouped history, the seven Settings tabs, light/dark switching, closing keeps the app and panel running | — |
| Windows | — | The C++ plugin has never been compiled |
| CI | GitHub Actions: the Linux job (pure Dart packages, generated code up to date) and the macOS job (`check.sh --build`) on the `xcode-27` image. Its runners are virtual machines without the system speech recogniser, so the integration test checks Apple Speech strictly only on a real Mac | — |

## How the panel is checked without touching the desktop

The panel's Swift files are compiled into a small harness that runs in its own process with its own windows, never takes focus from the app in front, simulates hover and clicks inside its own event queue and captures only regions covered by its own background window. Renders are compared with the previous version (stacked layout pixel-identical; only the translation column moved in side by side). Nothing in this record was driven by synthetic input on the user's desktop.

## Problems found while verifying (and fixed)

- Hardened Runtime refused media_kit's frameworks (signed by another team): library validation is disabled in the runner configuration.
- `file_picker` refused to open dialogs without the user-selected file entitlement.
- SpeechTranscriber can return finals up to about 22 s long; dictation splits lines into sentences by word timings.
- `AssetInventory.status` reported "supported" for an installed model; a missing install request now counts as installed.
- A `FlutterViewController` does not start Dart until its window shows; the runner starts a headless-capable engine itself.
- Quitting could crash while closing SQLite on a worker; the database closes in the exit handler.
- A build started while tests ran failed with "requires minimum platform version 14.2 … supports 12.0": Flutter reads the deployment target from `xcodebuild -showBuildSettings`, which did not answer in time. Build alone.
- macOS cannot launch the app twice in one integration run, so each integration test file runs on its own.
- SwiftUI's `.help` tooltips do not appear while the app is in the background, which is how the panel is used; the panel draws its own hints.
- The English accent picker overflowed with system fonts; long dropdown labels now shrink.

## Not verified yet

Any cloud speech service, sign-in or plan against a real server, a real in-app update, iCloud Drive between two Macs, opening packages from Finder, the panel with a real mouse, the microphone with a real voice, Developer ID signing and notarisation (builds are ad-hoc), Intel Macs, macOS 14.2–15 hardware and Windows.

Measurements of the speech models are in `docs/perf/`.
