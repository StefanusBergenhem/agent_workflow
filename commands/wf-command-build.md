---
name: wf-command-build
description: "Run the build phase — execute the current task contract using TDD"
---

Run the build phase for the current task.

1. Read `.workflow/config.yaml` for project paths
2. Verify `.workflow/current_task.yaml` exists — if not, HALT (no active task)
3. Load and execute the build skill (`skills/wf-skill-build/SKILL.md`) — it defines the full process

On success, pipeline state transitions to the review phase.
