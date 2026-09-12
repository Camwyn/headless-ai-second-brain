# Provenance: Synced From `camwyn-agent-skills`

The `skills/obsidian-rag/` suite here, plus `rules/obsidian-live-sync.md`, `hooks/`,
`scripts/`, `bin/`, and `install.ps1` / `install.sh` at the repo root, are a **verbatim copy**
of the same files in the `camwyn-agent-skills` repo. They are already fully
generic — driven entirely by `.agents/obsidian-config.json` placeholders, no company-specific
content — so nothing was stripped or rewritten on the way in.

- **Source repo:** [`camwyn-agent-skills`](https://github.com/Camwyn/camwyn-agent-skills) (public)
- **Synced:** 2026-09-11 (source repo HEAD at sync time: `bdb0a4c`, plus uncommitted
  same-session edits to `obsidian-setup`, `obsidian-project-init`, `obsidian-rag-grounding`,
  `obsidian-config.json.example`, and `templates/AI-CONTEXT.md.example` — verify against the
  next commit after `bdb0a4c` if you need the exact diff)
- **Also synced 2026-09-11:** `install.ps1` / `install.sh` gained multi-target detection
  (installs to `~/.agents/skills` always, `~/.claude/skills` only if Claude Code/Desktop is
  detected or the user opts in) — this change originated *here* in the public kit and was
  copied back to `camwyn-agent-skills`, banner text aside. Sync isn't only one direction.
- **Also synced 2026-09-11:** New `rules/content-mirror-sync.md` and `skills/obsidian-rag/
  obsidian-mirror/` — a declared, kept-in-sync (not collapsed) repo↔vault content mirror
  pattern, for anyone (a journalist, blogger, or anyone cross-referencing) who wants full
  independent copies of something in both places on purpose. `obsidian-vault-audit` gained a
  seventh diagnostic vector, Mirror Drift, to catch it if a declared pair diverges. Built after
  this exact gap bit the project itself: a blog post and its vault dispatch copy drifted
  silently because neither declared the other, and no tool existed to notice.
- **Also synced 2026-09-11:** `install.ps1` / `install.sh` gained a third detection-based
  target, `~/.gemini/config/skills`, for Antigravity — confirmed directly against Antigravity
  itself (not assumed from docs) that it reads both a global `~/.gemini/config/skills/<name>/
  SKILL.md` and a project-level `<repo>/.agents/skills/` walking up to the git root. The blog
  post's claim that Antigravity "connects to the exact same vault using custom agent skills"
  checks out — unlike the ChatGPT claim below, this one didn't need correcting.
- **Correction, same day:** initial web research suggested ChatGPT Desktop might read
  `.agents/skills` the same way Codex does (OpenAI's docs conflate "ChatGPT desktop app,
  Codex CLI, and IDE extension" as one Skills feature). Verified directly against ChatGPT
  itself: `.agents/skills` is Codex-only. ChatGPT's own Skills feature is upload-only (`.zip`
  via Plugins → Skills → Create → Upload) and limited to Business/Enterprise/Healthcare/Edu
  accounts — not personal Free/Plus/Pro. The custom-instructions snippet in
  `connectors/chatgpt-desktop/form-instructions.md` remains the real substitute for most
  ChatGPT users, not a fallback pending a better option.

## Keeping this in sync

There is no CI job or submodule doing this automatically, on purpose — a submodule would
silently break (empty folder, no error) for anyone who clones this kit without
`--recurse-submodules` or downloads it as a GitHub zip — the realistic path for this kit's
non-technical target audience — regardless of the source repo's visibility. A deliberate copy
avoids that failure mode. See `Decisions.md` in the vault's `camwyn-agent-skills` project for
the full ADR.

Sync runs in whichever direction the change happened:
1. Confirm the change is still fully generic (no hardcoded paths, domains, or brand facts).
2. Copy the changed file(s) to the other repo, replacing the existing copy (re-apply any
   repo-specific text, like this file's banner-line exception, by hand).
3. Update the "Synced" line above with the new date and source commit.

**Not included on purpose:** `skills/audit-skills/` and `skills/wrap/` from the source repo —
they're unrelated to the second-brain workflow (IDE-wide skill telemetry and an end-of-day
close-out routine) and out of scope for this starter kit.
