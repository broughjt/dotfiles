---
name: handoff-create
description: Create a handoff document for work expected to span multiple sessions. Use when starting a sustained piece of work, when the user asks for a handoff doc, or when a task is clearly too big to finish in one session. Companion skills are handoff-start (resume from a handoff doc) and handoff-update (record a session's work into a handoff doc).
---

# Creating a handoff document

A handoff document lets a fresh agent — with no memory of previous sessions —
pick up sustained work and be productive immediately. It carries motivation,
goal, current state, workflow, and the negative space (what not to reopen).

## The document set

Per arc, under `.scratch/`:

| File | Holds | Read |
|---|---|---|
| `handoff-<slug>.md` | the arc's current state | every session on that arc |
| `handoff-<slug>-log.md` | the arc's history | only when history matters |

State and history are separate files on purpose: a fresh agent pays nothing
for history it does not need, so the log can stay rich without degrading the
document anyone actually reads.

An **arc** is one sustained goal spanning many sessions. Arc docs are archived
to `.scratch/archive/` when the arc lands.

**There is no backlog document, and you do not create one.** Which arcs exist
is the user's to track, and they mostly track it in their head. When they
mention future work that is not arc-sized, say so and leave it with them — do
not open a `TODO.md`, a queue, or a "future work" section to hold it. The list
of arcs that does matter is derived at read time by globbing
`.scratch/handoff-*.md`, which needs no maintenance to stay true.

## Step 1 — Triage

Decide which of two outcomes applies. Ask the user how long they expect the
work to take if it is not obvious.

- **Plausibly one session** → do not create a doc. Say so and offer to do the
  work. A doc per one-off task is how this system becomes clutter.
- **Sustained, multi-session, one goal** → arc doc.

Several small independent items are not one arc, and they are not one doc
each. They are just work; offer to do them.

If the user overrides your triage, follow them without re-arguing.

## Step 2 — Infer before you ask

Never ask about what you can observe. Read, in parallel:

- `README.md`, `AGENTS.md` / `CLAUDE.md`, and whatever the project uses for
  architecture notes
- existing `.scratch/handoff-*.md`, any background doc in `.scratch/`, and
  `.scratch/archive/`
- build and test configuration; the commands that verify the project
- `git log` for the last 10–20 commits, and `git status`

From that, draft: the project's one-paragraph context, the verify command,
the layout an agent needs, and any workflow the existing docs already state.

## Step 3 — Interview the gaps

Use the harness's structured question tool when available, otherwise ask in
chat. Lead with your recommendation as the first option, labeled
`(Recommended)`. Ask only what is genuinely in the user's head:

- **Motivation** — why this work exists, what is inadequate today.
- **Done** — what the finished state looks like, concretely enough to check.
- **Route** — the shape of the path, not a task-level plan. Phases, ordering
  constraints, what has to be settled before what.
- **Workflow** — pick from `reference/workflows.md`, plus per-task overrides.
- **Negative space** — what has already been decided, tried and rejected, or
  ruled out of scope. This is the highest-value section and users rarely
  volunteer it; ask directly.
- **Open questions** — decisions the user reserves for themselves, which
  agents must not settle alone.

Keep interviewing until you would bet you are on the same page. Two or three
rounds is normal. Do not write the document while material questions are open.

## Step 4 — Write

Copy `reference/arc-template.md` and fill it in. Create the companion
`-log.md` with a single entry recording the doc's creation and the decisions
taken in the interview.

Rules for the prose:

- Every fact carries enough context to be actionable cold. "Use the warm
  state" is useless; "one warm `PersistentTCState` shared via `withResource`;
  never build a second warm-up path" is not.
- Narrative goes to the log, not here. This document is state.
- No section restates what a file it names already says. Point at the file
  and say what to look for.
- Facts are entries, not essays. Detail that only matters while one task is
  in flight belongs in `.scratch/plan-<task>.md`.
- Never write a verification number you did not observe. If you did not run
  it, write what to run instead.
- Write `Start here` last, once everything else is settled.

### Length

`Start here` is read cold and in full at the start of every session, so it is
the one place compression pays: keep it **under ~25 lines**. It is the only
budget in this document.

`Facts established` and `Do not reopen` grow with the project and are read
selectively. They have no limit.

Past roughly 400 lines total, check whether the document is carrying material
that belongs elsewhere — per-task detail, narrative, durable project context —
and relocate what qualifies. **Length is only ever a reason to move text,
never to delete it.** If nothing qualifies for relocation, the document is
simply that long, and you are done thinking about it.

Do not report the document's length to the user or justify it.

## Step 5 — Offer the durable split

If your draft is carrying material that will outlive this arc — build and
verify commands, test-harness gotchas, domain background, layering rules,
standing prohibitions — point that out and offer to extract it. That content
should not be buried in one arc's doc, and it should not die when the arc is
archived.

Two questions place it.

**Published, or agent-facing?** Architecture and the rationale behind it,
written for humans, belongs in the project's own documentation — whatever
this project already calls those files. Operational context that exists only
because agents work here belongs in `.scratch/`.

**Every session, or some sessions?** Context an agent doing *any* task here
goes wrong without belongs in the always-loaded file (`AGENTS.md`, plus a
one-line `CLAUDE.md` containing `@AGENTS.md` unless the harness reads
`AGENTS.md` natively). Keep it lean and operational — every session pays for
it. Context needed for *some* tasks, or too large to justify loading every
time, belongs in a named background doc in `.scratch/`, pointed at from the
handoff doc's `Read first`.

A project with real domain context normally wants that background doc.
Create it when the handoff doc starts carrying facts that will still be true
after the arc lands. Name it whatever suits the project — `BACKGROUND.md` is
a reasonable default — and follow the project's existing conventions over
these suggestions wherever they disagree.

Offer this; do not perform it unasked. It is a separate piece of work.
