# Night Shift Loop

A small wrapper for running an autonomous coding-agent loop with a hard wall-clock cap.

Night Shift is split into two parts:

- `loop/` — reusable runner, prompt, fallback React Native style guide, reference scripts, and loop-level logs.
- `<project>/.nightshift/` — project-specific backlog, current work file, Definition of Done, optional specs/reports, and generated project run logs.

The runner starts an autonomous coding agent, moves one ready backlog task into the current work file when needed, passes the project paths and selected style guide, and asks it to perform exactly one safe current task per iteration. The agent is expected to read project instructions first, follow the project's Definition of Done, use TDD where practical, run validation, update docs when needed, mark completed tasks, and emit machine-readable summary lines so the loop can log what happened. The loop stops when it reaches the time cap, iteration cap, an agent failure, or the agent outputs `<promise>COMPLETE</promise>`.

It uses **pi headless print mode** by default:

```bash
pi -p "<prompt>"
```

It can also use the Cursor agent preset:

```bash
agent --yolo "<prompt>"
```

The workflow is intentionally conservative:

1. Read the loop prompt in `AGENT_LOOP.md`.
2. Ask the selected agent to perform one safe task.
3. Before implementation, require task readiness analysis so the agent can proceed, gather repo context, split work that is too complex, or ask for human input instead of guessing.
4. By default, create no extra post-completion review tasks. If configured, append persona-specific follow-up backlog tasks such as architecture, UX, reviewer, or human tasks.
5. Stop if the agent outputs `<promise>COMPLETE</promise>`.
6. Otherwise repeat until the iteration cap or time cap is reached.

By default, the loop runs for **up to 5 hours from script start**.

## Files

- `night-shift.sh` — executable loop runner and npm `bin` target.
- `package.json` — installable CLI package metadata for `night-shift` / `nightshift`.
- `BACKLOG.md` — source-repo backlog for proposed Night Shift loop/tooling improvements.
- `AGENT_LOOP.md` — base autonomous-agent prompt.
- `NIGHTSHIFT_DEFINITION_OF_DONE.md` — bundled project-agnostic completion rules, including the commit rule.
- `REACTNATIVE_DEFAULT_STYLE_GUIDE.md` — fallback React Native/Expo style guide used when a project does not provide one.
- `tests/readiness-analysis-prompt-test.sh` — lightweight prompt/docs regression test for readiness-analysis guidance.
- `tests/readiness-logging-test.sh` — lightweight runner regression test for readiness-decision log summaries.
- `tests/nightshift-scaffold-test.sh` — lightweight runner regression test for missing `.nightshift` scaffolding.
- `tests/current-backlog-population-test.sh` — lightweight runner regression test for moving one ready backlog task into the current work file.
- `tests/cursor-agent-preset-test.sh` — lightweight runner regression test for the Cursor `agent --yolo` preset.
- `tests/follow-up-chain-test.sh` — lightweight runner regression test for configurable follow-up chain prompt/config wiring.
- `tests/package-cli-test.sh` — lightweight package/bin regression test for installable CLI metadata.
- `references/ralph-afk.sh` — original reference script this loop was based on.
- `logs/night-shift.log` — general append-only run log, created at runtime.
- `logs/runs/<run-id>.log` — detailed per-run logs, created at runtime.
- `logs/iterations.tsv` — append-only per-iteration overview across runs, created at runtime.
- `logs/iterations.md` — append-only Markdown table view of the same per-iteration overview, created at runtime.

## Project `.nightshift/` folder

Night Shift logic stays in `loop/`. Project-agnostic completion rules stay bundled with the CLI in `NIGHTSHIFT_DEFINITION_OF_DONE.md`. Project-specific task/config files stay in the project under `.nightshift/`.

Required per project:

```text
<project>/.nightshift/BACKLOG.md
<project>/.nightshift/CURRENT.md
<project>/.nightshift/DEFINITION_OF_DONE.md
```

