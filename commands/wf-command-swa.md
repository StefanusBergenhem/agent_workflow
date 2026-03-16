---
name: wf-command-swa
description: "Software architecture session — detail next sprint from master backlog into sprint.yaml with full task contracts"
---

Start a software architecture session for the next sprint.

1. Load and execute the SwA skill (`skills/wf-skill-swa/SKILL.md`)
2. Read `master_backlog.yaml` — if not present, HALT and suggest running `/wf-command-sa` first
3. Read `COMPONENTS.yaml` — if not present, HALT and suggest running `/wf-command-sa` first
4. Find the next incomplete sprint in the master backlog
5. Read relevant `ARCHITECTURE.md` files for affected components
6. **Read actual source code** in affected component directories — verify interfaces, types, and code structure match architecture docs
7. Produce detailed task contracts for each backlog item:
   - Acceptance criteria, files_to_touch, context_to_load, testing_mandate
   - Split tasks that exceed sizing limits (3 files, 150 lines, 5 context files)
   - Validate component boundaries and dependency rules
8. Flag any design issues discovered to `design_issues.yaml`
9. Assemble `sprint.yaml` with all task contracts
10. Present sprint for approval (summary, per-task details, design issues, dependency graph)
11. On approval, write `sprint.yaml` (and `design_issues.yaml` if applicable)

**This is a manual command** — invoke after `/wf-command-sa` (or when you have a `master_backlog.yaml` and `COMPONENTS.yaml`). The output (`sprint.yaml`) is consumed by `/wf-command-pipeline`.
