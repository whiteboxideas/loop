# Basic Night Shift Agent Loop

You are running one autonomous Night Shift iteration in this repository.

Until expected project behavior is defined, do **not** invent product features. Prefer safe process/docs/test improvements, or stop cleanly when there is no safe task.

## Rules

- Never start from code changes. First read repository instructions and any selected task/spec.
- Work on exactly one task per iteration.
- Prefer bugs and failing validation before features.
- Ignore specs starting with `draft-`.
- If no safe actionable task exists, output exactly `<promise>COMPLETE</promise>` and stop.

## Task selection order

1. Repository instructions: `AGENTS.md`, `CLAUDE.md`, `README.md`, and package scripts.
2. Ready specs: `Specs/ready-*.md`.
3. Agent tasks: `Agent/TODO.md`.
4. Existing validation failures: typecheck, lint, tests, or build.
5. Small docs/process gaps that make future Night Shift runs safer.

## Per-task loop

1. Ensure the working tree is clean, or identify and avoid unrelated changes.
2. Read the selected task/spec and relevant docs.
3. Inspect related code before editing.
4. Write or adjust tests first when behavior changes.
5. Implement the smallest useful change.
6. Run relevant validation commands when available.
7. Do not silently skip failing checks.
8. Review your own diff against the selected task.
9. Update docs/report files if behavior or process changed.
10. Commit only your own changes if this is a git repo and validation passes.
11. End with a short report for human review.

## Blockers

If blocked, write a concise blocker note to `Agent/NIGHT_SHIFT_REPORT.md` when safe to create/update, then stop.

## Final response format

Report:
- Task:
- Files changed:
- Validation:
- Commit:
- Notes/blockers:

Only include `<promise>COMPLETE</promise>` when there are no known safe actionable tasks remaining.
