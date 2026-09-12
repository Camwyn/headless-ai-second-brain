---
name: obsidian-project-init
description: >
  Scan Obsidian vault for the current project, initialize canonical project notes if missing,
  or detect drift and prompt for non-destructive updates if they already exist.
  Use when dropping into an existing codebase, kicking off a new project, or running /obsidian-init.
---

# Obsidian Project Init & Sync

Connects the active codebase to your central Obsidian knowledge vault (resolved from `default_vault` in `.agents/obsidian-config.json`). Discovers project identity, checks if project documentation exists in Obsidian, bootstraps missing notes with structured templates, or detects drift and prompts for non-destructive updates.

---

## 1. Discovery & Environment Detection

When triggered:

1. **Resolve Provider & Vault Target**:
   - Check `.agents/obsidian-config.json` for `provider` (defaults to `"auto"`) and `default_vault` (e.g. resolve `<VaultName>`).
   - Route all vault actions (`search_vault`, `create_directory`, `create_note`, `read_note`, `edit_note`) through the active provider (Headless MCP `obsidian_*` tools or Obsidian Local REST API endpoints).
   - If unsure, missing, or on error, call provider vault listing to confirm available vaults.

2. **Inspect Current Codebase Context & Workspace Topology**:
   - **Git Worktree Detection**:
     - Check if running inside a git worktree (`git rev-parse --git-dir` vs `git rev-parse --git-common-dir`).
     - If inside a worktree:
       - Set `is_worktree: true`
       - Resolve parent repo name and current branch name (`git branch --show-current`).
       - Canonical project target path: `Projects/<Org>/<ParentProject>/Worktrees/<branch>/` (or `Projects/<ParentProject>/Worktrees/<branch>/`).
   - **Organization / Multi-Repo Namespace**:
     - Check git remote URL (e.g. `github.com:<Org>/<Repo>` or `git@...:<Org>/<Repo>.git`).
     - If `organization_nesting` is enabled in `obsidian-config.json` or an organization is detected:
       - Prefix path: `Projects/<Org>/<ProjectName>/`
     - Otherwise, default to flat path: `Projects/<ProjectName>/`.
   - **Tech Stack**: Detected languages, frameworks, major dependencies.
   - **Repo Status**: Git remote URL, current branch, brief summary of repository purpose.

3. **Search Obsidian Vault**:
   - Call `obsidian_search_vault`:
     - `vault`: `"<VaultName>"`
     - `query`: `"<ProjectName>"`
     - `mode`: `"filename"` (and fallback to `"content"` with `scope: "Projects"`)

---

## 2. Branch A: Project Does NOT Exist in Obsidian (Bootstrap)

If no note matches the project target path under `Projects/`:

1. **Create Project Directory**:
   - Call `obsidian_create_directory`:
     - `vault`: `"<VaultName>"`
     - `path`: `"<TargetProjectPath>"` (e.g. `Projects/<ProjectName>` or `Projects/<Org>/<ProjectName>/Worktrees/<branch>`)

2. **Initialize `<TargetProjectPath>/Overview.md`** — this is the note every agent re-reads on
   every grounding call, so keep it plain-text and fact-dense. Nothing in it should require
   Obsidian's renderer to be useful:

