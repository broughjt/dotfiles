# `agent-implements`

The agent writes the code and commits it, then stops. The agent does not
push; the user collapses the commits.

Session ends with: what was written, what was verified (with real numbers),
and anything the reviewer should look at first--especially places where the
implementation deviated from the plan, and why.

## Review

One checkpoint, `proposal`: the commits written this session.

If the session ends with commits the user has not reviewed, set `Review:
in-review, proposal <sha>` after committing and writing the log entry that
briefs the reviewer. If the user reviews them in session, the field stays
`none` and the log records the acceptance.