If `.nightshift/`, `BACKLOG.md`, `CURRENT.md`, `DEFINITION_OF_DONE.md`, or `.nightshift/.gitignore` is missing, the runner creates the missing directory/files before invoking the selected agent. If a legacy `.nightshift/TODO.md` exists and `BACKLOG.md` does not, the runner migrates it to `BACKLOG.md`. The generated backlog, current-work, and Definition of Done files contain comment-only starter guidance so they are safe placeholders until you add real tasks and completion rules. The generated `.gitignore` ignores `logs/` while runs are in progress; finalized per-run logs are still force-added by the CLI log commit.

`DEFINITION_OF_DONE.md` should define the project-specific build process. For this repo pattern, it should require TDD where practical, `npm run check` when available, fallback lint/typecheck/test/fallow commands when `check` is unavailable, and explicit logging of validation runs and fixes. Do not duplicate universal Night Shift rules here; keep project-agnostic rules such as "commit this iteration's validated changes" in the bundled `NIGHTSHIFT_DEFINITION_OF_DONE.md`.

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

## Backlog to current-work flow

`BACKLOG.md` is the durable source for ready, draft, generated, follow-up, and completed task records. `CURRENT.md` is the iteration work file. Before each iteration, the runner checks `CURRENT.md`; if it has no unchecked task, the runner archives any completed current task into the backlog's **Completed tasks** section, then moves the first unchecked task from the backlog's **Ready tasks** section into `CURRENT.md`. If `CURRENT.md` already has an unchecked task or connected task set, the runner leaves it in place so work can resume.

Agents work only from `CURRENT.md`. When they need to create new tasks because of splitting, readiness follow-up, blockers, or configured review chains, they append actionable items under `BACKLOG.md` **Ready tasks** and unclear ideas under **Draft tasks** rather than adding more unrelated work to `CURRENT.md`.

## Task readiness analysis

Before coding the selected current task, the agent must make a `READINESS DECISION`:

- `ready` — implement normally.
- `gatherable` — collect missing context from the repo, docs, tests, logs, style guide, or `.nightshift` files, then reassess.
- `split` — if the task is too complex or broad for one safe iteration, split it into smaller independently-checkable child backlog tasks with bounded scope, validation notes, and an origin reference to the parent task.
- `needs-human` — if required information cannot be gathered safely, ask for human input through a targeted follow-up backlog task or blocker note instead of guessing.

When splitting or asking for human input, the parent task is closed in `CURRENT.md` as a non-implementation state rather than left unchecked. Do not leave the original task unchecked in `CURRENT.md` after creating child tasks or an input request. The new child/follow-up tasks carry the origin reference in `BACKLOG.md` so later loop iterations can continue the work safely without being blocked by the parent task.

## Configurable follow-up chains

Post-completion follow-up backlog tasks are opt-in. By default, Night Shift uses:

```text
Follow-up chain: none
```

With the default, the agent must not add extra review, architecture, UX, or human follow-up tasks after completing an implementation task unless the selected task explicitly asks for them.

Configure a chain from the CLI or environment:

```bash
night-shift --follow-up-chain ai:reviewer --project hello-world
night-shift --follow-up-chain ai:architect,ai:reviewer --project hello-world
NIGHTSHIFT_FOLLOW_UP_CHAIN=ai:ux,ai:reviewer night-shift --project hello-world
```

Configured steps are ordered personas. After an implementation task is completed, the agent appends only the first follow-up task to `BACKLOG.md`. Generated follow-ups include metadata such as `Type`, `Persona`, `Chain origin`, `Chain step`, and `Next step`. When a generated follow-up is later picked up, the runner moves it into `CURRENT.md`; the agent adopts the requested persona and creates only the next configured step. For example, `ai:architect` reviews structure, boundaries, dependencies, and maintainability; `ai:ux` reviews user flow, copy, accessibility, and interaction clarity; `ai:reviewer` performs a general correctness/regression review. Terminal steps do not create another review unless explicitly configured.

