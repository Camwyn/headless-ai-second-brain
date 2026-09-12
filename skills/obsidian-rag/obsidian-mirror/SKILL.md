---
name: obsidian-mirror
description: >
  Establishes or re-syncs a declared mirror relationship between a repo file and a standalone
  Obsidian vault note — two full, independent, kept-in-sync copies, for cases where someone
  (a journalist, blogger, or anyone cross-referencing content in their vault) wants both, not
  a canonical copy plus a pointer stub. Use when the user says "mirror this to Obsidian",
  "keep this in sync with the vault", or runs /obsidian-mirror.
---

# Obsidian Mirror

Declares (or re-syncs) a mirror between a file in the current repo and a note in the vault,
per the `mirror:` frontmatter convention in `rules/content-mirror-sync.md`. Read that rule
first — this skill is the mechanism for *establishing* what it *maintains*.

## 1. When to Use

- **On-demand**: user asks to mirror a specific file, or asks "does X have a copy in
  Obsidian?" and the answer should be "not yet, want one?"
- **Retroactively**: two files are already duplicates of each other (found by search, or
  pointed out by the user) and should be formally declared as a mirror pair going forward,
  rather than left as an undeclared, driftable duplicate.
- **Re-sync**: a declared mirror has drifted (per `obsidian-vault-audit`'s Mirror Drift check,
  or a user noticing by hand) and needs reconciling.

## 2. Establishing a New Mirror

1. **Identify source and destination.** The source is the file already open or referenced in
   the conversation. Ask the user for the destination if it isn't obvious — for a repo file
   mirroring *into* the vault, a reasonable default is `Areas/<Org>/Dispatches/<Title>.md` for
   blog/editorial content, or `Projects/<repo>/<Title>.md` for project-specific writing. Don't
   guess silently on ambiguous placement; a wrong guess here is expensive to unwind later.
2. **If the destination doesn't exist**, create it — adapting format to the target's
   conventions, not a literal copy:
   - Repo → vault: add an explicit `# H1` heading and an excerpt blockquote if the repo relies
     on a templating engine to render `title`/`excerpt` from frontmatter (the vault note is
     standalone and needs to carry that visibly). Convert plain markdown links that point at
     other vault-tracked content into `[[wikilinks]]`.
   - Vault → repo: strip vault-only frontmatter fields the repo's schema doesn't use; convert
     `[[wikilinks]]` to plain links or repo-relative paths as the repo's own convention expects.
3. **Set the `mirror:` frontmatter on both files** (see `rules/content-mirror-sync.md` for the
   exact shape). Both sides must declare it — a one-sided declaration is treated as a finding
   by `obsidian-vault-audit`, not a valid mirror.
4. **Confirm to the user**: name both file paths and which direction the initial content came
   from.

## 3. Re-syncing an Existing Mirror

1. Read both files (`obsidian_read_note` for the vault side, capturing its etag; the local
   file tools for the repo side).
2. Diff them substantively — ignore known-and-expected format differences (frontmatter shape,
   link syntax, an added H1/excerpt) and look for actual content divergence: sections one side
   has that the other doesn't, factual changes, corrections.
3. If one side is clearly newer (check `updated_at`/frontmatter dates, or ask if ambiguous),
   propagate its substantive changes to the other, adapting format per the rules in §2.2.
4. If both have changed independently since the last sync (a real merge conflict, not just a
   one-way update), present both versions' differences to the user and ask how to reconcile —
   don't silently pick one.
5. Update both files' `updated_at` and confirm the resync to the user.

## 4. Guardrails

- **Never collapse a mirror into a stub.** If a mirror pair should actually become one
  canonical copy plus a pointer (the ManyHats `CONTEXT.md` pattern), that's a different,
  deliberate decision the user makes explicitly — not something this skill or
  `content-mirror-sync.md` ever does on its own initiative.
- **Never fabricate the other side's content** if it's unreachable this session (repo not
  open, vault MCP disconnected). Say so and stop.
- **Read before writing**, same as every other skill in this suite — use `if_match`/etag
  guards on the vault side.
