# Headless AI Second Brain — Windows Quick Setup Script
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " 🧠 Headless AI Second Brain — Windows Setup" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Check for Node.js / npx
Write-Host "`n[1/4] Checking Node.js environment..." -ForegroundColor Yellow
if (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeVersion = node -v
    Write-Host "  ✅ Node.js is installed ($nodeVersion)" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Node.js not found. Installing via winget..." -ForegroundColor Yellow
    winget install OpenJS.NodeJS.LTS --silent --accept-source-agreements --accept-package-agreements
    # winget registers the PATH change in the registry immediately, but this process's own
    # $env:Path was captured before that happened — refresh it here so the checks below don't
    # fail purely because of session staleness, the exact class of user this fallback is for.
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (Get-Command node -ErrorAction SilentlyContinue) {
        Write-Host "  ✅ Node.js installed and available in this session ($(node -v))." -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Node.js installed, but this PowerShell session still can't see it." -ForegroundColor Yellow
        Write-Host "     Close this window, open a new PowerShell, and re-run this script." -ForegroundColor Yellow
        exit 1
    }
}

# 2. Check npx
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Host "  ❌ npx could not be located in PATH. Close this window, open a new" -ForegroundColor Red
    Write-Host "     PowerShell, and re-run this script." -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ npx is available" -ForegroundColor Green

# 3. Test obsidian-mcp resolution
Write-Host "`n[2/4] Pre-caching obsidian-mcp via npx..." -ForegroundColor Yellow
npx -y obsidian-mcp --help | Out-Null
Write-Host "  ✅ obsidian-mcp is ready to serve" -ForegroundColor Green

# 4. Install the agent skills (grounding, auto-sync, vault-audit, etc.)
Write-Host "`n[3/4] Installing agent skills into ~/.agents/..." -ForegroundColor Yellow
$installScript = "$PSScriptRoot\..\install.ps1"
if (-not (Test-Path $installScript)) {
    Write-Host "  ❌ Can't find install.ps1 next to this script." -ForegroundColor Red
    Write-Host "     This usually means only part of the downloaded folder got moved or" -ForegroundColor Red
    Write-Host "     extracted. Re-download the whole headless-ai-second-brain folder from" -ForegroundColor Red
    Write-Host "     GitHub and run this script from inside it, without moving anything" -ForegroundColor Red
    Write-Host "     out of it first." -ForegroundColor Red
    exit 1
}
Write-Host "  (If Claude Code/Desktop or Antigravity aren't detected, this may ask a" -ForegroundColor DarkGray
Write-Host "   yes/no question before continuing.)" -ForegroundColor DarkGray
& $installScript

# 5. Summary instructions
Write-Host "`n[4/4] Next Steps for Your AI Desktop App:" -ForegroundColor Yellow
Write-Host "  Full setup steps for each app, including plan requirements, live in:" -ForegroundColor Cyan
Write-Host "    - ChatGPT Desktop:  connectors\chatgpt-desktop\form-instructions.md" -ForegroundColor Gray
Write-Host "    - Claude Desktop:   connectors\claude-desktop\claude_desktop_config.json" -ForegroundColor Gray
Write-Host "    - Antigravity:      connectors\antigravity-ide\mcp_config.json (already linked above if detected)" -ForegroundColor Gray
Write-Host "    - Cursor:           README.md, 'Step 2' section (per-project, manual copy)" -ForegroundColor Gray
Write-Host "`n✨ Setup Complete! Happy building." -ForegroundColor Cyan
