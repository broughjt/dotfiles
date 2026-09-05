---
name: handoff-update
description: Record a session's work into a handoff document: write the progress-log entry, edit state in place, refresh the Start-here block for the next agent, and promote durable findings when work closes out. Use at the end of a session on multi-session work or when the user asks to update the handoff doc. Companion skills are handoff-create and handoff-start.
---

# Updating a handoff document

Run this at the end of a working session on an arc. It keeps the document from
degrading. State should be edited in place, history moved out, and findings
promoted up.

Find the document as `handoff-start` does: glob `.scratch/handoff-*.md`,
excluding `*-log.md`, and ask if several match. Read both the handoff document and
its log before writing anything.

## Step 1: Write the log entry

Entries in `handoff-<slug>-log.md` run newest first. A new one goes **directly
below the preamble**, above the previous entry.

```markdown
## <YYYY-MM-DD>: <headline: what changed, not "worked on X">
```

If the log does not exist, create it with the preamble `handoff-create` step 4
specifies.

Cover what was done, what was **observed** with real commands and real numbers,
where the work deviated from the plan and why, which commits are awaiting
review, and any change of workflow along with the reason for it.

**Deviations from the plan, each with its argument, are the entry's most
valuable content.** This is the reviewer's brief, and it is the only part of
what they read that you author. They already have the plan, the diff and this
document, so anything here that duplicates those is dead weight.

**Do not diagnose your own code.** Remark on deviations and on aspects you are
uncertain about or think deserve attention. A deviation's argument is required
and is not a diagnosis; a verdict on your own code's quality is out of bounds.
Of course, if asked directly by the user, answer.

**Entries are immutable.** Add them; never rewrite, collapse or delete previous
ones.

Never record a verification result you did not run this session. If the suite
was not run, say so.

## Step 2: Edit state in place

In the handoff document, **editing, never appending corrections**:

- **Tasks**: update status. Note the date and commit for finished tasks.
- **Facts established**: promote durable findings out of this session's log
  entry. A finding qualifies if future work would otherwise re-derive it. Give
  each enough context to act on cold.
- **Do not reopen**: add scope decisions settled this session and approaches
  tried and rejected, with the reason and the date.
- **Open questions**: delete answered ones, moving the answer into the section
  it belongs in. Add newly reserved decisions. Mark an entry `— blocks Next.`
  when the action you just wrote into `Next` cannot proceed without it, and
  clear the marker when it no longer applies. You are the only agent in a
  position to judge that; the next one will take the marker at face value.
- Anything the session proved wrong gets **corrected where it stands**.
  Superseded text is deleted, not annotated with a correction beside it.

## Step 3: Refresh `Start here`

This block is the interface to the next session. You know what the next agent
needs; they know nothing. Rewrite every field, and keep the whole block **under
~25 lines**.

- **Next**: one concrete action, beginnable cold.
- **Read first**: the specific files that action requires, each with a clause
  saying why. This is the field that saves the next session the most time and
  the one most often left stale.
- **Workflow**: the pattern governing `Next` and the path to its copy. That is
  the task's override when it has one, otherwise the arc default. The arc runs
  against `.scratch/workflow-<name>.md`, never against the shared pattern it was
  copied from, so a pattern named here without a copy installed is a defect. If
  the workflow changed this session, or the next task carries an override with
  no copy yet, install it from `../handoff-create/reference/workflows/`, point
  this field at it, and record the switch and its reason in the log. Amending a
  copy means forking it under a new name; see
  `../handoff-create/reference/workflows/README.md`.
- **Review**: see below.
- **Verified state**: see below.

### Writing `Review`

This field says whether a review is open. Two states:

- `none`: no open review. `Next` proposes work.
- `in-review, <checkpoint> <referent>`: a review is open. The referent is a
  commit SHA, or a path when the thing under review is not a commit. `Next` says
  what resumes once it closes, not what to do now. The arc's
  `.scratch/workflow-<name>.md` file will say which checkpoints to include. Do
  not invent a checkpoint the workflow does not define, and do not carry one
  over from a workflow the arc has switched away from.

**State, checkpoint and referent, nothing else.** Do not include what the review
has found or how much of it is left.

Move the field to `none` if the user indicates to you that review is finished. A
review that opens and closes inside one session never needs the field, so `none`
does not mean the work went unreviewed.

### Writing `Verified state`

Two jobs in one field: an instruction for the next session, then a report from
the last session that actually ran it, which is not always this one.

Name commands **cheapest-catch-all first**. `handoff-start` reruns whichever
command appears first, so that slot belongs to the check most likely to notice
the document going stale for the least time spent, not to the most thorough one.

Open the field with the **date the observations were made**. `handoff-start`
runs `git log` since that date to find commits the document does not describe,
so a date that does not match the observations beside it silently disables that
check.

For a repository whose user rewrites history, record the current branch tip as
the reconciliation point and describe the content state that matters. Do not
make the handoff depend on a list of per-commit SHAs expected to disappear.
`Review` still names the current commit when a commit is under review.

Record the **observed duration** beside each command. The next session derives
its timeout from that figure. Only record a duration you actually observed. If
you did not time it, write nothing rather than guessing, and if `handoff-start`
timed out this session, record that instead of a duration.

End with what was **not** run. That negative is what stops the next agent
trusting a green that only ever covered half the tree.

```markdown
**Verified state:** 2026-08-26: `stack build` (~90s warm) → green; `stack test`
(4m) → 3 failures in Spec.Metric. **Not run:** nix flake check.
```

## Step 4: Promote and prune

**When a task closes** (landed and reviewed, or abandoned): confirm its durable
findings reached *Facts established* and its rejected approaches reached *Do not
reopen*. The log entries behind it can then be left exactly where they are.

Move any `.scratch/` artifact the task owned, its plan doc for instance, to
`.scratch/archive/`, **and drop it from `Read first`**.

**When the handoff document is getting long**: follow the handoff document's
*Keeping this doc current* section, and tell the user what you moved.

**When an arc completes**: move both files to `.scratch/archive/`, together with
every workflow copy that is bespoke to this arc, overrides included, and any
`.scratch/review-<slug>.md` or `.scratch/spike-<slug>.md` the arc produced. A
`verbatim` workflow copy stays put, since another arc may be running against it.
Promote anything durable that outlives the arc first. An archived document is
history, and nothing should have to be grepped out of it.

## Step 5: Report

Tell the user what you changed in the document, what you promoted, and what you
moved or archived. If you found a claim you could not verify, say which one and
leave it marked rather than quietly dropping it.
