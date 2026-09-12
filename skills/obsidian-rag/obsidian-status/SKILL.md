---
name: obsidian-status
description: >
  On-demand, ephemeral "what needs my attention" briefing across the vault — vault health,
  mirror drift, inbox backlog, and open project tasks in one glance. Not written to a file
  (see obsidian-digest for the recorded, periodic rollup). Trigger with '/obsidian-status',
  'what's the status', 'what needs my attention', or a daily/weekly check-in habit.
---

# Obsidian Status

A live, human-initiated briefing — the thing you actually run "a lot," not a scheduled job.
Distinct from `obsidian-digest`: digest is a periodic rollup written to
`Areas/.../Digests/Digest-<period>.md` as a historical record; status is a glance you ask for
in the moment, never persisted. Running it twice in five minutes should just answer twice —
no state, no side effects, nothing to clean up.

## 1. When to Use

- On-demand, whenever the user asks for a status update, a daily/weekly check-in, or "what's
  going on."
- As a habit-forming replacement for manually running `/audit-vault`, `/obsidian-digest`, and
  a project-by-project task check separately — one command, one answer.

## 2. What It Surfaces

Pull from existing skills' own logic rather than re-implementing diagnostics — this skill is a
thin aggregator, not a second vault-audit engine:

1. **Vault Health** — one line: `/audit-vault`'s score + top issue count (e.g. "86/100, 5
   broken links"). Point to `/audit-vault` for full detail; don't dump the whole report here.
2. **Mirror Drift** — "0 drifted" if clean, or a short list of drifted/unreachable pairs from
   the same check `obsidian-vault-audit` runs.
3. **Inbox Backlog** — the count + oldest item's age from the audit script's Inbox Backlog
   vector, which covers every file in the inbox, not just markdown. **This is the hook**: if
   anything is stale, offer *in the same turn* to help file it. For a markdown note, that means
   reading it and proposing a destination in `Projects/`, `Areas/`, or `Resources/`. For
   anything else (a PDF, screenshot, voice memo) — say plainly that its content can't be read,
   name what it is and how old it is, and ask the human where it belongs rather than guessing.
   Either way, on confirmation move it — never delete — into
   `<inbox_dir>/<processed_subfolder>/`. Don't require a separate command for this; the whole
   point is removing a step, not adding one.
4. **Active Projects** — for each `Projects/<name>/`, an open-task count from `Tasks.md` (a
   quick count, not a dump — link to the file for detail).
5. **Pending Live-Sync Queue** — if `.agents/pending-sync.json` has unflushed entries, mention
   it. `cc-session-start.ps1` already surfaces this at Claude Code session start; this makes it
   reachable on-demand too, for anyone without that hook installed or checking mid-session.

## 3. Execution

1. Run `scripts/audit-vault.ps1` / `.sh` with `-Format Json` and pull `HealthScore`,
   `BrokenLinksCount`, `InboxTotalCount`, `InboxStaleCount`, `InboxStaleItems`.
2. Run the Mirror Drift check per `obsidian-vault-audit`'s own agent-driven procedure.
3. For each `Projects/<name>/Tasks.md`, count open (`- [ ]`) items.
4. Check `.agents/pending-sync.json` for entries (if the file exists and is non-empty).
5. Render as a short, scannable briefing — headings and counts, not prose paragraphs.

## 4. Report Template

```markdown
## Status

**Vault**: 86/100 (GOOD) — 5 broken links, 0 companion gaps. Run /audit-vault for detail.
**Mirrors**: 0 drifted, 3 declared pairs all in sync.
**Inbox**: 3 items (1 non-markdown), 2 stale — "Quick idea about X.md" (12 days) and a photo, "receipt-photo.png" (15 days, can't read it — where should this go?). Want me to help file either?
**Projects**: camwyn-agent-skills (2 open) · manyhats-ledger (5 open) · tradeops-mvp (0 open)
**Pending sync**: 2 commits queued, not yet flushed to Worklog.md. Run /obsidian-flush.
```

## 5. Guardrails

- **Never file inbox notes without a confirming answer** for anything beyond a trivial,
  obviously-correct move — this is a conversational offer, not autonomous action. See
  `content-mirror-sync.md` §"Confirm before propagating" for the same trust calibration.
- **Never delete originals.** Filed notes move to `<inbox_dir>/<processed_subfolder>/`, never
  removed — same principle as every other skill in this suite tonight.
- **This skill does not run on a schedule.** If the user wants ambient/automatic checking, that
  needs a scheduled headless invocation (Claude Code `claude -p`, Codex automations, or
  Antigravity local execution) — a separate, explicit setup step, not something this skill
  does on its own. Plain ChatGPT/Gemini chat cannot run this unattended; see the note in
  `connectors/chatgpt-desktop/form-instructions.md` for the closest available substitute there.
