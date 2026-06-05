# Night Shift Loop TODO

Backlog for proposed Night Shift loop/tooling improvements.

## Proposed features

- [ ] NS-LOOP-001 Add task-readiness analysis before implementation.
  - Goal: Before starting a task, analyze whether it is complex and whether all required information is available.
  - Expected behavior: If the task is sufficiently specified, proceed. If missing information can be gathered from the repo, docs, logs, or other available context, gather it. If required information cannot be inferred or gathered safely, route the missing-information need through the configurable follow-up/task-chain mechanism instead of guessin  - Splitting behavior: If a task is too complex or too broad to implement and validate safely in one loop iteration, split it into smaller independently-checkable TODOs instead of starting implementation. Each child task should have a clear goal, bounded scope, validation notes, and an origin reference to the parent task.
  - Chain integration: Readiness analysis can create targeted follow-up TODOs such as `needs-info`, `research`, `architecture-question`, `ux-question`, `human-input`, or `split-child`, assigned to personas like `ai:researcher`, `ai:architect`, `ai:ux`, or `human`.
  - Config idea: Projects can define how unresolved readiness questions or split tasks are chained, for example `analysis -> ai:researcher -> implementation`, `analysis -> human:product -> implementation`, `analysis -> ai:architect -> human:approval -> implementation`, or `analysis -> split into tracer-bullet implementation tasks -> ai:review`.
  - Acceptance notes: The loop/agent prompt should make this readiness check explicit before implementation work begins, especially for complex tasks, and should preserve origin links when creating readiness follow-up or split-child tasks.

- [ ] NS-LOOP-002 Add configurable follow-up TODO chains after task completion.
  - Goal: After completing an implementation TODO, optionally create one or more follow-up TODOs for later loop iterations, such as `review`, `architecture`, `ux`, or `human` tasks.
  - Expected behavior: The implementation task is closed normally, then configured follow-up tasks are added and each references the origin task ID/title. Later loops pick them up independently according to their task type and assignee/persona.
  - Routing idea: Follow-up tasks can target different users/agents, for example `ai:architect`, `ai:ux`, `ai:reviewer`, or `human`, and can be chained differently per project/config.
  - Config idea: Support project-specific chain presets, such as `implementation -> ai:review`, `implementation -> ai:architect -> ai:review`, or `implementation -> human:ux -> ai:review`.
  - Guardrail: Completing a generated follow-up task must only create the next configured step, and terminal tasks such as a final `review` should not create another review task unless explicitly configured.
  - Acceptance notes: The TODO format and agent prompt should distinguish task type, target user/agent, chain origin, and next-step behavior.
