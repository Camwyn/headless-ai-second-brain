# ChatGPT Desktop MCP Form Configuration

OpenAI provides a visual modal form in the **ChatGPT Desktop App** (Windows and macOS) to connect local MCP servers.

> **Prerequisite:** Connecting custom MCP servers in ChatGPT requires **Plus, Pro, Business,
> Enterprise, or Edu** — not available on the Free plan. (Separately, ChatGPT's own upload-based
> Skills feature is Business/Enterprise/Edu-only, but this setup doesn't use it — grounding on
> `AI CONTEXT.md` comes from the pasted custom-instructions block below, available on any paid
> plan.)

---

> **Windows users:** never end your vault path with a trailing backslash before the closing
> quote — `"C:\Users\you\vault\"` breaks the command because that backslash escapes the quote
> instead of just being part of the path. Use `"C:\Users\you\vault"` (no trailing `\`).

## 📋 Field-by-Field Instructions

1. Open **ChatGPT Desktop**.
2. Click your profile icon in the bottom-left / top-right → **Settings → Developer / Advanced → MCP Servers**.
3. Click **Add Server** or **New Connection**.

Fill out the form fields as follows:

---

### On Windows:

| Form Field | Value |
| :--- | :--- |
| **Name / Server ID** | `obsidian` |
| **Type / Transport** | `stdio` *(or Command)* |
| **Command** | `cmd.exe` |
| **Arguments** | `/c npx -y obsidian-mcp serve --vault main="C:\Users\username\Documents\Obsidian\my-vault"` |
| **Environment Variables** | *(Leave blank)* |
| **Working Directory** | *(Leave blank)* |

> **Note on Arguments:** If the ChatGPT form separates arguments into individual lines or pills, enter:
> 1. `/c`
> 2. `npx`
> 3. `-y`
> 4. `obsidian-mcp`
> 5. `serve`
> 6. `--vault`
> 7. `main=C:\Users\username\Documents\Obsidian\my-vault`

---

### On macOS / Linux:

| Form Field | Value |
| :--- | :--- |
| **Name / Server ID** | `obsidian` |
| **Type / Transport** | `stdio` *(or Command)* |
| **Command** | `npx` |
| **Arguments** | `-y obsidian-mcp serve --vault main="/Users/username/Documents/Obsidian/my-vault"` |
| **Environment Variables** | *(Leave blank)* |
| **Working Directory** | *(Leave blank)* |

---

## 🎯 Recommended System Instructions for ChatGPT

> **Why paste this instead of installing a Skill:** ChatGPT's own Skills feature is
> upload-only (**Plugins → Skills → Create → Upload from your computer**, a `.zip`, not a
> local folder ChatGPT scans automatically) and — as of writing — limited to Business,
> Enterprise, Healthcare, and Edu accounts, not personal Free/Plus/Pro plans. `.agents/skills`
> (what `install.ps1`/`install.sh` populate) is read by **Codex**, not by ChatGPT itself —
> different product, despite the shared branding. For a personal-plan ChatGPT setup, this
> pasted instructions block is the practical substitute for the real skill; on an eligible
> workspace plan, you could instead zip `skills/obsidian-rag/obsidian-rag-grounding/` and
> upload it as a proper Skill.

In your **ChatGPT Custom Instructions** (or Custom GPT / Project settings), paste this block so ChatGPT automatically recognizes and prioritizes the vault:

```markdown
You have direct access to our local Obsidian Second Brain via the connected `obsidian` MCP tools (`obsidian_search_vault`, `obsidian_read_note`, `obsidian_create_note`, `obsidian_edit_note`).

Key Directives:
1. Always search or read vault notes (specifically `AI CONTEXT.md` and active project notes) before answering strategic questions or drafting copy.
2. When creating notes, use standardized markdown formatting, clean kebab-case filenames, and frontmatter.
3. When updating worklogs, append timestamped updates using the format `### YYYY-MM-DD — @author`.
4. When asked for a status update or "what's going on," also check the `00-INBOX/` folder (excluding its `Processed/` subfolder) for unfiled notes and mention how many there are, especially any that look more than a week old. Never move or delete an inbox note without being asked — just flag it and offer to help file it.
```

> **Why this can't run on its own schedule:** ChatGPT's scheduled tasks don't inherit this MCP
> connection (confirmed directly, not assumed — see `skills/SYNCED-FROM.md`), so there's no way
> to make this check happen automatically here. Ask for a status update when you want one; it
> won't happen ambiently the way a scheduled headless agent (Claude Code, Codex) could.
