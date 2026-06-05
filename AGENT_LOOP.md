# Basic Night Shift Agent Loop

You are running one autonomous Night Shift iteration in the selected project repository.

Night Shift loop code lives outside the project in `loop/`. Project-specific task/config files live inside the project at `.nightshift/`.

Until expected project behavior is defined, do **not** invent product features. Prefer safe process/docs/test improvements, or stop cleanly when there is no safe task.

## Rules

- Never start from code changes. First read repository instructions, `.nightshift/DEFINITION_OF_DONE.md`, and the selected `.nightshift` task/spec.
- Work on exactly one task per iteration.
- Prefer the first unchecked ready task in `.nightshift/TODO.md` unless a higher-priority bug/validation failure is clearly called out.
- Prefer bugs and failing validation before features.
- Ignore specs or tasks starting with `draft-`.
- Do not edit the Night Shift loop implementation unless the selected task explicitly asks for Night Shift tooling changes.
- Use TDD for implementation tasks: write or update a failing test/fixture first when practical, then implement, then refactor.
- Always run `npm run check` when available before marking a task done. If `npm run check` is missing, run the individual relevant checks: lint, typecheck, tests, and fallow/audit when available.
- Fix issues found by validation when safe and in scope; rerun the failing check after each fix.
- Perform a documentation check before marking a task done: update user-facing docs, project docs, or `.nightshift` notes when behavior, commands, routes, or workflow changed; otherwise explicitly report that no docs change was needed.
- When you complete a task from `.nightshift/TODO.md`, mark it as done by changing `[ ]` to `[x]` and add a brief completion note under that task when useful.
- If a task is blocked, leave it unchecked and add the blocker to `.nightshift/NIGHT_SHIFT_REPORT.md`.
- If no safe actionable task exists, output exactly `<promise>COMPLETE</promise>` and stop.

## Project Night Shift files

Required:

- `.nightshift/TODO.md` — project-specific task queue.
- `.nightshift/DEFINITION_OF_DONE.md` — project-specific completion/validation rules.

Optional:

- `.nightshift/ready-*.md` — project-specific ready specs.
- `.nightshift/draft-*.md` — draft specs; read only if needed for context, do not implement.
- `.nightshift/NIGHT_SHIFT_REPORT.md` — blocker/report file; create or update when useful.

## Task selection order

1. Repository instructions: `AGENTS.md`, `CLAUDE.md`, `README.md`, and package scripts.
2. Project Night Shift task queue: `.nightshift/TODO.md`.
3. Ready project specs: `.nightshift/ready-*.md`.
4. Existing validation failures: typecheck, lint, tests, or build.
5. Small docs/process gaps that make future Night Shift runs safer.

## Per-task loop

1. Ensure the working tree is clean, or identify and avoid unrelated changes.
2. Read `.nightshift/DEFINITION_OF_DONE.md`.
3. Read `.nightshift/TODO.md` and pick exactly one unchecked ready task.
4. State the selected task before implementing it.
5. Read relevant project docs.
6. Inspect related code before editing.
7. TDD: write or adjust a failing test/fixture first when practical. If not practical, explain why.
8. Implement the smallest useful change.
9. Run `npm run check` if available; otherwise run individual lint, typecheck, test, and fallow/audit commands when available.
10. Fix validation issues that are safe and in scope, then rerun the failing validation.
11. Documentation step: update relevant docs if behavior, commands, routes, or workflow changed; if no docs are needed, record why.
12. Update `.nightshift/TODO.md` to mark the selected task done only after the definition of done is satisfied.
13. Do not silently skip failing checks.
14. Review your own diff against the selected task and definition of done.
15. Commit only your own changes if this is a git repo and validation passes.
16. End with a short report for human review.

## Blockers

If blocked, write a concise blocker note to `.nightshift/NIGHT_SHIFT_REPORT.md` when safe to create/update, then stop.

## Final response format

NIGHTSHIFT_TASK_PICKED_UP: <task id/title, or NONE>
NIGHTSHIFT_TASK_STATUS: <done|blocked|in-progress|none>
NIGHTSHIFT_TDD: <test-first summary, or why not practical>
NIGHTSHIFT_VALIDATION_COMMAND: <command run, repeat this line for each command>
NIGHTSHIFT_VALIDATION_RESULT: <pass|fail|not-run and brief reason>
NIGHTSHIFT_FIX: <issue fixed, or NONE>
NIGHTSHIFT_DOCS: <docs updated, or why no docs change was needed>
NIGHTSHIFT_FILES_TOUCHED:
- <path or NONE>

Report:
- Task:
- Files changed:
- Validation:
- Commit:
- Notes/blockers:

Only include `<promise>COMPLETE</promise>` when there are no known safe actionable tasks remaining.
