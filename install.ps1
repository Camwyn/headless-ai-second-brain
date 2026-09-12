# Headless AI Second Brain - Skills Installer
# Links (or copies) the skill packages into whichever agent skill directories are actually
# in use on this machine. Detects presence before writing anything app-specific - it will not
# create a ~/.claude/ folder for an app you don't have installed unless you say so.
param (
    [string]$AgentsSkillsDir = "$HOME\.agents\skills",
    [string]$RulesDir = "$HOME\.agents\rules",
    [string]$BinDir = "$HOME\.agents\bin",
    [string]$ScriptsDir = "$HOME\.agents\scripts",
    [string]$HooksDir = "$HOME\.agents\hooks",
    [switch]$Copy = $false,
    # Force Claude Code/Desktop install on or off without the interactive prompt.
    # Leave unset to auto-detect, and ask only when detection is inconclusive.
    [switch]$InstallClaude,
    [switch]$SkipClaude,
    [switch]$InstallAntigravity,
    [switch]$SkipAntigravity
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Headless AI Second Brain - Skills Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

function Get-LinkInfo {
    # Returns the Get-Item result if $Path exists, or $null. Callers check .LinkType to tell
    # a real directory (LinkType null/empty) from something we (or another tool) already
    # linked (Junction / SymbolicLink) — that distinction is the whole safety mechanism below.
    param([string]$Path)
    return Get-Item -Path $Path -Force -ErrorAction SilentlyContinue
}

function Remove-OwnedLinkOnly {
    # The ONE place either installer function is allowed to delete something at a skill
    # destination. Refuses outright unless the existing item is confirmed to be a reparse
    # point — a real directory is never provenance we can vouch for, so it's never touched.
    # Removes the link itself (no -Recurse): recursing into a directory-junction/symlink can,
    # depending on PowerShell/.NET version, follow the link and delete the TARGET's real
    # content instead of just unlinking — exactly how a prior version of this script destroyed
    # an entire personal skills library that happened to be aliased through one parent-level
    # junction. Never pass -Recurse here again.
    param([string]$Path, [string]$SkillName)

    $existing = Get-LinkInfo -Path $Path
    if (-not $existing) { return $true }

    if ($existing.LinkType) {
        Remove-Item -Path $Path -Force
        return $true
    }

    Write-Host "  [SKIP]   $SkillName -> $Path already exists as a REAL directory, not a link." -ForegroundColor Yellow
    Write-Host "           Leaving it alone — this installer only ever replaces links it (or a" -ForegroundColor DarkYellow
    Write-Host "           prior compatible run) created. Remove it yourself first if you want" -ForegroundColor DarkYellow
    Write-Host "           this skill installed here." -ForegroundColor DarkYellow
    return $false
}

function Install-SkillsTo {
    # Links (or copies) skills directly from the repo into $Dest. Use only for the one
    # canonical target ($AgentsSkillsDir) — every other target should mirror off of that
    # via Mirror-SkillsFrom instead, so there's exactly one real copy on disk to go stale.
    param([string]$Dest, [string]$Label)

    if (-not (Test-Path $Dest)) {
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    }

    $skillFiles = Get-ChildItem -Path "$PSScriptRoot\skills" -Filter "SKILL.md" -Recurse
    $installed = @()

    foreach ($skillFile in $skillFiles) {
        $skillFolder = $skillFile.Directory
        $skillName = $skillFolder.Name
        $skillDest = Join-Path $Dest $skillName

        if (-not (Remove-OwnedLinkOnly -Path $skillDest -SkillName $skillName)) { continue }

        if ($Copy) {
            Write-Host "  [COPY]   ($Label) $skillName -> $skillDest" -ForegroundColor Green
            Copy-Item -Path $skillFolder.FullName -Destination $Dest -Recurse -Force
        } else {
            Write-Host "  [LINK]   ($Label) $skillName -> $($skillFolder.FullName)" -ForegroundColor Green
            New-Item -ItemType Junction -Path $skillDest -Target $skillFolder.FullName | Out-Null
        }
        $installed += $skillName
    }
    return $installed
}

function Mirror-SkillsFrom {
    # Points $Dest at whatever is already installed under $SourceDir via a per-skill junction
    # (or a copy, if the whole install is running in -Copy mode) — never re-reads the repo, so
    # there's only ever one real place a skill's content lives on this machine.
    param([string]$SourceDir, [string]$Dest, [string]$Label)

    # Fast, whole-directory check FIRST: if $Dest is itself already a reparse point (a junction
    # or symlink covering the entire directory, pointing at $SourceDir or anywhere else),
    # every "skill" found by looking inside it is really just $SourceDir's own content seen
    # through the link — iterating per-skill and deleting-then-relinking each one would delete
    # the real, single copy on disk one folder at a time. Do nothing at all in that case.
    $destInfo = Get-LinkInfo -Path $Dest
    if ($destInfo -and $destInfo.LinkType) {
        Write-Host "  $Dest is already a $($destInfo.LinkType) -> $($destInfo.Target) — it's" -ForegroundColor Gray
        Write-Host "  already aliased to something as a whole directory. Nothing to mirror;" -ForegroundColor Gray
        Write-Host "  not touching it." -ForegroundColor Gray
        return (Get-ChildItem -Path $Dest -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    }

    if (-not (Test-Path $Dest)) {
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    }

    $installed = @()
    foreach ($skillFolder in (Get-ChildItem -Path $SourceDir -Directory)) {
        $skillName = $skillFolder.Name
        $skillDest = Join-Path $Dest $skillName

        if (-not (Remove-OwnedLinkOnly -Path $skillDest -SkillName $skillName)) { continue }

        if ($Copy) {
            Write-Host "  [COPY]   ($Label) $skillName -> $skillDest" -ForegroundColor Green
            Copy-Item -Path $skillFolder.FullName -Destination $Dest -Recurse -Force
        } else {
            Write-Host "  [LINK]   ($Label) $skillName -> $($skillFolder.FullName)" -ForegroundColor Green
            New-Item -ItemType Junction -Path $skillDest -Target $skillFolder.FullName | Out-Null
        }
        $installed += $skillName
    }
    return $installed
}

# --- Target 1: ~/.agents/skills — always installed. This is the repo's own base/neutral
# location, not a specific vendor's app folder, and it's what Codex (OpenAI) and the emerging
# cross-tool SKILL.md convention read directly. No detection needed here.
Write-Host "`n[1/3] Installing to $AgentsSkillsDir (Codex + open-standard tools)..." -ForegroundColor Yellow
$installedSkills = Install-SkillsTo -Dest $AgentsSkillsDir -Label "agents"

# --- Target 2: ~/.claude/skills — Claude Code's own directory (Claude Code does not read
# ~/.agents/skills natively). Only written if Claude appears to already be installed, or if
# the user explicitly opts in — never created speculatively for an app that isn't there.
Write-Host "`n[2/3] Checking for Claude Code / Claude Desktop..." -ForegroundColor Yellow
$claudeSkillsDir = "$HOME\.claude\skills"
$claudeDetected = (Test-Path "$HOME\.claude") -or
                  (Test-Path "$env:APPDATA\Claude") -or
                  ($null -ne (Get-Command claude -ErrorAction SilentlyContinue))

$doInstallClaude = $false
if ($SkipClaude) {
    Write-Host "  -SkipClaude passed; not touching ~/.claude/" -ForegroundColor Gray
} elseif ($InstallClaude) {
    $doInstallClaude = $true
} elseif ($claudeDetected) {
    Write-Host "  ✅ Claude Code or Claude Desktop detected." -ForegroundColor Green
    $doInstallClaude = $true
} elseif ([Environment]::UserInteractive -and (-not [Console]::IsInputRedirected)) {
    $answer = Read-Host "  Claude Code/Desktop not detected. Install skills there too, for later use? [y/N]"
    $doInstallClaude = ($answer -match '^[Yy]')
} else {
    Write-Host "  Claude not detected and not running interactively — skipping ~/.claude/skills." -ForegroundColor Gray
    Write-Host "  (Pass -InstallClaude to force it, e.g. in a non-interactive install.)" -ForegroundColor DarkGray
}

$installedClaudeSkills = @()
if ($doInstallClaude) {
    # Mirrors off $AgentsSkillsDir (already installed above), not the repo — ~/.claude/skills
    # ends up as junctions-to-junctions (or copies-of-copies in -Copy mode), same as your
    # existing personal ~/.agents/skills -> ~/.claude/skills setup. One real source, not two.
    $installedClaudeSkills = Mirror-SkillsFrom -SourceDir $AgentsSkillsDir -Dest $claudeSkillsDir -Label "claude"
} else {
    Write-Host "  Skipped — no ~/.claude/skills folder created." -ForegroundColor Gray
}

# --- Target 3: ~/.gemini/config/skills — Antigravity's global skills directory. Antigravity
# also reads a project-level <repo>/.agents/skills/ (walking up to the git root), which is out
# of scope for a machine-wide installer — that's a per-project copy, same as Cursor's
# .cursor/skills/, documented below rather than automated. Confirmed directly against
# Antigravity (2026-09) rather than assumed from docs, given how wrong that assumption turned
# out to be for ChatGPT.
Write-Host "`n[3/3] Checking for Antigravity IDE..." -ForegroundColor Yellow
$antigravitySkillsDir = "$HOME\.gemini\config\skills"
$antigravityDetected = (Test-Path "$HOME\.gemini") -or
                       ($null -ne (Get-Command antigravity -ErrorAction SilentlyContinue)) -or
                       ($null -ne (Get-Command gemini -ErrorAction SilentlyContinue))

$doInstallAntigravity = $false
if ($SkipAntigravity) {
    Write-Host "  -SkipAntigravity passed; not touching ~/.gemini/" -ForegroundColor Gray
} elseif ($InstallAntigravity) {
    $doInstallAntigravity = $true
} elseif ($antigravityDetected) {
    Write-Host "  ✅ Antigravity (or the Gemini CLI) detected." -ForegroundColor Green
    $doInstallAntigravity = $true
} elseif ([Environment]::UserInteractive -and (-not [Console]::IsInputRedirected)) {
    $answer = Read-Host "  Antigravity not detected. Install skills there too, for later use? [y/N]"
    $doInstallAntigravity = ($answer -match '^[Yy]')
} else {
    Write-Host "  Antigravity not detected and not running interactively — skipping ~/.gemini/config/skills." -ForegroundColor Gray
    Write-Host "  (Pass -InstallAntigravity to force it, e.g. in a non-interactive install.)" -ForegroundColor DarkGray
}

$installedAntigravitySkills = @()
if ($doInstallAntigravity) {
    $installedAntigravitySkills = Mirror-SkillsFrom -SourceDir $AgentsSkillsDir -Dest $antigravitySkillsDir -Label "antigravity"
} else {
    Write-Host "  Skipped — no ~/.gemini/config/skills folder created." -ForegroundColor Gray
}

# Link or copy behavioral rules into .agents/rules
$installedRules = @()
if (Test-Path "$PSScriptRoot\rules") {
    if (-not (Test-Path $RulesDir)) {
        New-Item -ItemType Directory -Path $RulesDir -Force | Out-Null
    }
    $ruleFiles = Get-ChildItem -Path "$PSScriptRoot\rules" -Filter "*.md"
    foreach ($rule in $ruleFiles) {
        $dest = Join-Path $RulesDir $rule.Name
        if (Test-Path $dest) {
            Remove-Item -Path $dest -Force
        }
        if ($Copy) {
            Copy-Item -Path $rule.FullName -Destination $dest -Force
            Write-Host "  [COPY]   Rule: $($rule.Name)" -ForegroundColor Green
        } else {
            try {
                New-Item -ItemType HardLink -Path $dest -Target $rule.FullName -ErrorAction Stop | Out-Null
                Write-Host "  [LINK]   Rule: $($rule.Name)" -ForegroundColor Green
            } catch {
                Copy-Item -Path $rule.FullName -Destination $dest -Force
                Write-Host "  [COPY]   Rule: $($rule.Name)" -ForegroundColor Yellow
            }
        }
        $installedRules += $rule.Name
    }
}

# Install git post-commit hook if in a git repository
$gitHooksDir = Join-Path $PSScriptRoot ".git\hooks"
if ((Test-Path $gitHooksDir) -and (Test-Path "$PSScriptRoot\scripts\post-commit")) {
    $hookDest = Join-Path $gitHooksDir "post-commit"
    Copy-Item -Path "$PSScriptRoot\scripts\post-commit" -Destination $hookDest -Force
    Write-Host "  [HOOK]   post-commit -> $hookDest" -ForegroundColor Green
}

# Install CLI tools into BinDir
if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
}
$installedBin = @()
if (Test-Path "$PSScriptRoot\bin") {
    $binFiles = Get-ChildItem -Path "$PSScriptRoot\bin" -File
    foreach ($bin in $binFiles) {
        $dest = Join-Path $BinDir $bin.Name
        Copy-Item -Path $bin.FullName -Destination $dest -Force
        Write-Host "  [CLI]    $($bin.Name) -> $dest" -ForegroundColor Green
        $installedBin += $bin.Name
    }
}

# Install supporting scripts into ScriptsDir
if (Test-Path "$PSScriptRoot\scripts") {
    if (-not (Test-Path $ScriptsDir)) {
        New-Item -ItemType Directory -Path $ScriptsDir -Force | Out-Null
    }
    $scriptFiles = Get-ChildItem -Path "$PSScriptRoot\scripts" -File
    foreach ($sf in $scriptFiles) {
        $dest = Join-Path $ScriptsDir $sf.Name
        Copy-Item -Path $sf.FullName -Destination $dest -Force
        Write-Host "  [SCRIPT] $($sf.Name) -> $dest" -ForegroundColor Green
    }
}

# Install Claude Code hook adapters into HooksDir — only alongside an actual Claude install,
# same reasoning as the skills target above (these hooks are meaningless without Claude Code).
$installedHooks = @()
if ($doInstallClaude -and (Test-Path "$PSScriptRoot\hooks")) {
    if (-not (Test-Path $HooksDir)) {
        New-Item -ItemType Directory -Path $HooksDir -Force | Out-Null
    }
    foreach ($hk in (Get-ChildItem -Path "$PSScriptRoot\hooks" -File)) {
        $dest = Join-Path $HooksDir $hk.Name
        Copy-Item -Path $hk.FullName -Destination $dest -Force
        Write-Host "  [HOOK]   $($hk.Name) -> $dest" -ForegroundColor Green
        $installedHooks += $hk.Name
    }
}

# Install obsidian-config.json if not present
$configTarget = "$HOME\.agents\obsidian-config.json"
$configExample = "$PSScriptRoot\skills\obsidian-rag\obsidian-config.json.example"
if (-not (Test-Path $configTarget) -and (Test-Path $configExample)) {
    Write-Host "`n  [CONFIG] Creating default config at $configTarget" -ForegroundColor Yellow
    Copy-Item -Path $configExample -Destination $configTarget
}

$pathEnv = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$inPath = $pathEnv -split ';' -contains $BinDir

Write-Host "`nDone." -ForegroundColor Cyan
if (-not $inPath) {
    Write-Host "NOTE: To run 'obsidian-sync' from any terminal, add $BinDir to your User PATH:" -ForegroundColor Yellow
    Write-Host "  [System.Environment]::SetEnvironmentVariable('PATH', `"`$env:PATH;$BinDir`", 'User')`n" -ForegroundColor DarkGray
}

Write-Host "Skills installed to ${AgentsSkillsDir} ($($installedSkills.Count)):"
foreach ($s in ($installedSkills | Sort-Object)) {
    Write-Host "  - /$s" -ForegroundColor White
}
if ($doInstallClaude) {
    Write-Host "Also installed to ${claudeSkillsDir} for Claude Code/Desktop ($($installedClaudeSkills.Count))."
}
if ($doInstallAntigravity) {
    Write-Host "Also installed to ${antigravitySkillsDir} for Antigravity ($($installedAntigravitySkills.Count))."
}

if ($installedRules.Count -gt 0) {
    Write-Host "Active rules ($($installedRules.Count)):"
    foreach ($r in ($installedRules | Sort-Object)) {
        Write-Host "  - $r" -ForegroundColor White
    }
}

if ($installedHooks.Count -gt 0) {
    Write-Host "Hook adapters ($($installedHooks.Count)) installed to ${HooksDir}:"
    foreach ($h in ($installedHooks | Sort-Object)) {
        Write-Host "  - $h" -ForegroundColor White
    }
    Write-Host "  Add these to ~/.claude/settings.json to activate them:" -ForegroundColor Yellow
    Write-Host "    SessionStart      -> $HooksDir\cc-session-start.ps1" -ForegroundColor DarkGray
    Write-Host "    PostToolUse:Bash  -> $HooksDir\cc-post-bash.ps1" -ForegroundColor DarkGray
    Write-Host "  (each as a `"type`":`"command`" hook: powershell -NoProfile -ExecutionPolicy Bypass -File `"<path>`")" -ForegroundColor DarkGray
}

Write-Host "`nOther agents:" -ForegroundColor Cyan
Write-Host "  Cursor reads skills per-project from .cursor\skills\, not a global folder. Copy" -ForegroundColor Gray
Write-Host "  skills\obsidian-rag\* there manually in each project where you want them." -ForegroundColor Gray
Write-Host "  Antigravity ALSO reads a project-level <repo>\.agents\skills\, walking up to the" -ForegroundColor Gray
Write-Host "  git root — commit that folder in a project to share skills with a team there too." -ForegroundColor Gray
Write-Host "  ChatGPT (the chat product) doesn't scan a local folder — its Skills feature is" -ForegroundColor Gray
Write-Host "  upload-only and limited to Business/Enterprise/Edu accounts. .agents/skills is" -ForegroundColor Gray
Write-Host "  read by Codex, a different product. Use the pasted instructions block in" -ForegroundColor Gray
Write-Host "  connectors\chatgpt-desktop\form-instructions.md instead." -ForegroundColor Gray

Write-Host "`nNext Step:" -ForegroundColor Cyan
Write-Host "  Run '/obsidian-setup' in chat to configure your vault (set 'vault_path'), or customize '$configTarget'`n" -ForegroundColor Gray
