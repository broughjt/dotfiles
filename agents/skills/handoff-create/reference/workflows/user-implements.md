# `user-implements`

The user writes the code. The agent either reviews the user's code afterwards or
writes the tests it has to pass. The agent does not modify the implementation.
Findings should be described to the user.

When writing tests under this pattern, write them against the agreed
interface, not against whatever the user has written so far.
