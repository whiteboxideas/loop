# Night Shift Loop

A small wrapper for running an autonomous coding-agent loop with a hard wall-clock cap.

The workflow is intentionally conservative:

1. Read the loop prompt in `AGENT_LOOP.md`.
2. Ask Claude to perform one safe task.
3. Stop if Claude outputs `<promise>COMPLETE</promise>`.
4. Otherwise repeat until the iteration cap or time cap is reached.

By default, the loop runs for **up to 5 hours from script start**.

## Files

- `night-shift.sh` — executable loop runner.
- `AGENT_LOOP.md` — base autonomous-agent prompt.
- `references/ralph-afk.sh` — original reference script this loop was based on.

## Basic usage

From the repository root:

```bash
loop/night-shift.sh
```

This uses the defaults:

- max runtime: `18000` seconds / 5 hours
- max iterations: `999999`
- workdir: current directory
- prompt: `loop/AGENT_LOOP.md`
- Claude command: `claude --dangerously-skip-permissions`

## Run against a specific workdir

```bash
loop/night-shift.sh 999999 hello-world
```

Arguments:

```text
loop/night-shift.sh [iterations] [workdir]
```

- `iterations` is optional and defaults to `NIGHTSHIFT_ITERATIONS` or `999999`.
- `workdir` is optional and defaults to the current directory.

## Limit to 5 hours

The 5-hour limit is already the default:

```bash
loop/night-shift.sh
```

Explicitly:

```bash
NIGHTSHIFT_MAX_SECONDS=18000 loop/night-shift.sh
```

The timer starts when `night-shift.sh` starts. If a Claude invocation is still running when the cap is reached, the script terminates that invocation and exits cleanly.

## Short test run

Use a small time cap while testing the loop itself:

```bash
NIGHTSHIFT_MAX_SECONDS=60 loop/night-shift.sh 10 hello-world
```

## Disable the time cap

```bash
NIGHTSHIFT_MAX_SECONDS=0 loop/night-shift.sh 25 hello-world
```

Use this carefully. Without a time cap, the loop stops only when:

- it reaches the iteration cap,
- Claude outputs `<promise>COMPLETE</promise>`, or
- the Claude command fails.

## Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `NIGHTSHIFT_ITERATIONS` | `999999` | Max iterations when no argument is passed. |
| `NIGHTSHIFT_MAX_SECONDS` | `18000` | Max wall-clock runtime. Set `0` to disable. |
| `NIGHTSHIFT_PROMPT` | `loop/AGENT_LOOP.md` | Prompt file passed to Claude. |
| `CLAUDE_BIN` | `claude` | Claude executable to run. |
| `CLAUDE_FLAGS` | `--dangerously-skip-permissions` | Extra flags passed to Claude. |

## Completion signal

Claude should output this exact token when there is no safe actionable task left:

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
