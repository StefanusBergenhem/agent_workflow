---
name: wf-command-strategist
description: "Product strategy session — structure unstructured input into a prioritized roadmap"
---

Start a product strategy session.

1. Load and execute the strategist skill (`skills/wf-skill-strategist/SKILL.md`)
2. Check for existing `roadmap.yaml` — if present, load for context
3. Check for `COMPONENTS.yaml` — if present, read for awareness (do NOT modify)
4. Engage the human in freeform product discussion
5. Help structure ideas into epics, features, priorities, and dependencies
6. Present the structured roadmap for approval
7. On approval, write `roadmap.yaml`

**This is a manual command** — invoke when you need to plan or refine the product direction. The output (`roadmap.yaml`) feeds into `/wf-command-sa`.
