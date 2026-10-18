**VLC Redesign** is an unofficial build of VLC media player with an interface based on
**["I Redesigned VLC After 25 Years"](https://www.youtube.com/watch?v=ERFeOgqk324) by [Juxtopposed](https://www.youtube.com/@juxtopposed)**.

VLC media player is made by [VideoLAN](https://www.videolan.org) and its contributors. This project is not affiliated with or endorsed by VideoLAN or Juxtopposed.

### Downloads

| Platform | File |
| --- | --- |
| Windows 10/11 (x64) | `vlc-redesign-*-win64.exe` (installer) or `*-win64-portable.zip` |
| macOS, Apple Silicon (M1 and later) | `vlc-redesign-*-macos-arm64.dmg` |
| macOS, Intel | `vlc-redesign-*-macos-x86_64.dmg` |
| Linux x86_64 | `vlc-redesign-*-x86_64.AppImage` |

### First launch

- **macOS:** these builds are not notarized. Right-click **VLC Redesign.app**, choose **Open**, then **Open** again. If macOS says the app is damaged, run `xattr -dr com.apple.quarantine "/Applications/VLC Redesign.app"`.
- **Windows:** the installer is unsigned, so SmartScreen may warn you. Choose **More info**, then **Run anyway**. It installs next to any official VLC.
- **Linux:** `chmod +x vlc-redesign-*.AppImage`, then run it. AppImageLauncher won't prompt you to integrate it.

This is based on the in-development VLC 4.0 branch, so expect nightly-level stability.
