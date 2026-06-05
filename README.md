# Night Shift Loop

A small wrapper for running an autonomous coding-agent loop with a hard wall-clock cap.

Night Shift is split into two parts:

- `loop/` — reusable runner, prompt, fallback React Native style guide, reference scripts, and loop-level logs.
- `<project>/.nightshift/` — project-specific task queue, Definition of Done, optional specs/reports, and generated project run logs.

The runner starts `pi` in headless print mode, passes it the project paths and selected style guide, and asks it to perform exactly one safe ready task per iteration. The agent is expected to read project instructions first, follow the project's Definition of Done, use TDD where practical, run validation, update docs when needed, mark completed tasks, and emit machine-readable summary lines so the loop can log what happened. The loop stops when it reaches the time cap, iteration cap, a `pi` failure, or the agent outputs `<promise>COMPLETE</promise>`.

It uses **pi headless print mode** by default:

```bash
pi -p "<prompt>"
```

The workflow is intentionally conservative:

1. Read the loop prompt in `AGENT_LOOP.md`.
2. Ask pi to perform one safe task in headless print mode.
3. Stop if the agent outputs `<promise>COMPLETE</promise>`.
4. Otherwise repeat until the iteration cap or time cap is reached.

By default, the loop runs for **up to 5 hours from script start**.

## Files

- `night-shift.sh` — executable loop runner.
- `AGENT_LOOP.md` — base autonomous-agent prompt.
- `REACTNATIVE_DEFAULT_STYLE_GUIDE.md` — fallback React Native/Expo style guide used when a project does not provide one.
- `references/ralph-afk.sh` — original reference script this loop was based on.
- `logs/night-shift.log` — general append-only run log, created at runtime.
- `logs/runs/<run-id>.log` — detailed per-run logs, created at runtime.

## Project `.nightshift/` folder

Night Shift logic stays in `loop/`. Project-specific task/config files stay in the project under `.nightshift/`.

Required per project:

```text
<project>/.nightshift/TODO.md
<project>/.nightshift/DEFINITION_OF_DONE.md
```

`DEFINITION_OF_DONE.md` should define the project-specific build process. For this repo pattern, it should require TDD where practical, `npm run check` when available, fallback lint/typecheck/test/fallow commands when `check` is unavailable, and explicit logging of validation runs and fixes.

Optional per project:

```text
<project>/REACTNATIVE_DEFAULT_STYLE_GUIDE.md
<project>/STYLE_GUIDE.md
<project>/docs/REACTNATIVE_DEFAULT_STYLE_GUIDE.md
<project>/docs/STYLE_GUIDE.md
<project>/.nightshift/REACTNATIVE_DEFAULT_STYLE_GUIDE.md
<project>/.nightshift/STYLE_GUIDE.md
<project>/.nightshift/ready-*.md
<project>/.nightshift/draft-*.md
<project>/.nightshift/NIGHT_SHIFT_REPORT.md
```

The first style guide found in that order is passed to the agent. If none exists, `loop/REACTNATIVE_DEFAULT_STYLE_GUIDE.md` is passed as the default React Native style guide.

If a required `.nightshift` file is missing, the loop logs a `config_error`, prints the missing path(s), and exits before invoking pi.

## Basic usage

Run for the default 5 hours against the current directory:

```bash
loop/night-shift.sh
```

Run for a specific duration and project:

```bash
loop/night-shift.sh --duration 5h --project hello-world
```

Short positional form:

```bash
loop/night-shift.sh 5h hello-world
```

This uses the defaults unless overridden:

- max runtime: `18000` seconds / 5 hours
- max iterations: `999999`
- project/workdir: `NIGHTSHIFT_PROJECT` or current directory
- prompt: `loop/AGENT_LOOP.md`
- pi command: `pi -p`
- log directory: `<project>/.nightshift/logs`

## Logs

Every run writes a concise run log plus raw agent output files:

1. General run log:

   ```text
   <project>/.nightshift/logs/night-shift.log
   ```

   This is an append-only history of loop starts and finishes. Each entry includes the run id, timestamps, final status, exit code, iteration count, workdir, prompt file, time cap, and per-run log path.

2. Concise per-run detail log:

   ```text
   <project>/.nightshift/logs/runs/<run-id>.log
   ```

   This records the useful summary for that specific run: config, iteration start/end, worktree state, task picked up, task status, TDD summary, validation commands/results, fixes, docs review, files reported by the agent, final worktree state, commit, completion detection, and final reason.

3. Raw agent output files:

   ```text
   <project>/.nightshift/logs/runs/<run-id>.raw/iteration-<n>.log
   ```

   Full pi output is saved here instead of being pasted inline into the per-run log. ANSI terminal control sequences are stripped before saving.

Use a custom log directory with:

```bash
NIGHTSHIFT_LOG_DIR=/tmp/nightshift-logs loop/night-shift.sh
```

Runtime logs should be ignored by git from the project `.nightshift/.gitignore`:

```gitignore
logs/
```

For config errors where the project `.nightshift/` folder itself is missing, the runner falls back to `loop/logs` so the failure can still be recorded.

The agent prompt asks pi to include these machine-readable lines in its final response so the loop can summarize task activity, TDD, validation, fixes, and documentation review in the run log:

