---
name: handoff-update
description: Record a session's work into a handoff document — write the progress-log entry, edit state in place, refresh the Start-here block for the next agent, and promote durable findings when work closes out. Use at the end of a session on multi-session work, before handing off, or when the user asks to update the handoff doc. Companion skills are handoff-create and handoff-start.
---

# Updating a handoff document

Run this at the end of a working session on an arc. It is what keeps the
document from degrading: state edited in place, history moved out, findings
promoted up.

Find the document as `handoff-start` does — glob `.scratch/handoff-*.md`
excluding `*-log.md`; ask if several match. Read both the state document and
its log before writing anything.

## Step 1 — Write the log entry

Entries in `handoff-<slug>-log.md` run newest first: a new one goes
**directly below the preamble**, above the previous entry. The top of the file
is the title, not an entry slot.

```markdown
## <YYYY-MM-DD> — <headline: what changed, not "worked on X">
```

If the log does not exist, create it with the preamble `handoff-create` step 4
specifies.

Cover what was done, what was **observed** — real commands and real numbers —
where the work deviated from the plan and why, and what is left unstaged for
review. Deviations are the most valuable thing in an entry: they are what a
reviewer needs to look at first and what a future agent will otherwise
rediscover the hard way.

**Entries are immutable.** Add them; never rewrite, collapse or delete
existing ones. Nobody reads this file by default, so its length costs nothing
and is never a reason to touch it — that cheapness is the whole reason state
and history are separate files. Correcting the record means a new entry
saying what turned out to be wrong, not an edit to the entry that got it
wrong.

Never record a verification result you did not run this session. If the suite
was not run, say so. A number carried forward unchecked is worse than no
number, because the next agent will trust it.

## Step 2 — Edit state in place

In the state document — **editing, never appending corrections**:

- **Tasks** — update status. Note the landing date and commit for finished
  ones.
- **Facts established** — promote durable findings out of this session's log
  entry. A finding qualifies if future work would otherwise re-derive it.
  Give each enough context to act on cold.
- **Do not reopen** — add scope decisions settled this session and approaches
  tried and rejected, with the reason and the date.
- **Open questions** — delete answered ones, moving the answer into the
  section it belongs in; add newly reserved decisions.
- Anything the session proved wrong gets **corrected where it stands**.
  Superseded text is deleted, not annotated with a correction beside it.

## Step 3 — Refresh `Start here`

This block is the interface to the next session. You know what the next agent
needs; they know nothing. Rewrite every field, and keep the whole block
**under ~25 lines** — it is read cold and in full every session.

- **Next** — one concrete action, beginnable cold.
- **Read first** — the specific files that action requires, each with a
  clause saying why. This is the field that saves the next session the most
  time and the one most often left stale.
- **Workflow** — including any override for the next task specifically. The
  palette is `../handoff-create/reference/workflows.md`. If the next task
  needs a pattern that is not there, describe it precisely in this field;
  mention to the user that it might be worth adding, but do not edit the
  skill from a project session.
- **Awaiting review** — what is unstaged, or `nothing`.
- **Verified state** — see below.
- **Open for \<user\>** — or `none`.

### Writing `Verified state`

Two jobs in one field: an instruction for the next session, then a report of
this one.

Name commands **cheapest-catch-all first**. `handoff-start` reruns whichever
command appears first, so that slot belongs to the check most likely to
notice the document going stale for the least time spent — not to the most
thorough one.

Record the **observed duration** beside it: `` `stack build` (~90s warm) →
green ``. The next session derives its timeout from that figure, so it is
worth the seconds it costs to notice. Only ever record a duration you
actually observed — an estimate here gets a slow build killed and reported as
unverified. If you did not time it, write nothing rather than guessing, and
if `handoff-start` timed out this session, record that instead of a duration.

End with what was **not** run — `**Not run this session:** stack test, nix
flake check`. That negative is what stops the next agent trusting a green
that only ever covered half the tree.

## Step 4 — Promote and prune (every run)

This is a check on every update, not a separate ritual. A step you have to
remember is one that never happens.

**When a task closes** (landed and reviewed, or abandoned): confirm its
durable findings reached *Facts established* and its rejected approaches
reached *Do not reopen*. Once that is done the log entries behind it can be
left exactly where they are — the state document no longer depends on them.

**When the state document is getting long** (past roughly 400 lines): check
whether it is carrying material that belongs elsewhere. In order of
preference — task-independent operational rules to `AGENTS.md`, architecture
and rationale to the project's published docs, durable agent-facing
background to the `.scratch/` background doc, per-task detail to
`.scratch/plan-<task>.md`, and narrative to the log. Tell the user what you
moved.

**Relocate; never delete to hit a length.** If nothing in the document
qualifies for a better home, it is simply that long. `Facts established` and
`Do not reopen` are expected to grow without limit — they are read
selectively, and pruning them is how a project forgets what it paid to learn.
Do not report the document's length to the user or justify it.

**When an arc completes**: move both files to `.scratch/archive/`. If
anything durable was learned that outlives the arc, promote it out first — an
archived document is history, and nothing should have to be grepped out of
it.

## Step 5 — Report

Tell the user what you changed in the document, what you promoted, and what
you moved or archived. If you found a claim you could not verify, say which
one and leave it marked rather than quietly dropping it.
