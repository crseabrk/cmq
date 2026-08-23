# CMQ

**Copy. Move. Quit.**

CMQ is a deliberately small, native two-pane file manager. Choose a drive or folder in each pane, then copy or move files between them. It is not intended to replace Finder or File Explorer or grow into a commander-style toolbox.

## Platforms

- **macOS:** the original Swift/AppKit implementation in `CMQ.swift`
- **Windows 11:** the native .NET/WPF implementation under [`windows/`](windows/README.md)

The platform implementations share the same workflow and project space while remaining separate native applications.

## Downloads

- **macOS:** [CMQ 1.0.2 for macOS](https://github.com/crseabrk/cmq/releases/tag/v1.0.2)
- **Windows 11:** [CMQ for Windows 1.0.0](https://github.com/crseabrk/cmq/releases/tag/windows-v1.0.0) — [direct ZIP download](https://github.com/crseabrk/cmq/releases/download/windows-v1.0.0/CMQ-Windows-x64.zip)
- **All versions:** [Releases](https://github.com/crseabrk/cmq/releases)

## Features

- Two independent file panes
- Mounted-drive selector for each pane
- Back, forward, up, and direct path navigation
- Drag-and-drop copy with a platform-appropriate modifier for moving
- Byte-level transfer progress
- Platform-native file opening and previews
- Native context menu for common file operations
- Remembers pane locations, window size, and divider position
- Falls back to the home folder when a remembered location is unavailable

## macOS requirements

- macOS 13 or later
- Apple Silicon Mac
- Xcode or matching Apple command-line toolchain

## Build for macOS

```sh
chmod +x build.sh
./build.sh
open outputs/CMQ.app
```

The script compiles the single Swift/AppKit source file, constructs the application bundle, embeds the icon, and applies an ad-hoc local signature. It does not require an Xcode project.

## Build for Windows 11

Install the .NET 8 SDK, then:

```powershell
cd windows\CMQ.Windows
dotnet run
```

See the [Windows documentation](windows/README.md) for publishing instructions and Windows-specific interaction details.

## Installing a downloaded macOS build

1. Download and unzip the CMQ release.
2. Drag `CMQ.app` into `/Applications`.
3. On first launch, Control-click CMQ, choose **Open**, then confirm **Open**.

CMQ is free, small, and non-commercial. Apple requires the same $99 USD annual Developer Program membership to Developer ID sign and notarize this hobby utility as it does for commercial Mac software. That recurring cost is out of proportion to CMQ's deliberately limited scope, so community builds are currently ad-hoc signed instead. The source and build process are public so users can inspect or build CMQ themselves.

## macOS file and drive permissions

macOS protects locations including Desktop, Documents, Downloads, iCloud Drive, network volumes, and removable drives. The first time CMQ tries to access one of these locations, macOS may ask for permission. Choose **Allow** if you want to use that location in CMQ.

Permissions can be reviewed later under:

**System Settings → Privacy & Security → Files & Folders → CMQ**

If CMQ needs to browse locations that are not available through the individual switches, you can add it as an exception under:

**System Settings → Privacy & Security → Full Disk Access**

Click **+**, select `/Applications/CMQ.app`, enable it, and restart CMQ. Full Disk Access is optional and much broader than ordinary folder access; only grant it if you intentionally want CMQ to browse protected locations across the Mac. It does not override normal Unix ownership, read-only media, server permissions, or filesystem restrictions.

## Philosophy

CMQ began with one uncomplicated need: after a night-long session with a smart telescope, retrieve a large batch of FITS files from the telescope while keeping the source and destination visible. A simple two-pane view makes that transfer direct and easy to follow.

Its name describes the intended workflow—copy something, move something, quit.

Feature proposals are welcome when they strengthen that workflow without turning CMQ into a general-purpose file-management suite.

The development story and completed release milestones are recorded in [Project history](PROJECT_HISTORY.md).

## License

[MIT](LICENSE)
