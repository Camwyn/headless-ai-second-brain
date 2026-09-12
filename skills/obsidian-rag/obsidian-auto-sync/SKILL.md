---
name: obsidian-auto-sync
description: >
  Autonomous, event-driven live synchronization engine that records commits to Worklog.md,
  tickets/TODOs to Tasks.md, and architectural choices to Decisions.md, while dynamically
  linking them in Projects/<ProjectName>/Overview.md.
---

# Obsidian Auto-Sync Engine

Autonomously records repository milestones, tasks, and architectural decisions into your central Obsidian knowledge vault, maintaining a structured, living record of project evolution without requiring manual user commands.

---

## 1. Trigger Conditions & Configuration Gate

Before executing any sync action, read `.agents/obsidian-config.json`:

1. **Verify Global Switch**:
   - If `auto_sync.enabled` is `false` or missing, abort silently.
2. **Verify Event Trigger**:
   - For commits: verify `auto_sync.on_commit == true`
   - For tasks/TODOs: verify `auto_sync.on_todo == true`
   - For decisions: verify `auto_sync.on_decision == true`
3. **Resolve Provider & Vault**:
   - Check `provider` in `.agents/obsidian-config.json` (defaults to `"auto"`).
   - If `"auto"`: prefer MCP toolset (`obsidian_*`), falling back to Local REST API (`127.0.0.1:27124`).
   - Use `default_vault` from `.agents/obsidian-config.json` (e.g. `<VaultName>`).
4. **Resolve Project Target Path & Worktree Awareness**:
   - Check if current workspace is a **Git Worktree**:
     - If `git rev-parse --git-dir` differs from `git-common-dir`:
       - Target folder: `Projects/<ParentProject>/Worktrees/<branch>/` (or `Projects/<Org>/<ParentProject>/Worktrees/<branch>/`).
       - Commits log to the branch worktree's `Worklog.md`.
       - Major architectural decisions link or roll up into parent `Decisions.md`.
   - Otherwise, resolve standard project path:
     - If organization nesting is detected/configured: `Projects/<Org>/<ProjectName>/`.
     - Default: `Projects/<ProjectName>/`.
   - Set `<TargetProjectPath>` for all subsequent note operations.

---

## 2. Dynamic `Overview.md` Link Injection

Whenever writing to `Worklog.md`, `Tasks.md`, or `Decisions.md`:

1. **Check if `<TargetProjectPath>/Overview.md` exists**:
   - Call `obsidian_read_note` on `<TargetProjectPath>/Overview.md`.
   - If missing, bootstrap it via `obsidian-project-init` template.
2. **Ensure Quick Links Section Contains Target Notes**:
   - Under `## Quick Links`, verify links exist:
     - `[[<TargetProjectPath>/Decisions|Decisions Log]]`
     - `[[<TargetProjectPath>/Worklog|Worklog]]`
     - `[[<TargetProjectPath>/Tasks|Tasks & Backlog]]`
     - *(If in a worktree)*: `[[Projects/<ParentProject>/Overview|Parent Project Overview]]`
   - If any link is missing, append it under `## Quick Links` via safe `etag` edit.

---

## 3. Sync Handlers

### A. Commit Sync (`Worklog.md`)
Triggered when the agent executes a git commit:

1. **Significance Evaluation**:
   - Check `auto_sync.filters.commit_level` in `.agents/obsidian-config.json` (defaults to `"milestones_only"`).
   - If `"milestones_only"`:
     - Allow: `feat:`, `refactor:`, breaking changes, major skill/rule additions, or architectural migrations.
     - Silently skip: `style:`, `lint:`, minor typos (`docs(typo):`), temp debug logs, or minor test bumps.

