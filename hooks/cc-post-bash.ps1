# Claude Code PostToolUse(Bash) adapter -> Obsidian live-sync on commit.
# Reads the hook JSON on stdin. If the Bash command was a real `git commit`,
# invokes scripts/obsidian-post-commit.ps1 to queue the milestone. Always non-blocking, always exit 0.
#
# Wire it up in ~/.claude/settings.json:
#   "hooks": { "PostToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command",
#     "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<HOME>/.agents/hooks/cc-post-bash.ps1\"" } ] } ] }

$ErrorActionPreference = 'SilentlyContinue'

try {
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }

    $payload = $raw | ConvertFrom-Json
    $cmd = [string]$payload.tool_input.command
    if (-not $cmd) { exit 0 }

    # Match `git commit` (incl. inside `&&` / `;` chains). Skip amend and dry-run.
    if ($cmd -notmatch '(^|[\s&;|])git(\s+-[^\s]+)*\s+commit(\s|$)') { exit 0 }
    if ($cmd -match '--amend' -or $cmd -match '--dry-run') { exit 0 }

    $script = Join-Path $HOME '.agents\scripts\obsidian-post-commit.ps1'
    if (-not (Test-Path $script)) { exit 0 }

    # Run in the project directory the hook fired from so `git rev-parse` resolves.
    $work = if ($payload.cwd) { [string]$payload.cwd } else { (Get-Location).Path }
    Push-Location $work
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $script *>&1
    } finally {
        Pop-Location
    }
} catch {
    exit 0
}

exit 0
