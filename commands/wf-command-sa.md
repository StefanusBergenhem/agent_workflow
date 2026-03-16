---
name: wf-command-sa
description: "Solution architecture session — translate roadmap into technical strategy, component registry, and master backlog"
---

Start a solution architecture session.

1. Load and execute the SA skill (`skills/wf-skill-sa/SKILL.md`)
2. Read `roadmap.yaml` — if not present, HALT and suggest running `/wf-command-strategist` first
3. Read `COMPONENTS.yaml` and all `ARCHITECTURE.md` files (if they exist)
4. Read `master_backlog.yaml` (if exists) for continuity
5. Run architecture health checks:
   - Component size (files, exports vs constraints)
   - Dependency direction violations
   - Responsibility overlap
   - Duplication detection
6. Present health findings to the human
7. Make technical design decisions for roadmap features
8. Update `COMPONENTS.yaml` with new/modified component definitions
9. Update/create per-module `ARCHITECTURE.md` files
10. Build `master_backlog.yaml` with sprint groupings
11. Present all artifacts for approval
12. On approval, write all artifacts

**This is a manual command** — invoke after `/wf-command-strategist` (or when you have a `roadmap.yaml`). The output feeds into `/wf-command-swa`.