2. **The "1 Milestone per Rollup" Algorithm**:
   Every entry in `Worklog.md` represents **strictly one milestone**:
   - Call `obsidian_read_note` on `Projects/<ProjectName>/Worklog.md`.
   - Inspect the latest `### [YYYY-MM-DD HH:MM]` block.
   - **Start New Milestone Block** if:
     - The incoming commit is a milestone commit (`feat:`, major refactor, completed ticket).
     - OR the latest block is already capped with a milestone.
     - OR $>2$ hours have elapsed (`rollup_window_hours`) or functional scope changed.
   - **Rollup Supporting Commit** if:
     - The incoming commit is an incremental supporting commit (`chore:`, `test:`, minor `refactor:`) building toward an active milestone.
     - Append to the active block's `- **Commits**:` bullet list.

3. **Target Note**: `Projects/<ProjectName>/Worklog.md`
4. **Initial Scaffolding** (if note does not exist):
   ```markdown
   ---
   title: "<ProjectName> - Worklog"
   type: worklog
   tags:
     - project/worklog
     - changelog
   project: "[[Projects/<ProjectName>/Overview|<ProjectName>]]"
   ---

   # <ProjectName> — Engineering Worklog

   Chronological record of commits, milestones, and implementation progress.

   ---
   ```
5. **Milestone Rollup Entry Format**:
   ```markdown
   ### [YYYY-MM-DD HH:MM] <Milestone Title>
   - **Milestone**: 🏁 <1-sentence summary of the milestone achieved>
   - **Commits (<N>)**:
     - `<short_hash>` - <commit subject>
   - **Key Files**: `<file1>`, `<file2>`
   ```

6. **Dependency & Subsystem Drift Awareness**:
   - If the commit modified dependencies (`package.json`, `pyproject.toml`, `Cargo.toml`, `composer.json`, etc.) or introduced new architectural directories:
     - Note the dependency / subsystem change in the worklog entry.
     - Emit a brief, helpful prompt:
       > 💡 **Obsidian Drift Note**: Dependencies or repository structure changed. Run `/obsidian-init` to reconcile `Projects/<ProjectName>/Overview.md`.

7. **Worklog Rotation & Archiving Policy (1,000-Line Threshold)**:
   - When reading `<TargetProjectPath>/Worklog.md`, check total line count.
   - If lines exceed `auto_sync.worklog_archive_limit_lines` (default: `1000` lines):
     - Resolve current year `<YYYY>` (e.g. `2026`).
     - Target archive note: `<TargetProjectPath>/Worklog-Archive-<YYYY>.md`.
     - If archive note does not exist, initialize with frontmatter (`type: worklog-archive`) and link back to `Overview.md`.
     - Move older milestone blocks to the archive note, keeping the frontmatter, title, and the **latest 5–10 active milestone blocks** in `Worklog.md`.
     - In `Worklog.md`, ensure the archive index link exists beneath the header:
       > 📚 **Archived Milestones**: [[<TargetProjectPath>/Worklog-Archive-<YYYY>|<YYYY> Archive]]
     - Write archive note and update active `Worklog.md` with `if_match` revision guard.
     - Emit receipt:
       > 📦 **Obsidian Worklog Rotated**: Archived older entries to `<TargetProjectPath>/Worklog-Archive-<YYYY>.md`.

### B. Task / Ticket Sync (`Tasks.md`)
Triggered when a task, ticket, or major TODO is created, updated, or marked completed in session:

1. **Target Note**: `Projects/<ProjectName>/Tasks.md`
2. **Initial Scaffolding** (if note does not exist):
   ```markdown
   ---
   title: "<ProjectName> - Tasks & Backlog"
   type: tasks
   tags:
     - project/tasks
     - backlog
   project: "[[Projects/<ProjectName>/Overview|<ProjectName>]]"
   ---

   # <ProjectName> — Tasks & Backlog

   Live ledger of active, completed, and backlog items.

   ---
   ```
3. **Append or Update Entry**:
   ```markdown
   ### [YYYY-MM-DD] <Task Title>
   - **Status**: `[Pending | In Progress | Done]`
   - **Context**: <Brief description of the problem, ticket requirement, or blocker>
   - **Resolution / Next Steps**: <What was completed or what remains to be done>
   ```

