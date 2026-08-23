# Project history

CMQ was created on August 22, 2026, to solve a specific file-transfer problem: after a night-long smart-telescope session, Chris needed a straightforward way to retrieve a large batch of FITS files while keeping the telescope storage and destination folder visible at the same time.

The project was developed conversationally by Chris and Cody, his OpenAI Codex programming collaborator. Chris defined the workflow, tested each build on the Mac and with real files, and reported what happened. Cody translated those observations into the Swift/AppKit implementation, packaging, documentation, and release updates. The same collaboration later produced a separate native Windows 11 implementation in the same repository while preserving the original Mac code. The design stayed intentionally narrow throughout: two panes, copy, move, and the native file actions needed around that workflow.

## Retrospective milestones

### 1.0.0 — Initial public release

The first usable version established CMQ's core:

- Two independent file panes with drive and folder selection
- Back, forward, up, and direct-path navigation
- Drag-and-drop copying and Command-drag moving
- Byte-level transfer progress
- Native context-menu file actions
- Remembered pane locations, window size, and divider position
- A compact native macOS application bundle with its own icon
- Public source, build instructions, installation guidance, and an MIT license

This version turned the original telescope-transfer need into a small general-purpose utility without expanding into a full commander-style file manager.

### 1.0.1 — Quick Look safety fix

Real-world testing exposed a problem in the Quick Look context action: it could open the file's associated application and crash when the selection changed as the context menu closed.

The first corrective release switched the action to Apple's native Quick Look panel, removed the unsafe selection assumption, and supported browsing several selected files in one preview panel.

### 1.0.2 — Reliable Quick Look selection

Further testing showed that Quick Look no longer crashed but sometimes did nothing. The context-menu selection was transient and could disappear before the preview panel requested its files.

The final fix captured the right-clicked selection before the menu closed and passed that saved URL list to Quick Look. Right-clicking an unselected row was also made to select that row, matching normal macOS file-browser behavior.

### Windows 1.0.0 — Native Windows 11 release

On August 23, 2026, CMQ's focused workflow was recreated as a native .NET 8/WPF application for Windows 11. The macOS Swift/AppKit source remained unchanged, while the repository gained a separate `windows/` implementation.

The Windows release retained the two-pane layout, navigation history, direct paths, copy and move transfers, byte-level progress, remembered layout, and familiar file actions. Windows conventions replaced platform-specific Mac behavior: Shift-drop moves items, File Explorer replaces Finder, and the Recycle Bin replaces Trash.

The initial release was distributed as a self-contained x64 ZIP and documented Microsoft Defender SmartScreen authorization for unsigned community builds.

### Windows 1.0.1 — Shared CMQ branding

The first corrective Windows release embedded a multi-resolution executable icon derived from the original CMQ artwork and added explicit Windows version metadata. The original 1.0.0 release was preserved so published binaries remained immutable.

## Working method

CMQ's development followed a short feedback loop:

1. Start with a real task and keep the feature set deliberately small.
2. Build a native version that can be tested immediately.
3. Use it with real files and report the observed behavior.
4. Diagnose and correct one concrete problem at a time.
5. Package and publish a numbered release only after the change works in practice.

That process remains the preferred way to evolve CMQ. New features should strengthen its central copy-and-move workflow without obscuring it.
