# <Arc title>

## Start here

**Next:** <the single next action, concrete enough to begin>

**Read first:**
- `<path>`: <why this one, in a clause>
- `<path>`: <why>

**Workflow:** <pattern name, from workflows.md or coined for this arc and
defined under `## Workflow` below>

**Review:** <`none`, or: in-review, proposal \<sha\>>

**Verified state:** <YYYY-MM-DD>: `<cheapest command that would catch this doc
being wrong>` (<observed duration>) → <observed result>; `<other command run>`
→ <result>. **Not run this session:** <commands skipped>.

**Open for <user>:** <decisions reserved for the user, or `none`>

## Why this work exists

<One or two paragraphs. What is inadequate today, and what changes when this
lands. Written so someone who has never seen the project understands the
stakes. This section changes rarely. Edit it only when the motivation actually
shifts.>

## Where this is going

<What "done" looks like, concretely enough to check. Then the shape of the
route: phases, ordering constraints, what must be settled before what. This is
not a task-level plan; those live in `.scratch/plan-<task>.md`.>

## Workflow

<Only when the workflow is not a named pattern from workflows.md. Delete this
section otherwise.

Define the coined name used in `Start here` by indicating what the agent does,
in what order, what it does not do, and what counts as the task being
finished. Write such that a fresh agent can follow the workflow without asking.>

## Tasks

- [ ] <task> (<workflow override, if it differs from the doc default>)
- [ ] <task>
- [x] <finished task> (landed <YYYY-MM-DD>, commit if there is one)

## Do not reopen

<Settled scope decisions and rejected approaches. One line each, with the
reason and the date. Fresh agents reliably try to "helpfully" restore deleted
work and re-propose rejected designs. This section is what stops them.>

- **<thing>**: <why it is closed> (<YYYY-MM-DD>)

## Facts established

<Durable findings promoted out of the log. Things observed or pinned that a
fresh agent would otherwise re-derive. Group under subheadings once there are
more than a handful. Each fact carries enough context to be acted on cold.>

## Open questions

<Decisions reserved for the user. An agent must not settle these alone. It may
gather evidence and present options. Delete each one as it is answered, moving
the answer into the relevant section above.>

## Keeping this doc current

- **Edit in place; do not append corrections.** When a fact changes, change
  the fact. Superseded text is deleted, not annotated.
- **State lives here; history lives in the log.** Session narrative goes to
  `handoff-<slug>-log.md`, which is append-only. Findings that future work
  depends on get promoted up into *Facts established*.
- **Refresh `Start here` at the end of every session**, especially `Next` and
  `Read first`. Keep the block under ~25 lines.
- **`Read first` is the highest-value line in the document.** It is written by
  the agent finishing a session, who knows what the next agent will need, and
  executed by an agent that knows nothing. Name specific files and say why in
  a clause, not "the relevant source".
- Past ~400 lines, consider moving material to a better home: `AGENTS.md`, the
  project's published docs, a `.scratch/` background doc, a plan doc, etc. Never
  delete to hit a length. *Facts established* and *Do not reopen* have no limit.