### C. Decision Sync (`Decisions.md`)
Triggered when an architectural choice, dependency selection, or styling decision is finalized:

1. **Target Note**: `Projects/<ProjectName>/Decisions.md`
2. **Initial Scaffolding** (if note does not exist):
   ```markdown
   ---
   title: "<ProjectName> - Decision Log"
   type: decision-log
   tags:
     - project/decisions
     - adr
   project: "[[Projects/<ProjectName>/Overview|<ProjectName>]]"
   ---

   # <ProjectName> — Architectural Decision Records (ADRs)

   This log records significant architectural, voice, styling, and structural choices.

   ---
   ```
3. **Automated Superseded Detection & Append**:
   - Check existing ADRs in `Projects/<ProjectName>/Decisions.md` for overlapping or contradicting decisions.
   - If an existing ADR is superseded:
     - Update its status to `- **Status**: Superseded by [[#ADR-[NewID]: <New Title>|ADR-[NewID]]]`.
     - In the new ADR, include `- **Supersedes**: [[#ADR-[PriorID]: <Prior Title>|ADR-[PriorID]]]`.
   - Format entry:
   ```markdown
   ### ADR-[YYYYMMDD-HHMM]: <Descriptive Title>
   - **Date**: <YYYY-MM-DD>
   - **Status**: Accepted
   - **Supersedes**: [[#ADR-[PriorID]: <Prior Title>|ADR-[PriorID]]] *(if applicable)*
   - **Context**: <1-2 sentences on what problem or tradeoff necessitated this decision>
   - **Decision**: <Clear statement of the chosen architecture, library, pattern, or rule>
   - **Rationale**: <Why this option was selected, referencing performance, DX, simplicity, or constraints>
   - **Rejected Alternatives**:
     - *<Alternative 1>*: <Why it was rejected>
     - *<Alternative 2>*: <Why it was rejected>
   ```

---

## 4. Multi-Provider Protocol & Concurrency Protection (Zero Data Loss)

All vault read/write operations route through the active provider adapter (`headless_mcp` or `local_rest_api`):

### A. Provider Operations Adapter Table

| Operation | Headless MCP Toolset (`headless_mcp`) | Obsidian Local REST API (`local_rest_api`) |
|---|---|---|
| **Read Note** | `obsidian_read_note(vault, path)` $\rightarrow$ `{ content, etag }` | `GET /vault/<path>` (with `Accept: text/markdown` or JSON) $\rightarrow$ body + `ETag` header |
| **Edit / Replace** | `obsidian_edit_note(vault, path, content, operation: "replace", if_match)` | `PUT /vault/<path>` with header `If-Match: <etag>`, body: content |
| **Append** | `obsidian_edit_note(vault, path, content, operation: "append", if_match)` | `POST /vault/<path>` with header `If-Match: <etag>`, body: content |
| **Prepend** | `obsidian_edit_note(vault, path, content, operation: "prepend", if_match)` | `PATCH /vault/<path>` with header `Operation: prepend` (or read + prepend + PUT) |
| **Create Note** | `obsidian_create_note(vault, path, content)` | `PUT /vault/<path>` (new file), body: content |
| **Search Vault** | `obsidian_search_vault(vault, query, scope)` | `POST /search/simple?query=<query>` |

---

### B. Concurrency & Retry Loop

All updates MUST execute through this bounded exponential backoff loop:

0. **Provider Reachability Check**:
   - Verify that the active provider (MCP toolset or Local REST API) is responsive.
   - If missing, unconfigured, or connection is dropped:
     - Do NOT crash, throw unhandled exceptions, or block developer git operations.
     - Immediately persist the uncommitted payload to `.agents/pending-sync.json` (or `~/.agents/pending-sync.json`).
     - Emit a clear, non-blocking diagnostic receipt:
       > ⚠️ **Obsidian Auto-Sync**: Configured provider is unreachable or not running.
       > Queued update to `.agents/pending-sync.json`. Run `/obsidian-setup` or check provider settings to restore sync.
     - Terminate the sync attempt gracefully.

