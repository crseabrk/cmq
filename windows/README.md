# CMQ for Windows 11

This directory contains the native Windows implementation of **CMQ — Copy. Move. Quit.**

The existing Swift/AppKit application remains the macOS implementation. The Windows version follows the same deliberately small two-pane workflow while using Windows-native behavior and terminology.

## Requirements

- Windows 11
- .NET 8 SDK

## Build and run

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
