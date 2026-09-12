# Content Mirror Sync

## Purpose
Some content is meant to exist as two full, independent, readable copies on purpose — not
duplication to be eliminated. A journalist or blogger, for instance, may want a blog post to
live both in its publishing repo (with the frontmatter and templating that repo needs) and as
a standalone Obsidian note (so it's searchable and cross-referenceable alongside everything
else in the vault). This rule keeps declared pairs like that from silently drifting apart —
the way a repo `CONTEXT.md` and its blog-post mirror drifted apart earlier in this project's
history, undetected until a human happened to check by hand.

This is **not** the same problem as `obsidian-live-sync.md` solves (commits/tasks/decisions
flowing into a vault Worklog) or the "collapse to one canonical copy + pointer stub" pattern
used when two files genuinely shouldn't both carry real content (see the ManyHats `CONTEXT.md`
ADR). A declared mirror is the opposite of that: **both copies stay real, both stay complete.**
Never turn a mirror into a stub — that defeats the reason it exists.

## The Mirror Declaration
A file declares a mirror relationship via frontmatter. It's opt-in and per-file — most notes
have no mirror, and that's the normal case.

**In a repo file**, pointing at its vault counterpart:
```yaml
mirror:
  vault: "Areas/00 Camwyn & Co/Dispatches/The Headless Brain - Why We Stopped Opening Obsidian.md"
```

**In a vault note**, pointing at its repo counterpart:
```yaml
mirror:
  repo: "camwyn-and-co"
  path: "src/notes/the-headless-brain.md"
```

`repo` is the repo's folder name (matching `project_aliases` in `obsidian-config.json` where
one exists), so a mirror declaration stays meaningful even if the absolute path differs across
machines. Both sides declare the relationship — a one-sided declaration is incomplete and
should be treated as a finding by `obsidian-vault-audit`, not silently accepted.

## The Behavioral Rule
Whenever you finish a substantive edit to a file that carries a `mirror` field:

1. **Check reachability.** Can this session actually reach the mirrored file? A repo path
   needs that repo open or readable from here; a vault path needs the `obsidian` MCP tools
   connected. If neither, skip to step 4 — don't guess or fabricate the other copy's content.
2. **Apply the equivalent change**, not a byte-for-byte patch. The two copies are allowed to
   differ in format — frontmatter schema, a repo's plain markdown link vs. a vault's
   `[[wikilink]]`, an H1 heading a templated site derives from frontmatter but a standalone
   vault note needs written out. Match the *substance* of the change to each copy's own
   conventions, the same way the two copies of this project's own blog post already differ in
   exactly those ways without being out of sync.
3. **Confirm before propagating** only when the edit is substantial (new sections, meaning
   changes) — small corrections (a typo, a broken link, a factual fix) can propagate directly
   without asking, the same trust level as fixing a typo in the file you were already asked to
   edit.
4. **If you can't reach the mirror**, say so plainly: name the exact file that still needs the
   same edit, so the human (or the next session) can apply it. Never silently skip a declared
   mirror without saying anything — that's exactly the failure mode this rule exists to prevent.

## Establishing a New Mirror
Use the `obsidian-mirror` skill (`/obsidian-mirror`) to declare a mirror between an existing
file and a new or existing counterpart — it sets the frontmatter on both sides and does the
first sync. Don't hand-write the frontmatter into just one side and assume the other will pick
it up; that's the one-sided-declaration case `obsidian-vault-audit` flags.

## Interaction with `obsidian-vault-audit`
The auditor's Mirror Drift check reads every declared mirror pair it can reach and flags: a
one-sided declaration (only one file names the other), a pair that's drifted (the reachable
repo file and vault note have diverged beyond a trivial formatting difference), or a mirror
pointing at a path that no longer exists. See that skill for the full check.
