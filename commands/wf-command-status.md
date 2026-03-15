---
name: wf-command-status
description: "Report current pipeline status — phase, active task, attempt count, blockers"
---

Read the workflow state and report a concise status summary.

1. Read `.workflow/pipeline_state.yaml` for current phase and metadata
2. Read `current_task.yaml` if it exists (active task details)
3. Read the sprint file (path from `.workflow/config.yaml`) for sprint progress
4. Read `feedback.yaml` if it exists (pending review feedback)
5. Read `review_ready.yaml` if it exists (pending review)
6. Read `.workflow/stage_manifest.yaml` if it exists (active stage details)

Report the following in a clear, structured format:

**Pipeline Status:**
- **Current phase:** analyse | plan_stage | build | review | idle | executing_stage | computing_stages
- **Active task:** step ID and title (or "None")
- **Sprint progress:** X of Y tasks complete
- **Stage progress:** Stage N of M (if parallel execution is active)
- **Per-task status:** For each task in the current stage, show: task ID, status (building/reviewing/completed/escalated), worktree path, attempt count
- **Blocked tasks:** Tasks in later stages blocked by escalated dependencies (or "None")
- **Attempt count:** N (if in build/review cycle)
- **Last action:** what happened most recently
- **Blockers:** any halt conditions or failures (or "None")
- **Worktree locations:** Active worktrees and their branches (if parallel execution is active)
- **Next step:** what command to run next

If no `.workflow/` directory exists, report that the project has not been initialized and suggest running `/wf-command-init`.
