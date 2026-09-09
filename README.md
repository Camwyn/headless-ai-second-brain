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
├── connectors/                         # Plug-and-play AI configs
│   ├── chatgpt-desktop/                # Exact visual form instructions & prompts
│   ├── claude-desktop/                 # claude_desktop_config.json snippet
│   └── antigravity-ide/                # Universal agent mcp_config.json snippet
│
└── scripts/                            # 1-Click setup automation
    ├── setup-windows.ps1               # Automated Windows Node & MCP installer
    └── setup-mac.sh                    # Automated macOS/Linux Node & MCP installer
```

---

## 🚀 5-Minute Quickstart

### Step 1: Copy the Vault Skeleton
1. Copy the contents of `vault-template/` to your chosen local folder (e.g. `C:\Users\username\Documents\Obsidian\my-vault` or `~/Documents/Obsidian/my-vault`).
2. (Optional) Open the folder once in Obsidian if you want to verify the visual graph or enable **Obsidian Sync** with End-to-End Encryption for your team.

### Step 2: Run the Setup Script
Run the automated setup script for your operating system:

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

### Step 3: Connect Your AI App

#### 💬 Option A: ChatGPT Desktop (Windows & Mac)
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
