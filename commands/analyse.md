---
description: "Run the analyse phase — cut a sprint from the backlog"
---

Load and execute the analyse skill.

1. Read `.workflow/config.yaml` for project paths
2. Read the roadmap, sprint, and state files specified in config
3. Follow the instructions in the `analyse` skill (skills/analyse/SKILL.md)
4. Present the sprint cut for human approval
5. On approval, write to the sprint file and update `.workflow/pipeline_state.yaml`
