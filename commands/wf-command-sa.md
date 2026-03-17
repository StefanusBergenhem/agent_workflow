---
name: wf-command-sa
description: "Solution architecture session — translate roadmap into technical strategy, component registry, and master backlog"
---

Start a solution architecture session.

1. Read `.workflow/config.yaml` for project paths
2. Load and execute the SA skill (`skills/wf-skill-sa/SKILL.md`) — it defines the full process
3. If `roadmap.yaml` is not present, HALT and suggest running `/wf-command-strategist` first

**This is a manual command** — invoke after `/wf-command-strategist` (or when you have a `roadmap.yaml`). The output feeds into `/wf-command-swa`.
