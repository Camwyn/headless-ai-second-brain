---
name: obsidian-decision-sync
description: >
  Captures architectural, voice, styling, and technical decisions made during development
  and syncs them to the project's Decision Log in Obsidian as structured ADRs.
  Use when confirming major technical choices, after plan reviews, or when asked to 'log decision'.
---

# Obsidian Decision Sync

Captures critical decisions made during pair programming, architecture planning, and feature implementation, persisting them into your central Obsidian knowledge vault (resolving `default_vault` from `.agents/obsidian-config.json`) so future agent sessions and team members retain full rationale and rejected alternatives.

---

## 1. When to Trigger

- **Explicitly**: When the user says "log this decision", "record our choice in Obsidian", "update decision log", or runs `/obsidian-decision`.
- **Proactively**: When completing an architecture review (`/plan-eng-review`), adopting a new framework/library, establishing a design token standard, or discarding an approach after a technical spike.

---

## 2. Decision Anatomy (ADR Standard)

Every decision record must capture **Choice**, **Rationale**, and **Rejected Alternatives** to prevent future sessions from re-exploring dead ends:

```markdown
### ADR-[YYYYMMDD-HHMM]: <Descriptive Decision Title>
- **Date**: <YYYY-MM-DD>
- **Status**: Accepted
- **Supersedes**: [[#ADR-[PriorID]: <Prior Title>|ADR-[PriorID]]] *(if replacing an older decision)*
- **Context**: <1-2 sentences on what problem or tradeoff necessitated this decision>
- **Decision**: <Clear statement of the chosen architecture, library, pattern, or rule>
- **Rationale**: <Why this option was selected, referencing performance, DX, simplicity, or constraints>
- **Rejected Alternatives**:
  - *<Alternative 1>*: <Why it was rejected, e.g. too complex, lacking maintenance, high latency>
  - *<Alternative 2>*: <Why it was rejected>
```

---

## 3. Concurrency-Safe Sync Flow & Lifecycle Management

To safely write to Obsidian without race conditions or overwriting desktop changes (resolves vault name `<VaultName>` from `default_vault` in `.agents/obsidian-config.json`):

1. **Locate Target Note**:
   - Primary: `Projects/<ProjectName>/Decisions.md`
   - Fallback 1: `Projects/<ProjectName>.md` (under `## Decision Log`)
   - Fallback 2: `Projects/<ProjectName>/Overview.md` (under `## Decision Log`)

2. **Read Note & Capture Etag**:
   - Call `obsidian_read_note`:
     - `vault`: `"<VaultName>"`
     - `path`: target note path
   - Extract `etag` and current content.

3. **Automated Superseded ADR Detection**:
   - Scan existing ADR entries in the note for overlapping topics, superseded technologies, or conflicting choices (e.g. replacing Tailwind with Vanilla CSS, or switching database drivers).
   - If a related or conflicting ADR is found:
     - Prompt user or confirm: `Does this decision supersede ADR-[ID]: <Title>?`
     - If confirmed:
       - Update the previous ADR's status line from:
         `- **Status**: Accepted`
         to:
         `- **Status**: Superseded by [[#ADR-[NewID]: <New Title>|ADR-[NewID]]]`
       - Add `- **Supersedes**: [[#ADR-[PriorID]: <Prior Title>|ADR-[PriorID]]]` to the new ADR block.

4. **Format & Write Note via Safe Etag**:
   - Append the new ADR block (and update the prior ADR status if superseded) in the content buffer.
   - Call `obsidian_edit_note`:
     - `vault`: `"<VaultName>"`
     - `path`: target note path
     - `operation`: `"replace"`
     - `content`: updated note content
     - `if_match`: captured etag

5. **Handle Conflicts & Reachability (Bounded Backoff & Queue Fallback)**:
   - If the `obsidian` MCP toolset is missing or unreachable:
     - Append the uncommitted ADR payload to `.agents/pending-sync.json`.
     - Emit: `⚠️ Obsidian Decision Sync: Obsidian MCP server unreachable. Queued ADR to pending-sync.json.`
   - If `obsidian_edit_note` returns `412 Precondition Failed`:
     - Attempt 2: Pause 500ms, re-read note via `obsidian_read_note`, get fresh content & etag, re-apply ADR, retry.
     - Attempt 3: Pause 1500ms, re-read note and retry.
     - If Attempt 3 fails: append ADR payload to `.agents/pending-sync.json` and inform user (will auto-flush on next sync or via `/obsidian-flush`).

6. **Emit In-Chat Receipt**:
   - Display a clean summary of what was logged to Obsidian:
     > 📝 **Obsidian Decision Recorded**
     > **Note**: `Projects/<ProjectName>/Decisions.md`
     > **ADR**: `ADR-[YYYYMMDD-HHMM]: <Title>`
     > **Status**: Accepted

---

## 4. Guardrails & Privacy

- **Secret Scrubbing**: Never include API keys, passwords, database URLs with credentials, or personal access tokens in ADR entries.
- **Concise & Scannable**: Avoid dumping full source code or verbose chat logs into ADRs. Focus on the core decision, reasoning, and discarded paths.
- **Preserve Note Structure**: Do not modify or delete existing ADR entries when appending new ones unless explicitly instructed to mark an older ADR as `Superseded`.
