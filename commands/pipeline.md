---
name: pipeline
description: "Run the full pipeline — orchestrate analyse/plan/build/review in a loop"
---

Load and execute the orchestrate skill.

1. Read `.workflow/config.yaml` for project paths and settings
2. Read `.workflow/pipeline_state.yaml` to determine current phase
3. Follow the instructions in the `orchestrate` skill (skills/orchestrate/SKILL.md)
4. Execute the pipeline state machine:

```
analyse → approve sprint → compute stages →
  plan stage → approve stage → execute stage (parallel builds + reviews) →
  [more stages?] → plan stage →
  [all done?] → idle
```

Within each stage execution:
```
Each task: build → review → (approve → merge to main | reject → retry build, max 3x)
Tasks within a stage run in parallel (separate git worktrees).
```

**State transitions:**
- `idle`: Transition to `analysing`. Run `/analyse`.
- `analysing`: Sprint analysis in progress.
- `awaiting_analyse_approval`: Sprint cut presented. On approval, transition to `computing_stages`.
- `computing_stages`: Topological sort of tasks into dependency stages. Automatic transition to `planning_stage`.
- `planning_stage`: Plan all tasks in the current stage as a batch. On completion, transition to `awaiting_stage_approval`.
- `awaiting_stage_approval`: Stage task contracts presented. On approval, transition to `executing_stage`.
- `executing_stage`: All tasks in the stage run build→review in parallel worktrees. Approved tasks merge to main immediately. On stage completion, transition to `stage_complete`.
- `stage_complete`: Check for more stages. If yes, transition to `planning_stage` for the next stage. If all done, transition to `idle`.

**Guardrails:**
- Max 3 review attempts per task. On 3rd rejection, escalate the task (other tasks continue).
- Human approval is required after analyse (sprint) and after each stage plan (batch of task contracts).
- Escalated tasks block their dependents in later stages.
- Merge conflicts escalate to the human.
- If any phase HALTs, stop the pipeline and report the halt reason.

5. After each phase completes, update `.workflow/pipeline_state.yaml` with current state.
