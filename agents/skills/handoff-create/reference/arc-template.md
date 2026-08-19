# <Arc title>

**Shape:** arc · **Started:** <YYYY-MM-DD> · **Log:** `handoff-<slug>-log.md`

## Start here

**Next:** <the single next action, concrete enough to begin>

**Read first:**
- `<path>` — <why this one, in a clause>
- `<path>` — <why>

**Workflow:** <pattern name from workflows.md><, plus any override for this task>

**Awaiting review:** <which commits are awaiting review and who owns them, or
`nothing`>

**Verified state:** <YYYY-MM-DD> — `<cheapest command that would catch this
doc being wrong>` (<observed duration>) → <observed result>; `<other command
run>` → <result>. **Not run this session:** <commands skipped>.

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
  `handoff-<slug>-log.md`, which is append-only. Findings that future work
  depends on get promoted up into *Facts established*.
- **Refresh `Start here` at the end of every session** — especially `Next`
  and `Read first`, which are written for an agent that knows nothing. Keep
  the block under ~25 lines; it is the only part of this document that is
  read cold and in full every time.
- **Never record a verification number you did not observe** — including the
  duration in *Verified state*.
- Past ~400 lines, move material to a better home — `AGENTS.md`, the
  project's published docs, the `.scratch/` background doc, a plan doc, the
  log. Never delete to hit a length; *Facts established* and *Do not reopen*
  have no limit.

<!-- --- guidance below; delete this comment block and everything after it ---

Fill every section or delete it — an empty heading reads as an oversight.
`Start here` is written last, once the rest is settled.

`Read first` is the highest-value line in the document. It is written by the
agent finishing a session, who knows what the next agent will need; it is
executed by an agent that knows nothing. Name specific files and say why in a
clause, not "the relevant source".

`Verified state` faces both ways. The first command named is what the next
session reruns before briefing, so put the cheapest useful check there and
record how long it took — that duration is what stops a slow rebuild being
killed and misreported as a failure. Everything after it is a report of what
this session actually verified, including what it did not.

-->
