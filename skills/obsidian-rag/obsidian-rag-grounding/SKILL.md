---
name: obsidian-rag-grounding
description: >
  Uses Obsidian as an authoritative source of truth for tone, voice, design principles,
  and architectural constraints. Retrieves project context and system guidelines with
  cascading project-level overrides from the configured Obsidian vault to ground tasks.
---

# Obsidian RAG Grounding

Retrieves authoritative guidelines and project knowledge from Obsidian (resolving `default_vault` from `.agents/obsidian-config.json`) to ground the agent before drafting copy, designing UI components, setting up architecture, or making style decisions.

Supports **Cascading Directives**: Project-specific overrides take precedence over global `System/` defaults.

---

## 1. When to Invoke

Run this skill:
- **Proactively**: Before any creative, styling, user-facing copy, or architecture planning task.
- **On-Demand**: When the user requests "ground with Obsidian", "check our voice/tone in Obsidian", "what are our design rules in the vault?", or uses `/obsidian-rag`.

---

## 2. Step 0: Read the AI Constitution First

Before any cascading lookup, read the vault's constitution note once per session (cache it —
don't re-fetch on every subsequent grounding call this session unless the etag changes):

- Path: `ai_context.path` in `.agents/obsidian-config.json` (default `AI-CONTEXT.md` at vault root).
- If `ai_context.enabled` is `false` or the note doesn't exist, skip silently — don't block or
  suggest bootstrapping unless the user asks.
- This one note carries voice thesis, banned vocabulary, archetype switching rules, and
  operational guardrails (including whether visual boards are allowed). It replaces, not
  supplements, a separate "Voice & Tone" lookup when both exist and agree — only fall through
  to the cascade below for anything the constitution doesn't cover or for project-specific
  overrides.

## 3. Cascading Retrieval Engine (Project Override > Areas Default > Resources)

For anything not already settled by `AI-CONTEXT.md`, resolve directives (Voice & Tone, Design Tokens, Architecture Standards) using a cascading priority based on **PARA**:

```
[ Step 1: Check Project-Specific Note / Section ] ──(Found?)──> Use Project Override
                      │ (Not Found)
                      ▼
[ Step 2: Fall back to `Areas/` Standards Note ]  ──(Found?)──> Use Area Standard
                      │ (Not Found)
                      ▼
[ Step 3: Check Legacy `System/` Note ]          ─────────────> Use Legacy Default
```

### Directives Resolution Matrix:

1. **Voice & Tone Resolution**:
   - *Priority 1 (Project Override)*: Look for `Projects/<ProjectName>/Tone and Voice.md` or section `## Voice, Tone & Design Principles` in `Projects/<ProjectName>/Overview.md`.
   - *Priority 2 (Area Standard)*: Look for `Areas/Tone and Voice.md` (fallback: `System/Tone and Voice.md`).

2. **Design System & Styling Tokens Resolution**:
   - *Priority 1 (Project Override)*: Look for `Projects/<ProjectName>/Design Tokens.md` or section `## Design Tokens` in `Projects/<ProjectName>/Overview.md`.
   - *Priority 2 (Area Standard)*: Look for `Areas/Design Tokens.md` (fallback: `System/Design Tokens.md`).

3. **Architecture & Engineering Principles Resolution**:
   - *Priority 1 (Project Override)*: Look for `Projects/<ProjectName>/Architecture.md` or section `## Architecture & Tech Stack` in `Projects/<ProjectName>/Overview.md`.
   - *Priority 2 (Area Standard)*: Look for `Areas/Architecture Principles.md` (fallback: `System/Architecture Principles.md`).

4. **Technical Resources & Cheat-Sheets (`Resources/`)**:
   - Check `Resources/` for cheat-sheets, SDK specs, or prompt guides matching the active stack (e.g. `Resources/MCP-Protocols/`, `Resources/Python-Conventions.md`).

5. **Recent Decisions (Top 3–5 ADRs)**:
   - Read `Projects/<ProjectName>/Decisions.md` and parse the **latest 3 to 5 ADR entries** for active constraints and rejected alternatives.

---

## 4. Grounding Context Emission

Synthesize the resolved directives and output a clear, structured **Grounding Brief** into the active context before proceeding:

```markdown
## 🧠 Obsidian Grounding: [<ProjectName>]
- **Voice & Tone**: <Rules summary> `[Project Override | Area Standard]`
- **Design & Styling Tokens**: <Theme/tokens summary> `[Project Override | Area Standard]`
- **Active Architectural Decisions**:
  - `ADR-YYYYMMDD`: <Summary of accepted decision and key constraint>
  - `ADR-YYYYMMDD`: <Summary of rejected alternative to avoid re-evaluating>
- **Referenced Resources**: <List of relevant notes from Resources/ if applicable>
- **Resolved Sources**:
  - Voice: `Projects/<ProjectName>/Tone and Voice.md` (or `Areas/Tone and Voice.md`)
  - Design: `Projects/<ProjectName>/Design Tokens.md` (or `Areas/Design Tokens.md`)
  - Architecture: `Projects/<ProjectName>/Architecture.md` (or `Areas/Architecture Principles.md`)
  - Project Overview: `Projects/<ProjectName>/Overview.md`
  - Decisions Log: `Projects/<ProjectName>/Decisions.md`
```

---

## 5. Execution Guidance

Once grounded:
- **Enforce Effective Directives**: Strictly follow the resolved voice, design, and architecture rules (prioritizing project overrides).
- **Respect Past Rationale & Rejections**: Never propose or implement an architecture pattern or dependency that was explicitly rejected in the ADR log unless the user explicitly asks to revisit it.

---

## 6. Fallback & Graceful Degradation

- If the `obsidian` MCP toolset is missing or unreachable:
  - Do NOT crash, error out, or halt the conversation.
  - Emit: `⚠️ Obsidian Grounding: Obsidian MCP server not detected or unreachable. Grounding with local repository context only. (Run /obsidian-setup to configure).`
  - Proceed with existing repository directives, AGENTS.md, or system prompts.
- If no project note or system note exists in Obsidian:
  - Do NOT crash or block the user.
  - Emit: `Obsidian Grounding: No notes found in vault '<VaultName>' for <ProjectName>. Proceeding with repository context.`
  - Suggest running `obsidian-project-init` (`/obsidian-init`) to bootstrap the project.
