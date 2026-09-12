# PowerShell 5.1 & Core compatible vault health auditor
param (
    [string]$VaultPath,
    [ValidateSet("Console", "Markdown", "Json")]
    [string]$Format = "Console",
    [switch]$ScaffoldMissing = $false
)

# 1. Resolve vault path: -VaultPath arg, then $env:OBSIDIAN_VAULT_PATH, then config `vault_path`.
# Config is loaded here regardless of which path source wins, since the inbox settings below
# (dir name, staleness threshold) come from it too.
$cfg = $null
$configPath = "$HOME\.agents\obsidian-config.json"
if (Test-Path $configPath) {
    try { $cfg = Get-Content $configPath -Raw | ConvertFrom-Json } catch {}
}
if (-not $VaultPath) { $VaultPath = $env:OBSIDIAN_VAULT_PATH }
if (-not $VaultPath -and $cfg -and $cfg.vault_path) { $VaultPath = [string]$cfg.vault_path }

if (-not $VaultPath -or -not (Test-Path $VaultPath)) {
    Write-Error "Vault path not found. Set 'vault_path' in ~/.agents/obsidian-config.json, `$env:OBSIDIAN_VAULT_PATH, or pass -VaultPath."
    exit 1
}

$vaultRoot = (Get-Item $VaultPath).FullName
$excludeDirs = @(".obsidian", ".git", ".trash", "gemini-scribe")

