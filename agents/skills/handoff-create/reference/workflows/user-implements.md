# `user-implements`

The user writes the code. The agent either reviews the user's code afterwards or
writes the tests it has to pass. The agent does not modify the implementation.
Findings should be described to the user.

If the user asks the agent to edit user-authored content, put those edits in
their own commit so their diff stands alone. Keep optional style findings in
chat unless the user asks to apply them.

When writing tests under this pattern, write them against the agreed
interface, not against whatever the user has written so far.

## Review

One checkpoint, `findings`: the agent's review of the user's code, which the
user then signs off.

Write the findings to `.scratch/review-<slug>.md`, naming at the top the commit
they were made against, and describe them to the user as well. If the session
ends before the user signs them off, set `Review: in-review, findings
.scratch/review-<slug>.md`. If the user signs them off in session, the field
stays `none` and the log records the acceptance.

**Writing the findings does not close the review; the user's sign-off does.**
Until then `Next` says what resumes afterwards.

Writing tests under this pattern opens no review. They are the interface the
user implements against, not a proposal awaiting their verdict.
