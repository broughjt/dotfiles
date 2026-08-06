---
name: handoff-create
description: Create a handoff document for work expected to span multiple sessions, or add an item to a project's standing queue. Use when starting a sustained piece of work, when the user asks for a handoff doc, or when a task is clearly too big to finish in one session. Companion skills are handoff-start (resume from a doc) and handoff-update (record a session's work into one).
---

# Creating a handoff document

A handoff document lets a fresh agent — with no memory of previous sessions —
pick up sustained work and be productive immediately. It carries motivation,
goal, current state, workflow, and the negative space (what not to reopen).

## The document set

Per project, under `.scratch/`:

| File | Holds | Read |
|---|---|---|
| `handoff-<slug>.md` | an arc's current state | every session on that arc |
| `handoff-<slug>-log.md` | that arc's history | only when history matters |
| `handoff-queue.md` | the standing backlog of small items | when picking work |
| `handoff-queue-log.md` | finished queue items | rarely |

State and history are separate files on purpose: a fresh agent pays nothing
for history it does not need, so the log can stay rich without degrading the
document anyone actually reads.

An **arc** is one sustained goal spanning many sessions. The **queue** is a
long-lived, per-project list of small independent items; it is never archived.
Arc docs are archived to `.scratch/archive/` when the arc lands. A queue item
that grows can graduate into its own arc doc.

## Step 1 — Triage

Decide which of three outcomes applies. Ask the user how long they expect the
work to take if it is not obvious.

- **Plausibly one session** → do not create an arc doc. Say so, and offer to
  add it to `handoff-queue.md` instead (creating that file if absent). A doc
  per one-off task is how this system becomes clutter.
- **Sustained, multi-session, one goal** → arc doc.
- **Several small independent items** → queue items, not one arc doc each.

If the user overrides your triage, follow them without re-arguing.

## Step 2 — Infer before you ask

Never ask about what you can observe. Read, in parallel:

- `README.md`, `AGENTS.md` / `CLAUDE.md`, `DESIGN.md` if present
- existing `.scratch/handoff-*.md` and `.scratch/archive/`
- build and test configuration; the commands that verify the project
- `git log` for the last 10–20 commits, and `git status`

From that, draft: the project's one-paragraph context, the verify command,
the layout an agent needs, and any workflow the existing docs already state.

## Step 3 — Interview the gaps

Use the harness's structured question tool when available, otherwise ask in
chat. Lead with your recommendation as the first option, labelled
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

Copy `reference/arc-template.md` or `reference/queue-template.md` and fill it
in. Create the companion `-log.md` with a single entry recording the doc's
creation and the decisions taken in the interview.

Rules for the prose:

- Every fact carries enough context to be actionable cold. "Use the warm
  state" is useless; "one warm `PersistentTCState` shared via `withResource`;
  never build a second warm-up path" is not.
- State-doc target is **under 200 lines**. If it is longer, material belongs
  in a reference doc or the log.
- Never write a verification number you did not observe. If you did not run
  it, write what to run instead.
- Write `Start here` last, once everything else is settled.

## Step 5 — Offer the durable split

If the project has no `AGENTS.md`/`CLAUDE.md` and your draft is carrying
durable, task-independent material — build and verify commands, test-harness
gotchas, code style, layering rules, standing prohibitions — point that out
and offer to extract it. That content outlives every arc and should be loaded
every session, not buried in one arc's doc.

Split by who pays to read it:

- **`AGENTS.md`** — an agent doing *any* task here goes wrong without it.
  Keep it lean and operational; 40–70 lines. Add a one-line `CLAUDE.md`
  containing `@AGENTS.md` unless the harness reads `AGENTS.md` natively.
- **Public docs** (`README.md`, `DESIGN.md`) — architecture and the rationale
  behind it. Design decisions written for humans belong here, not in a
  private scratch doc.
- **`.scratch/PROJECT.md`** — only for durable *agent-facing* context that is
  too large for `AGENTS.md` and does not belong in a public doc. Most
  projects do not need one. Do not create it by default.

Offer this; do not perform it unasked. It is a separate piece of work.
