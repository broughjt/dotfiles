# <Arc title>

**Shape:** arc · **Started:** <YYYY-MM-DD> · **Log:** `handoff-<slug>-log.md`

## Start here

**Next:** <the single next action, concrete enough to begin>

**Read first:**
- `<path>` — <why this one, in a clause>
- `<path>` — <why>

**Workflow:** <pattern name from workflows.md><, plus any override for this task>

**Awaiting review:** <what is left unstaged and who owns it, or `nothing`>

**Verified state:** <YYYY-MM-DD> — `<verify command>` → <observed result>

**Open for <user>:** <decisions reserved for the user, or `none`>

## Why this work exists

<One or two paragraphs. What is inadequate today, and what changes when this
lands. Written so someone who has never seen the project understands the
stakes. This section changes rarely — edit it only when the motivation
actually shifts.>

## Where this is going

<What "done" looks like, concretely enough to check. Then the shape of the
route: phases, ordering constraints, what must be settled before what. This
is not a task-level plan — those live in `.scratch/plan-<task>.md`.>

## Tasks

- [ ] <task> — <workflow override, if it differs from the doc default>
- [ ] <task>
- [x] <finished task> — <landed YYYY-MM-DD, commit if there is one>

## Do not reopen

<Settled scope decisions and rejected approaches. One line each, with the
reason and the date. Fresh agents reliably try to "helpfully" restore deleted
work and re-propose rejected designs; this section is what stops them.>

- **<thing>** — <why it is closed> (<YYYY-MM-DD>)

## Facts established

<Durable findings promoted out of the log: things observed or pinned that
nothing needs to re-derive. Group under subheadings once there are more than
a handful. Each fact carries enough context to be acted on cold.>

## Open questions

<Decisions the user has reserved. An agent must not settle these alone; it
may gather evidence and present options. Delete each one as it is answered,
moving the answer into the relevant section above.>

## Keeping this doc current

- **Edit in place; do not append corrections.** When a fact changes, change
  the fact. Superseded text is deleted, not annotated.
- **State lives here; history lives in the log.** Session narrative goes to
  `handoff-<slug>-log.md`. Findings that future work depends on get promoted
  up into *Facts established*.
- **Refresh `Start here` at the end of every session** — especially `Next`
  and `Read first`, which are written for an agent that knows nothing.
- **Never record a verification number you did not observe.**
- Keep this document under ~200 lines. If it grows past that, distil.

<!-- --- guidance below; delete this comment block and everything after it ---

Fill every section or delete it — an empty heading reads as an oversight.
`Start here` is written last, once the rest is settled.

`Read first` is the highest-value line in the document. It is written by the
agent finishing a session, who knows what the next agent will need; it is
executed by an agent that knows nothing. Name specific files and say why in a
clause, not "the relevant source".

-->
