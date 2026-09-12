<#
.SYNOPSIS
    Unified CLI companion for Obsidian knowledge base synchronization, audits, digests, and queues.
.DESCRIPTION
    Commands:
      status    Check vault connectivity, active provider, replay queue, and health.
      audit     Run multi-vector vault health & link integrity audit.
      digest    Generate weekly or monthly executive rollup briefing.
      flush     Drain pending milestone queue (.agents/pending-sync.json) into Worklog.md.
      help      Show command help and usage examples.
#>

param (
    [Parameter(Position=0)]
    [string]$Command = "help",
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$RemainingArgs
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$configPath = "$HOME\.agents\obsidian-config.json"

# Resolve the pending-sync queue from the CALLER's context, not this script's
# install dir. Priority: explicit path arg > current git repo root > current dir.
$queueRoot = $null
if ($RemainingArgs -and $RemainingArgs.Count -ge 1 -and $RemainingArgs[0] -and ($RemainingArgs[0] -notmatch '^-') -and (Test-Path -LiteralPath $RemainingArgs[0])) {
    $queueRoot = (Resolve-Path -LiteralPath $RemainingArgs[0]).Path
} else {
    $gitRoot = (git rev-parse --show-toplevel 2>$null)
    $queueRoot = if ($gitRoot) { $gitRoot } else { (Get-Location).Path }
}
$queuePath = Join-Path $queueRoot ".agents\pending-sync.json"

# Resolve vault path: $env:OBSIDIAN_VAULT_PATH, then config `vault_path`.
$vaultPath = $env:OBSIDIAN_VAULT_PATH
$defaultVault = $null
$provider = "auto"

if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        $provider = if ($cfg.provider) { $cfg.provider } else { "auto" }
        $defaultVault = $cfg.default_vault
        if (-not $vaultPath -and $cfg.vault_path) { $vaultPath = [string]$cfg.vault_path }
    } catch {}
}

if ($vaultPath -and -not (Test-Path $vaultPath)) { $vaultPath = $null }

