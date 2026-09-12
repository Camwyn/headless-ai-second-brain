# 🧠 Headless AI Second Brain Starter Kit
*An autonomous, human-friendly knowledge architecture for solo builders, studios, and teams powered by Obsidian & Model Context Protocol (MCP).*

---

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![MCP Compatible](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io)
[![Obsidian Ready](https://img.shields.io/badge/Obsidian-Ready-purple.svg)](https://obsidian.md)

---

## 🎯 The Philosophy

Most "Second Brain" setups fail for the same reason home gyms collect dust: **the maintenance overhead exceeds the daily value.** You spend three hours designing folders, configuring Dataview plugins, and color-coding tags—only to dread opening the app next Tuesday.

The **Headless AI Second Brain** flips this on its head:

- **The filesystem is the database.** Your notes are 100% plain Markdown files on your hard drive. No SaaS lock-in, no database servers.
- **You don't need to open Obsidian.** Your AI assistants (**ChatGPT Desktop**, **Claude Desktop**, **Antigravity**, **Cursor**) interact directly with the files via the [Model Context Protocol (MCP)](https://modelcontextprotocol.io) and [`obsidian-mcp`](https://github.com/StevenStavrakis/obsidian-mcp).
- **Non-technical friendly.** Collaborators, clients, or partners can talk to their AI in plain English (*"Draft a dispatch based on our brand voice"* or *"What's the status of Project Alpha?"*) and the AI reads and writes the notes headlessly in the background.

```
┌─────────────────────────────────────────────────────────────┐
│                    Any AI Interface                         │
│       (ChatGPT Desktop · Claude Desktop · IDE Agents)       │
└──────────────────────────────┬──────────────────────────────┘
                               │ MCP Protocol (obsidian-mcp)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│            Headless Local Obsidian Vault Files              │
│                 (No App Needs to Be Open!)                  │
├─────────────────────────────────────────────────────────────┤
│ • 00-INBOX/        — Frictionless capture for humans & AIs  │
│ • AI CONTEXT.md    — The Brand Constitution & AI Guardrails │
│ • PARA-Index.md    — Authoritative Map of Content (MOC)     │
│ • Projects/        — Active sprints, tasks & worklogs       │
│ • Areas/           — Standards, governance & business pillars│
│ • Resources/       — Knowledge bases & playbooks            │
│ • Archives/        — Historical milestone records           │
└──────────────────────────────┬──────────────────────────────┘
                               │ Background Sync
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 Remote Vault / Team Sync                    │
│      (Obsidian Sync · Private GitHub Repo · Cloud Mirror)   │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 What's Included

```text
headless-ai-second-brain/
├── README.md                           # Master guide and setup tutorial
├── LICENSE                             # Open-source MIT License
├── .gitignore                          # Pre-configured to ignore personal caches
├── install.ps1 / install.sh            # Links/copies skills, rules, hooks & CLI into ~/.agents/
│
├── vault-template/                     # Sanitized PARA vault skeleton
│   ├── AI CONTEXT.md                   # The "Constitution" template for brand & voice
│   ├── PARA-Index.md                   # Master MOC index with Dataview DQL blocks
│   ├── 00-INBOX/                       # Zero-friction quick capture
│   ├── Projects/_template-project/     # Overview.md, Tasks.md, Worklog.md
│   ├── Areas/                          # Domain and standard directories
│   ├── Resources/                      # Knowledge bases & references
│   └── Archives/                       # Historical records & retrospectives
│
├── skills/                             # The agent behavior this kit is actually named for
│   ├── SYNCED-FROM.md                  # Provenance note — kept as a deliberate copy, not a submodule
│   └── obsidian-rag/                   # Grounding, auto-sync, vault-audit, project-init, digest, ADRs
│
├── rules/                              # obsidian-live-sync.md + content-mirror-sync.md (declared repo<->vault mirrors)
├── hooks/                              # Claude Code SessionStart / PostToolUse hook adapters
├── scripts/                            # Sync engines (audit-vault, generate-digest, post-commit)
│   ├── setup-windows.ps1               # Automated Windows Node, MCP & skills installer
│   └── setup-mac.sh                    # Automated macOS/Linux Node, MCP & skills installer
├── bin/                                # Standalone obsidian-sync CLI (status/flush/audit/digest)
│
└── connectors/                         # Plug-and-play AI configs
    ├── chatgpt-desktop/                # Exact visual form instructions & prompts
    ├── claude-desktop/                 # claude_desktop_config.json snippet
    └── antigravity-ide/                # Universal agent mcp_config.json snippet
```

> **Without `skills/`, this is just an organized folder.** The vault skeleton and MCP wiring
> get an AI reading and writing your notes; the skills are what make it *autonomous* — logging
> worklogs on commit, keeping ADRs, auditing vault health — instead of something you have to
> ask for every time. `install.ps1` / `install.sh` (run automatically by the setup scripts
> below) link them into `~/.agents/` so any MCP-capable agent can use them.

---

## 🚀 5-Minute Quickstart

> Keep the whole folder you cloned or downloaded around until Step 3 is done — Step 1 only
> copies `vault-template/` elsewhere, but Steps 2 and 3 still need `install.ps1`/`install.sh`,
> `scripts/`, and `connectors/` from this same folder.

### Step 1: Copy the Vault Skeleton
1. Copy the contents of `vault-template/` to your chosen local folder (e.g. `C:\Users\username\Documents\Obsidian\my-vault` or `~/Documents/Obsidian/my-vault`).
2. (Optional) Open the folder once in Obsidian if you want to verify the visual graph or enable **Obsidian Sync** with End-to-End Encryption for your team.

### Step 2: Run the Setup Script
Run the automated setup script for your operating system. This checks Node.js, pre-caches
`obsidian-mcp`, and installs the skills in `skills/obsidian-rag/`. Installation is
detection-based, not one-size-fits-all:
- **`~/.agents/skills`** — always installed. This is where Codex and the emerging cross-tool
  `SKILL.md` convention read from; it isn't specific to one app, so there's nothing to detect.
- **`~/.claude/skills`** — only installed if Claude Code or Claude Desktop is already present
  on your machine (or you say yes to a one-time prompt). It will not create a `~/.claude/`
  folder for an app you don't have — see `install.ps1 -InstallClaude` / `-SkipClaude` to force
  either way non-interactively.
- **`~/.gemini/config/skills`** — Antigravity's global skills directory, same detection-based
  treatment as Claude (`-InstallAntigravity` / `-SkipAntigravity`). Antigravity *also* reads a
  project-level `<repo>/.agents/skills/` walking up to the git root — commit that folder in a
  given project to share skills with a team there, independent of the global install.
- **Cursor** reads skills per-project from `.cursor/skills/`, not a global folder — copy
  `skills/obsidian-rag/*` there manually in each project where you want them.
- **ChatGPT** (the chat product) doesn't scan a local folder — its Skills feature is
  upload-only (`.zip` via Plugins → Skills) and limited to Business/Enterprise/Healthcare/Edu
  accounts, not personal Free/Plus/Pro plans. `.agents/skills` is read by **Codex**, a
  different OpenAI product despite the shared branding. See Step 3's custom instructions
  snippet instead — that's the real substitute for most ChatGPT users, not a fallback.

Run `install.ps1` / `install.sh` directly (also called automatically by the setup scripts
below) if you want to re-run just this step, or pass `-Copy` for real copies instead of the
default directory-junction/symlink behavior.

**On Windows (PowerShell):**
```powershell
.\scripts\setup-windows.ps1
```

**On macOS / Linux:**
```bash
chmod +x ./scripts/setup-mac.sh
./scripts/setup-mac.sh
```

*(This verifies Node.js and pre-caches `obsidian-mcp` automatically).*

> **If you don't already have Node.js installed**, the script installs it for you (via
> `winget` on Windows, `brew` on macOS) — that part may pop up its own confirmation window
> (Windows may ask for administrator permission). If the script then tells you to close and
> reopen your terminal, that's expected — a freshly-installed program isn't always visible to
> a terminal window that was already open before the install happened. Just do what it says
> and run the same command again in the new window; nothing gets damaged by running it twice.

### Step 3: Connect Your AI App

> **Windows users, one thing to watch for:** wherever you paste your vault path below (or
> into the Claude Desktop JSON file), **never end it with a trailing backslash** before the
> closing quote — `"C:\Users\you\vault\"` breaks both a plain command and a JSON file, because
> that backslash escapes the quote instead of just being part of the path. Drop the trailing
> backslash: `"C:\Users\you\vault"` is correct.

#### 💬 Option A: ChatGPT Desktop (Windows & Mac)

> **Prerequisite:** Connecting custom MCP servers in ChatGPT requires **Plus, Pro, Business,
> Enterprise, or Edu** — not available on the Free plan. (Separately, ChatGPT's own upload-based
> Skills feature is Business/Enterprise/Edu-only, but this setup doesn't use it — grounding on
> `AI CONTEXT.md` comes from the pasted custom-instructions block below, available on any paid
> plan.)

1. In ChatGPT Desktop, open **Settings → Developer / Advanced → MCP Servers → Add Server**.
2. Fill out the form:
   - **Name:** `obsidian`
   - **Command:** `cmd.exe` (Windows) or `npx` (macOS)
   - **Arguments:** `/c npx -y obsidian-mcp serve --vault main="<YOUR_LOCAL_VAULT_PATH>"`
3. Save and restart ChatGPT.

#### 🤖 Option B: Claude Desktop (Windows & Mac)
1. Open your Claude Desktop configuration file:
   - **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
   - **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
2. Paste the JSON from `connectors/claude-desktop/claude_desktop_config.json` and insert your vault path.
3. Restart Claude Desktop.

---

## 💡 How to Use It Daily

You and your team can now interact with the vault conversationally:

| What you tell your AI assistant | What the AI does behind the scenes |
| :--- | :--- |
| *"What are our approved brand colors and voice rules?"* | Reads `AI CONTEXT.md` and gives you the exact guidelines. |
| *"What tasks are currently open under Project Alpha?"* | Scans `Projects/Project Alpha/Tasks.md` and outputs a clean checklist. |
| *"Draft a dispatch about our new launch and save it."* | References your brand guidelines, crafts the article, and calls `obsidian_create_note`. |
| *"Add a note to today's worklog that we finalized the API."* | Appends a timestamped entry with author attribution to `Worklog.md`. |

---

## 🧠 Skills Included (`skills/obsidian-rag/`)

| Skill | Trigger / Command | Description |
|---|---|---|
| **obsidian-setup** | `/obsidian-setup` | Discovers vaults, validates PARA folders, bootstraps `AI CONTEXT.md`. Run this first. |
| **obsidian-project-init** | `/obsidian-init` | Scans the current repo, creates `Overview.md`/`Decisions.md` in the vault, detects drift on repeat runs. |
| **obsidian-rag-grounding** | `/obsidian-rag` | Reads `AI CONTEXT.md` plus project/area overrides before creative or architectural work. |
| **obsidian-auto-sync** | Autonomous / `/obsidian-flush` | Logs commits to `Worklog.md`, tasks to `Tasks.md`, decisions to `Decisions.md`. |
| **obsidian-decision-sync** | `/obsidian-decision` | Formats a choice into a structured ADR with rejected alternatives. |
| **obsidian-vault-audit** | `/audit-vault` | Health score, broken links, missing companion notes, drifted content mirrors. |
| **obsidian-mirror** | `/obsidian-mirror` | Establishes or re-syncs a declared repo↔vault content mirror — full, independent, kept-in-sync copies (see `rules/content-mirror-sync.md`), not a canonical-plus-stub pair. |
| **obsidian-index** | `/obsidian-index` | Builds `PARA-Index.md`, the master map of content. |
| **obsidian-digest** | `/obsidian-digest` | Weekly/monthly rollup across all active projects. |

Full details for each live in its own `SKILL.md`; see `skills/SYNCED-FROM.md` for how this
folder relates to its private upstream.

---

## 🛠️ Modified PARA/BASB Architecture

This starter kit implements a **modified PARA (Projects, Areas, Resources, Archives)** structure tailored specifically for AI agents and human teams:

1. **`00-INBOX/`**: A frictionless landing zone. Capture raw voice memos, unformatted meeting notes, or rough links. Let your AI synthesize them during weekly reviews.
2. **`Projects/`**: Goal-oriented initiatives with clear completion criteria. Every project contains `Overview.md`, `Tasks.md`, and `Worklog.md`.
3. **`Areas/`**: Permanent standards, brand identity, governance, and responsibilities with no end date.
4. **`Resources/`**: Reference playbooks, how-to guides, and curated discipline knowledge bases.
5. **`Archives/`**: Historical milestone histories, completed projects, and sunset experiments.

---

## 📄 License

Created by **[Camwyn & Co](https://camwyn.com)** — An independent house of projects.  
Distributed under the **MIT License**. See [LICENSE](LICENSE) for details.