Use an optional project-specific guidance file for naming or review criteria:

```bash
night-shift --follow-up-chain ai:architect,ai:reviewer --follow-up-config .nightshift/FOLLOW_UP_CHAIN.md --project hello-world
```

Example generated follow-up shape:

```text
- [ ] NS-HW-123-FU-1 Architecture review for NS-HW-123
  - Type: architecture
  - Persona: ai:architect
  - Chain origin: NS-HW-123 Add checkout flow
  - Chain step: 1/2
  - Next step: ai:reviewer
  - Goal: Review structure, module boundaries, dependencies, and maintainability for the origin task.
```

## Install as a CLI

From a checked-out copy of this `loop/` package, install globally:

```bash
cd loop
npm install -g .
```

Then run it from any project directory:

```bash
night-shift
```

Or point it at a target project from elsewhere:

```bash
night-shift --duration 5h --project /path/to/project
```

The package also installs a `nightshift` alias. The installed CLI carries its bundled `AGENT_LOOP.md`, `NIGHTSHIFT_DEFINITION_OF_DONE.md`, and fallback `REACTNATIVE_DEFAULT_STYLE_GUIDE.md`, so it does not need the source checkout at runtime.

Uninstall with:

```bash
npm uninstall -g nightshift-loop
```

## Basic usage

Run for the default 5 hours against the current directory:

```bash
night-shift
# or, from this source checkout:
loop/night-shift.sh
```

Run for a specific duration and project:

```bash
night-shift --duration 5h --project hello-world
```

Short positional form:

```bash
night-shift 5h hello-world
```

Run with Cursor agent instead of pi:

```bash
night-shift --agent cursor --duration 5h --project hello-world
```

Run with a configured follow-up chain:

```bash
night-shift --follow-up-chain ai:architect,ai:reviewer --project hello-world
```

This uses the defaults unless overridden:

- max runtime: `18000` seconds / 5 hours
- max iterations: `999999`
- project/workdir: `NIGHTSHIFT_PROJECT` or current directory
- prompt: bundled `AGENT_LOOP.md` next to the installed/source CLI
- agent command: `pi -p`
- follow-up chain: `none` (no extra review/architecture/UX tasks unless configured)
- log directory: `<project>/.nightshift/logs`

## Logs

Every run writes a concise run log, raw agent output files, and an append-only iteration overview. Human-readable timestamps use the machine's local time with a numeric timezone offset, for example `2026-06-07T14:30:00+0100`:

1. General run log:

   ```text
   <project>/.nightshift/logs/night-shift.log
   ```

   This is an append-only history of loop starts and finishes. Each entry includes the run id, local timestamps, final status, exit code, iteration count, workdir, prompt file, time cap, and per-run log path.

2. Concise per-run detail log:

   ```text
   <project>/.nightshift/logs/runs/<run-id>.log
   ```

   This records the useful summary for that specific run: config, iteration start/end, worktree state, task picked up, task status, readiness decision, TDD summary, validation commands/results, fixes, docs review, files reported by the agent, final worktree state, commit, completion detection, and final reason.

3. Raw agent output files:

   ```text
   <project>/.nightshift/logs/runs/<run-id>.raw/iteration-<n>.log
   ```

   Full agent output is saved here instead of being pasted inline into the per-run log. ANSI terminal control sequences are stripped before saving.

4. Cross-run iteration overview:

   ```text
   <project>/.nightshift/logs/iterations.tsv
   <project>/.nightshift/logs/iterations.md
   ```

   These files append one entry per iteration across all runs. The TSV is the machine-readable source; the Markdown file renders each iteration as a compact vertical field/value table so long values do not create an unreadably wide table. They include run id, iteration number, status, iteration duration, visible prompt/output length, estimated visible token usage, any agent-reported token usage, task type/persona/source metadata, task status, readiness decision, and links to the raw output and per-run log. Token estimates use a simple visible-text approximation from the prompt and sanitized raw output; when an agent can report exact usage, that value is stored separately in `reported_token_usage`.

