## Install · 安装

1. Download `Tinglang-{VERSION}-macOS.zip` below, unzip it and move **Tinglang** to Applications. macOS 14.2 or later, Apple silicon and Intel.
2. This build is **not signed or notarised** yet. The first time, macOS refuses to open it (choose **Done**, not Move to Trash): try once, then choose **System Settings → Privacy & Security → Open Anyway**, or run `xattr -dr com.apple.quarantine /Applications/Tinglang.app`.
3. Check the download: `shasum -a 256 Tinglang-{VERSION}-macOS.zip` should print `{SHA256}`.

Live captions and transcription use Apple's on-device speech recognition on macOS 26 and later; on macOS 14.2–15, download an open speech model first (Settings → Speech models). Your recordings and texts go nowhere unless you turn on a cloud provider yourself; once a day the app asks GitHub whether a new version is out (Settings → General turns that off).

1. 下载下面的 `Tinglang-{VERSION}-macOS.zip`，解压后把 **Tinglang** 拖进「应用程序」。需要 macOS 14.2 或更高版本，Apple 芯片和 Intel 芯片都可以。
2. 这个版本**还没有签名和公证**，第一次打开会被 macOS 拦下（请点「完成」，不要点「移到废纸篓」）：先尝试打开一次，再到 **系统设置 → 隐私与安全性 → 仍要打开**，或在终端运行 `xattr -dr com.apple.quarantine /Applications/Tinglang.app`。
3. 核对下载：`shasum -a 256 Tinglang-{VERSION}-macOS.zip` 应输出 `{SHA256}`。

macOS 26 及以上用 Apple 的设备端语音识别做实时字幕和转写；macOS 14.2–15 请先下载一个开源识别模型（设置 → 识别模型）。除非你自己开启云端服务，录音和文字不会发往任何地方；App 每天向 GitHub 询问一次是否有新版本（可在 设置 → 通用 里关闭）。

What was checked for this version: [docs/VERIFICATION.md](https://github.com/eeeease/TingLang/blob/{TAG}/docs/VERIFICATION.md) · 已知限制：[docs/KNOWN_LIMITATIONS.md](https://github.com/eeeease/TingLang/blob/{TAG}/docs/KNOWN_LIMITATIONS.md)

## Changes · 更新

{CHANGES}