function Show-Banner {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Obsidian Sync CLI Companion (obsidian-sync)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Show-Help {
    Show-Banner
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  obsidian-sync <command> [options]`n" -ForegroundColor Gray
    Write-Host "Commands:" -ForegroundColor White
    Write-Host "  status    Show vault connectivity, active provider, queue, and stats" -ForegroundColor Yellow
    Write-Host "  audit     Audit link integrity, companions, orphans, and schemas" -ForegroundColor Yellow
    Write-Host "  digest    Compile weekly or monthly executive rollup briefing" -ForegroundColor Yellow
    Write-Host "  flush     Replay and drain pending milestones into vault Worklog" -ForegroundColor Yellow
    Write-Host "  help      Show this help message`n" -ForegroundColor Yellow
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  obsidian-sync status" -ForegroundColor Gray
    Write-Host "  obsidian-sync audit -ScaffoldMissing" -ForegroundColor Gray
    Write-Host "  obsidian-sync digest -Period Weekly" -ForegroundColor Gray
    Write-Host "  obsidian-sync digest -Period Monthly" -ForegroundColor Gray
    Write-Host "  obsidian-sync flush`n" -ForegroundColor Gray
}

switch ($Command.ToLower()) {
    "status" {
        Show-Banner
        Write-Host "Configuration & Connectivity:" -ForegroundColor White
        Write-Host "  Config Path    : $configPath" -ForegroundColor Gray
        Write-Host "  Config Status  : $(if (Test-Path $configPath) { 'Active' } else { 'Missing (run install.ps1)' })" -ForegroundColor $(if (Test-Path $configPath) { 'Green' } else { 'Red' })
        Write-Host "  Active Vault   : $(if ($vaultPath) { $vaultPath } else { 'Not Found' })" -ForegroundColor $(if ($vaultPath) { 'Green' } else { 'Red' })
        Write-Host "  Provider Mode  : $provider" -ForegroundColor Gray
        
        # Check Pending Queue
        $queueFile = $queuePath
        $queueCount = 0
        if (Test-Path $queueFile) {
            try {
                $q = Get-Content $queueFile -Raw | ConvertFrom-Json
                $queueCount = @($q).Count
            } catch {}
        }
        Write-Host "  Pending Queue  : $queueCount queued milestones" -ForegroundColor $(if ($queueCount -eq 0) { 'Green' } else { 'Yellow' })

        # Quick File Count
        if ($vaultPath -and (Test-Path $vaultPath)) {
            $notesCount = (Get-ChildItem -Path $vaultPath -Filter "*.md" -Recurse -ErrorAction SilentlyContinue | Where-Object {
                $_.FullName -notmatch '[\\/](\.obsidian|\.git|\.trash)[\\/]'
            }).Count
            Write-Host "  Total Notes    : $notesCount markdown notes in vault" -ForegroundColor White

            $projCount = (Get-ChildItem -Path "$vaultPath\Projects" -Directory -ErrorAction SilentlyContinue).Count
            $areaCount = (Get-ChildItem -Path "$vaultPath\Areas" -Directory -ErrorAction SilentlyContinue).Count
            Write-Host "  Structure      : $projCount Projects | $areaCount Areas" -ForegroundColor Gray
        }
        Write-Host ""
    }

    "audit" {
        $auditScript = Join-Path $rootDir "scripts\audit-vault.ps1"
        if (-not (Test-Path $auditScript)) {
            Write-Error "Audit script not found at $auditScript."
            exit 1
        }
        & powershell -NoProfile -ExecutionPolicy Bypass -File $auditScript @RemainingArgs
    }

    "digest" {
        $digestScript = Join-Path $rootDir "scripts\generate-digest.ps1"
        if (-not (Test-Path $digestScript)) {
            Write-Error "Digest script not found at $digestScript."
            exit 1
        }
        & powershell -NoProfile -ExecutionPolicy Bypass -File $digestScript @RemainingArgs
    }

    "flush" {
        Show-Banner
        $queueFile = $queuePath
        if (-not (Test-Path $queueFile)) {
            Write-Host "No pending sync queue found at $queueFile." -ForegroundColor Yellow
            exit 0
        }

        $queue = try { Get-Content $queueFile -Raw | ConvertFrom-Json } catch { @() }
        $queueItems = @($queue)

        if ($queueItems.Count -eq 0) {
            Write-Host "Pending sync queue is completely empty (0 items). Nothing to flush!" -ForegroundColor Green
            Write-Host ""
            exit 0
        }

        Write-Host "Found $($queueItems.Count) pending milestone(s) to flush." -ForegroundColor Yellow

        # Drain items into target worklogs
        $flushed = 0
        foreach ($item in $queueItems) {
            $targetPath = if ($item.target_path) { $item.target_path } else { "Projects/$($item.project)/Worklog.md" }
            $fullTarget = Join-Path $vaultPath $targetPath
            
            if (Test-Path $fullTarget) {
                $commitHash = $item.commit.hash
                $commitSubj = $item.commit.subject
                $commitDate = if ($item.commit.date) { ([DateTime]$item.commit.date).ToString('yyyy-MM-dd HH:mm') } else { (Get-Date -Format 'yyyy-MM-dd HH:mm') }
                $keyFiles = ($item.commit.files | Select-Object -First 5) -join ', '
                $formattedHash = [char]96 + $commitHash + [char]96
                $flag = [char]::ConvertFromUtf32(0x1F3C1)  # build non-ASCII from codepoint; script parses as ANSI under PS 5.1

                $blockLines = @(
                    ""
                    "### [$commitDate] $commitSubj"
                    "- **Milestone**: $flag $commitSubj"
                    "- **Commits (1)**:"
                    "  - $formattedHash - $commitSubj"
                    "- **Key Files**: $keyFiles"
                )
                $block = ($blockLines -join "`n") + "`n"
                [System.IO.File]::AppendAllText($fullTarget, $block, [System.Text.Encoding]::UTF8)
                Write-Host "  [FLUSHED] Milestone $commitHash -> $targetPath" -ForegroundColor Green
                $flushed++
            } else {
                Write-Host "  [SKIPPED] Target worklog not found: $fullTarget" -ForegroundColor Red
            }
        }

        # Clear queue
        "[]" | Out-File -FilePath $queueFile -Encoding utf8
        Write-Host "Flushed $flushed milestone(s). Pending queue cleared.`n" -ForegroundColor Cyan
    }

    default {
        Show-Help
    }
}
