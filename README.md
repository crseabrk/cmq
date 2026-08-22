# CMQ

**Copy. Move. Quit.**

CMQ is a deliberately small, native two-pane file manager for macOS. Choose a drive or folder in each pane, then copy or move files between them. It is not intended to replace Finder or grow into a commander-style toolbox.

## Features

- Two independent file panes
- Mounted-drive selector for each pane
- Back, forward, up, and direct path navigation
- Drag-and-drop copy; hold Command while dropping to move
- Byte-level transfer progress
- Native context menu for common file operations
- Remembers pane locations, window size, and divider position
- Falls back to the home folder when a remembered location is unavailable

## Requirements

- macOS 13 or later
- Apple Silicon Mac
- Xcode or matching Apple command-line toolchain

## Build

```sh
chmod +x build.sh
./build.sh
open outputs/CMQ.app
```

The script compiles the single Swift/AppKit source file, constructs the application bundle, embeds the icon, and applies an ad-hoc local signature. It does not require an Xcode project.

## Philosophy

CMQ began with one uncomplicated need: keep two folders visible and move files between them. Its name is its intended workflow—copy something, move something, quit.

Feature proposals are welcome when they strengthen that workflow without turning CMQ into a general-purpose file-management suite.

## License

[MIT](LICENSE)
