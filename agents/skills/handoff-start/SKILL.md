---
name: handoff-start
description: Resume multi-session work from a handoff document. Reads the doc, loads the context listed by the Start-here block, checks the doc's claims against the repository, and briefs the user on where things stand. Use at the beginning of a session on ongoing work, or whenever the user asks to pick up where things left off. Companion skills are handoff-create and handoff-update.
---

# Resuming from a handoff document

Argument forms:

- *(none)*: find the document, brief, wait
- `<slug>`: use `.scratch/handoff-<slug>.md`
- `go`: brief, then begin the `Next` action without waiting
- `<slug> go`: both

## Step 1: Find the document

Glob `.scratch/handoff-*.md`, excluding `*-log.md`.

- **One match**: use it.
- **Several**: list them with each one's `Next:` line and ask which. Do not
  guess from recency; the user may be switching arcs deliberately.
- **None**: say so, and offer `handoff-create`. Then stop.

## Step 2: Load context

Read the document. Then read every path in its **Read first** list, and the
workflow file named by the **Workflow** field. The workflow governs how you work
and what you must not do, so do not begin the `Next` action without it.

When **Review** names a path rather than a SHA, read that document too.

Read the log file only if `Start here` points at it, or if something in the
handoff document is unclear and reading the history would help resolve it. The
intention is that you should *not* have to read it by default.

## Step 3: Check the claims

Run these in parallel with the reads; they take seconds.

- `git status --short`. The tree should normally be clean, since work
  awaiting review is committed rather than left uncommitted. Anything
  uncommitted is unexplained and worth raising.
- `git log --oneline` since the **Verified state** date. Compare against
  **Review**. Commits the document does not describe, or none where it claims
  a review is in progress, both mean the document is behind reality. Also
  catches work done outside a handoff session.
- If **Review**'s referent is a commit SHA, meaning the commit submitted for
  the user's review, resolve the default branch using `git symbolic-ref --short
  refs/remotes/origin/HEAD`, falling back to whatever this repository calls its
  mainline, and check `git merge-base --is-ancestor <sha> <mainline>`. A
  commit already merged there while the document still claims `in-review`
  means the review closed and the document is stale. When the referent is a path
  rather than a SHA, there is no merge-base to check. Confirm the file exists
  instead.
- Confirm every path named in `Start here` still exists. A document naming a
  file, function or flag that has since been deleted is the characteristic
  stale-handoff failure.

Report discrepancies. Do not silently reconcile them. The user decides whether
the document or the tree is wrong.

### Running the verify command

Run it **synchronously, before briefing**. Do not put it in the background. A
check the user has already moved past is worse than no check, because it
surfaces later out of context and becomes a distraction.

The command is the **first command named in `Verified state`**, after the date
that opens the field. The rest of that field is a report of what the last
session verified, not an instruction.

Choose the timeout from the duration recorded beside the command:

- **Duration recorded**: set the timeout to three times as long with a
  two-minute floor.
- **No duration recorded**: two minutes.
- **Duration over ~10 minutes**: do not run it, and do not background it. Brief
  with what it is and what it costs and then let the user opt in.

**A timeout is not a failure:**

- **Timed out**: say the check did not finish and the document's claimed state
  is unverified, not contradicted.
- **Ran and failed**: a *discrepancy*. The document's claimed state is wrong,
  and the user needs that information before the session builds on it.

### When `Review:` is `in-review`

1. **Do not propose new work.** The `Next` field is parked until the review
   closes. It says what resumes afterwards, not what to do now.
2. Say that a review is open, mentioning the checkpoint included in the field.
3. **Ask whether the review has closed.** If the answer is yes, repair the field
   to `none` and carry on with `Next`.

## Step 4: Brief

Keep it under about fifteen lines:

- where the work stands, in a sentence or two
- the next action, and the workflow governing it. Under `in-review`, replace
  that with the fact that a review is open at the checkpoint included in the
  field, and the question of whether it has closed.
- discrepancies found in step 3, including a failed verify
- verification left unconfirmed, if the command timed out or was not run
- open questions marked `blocks Next`, which hold the next action, then any
  other open questions for the user

Do not restate the document. The user is familiar with its contents. They need
the change since last time and the direction for this session, not a summary.

## Step 5: Either wait or begin

Without `go`, stop after the brief. The user will direct you further.

With `go`, begin the `Next` action under the stated workflow. Three things stop
that:

- **`in-review`.** Brief and stop. Say that starting the next step conflicts
  with the open review, which holds the work until it closes.
- **An open question marked `blocks Next`.** Brief and stop. Present the
  options and whatever evidence the document includes, but do not settle it. Ask
  whether the decision has been made since the marker was written, the way step
  3 asks about an open review; if it has, record the answer and carry on.
- **A discrepancy from step 3**, including a failed verify. Raise it and ask for
  further direction from the user.
