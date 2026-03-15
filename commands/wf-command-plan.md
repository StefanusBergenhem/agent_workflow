---
name: wf-command-plan
description: "Run the plan phase — produce an agent-executable task contract from the sprint backlog"
---

Load and execute the plan skill.

1. Read `.workflow/config.yaml` for project paths and settings
2. Read the sprint file to identify the next incomplete task
3. Read `current_task.yaml` to confirm no task is already active (if one exists, HALT and report — finish or discard the active task first)
4. Follow the instructions in the `plan` skill (skills/wf-skill-plan/SKILL.md)
5. Present the task summary for human approval (goal, approach, scope, risks)
6. On approval:
   - Create the feature branch
   - Run baseline checks
   - Write `current_task.yaml` with the full task contract
   - Update `.workflow/pipeline_state.yaml` to `phase: build`
