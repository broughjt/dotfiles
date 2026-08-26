# <Arc title>

## Start here

**Next:** <the single next action, concrete enough to begin>

**Read first:**
- `<path>`: <why this one, in a clause>
- `<path>`: <why>

**Workflow:** <pattern name> — `.scratch/workflow-<name>.md`

**Review:** <`none`, or `in-review, proposal <sha>`. The proposal is the commit
submitted for the user to review. `in-review` parks `Next`, which then says what
resumes once the review closes, not what to do now. State and SHA only; review
findings do not belong here. A new arc starts `none`.>

**Verified state:** <YYYY-MM-DD>: `<cheapest command that would catch this doc
being wrong>` (<observed duration>) → <observed result>; `<other command run>`
→ <result>. **Not run:** <commands skipped>.

## Why this work exists

<One or two paragraphs. What is inadequate today, and what changes when this
lands. Written so someone who has never seen the project understands the
stakes. This section changes rarely. Edit it only when the motivation actually
shifts.>

## Where this is going

<What "done" looks like, concretely enough to check. Then the shape of the
route: phases, ordering constraints, what must be settled before what. This is
not a task-level plan; those live in `.scratch/plan-<task>.md`.>

## Tasks

- [ ] <task> (<override: <pattern name> `.scratch/workflow-<name>.md`, when it
      differs from the doc default>)
- [ ] <task>
- [x] <finished task> (landed <YYYY-MM-DD>, commit if there is one)

## Do not reopen

<Settled scope decisions and rejected approaches, one line each as
`- **<thing>**: <why it is closed> (<YYYY-MM-DD>)`. Fresh agents reliably try
to "helpfully" restore deleted work and re-propose rejected designs. This
section is what stops them.>

_None._

## Facts established

<Durable findings promoted out of the log. Things observed or pinned that a
fresh agent would otherwise re-derive. Group under subheadings once there are
more than a handful. Each fact carries enough context to be acted on cold.>

_None._

## Open questions

<Decisions reserved for the user. An agent must not settle these alone. It may
gather evidence and present options. Delete each one as it is answered, moving
the answer into the relevant section above.

Mark an entry `— blocks Next.` when the next action cannot proceed without
it. `handoff-start` stops on that marker rather than settling the decision, so
it is written by the agent that knows and read by one that does not.>

_None._

## Keeping this doc current

- **Edit in place; do not append corrections.** When a fact changes, change
  the fact. Superseded text is deleted, not annotated.
- **State lives here; history lives in the log.** Session narrative goes to
  `handoff-<slug>-log.md`, which is append-only. Findings that future work
  depends on get promoted up into *Facts established*.
- **Sections are never deleted.** *Tasks*, *Do not reopen*, *Facts established*
  and *Open questions* accumulate over the arc, so an empty one means "not yet",
  not "not applicable". Mark it `_None._` rather than removing the heading.
- **Refresh `Start here` at the end of every session**, especially `Next` and
  `Read first`. Keep the block under ~25 lines.
- **`Read first` is the highest-value line in the document.** It is written by
  the agent finishing a session, who knows what the next agent will need, and
  executed by an agent that knows nothing. Name specific files and say why in
  a clause, not "the relevant source".
- Past ~400 lines, consider moving material to a better home: `AGENTS.md`, the
  project's published docs, a `.scratch/` background doc, a plan doc, etc. Never
  delete to hit a length. *Facts established* and *Do not reopen* have no limit.
