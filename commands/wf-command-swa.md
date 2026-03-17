---
name: wf-command-swa
description: "Software architecture session — detail next sprint from master backlog into sprint.yaml with full task contracts"
---

Start a software architecture session for the next sprint.

1. Read `.workflow/config.yaml` for project paths
2. Verify `master_backlog.yaml` and `COMPONENTS.yaml` exist — if not, HALT and suggest running `/wf-command-sa` first
3. Load and execute the SwA skill (`skills/wf-skill-swa/SKILL.md`) — it defines the full process

**This is a manual command** — invoke after `/wf-command-sa` (or when you have a `master_backlog.yaml` and `COMPONENTS.yaml`). The output (`sprint.yaml`) is consumed by `/wf-command-pipeline`.
