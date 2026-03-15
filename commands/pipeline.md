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
analyse -> plan -> build -> review -> (approve -> plan | reject -> build)
                                         |
                                    sprint complete -> analyse
```

**State transitions:**
- `idle` or `analyse`: Run `/analyse`. On approval, transition to `plan`.
- `plan`: Run `/plan`. On approval, transition to `build`.
- `build`: Run `/build`. On completion, transition to `review`.
- `review`: Run `/review`.
  - On approval: transition to `plan` (next task) or `analyse` (sprint complete).
  - On rejection: transition to `build` with `feedback.yaml`. Increment `attempt_count`.

**Guardrails:**
- Max 3 review attempts per task. On 3rd rejection, HALT and escalate to the human.
- Human approval is required at every phase gate (analyse, plan, review).
- If any phase HALTs, stop the pipeline and report the halt reason.

5. After each phase completes, update `.workflow/pipeline_state.yaml` with current state.