```markdown
---
title: "<ProjectName>"
type: project
pillar: project
status: active
tech_stack:
  - <tech_1>
  - <tech_2>
created_at: <YYYY-MM-DD>
updated_at: <YYYY-MM-DD>
repo_path: "<relative_or_git_url>"
tags:
  - project
  - active
  - para/projects
---

# <ProjectName>

## Overview
<1-2 paragraph description of the project's purpose, domain, and primary goals>

## Architecture & Tech Stack
- **Languages & Frameworks**: <Languages/Frameworks>
- **Core Dependencies**: <Key libraries>
- **Key Subsystems**:
  - `src/...`: <Brief role>

## Voice, Tone & Design Principles
- **Tone & Voice**: <Key tone rules for UI/copy (overrides global `Areas/Tone and Voice.md` if specified)>
- **Design Tokens**: <Key styling/design system rules (overrides global `Areas/Design Tokens.md` if specified)>

## Quick Links
- Repository: `<RepoPath>`
- Decisions: [[<TargetProjectPath>/Decisions|Decisions Log]]
- Worklog: [[<TargetProjectPath>/Worklog|Worklog]]
- Tasks: [[<TargetProjectPath>/Tasks|Tasks & Backlog]]
- Optional Project Overrides:
  - [[<TargetProjectPath>/Tone and Voice|Custom Voice & Tone]] *(if overriding global)*
  - [[<TargetProjectPath>/Design Tokens|Custom Design Tokens]] *(if overriding global)*
```

   Only add a `Visual Board:` quick link and a `## 📊 Live Project Queries (Dataview)` block
   if `dataview.enabled` is true; only add the Mermaid subsystem diagram and the
   `Dashboard.canvas` companion (step 4 below) if `visual_boards.enabled` is true in
   `.agents/obsidian-config.json`. Treat the key as `true` if the config predates this option
   (don't silently strip Canvas boards from a vault that already relies on them) but default
   new vaults to `false` per `obsidian-setup`. These are human-in-Obsidian conveniences —
   an agent reading this note over MCP gets no value from a diagram it can't render, so don't
   spend the tokens on it unless someone will actually open the app to look.

3. **Initialize `<TargetProjectPath>/Decisions.md`**:
   - Call `obsidian_create_note`:

```markdown
---
title: "<ProjectName> - Decision Log"
type: decision-log
tags:
  - project/decisions
  - adr
project: "[[<TargetProjectPath>/Overview|<ProjectName>]]"
---

# <ProjectName> — Architectural Decision Records (ADRs)

This log records significant architectural, voice, styling, and structural choices.

---
```

4. **Initialize Visual Dashboard Canvas (`<TargetProjectPath>/Dashboard.canvas`)** — only if
   `visual_boards.enabled` (or `visual_boards.generate_canvas`) is `true`; skip this step
   entirely otherwise and don't link to a canvas that doesn't exist:
   - Call `obsidian_create_note`:
     - `vault`: `"<VaultName>"`
     - `path`: `"<TargetProjectPath>/Dashboard.canvas"`
     - `content`: JSON canvas structure connecting project nodes in a visual 2x2 grid:
       ```json
       {
         "nodes": [
           {"id": "node-overview", "type": "file", "file": "<TargetProjectPath>/Overview.md", "x": 0, "y": 0, "width": 450, "height": 340},
           {"id": "node-decisions", "type": "file", "file": "<TargetProjectPath>/Decisions.md", "x": 500, "y": 0, "width": 450, "height": 340},
           {"id": "node-worklog", "type": "file", "file": "<TargetProjectPath>/Worklog.md", "x": 0, "y": 380, "width": 450, "height": 340},
           {"id": "node-tasks", "type": "file", "file": "<TargetProjectPath>/Tasks.md", "x": 500, "y": 380, "width": 450, "height": 340}
         ],
         "edges": [
           {"id": "e-ov-dec", "fromNode": "node-overview", "toNode": "node-decisions", "fromSide": "right", "toSide": "left"},
           {"id": "e-ov-work", "fromNode": "node-overview", "toNode": "node-worklog", "fromSide": "bottom", "toSide": "top"},
           {"id": "e-ov-tasks", "fromNode": "node-overview", "toNode": "node-tasks", "fromSide": "bottom", "toSide": "top"}
         ]
       }
       ```

5. **Confirm to User**:
   - Emit a clean summary of newly created Obsidian notes (list `Dashboard.canvas` only if it
     was actually created per step 4):
     - `<TargetProjectPath>/Overview.md`
     - `<TargetProjectPath>/Decisions.md`
     - `<TargetProjectPath>/Dashboard.canvas` *(only when `visual_boards.enabled` is true)*

---

## 3. Branch B: Project Note Already Exists (Automated Drift Detection & Reconciliation)

If a matching project note is found (e.g. `Projects/<ProjectName>/Overview.md` or single-file `Projects/<ProjectName>.md`):

1. **Read Existing Note**:
   - Call `obsidian_read_note` on the matched note to inspect frontmatter, current content, and capture `etag`.

2. **Multi-Vector Drift Analysis**:
   Perform automated drift inspection across 4 vectors:

   - **Vector 1: Tech Stack & Dependencies**:
     - Inspect project manifests (`package.json`, `pyproject.toml`, `Cargo.toml`, `composer.json`, `go.mod`, script files).
     - Compare detected technologies against `tech_stack` frontmatter and `## Architecture & Tech Stack`.
     - Detect: newly added dependencies, removed packages, or framework upgrades.

   - **Vector 2: Subsystems & Architectural Directories**:
     - Scan top-level workspace directories (filtering out vendor/build directories like `node_modules`, `.git`, `vendor`, `dist`, `.gemini`).
     - Compare against documented subsystems in `Overview.md`.
     - Detect: new architectural components (e.g., newly added `rules/`, `plugins/`, `api/`, `services/`, `packages/`).

   - **Vector 3: Companion Notes & Visual Canvas Links**:
     - Check if companion notes exist in `<TargetProjectPath>/`:
       - `Decisions.md` (ADR log)
       - `Worklog.md` (Engineering worklog)
       - `Tasks.md` (Tasks and backlog ledger)
       - `Dashboard.canvas` (Interactive visual workspace) — **only if `visual_boards.enabled`
         is true**; if it's false, a missing canvas is expected, not drift.
     - Check `## Quick Links` in `Overview.md`.
     - Detect: missing companion notes, or missing wiki-links `[[<TargetProjectPath>/...]]`;
       flag a missing `Dashboard.canvas` only when `visual_boards.enabled` is true.

   - **Vector 4: Repository & Git State**:
     - Compare current git branch, remote URL (`git remote get-url origin`), and workspace path against frontmatter `repo_path` and status.

3. **Present Drift Audit Matrix**:
   If ANY drift is detected, present a structured audit table to the user:

   ```markdown
   ### 🔍 Obsidian Project Drift Detected: [<ProjectName>]

   | Vector | Workspace Reality | Obsidian Note (`Overview.md`) | Status |
   |---|---|---|---|
   | **Tech Stack** | `[<found_in_repo>]` | `[<found_in_note>]` | ⚠️ Outdated / New additions |
   | **Subsystems** | `[<found_subsystems>]` | `[<documented_subsystems>]` | ⚠️ Undocumented directories |
   | **Visual & Links**| `[<existing_companion_notes>]` | `[<linked_in_quick_links>]` | ⚠️ Missing canvas or wiki-links |
   | **Git / Branch** | `<current_branch>` | `<documented_state>` | ℹ️ Metadata update |
   ```

4. **Reconciliation Options (User Selection)**:
   Offer 3 non-destructive options:

   - **Option 1: Surgical Non-Destructive Reconciliation (Recommended)**:
     - Surgically update `tech_stack` in YAML frontmatter.
     - Update or append new subsystems under `## Architecture & Tech Stack` (and refresh the
       Mermaid diagram only if one is already present — don't add one that wasn't there).
     - If `visual_boards.enabled` is true, ensure `<TargetProjectPath>/Dashboard.canvas` exists
       (bootstrap if missing); if false, leave it absent.
     - Populate missing wiki-links under `## Quick Links` to point to `Decisions.md`,
       `Worklog.md`, and `Tasks.md` (plus `Dashboard.canvas` only when it exists).
     - **Preserve all custom descriptions, manual notes, and user text byte-for-byte**.
     - Call `obsidian_edit_note` with `operation: "replace"` and `if_match: "<etag>"`.
   - **Option 2: Append Drift Audit Log**:
     - Preserve existing overview note exactly as-is.
     - Append a dated audit entry under `## Drift & Sync Audit` documenting the findings.
   - **Option 3: Keep As-Is**:
     - Leave Obsidian untouched; load existing note into active context.

5. **Reconciliation Receipt**:
   Emit a clean receipt upon completion:
   > 🔄 **Obsidian Project Reconciled**: Updated `Overview.md` for `<ProjectName>` (Tech stack + subsystems + quick links synchronized).

---

## 4. Error Handling & Guardrails

- **MCP Server Missing / Unreachable**: If `obsidian` MCP tools (`obsidian_search_vault`, `obsidian_create_note`, etc.) are not available, halt and advise the user to run `/obsidian-setup` or configure the `obsidian-mcp` server in their agent MCP settings.
- **Vault Not Connected / Missing**: If the configured vault is unreachable, call `obsidian_list_vaults` and prompt the user to pick an active vault.
- **Etag Conflict on Edit**: If `obsidian_edit_note` returns a 412/etag mismatch, execute bounded 3-attempt backoff (500ms, 1500ms). If all attempts fail, queue payload to `.agents/pending-sync.json` for later flush.
- **Never Overwrite Blindly**: Never replace entire note content without preserving existing non-metadata text written by the user. Always use `if_match` revision guards.
