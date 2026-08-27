# Workflow patterns

These are patterns this user has worked with so far. They are a starting
vocabulary, not a menu, and not a closed set. An arc might adhere to one of
these patterns, a variation, or a new, bespoke pattern invented for the task.
`handoff-create`'s "Choosing a workflow" section describes how to choose.

| Pattern | The agent | Deliverable |
|---|---|---|
| [`agent-implements`](agent-implements.md) | writes the code and commits it, then stops | committed work awaiting the user's review |
| [`design-first-tdd`](design-first-tdd.md) | designs with the user, writes a plan doc, leaves tests red, then makes them green | an interface pinned by tests before it is implemented |
| [`spike`](spike.md) | investigates under a budget agreed in advance | a written verdict, not working software |
| [`user-implements`](user-implements.md) | reviews the user's code, or writes the tests it has to pass | findings, or a red suite; never the implementation |

Shortlist from the table, then open only the candidates you are weighing.

## How a workflow attaches to an arc

Work proceeds under one workflow at a time. It may change as the arc moves
between phases. Individual tasks may override the arc's default.

**Every pattern the arc doc names has a copy in `.scratch/`**, overrides
included. An override is installed exactly like a default, and the task should
include the workflow pattern name and a path to the file which describes it,
just like the `Start here` `Workflow:` field.

Each pattern also defines its own review checkpoints in its `## Review` section,
including what gets reviewed, when `Review` moves to `in-review`, and what the
field points at.

An arc runs against a **copy** of the pattern, at `.scratch/workflow-<name>.md`,
and `Start here`'s `Workflow:` field names both the pattern and that path. The
copy is what governs the arc; this directory is only where copies come from. An
arc therefore keeps the rules it started under until someone deliberately
changes them, and the log records the switch and its reason.

### Provenance

Every `.scratch/workflow-<name>.md` opens with one of these lines:

```markdown
<!-- copied from reference/workflows/<name>.md on <YYYY-MM-DD>; verbatim -->
<!-- forked from reference/workflows/<name>.md on <YYYY-MM-DD> -->
<!-- coined for this arc on <YYYY-MM-DD> -->
```

`verbatim` is a claim that can be checked against this directory, and the rule
below depends on it holding.

### Amending a copy

A copy marked `verbatim` keeps the shared pattern's name and may be shared by
every arc in the repository. **The moment one arc needs to amend it, the file is
forked** to `.scratch/workflow-<bespoke-name>.md` with `forked from` provenance,
so that no other arc's rules change underneath it. Point the amending arc's
`Workflow:` field at the new name and path, and log the switch.

This is also how an arc that started on a shared pattern becomes bespoke three
sessions in, once the mismatch is visible. The choice does not have to be made
up front.

## Editing this directory

Do not edit anything under `reference/workflows/` from a project session. It is
shared across every project, and arcs run against their copies, so an edit here
will not read in-flight handoffs. If a pattern looks generally useful, indicate
this and ask the user if they would like to add it globally.
