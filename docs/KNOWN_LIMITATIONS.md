# Known limitations · TingLang 0.6

## Not yet verified

See VERIFICATION.md for what actually ran. Not executed yet: live captions from a downloaded sherpa model with real system audio or the microphone in the running app (0.4; the PCM ring path ran from a file source), the panel's download states on screen, the Windows sherpa build, importing real Voice Memos (needs Full Disk Access, which only the user can grant), dropping files on the panel or the main window in the real app, the Dock menu items, microphone capture from the panel, exporting and importing a `.tinglang` file through the system dialogs, opening one from Finder or the Dock, iCloud Drive sync between two real Macs, a release build's start-up time, an in-app update from a real release (download, swap and relaunch); any Windows build (the C++ plugin has never been compiled); Developer ID signing or notarization (builds are ad-hoc).

## Product limits

- macOS first. On macOS 26+ live captions and file transcription use Apple's recognisers by default; on macOS 14.2–15 they use a downloaded sherpa-onnx model (the app asks before the first download). There is no Windows panel yet, and the Windows build of the sherpa pipeline has not been compiled.
- The Dock icon is the flat PNG set. The macOS 26 Liquid Glass icon (an Icon Composer `.icon` built from `assets/brand/icon-composer/`) has not been made yet.
- The TingLang account signs in to `api.tinglang.app`. Sign-in has been tested only against a local test server with a fake browser; the system sign-in window and the real server have not been driven from the app yet. TingLang's own cloud jobs and LLM gateway are not offered yet ("coming soon"). There is no sign-in on Windows.
- Discover is a placeholder. Community sharing has no server yet; the Shared tab imports `.tinglang` files that someone sends you.
- Only English and Simplified Chinese interface strings. Some parser and native error details are still English technical text.
- No pronunciation scores or conversation bot. AI course generation only uses providers you add yourself (BYOK); the basic course needs no network.
- No downloads from YouTube, Twitch or streaming sites; YouTube clips play in the official embedded player.
- Six preset Areas; no custom Area editor. Course title and Area change by reimporting the same course ID.
- Saved sessions can be deleted; courses and copied media cannot be removed in the app yet, so unused media can accumulate after cancelled imports.
- The Markdown export is not a backup; there is no backup import. Back up the data folder instead (Settings → Data).
- The stage-complete checkbox is self-reported, not a measure of fluency. Review uses FSRS-6 with default parameters (no per-user optimisation yet).

## Share files and iCloud Drive sync

