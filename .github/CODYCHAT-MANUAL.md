# CodyChat Manual

CodyChat is CMQ's lightweight, repository-backed handoff log for coordination between macOS Cody, Windows Cody, and future Codex instances.

## Files

- `.github/CODYCHAT.md` — the append-only message log and read cursors.
- `.github/CODYCHAT-MANUAL.md` — this protocol.
- `AGENTS.md` — tells future Codex instances to consult CodyChat before making project changes.

The canonical copies live on the default branch. Product source, pull-request discussion, and formal release notes still belong in their normal locations; CodyChat records coordination and points to them.

## Starting a CMQ work session

1. Read this manual completely.
2. Read the cursor table and all messages in `.github/CODYCHAT.md`.
3. Identify yourself as `macOS Cody`, `Windows Cody`, or `General Cody` from the machine and task.
4. Process messages addressed to you whose IDs are newer than your cursor.
5. Before finishing authorized repository work, update your cursor and append any useful ACK, STATUS, QUESTION, DECISION, or HANDOFF entry.

Reading CodyChat does not itself authorize code changes, merging, releasing, posting comments, or other external actions. Follow the user's current request and normal safety rules.

## Message IDs

Use an independent, increasing sequence for each sender:

- `MAC-001`, `MAC-002`, ... for macOS Cody.
- `WIN-001`, `WIN-002`, ... for Windows Cody.
- `GEN-001`, `GEN-002`, ... when the instance is not platform-specific.

Never reuse an ID. If two instances race, keep both entries and renumber the later conflicting entry in the resolving commit.

## Message format

Append messages in chronological order:

```md
### WIN-002 — 2026-08-24T16:30:00+02:00
From: Windows Cody
To: macOS Cody
Type: HANDOFF
Related: PR #2; Actions run #12

Message text.
```

Use ISO 8601 timestamps with an explicit offset. Valid types are:

- `HANDOFF` — work or responsibility is being passed to another instance.
- `STATUS` — notable progress or test state.
- `QUESTION` — a response or decision is needed.
- `DECISION` — a project decision and its rationale.
- `ACK` — confirms a message was read and understood.

Keep entries concise, factual, and link or name the relevant PR, issue, Actions run, commit, release, or file.

## Read cursors

The cursor table records the last message each role has processed. A role may point to a message from any sender.

Update only your own role's cursor. Do not advance another Cody's cursor on its behalf. Advance the cursor only after reading every earlier message in the file. If no new outbound message is needed, a cursor-only update is acceptable during otherwise authorized repository work.

## Append-only rule

Do not silently edit or delete historical messages. Correct an error with a new `CORRECTION` note inside a STATUS or DECISION entry that names the mistaken message ID. Git history remains the final audit trail.

## Relationship to GitHub features

- Use pull-request comments for detailed review discussion tied to a specific change.
- Use issues for trackable bugs or future work.
- Use release notes and `CHANGELOG.md` for user-facing shipped changes.
- Use CodyChat for short cross-instance context, test handoffs, and pointers to those records.

## Safety and hygiene

- Never store passwords, tokens, signed artifact URLs, personal data, or other secrets.
- Prefer stable GitHub URLs and IDs; signed download URLs expire.
- Do not claim tests passed unless a named person or automation actually completed them.
- State explicitly whether a PR was merged, a release was published, or source files were changed.
- Preserve platform boundaries requested by the user.
