---
description: "Report current pipeline status — phase, active task, attempt count, blockers"
---

Read the workflow state and report a concise status summary.

1. Read `.workflow/pipeline_state.yaml` for current phase and metadata
2. Read `current_task.yaml` if it exists (active task details)
3. Read the sprint file (path from `.workflow/config.yaml`) for sprint progress
4. Read `feedback.yaml` if it exists (pending review feedback)
5. Read `review_ready.yaml` if it exists (pending review)

Report the following in a clear, structured format:

**Pipeline Status:**
- **Current phase:** analyse | plan | build | review | idle
- **Active task:** step ID and title (or "None")
- **Sprint progress:** X of Y tasks complete
- **Attempt count:** N (if in build/review cycle)
- **Last action:** what happened most recently
- **Blockers:** any halt conditions or failures (or "None")
- **Next step:** what command to run next

If no `.workflow/` directory exists, report that the project has not been initialized and suggest running `/init`.
