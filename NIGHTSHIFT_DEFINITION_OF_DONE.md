# Night Shift Definition of Done

These rules are project-agnostic and apply to every Night Shift run. Project-specific `.nightshift/DEFINITION_OF_DONE.md` rules can add stricter validation, but they should not weaken these rules.

## Universal completion rules

A non-blocked task is done only when:

- exactly one selected ready task was handled,
- the selected current task in `.nightshift/CURRENT.md` is marked `[x]` or otherwise moved into a clearly non-blocking state,
- relevant validation was run and passed, or a clear blocker was documented,
- documentation impact was reviewed and either updated or explicitly deemed unnecessary,
- all files touched by the iteration are reported,
- the work is committed when this is a git repository and validation passed.

## Commit rule

When the target project is a git repository and validation passed:

1. Review `git status --short --untracked-files=all`.
2. Stage and commit all changes made by this Night Shift iteration, including code, tests, docs, `.nightshift/CURRENT.md`, and `.nightshift/BACKLOG.md` updates.
3. Do not stage pre-existing unrelated user changes. If unrelated changes make a safe commit impossible, document the blocker instead of committing.
4. Use a concise commit message that describes the selected task.
5. Report the commit hash in the final response.

The loop CLI finalizes and commits its generated per-run logs after the agent exits, using a separate log-only commit. Do not create a premature commit for incomplete loop-generated logs.

If the target project is not a git repository, or validation did not pass, do not invent a task-change commit. Report why no task-change commit was made.

## Final response requirements

Include the standard `NIGHTSHIFT_...` summary lines requested by the runtime prompt. Also include a `Commit:` entry in the human-readable report with either the commit hash or the reason no commit was made.
