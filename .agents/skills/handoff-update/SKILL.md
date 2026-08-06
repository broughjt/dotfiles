---
name: handoff-update
description: Record a session's work into a handoff document — write the progress-log entry, edit state in place, refresh the Start-here block for the next agent, and distil the log when work closes out. Use at the end of a session on multi-session work, before handing off, or when the user asks to update the handoff doc. Companion skills are handoff-create and handoff-start.
---

# Updating a handoff document

Run this at the end of a working session on an arc or queue document. It is
what keeps the document from degrading: state edited in place, history moved
out, findings promoted up.

Find the document as `handoff-start` does — glob `.scratch/handoff-*.md`
excluding `*-log.md`; ask if several match. Read both the state document and
its log before writing anything.

## Step 1 — Write the log entry

Prepend to `handoff-<slug>-log.md`, newest first:

```markdown
## <YYYY-MM-DD> — <headline: what changed, not "worked on X">
```

Cover what was done, what was **observed** — real commands and real numbers —
where the work deviated from the plan and why, and what is left unstaged for
review. Deviations are the most valuable thing in an entry: they are what a
reviewer needs to look at first and what a future agent will otherwise
rediscover the hard way.

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
needs; they know nothing. Rewrite every field:

- **Next** — one concrete action, beginnable cold.
- **Read first** — the specific files that action requires, each with a
  clause saying why. This is the field that saves the next session the most
  time and the one most often left stale.
- **Workflow** — including any override for the next task specifically.
- **Awaiting review** — what is unstaged, or `nothing`.
- **Verified state** — today's date, the command, the observed result.
- **Open for \<user\>** — or `none`.

## Step 4 — Distil (every run)

Compaction is a check on every update, not a separate ritual. A compaction
step you have to remember is one that never happens.

**When a task closes** (landed and reviewed, or abandoned): confirm its
durable findings reached *Facts established*, then collapse that task's log
entries into a single summary entry naming the outcome and pointing at the
commits. Detail that survives only as narrative goes; detail future work
depends on has already been promoted.

**When the state document exceeds ~200 lines**: it is carrying material that
belongs elsewhere. In order of preference — promote task-independent
operational rules to `AGENTS.md`, architecture and rationale to `DESIGN.md`,
per-task detail to a `.scratch/plan-<task>.md`, and narrative to the log.
Tell the user what you moved.

**When an arc completes**: move both files to `.scratch/archive/`. If
anything durable was learned that outlives the arc, promote it first — an
archived document is history, and nothing should have to be grepped out of
it. Note the completion in `handoff-queue.md` if the arc came from there.

## Step 5 — Report

Tell the user what you changed in the document, what you promoted, and what
you distilled or archived. If you found a claim you could not verify, say
which one and leave it marked rather than quietly dropping it.
