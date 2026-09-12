---
name: obsidian-setup
description: >
  Interactive setup wizard for Obsidian integration. Discovers available vaults,
  configures default vault preferences, validates foundational folder structure
  (Projects/, System/), and bootstraps core voice/design/architecture notes.
  Run once on initial setup or anytime you want to reconfigure Obsidian settings.
---

# Obsidian Integration Setup Wizard

Interactive configuration wizard for connecting AI agent workflows to your Obsidian knowledge base.

## 0. Multi-Provider Detection & Health Check

Before attempting any vault operations, detect available communication providers:

1. **Provider Auto-Detection Priority**:
   - Check `.agents/obsidian-config.json` for `provider` (defaults to `"auto"`).
   - **Provider 1: Headless MCP / In-App MCP Toolset (`headless_mcp` / `mcp_connector`)**:
     - Check if `obsidian_list_vaults` exists in the active agent tool definitions and responds.
     - If available, probe succeeded using native MCP tools.
   - **Provider 2: Obsidian Local REST API (`local_rest_api`)**:
     - If MCP toolset is not present or user selected `local_rest_api`:
     - Test HTTPS connection to `https://127.0.0.1:27124/` using `OBSIDIAN_REST_API_KEY` (or key from config).
     - If reachable (HTTP 200 / authentication verified), probe succeeded via Local REST API.

2. **If Neither Provider is Detected**:
   - **Immediately stop** the setup wizard.
   - Present a clear, actionable diagnostic guide with setup options for both providers:

```markdown
> 🛑 **Obsidian Provider Not Detected or Unreachable**
>
> To connect your AI agent to your Obsidian vault, choose one of the following two providers:
>
> ---
>
> ### Option A: Headless MCP Server (Recommended for CLI / Background Agents)
> Uses [`obsidian-mcp`](https://github.com/StevenStavrakis/obsidian-mcp). Operates directly on vault files without requiring the Obsidian desktop app to be open.
>
> #### 1. Antigravity IDE
> Add to `~/.gemini/config/mcp_config.json`:
> **Windows**:
> ```json
> {
>   "mcpServers": {
>     "obsidian": {
>       "command": "cmd.exe",
>       "args": [
>         "/c",
>         "npx",
>         "-y",
>         "obsidian-mcp",
>         "serve",
>         "--vault",
>         "<vault_name>=<absolute_path_to_vault>"
>       ]
>     }
>   }
> }
> ```
> **macOS / Linux**:
> ```json
> {
>   "mcpServers": {
>     "obsidian": {
>       "command": "npx",
>       "args": [
>         "-y",
>         "obsidian-mcp",
>         "serve",
>         "--vault",
>         "<vault_name>=<absolute_path_to_vault>"
>       ]
>     }
>   }
> }
> ```
>
> #### 2. Claude Desktop / Claude Code
> Add to `claude_desktop_config.json`:
> ```json
> {
>   "mcpServers": {
>     "obsidian": {
>       "command": "npx",
>       "args": [
>         "-y",
>         "obsidian-mcp",
>         "serve",
>         "--vault",
>         "<vault_name>=<absolute_path_to_vault>"
>       ]
>     }
>   }
> }
> ```
> *(On Windows, use `command: "cmd.exe"` with `args: ["/c", "npx", ...]`)*.
>
> #### 3. Cursor
> Under **Cursor Settings > Features > MCP Servers**, add:
> - **Name**: `obsidian`
> - **Type**: `command`
> - **Command**: `npx -y obsidian-mcp serve --vault <vault_name>=<absolute_path_to_vault>`
>
> ---
>
> ### Option B: Obsidian Local REST API Plugin (Recommended for Live Desktop Users)
> Uses the [Obsidian Local REST API](https://github.com/coddingtonbear/obsidian-local-rest-api) community plugin. Integrates with live Obsidian desktop plugins (Dataview, Graph View, and canvas refresh).
>
> 1. In Obsidian, open **Settings > Community plugins > Browse** and install **Local REST API**.
> 2. Enable the plugin and copy your generated **API Key** from the plugin settings.
> 3. Export your API key in your shell profile or environment:
>    - **Windows (PowerShell)**: `[Environment]::SetEnvironmentVariable("OBSIDIAN_REST_API_KEY", "<your_api_key>", "User")`
>    - **macOS / Linux**: `export OBSIDIAN_REST_API_KEY="<your_api_key>"`
> 4. In `.agents/obsidian-config.json`, set `"provider": "local_rest_api"`.
>
> ---
>
> 🔄 **After Setup**: Restart or reload your AI agent session, then re-run `/obsidian-setup`.
```

---

## 1. Vault Discovery & Configuration

