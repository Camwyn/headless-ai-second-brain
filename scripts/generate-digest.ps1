# PowerShell 5.1 & Core compatible executive digest generator for Obsidian vaults
param (
    [string]$VaultPath,
    [ValidateSet("Weekly", "Monthly", "Custom")]
    [string]$Period = "Weekly",
    [int]$Days = 7,
    [string]$OutputDir = "Areas/Digests",
    [switch]$DryRun = $false
)

# 1. Resolve vault path: -VaultPath arg, then $env:OBSIDIAN_VAULT_PATH, then config `vault_path`.
if (-not $VaultPath) { $VaultPath = $env:OBSIDIAN_VAULT_PATH }
$configPath = "$HOME\.agents\obsidian-config.json"
if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        if (-not $VaultPath -and $cfg.vault_path) { $VaultPath = [string]$cfg.vault_path }
        if ($cfg.digest.output_dir) {
            $OutputDir = $cfg.digest.output_dir
        }
    } catch {}
}

if (-not $VaultPath -or -not (Test-Path $VaultPath)) {
    Write-Error "Vault path not found. Set 'vault_path' in ~/.agents/obsidian-config.json, `$env:OBSIDIAN_VAULT_PATH, or pass -VaultPath."
    exit 1
}

$vaultRoot = (Get-Item $VaultPath).FullName

# 2. Determine Date Window
$now = Get-Date
$cutoffDate = switch ($Period) {
    "Weekly"  { $now.AddDays(-7) }
    "Monthly" { $now.AddMonths(-1) }
    "Custom"  { $now.AddDays(-$Days) }
}

