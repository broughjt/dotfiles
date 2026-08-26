---
name: handoff-create
description: Create a handoff document for work expected to span multiple sessions. Use when starting a sustained piece of work, when the user asks for a handoff doc, or when a task is clearly too big to finish in one session. Companion skills are handoff-start (resume from a handoff doc) and handoff-update (record a session's work into a handoff doc).
---

# Creating a handoff document

A handoff document lets a fresh agent, with no memory of previous sessions, pick
up sustained work and be productive immediately. It carries motivation, goal,
current state, workflow, and what not to reopen.

## The document set

An **arc** is one sustained goal spanning many sessions. Arc docs are archived
to `.scratch/archive/` when the arc lands.

An arc has two files, both under `.scratch/`:

| File | Holds | Read |
|---|---|---|
| `handoff-<slug>.md` | the arc's current state | every session of that arc |
| `handoff-<slug>-log.md` | the arc's history | only when history matters |

State and history are separate files on purpose. A fresh agent pays nothing for
history it does not need, so the log can stay rich without degrading the
document anyone actually reads.

**There is no backlog document, and you do not create one.** Which arcs
exist is the user's to track, and they mostly track it in their head. When they
mention future work that is not arc-sized, say so and leave it with them. Do not
open a `TODO.md`, a queue, or a "future work" section to hold it.

## Step 1: Triage

Decide which of two outcomes applies. Ask the user how long they expect the
work to take if it is not obvious.

- If the work is **plausibly one session**, do not create an arc doc. Say so and
  offer to do the work instead. A doc per one-off task leads to clutter.
- If the work will take **multiple sessions** toward **one goal**, create an arc
  doc.

Several small independent items are not one arc, and they are not one doc
each. They are just work; offer to do them.

If the user overrides your triage, follow them without re-arguing.

## Step 2: Infer before you ask

Never ask about what you can observe. Read until you can answer, without asking:

- what the project is
- what command verifies it
- which files a fresh agent needs to open to work on the arc
- whether a sibling arc doc already sets a workflow pattern

What is still unanswered is interview material.

Places to check:

- `README.md`, `AGENTS.md` / `CLAUDE.md`, and any other public facing
  documentation
- existing `.scratch/handoff-*.md`, excluding `*-log.md`, plus any background
  doc in `.scratch/` and `.scratch/archive/`
- existing `.scratch/workflow-*.md`; a `verbatim` copy can be shared with this
  arc rather than duplicated
- build and test configuration; the commands that verify the project
- `git log` for the last 10–20 commits, and `git status`

Then **run the cheapest command that verifies the project**, and time it. This
confirms the command is real before the document commits a fresh agent to it,
and it gives `Verified state` a date and a result to open with rather than a
guess. If it fails, that is a fact about where the arc starts; record it and
raise it in the interview. If it is too slow to be worth running at creation,
say so in the field instead of inventing a result.

## Step 3: Ask about what you cannot infer

Interview the user about what you cannot infer. Use the harness's structured question
tool when available, otherwise ask in chat. Lead with your recommendation as the
first option, labeled `(Recommended)`.

Which questions matter depends on the project and on the work. Use the
information from Step 2 to choose the questions, and skip anything Step 2
already answered.

The following are examples--they are not meant to be an agenda.

- **Motivation**: why this work exists, what is inadequate today.
- **Done**: what the finished state looks like, concretely enough to check.
- **Route**: the shape of the path, not a task-level plan. Phases, ordering
  constraints, what has to be settled before what.
- **Workflow**: how the work should proceed, and how it should be verified.
  See below.
- **What not to reopen**: what has already been decided, tried and rejected, or
  ruled out of scope. This is the highest-value section and users rarely
  volunteer it, so ask directly.
- **Open for the user**: decisions the user reserves for themselves, which
  agents must not settle alone.

Interview until you are 95% confident you are on the same page. Do not write the
document while material questions are open.

### Choosing a workflow

Read `reference/workflows/README.md`. Its table includes patterns the user has
worked with before, but it is a starting vocabulary, not a menu and not a closed
set. Make a shortlist by viewing the table, then open the candidates you are
weighing. Use the context you gathered to propose the workflow that actually
suits this arc, including workflows the user has not thought of.

Propose a variation when you can name the property of this arc that the existing
patterns handle badly. For example, an interface that has to be pinned before
anything else, a verification step too slow to run per-commit, or a component
only the user can exercise. If you cannot name one, pick the closest existing
pattern rather than inventing a new one.

A bespoke workflow needs a name and a definition. Coin a short name, and
describe the workflow precisely enough that a fresh agent can follow it without
asking: what the agent does, in what order, what it does not do, and what counts
as the task being finished.

A workflow does not have to fit the whole arc. When the one you propose only
fits the phase in front of you, say so.

## Step 4: Write

Copy `reference/arc-template.md` and fill it in.

Install the workflow at `.scratch/workflow-<name>.md`: copy the chosen pattern
out of `reference/workflows/`, or write the bespoke definition there. Open the
file with the provenance line `reference/workflows/README.md` specifies. `Start
here`'s `Workflow:` field names the pattern and that path. **The copy is what
governs the arc**, so an arc keeps the rules it started under even when the
shared pattern later changes.

Create the companion `-log.md` with this preamble, and a single entry below it
recording the doc's creation and the decisions taken in the interview:

```markdown
# <Arc title>: log

Append-only history for `handoff-<slug>.md`. Newest entries at the top.
```

Rules for the prose:

- Every fact carries enough context to be actionable cold. "Use the warm
  state" is useless; "one warm `PersistentTCState` shared via `withResource`;
  never build a second warm-up path" is better.
- Narrative goes to the log, not here. This document keeps state.
- No section restates what a file it names already says. Point at the file
  and say what to look for.
- Facts are entries, not essays. Detail that only matters while one task is
  in flight belongs in `.scratch/plan-<task>.md`.
- Never write a verification number you did not observe. If you did not run
  it, write what to run instead.
- Write `Start here` last, once everything else is settled.

### Length

`Start here` is read cold and in full at the start of every session, so keep it
**under ~25 lines**.

`Facts established` and `Do not reopen` grow with the project and are read
selectively. They have no limit.

Past roughly 400 lines total, check whether the document is carrying material
that belongs elsewhere--per-task detail, narrative, durable project context--and
relocate what qualifies. **Length is only ever a reason to move text, never to
delete it.** If nothing qualifies for relocation, the document is simply that
long--no need to fret about length further.

Do not report the document's length to the user or justify it.
