# CMQ for Windows 11

This directory contains the native Windows implementation of **CMQ — Copy. Move. Quit.**

The existing Swift/AppKit application remains the macOS implementation. The Windows version follows the same deliberately small two-pane workflow while using Windows-native behavior and terminology. Its executable embeds Windows icon sizes generated from the original CMQ macOS artwork.

## Download

- [CMQ for Windows 1.0.0 release page](https://github.com/crseabrk/cmq/releases/tag/windows-v1.0.0)
- [Direct download: CMQ-Windows-x64.zip](https://github.com/crseabrk/cmq/releases/download/windows-v1.0.0/CMQ-Windows-x64.zip)

Windows and macOS releases use independent version numbers. See [all releases](https://github.com/crseabrk/cmq/releases) for both platforms.

## Requirements

- Windows 11
- .NET 8 SDK when building from source

Self-contained release and test builds include the required runtime.

## Running a downloaded build

1. Download `CMQ-Windows-x64.zip` from the official Windows release and extract it to a normal folder.
2. Run `CMQ.exe`.
3. If Microsoft Defender SmartScreen shows **Windows protected your PC**, select **More info**.
4. Confirm that the application name is **CMQ.exe**, then select **Run anyway**.

CMQ's community builds are not currently code-signed, so Windows may show this warning for every newly downloaded version—not only test builds. Only authorize a copy downloaded from the [official CMQ GitHub repository](https://github.com/crseabrk/cmq).

You can also remove the downloaded-file marker before running it:

1. Right-click the downloaded ZIP—or `CMQ.exe` after extraction—and choose **Properties**.
2. On the **General** tab, select **Unblock** near the bottom.
3. Select **Apply**, then **OK**.

If **Unblock** is not shown, Windows has not marked that file as downloaded or it has already been unblocked.

## Build and run from source

```powershell
cd windows\CMQ.Windows
dotnet run
```

## Publish a standalone x64 build

```powershell
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

The published application is written beneath `bin\Release\net8.0-windows10.0.19041.0\win-x64\publish`.

## Interaction

- Drag files or folders onto either pane to copy them there.
- Hold **Shift** while dropping to move instead.
- Right-click a selection for copy/move to the other pane, rename, new folder, Recycle Bin, Explorer, path copying, Properties, and refresh.
