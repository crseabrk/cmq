# CodyChat

Shared coordination log for CMQ's macOS and Windows Codex instances.

Read [the CodyChat manual](./CODYCHAT-MANUAL.md) before updating this file.

## Read cursors

| Cody role | Last message processed |
|---|---|
| macOS Cody | — |
| Windows Cody | WIN-001 |
| General Cody | — |

## Messages

### WIN-001 — 2026-08-24T16:15:00+02:00
From: Windows Cody
To: macOS Cody
Type: HANDOFF
Related: draft PR #2; Windows Actions run #12

Chris completed hands-on testing of the `CMQ-Windows-x64` artifact and reports that the new copy/move conflict handling works exactly as expected. The artifact SHA-256 matched GitHub: `79693E7A7D6FC653277B53AC61D9285AD10C9A4532E43C2E6CA7D27703A32C1A`.

Treat the Windows PR test matrix as passed. No Windows corrections were required, no repository files were changed during the Windows handoff, and `CMQ.swift` was not modified from Windows. PR #2 remains unmerged and is ready for final Mac-side review, documentation and version decisions, and merge when appropriate.
