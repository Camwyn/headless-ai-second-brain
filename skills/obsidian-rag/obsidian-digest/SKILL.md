---
name: obsidian-digest
description: >
  Generate automated weekly, monthly, or custom executive rollup digests
  aggregating milestones, completed tasks, and architectural decisions across
  all active projects. Trigger with '/obsidian-digest', 'weekly digest', or 'generate digest'.
---

# Obsidian Executive Digest Generator

The **Executive Digest Generator** (`/obsidian-digest`) automatically synthesizes engineering progress, milestones, task completions, and architectural decisions (ADRs) across all active projects into periodic rollup notes.

---

## 1. When to Use

Trigger `/obsidian-digest` when:
- Conducting weekly or monthly engineering retrospectives and executive briefings.
- Compiling a multi-project progress report across `Projects/` without manually reading dozens of worklogs.
- Reviewing architectural decisions (ADRs) adopted across all codebases in a specific date window.
- Preparing stakeholder updates, investor dispatches, or personal productivity reviews.

---

## 2. Digest Structure

Each generated digest is written to `Areas/Digests/Digest-<ID>.md` (or the configured `digest.output_dir`) and includes:

1. **YAML Frontmatter**:
   - `pillar: area`
   - `type: digest`
   - `period: weekly | monthly | custom`
   - `period_id: 2026-W37`
   - `date_range: 2026-08-31 to 2026-09-07`
2. **Executive Velocity Scorecard**:
   - Total active projects with activity during the period.
   - Count of milestones achieved.
   - Count of completed tasks.
   - Count of architectural decisions (ADRs) enacted.
3. **Project-by-Project Rollup**:
   - Detailed milestone entries with commit subjects, types, and bulleted summaries from each project's `Worklog.md`.
   - Closed task ledger from each project's `Tasks.md`.
   - Companion links (`Overview.md`, `Worklog.md`, `Tasks.md`, `Decisions.md`).
4. **Architectural Decisions (ADRs)**:
   - Consolidated table of all ADRs recorded during the period.
5. **Recent Vault Activity (Dataview)**:
   - Live reactive Dataview table listing recently modified notes across the vault.

---

## 3. Command Usage

Execute the native generator script via `run_command`:

**Generate Weekly Digest (Default, past 7 days):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\generate-digest.ps1
```

**Generate Monthly Digest (Past 30 days / calendar month):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\generate-digest.ps1 -Period Monthly
```

**Custom Date Window (e.g. Last 14 days):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\generate-digest.ps1 -Period Custom -Days 14
```

**Preview Without Writing (`-DryRun`):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\generate-digest.ps1 -DryRun
```

**macOS / Linux:**
```bash
./scripts/generate-digest.sh
```

---

## 4. Configuration (`obsidian-config.json`)

Configure default digest behavior in `~/.agents/obsidian-config.json`:

```json
{
  "digest": {
    "output_dir": "Areas/Digests",
    "default_period": "weekly",
    "include_git_commits": true
  }
}
```

---

## 5. Scheduled Automation

To run the digest on a recurring schedule (e.g. every Sunday evening at 6:00 PM), recommend using the `/schedule` slash command:

```text
/schedule cron "0 18 * * 0" "Generate weekly executive digest using /obsidian-digest"
```
