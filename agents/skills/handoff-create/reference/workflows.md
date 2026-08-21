# Workflow patterns

These are the patterns this user has worked under so far. They are a starting
vocabulary, not a closed set. An arc might adhere to one of the existing
patterns, a variation, or a new, bespoke pattern invented for the
task. `handoff-create`'s "Choosing a workflow" section describes how to choose.

Work proceeds under one workflow at a time. It may change as the arc moves
between phases. The arc doc shows the current one, and the log records the
switch and its reason. Individual tasks may override the arc's default.

An arc always names its workflow in `Start here`, whether the name comes from
this file or was coined for the arc and defined in the arc doc's own `##
Workflow` section.

Do not edit `reference/workflows.md` from a project session. It is shared across
every project. If the pattern looks generally useful, indicate this and ask the
user if they would like to add it globally.

## `agent-implements`

The agent writes the code and commits it, then stops. The agent does not
push; the user collapses the commits.

Session ends with: what was written, what was verified (with real numbers),
and anything the reviewer should look at first--especially places where the
implementation deviated from the plan, and why.

## `design-first-tdd`

The full loop, for work where the output format or interface is the hard part:

1. **Design conversation**: work out the design with the user. Present decisions
   through the harness's structured question tool when available, with the
   recommendation first and labelled `(Recommended)`. Interview until genuinely
   aligned, not until the user stops objecting.
2. **Plan document**: `.scratch/plan-<task>.md`, written so a *different*
   agent can implement from it without the design conversation's context.
3. **Tests first**: rendering/unit tests that pin the output format, and
   scenario/integration tests for the paths the design conversation
   identified. Written and left **red** before implementation exists.
4. **Implement**: a fresh agent reads the handoff doc and the plan doc, then
   makes the tests green. The plan doc is archived once the task lands.

## `user-implements`

The user writes the code. The agent either reviews the user's code afterwards or
writes the tests it has to pass. The agent does not modify the implementation.
Findings should be described to the user.

When writing tests under this pattern, write them against the agreed
interface, not against whatever the user has written so far.

## `spike`

An investigation with a budget. The deliverable is a written verdict, not
working software.

Agree the budget with the user before starting, whether that is a number of
hours, a single session, or something else they name. When it is spent, stop
and report, including when the question is still open. Report the state of the
evidence rather than a guess.

Experiments are committed on a new branch that is not intended to be
merged.

The verdict goes in `.scratch/spike-<slug>.md`. This should consist of the
question, what was tried, what was observed with real numbers, the sha of the
throwaway branch, and a recommendation. The arc doc points at that file from
`Read first` and states the conclusion itself, so the finding outlives the file.

The spike ends when the investigation yields answers. Building on it is a
separate task under a different workflow, so the design decisions get made
deliberately isntead of inherited from throwaway code.
