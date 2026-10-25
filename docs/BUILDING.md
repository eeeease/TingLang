# Building Tinglang from source

There are no signed downloads yet, so building from source is the way to run Tinglang. What has actually been built and checked, and on which versions, is recorded in [VERIFICATION.md](VERIFICATION.md).

## 1. Get the source

```bash
git clone git@github.com:eeeease/TingLang.git
cd TingLang
```

## 2. Toolchain

The project pins **Flutter 3.47.7 / Dart 3.13.x** in `.fvmrc`; install it with [fvm](https://fvm.app) (`fvm install`). The app needs **macOS 14.2** or later (live captions use a Core Audio process tap).

You need fvm (or the same Flutter version), full Xcode 26 or later (the Command Line Tools alone are not enough; the speech APIs need the macOS 26 SDK; verified with Xcode 27) and Python **3.10+**. Flutter 3.47 uses Swift Package Manager; CocoaPods is only used for plugins that still ship podspecs (media_kit). The first setup needs the network to resolve dependencies (the sqlite3 build hook downloads a prebuilt SQLite); no learning material is uploaded. Direct dependencies are pinned in `pubspec.yaml`, the full set in `pubspec.lock`.

```bash
fvm flutter --version
fvm flutter doctor -v
xcodebuild -version
python3 --version
```

Fix the Xcode and macOS items of `flutter doctor -v` first; see [Flutter macOS setup](https://docs.flutter.dev/platform-integration/macos/setup). After upgrading Flutter, run the full checks again: a newer version is not the same as a verified one.

**Signing.** Builds are signed ad-hoc ("Sign to Run Locally") by default. To sign with your own Apple Development certificate, so that macOS stops asking for permissions again after every rebuild, copy `Local.xcconfig.example` to `Local.xcconfig` in the repository root (ignored by Git), set your Team ID and run `bash scripts/bootstrap_macos.sh` again.

## 3. Run

```bash
bash scripts/run_macos.sh
```

The script generates a standard macOS runner in a temporary folder with the Flutter SDK from `.fvmrc`, copies only the platform folder, applies the Tinglang name and icon, the microphone and system-audio usage strings (English and Simplified Chinese), App Sandbox off, Hardened Runtime on, outgoing network, macOS 14.2 and the desktop window setup, then starts the app. It does not touch `lib/` or `pubspec.yaml`, and does not read any old repository.

After the first run you can use:

```bash
fvm flutter run -d macos
```

`macos/` is generated and not committed. Native customisation lives in `scripts/native/` and `scripts/configure_macos.py`; after changing them, run `bash scripts/bootstrap_macos.sh` again instead of editing the generated files.

## 4. Checks and release build

```bash
# Checks that run without Flutter
python3 -m unittest discover -s tools/tests -v
python3 tools/validate_course.py assets/demo/course.json

# Dependencies, static analysis, Flutter and package tests
bash scripts/check.sh

# On a Mac: also a release build and an integration test on macOS
bash scripts/check.sh --build
```

Static analysis is `flutter analyze --no-fatal-infos`: errors and warnings stop the run, style infos are shown but do not. The app tests and the tests of each package in `packages/` follow. `--build` also checks `NSAudioCaptureUsageDescription` in the built Info.plist and verifies the signature. Without Flutter the script exits with code 2 and says that the Dart/Flutter checks did not run; Python checks are never presented as a passing app build.

Record every real run (Flutter and Xcode versions, results) in `docs/VERIFICATION.md`. `.github/workflows/ci.yml` has a Linux job (pure Dart packages, generated code up to date) and a macOS job (`check.sh --build`) on GitHub's `xcode-27` image, which matches the machine in `docs/VERIFICATION.md`. Older macOS images fail to compile: their SDKs lack the macOS 26 speech APIs.

The release build ends up at:

```text
build/macos/Build/Products/Release/Tinglang.app
```

There is no Developer ID signing, notarization or App Store distribution yet.

## 5. Versions and releases

The version lives in `pubspec.yaml` (`version: X.Y.Z+N`, N is the build number macOS shows as the bundle version). `lib/app.dart` repeats it as `appVersion` for the sidebar and About; `test/version_test.dart` and the release workflow fail if the two differ. Tags are `vX.Y.Z`. One command sets everything:

```bash
bash scripts/bump_version.sh minor   # 0.4.0 → 0.5.0; also patch, major or X.Y.Z
```

It needs a clean working tree, writes both files (build number + 1), commits `release: X.Y.Z` and makes the annotated tag `vX.Y.Z`, then prints the push command, which sends the commit and the tag together:

```bash
git push --atomic origin main vX.Y.Z
```

`.github/workflows/release.yml` runs when a push to `main` changes `pubspec.yaml`:

| Version | What happens |
|---|---|
| any new `X.Y.Z` (patch, minor or major) | Creates the tag on the pushed commit if it is missing, runs `scripts/check.sh --build` on the `xcode-27` image, packs the app with `ditto` into `Tinglang-X.Y.Z-macOS.zip`, writes its SHA-256 and publishes a GitHub Release with the notes from `.github/release-notes.md` and the commit subjects since the previous version's tag. The in-app updater offers it from then on. |
| unchanged | Nothing (the tag and the release already exist). |

Pushing a tag on its own does not start a release. To publish an older tag (such as `v0.6.1`, from before every version was released) or to rebuild an existing release, run the workflow by hand (Actions → Release → Run workflow) with the tag.

Builds are signed ad-hoc, not with a Developer ID, and are not notarised, so macOS asks users to allow the app once; the release notes explain how. Signing and notarisation need an Apple Developer account and secrets in the repository; see KNOWN_LIMITATIONS.
