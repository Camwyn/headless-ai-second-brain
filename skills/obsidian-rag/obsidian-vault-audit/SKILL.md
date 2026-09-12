---
name: obsidian-vault-audit
description: >
  Autonomous diagnostic health and link integrity audit for Obsidian vaults.
  Scans for broken wikilinks, orphan notes, missing project companion notes
  (Overview, Tasks, Worklog, Decisions), frontmatter schema violations, drifted
  content mirrors (declared repo/vault duplicate pairs), and a stale inbox backlog,
  with automated remediation. Trigger with '/audit-vault', 'audit vault', or 'vault health'.
---

# Obsidian Vault Health & Link Integrity Auditor

The **Vault Health Auditor** (`/audit-vault`) performs deep diagnostic analysis across an Obsidian vault to detect broken internal links, identify missing project companion notes, flag unlinked orphan notes, and validate frontmatter schemas.

---

## 1. When to Use

Activate `/audit-vault` when:
- Verifying vault integrity after restructuring, note renames, or folder migrations.
- Auditing link health and identifying broken wikilinks (`[[target]]`) or markdown links (`[text](url)`).
- Checking that all active codebases in `Projects/` have required companion notes (`Overview.md`, `Tasks.md`, `Worklog.md`, `Decisions.md`).
- Finding orphan notes that lack incoming backlinks from MOCs or other notes.
- Validating YAML frontmatter compliance against suite schemas.

---

## 2. Multi-Vector Diagnostics

The auditor evaluates eight distinct dimensions:

| Vector | Diagnostic Focus | Threshold / Standard |
| :--- | :--- | :--- |
| **Broken Wikilinks** | Broken `[[target]]`, `[[target\|alias]]`, or `[[target#heading]]` | Target must exist by exact path, stem, or attachment |
| **Markdown Links** | Broken relative file links `[label](path/to/file.md)` | File must exist relative to vault root |
| **Companion Completeness** | Missing companion notes in `Projects/<Project>/` | Must contain `Overview.md`, `Tasks.md`, `Worklog.md`, `Decisions.md` |
| **Orphan Notes** | Notes with 0 incoming backlinks | Flags unindexed leaves not referenced in any MOC |
| **Stub Notes** | Empty or near-empty notes (<30 characters) | Flags forgotten placeholders or zero-byte files |
| **Frontmatter Compliance** | Missing YAML blocks or required fields | Checks `pillar`, `status`, `tags`, and timestamps |
| **Mirror Drift** | Declared `mirror:` pairs (see `rules/content-mirror-sync.md`) that are one-sided, unreachable, or diverged | Both sides must declare each other and agree substantively |
| **Inbox Backlog** | Notes in `<inbox_dir>/` (default `00-INBOX`) older than `inbox.stale_after_days` (default 7) | Excludes `<inbox_dir>/<processed_subfolder>/` (default `Processed`) and its own `README.md` |