Use a custom log directory with:

```bash
NIGHTSHIFT_LOG_DIR=/tmp/nightshift-logs night-shift
```

Keep the runtime log directory ignored by git (for example, `logs/` in project `.nightshift/.gitignore`) so in-progress and aggregate log files do not dirty the agent's working tree. At shutdown, when the log directory is inside the target git repository, the loop CLI force-adds and commits the finalized per-run detail log and raw agent output in a separate log-only commit:

```text
chore: add Night Shift run logs <run-id>
```

The commit uses an explicit pathspec so pre-existing staged or unstaged user changes are not included. Append-only aggregate files such as `night-shift.log`, `iterations.tsv`, and `iterations.md` remain local by default to avoid dirtying later runs before the agent starts.

The agent prompt asks the selected agent to include these machine-readable lines in its final response so the loop can summarize task activity, readiness, TDD, validation, fixes, and documentation review in the run log:

```text
NIGHTSHIFT_TASK_PICKED_UP: <task id/title, or NONE>
NIGHTSHIFT_TASK_STATUS: <done|blocked|in-progress|none; use done when split/input follow-up was created and the original task is non-blocking>
NIGHTSHIFT_TASK_TYPE: <implementation|review|architecture|ux|human-input|follow-up|none>
NIGHTSHIFT_TASK_PERSONA: <ai:implementer|ai:reviewer|ai:architect|ai:ux|human|none>
NIGHTSHIFT_TASK_SOURCE: <human-or-unmarked|ai-generated-follow-up|ai-generated-readiness|none|unknown>
NIGHTSHIFT_TOKEN_USAGE: <agent-reported prompt/completion/total tokens or context usage if available; otherwise unavailable>
NIGHTSHIFT_READINESS_DECISION: <ready|gatherable|split|needs-human|none and brief reason>
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
TASK_META iteration=1 type=implementation persona=ai:implementer source=human-or-unmarked ai_persona_task=no
USAGE iteration=1 duration_seconds=42 prompt_chars=15234 prompt_tokens_est=3809 output_chars=2480 output_lines=52 output_tokens_est=620 total_visible_tokens_est=4429 reported_token_usage=unavailable
READINESS iteration=1 decision=ready - small static copy task
TDD iteration=1 summary=Added failing home screen content test first, then implemented copy.
VALIDATION iteration=1 VALIDATION_COMMAND: npm run check
VALIDATION iteration=1 VALIDATION_RESULT: pass
FIX iteration=1 summary=NONE
DOCS iteration=1 summary=No separate docs needed for static copy-only change.
FILES_REPORTED iteration=1 path=app/(tabs)/index.tsx
COMMIT iteration=1 value=3c7865b Add Night Shift note to home screen
WORKTREE iteration=1 after=clean
```

The loop also independently checks `git status --short --untracked-files=all` after each iteration. If the agent committed its work, this will normally be `WORKTREE ... after=clean`; the files changed are still captured from `NIGHTSHIFT_FILES_TOUCHED`. Finalized per-run logs are committed by the CLI after the run log receives its final summary.

Set `NIGHTSHIFT_LOG_VERBOSE=1` to include lower-level debug entries such as pids, temp files, and watcher steps.

## Run against a specific project

Preferred named-argument form:

```bash
night-shift --duration 5h --project hello-world
```

Positional form:

```bash
night-shift 5h hello-world
```

Set an iteration cap separately when needed:

```bash
night-shift --duration 5h --project hello-world --iterations 25
```

Arguments/options:

```text
night-shift [duration] [project]
night-shift --duration 5h --project hello-world --iterations 25
```

- `duration` accepts `0`, seconds, `Nm`, or `Nh`.
- `project` defaults to `NIGHTSHIFT_PROJECT` or the current directory.
- `iterations` defaults to `NIGHTSHIFT_ITERATIONS` or `999999`.

