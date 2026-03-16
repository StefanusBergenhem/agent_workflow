---
name: wf-command-plan
description: "[DEPRECATED] Use /wf-command-swa instead — task contracts are now produced by the Software Architect"
---

> **DEPRECATED:** This command has been replaced:
> - Task contract creation → `/wf-command-swa` (Software Architect) produces `sprint.yaml` with full inline contracts
> - Worktree/branch setup → The pipeline orchestrator handles this automatically from `sprint.yaml`
>
> The old plan skill is kept for backward compatibility but is no longer invoked by the pipeline.

Legacy usage (if needed):

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
