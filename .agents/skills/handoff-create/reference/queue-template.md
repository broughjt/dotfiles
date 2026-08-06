# <Project> — standing queue

**Shape:** queue · **Log:** `handoff-queue-log.md`

## Start here

**Next:** <the item to pick up, or `pick an item below`>

**Read first:**
- `<path>` — <why>

**Workflow:** <default pattern from workflows.md; items may override>

**Awaiting review:** <what is left unstaged, or `nothing`>

**Verified state:** <YYYY-MM-DD> — `<verify command>` → <observed result>

**Open for <user>:** <or `none`>

## How this queue works

Items are independent and can be done in any order unless an item says
otherwise. Each carries enough context to be picked up cold. Finished items
move to `handoff-queue-log.md` with what was done. An item that turns out to
be sustained work graduates into its own `handoff-<slug>.md` arc doc, and its
entry here is replaced by a pointer.

This document is long-lived and is never archived.

## Items

### <Item name> — <ready | in progress | blocked | needs design>

**Why:** <what is inadequate today>
**Done when:** <checkable condition>
**Workflow:** <pattern, if it differs from the default>
**Read first:** `<path>` — <why>
**Notes:** <constraints, gotchas, prior attempts>

### <Item name> — <status>

...

## Do not reopen

<Settled scope decisions and rejected approaches that apply across items.
One line each, with the reason and the date.>

## Facts established

<Shared context that outlived individual items — findings any future item
here would otherwise re-derive.>

## Keeping this doc current

- **Edit in place; do not append corrections.**
- Finished items move to the log with what was done; they do not accumulate
  here as struck-through text.
- **Refresh `Start here` at the end of every session.**
- **Never record a verification number you did not observe.**
- Keep this document under ~200 lines. Items are entries, not essays; detail
  that only matters during the work belongs in a plan doc.

<!-- --- guidance below; delete this comment block and everything after it ---

Item status meanings:
  ready        — can be started cold
  in progress  — partially done; Notes says where it stopped
  blocked      — waiting on something named in Notes
  needs design — a design conversation must happen before implementation

-->
