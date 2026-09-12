# Autonomous Live Obsidian Synchronization Rule

## Purpose
Enforces autonomous, live synchronization of engineering milestones, architectural choices, and task tracking directly into the developer's Obsidian vault without requiring manual slash commands.

## Activation Triggers & Protocol
Whenever the agent performs any of the following operations during a coding session:

1. **Git Commit (`on_commit`)**:
   - Immediately after executing a `git commit` command, check `.agents/obsidian-config.json`.
   - If `auto_sync.enabled` is `true` and `auto_sync.on_commit` is `true`:
   - Evaluate against the **Threshold of Significance** and apply the **1-Milestone-per-Rollup** lifecycle before writing to `Projects/<ProjectName>/Worklog.md`.

2. **Task / Ticket / Major TODO Lifecycle (`on_todo`)**:
   - When a task, ticket, or milestone TODO is created, resolved, or blocked during development.
   - If `auto_sync.enabled` is `true` and `auto_sync.on_todo` is `true`:
   - Invoke the `obsidian-auto-sync` skill (Task Sync) to update `Projects/<ProjectName>/Tasks.md`.

3. **Architectural & Design Decisions (`on_decision`)**:
   - When selecting a library/framework, establishing a design token standard, designing an API contract, or rejecting an architectural alternative.
   - If `auto_sync.enabled` is `true` and `auto_sync.on_decision` is `true`:
   - Invoke the `obsidian-auto-sync` skill (Decision Sync) to record a structured ADR in `Projects/<ProjectName>/Decisions.md`.

---

## Record Ownership (Single Source of Truth)

The Obsidian vault is the single source of truth for every durable or cross-cutting record. A repo may hold a working copy; it is never authoritative.

- **Vault owns (canonical, hand-editable):** `Projects/<ProjectName>/Overview.md`, `Tasks.md`, `Worklog.md`, `Decisions.md`, and everything under `Areas/` — durable backlog, triage items, milestone history, ADRs, audits, dispatches, digests.
- **Repo owns (transient, non-authoritative):** `.agents/obsidian-config.json` (per-repo config override for this rule — config, not a record), `.agents/pending-sync.json` (local outbox; drains to the vault), and `.scratch/<feature>/` plus in-repo docs like `.ai/` (in-flight spec and roadmap beside the diff). `.scratch/` has a death date: on merge, distill the outcome into a `Worklog.md` milestone plus, if architectural, a `Decisions.md` ADR, then delete or archive it.
- **Rule of thumb:** if it must still be true in six months, it belongs in the vault; if it is only true until this branch lands, it belongs in `.scratch/`.
- **Precedence:** where a skill's own instructions say to record something in the repo, that yields to this section for anything in the "Vault owns" list. Skill-local scratch — `investigate` evidence logs, `triage` `.out-of-scope/` KBs, review notes — stays where the skill puts it; those are not durable project records.

---

## Threshold of Significance & "1 Milestone per Rollup"

To prevent knowledge vault spam, the agent must adhere to strict cognitive filtering:

### 1. Commit Filtering (when `commit_level == "milestones_only"`)
- **Significant (Log/Rollup)**:
  - Feature completions (`feat:` or `feat(...):`)
  - Architectural or structural refactors (`refactor:` or `refactor(...):`)
  - Breaking changes (`feat!:` or `BREAKING CHANGE`)
  - New tools, skills, or rules added
  - Major dependency upgrades or architecture migrations
- **Insignificant (Skip Silently)**:
  - Formatting, lint, or whitespace tweaks (`style:`, `lint:`)
  - Minor typo or comment updates (`docs(minor):`, `chore(typo):`)
  - Temporary debugging prints or scratch file additions
  - Incremental test bumps without structural changes

### 2. "1 Milestone per Rollup" Lifecycle
Every entry in `Worklog.md` represents **strictly one milestone**:
- **Supporting Commits**: Commits that build toward an active milestone roll up under its commit list.
- **Milestone Commit as Rollup Capstone**: An obvious milestone commit (e.g., feature completion, major refactor) **ends and finalizes** the rollup.
- **No Merging Milestones**: A new milestone commit must **never** be merged into a prior milestone entry. It immediately starts a fresh, distinct milestone block.
- **Window Boundary**: If more than 2 hours have passed or the functional scope changes, start a new block even if the prior milestone was not explicitly capped.

### 3. Decision Significance
- **Record as ADR**: Choosing a tech stack, adopting a design system token structure, picking an MCP interface, rejecting an alternative approach, or establishing a security protocol.
- **Skip ADR**: Routine helper function implementations, bug fixes following established patterns, or local variable renames.

### 4. Drift Awareness & Notification
- When a commit modifies package manifests (`package.json`, `Cargo.toml`, etc.) or introduces new top-level directories:
  - Note the dependency / architecture shift in `Worklog.md`.
  - Prompt the user with a 1-line note suggesting `/obsidian-init` to reconcile `Projects/<ProjectName>/Overview.md`.

---

## Operational Guardrails
- **Silent Check**: If `.agents/obsidian-config.json` is absent or `auto_sync.enabled` is `false`, proceed normally with development without failing or interrupting the user.
- **Missing or Unreachable MCP Server**: If the `obsidian` MCP toolset is not configured or the server is down, do NOT fail or interrupt developer operations; append the payload to `.agents/pending-sync.json` and emit a concise 1-line non-blocking notice.
- **PARA Architecture & CODE Workflow**:
  - Organize vault context strictly according to Tiago Forte's **PARA** model: `Projects/` (active efforts), `Areas/` (ongoing standards/directives), `Resources/` (reusable references/cheatsheets), and `Archives/` (cold storage).
  - Execute live sync following the **CODE** operating cycle: **Capture** raw commits/tasks $\rightarrow$ **Organize** into PARA $\rightarrow$ **Distill** via 1-Milestone Rollups and structured ADRs $\rightarrow$ **Express** via `Dashboard.canvas` and verified code.
- **Worktree & Organization Routing**: If the workspace is a git worktree, route commit logs to `Projects/<ParentProject>/Worktrees/<branch>/Worklog.md` and inherit parent project overview/decisions links. If an organization namespace is configured, nest projects under `Projects/<Org>/<Project>/`.
- **Worklog Archiving Threshold**: When `<TargetProjectPath>/Worklog.md` exceeds 1,000 lines, rotate older milestone blocks into `Worklog-Archive-<YYYY>.md` (or `Archives/Worklogs/`), retaining the latest 5–10 active blocks in `Worklog.md` with an archive index link.
- **Dynamic Quick Links**: Ensure `<TargetProjectPath>/Overview.md` contains links under `## Quick Links` to `Worklog.md`, `Tasks.md`, and `Decisions.md`.
- **Concurrency Safety (Zero Data Loss)**:
  - Always read note content and capture `etag` first, editing with `obsidian_edit_note`.
  - On 412 conflicts, execute 3-attempt exponential backoff (500ms, 1500ms).
  - If all 3 attempts fail due to active desktop edits, append the payload to `.agents/pending-sync.json`.
  - The queue automatically drains on the next sync event, or on-demand when the user runs `/obsidian-flush`.
