---
name: wf-command-review
description: "Run the review phase — validate the build against the task contract"
---

Run the review phase for the current task.

1. Read `.workflow/config.yaml` for project paths
2. Verify `.workflow/current_task.yaml` and `.workflow/review_ready.yaml` both exist — if not, HALT (nothing to review)
3. Load and execute the review skill (`skills/wf-skill-review/SKILL.md`) — it defines the full process

On approval, pipeline advances. On rejection, pipeline returns to build phase.