1. **Resolve Provider**:
   - If multiple providers respond, prompt the user for their preferred provider (`headless_mcp`, `local_rest_api`, or `auto`).
2. **List Available Vaults**:
   - **MCP**: Call `obsidian_list_vaults` to discover all mounted vault IDs.
   - **Local REST API**: Query `/` to confirm the connected active vault.
3. **Confirm Default Vault**:
   - Prompt the user to select or confirm the primary vault (e.g., `personal` or `work`).
4. **Persist Configuration**:
   - Save or update `.agents/obsidian-config.json`:
     ```json
     {
       "layout": "para",
       "para": {
         "projects_dir": "Projects",
         "areas_dir": "Areas",
         "resources_dir": "Resources",
         "archives_dir": "Archives"
       },
       "provider": "auto",
       "providers": {
         "headless_mcp": {
           "type": "mcp_toolset",
           "description": "Direct filesystem headless MCP server via npx obsidian-mcp"
         },
         "local_rest_api": {
           "type": "https_rest",
           "base_url": "https://127.0.0.1:27124",
           "api_key_env": "OBSIDIAN_REST_API_KEY",
           "insecure_ssl": true
         },
         "mcp_connector": {
           "type": "in_app_mcp",
           "description": "In-app Obsidian community plugin (obsidian-mcp-plugin) exposing MCP tools"
         }
       },
       "default_vault": "main",
       "organization_nesting": "auto",
       "worktree_support": true,
       "adrs_per_context_limit": 5,
       "dataview": {
         "enabled": true,
         "render_dynamic_queries": true
       },
       "auto_sync": {
         "enabled": true,
         "on_commit": true,
         "on_decision": true,
         "on_todo": true,
         "filters": {
           "commit_level": "milestones_only",
           "rollup_window_hours": 2
         },
         "worklog_archive_limit_lines": 1000
       },
       "global_notes": {
         "tone_and_voice": "Areas/Tone and Voice.md",
         "design_tokens": "Areas/Design Tokens.md",
         "architecture": "Areas/Architecture Principles.md"
       },
       "legacy_fallbacks": {
         "system_dir": "System"
       }
     }
     ```

---

## 2. Vault Structure Inspection (The PARA Framework)

Validate that the vault adheres to Tiago Forte's **PARA** organizational model:

1. **Projects Directory (`Projects/`)**:
   - Query `obsidian_search_vault` with `scope: "Projects"`.
   - Purpose: Active repositories, codebases, deliverables, and goal-oriented initiatives.
   - If missing, create `Projects/` via `obsidian_create_directory`.

2. **Areas Directory (`Areas/`)**:
   - Query `obsidian_search_vault` with `scope: "Areas"`.
   - Purpose: Ongoing standards, architectural principles, voice/tone rules, and design systems.
   - *Legacy Fallback*: If `System/` exists, ask user if they want to retain it or migrate to `Areas/`.
   - If missing and no `System/` exists, create `Areas/` via `obsidian_create_directory`.

3. **Resources Directory (`Resources/`)**:
   - Query `obsidian_search_vault` with `scope: "Resources"`.
   - Purpose: Reference libraries, external API specs, prompt playbooks, and cheat-sheets.
   - If missing, create `Resources/` via `obsidian_create_directory`.

4. **Archives Directory (`Archives/`)**:
   - Query `obsidian_search_vault` with `scope: "Archives"`.
   - Purpose: Inactive projects, deprecated architectures, and rotated historical worklogs (`Archives/Worklogs/`).
   - If missing, create `Archives/` via `obsidian_create_directory`.

---

## 3. Global Knowledge Note Bootstrapping (Areas of Responsibility)

Check if foundational directives exist in `Areas/` (falling back to `System/` if present), and bootstrap starter templates for any that are missing:

### A. `Areas/Tone and Voice.md`
If missing, offer to create with template:
```markdown
---
title: "Global Tone & Voice Guidelines"
type: area-directive
tags: [area, voice, tone, style, para/areas]
---

# Tone & Voice Guidelines

Authoritative voice, tone, and communication principles to ground all user-facing copy, documentation, and agent responses.

## Core Tone Principles
1. **Clear & Concise**: Favor direct, active sentences over verbose fluff.
2. **Humanized & Natural**: Avoid corporate buzzwords, excessive signpost transitions, and formulaic AI writing patterns.
3. **Accurate & Unambiguous**: Be precise with technical terminology and instructions.

## UI Copy Standards
- **Buttons**: Short, action-oriented verbs (e.g. "Create Project", "Sync Changes").
- **Error Messages**: Explain what happened clearly and provide a concrete recovery action.
- **Empty States**: Friendly guidance on what to do first.
```