## Limit to 5 hours

The 5-hour limit is already the default:

```bash
night-shift
```

Explicitly:

```bash
NIGHTSHIFT_MAX_SECONDS=18000 night-shift
# or
night-shift --duration 5h
```

The timer starts when `night-shift.sh` starts. If an agent invocation is still running when the cap is reached, the script terminates that invocation and exits cleanly.

## Short test run

Use a small time cap while testing the loop itself:

```bash
night-shift --duration 60s --project hello-world --iterations 10
```

## Disable the time cap

```bash
night-shift --duration 0 --project hello-world --iterations 25
```
Use this carefully. Without a time cap, the loop stops only when:

- it reaches the iteration cap,
- the agent outputs `<promise>COMPLETE</promise>`, or
- the agent command fails.

## Agent configuration

The loop uses the `pi` preset by default, which runs `pi -p` in pi's headless print mode.

Examples:

```bash
PI_FLAGS='-p --model sonnet:high' night-shift
```

```bash
PI_FLAGS='-p --no-context-files' night-shift --duration 5h --project hello-world
```

Use `PI_BIN` if pi is not on your `PATH`:

```bash
PI_BIN=/path/to/pi night-shift
```

Use Cursor agent with the `cursor` preset:

```bash
night-shift --agent cursor --duration 5h --project hello-world
# equivalent via env:
NIGHTSHIFT_AGENT=cursor night-shift --duration 5h --project hello-world
```

The Cursor preset runs:

```bash
agent --yolo "<prompt>"
```

Override the executable or flags when needed:

```bash
CURSOR_AGENT_BIN=/path/to/agent CURSOR_AGENT_FLAGS='--yolo' night-shift --agent cursor
```

## Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `NIGHTSHIFT_PROJECT` | current directory | Project directory to run against. Missing `.nightshift/BACKLOG.md`, `.nightshift/CURRENT.md`, and `.nightshift/DEFINITION_OF_DONE.md` files are scaffolded automatically. Legacy `.nightshift/TODO.md` is migrated to `BACKLOG.md` when needed. |
| `NIGHTSHIFT_ITERATIONS` | `999999` | Max iterations. |
| `NIGHTSHIFT_MAX_SECONDS` | `18000` | Max wall-clock runtime. Accepts seconds, `Nm`, or `Nh`. Set `0` to disable. |
| `NIGHTSHIFT_PROMPT` | `loop/AGENT_LOOP.md` | Prompt file passed to the selected agent. |
| `NIGHTSHIFT_LOG_DIR` | `<project>/.nightshift/logs` | Directory for general, per-run, and raw output logs. |
| `NIGHTSHIFT_LOG_VERBOSE` | `0` | Set to `1` for low-level debug log entries. |
| `NIGHTSHIFT_FOLLOW_UP_CHAIN` | `none` | Optional comma-separated persona chain, for example `ai:architect,ai:reviewer`. Default creates no extra review tasks. |
| `NIGHTSHIFT_FOLLOW_UP_CONFIG` | unset | Optional project-relative or absolute file with follow-up chain naming/persona guidance. |
| `NIGHTSHIFT_AGENT` | `pi` | Agent preset: `pi`, `cursor`, or `custom`. |
| `NIGHTSHIFT_AGENT_BIN` | preset-specific | Override selected agent executable. Required for `custom`. |
| `NIGHTSHIFT_AGENT_FLAGS` | preset-specific | Override selected agent flags. |
| `PI_BIN` | `pi` | pi executable alias for the `pi` preset. |
| `PI_FLAGS` | `-p` | pi flags alias for the `pi` preset. Keep `-p` for headless print mode. |
| `CURSOR_AGENT_BIN` | `agent` | Cursor agent executable alias for the `cursor` preset. |
| `CURSOR_AGENT_FLAGS` | `--yolo` | Cursor agent flags alias for the `cursor` preset. |

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