### Mirror Drift — How It's Checked
This vector is agent-driven, not part of `audit-vault.ps1`/`.sh` (those scripts only see the
vault filesystem; the repo side of a mirror lives elsewhere on disk, sometimes on a different
machine entirely, so a generic script can't resolve it reliably):
1. Search the vault for every note with a `mirror.repo` + `mirror.path` frontmatter pair.
2. For each, check whether the named repo is reachable in this session (open, or resolvable
   from a known local project path). If not reachable, report it as **Unverifiable** rather
   than **Drifted** — absence of evidence isn't evidence of drift.
3. If reachable, read the repo file and check whether it declares the matching `mirror.vault`
   back — flag a **one-sided declaration** if not.
4. Diff the two for *substantive* content divergence, not formatting differences that are
   expected per `content-mirror-sync.md` (frontmatter shape, link syntax, an added H1/excerpt).
   Flag pairs whose actual content has diverged as **Drifted**, and suggest `/obsidian-mirror`
   to reconcile.
5. Never remediate a drifted mirror automatically — always report it and let the user (or a
   follow-up `/obsidian-mirror` run) decide the direction of the fix.

### Inbox Backlog — How It's Checked
Unlike Mirror Drift, this is a pure filesystem check (location + age, no cross-repo
reachability or semantic judgment needed) — it runs inside `audit-vault.ps1`/`.sh` directly,
not as a separate agent-driven pass:
1. List every `.md` file directly under `<inbox_dir>/`, excluding `README.md` and anything
   inside `<inbox_dir>/<processed_subfolder>/` — moved-and-filed notes never get re-flagged.
2. Age comes from frontmatter `created:` if present, else the file's last-write time.
3. Anything older than `inbox.stale_after_days` is **Stale**; report the total count either way.
4. **Stays out of the numeric Health Score**, same as Mirror Drift — a full inbox is a
   workflow-hygiene signal, not structural vault integrity.
5. Never move or file anything automatically — this vector only reports. See
   `obsidian-status` for the on-demand skill that offers to help file a stale backlog.

---

## 3. Execution

### Running the Diagnostic Engine

Run the native auditor script via `run_command`:

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\audit-vault.ps1
```

**Auto-Scaffolding Missing Companions:**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\audit-vault.ps1 -ScaffoldMissing
```

**Markdown Report Output:**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\audit-vault.ps1 -Format Markdown
```

**JSON Output (Programmatic/CI):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\audit-vault.ps1 -Format Json
```

**macOS / Linux:**
```bash
./scripts/audit-vault.sh
```

---

## 4. Health Scoring Algorithm

The vault receives an overall **Health Score (0-100%)**:

$$\text{Health Score} = \max(0, 100 - (2 \times \text{BrokenLinks}) - (5 \times \text{MissingCompanions}) - (2 \times \text{StubNotes}))$$

- 🟢 **90 - 100%**: **EXCELLENT** — Vault is tightly linked, companions are complete, and indices are sound.
- 🟡 **75 - 89%**: **GOOD** — Minor link gaps or unlinked notes, but core structure is intact.
- 🔴 **< 75%**: **ATTENTION NEEDED** — Significant broken links or missing project companion notes require remediation.

Mirror Drift and Inbox Backlog findings are reported separately, not folded into this score —
Mirror Drift depends on what's reachable in the current session, and Inbox Backlog is a
workflow-hygiene signal rather than a structural fact about the vault.

---

## 5. Report Template

Format the user-facing diagnostic report cleanly:

```markdown
# 🏥 Vault Health & Link Integrity Audit: <Vault Name>

**Health Score**: 🟢 **92 / 100 (EXCELLENT)** | **Total Notes**: 374

| Metric | Value | Status |
|---|---|---|
| **Broken Links** | 0 | ✅ None |
| **Project Companion Gaps** | 0 | ✅ Complete |
| **Stub Notes (<30 chars)** | 2 | ℹ️ Review Stubs |
| **Orphan Notes** | 45 | ℹ️ Backlink audit |

---

### ⚠️ Broken Link Details
*(Omitted if 0 broken links)*
| Source Note | Line | Broken Target | Type |
|---|---|---|---|
| `Areas/Brand/Design.md` | 42 | `[[Old-Color-Palette]]` | Wikilink |

---

### 📁 Project Companion Status
| Project Directory | Status | Missing Notes |
|---|---|---|
| `Projects/project-alpha` | ✅ Complete | None |
| `Projects/project-beta` | ⚠️ Incomplete | `Decisions.md` |

---

### 🪞 Mirror Drift
*(Omitted if no declared mirrors, or none found drifted/unreachable)*
| Vault Note | Repo Mirror | Status |
|---|---|---|
| `Areas/.../The Headless Brain....md` | `camwyn-and-co/src/notes/the-headless-brain.md` | ⚠️ Drifted — run `/obsidian-mirror` |
| `Areas/.../Some Other Note.md` | `some-repo/docs/x.md` | ℹ️ Unverifiable — repo not open this session |

### Inbox Backlog
*(Omitted if the inbox is empty or nothing exceeds the threshold)*
| Note | Age | Status |
|---|---|---|
| `00-INBOX/Quick idea about X.md` | 12 days | ⚠️ Stale |

3 total in 00-INBOX, 1 stale (>7 days).

### 💡 Remediation Guidance
1. **Auto-Scaffold Missing Companions**: Run `/audit-vault --fix-companions` to generate missing templates.
2. **Fix Renamed Wikilinks**: Update old target stems in affected notes.
3. **Index Orphan Notes**: Add unlinked notes into the appropriate Area MOC or `PARA-Index.md`.
4. **Reconcile Drifted Mirrors**: Run `/obsidian-mirror` on each flagged pair.
5. **Clear Inbox Backlog**: Run `/obsidian-status` for a filing offer, or file the notes manually.
```

---

## 6. Automated Remediation Workflow

When companion notes or links need repair:
1. **Scaffolding**: Automatically generate canonical YAML frontmatter, title, and companion link back to `[[Projects/<Project>/Overview]]`.
2. **Link Canonicalization**: For broken links that point to notes renamed or moved to `Areas/` or `Resources/`, suggest or apply the closest stem match.
3. **MOC Linking**: Present orphan notes grouped by folder so the user can quickly link them into parent Map of Content notes.
