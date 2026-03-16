---
name: wf-command-pipeline
description: "Run the automated pipeline — compute stages from sprint.yaml, build/review in parallel, run retrospective"
---

Load and execute the orchestrate skill.

1. Read `.workflow/config.yaml` for project paths and settings
2. Read `.workflow/pipeline_state.yaml` to determine current phase
3. Follow the instructions in the `orchestrate` skill (skills/wf-skill-orchestrate/SKILL.md)
4. Execute the pipeline state machine:

**Prerequisites:** `sprint.yaml` must exist (produced by `/wf-command-swa`). If not present, the pipeline will HALT and tell you to run `/wf-command-swa` first.

```
compute stages from sprint.yaml →
  plan worktrees → approve stage → execute stage (parallel builds + reviews) →
  [more stages?] → plan worktrees →
  [all done?] → retrospective → idle
```

Within each stage execution:
```
Each task: build → review → (approve → merge to main | reject → retry build, max 3x)
Tasks within a stage run in parallel (separate git worktrees).
Design issues → halt task, write design_issues.yaml, continue other tasks.
```

**State transitions:**
- `idle`: Run resume detection first. If sprint.yaml has incomplete tasks, skip to the appropriate phase. If no sprint.yaml exists, HALT.
- `computing_stages`: Topological sort of tasks into dependency stages. Automatic transition to `planning_worktrees`.
- `planning_worktrees`: Create git worktrees and write task contracts for the current stage. Automatic transition to `awaiting_stage_approval`.
- `awaiting_stage_approval`: Stage task contracts presented. On approval, transition to `executing_stage`.
- `executing_stage`: All tasks in the stage run build→review in parallel worktrees. Approved tasks merge to main immediately. On stage completion, transition to `stage_complete`.
- `stage_complete`: Check for more stages. If yes, transition to `planning_worktrees` for the next stage. If all done, transition to `retrospective`.
- `retrospective`: Run sprint retrospective analysis. Produces `retrospective/<sprint-id>.md`. Transition to `idle`.

**Guardrails:**
- Max 3 review attempts per task. On 3rd rejection, escalate the task (other tasks continue).
- Human approval is required after each stage plan (batch of task contracts).
- Design issues halt the affected task immediately (no retries — requires architect intervention).
- Escalated tasks and design-issue tasks block their dependents in later stages.
- Merge conflicts escalate to the human.
- If any phase HALTs, stop the pipeline and report the halt reason.
- Retrospective runs automatically at pipeline end.

5. After each phase completes, update `.workflow/pipeline_state.yaml` with current state.
