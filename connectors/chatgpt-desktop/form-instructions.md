# ChatGPT Desktop MCP Form Configuration

OpenAI provides a visual modal form in the **ChatGPT Desktop App** (Windows and macOS) to connect local MCP servers.

---

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

In your **ChatGPT Custom Instructions** (or Custom GPT / Project settings), paste this block so ChatGPT automatically recognizes and prioritizes the vault:

```markdown
You have direct access to our local Obsidian Second Brain via the connected `obsidian` MCP tools (`obsidian_search_vault`, `obsidian_read_note`, `obsidian_create_note`, `obsidian_edit_note`).

Key Directives:
1. Always search or read vault notes (specifically `AI CONTEXT.md` and active project notes) before answering strategic questions or drafting copy.
2. When creating notes, use standardized markdown formatting, clean kebab-case filenames, and frontmatter.
3. When updating worklogs, append timestamped updates using the format `### YYYY-MM-DD — @author`.
```
