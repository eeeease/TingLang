# Verification record

What has actually been run, on which machine, and what has not. A check is listed here only after it ran; anything not run says so. Add an entry for every change that needs checking, with the exact command and its outcome.

Machine: MacBook Pro, Apple M4 Pro, macOS 27.0.1; Xcode 27.1; Flutter 3.47.7 through fvm; Python 3.12. Builds are signed ad-hoc (no Apple team), so macOS asks for permissions again after rebuilds.

## 0.8.4 · the whole official library for signed-in accounts

| Command | Outcome |
| --- | --- |
| `bash scripts/check.sh` | Python checks OK; analyze no issues; app tests 318 (new: signed out the library is the preview, signing in asks an opened library again with the account's token and signing out asks again without; nothing is asked before the library is opened; a failed sign-in from the library is reported; the preview notice gives the full count, a chosen category says how many more it has, and its button signs in); `tinglang_api` 78 (new: the library without a session is the preview and complete with one; a course outside the preview is 401) plus the contract check (15 operations, 19 schemas, 41 examples); other packages as before |
| `fvm flutter build macos --debug` | Built `Tinglang.app` |
| `pnpm exec vitest run` and `pnpm run typecheck` in TingLang-web `workers/api` (contract 1.3.0 copied in) | 54 tests; typecheck clean. New: an app or website token gets the whole index (`private`, `vary: authorization`); no token gets `preview.json`; an invalid, foreign-client or signed-out token gets 401, not the preview; preview courses open without a token, others answer 401 and unknown ids stay 404 |
| `python3 scripts/publish-library.py --dry-run` (TingLang-web), then `index.json` and `preview.json` checked against `schemas/library.json` with ajv, and every course decoded with `OfficialLibrary.fromJson` and `CourseCodec` | 2,118 courses in 18 categories, 26,063 clips, none rejected; preview 54 courses (3 per category); both files valid |

Not run: the deployed Worker; the running app signed in against api.tinglang.app.

## 0.8.3 · YouTube captions off, words and phrases as cards

| Command | Outcome |
| --- | --- |
| `bash scripts/check.sh` | Python checks OK; analyze no issues; app tests 315 (new: words show one card at a time, the small tabs and Previous / Next move between them, Previous is off on the first and Next on the last, phrases keep their own place, no heading above a tab's content); other packages as before |
| `fvm flutter build macos --debug` | Built `Tinglang.app`; it starts |
| The player page of `lib/ui/youtube_player.dart` in the in-app browser on localhost, Steve Jobs' Stanford address, clip 1:10–2:12, with Arabic captions forced on (`cc_load_policy: 1`, `cc_lang_pref: 'ar'`) as a stand-in for a saved caption choice | Before: Arabic captions on the video while playing (the reported bug). `setOption('captions', 'track', {})` left them on. Unloading the captions module on every tick: no captions while playing, after a seek or after the loop back to the clip start; position messages still sent |

Not run: a YouTube course in the running app (WKWebView) with a saved caption choice; the new cards in the running app.

## 0.8.2 · the count by History explained, denser official courses

| Command | Outcome |
| --- | --- |
| `bash scripts/check.sh` | Python checks 33 OK; analyze no issues; app tests 314 (new: with a card due, the count by History says "1 张卡片待复习，点这里复习" on hover, tapping it opens Review, and the panel's history request opens Review instead of Captions); `tinglang_api` 74 plus the contract check; other packages as before |
| `fvm flutter build macos --debug` | Built `Tinglang.app` (the panel's history button now names the due cards in its hint) |
| `build_courses` (compiled, Haiku 5.5) on the 34 videos of 0.8.1 at the new density | 34 of 34 rebuilt in place, one clip per 2 minutes (at most 30): 462 requests, 1,000,073 tokens read from the prompt cache, $0.93. A second run skips them; an older course without a density is rebuilt |

Not run: the panel in the running app with a card due.

## 0.8.1 · official library by interest, captions-first links

| Command | Outcome |
| --- | --- |
| `bash scripts/check.sh` | Python checks 33 OK; analyze no issues; app tests 313 (new: the English caption track chosen from yt-dlp's list, machine captions of other speech refused; machine captions regrouped into sentences with word timings, publisher rows joined to sentence ends, sound tags dropped; a page with captions imported without downloading or transcribing; captions that fail fall back to the audio; Claude's system prompt marked for caching and cache tokens counted and priced; category chips filter the official library, uncategorised courses under Other); `tinglang_api` 74 plus the contract check (15 operations, 19 schemas, 38 examples); other packages as before |
| `fvm dart run tools/llm_demo.dart --preset anthropic --model claude-haiku-5-5 --clips 2` with the user's key | First real provider run of the 0.8 client: 2 clips, 16 items, all quotes verbatim, structured output `schema`, 23 s, $0.005 |
| `swiftc -O tools/official/transcribe.swift`, run on a 21-minute interview | 4,294 punctuated words with timings in 20 s |
| `fvm dart run tools/official/build_courses.dart` (Haiku 5.5, manifest in TingLang-web) | 34 videos in 8 new categories over three runs (a 2-video trial, the batch, one replacement for an age-restricted video that yt-dlp could not read without sign-in): 32 from YouTube captions (10 publisher, 22 machine), 2 transcribed on the Mac. 221 clips, 258 requests; 3,843 tokens written to the prompt cache and 522,356 read from it; $0.51 in all. Every course validated with the strict codec |
| `python3 scripts/publish-library.py --dry-run` (TingLang-web), then the index and every course parsed with `OfficialLibrary.fromJson` and `CourseCodec` | 64 courses in 11 categories; all decode with matching id and YouTube id |

Not run: the upload to R2 and the running app against it; a captioned link imported in the running app.

## 0.8.0 · AI courses on Genkit, clips in parallel

| Command | Outcome |
| --- | --- |
| Research on pub.dev (2026-11-02) | genkit 1.0.1 (Google, Oct 2026, 40k downloads/30 days, plugins for OpenAI-compatible servers, Anthropic, Gemini), dartantic_ai 3.4.2 (Jul 2026, 8.6k), langchain 0.9.0 (Aug 2026, 3.2k; langchain_anthropic 0.4), llm_dart 0.10.7 (Mar 2026, 90 points). Genkit chosen; sources of genkit, genkit_openai, genkit_anthropic, schemantic and both SDKs read for request shape, errors and usage |
| `bash scripts/check.sh` | Python checks 33 OK; analyze no issues; app tests 307 (new: the OpenAI-compatible client steps from `json_schema` to `json_object` with the schema on one line in the system prompt and plain-string messages, remembers it, counts tokens; a model listed without JSON schema starts at `json_object`; chat errors carry the status and never the key; Claude requests carry `output_config`, `max_tokens` 16000, the key only in `x-api-key`, refusals and cut-off replies reported as such; near-verbatim quotes fixed locally, the rest by one small request that asks only for quotes; clips planned at most N at once, in order, stopping after a fatal error; the end-to-end run over HTTP reports provider tokens); other packages as before |
| `fvm dart run tools/llm_demo.dart --base-url http://127.0.0.1:18765/v1 --model fake --clips 3` against a stand-in OpenAI-compatible server (Python, scratch) | 30 sentences, 2 windows, both clips requested at the same time (0.5 s for two 0.4 s answers), a sentence with a dropped word restored from the transcript without a further request, the course validated with the strict codec, `json_schema` used |

Not run: any real provider (needs your key; `tools/llm_demo.dart` is the check); the app's Make course dialog with the new client; a macOS build.

## 0.7.6 · video back, online playback for links, covers

| Command | Outcome |
| --- | --- |
| `bash scripts/check.sh --build` | Python checks 33 OK; analyze no issues; app tests 303 (new: courses made before the rename find their YouTube video again; YouTube ids from the usual page addresses; a link's audio is transcribed in place, nothing is kept in the library and the temporary folder goes; its thumbnail becomes the cover, from a loopback server; a page's stream and headers from a stand-in yt-dlp; link courses carry the YouTube id or the page address and no media; covers: pattern seed per course, reshuffle, chosen picture first and removable, only JPEG/PNG/WebP kept; the card draws its pattern and offers the cover menu); `tinglang_api` 74 plus the contract check (15 operations, 19 schemas, 38 examples); Release and Debug builds |
| A temporary widget test (not kept) | 20 pattern covers rendered and looked at: stripes, waves, rings, rays and tiles in different palettes |
| Read-only query of this Mac's library | 30 of 32 courses carry the video id under the key from before the rename, none under the current one: the cause of the missing video |

Not run: the running app (the YouTube player for those courses, the cover menu, a link course or session streaming); real yt-dlp against Bilibili or other non-YouTube pages for the stream address.

## 0.7.5 · official library

| Command | Outcome |
| --- | --- |
| `bash scripts/check.sh` | Python checks 33 OK; analyze no issues; app tests 294 (new: nothing asked before the tab opens, adding a course with its cover, an update offered for a newer version, covers only from the library server, an unreachable server shown as an error, the cards); `tinglang_api` 74 plus the contract check (15 operations, 19 schemas, 38 examples); other packages as before |

Not run: against the real api.tinglang.app (the endpoints and the upload are not live yet); the tab in the running app.

## 0.7.4 · video links

| Command | Outcome |
| --- | --- |
| `bash scripts/check.sh` | Python checks 33 OK; analyze no issues; app tests 289 (new: yt-dlp offered, downloaded, checked and made runnable only when asked, against a loopback GitHub; a bad checksum is not kept; only allowed hosts; a fake yt-dlp script for reading a page, fetching the audio, transcribing it as a `link` session; not-a-link, live and unsupported pages; the dialog's link field) |
| A temporary integration test (not kept) on this Mac, temporary library | Real yt-dlp 2026.10.26 from GitHub (37 MB, SHA-256 checked, 2 s); YouTube "Me at the zoo": title and length read, audio only downloaded, transcribed by Apple SpeechTranscriber into 4 correct lines, a Basic course made, 16 s in all |

Not run: the dialog's buttons in the running app; sites other than YouTube; a long video.

## 0.7.3 · choosing the languages, no translation-pack prompt

| Command | Outcome |
| --- | --- |
| `bash scripts/check.sh --build` | Python checks 33 OK; analyze no issues; app tests 283 (new: the first start asks for the languages and the mark menu changes them, the language dialog saves and lets captions start, a missing pack never shows on the panel); packages as before; release build 172.6 MB (the Swift menu compiles without warnings); `integration_test/app_test.dart` 1 passed, 2 skipped |

Not seen on screen: the Recognise and Translate into submenus of the panel's mark (native SwiftUI menu), and macOS's own translation-pack download sheet opened from the dialog.

## 0.7.2 · course generation, renaming, the panel under the Dock, Voice Memos access

| Command | Outcome |
| --- | --- |
| `bash scripts/check.sh --build` | Python checks 33 OK; analyze no issues; app tests 281 (new: untitled captions give a course title, a cloud provider without a key sends nothing, renaming from History, Voice Memos "Check again" says the folder is still closed); packages as in 0.7.1; release build 172.5 MB; `integration_test/app_test.dart` 1 passed, 2 skipped |

- Basic and AI courses from live captions failed with `FormatException: title must contain 1–2000 characters`: live sessions are saved untitled. The course now takes the session's name, else its first sentence, else the date.
- An AI course with no key in the Keychain sent the request without one (`x-api-key header is required (HTTP 401)`). It now stops before sending and says to enter the key again in Settings → AI services.
- The panel could be dropped under the Dock, which then hid it and took its clicks. Letting go, starting the app and a change of displays or the Dock now bring it fully into the visible area. Compiled in the release build; not dragged by hand on a real screen.
- Voice Memos: macOS never lists an app under Full Disk Access by itself. The dialog now says to add TingLang with + (with "Show TingLang in Finder" to drag it), says so when "Check again" still finds the folder closed, and offers "Quit and reopen". Reveal and relaunch are faked in tests; not run in the real app.

## 0.7.1 · captions from downloaded and cloud models start again

A user on macOS 15.6 got `Bad state: No usable microphone backend` with the microphone allowed. The portable pipeline (every downloaded or cloud model, so all of macOS 14.2–15) refused capture unless the probe said the permission was granted: the probe never reports system audio recording (macOS cannot be asked), and an ad-hoc build that macOS has not asked yet reads "not determined". Nothing asked macOS, so captions from that pipeline could not start.

| Command | Outcome |
| --- | --- |
| A temporary integration test (not kept) on this Mac with the real probe | Before: `systemAudio → none; coreaudio_tap: NeedsPermission(systemAudio)`. With `pickCapture`: the Core Audio tap and the microphone (probe "not determined") both opened and ran for 2 s |
| `bash scripts/check.sh` | Python checks 33 OK (release rules: every version is released); analyze no issues; app tests 278; `tinglang_platform_interface` 53; `tinglang_api` 68; `tinglang_cloud_asr` 118; `tinglang_ui` 4; `tinglang_native` 74; `tinglang_native_macos` 27 |

Not run: a macOS 14.2–15 Mac; captions from a downloaded model with real system audio end to end; the microphone question and the System Settings button in the running app.

## 0.7.0 · first-start guide and update arrow

| Command | Outcome |
| --- | --- |
| `bash scripts/check.sh --build` (before the version commit, so the build says 0.6.1) | Python delivery checks 33 OK; `flutter analyze --no-fatal-infos` no issues; app tests 275 passed (new: `test/onboarding_test.dart`, the arrow in `test/shell_test.dart` and `test/update/update_widgets_test.dart`); `tinglang_platform_interface` 51; `tinglang_api` 68 plus the contract check; `tinglang_cloud_asr` 118; `tinglang_ui` 4; `tinglang_native` 73 (9 skipped); `tinglang_native_macos` 27; release build `Tinglang.app` 172.4 MB, literal usage strings, `codesign --verify` (ad-hoc); `integration_test/app_test.dart` 1 passed, 2 skipped |
| A temporary integration test (not kept) driving `TinglangApp` on this Mac with the real platform, a temporary library, `onboarding = pending` and a cached release 0.7.0 | 1 passed; screenshots checked by eye: the guide's three steps, the cloud choice, Skip, Show again, the arrow on the mark and the update dialog, light and dark, Chinese and English. Its first run found the arrow taking no clicks (below) |

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
| In-app updates | The green arrow on the mark and the update dialog opening from it, rendered by the app on this Mac with a cached newer release (no download). Tests only: release parsing, versions, host checks; a loopback fake GitHub (404/403/429/5xx, no connection, bad JSON, prereleases: silently nothing); download → size and SHA-256 → `ditto -x -k` → Info.plist check; the install script against fake folders (swap, roll-back, give-up); nothing requested at startup. The real endpoint answers 404 while the repository is private, and the app shows nothing | A real update: downloading from GitHub, replacing the running app and reopening it |
| TingLang account | Tests only: the contract and client, sign-in against a local server with a fake browser, the sidebar entry and dialog, and the whole app proving it opens no connection before sign-in | Signing in to `api.tinglang.app` through the system sign-in window; plans and usage from the real server |
| Main window and Settings | Sections, grouped history, the seven Settings tabs, light/dark switching, closing keeps the app and panel running | — |
| First-start guide (0.7) | Rendered by the app on this Mac from a temporary library (light Chinese, dark English): the three steps, the real probe's permission states, Apple Speech recommended and ready on macOS 27, the cloud choice, Skip, Settings → General → Show again; widget tests for the microphone question, the System Settings links (faked), the download question with no request, the outcome and the `onboarding` value | Pressing Allow for the microphone and the System Settings links in the running app; a real first start of the release build without a data folder; a model download started from the guide; macOS 14.2–15 |
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
- 0.7: the update arrow was first drawn partly outside the box of the sidebar's mark, and Flutter takes no clicks outside a widget's parent: clicking it in the real app did nothing. The arrow now sits inside the mark's box (`test/shell_test.dart` clicks it where it is drawn).
- 0.7: on a Mac where every local model still needs a download (macOS 14.2–15), "automatic" resolved to nothing, so the guide would have recommended no model; `SpeechModelService.automaticModel` now names the model starting captions would offer to download, as `LiveController` does.

## Not verified yet

Any cloud speech service, sign-in or plan against a real server, a real in-app update, iCloud Drive between two Macs, opening packages from Finder, the panel with a real mouse, the microphone with a real voice, Developer ID signing and notarisation (builds are ad-hoc), Intel Macs, macOS 14.2–15 hardware and Windows.

Measurements of the speech models are in `docs/perf/`.
