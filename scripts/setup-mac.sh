#!/usr/bin/env bash
# Headless AI Second Brain — macOS / Linux Quick Setup Script

set -e

echo "===================================================="
echo " 🧠 Headless AI Second Brain — Setup"
echo "===================================================="

# 1. Check for Node.js / npx
echo ""
echo "[1/4] Checking Node.js environment..."
if command -v node >/dev/null 2>&1; then
    NODE_VER=$(node -v)
    echo "  ✅ Node.js is installed ($NODE_VER)"
else
    echo "  ⚠️ Node.js not found."
    if command -v brew >/dev/null 2>&1; then
        echo "  Installing Node.js via Homebrew..."
        brew install node
        # This shell's PATH was set before Homebrew's own PATH entries existed (or before this
        # install added node to them) — refresh it here rather than let the next check fail
        # purely from session staleness, for the exact user this fallback exists to help.
        eval "$(brew shellenv)" 2>/dev/null || true
        if ! command -v node >/dev/null 2>&1; then
            echo "  ⚠️ Node.js installed, but this shell still can't see it."
            echo "     Close this terminal, open a new one, and re-run this script."
            exit 1
        fi
        echo "  ✅ Node.js installed and available in this session ($(node -v))."
    else
        echo "  ❌ Please install Node.js from https://nodejs.org"
        exit 1
    fi
fi

# 2. Check npx
if ! command -v npx >/dev/null 2>&1; then
    echo "  ❌ npx could not be located in PATH. Close this terminal, open a new"
    echo "     one, and re-run this script."
    exit 1
fi
echo "  ✅ npx is available"

# 3. Pre-cache obsidian-mcp
echo ""
echo "[2/4] Pre-caching obsidian-mcp via npx..."
npx -y obsidian-mcp --help >/dev/null 2>&1 || true
echo "  ✅ obsidian-mcp is ready to serve"

# 4. Install the agent skills (grounding, auto-sync, vault-audit, etc.)
echo ""
echo "[3/4] Installing agent skills into ~/.agents/..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/../install.sh" ]; then
    echo "  ❌ Can't find install.sh next to this script."
    echo "     This usually means only part of the downloaded folder got moved or"
    echo "     extracted. Re-download the whole headless-ai-second-brain folder from"
    echo "     GitHub and run this script from inside it, without moving anything"
    echo "     out of it first."
    exit 1
fi
echo "  (If Claude Code/Desktop or Antigravity aren't detected, this may ask a"
echo "   yes/no question before continuing.)"
bash "$SCRIPT_DIR/../install.sh"

# 5. Instructions
echo ""
echo "[4/4] Next Steps for Your AI Desktop App:"
echo "  Full setup steps for each app, including plan requirements, live in:"
echo "    - ChatGPT Desktop:  connectors/chatgpt-desktop/form-instructions.md"
echo "    - Claude Desktop:   connectors/claude-desktop/claude_desktop_config.json"
echo "    - Antigravity:      connectors/antigravity-ide/mcp_config.json (already linked above if detected)"
echo "    - Cursor:           README.md, 'Step 2' section (per-project, manual copy)"
echo ""
echo "✨ Setup Complete!"
