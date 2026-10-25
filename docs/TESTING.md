# Test plan

This file describes tests to run, not evidence that they have run. Evidence belongs in VERIFICATION.md.

## Automated checks

```bash
bash scripts/check.sh            # everything below
python3 -m unittest discover -s tools/tests -v
python3 tools/validate_course.py assets/demo/course.json
fvm flutter pub get
fvm flutter analyze --no-fatal-infos
fvm flutter test
for p in packages/tinglang_platform_interface packages/tinglang_ui packages/tinglang_native_macos; do (cd "$p" && fvm flutter test); done
```

Python checks exercise a supplemental course validator, example WAV bounds, asset dimensions, native config idempotence, source-file policy and shell dry-run/syntax. They do **not** execute the Flutter UI, the Dart course parser, the microphone or the native media player.

Flutter tests exercise course/timestamp/subtitle parsing, preservation of original metadata, reversible blanks, source evidence, state backup/corruption paths, copy/deduplication, reimport preservation, queued saves, failed-save retry, FSRS review, SQLite migrations against committed snapshots, live captions and the floating panel through fakes (phases, setup downloads, translation packs, settings sync, drops), file import and transcription, share package round trips and refusals, Voice Memos (service and list dialog), and the main window's sections. Package tests cover backend selection (every catalog spec, fake probes for macOS 14.2/26 and Windows), panel event mapping and the Voice Memos index reader against generated databases. Player/recorder plugin behavior is not mocked into a full integration suite; `integration_test/` runs on a real Mac.

## macOS smoke test

Run `bash scripts/run_macos.sh` on a fresh clone. The first preparation must produce a runner without altering `lib/` or replacing `pubspec.yaml`. On launch only the floating panel appears; its History button (or the Dock icon) opens the main window, which has no title bar strip. A fresh library is empty, with no login screen.

### A. Bundled original sample

Load the example via Library, then open its three clips. Confirm:

1. Each starts at its displayed absolute offset, including clips two and three.
2. Playback pauses at the end when loop is off; returns to the clip start when loop is on; the final clip also loops at EOF.
3. Rapid A→B→A clip switching does not play the wrong range or file.
4. Speed control, seek slider and subtitle cue jumps work.
5. Subtitles start hidden; Phrases and Sentences show source-linked learning items; Words has an explicit empty state.
6. Blind exercises reveal answers only after the corresponding action. Exact matches ignoring whitespace/case/end punctuation are accepted.

### B. Microphone and saved practice

First deny microphone permission: error must be visible, no successful attempt may be recorded, and navigation must unlock. Enable it in macOS privacy settings, then retry.

Record a short shadowing attempt, stop/save, and replay it. Repeat with a retelling attempt and a free Speak recording. Confirm the correct recording opens, original playback pauses before recording, and simultaneous players are not heard. Try navigating and quitting while capture is in progress: normal exit should be cancelled with an explanation. Never use important recordings for the first trial.

### C. Persistence and update

Save text notes, tick one completed step, and bookmark an expression. Exit normally, reopen, and confirm all are retained. Reimport the same `assets/demo/course.json` without choosing new media: no duplicate course, prior media association, attempts, drafts, bookmarks and completion stay intact.

Use a copied fixture for a course revision that removes a clip. The old attempt/card should still exist, and “back to source” should explain the missing clip rather than crash. Force-kill is a separate stress test, not an expected no-loss guarantee.

### D. Your own media

Import one authorized local video and its SRT or VTT, then one audio-only file. Test filenames with spaces and Chinese characters. After import, move the original selected file outside the app's folder and restart: the copied local media should still play. Try pairing a long-course timestamp with a short already-cut file: show a mismatch instead of claiming a valid alignment.

### E. Floating panel

Play English speech in any app (a video, or `say` in Terminal), press the panel's record button with System audio selected, and confirm captions and translations appear in the panel. Stop: the saved summary offers View (opens the session) and Make course. Open Appearance (the palette or ··· menu): switch to text only with a clear background, change colours and size, lock it (clicks pass through; hovering shows Unlock), then reset its position from Settings. Hide it from the ··· menu: the setting turns off and the next launch opens the main window. Drop an audio file on the panel and on the main window: an import appears at the top of History.

### F. Voice Memos and sharing

Open History → Voice Memos without Full Disk Access: the list explains how to grant it. Grant it in System Settings, reopen the app, and confirm today's recordings are listed and selected; import one and check it appears under the day it was recorded, titled as in Voice Memos. Relaunch: the banner and the panel's chip show only recordings not imported yet. Export a session (share button on its page) and a course (share button on the Learn page) as `.tinglang`, then import them under Library → Shared on a second user account or a copy of the data folder.

### G. Review, export, errors

Check recall scheduling for Again/Hard/Good/Easy; reopen to confirm due times persist. Export Markdown, cancel an export, and open the Settings data directory in Finder. Export must leave recordings in place. Backup the whole directory before experimenting with a damaged `library.json` or `tinglang.sqlite`; loading a broken file must not erase or silently replace it. Recover manually from the backup only with the app closed and after keeping copies of both files.

## Release validation

```bash
bash scripts/check.sh --build
open build/macos/Build/Products/Release/Tinglang.app
```

Repeat media, microphone, file import and app restart checks in release mode. Debug success alone does not validate the release entitlements or native bundle. Inspect the built dependency licenses before redistribution. Developer ID distribution and notarization are not configured.

## Reporting a failed build

Record Flutter version, macOS version, chip architecture, Xcode version, exact command and the **first meaningful error**, not only the final exit code. Do not attach `tinglang.sqlite`, `library.json`, private recordings, tokens or your whole private repository to a public issue.