# 2. Gather All Files (Markdown and Attachments)
$allFiles = Get-ChildItem -Path $vaultRoot -Filter "*.md" -Recurse | Where-Object {
    $rel = $_.FullName.Substring($vaultRoot.Length).TrimStart('\', '/')
    $firstPart = $rel.Split([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)[0]
    $excludeDirs -notcontains $firstPart
}

$attachmentFiles = Get-ChildItem -Path $vaultRoot -File -Recurse | Where-Object {
    $_.Extension -ne ".md" -and ($excludeDirs -notcontains ($_.FullName.Substring($vaultRoot.Length).TrimStart('\', '/').Split([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)[0]))
}

$noteMapByRelativePath = @{}
$noteMapByStem = @{}

foreach ($f in $allFiles) {
    $rel = $f.FullName.Substring($vaultRoot.Length).TrimStart('\', '/').Replace('\', '/')
    $stem = if ($f.Name.EndsWith(".md", [System.StringComparison]::OrdinalIgnoreCase)) {
        $f.Name.Substring(0, $f.Name.Length - 3)
    } else {
        $f.Name
    }
    
    $noteMapByRelativePath[$rel] = $f
    if ($rel.EndsWith(".md", [System.StringComparison]::OrdinalIgnoreCase)) {
        $noteMapByRelativePath[$rel.Substring(0, $rel.Length - 3)] = $f
    }
    
    if (-not $noteMapByStem.ContainsKey($stem)) {
        $noteMapByStem[$stem] = [System.Collections.ArrayList]::new()
    }
    [void]$noteMapByStem[$stem].Add($rel)
}

foreach ($af in $attachmentFiles) {
    $rel = $af.FullName.Substring($vaultRoot.Length).TrimStart('\', '/').Replace('\', '/')
    $noteMapByRelativePath[$rel] = $af
    $noteMapByRelativePath[$af.Name] = $af
    if (-not $noteMapByStem.ContainsKey($af.Name)) {
        $noteMapByStem[$af.Name] = [System.Collections.ArrayList]::new()
    }
    [void]$noteMapByStem[$af.Name].Add($rel)
}

# 3. Analyze Links & Content
$brokenLinks = [System.Collections.ArrayList]::new()
$allTargetedNotes = [System.Collections.Generic.HashSet[string]]::new()
$stubNotes = [System.Collections.ArrayList]::new()
$schemaWarnings = [System.Collections.ArrayList]::new()

$wikilinkRegex = [regex]'\[\[(.*?)\]\]'
$mdlinkRegex = [regex]'\[.*?\]\((.*?)\)'

foreach ($f in $allFiles) {
    $rel = $f.FullName.Substring($vaultRoot.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = try { [System.IO.File]::ReadAllLines($f.FullName) } catch { @() }

    if (-not $lines -or ($lines -join "").Trim().Length -lt 30) {
        [void]$stubNotes.Add([PSCustomObject]@{
            File = $rel
            Size = if ($f.Length) { $f.Length } else { 0 }
        })
    }

    # Frontmatter check
    $hasFrontmatter = $false
    if ($lines.Count -ge 2 -and $lines[0].Trim() -eq "---") {
        $hasFrontmatter = $true
    }
    if (-not $hasFrontmatter -and $rel -notmatch 'README\.md$') {
        [void]$schemaWarnings.Add([PSCustomObject]@{
            File = $rel
            Issue = "Missing YAML frontmatter block"
        })
    }

    # Line-by-line link parsing
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNum = $i + 1

        # Wikilinks: [[target]] or [[target|alias]] or [[target#anchor]]
        $matches = $wikilinkRegex.Matches($line)
        foreach ($m in $matches) {
            $rawLink = $m.Groups[1].Value.Trim()
            if (-not $rawLink) { continue }

            $linkTarget = $rawLink.Split('|')[0].Trim()
            $linkTarget = $linkTarget.Split('#')[0].Trim()
            if (-not $linkTarget) { continue }

            $targetNormalized = $linkTarget.Replace('\', '/').TrimEnd('/')
            if ($targetNormalized.EndsWith(".md", [System.StringComparison]::OrdinalIgnoreCase)) {
                $targetNormalized = $targetNormalized.Substring(0, $targetNormalized.Length - 3)
            }

            $resolved = $false
            if ($noteMapByRelativePath.ContainsKey($targetNormalized) -or $noteMapByRelativePath.ContainsKey("$targetNormalized.md") -or $noteMapByRelativePath.ContainsKey($linkTarget)) {
                $resolved = $true
                $resolvedPath = if ($noteMapByRelativePath.ContainsKey($targetNormalized)) { $targetNormalized } else { "$targetNormalized.md" }
                [void]$allTargetedNotes.Add($resolvedPath)
            }
            
            $targetStem = if ($targetNormalized.Contains('/')) { $targetNormalized.Split('/')[-1] } else { $targetNormalized }
            if (-not $resolved -and ($noteMapByStem.ContainsKey($targetStem) -or $noteMapByStem.ContainsKey($linkTarget))) {
                $resolved = $true
                $stemKey = if ($noteMapByStem.ContainsKey($targetStem)) { $targetStem } else { $linkTarget }
                foreach ($p in $noteMapByStem[$stemKey]) {
                    [void]$allTargetedNotes.Add($p)
                }
            }
            if (-not $resolved) {
                $assetPath = Join-Path $vaultRoot $targetNormalized
                $assetInAssets = Join-Path $vaultRoot "assets\$targetNormalized"
                if ((Test-Path $assetPath) -or (Test-Path "$assetPath.canvas") -or (Test-Path "$assetPath.pdf") -or (Test-Path "$assetPath/README.md") -or (Test-Path $assetInAssets)) {
                    $resolved = $true
                }
            }

            if (-not $resolved) {
                [void]$brokenLinks.Add([PSCustomObject]@{
                    SourceFile = $rel
                    LineNumber = $lineNum
                    TargetLink = $rawLink
                    Type       = "Wikilink"
                })
            }
        }

        # Markdown links: [text](target)
        $mdMatches = $mdlinkRegex.Matches($line)
        foreach ($m in $mdMatches) {
            $rawUrl = $m.Groups[1].Value.Trim()
            # Ignore web URLs, file paths, mailto, in-page anchors, or regex/assertion syntax
            if ($rawUrl -match '^(https?://|file:///|mailto:|#|\w+:\s*\d+)' -or -not $rawUrl) { continue }

            $urlTarget = $rawUrl.Split('#')[0].Split('?')[0].Trim()
            $urlTarget = [System.Uri]::UnescapeDataString($urlTarget).Replace('\', '/').TrimEnd('/')
            if (-not $urlTarget) { continue }

            $resolved = $false
            if ($noteMapByRelativePath.ContainsKey($urlTarget) -or $noteMapByRelativePath.ContainsKey("$urlTarget.md") -or $noteMapByRelativePath.ContainsKey($rawUrl)) {
                $resolved = $true
                [void]$allTargetedNotes.Add($urlTarget)
            }
            $urlStem = if ($urlTarget.Contains('/')) { $urlTarget.Split('/')[-1] } else { $urlTarget }
            if (-not $resolved -and ($noteMapByStem.ContainsKey($urlStem) -or $noteMapByStem.ContainsKey($rawUrl))) {
                $resolved = $true
                $stemKey = if ($noteMapByStem.ContainsKey($urlStem)) { $urlStem } else { $rawUrl }
                foreach ($p in $noteMapByStem[$stemKey]) {
                    [void]$allTargetedNotes.Add($p)
                }
            }
            if (-not $resolved) {
                $assetPath = Join-Path $vaultRoot $urlTarget
                $assetInAssets = Join-Path $vaultRoot "assets\$urlTarget"
                if ((Test-Path $assetPath) -or (Test-Path "$assetPath.canvas") -or (Test-Path "$assetPath.pdf") -or (Test-Path "$assetPath/README.md") -or (Test-Path $assetInAssets)) {
                    $resolved = $true
                }
            }

            if (-not $resolved) {
                [void]$brokenLinks.Add([PSCustomObject]@{
                    SourceFile = $rel
                    LineNumber = $lineNum
                    TargetLink = $rawUrl
                    Type       = "MarkdownLink"
                })
            }
        }
    }
}

# 4. Check Project Companion Notes
$requiredCompanions = @("Overview.md", "Tasks.md", "Worklog.md", "Decisions.md")
$projectsDir = Join-Path $vaultRoot "Projects"
$missingCompanions = [System.Collections.ArrayList]::new()

if (Test-Path $projectsDir) {
    $projectFolders = Get-ChildItem -Path $projectsDir -Directory
    foreach ($p in $projectFolders) {
        $projName = $p.Name
        $missing = [System.Collections.ArrayList]::new()
        foreach ($c in $requiredCompanions) {
            $expected = Join-Path $p.FullName $c
            if (-not (Test-Path $expected)) {
                [void]$missing.Add($c)
            }
        }
        if ($missing.Count -gt 0) {
            [void]$missingCompanions.Add([PSCustomObject]@{
                Project      = $projName
                MissingFiles = $missing
                Path         = "Projects/$projName"
            })
            
            if ($ScaffoldMissing) {
                foreach ($m in $missing) {
                    $filePath = Join-Path $p.FullName $m
                    $noteType = ([IO.Path]::GetFileNameWithoutExtension($m)).ToLower()
                    $scaffoldContent = @"
---
title: "$projName - $([IO.Path]::GetFileNameWithoutExtension($m))"
type: $noteType
pillar: project
status: active
project: "[[Projects/$projName/Overview|$projName]]"
created_at: "$(Get-Date -Format 'yyyy-MM-dd HH:mm')"
updated_at: "$(Get-Date -Format 'yyyy-MM-dd HH:mm')"
---

# $projName — $([IO.Path]::GetFileNameWithoutExtension($m))

Companion note for [[Projects/$projName/Overview|$projName]].
"@
                    [System.IO.File]::WriteAllText($filePath, $scaffoldContent, [System.Text.Encoding]::UTF8)
                }
            }
        }
    }
}

# 5. Check Orphan Notes
$orphanNotes = [System.Collections.ArrayList]::new()
$exemptOrphans = @("PARA-Index.md", "README.md")

foreach ($f in $allFiles) {
    $rel = $f.FullName.Substring($vaultRoot.Length).TrimStart('\', '/').Replace('\', '/')
    $relWithoutExt = if ($rel.EndsWith(".md", [System.StringComparison]::OrdinalIgnoreCase)) { $rel.Substring(0, $rel.Length - 3) } else { $rel }
    $baseName = $f.Name

    if ($exemptOrphans -contains $baseName) { continue }
    if ($baseName.EndsWith("MOC.md")) { continue }

    $isTargeted = $false
    if ($allTargetedNotes.Contains($rel) -or $allTargetedNotes.Contains($relWithoutExt)) {
        $isTargeted = $true
    }

    if (-not $isTargeted) {
        [void]$orphanNotes.Add([PSCustomObject]@{
            File = $rel
            Folder = [IO.Path]::GetDirectoryName($rel).Replace('\', '/')
        })
    }
}

# 5.5. Check Inbox Backlog - pure filesystem check (location + age), so it lives here in the
# deterministic script rather than as an agent-driven vector like Mirror Drift. Stays out of
# the Health Score below: a full inbox is a workflow-hygiene signal, not structural integrity.
$inboxDirName = if ($cfg -and $cfg.para -and $cfg.para.inbox_dir) { [string]$cfg.para.inbox_dir } else { "00-INBOX" }
$staleAfterDays = if ($cfg -and $cfg.inbox -and $cfg.inbox.stale_after_days) { [int]$cfg.inbox.stale_after_days } else { 7 }
$processedSubfolder = if ($cfg -and $cfg.inbox -and $cfg.inbox.processed_subfolder) { [string]$cfg.inbox.processed_subfolder } else { "Processed" }

$inboxItems = [System.Collections.ArrayList]::new()
$inboxDirPath = Join-Path $vaultRoot $inboxDirName
if (Test-Path $inboxDirPath) {
    $inboxFiles = Get-ChildItem -Path $inboxDirPath -Filter "*.md" -File -Recurse | Where-Object {
        $_.Name -ne "README.md" -and
        ($_.FullName.Substring($inboxDirPath.Length).TrimStart('\', '/').Split([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)[0] -ne $processedSubfolder)
    }
    foreach ($inf in $inboxFiles) {
        $createdDate = $inf.LastWriteTime
        try {
            $firstLines = Get-Content $inf.FullName -TotalCount 15
            $frontmatterText = ($firstLines -join "`n")
            $createdMatch = [regex]::Match($frontmatterText, '(?m)^created:\s*"?([\d-]{10})"?')
            if ($createdMatch.Success) {
                $parsed = [DateTime]::MinValue
                if ([DateTime]::TryParse($createdMatch.Groups[1].Value, [ref]$parsed)) { $createdDate = $parsed }
            }
        } catch {}
        $ageDays = [Math]::Floor(((Get-Date) - $createdDate).TotalDays)
        [void]$inboxItems.Add([PSCustomObject]@{
            File    = $inf.FullName.Substring($vaultRoot.Length).TrimStart('\', '/').Replace('\', '/')
            AgeDays = $ageDays
            Stale   = $ageDays -gt $staleAfterDays
        })
    }
}
$inboxStaleItems = @($inboxItems | Where-Object { $_.Stale } | Sort-Object AgeDays -Descending)

# 6. Compute Health Score
$score = 100 - ($brokenLinks.Count * 2) - ($missingCompanions.Count * 5) - ($stubNotes.Count * 2)
if ($score -lt 0) { $score = 0 }
if ($score -gt 100) { $score = 100 }

$auditResults = [PSCustomObject]@{
    VaultName             = (Get-Item $vaultRoot).Name
    VaultPath             = $vaultRoot
    TotalNotes            = $allFiles.Count
    HealthScore           = $score
    BrokenLinksCount      = $brokenLinks.Count
    BrokenLinks           = $brokenLinks
    MissingCompanionsCount = $missingCompanions.Count
    MissingCompanions     = $missingCompanions
    OrphanNotesCount      = $orphanNotes.Count
    OrphanNotes           = ($orphanNotes | Select-Object -First 30)
    StubNotesCount        = $stubNotes.Count
    StubNotes             = $stubNotes
    SchemaWarningsCount   = $schemaWarnings.Count
    InboxTotalCount       = $inboxItems.Count
    InboxStaleCount       = $inboxStaleItems.Count
    InboxStaleItems       = $inboxStaleItems
    InboxDir              = $inboxDirName
    InboxStaleAfterDays   = $staleAfterDays
}

# 7. Render Output
if ($Format -eq "Json") {
    $auditResults | ConvertTo-Json -Depth 6
    exit 0
}

$statusLabel = if ($score -ge 90) { "EXCELLENT" } elseif ($score -ge 75) { "GOOD" } else { "ATTENTION NEEDED" }

if ($Format -eq "Markdown") {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Vault Health & Link Integrity Audit: $($auditResults.VaultName)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**Health Score**: **$score / 100 ($statusLabel)** | **Total Notes**: $($allFiles.Count)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Metric | Value | Status |")
    [void]$sb.AppendLine("|---|---|---|")
    [void]$sb.AppendLine("| Broken Links | $($brokenLinks.Count) | $(if ($brokenLinks.Count -eq 0) { 'None' } else { 'Needs Repair' }) |")
    [void]$sb.AppendLine("| Project Companion Gaps | $($missingCompanions.Count) | $(if ($missingCompanions.Count -eq 0) { 'Complete' } else { 'Missing Files' }) |")
    [void]$sb.AppendLine("| Stub Notes (<30 chars) | $($stubNotes.Count) | $(if ($stubNotes.Count -eq 0) { 'Clean' } else { 'Review Stubs' }) |")
    [void]$sb.AppendLine("| Orphan Notes | $($orphanNotes.Count) | Review backlinks |")
    [void]$sb.AppendLine("")
    
    if ($brokenLinks.Count -gt 0) {
        [void]$sb.AppendLine("### Broken Link Details ($($brokenLinks.Count))")
        [void]$sb.AppendLine("| Source Note | Line | Broken Target | Type |")
        [void]$sb.AppendLine("|---|---|---|---|")
        foreach ($b in ($brokenLinks | Select-Object -First 25)) {
            [void]$sb.AppendLine("| $($b.SourceFile) | $($b.LineNumber) | $($b.TargetLink) | $($b.Type) |")
        }
        if ($brokenLinks.Count -gt 25) {
            [void]$sb.AppendLine("*... and $($brokenLinks.Count - 25) more broken links.*")
        }
        [void]$sb.AppendLine("")
    }

    if ($missingCompanions.Count -gt 0) {
        [void]$sb.AppendLine("### Incomplete Project Companions")
        [void]$sb.AppendLine("| Project Directory | Missing Notes | Action |")
        [void]$sb.AppendLine("|---|---|---|")
        foreach ($m in $missingCompanions) {
            [void]$sb.AppendLine("| Projects/$($m.Project) | $(($m.MissingFiles) -join ', ') | Run with -ScaffoldMissing to generate |")
        }
        [void]$sb.AppendLine("")
    }

    if ($inboxItems.Count -gt 0) {
        [void]$sb.AppendLine("### Inbox Backlog")
        if ($inboxStaleItems.Count -gt 0) {
            [void]$sb.AppendLine("| Note | Age | Status |")
            [void]$sb.AppendLine("|---|---|---|")
            foreach ($item in ($inboxStaleItems | Select-Object -First 15)) {
                [void]$sb.AppendLine("| $($item.File) | $($item.AgeDays) days | Stale |")
            }
            if ($inboxStaleItems.Count -gt 15) {
                [void]$sb.AppendLine("*... and $($inboxStaleItems.Count - 15) more stale.*")
            }
            [void]$sb.AppendLine("")
        }
        [void]$sb.AppendLine("$($inboxItems.Count) total in $inboxDirName, $($inboxStaleItems.Count) stale (>$staleAfterDays days).")
        [void]$sb.AppendLine("")
    }
    Write-Output $sb.ToString()
} else {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Vault Health & Integrity Audit: $($auditResults.VaultName)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Vault Path   : $vaultRoot" -ForegroundColor Gray
    Write-Host "Total Notes  : $($allFiles.Count)" -ForegroundColor Gray
    Write-Host "Health Score : $score / 100 ($statusLabel)`n" -ForegroundColor $(if ($score -ge 85) { 'Green' } else { 'Yellow' })

    Write-Host "Diagnostic Summary:" -ForegroundColor White
    Write-Host "  - Broken Links       : $($brokenLinks.Count)" -ForegroundColor $(if ($brokenLinks.Count -eq 0) { 'Green' } else { 'Red' })
    Write-Host "  - Companion Gaps     : $($missingCompanions.Count)" -ForegroundColor $(if ($missingCompanions.Count -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "  - Stub Notes         : $($stubNotes.Count)" -ForegroundColor $(if ($stubNotes.Count -eq 0) { 'Green' } else { 'Gray' })
    Write-Host "  - Orphan Notes       : $($orphanNotes.Count)" -ForegroundColor Gray
    Write-Host "  - Inbox Backlog      : $($inboxItems.Count) total, $($inboxStaleItems.Count) stale (>$staleAfterDays days)" -ForegroundColor $(if ($inboxStaleItems.Count -eq 0) { 'Green' } else { 'Yellow' })

    if ($brokenLinks.Count -gt 0) {
        Write-Host "`nBroken Links Detected ($($brokenLinks.Count)):" -ForegroundColor Red
        foreach ($b in ($brokenLinks | Select-Object -First 15)) {
            Write-Host "  [$($b.Type)] $($b.SourceFile):$($b.LineNumber) -> '$($b.TargetLink)'" -ForegroundColor DarkYellow
        }
        if ($brokenLinks.Count -gt 15) {
            Write-Host "  ... and $($brokenLinks.Count - 15) more." -ForegroundColor Gray
        }
    }

    if ($missingCompanions.Count -gt 0) {
        Write-Host "`nProject Companion Note Gaps:" -ForegroundColor Yellow
        foreach ($m in $missingCompanions) {
            Write-Host "  - Projects/$($m.Project) missing: $(($m.MissingFiles) -join ', ')" -ForegroundColor DarkYellow
        }
        Write-Host "  Tip: Run with -ScaffoldMissing to auto-generate companion notes." -ForegroundColor Cyan
    }

    if ($inboxStaleItems.Count -gt 0) {
        Write-Host "`nInbox Backlog ($($inboxStaleItems.Count) stale):" -ForegroundColor Yellow
        foreach ($item in ($inboxStaleItems | Select-Object -First 15)) {
            Write-Host "  $($item.File) - $($item.AgeDays) days" -ForegroundColor DarkYellow
        }
        if ($inboxStaleItems.Count -gt 15) {
            Write-Host "  ... and $($inboxStaleItems.Count - 15) more." -ForegroundColor Gray
        }
    }
    Write-Host ""
}
