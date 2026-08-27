# `design-first-tdd`

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
   makes the tests green. While the task is in flight the arc doc names the plan
   in `Read first`. The plan doc moves to `.scratch/archive/` when the task
   lands.

## Review

Three checkpoints, one per stage:

| After | Field |
|---|---|
| the plan document | `in-review, plan .scratch/plan-<task>.md` |
| the tests, committed red | `in-review, tests <sha>` |
| the implementation | `in-review, implementation <sha>` |

Each stage waits on the user before the next begins. This is the whole point of
the pattern: the design is settled before tests pin it, and the tests are
settled before implementation. `Next` names the stage that resumes once the open
review closes.
