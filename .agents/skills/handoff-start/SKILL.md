---
name: handoff-start
description: Resume multi-session work from a handoff document. Reads the doc, loads the context its Start-here block names, checks the doc's claims against the repository, and briefs the user on where things stand. Use at the beginning of a session on ongoing work, or whenever the user asks to pick up where things left off. Companion skills are handoff-create and handoff-update.
---

# Resuming from a handoff document

Argument forms:

- *(none)* — find the document, brief, wait
- `<slug>` — use `.scratch/handoff-<slug>.md`
- `go` — brief, then begin the `Next` action without waiting
- `<slug> go` — both

## Step 1 — Find the document

Glob `.scratch/handoff-*.md`, excluding `*-log.md`.

- **One match** → use it.
- **Several** → list them with each one's `Next:` line and ask which. Do not
  guess from recency; the user may be switching arcs deliberately.
- **None** → say so, and offer `handoff-create`. Then stop.

## Step 2 — Load context

Read the document. Then read every path in its **Read first** list.

Read the log file only if `Start here` points at it, or if something in the
state document is unclear in a way history would resolve. It exists so you do
*not* have to read it by default.

## Step 3 — Check the claims

Run these in parallel with the reads; they take seconds.

- `git status --short` — compare against **Awaiting review**. Uncommitted
  work the document does not describe, or a clean tree where it claims work
  is pending, both mean the document is behind reality.
- `git log --oneline` since the **Verified state** date — catches work done
  outside a handoff session, and review commits the document does not know
  about.
- Confirm every path named in `Start here` still exists. A document naming a
  file, function or flag that has since been deleted is the characteristic
  stale-handoff failure.

If the document records a verify command, start it **in the background** now
so the brief is not blocked on a build. Report the result when it lands.

Report discrepancies; do not silently reconcile them. The user decides
whether the document or the tree is wrong.

## Step 4 — Brief

Keep it under about fifteen lines:

- where the work stands, in a sentence or two
- the next action, and the workflow governing it
- anything awaiting the user's review
- discrepancies found in step 3
- open questions the document reserves for the user
- that the verify command is running, if it is

Do not restate the document. The user wrote most of it; they need the delta
and the direction, not a summary.

## Step 5 — Wait, or begin

Without `go`, stop after the brief. The user reads it and directs — often
redirecting away from the stated `Next`, which is the point of waiting.

With `go`, begin the `Next` action under the stated workflow. Still surface
any discrepancy from step 3 before acting on it; `go` authorises the work the
document describes, not work its own premises contradict.

If the verify command was started, check it before finishing, and treat a
failure as a discrepancy — the document's claimed state is wrong and the user
needs to know before the session builds on it.
