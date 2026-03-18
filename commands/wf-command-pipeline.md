---
name: wf-command-pipeline
description: "Run the automated pipeline — compute stages from sprint.yaml, build/review in parallel, run retrospective"
---

Run the automated build/review pipeline.

1. Read `.workflow/config.yaml` for project paths
2. Verify `sprint.yaml` exists — if not, HALT and suggest running `/wf-command-swa` first
3. Load and execute the orchestrate skill (`skills/wf-skill-orchestrate/SKILL.md`) — it defines the full state machine

The pipeline runs fully autonomously with no human approval gates: compute stages → plan worktrees → execute (build + review) → retrospective → publish. Error-path halts (merge conflicts, design issues, max-retry escalations) still pause for human intervention.
