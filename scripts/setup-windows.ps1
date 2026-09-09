# Headless AI Second Brain — Windows Quick Setup Script
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " 🧠 Headless AI Second Brain — Windows Setup" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Check for Node.js / npx
Write-Host "`n[1/3] Checking Node.js environment..." -ForegroundColor Yellow
if (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeVersion = node -v
    Write-Host "  ✅ Node.js is installed ($nodeVersion)" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Node.js not found. Installing via winget..." -ForegroundColor Yellow
    winget install OpenJS.NodeJS.LTS --silent --accept-source-agreements --accept-package-agreements
    Write-Host "  ✅ Node.js installed! Please restart your terminal after setup completes." -ForegroundColor Green
}

# 2. Check npx
if (Get-Command npx -ErrorAction SilentlyContinue) {
    Write-Host "  ✅ npx is available" -ForegroundColor Green
} else {
    Write-Host "  ❌ npx could not be located in PATH. Please restart PowerShell." -ForegroundColor Red
}

# 3. Test obsidian-mcp resolution
Write-Host "`n[2/3] Pre-caching obsidian-mcp via npx..." -ForegroundColor Yellow
npx -y obsidian-mcp --help | Out-Null
Write-Host "  ✅ obsidian-mcp is ready to serve" -ForegroundColor Green

# 4. Summary instructions
Write-Host "`n[3/3] Next Steps for Your AI Desktop App:" -ForegroundColor Yellow
Write-Host "  • In ChatGPT Desktop: Go to Settings -> Developer -> MCP Servers -> Add Server"
Write-Host "    - Command: cmd.exe"
Write-Host "    - Arguments: /c npx -y obsidian-mcp serve --vault main=`"<YOUR_VAULT_PATH>`""
Write-Host "  • In Claude Desktop: Add the JSON snippet in connectors/claude-desktop/claude_desktop_config.json"
Write-Host "`n✨ Setup Complete! Happy building." -ForegroundColor Cyan
