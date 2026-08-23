# CMQ — Copy. Move. Quit.

CMQ is a deliberately small, native two-pane file manager for **macOS** and **Windows 11**. Choose a drive or folder in each pane, then copy or move files while keeping both locations visible.

CMQ is intentionally focused. It is not meant to replace Finder or File Explorer or become a commander-style toolbox.

## Download CMQ

### macOS

[Download CMQ 1.0.2 for macOS](https://github.com/crseabrk/cmq/releases/tag/v1.0.2)

CMQ for macOS requires macOS 13 or later on an Apple Silicon Mac.

### Windows 11

[Download CMQ for Windows 1.0.0](https://github.com/crseabrk/cmq/releases/tag/windows-v1.0.0)

[Direct Windows ZIP download](https://github.com/crseabrk/cmq/releases/download/windows-v1.0.0/CMQ-Windows-x64.zip)

The Windows ZIP is self-contained; no separate .NET installation is required.

## Installing on macOS

1. Download and unzip the macOS release.
2. Drag `CMQ.app` into `/Applications`.
3. On first launch, Control-click CMQ, choose **Open**, then confirm **Open**.

macOS may request access to protected folders, removable drives, or network locations. Allow only the locations you intend to use.

## Installing on Windows 11

1. Download and extract `CMQ-Windows-x64.zip`.
2. Run `CMQ.exe`.
3. If Microsoft Defender SmartScreen shows **Windows protected your PC**, select **More info**.
4. Confirm that the application name is **CMQ.exe**, then select **Run anyway**.

CMQ's community builds are not currently code-signed, so newly downloaded versions may show this warning. Only authorize builds downloaded from the official CMQ repository.

You can alternatively right-click the downloaded ZIP or extracted executable, choose **Properties**, select **Unblock** on the General tab, and apply the change.

## Using CMQ

- Each pane browses a drive or folder independently.
- Use the drive selector or path field to choose a location.
- Use **Back**, **Forward**, and **Up** for navigation.
- Double-click a folder to enter it or a file to open it.
- Drag files or folders to the other pane to copy them.
- On macOS, hold **Command** while dropping to move.
- On Windows, hold **Shift** while dropping to move.
- Right-click selections for copy, move, duplicate, rename, new folder, trash or Recycle Bin, reveal, path copying, information, and refresh.
- Transfer progress is shown across both panes.

When first testing move or Recycle Bin behavior, use disposable files.

## Project links

- [Source repository](https://github.com/crseabrk/cmq)
- [All releases](https://github.com/crseabrk/cmq/releases)
- [Project history](https://github.com/crseabrk/cmq/blob/main/PROJECT_HISTORY.md)
- [Changelog](https://github.com/crseabrk/cmq/blob/main/CHANGELOG.md)
- [License](https://github.com/crseabrk/cmq/blob/main/LICENSE)

## Philosophy

CMQ began with one uncomplicated need: retrieving a large batch of FITS files after a smart-telescope session while keeping the telescope storage and destination visible at the same time.

Its name describes the intended workflow: copy something, move something, quit.

