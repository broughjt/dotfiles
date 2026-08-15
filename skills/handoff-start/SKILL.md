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
  guess from recency; the user may be switching arcs deliberately. This
  listing is the only inventory of live arcs there is — no document tracks
  them, by design.
- **None** → say so, and offer `handoff-create`. Then stop.

## Step 2 — Load context

Read the document. Then read every path in its **Read first** list.

Read the log file only if `Start here` points at it, or if something in the
state document is unclear in a way history would resolve. It exists so you do
*not* have to read it by default.

If the document names a workflow pattern you do not recognize, read
`../handoff-create/reference/workflows.md` — the pattern governs how the
session is allowed to proceed, so do not guess at it.

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

Report discrepancies; do not silently reconcile them. The user decides
whether the document or the tree is wrong.

### Running the verify command

Run it **synchronously, before briefing**. Do not put it in the background:
a check the user has already moved past is worse than no check, because it
surfaces later, out of context, attached to work it no longer describes.

The command is the **first one named in `Verified state`** — written to be
the cheapest check that would catch the document being wrong. The rest of
that field is a report of what the last session verified, not an instruction.

Choose the timeout from the duration recorded beside the command:

- **Duration recorded** → timeout of 3× it, with a two-minute floor and the
  harness maximum as the ceiling.
- **No duration recorded** → the default two minutes. If it times out, that
  is this session's `handoff-update` learning the real figure.
- **Duration over ~10 minutes** → do not run it, and do not background it.
  Brief with what it is and what it costs — "verification not run;
  `<cmd>` takes ~15 min, say the word" — and let the user opt in.

**A timeout is not a failure.** They brief differently and conflating them
opens the session with a false alarm:

- **Timed out** → verification *unconfirmed*. Say the check did not finish
  and the document's claimed state is unverified, not contradicted. A cold
  rebuild after a dependency change routinely lands here.
- **Ran and failed** → a *discrepancy*. The document's claimed state is
  wrong, and the user needs that before the session builds on it.

## Step 4 — Brief

Keep it under about fifteen lines:

- where the work stands, in a sentence or two
- the next action, and the workflow governing it
- anything awaiting the user's review
- discrepancies found in step 3, including a failed verify
- verification left unconfirmed, if the command timed out or was not run
- open questions the document reserves for the user

Do not restate the document. The user wrote most of it; they need the delta
and the direction, not a summary.

## Step 5 — Wait, or begin

Without `go`, stop after the brief. The user reads it and directs — often
redirecting away from the stated `Next`, which is the point of waiting.

With `go`, begin the `Next` action under the stated workflow. Still surface
any discrepancy from step 3 before acting on it; `go` authorizes the work the
document describes, not work its own premises contradict. A verify failure is
such a discrepancy: raise it and get direction rather than building on a
state the document has already got wrong.
