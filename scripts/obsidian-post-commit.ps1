# Camwyn Agent Skills - Git Post-Commit Sync Hook (PowerShell)
# Autonomously queues git milestones to .agents/pending-sync.json for Obsidian live-sync
[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

try {
    # 1. Resolve Repository Root & Project Identity
    $repoRoot = (git rev-parse --show-toplevel 2>$null)
    if (-not $repoRoot) { exit 0 }
    $projectName = Split-Path $repoRoot -Leaf

    # 2. Locate Configuration
    $configPath = Join-Path $repoRoot ".agents\obsidian-config.json"
    if (-not (Test-Path $configPath)) {
        $configPath = Join-Path $HOME ".agents\obsidian-config.json"
    }
    if (-not (Test-Path $configPath)) { exit 0 }

    # 3. Parse Configuration Gate
    $rawConfig = Get-Content -Path $configPath -Raw -ErrorAction SilentlyContinue
    if (-not $rawConfig) { exit 0 }
    $config = ConvertFrom-Json -InputObject $rawConfig -ErrorAction SilentlyContinue
    if (-not $config) { exit 0 }

    # Map repo folder name -> canonical vault project folder (config: project_aliases).
    # Use when the repo folder name differs from the vault project name (nested repos,
    # monorepo subprojects, or a renamed repo) so commits don't spawn a divergent folder.
    if ($config.project_aliases) {
        $alias = $config.project_aliases.PSObject.Properties | Where-Object { $_.Name -eq $projectName } | Select-Object -First 1
        if ($alias -and $alias.Value) { $projectName = [string]$alias.Value }
    }

    if (-not $config.auto_sync -or -not $config.auto_sync.enabled -or -not $config.auto_sync.on_commit) {
        exit 0
    }

    # 4. Extract Commit Metadata
    $commitHash = (git rev-parse --short HEAD 2>$null)
    $commitSubject = (git log -1 --format="%s" 2>$null)
    $author = (git log -1 --format="%an" 2>$null)
    $commitDate = (git log -1 --format="%aI" 2>$null)
    $changedFiles = @(git diff-tree --no-commit-id --name-only -r HEAD 2>$null)

    if (-not $commitHash -or -not $commitSubject) { exit 0 }

    # 5. Evaluate Threshold of Significance
    $commitLevel = "milestones_only"
    if ($config.auto_sync.filters -and $config.auto_sync.filters.commit_level) {
        $commitLevel = $config.auto_sync.filters.commit_level
    }

    if ($commitLevel -eq "milestones_only") {
        $isMilestone = ($commitSubject -match "^(feat|refactor|breaking|perf)[\(!:]") -or ($commitSubject -match "BREAKING CHANGE")
        if (-not $isMilestone) {
            exit 0
        }
    }

    # 6. Queue into .agents/pending-sync.json
    $queueDir = Join-Path $repoRoot ".agents"
    if (-not (Test-Path $queueDir)) {
        New-Item -ItemType Directory -Path $queueDir -Force | Out-Null
    }
    $queuePath = Join-Path $queueDir "pending-sync.json"

    $queueItems = [System.Collections.ArrayList]::new()
    if (Test-Path $queuePath) {
        $rawQueue = Get-Content -Path $queuePath -Raw -ErrorAction SilentlyContinue
        if ($rawQueue) {
            $parsed = ConvertFrom-Json -InputObject $rawQueue -ErrorAction SilentlyContinue
            if ($parsed -is [System.Array]) {
                foreach ($item in $parsed) { [void]$queueItems.Add($item) }
            } elseif ($parsed) {
                [void]$queueItems.Add($parsed)
            }
        }
    }

    # Avoid duplicate queue entries for the same commit
    foreach ($item in $queueItems) {
        if ($item.commit -and $item.commit.hash -eq $commitHash) {
            exit 0
        }
    }

    $defaultVault = if ($config.default_vault) { $config.default_vault } else { "default" }
    $projectsDir = if ($config.para -and $config.para.projects_dir) { $config.para.projects_dir } else { "Projects" }

    $newEntry = [PSCustomObject]@{
        id = "commit-$commitHash"
        timestamp = $commitDate
        type = "commit"
        vault = $defaultVault
        target_path = "$projectsDir/$projectName/Worklog.md"
        project = $projectName
        commit = [PSCustomObject]@{
            hash = $commitHash
            subject = $commitSubject
            author = $author
            date = $commitDate
            files = $changedFiles
        }
        source = "git-post-commit-hook"
    }

    [void]$queueItems.Add($newEntry)
    $jsonOutput = ConvertTo-Json -InputObject @($queueItems) -Depth 6
    Set-Content -Path $queuePath -Value $jsonOutput -Encoding UTF8 -Force

    Write-Host "[obsidian-sync] Queued milestone [$commitHash] to .agents/pending-sync.json" -ForegroundColor Cyan
} catch {
    # Non-blocking: never interrupt or fail the developer's git workflow
    exit 0
}

exit 0