$culture = [System.Globalization.CultureInfo]::InvariantCulture
$cal = $culture.Calendar
$weekNum = $cal.GetWeekOfYear($now, [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday)
$digestId = switch ($Period) {
    "Weekly"  { "$($now.ToString('yyyy'))-W$($weekNum.ToString('00'))" }
    "Monthly" { $now.ToString('yyyy-MM') }
    "Custom"  { "$($now.ToString('yyyy-MM-dd'))-$(($Days))d" }
}

$digestTitle = switch ($Period) {
    "Weekly"  { "Executive Weekly Digest - $($now.ToString('yyyy')) Week $($weekNum)" }
    "Monthly" { "Executive Monthly Digest - $($now.ToString('MMMM yyyy'))" }
    "Custom"  { "Executive Rollup Digest - Last $($Days) Days" }
}

# 3. Discover Active Projects
$projectsDir = Join-Path $vaultRoot "Projects"
$projectSummaries = [System.Collections.ArrayList]::new()
$allMilestones = [System.Collections.ArrayList]::new()
$allTasks = [System.Collections.ArrayList]::new()
$allDecisions = [System.Collections.ArrayList]::new()

if (Test-Path $projectsDir) {
    $projFolders = Get-ChildItem -Path $projectsDir -Directory
    foreach ($p in $projFolders) {
        $projName = $p.Name
        $worklogFile = Join-Path $p.FullName "Worklog.md"
        $tasksFile = Join-Path $p.FullName "Tasks.md"
        $decisionsFile = Join-Path $p.FullName "Decisions.md"

        $projMilestones = [System.Collections.ArrayList]::new()
        $projTasks = [System.Collections.ArrayList]::new()
        $projDecisions = [System.Collections.ArrayList]::new()

        # Parse Worklog
        if (Test-Path $worklogFile) {
            $lines = try { [System.IO.File]::ReadAllLines($worklogFile) } catch { @() }
            $currentBlock = $null
            $currentDate = $null

            foreach ($line in $lines) {
                if ($line -match '^###\s*\[(\d{4}-\d{2}-\d{2})[^\]]*\]\s*(.+)$') {
                    if ($currentBlock -and $currentDate -and $currentDate -ge $cutoffDate) {
                        [void]$projMilestones.Add($currentBlock)
                        [void]$allMilestones.Add($currentBlock)
                    }
                    $dateStr = $Matches[1]
                    $headerTitle = $Matches[2].Trim()
                    try {
                        $currentDate = [DateTime]::ParseExact($dateStr, 'yyyy-MM-dd', $culture)
                    } catch {
                        $currentDate = $null
                    }
                    $currentBlock = [PSCustomObject]@{
                        Project = $projName
                        Date    = $dateStr
                        Title   = $headerTitle
                        Lines   = [System.Collections.ArrayList]::new()
                    }
                } elseif ($currentBlock) {
                    [void]$currentBlock.Lines.Add($line)
                }
            }
            if ($currentBlock -and $currentDate -and $currentDate -ge $cutoffDate) {
                [void]$projMilestones.Add($currentBlock)
                [void]$allMilestones.Add($currentBlock)
            }
        }

        # Parse Tasks
        if (Test-Path $tasksFile) {
            $lines = try { [System.IO.File]::ReadAllLines($tasksFile) } catch { @() }
            $currentTask = $null
            $currentTaskDate = $null

            foreach ($line in $lines) {
                if ($line -match '^###\s*\[(\d{4}-\d{2}-\d{2})\]\s*(.+)$') {
                    if ($currentTask -and $currentTaskDate -and $currentTaskDate -ge $cutoffDate) {
                        [void]$projTasks.Add($currentTask)
                        [void]$allTasks.Add($currentTask)
                    }
                    $dateStr = $Matches[1]
                    $taskTitle = $Matches[2].Trim()
                    try {
                        $currentTaskDate = [DateTime]::ParseExact($dateStr, 'yyyy-MM-dd', $culture)
                    } catch {
                        $currentTaskDate = $null
                    }
                    $currentTask = [PSCustomObject]@{
                        Project = $projName
                        Date    = $dateStr
                        Title   = $taskTitle
                        Status  = ""
                        Summary = ""
                    }
                } elseif ($currentTask) {
                    if ($line -match '-\s*\*\*Status\*\*:\s*`?([^`]+)`?') {
                        $currentTask.Status = $Matches[1].Trim()
                    }
                    if ($line -match '-\s*\*\*Resolution[^:]*\*\*:\s*(.+)$') {
                        $currentTask.Summary = $Matches[1].Trim()
                    }
                }
            }
            if ($currentTask -and $currentTaskDate -and $currentTaskDate -ge $cutoffDate) {
                [void]$projTasks.Add($currentTask)
                [void]$allTasks.Add($currentTask)
            }
        }

        # Parse Decisions
        if (Test-Path $decisionsFile) {
            $lines = try { [System.IO.File]::ReadAllLines($decisionsFile) } catch { @() }
            foreach ($line in $lines) {
                if ($line -match '^(?:##|###)\s*(?:\[(\d{4}-\d{2}-\d{2})\]\s*)?(ADR-\d+[^:]*:\s*.+)$') {
                    $adrDate = if ($Matches[1]) { $Matches[1] } else { $now.ToString('yyyy-MM-dd') }
                    $adrTitle = $Matches[2].Trim()
                    $item = [PSCustomObject]@{
                        Project = $projName
                        Date    = $adrDate
                        Title   = $adrTitle
                    }
                    [void]$projDecisions.Add($item)
                    [void]$allDecisions.Add($item)
                }
            }
        }

        [void]$projectSummaries.Add([PSCustomObject]@{
            Name        = $projName
            Milestones  = $projMilestones
            Tasks       = $projTasks
            Decisions   = $projDecisions
            HasActivity = ($projMilestones.Count -gt 0 -or $projTasks.Count -gt 0 -or $projDecisions.Count -gt 0)
        })
    }
}

# 4. Synthesize Markdown Digest
$sb = [System.Text.StringBuilder]::new()

[void]$sb.AppendLine("---")
[void]$sb.AppendLine("title: `"$digestTitle`"")
[void]$sb.AppendLine("type: digest")
[void]$sb.AppendLine("pillar: area")
[void]$sb.AppendLine("period: $($Period.ToLower())")
[void]$sb.AppendLine("period_id: `"$digestId`"")
[void]$sb.AppendLine("date_range: `"$($cutoffDate.ToString('yyyy-MM-dd')) to $($now.ToString('yyyy-MM-dd'))`"")
[void]$sb.AppendLine("created_at: `"$($now.ToString('yyyy-MM-dd HH:mm'))`"")
[void]$sb.AppendLine("tags:")
[void]$sb.AppendLine("  - digest")
[void]$sb.AppendLine("  - executive-review")
[void]$sb.AppendLine("  - $($Period.ToLower())")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("# $digestTitle")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("> Comprehensive cross-project executive briefing consolidating engineering progress, milestones, architectural decisions, and task completions across all active projects.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Executive Velocity Scorecard")
[void]$sb.AppendLine("")
$activeProjects = @($projectSummaries | Where-Object { $_.HasActivity })
$activeProjectsCount = $activeProjects.Count
[void]$sb.AppendLine("| Metric | Value | Scope |")
[void]$sb.AppendLine("| :--- | :--- | :--- |")
[void]$sb.AppendLine("| **Period Window** | $($cutoffDate.ToString('yyyy-MM-dd')) to $($now.ToString('yyyy-MM-dd')) | $($Days) days |")
[void]$sb.AppendLine("| **Active Projects** | **$activeProjectsCount** / $($projectSummaries.Count) | Vault-wide |")
[void]$sb.AppendLine("| **Milestones Reached** | **$($allMilestones.Count)** | Production & Architecture |")
[void]$sb.AppendLine("| **Tasks Closed** | **$($allTasks.Count)** | Sprints & Roadmaps |")
[void]$sb.AppendLine("| **ADRs Enacted** | **$($allDecisions.Count)** | System Decisions |")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# 5. Project Progress Rollups
[void]$sb.AppendLine("## Project Progress & Milestones")
[void]$sb.AppendLine("")

foreach ($ps in $projectSummaries) {
    if ($ps.HasActivity) {
        [void]$sb.AppendLine("### [[Projects/$($ps.Name)/Overview|$($ps.Name)]]")
        [void]$sb.AppendLine("- **Quick Links**: [[Projects/$($ps.Name)/Worklog|Worklog]] | [[Projects/$($ps.Name)/Tasks|Tasks]] | [[Projects/$($ps.Name)/Decisions|Decisions]]")
        
        if ($ps.Milestones.Count -gt 0) {
            [void]$sb.AppendLine("- **Milestones Achieved ($($ps.Milestones.Count))**:")
            foreach ($m in $ps.Milestones) {
                [void]$sb.AppendLine("  - **[$($m.Date)] $($m.Title)**")
                foreach ($ml in $m.Lines) {
                    if ($ml -match '^\s*-\s*\*\*(Milestone|Summary)\*\*:\s*(.+)$') {
                        [void]$sb.AppendLine("    - *$($Matches[2].Trim())*")
                    }
                }
            }
        }
        
        if ($ps.Tasks.Count -gt 0) {
            [void]$sb.AppendLine("- **Completed Tasks ($($ps.Tasks.Count))**:")
            foreach ($t in $ps.Tasks) {
                $statusText = if ($t.Status) { $t.Status } else { "Done" }
                [void]$sb.AppendLine("  - [$statusText] **$($t.Title)**")
                if ($t.Summary) {
                    [void]$sb.AppendLine("    - $($t.Summary)")
                }
            }
        }
        [void]$sb.AppendLine("")
    }
}

if ($activeProjectsCount -eq 0) {
    [void]$sb.AppendLine("*(No new milestones logged in this period window)*")
    [void]$sb.AppendLine("")
}

# 6. Architectural Decisions Section
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Architectural Decisions (ADRs)")
[void]$sb.AppendLine("")

if ($allDecisions.Count -gt 0) {
    [void]$sb.AppendLine("| Date | Project | Architectural Decision |")
    [void]$sb.AppendLine("| :--- | :--- | :--- |")
    foreach ($d in $allDecisions) {
        [void]$sb.AppendLine("| $($d.Date) | [[Projects/$($d.Project)/Decisions|$($d.Project)]] | $($d.Title) |")
    }
    [void]$sb.AppendLine("")
} else {
    [void]$sb.AppendLine("*(No new ADRs logged in this period window)*")
    [void]$sb.AppendLine("")
}

# 7. Vault-Wide Reactive Query (Dataview)
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Recent Vault Activity (Dataview)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine('```dataview')
[void]$sb.AppendLine('TABLE file.folder AS "Folder", file.mtime AS "Last Modified"')
[void]$sb.AppendLine('FROM ""')
[void]$sb.AppendLine("WHERE file.mtime >= date(today) - dur($($Days) days)")
[void]$sb.AppendLine('SORT file.mtime DESC')
[void]$sb.AppendLine('LIMIT 15')
[void]$sb.AppendLine('```')
[void]$sb.AppendLine("")

# 8. Save or Output
$digestContent = $sb.ToString()
$targetFolder = Join-Path $vaultRoot $OutputDir
$targetFileName = "Digest-$digestId.md"
$targetFilePath = Join-Path $targetFolder $targetFileName

if ($DryRun) {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Preview: $digestTitle" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Output $digestContent
    exit 0
}

if (-not (Test-Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
}

[System.IO.File]::WriteAllText($targetFilePath, $digestContent, [System.Text.Encoding]::UTF8)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Executive Digest Generated Successfully!" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Title        : $digestTitle" -ForegroundColor White
Write-Host "File         : $targetFilePath" -ForegroundColor Green
Write-Host "Active Scope : $activeProjectsCount projects | $($allMilestones.Count) milestones | $($allTasks.Count) tasks | $($allDecisions.Count) decisions`n" -ForegroundColor Gray