```text
NIGHTSHIFT_TASK_PICKED_UP: <task id/title, or NONE>
NIGHTSHIFT_TASK_STATUS: <done|blocked|in-progress|none>
NIGHTSHIFT_TDD: <test-first summary, or why not practical>
NIGHTSHIFT_VALIDATION_COMMAND: <command run, repeat this line for each command>
NIGHTSHIFT_VALIDATION_RESULT: <pass|fail|not-run and brief reason>
NIGHTSHIFT_FIX: <issue fixed, or NONE>
NIGHTSHIFT_DOCS: <docs updated, or why no docs change was needed>
NIGHTSHIFT_FILES_TOUCHED:
- <path or NONE>
```

The loop turns those lines into concise per-run entries such as:

```text
TASK iteration=1 picked_up=NS-HW-010 Add a short Night Shift note to the Home screen status=done
TDD iteration=1 summary=Added failing home screen content test first, then implemented copy.
VALIDATION iteration=1 VALIDATION_COMMAND: npm run check
VALIDATION iteration=1 VALIDATION_RESULT: pass
FIX iteration=1 summary=NONE
DOCS iteration=1 summary=No separate docs needed for static copy-only change.
FILES_REPORTED iteration=1 path=app/(tabs)/index.tsx
COMMIT iteration=1 value=3c7865b Add Night Shift note to home screen
WORKTREE iteration=1 after=clean
```

The loop also independently checks `git status --short --untracked-files=all` after each iteration. If the agent committed its work, this will normally be `WORKTREE ... after=clean`; the files changed are still captured from `NIGHTSHIFT_FILES_TOUCHED`.

Set `NIGHTSHIFT_LOG_VERBOSE=1` to include lower-level debug entries such as pids, temp files, and watcher steps.

## Run against a specific project

Preferred named-argument form:

```bash
loop/night-shift.sh --duration 5h --project hello-world
```

Positional form:

```bash
loop/night-shift.sh 5h hello-world
```

Set an iteration cap separately when needed:

```bash
loop/night-shift.sh --duration 5h --project hello-world --iterations 25
```

Arguments/options:

```text
loop/night-shift.sh [duration] [project]
loop/night-shift.sh --duration 5h --project hello-world --iterations 25
```

- `duration` accepts `0`, seconds, `Nm`, or `Nh`.
- `project` defaults to `NIGHTSHIFT_PROJECT` or the current directory.
- `iterations` defaults to `NIGHTSHIFT_ITERATIONS` or `999999`.

## Limit to 5 hours

The 5-hour limit is already the default:

```bash
loop/night-shift.sh
```

Explicitly:

```bash
NIGHTSHIFT_MAX_SECONDS=18000 loop/night-shift.sh
# or
loop/night-shift.sh --duration 5h
```

The timer starts when `night-shift.sh` starts. If a pi invocation is still running when the cap is reached, the script terminates that invocation and exits cleanly.

## Short test run

Use a small time cap while testing the loop itself:

```bash
loop/night-shift.sh --duration 60s --project hello-world --iterations 10
```

## Disable the time cap

```bash
loop/night-shift.sh --duration 0 --project hello-world --iterations 25
```

Use this carefully. Without a time cap, the loop stops only when:

- it reaches the iteration cap,
- the agent outputs `<promise>COMPLETE</promise>`, or
- the pi command fails.

## pi configuration

The loop uses `pi -p` by default, which is pi's headless print mode.

Examples:

```bash
PI_FLAGS='-p --model sonnet:high' loop/night-shift.sh
```

```bash
PI_FLAGS='-p --no-context-files' loop/night-shift.sh --duration 5h --project hello-world
```

Use `PI_BIN` if pi is not on your `PATH`:

```bash
PI_BIN=/path/to/pi loop/night-shift.sh
```

## Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `NIGHTSHIFT_PROJECT` | current directory | Project directory to run against. Must contain `.nightshift/TODO.md` and `.nightshift/DEFINITION_OF_DONE.md`. |
| `NIGHTSHIFT_ITERATIONS` | `999999` | Max iterations. |
| `NIGHTSHIFT_MAX_SECONDS` | `18000` | Max wall-clock runtime. Accepts seconds, `Nm`, or `Nh`. Set `0` to disable. |
| `NIGHTSHIFT_PROMPT` | `loop/AGENT_LOOP.md` | Prompt file passed to pi. |
| `NIGHTSHIFT_LOG_DIR` | `<project>/.nightshift/logs` | Directory for general, per-run, and raw output logs. Falls back to `loop/logs` only when project `.nightshift/` is missing. |
| `NIGHTSHIFT_LOG_VERBOSE` | `0` | Set to `1` for low-level debug log entries. |
| `PI_BIN` | `pi` | pi executable to run. |
| `PI_FLAGS` | `-p` | Flags passed to pi. Keep `-p` for headless print mode. |

## Completion signal

The agent should output this exact token when there is no safe actionable task left:

```text
<promise>COMPLETE</promise>
```

When the token appears, `night-shift.sh` stops early.

## Safety notes

- Start with clean commits before running an unattended loop.
- Keep `AGENT_LOOP.md` conservative until expected behavior is defined.
- Prefer tests/docs/process tasks over speculative feature work.
- Review all commits and reports after the loop finishes.
- Do not run long unattended sessions on important repos without strong validation.
