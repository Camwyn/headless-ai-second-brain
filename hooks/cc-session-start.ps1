# Claude Code SessionStart adapter -> Obsidian workflow briefing.
# stdout is injected by Claude Code as session context. Emits, when relevant:
#   - stale site-health audit reminders   (opt-in: only when obsidian-config.json `site_audit.sites` is set)
#   - a pending Obsidian live-sync queue for the current project, auto-draining it when the vault is reachable
# Read-only w.r.t. the repo. Never fails the session. Prints nothing when all is current.
#
# Wire it up in ~/.claude/settings.json:
#   "hooks": { "SessionStart": [ { "hooks": [ { "type": "command",
#     "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<HOME>/.agents/hooks/cc-session-start.ps1\"" } ] } ] }

$ErrorActionPreference = 'SilentlyContinue'

try {
    $raw = [Console]::In.ReadToEnd()
    $payload = if ($raw) { $raw | ConvertFrom-Json } else { $null }

    # Don't re-brief on every compaction.
    if ($payload -and $payload.source -eq 'compact') { exit 0 }

    $cwd = if ($payload -and $payload.cwd) { [string]$payload.cwd } else { (Get-Location).Path }

    # --- Resolve vault path: $env:OBSIDIAN_VAULT_PATH, then config `vault_path`. ---
    $cfgPath = Join-Path $HOME '.agents\obsidian-config.json'
    $cfg = $null
    if (Test-Path $cfgPath) { $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json }
    $vault = $env:OBSIDIAN_VAULT_PATH
    if (-not $vault -and $cfg -and $cfg.vault_path) { $vault = [string]$cfg.vault_path }

    $lines = New-Object System.Collections.Generic.List[string]

    # --- 1. Site-audit cadence check (opt-in via config `site_audit`) ---
    if ($cfg -and $cfg.site_audit -and $cfg.site_audit.sites -and $vault) {
        $reportsRel = if ($cfg.site_audit.reports_dir) { $cfg.site_audit.reports_dir } else { 'Areas/Audits' }
        $cadence = if ($cfg.site_audit.cadence_days) { [int]$cfg.site_audit.cadence_days } else { 7 }
        $auditDir = Join-Path $vault ($reportsRel -replace '/', '\')
        if (Test-Path $auditDir) {
            $stale = New-Object System.Collections.Generic.List[string]
            foreach ($prop in $cfg.site_audit.sites.PSObject.Properties) {
                $domain = $prop.Name; $slug = [string]$prop.Value
                $newest = Get-ChildItem -Path $auditDir -Filter "*-$slug-site-health-report.md" -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending | Select-Object -First 1
                $age = $null
                if ($newest -and $newest.BaseName -match '^(\d{4}-\d{2}-\d{2})') {
                    try { $age = (New-TimeSpan -Start ([datetime]$Matches[1]) -End (Get-Date)).Days } catch {}
                }
                if ($null -eq $age) { $stale.Add("$domain (no report found)") }
                elseif ($age -gt $cadence) { $stale.Add("$domain (last audited ${age}d ago)") }
            }
            if ($stale.Count -gt 0) {
                $lines.Add("STALE SITE AUDITS - re-run the site-health audit for:")
                foreach ($s in $stale) { $lines.Add("  - $s") }
            }
        }
    }

    # --- 2. Pending Obsidian live-sync queue for this project ---
    $queuePath = Join-Path $cwd '.agents\pending-sync.json'
    if (Test-Path $queuePath) {
        $q = Get-Content $queuePath -Raw | ConvertFrom-Json
        $n = @($q).Count
        if ($n -gt 0) {
            $flushDisabled = $cfg -and $cfg.auto_sync -and ($cfg.auto_sync.flush_on_session_start -eq $false)
            $syncCli = Join-Path $HOME '.agents\bin\obsidian-sync.ps1'
            if (-not $flushDisabled -and $vault -and (Test-Path $vault) -and (Test-Path $syncCli)) {
                # Auto-drain into the vault Worklog. Non-blocking; append-only.
                & powershell -NoProfile -ExecutionPolicy Bypass -File $syncCli flush $cwd *> $null
                $after = 0
                try { $after = @(Get-Content $queuePath -Raw | ConvertFrom-Json).Count } catch {}
                if ($after -eq 0) {
                    $lines.Add("OBSIDIAN LIVE-SYNC: auto-drained $n queued milestone(s) into the vault Worklog on session start.")
                } else {
                    $lines.Add("OBSIDIAN LIVE-SYNC: $after of $n milestone(s) still queued after auto-flush (target Worklog missing?) - run /obsidian-flush or the obsidian-auto-sync skill.")
                }
            } else {
                $lines.Add("OBSIDIAN LIVE-SYNC: $n milestone(s) queued in .agents/pending-sync.json - vault unreachable; drain via the obsidian-auto-sync skill (etag-safe) or /obsidian-flush.")
            }
        }
    }

    if ($lines.Count -gt 0) {
        Write-Output "== Obsidian workflow briefing =="
        $lines | ForEach-Object { Write-Output $_ }
    }
} catch {
    exit 0
}

exit 0
