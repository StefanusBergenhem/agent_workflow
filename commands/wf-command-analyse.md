---
name: wf-command-analyse
description: "[DEPRECATED] Use /wf-command-sa + /wf-command-swa instead"
---

> **DEPRECATED:** This command has been replaced by the layered architecture workflow:
> 1. `/wf-command-strategist` — Structure ideas into `roadmap.yaml`
> 2. `/wf-command-sa` — Translate roadmap into `master_backlog.yaml` + `COMPONENTS.yaml`
> 3. `/wf-command-swa` — Detail next sprint into `sprint.yaml` with full task contracts
>
> The old analyse skill is kept for backward compatibility but is no longer invoked by the pipeline.

Legacy usage (if needed):

1. Read `.workflow/config.yaml` for project paths
2. Read the roadmap, sprint, and state files specified in config
3. Follow the instructions in the `analyse` skill (skills/wf-skill-analyse/SKILL.md)
4. Present the sprint cut for human approval
5. On approval, write to the sprint file and update `.workflow/pipeline_state.yaml`