### B. `Areas/Design Tokens.md`
If missing, offer to create with template:
```markdown
---
title: "Global Design System & Styling Rules"
type: area-directive
tags: [area, design, styling, tokens, para/areas]
---

# Design System & Styling Tokens

Authoritative design rules, typography, and color palettes for web apps and user interfaces.

## Aesthetics & Theme
- **Theme**: Dark mode first, sleek glassmorphism accents, subtle micro-interactions.
- **Typography**: Modern Google Fonts (e.g., Inter, Plus Jakarta Sans, Outfit).
- **Color Palette**: Curated HSL tokens with high contrast and harmonious accent gradients.

## Component Rules
- Avoid generic browser default inputs; use crafted states (hover, focus-visible, active).
- Maintain responsive fluid layouts with container queries and modern CSS variables.
```

### C. `Areas/Architecture Principles.md`
If missing, offer to create with template:
```markdown
---
title: "Engineering & Architecture Principles"
type: area-directive
tags: [area, architecture, engineering, para/areas]
---

# Engineering & Architecture Principles

Core architectural standards across repositories and projects.

## Standards
- **DRY & Modular**: Keep components focused on a single responsibility.
- **Explicit over Clever**: Write readable, well-typed, and maintainable code.
- **Decision Records**: Log all major architectural pivots and rejected alternatives to `Decisions.md`.
```

### D. `Resources/README.md`
If missing, offer to create reference index starter:
```markdown
---
title: "Resources & Reference Index"
type: resource-index
tags: [resource, cheatsheets, references, para/resources]
---

# Resources & Reference Index

Shared reference materials, API contracts, prompt packs, and technical cheatsheets accessible across all projects.
```

---

## 3.5 The AI Constitution (`AI CONTEXT.md`)

Check for `<vault_root>/<ai_context.path>` (default `AI CONTEXT.md` at vault root — this must
match whatever filename `obsidian-rag-grounding` actually looks for; don't let the two drift).
This
is the one note every downstream skill (`obsidian-rag-grounding` first and foremost) reads
before anything else — voice thesis, banned vocabulary, archetype rules, and non-negotiable
operational guardrails, all in one short file.

If missing, offer to bootstrap it from `skills/obsidian-rag/templates/AI-CONTEXT.md.example`.
Do not fill in the placeholders yourself — ask the user for their operating thesis, banned
words, and archetypes, or leave them as visible `<placeholder>` text for them to fill in later.

### Visual Boards: Default Off
Ask the user directly: *"Generate Canvas boards and Mermaid diagrams for every project
(visual, but only useful when someone opens Obsidian), or keep notes plain-text only (leaner
for agents, matches a headless workflow)?"* Persist the answer to `visual_boards.enabled`.
Default to `false` for new vaults — a plain-text `Overview.md` is what every agent actually
reads on every grounding call; Canvas/Mermaid ceremony is opt-in polish for humans who do open
the app. An existing vault with `Dashboard.canvas` files already in place may prefer `true` to
avoid orphaning them — ask rather than assume.

---

## 4. Autonomous Live-Sync Configuration

Ask the user if they would like the agent to autonomously keep Obsidian updated as work happens:

1. **Prompt for Live Sync & Filter Thresholds**:
   - Ask if they want autonomous synchronization enabled:
     - Commits logged to `Projects/<ProjectName>/Worklog.md` (with "1 Milestone per Rollup" lifecycle)
     - Tasks/TODOs logged to `Projects/<ProjectName>/Tasks.md`
     - Architectural decisions logged to `Projects/<ProjectName>/Decisions.md`
   - Ask for their preferred commit verbosity:
     - **Milestones Only (Recommended)**: Filters out minor formatting, lints, and typos; rolls up supporting work into 1 milestone per block.
     - **All Commits**: Records every commit unconditionally.
2. **Persist Toggles**:
   - Update `auto_sync` in `.agents/obsidian-config.json`:
     ```json
     "auto_sync": {
       "enabled": true,
       "on_commit": true,
       "on_decision": true,
       "on_todo": true,
       "filters": {
         "commit_level": "milestones_only",
         "rollup_window_hours": 2
       },
       "worklog_archive_limit_lines": 1000
     }
     ```

---

## 5. Verification & Summary

1. **Verify Tool Permissions**:
   - Confirm read, write, and search operations succeed against the selected vault.
2. **Present Final Setup Summary**:
   - Display configured vault name, detected directories, auto-sync status, and available global notes.
   - Summarize how downstream skills (`obsidian-project-init`, `obsidian-rag-grounding`, `obsidian-decision-sync`, `obsidian-auto-sync`) will use this configuration.
