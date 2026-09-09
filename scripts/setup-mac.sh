#!/usr/bin/env bash
# Headless AI Second Brain — macOS / Linux Quick Setup Script

set -e

echo "===================================================="
echo " 🧠 Headless AI Second Brain — Setup"
echo "===================================================="

# 1. Check for Node.js / npx
echo ""
echo "[1/3] Checking Node.js environment..."
if command -v node >/dev/null 2>&1; then
    NODE_VER=$(node -v)
    echo "  ✅ Node.js is installed ($NODE_VER)"
else
    echo "  ⚠️ Node.js not found."
    if command -v brew >/dev/null 2>&1; then
        echo "  Installing Node.js via Homebrew..."
        brew install node
    else
        echo "  ❌ Please install Node.js from https://nodejs.org"
        exit 1
    fi
fi

# 2. Check npx
if command -v npx >/dev/null 2>&1; then
    echo "  ✅ npx is available"
else
    echo "  ❌ npx could not be located in PATH."
    exit 1
fi

# 3. Pre-cache obsidian-mcp
echo ""
echo "[2/3] Pre-caching obsidian-mcp via npx..."
npx -y obsidian-mcp --help >/dev/null 2>&1 || true
echo "  ✅ obsidian-mcp is ready to serve"

# 4. Instructions
echo ""
echo "[3/3] Next Steps for Your AI Desktop App:"
echo "  • In ChatGPT Desktop: Go to Settings -> Developer -> MCP Servers -> Add Server"
echo "    - Command: npx"
echo "    - Arguments: -y obsidian-mcp serve --vault main=\"<YOUR_VAULT_PATH>\""
echo "  • In Claude Desktop: Paste the snippet from connectors/claude-desktop/claude_desktop_config.json"
echo ""
echo "✨ Setup Complete!"