- Not yet verified on a real Mac: opening a `.tinglang` file by double-click, Open With or a drop on the Dock icon (the Info.plist declarations and the plugin's queue are built and unit-tested; the round trip through Finder and LaunchServices was not driven); the document icon macOS generates; real iCloud Drive syncing between two Macs (the engine is tested with two simulated Macs sharing one folder, placeholders and "not downloaded" states are simulated); the iCloud Drive access prompt macOS may show the first time (`NSFileProviderDomainUsageDescription`).
- Why no CloudKit or iCloud container: those need an iCloud entitlement, which needs a paid Apple developer account and a provisioning profile; builds are ad-hoc signed. Sync therefore uses the user's own iCloud Drive folder, which any non-sandboxed app can read and write, and macOS does the transfer. The files are visible (and deletable) in Finder under iCloud Drive › Tinglang; deleting files there by hand never deletes anything in a library, but another Mac may then miss what only that folder held.
- Sync needs iCloud Drive turned on for the same Apple Account on each Mac, and "Optimize Mac Storage" can leave files only in iCloud: Tinglang asks macOS to download them and adds them when they arrive ("waiting for iCloud"). Without a network nothing arrives, but local work goes on.
- Not synced: settings (interface language, theme, panel look, speech models, latency), AI provider settings and API keys (Keychain), the LLM cache, downloaded speech models. Sessions still recording or transcribing, failed imports and YouTube/recording-only sessions are not synced. Time anchors are not exported.
- Conflicts are last writer wins per record, by each Mac's clock: a Mac whose clock is far off can win or lose wrongly. A card reviewed on two Macs before they synced keeps only the later review (the other review is not merged into its history); the same draft edited on two Macs keeps the later text. Changes made while sync is off count as made when it is turned back on. When a library is synced for the first time, its drafts and progress give way to what other Macs already have.
- Each item is a self-contained package with its media, so a course made from a recording stores the same audio twice in iCloud Drive, and renaming a recording uploads its package (with media) again. Large videos take iCloud space and upload time; there is no size limit or per-item choice yet.
- Tombstones are kept for good (they are small); deleting things in the app is the only way to remove them from other Macs. Courses cannot be deleted in the app yet, so only recordings, progress, drafts and cards are deleted through sync in practice.
- Two Macs must not use the same device folder: a library copied to another Mac (Migration Assistant, a backup) is detected by the Mac's hardware id and gets a new one; on a Mac without that id the copy would keep the old one.

## Speech models

- Downloaded models (sherpa-onnx) come from k2-fsa's GitHub releases and Hugging Face, pinned by size and SHA-256. A publisher can replace a release file under the same name; the download then fails its checksum ("the publisher may have changed the file") until Tinglang's catalog is updated. There is no mirror setting, no proxy support and no disk-space check before a download.
- The X-ASR packs are only published as `.tar.bz2` archives: the whole archive is downloaded (about 135 MB each) and needs room for the archive and the extracted files briefly. Extraction uses the system `tar`.
- The two Zipformer English models were trained on LibriSpeech (read audiobooks): they write capital letters without punctuation and are weaker on conversation and noise. They are offered for low CPU and early captions, not accuracy.
- Translation of captions from a downloaded model needs Apple Translation, so on macOS 14.2–15 captions are not translated. Word timings from sherpa models are token timestamps from the model; a word's end is the next word's start (or the line's end).
- Apple's accents and Dictation are system assets that macOS downloads and may remove; "Remove" only gives the asset back to macOS. Apple does not report their size before downloading.
- The latency tier mostly changes how early words appear and when a line ends, not how hard the recogniser works: measured on an M4 Pro, Apple Speech uses 3–4% CPU on every tier, and a second sherpa thread only added CPU, so every tier uses one (docs/perf/asr-latency-2026-10.md). `ignoresResourceLimits` exists only on macOS 27+.
- Downloaded models use about 13–16% of one core while captioning (measured in the benchmark harness, whole process), several times Apple Speech; about 6–7 points of that are outside the recogniser and have not been profiled yet. Apple Dictation uses about 11% and is less accurate than Apple Speech for captions; its lines can still end up to ~10 s late (p90).
- Model choice is per Mac (settings in the library), not per session; changing it during a live session applies to the next one.

## Cloud speech services

- The six adapters (Tencent Cloud, Alibaba Cloud Model Studio, iFlytek, Soniox, AssemblyAI, Azure AI Speech) follow each service's published documentation and are tested only against loopback servers that behave as documented (signatures against the documentation's examples where it has them). None has been run against the real service: that needs your own key. Each `packages/tinglang_cloud_asr/doc/<id>.md` says what was checked and what was not.
- Keys are your own (bring your own key); prices, free quotas and activation are the service's. Tinglang cannot see your balance; an exhausted quota shows up as an error when captions or a transcription start.
- Live captions in the cloud depend on the network. While reconnecting, up to 30 s of audio waits and is sent afterwards; longer outages leave a gap in the transcript. Audio already sent on a connection that then fails may not be recognised.
- Cloud mode is one choice for live captions and files; a service without one of them leaves that one to the local model. Translation of cloud captions still uses Apple Translation (macOS 15+).
- Long files are cut into pieces at quiet moments; a sentence that spans a cut may be split in two.

## Floating panel

- The look (mode, colours, size, lines, lock) is one set per Mac, not per display. The panel stays where it was dragged; Settings → Live captions → Reset position brings it back.
- In text-only mode with a clear background, the toolbar only appears while the pointer is over the captions; a locked panel passes clicks through and shows an unlock chip on hover (the Dock menu can also unlock).
- With the panel hidden (Settings → Show the floating panel), the main window opens at launch instead; starting captions (⌘⇧T) brings the panel back.
- The panel scrolls back through the current session only, up to the number of lines chosen in Settings (50 to 500). Earlier lines and earlier sessions are in History; the scroll-back empties when captions stop.
- The caption area's height is the chosen number of rows at the chosen size; a line that wraps takes more room, so fewer whole lines show at once and the rest is a scroll away.
- Side by side pairs each line with its translation; a line whose translation has not arrived leaves its right side empty. Translation on/off and centring do not apply to it.
- The lock only acts while captions run; the idle pill always takes clicks.

## Voice Memos

- Reading the library needs Full Disk Access (System Settings › Privacy & Security). macOS asks you to quit and reopen after granting it. Debug builds are ad-hoc signed, so macOS forgets the grant after every rebuild; a Team ID in `Local.xcconfig` keeps it.
- Recordings that are only in iCloud must be downloaded in Voice Memos first. Recently deleted recordings are not listed.
- New recordings are found when the app starts or comes back to the front (after the list has worked once), not by watching the folder. Only today's recordings are flagged as new.
- The library's format is Apple's private Core Data store; a future macOS may change it. The app then says it cannot read the library rather than guessing.

## Import and playback cautions

UTF-8 JSON/SRT/VTT is expected. A JSON file is limited to 20 MB in the UI (and inside share packages). Extension checks are not a promise that every codec inside each container decodes; MKV/WebM/Ogg are refused before copying because AVFoundation cannot read them. Course clips refer to the complete source file; there is no automatic timeline adjustment for already-cut media. Most existing English courses provide clip-level, not sentence-level, timing. Only explicit cue timestamps are clickable.

Player boundary handling uses streams; exact timing, rapid source-switch races and rate-specific behaviour still need native tests. External source URLs are kept as unknown JSON metadata but never downloaded. Not every teaching-rule constraint from English's Python compiler/validator is implemented by the importer.

## Persistence cautions

Writes are queued and each change is one SQLite transaction, but a power failure, forced termination, disk-full condition or native recorder crash is not a guaranteed recovery path. A stopped but unindexed recording can remain in `recordings/`; do not remove such files without inspection. Sessions that were capturing or importing when the app stopped are marked interrupted on the next launch.

Only one app instance should write a library. The data folder is `~/Library/Application Support/dev.eeeease.tinglang/Tinglang/`.

## Updates

The update check reads the GitHub Releases of `eeeease/TingLang`. While the repository is private, GitHub cannot be reached or the unauthenticated rate limit (60 requests an hour per address) is used up, the app quietly finds no update. Only X.Y.0 versions are published as releases, so patch versions are never offered. The download is checked against the `.sha256` file of the same release and the bundle's identifier and version, not against a signature: builds are ad-hoc signed, so there is no Developer ID to compare. The app replaces itself only where the user may change the folder that holds it (usually `/Applications` for an administrator); a standard account, a disk image and App Translocation get the release page instead. If the app stops between moving the new copy next to itself and starting the script, a hidden `.tinglang-update-*` folder stays next to the app and can be deleted.

## Build and distribution cautions

Direct package versions are pinned and `pubspec.lock` is committed. Flutter 3.47.7 and macOS 14.2 are the build targets (see VERIFICATION.md). Newer Flutter versions may change the generated runner; `configure_macos.py` fails loudly if the Xcode project layout it patches is not found. Bootstrap refuses partial runners rather than overwriting them.

Library validation is disabled under Hardened Runtime because media_kit's prebuilt frameworks are signed by another team; re-signing them for Developer ID builds (M9) should allow re-enabling it. No signing identity, Apple account, certificate or notarization credential is embedded. The source lives at `github.com/eeeease/TingLang`; GitHub Actions runs both jobs (Linux and macOS on the `xcode-27` image); its macOS runners are virtual machines without the system speech recogniser, so live captions with Apple Speech are only checked on a real Mac.