1. **Attempt 1**:
   - Call provider read note: retrieve markdown content and current `etag`.
   - Format the update and dispatch write/edit with `if_match: etag`.
2. **Attempt 2 (on 412 Precondition Failed)**:
   - Pause briefly (500ms).
   - Re-read note to get fresh content and new `etag`.
   - Re-apply delta to latest content and retry edit.
3. **Attempt 3 (on 412 Precondition Failed)**:
   - Pause with jitter (1500ms).
   - Re-read note and re-attempt edit.
4. **Final Failure Handling (Persist to Replay Queue)**:
   - If Attempt 3 fails with 412 (note is being actively edited in Obsidian desktop):
     - Append the uncommitted payload to `.agents/pending-sync.json` (or `~/.agents/pending-sync.json`):
       ```json
       {
         "id": "sync-<timestamp>-<hash>",
         "timestamp": "<ISO8601>",
         "vault": "<VaultName>",
         "target_path": "<target_note_path>",
         "operation": "append",
         "content": "<formatted_entry>"
       }
       ```
     - Emit a warning receipt in chat:
       > ⚠️ **Obsidian Concurrency**: Note `<target_note_path>` is currently being edited in Obsidian desktop.
       > Queued update to `.agents/pending-sync.json`.
       > - *Auto-flush*: Will automatically flush on the next sync event.
       > - *Manual flush*: Run `/obsidian-flush` whenever you finish editing.

---

## 5. Queue Drain & Manual Flush (`/obsidian-flush`)

Triggered automatically before any new sync event OR on-demand when the user runs `/obsidian-flush`:

1. **Check Queue File**:
   - Check if `.agents/pending-sync.json` exists and contains queued items.
   - If empty or missing, notify: `All Obsidian sync items are up to date. Queue is empty.`
2. **Drain Items**:
   - For each queued item in chronological order:
     - Attempt safe `obsidian_read_note` $\rightarrow$ `etag` $\rightarrow$ `obsidian_edit_note`.
     - On success: remove item from queue.
     - On 412 failure: leave in queue for subsequent flush.
3. **Persist State**:
   - Write remaining items back to `.agents/pending-sync.json` (or remove file if queue is empty).
   - Emit receipt:
     > 🔄 **Obsidian Queue Flushed**: Synced `<N>` pending update(s) to vault `<VaultName>`.

---

## 6. Session Confirmation

Emit a compact, unobtrusive receipt in conversation:
> 🔄 **Obsidian Live Sync**: Recorded commit `[<short_hash>]` to `Projects/<ProjectName>/Worklog.md`

---

## 7. Standalone Git Post-Commit Hook Integration

To guarantee 100% milestone capture even when commits are made outside an active AI agent session (via CLI `git commit`, IDE source control panels, or GUI git clients):

1. **Portable Hook Architecture**:
   - The repository provides a universal `.git/hooks/post-commit` script located at `scripts/post-commit`.
   - On Windows, it executes `scripts/obsidian-post-commit.ps1`.
   - On macOS / Linux, it executes `scripts/obsidian-post-commit.sh`.
2. **Execution Flow**:
   - Gathers commit hash, subject, author, date, and changed files.
   - Evaluates against the configured `commit_level` (default: `milestones_only`).
   - Appends significant milestones directly into `.agents/pending-sync.json`.
   - Emits a non-blocking terminal notice: `[obsidian-sync] Queued milestone [<hash>] to .agents/pending-sync.json`.
3. **Automatic Reconciliation**:
   - The queued commits automatically flush and roll up into `Projects/<ProjectName>/Worklog.md` on the next agent interaction or on-demand via `/obsidian-flush`.

