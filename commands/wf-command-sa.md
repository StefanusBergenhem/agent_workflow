---
name: wf-command-sa
description: "Solution architecture session — evaluate system health, update COMPONENTS.yaml, and plan next sprint (with or without roadmap)"
---

Start a solution architecture session.

1. Read `.workflow/config.yaml` for project paths
2. Load and execute the SA skill (`skills/wf-skill-sa/SKILL.md`) — it defines the full process
3. The SA skill supports two modes:
   - **Roadmap mode:** When `roadmap.yaml` is present — translates roadmap into `COMPONENTS.yaml` and `master_backlog.yaml`
   - **Ongoing mode:** When only `master_backlog.yaml` is present — evaluates system health, updates `COMPONENTS.yaml`, cuts next sprint

**This is a manual command** — invoke after `/wf-command-strategist` (roadmap mode) or whenever you need to reassess architecture and cut the next sprint (ongoing mode). The output feeds into `/wf-command-swa`.
