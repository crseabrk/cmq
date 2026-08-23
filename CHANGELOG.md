# Changelog

CMQ maintains independent macOS and Windows release numbers.

## Windows 1.0.0 — 2026-08-23

### Added

- Native Windows 11 implementation using .NET 8 and WPF.
- Two independent panes with drive selection, navigation history, direct paths, and remembered layout.
- Drag-and-drop copying and Shift-drag moving with byte-level progress.
- Windows-native opening, context actions, File Explorer integration, Properties, and Recycle Bin support.
- Self-contained public x64 release that does not require a separate .NET installation.
- Microsoft Defender SmartScreen authorization guidance for unsigned community builds.
- Multi-resolution Windows executable icon generated from the original CMQ macOS artwork.

## macOS 1.0.2 — 2026-08-22

### Fixed

- Quick Look captures the right-clicked file selection before the context menu closes, so the native preview panel receives the selected files reliably.
- Right-clicking an unselected row now makes that row the context-menu selection, matching normal macOS file-browser behavior.

## macOS 1.0.1 — 2026-08-22

### Fixed

- Quick Look now uses the native macOS preview panel instead of opening the file's associated application.
- Quick Look no longer crashes if the file selection changes while the context menu is closing.
- Multiple selected files can be browsed in one Quick Look panel.

## macOS 1.0.0 — 2026-08-22

- Initial public release.
