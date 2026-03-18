# Pipeline State Schema

## pipeline_state.yaml

```yaml
# .workflow/pipeline_state.yaml
current_phase: "idle"
# Valid: idle | creating_sprint_branch | computing_stages | planning_worktrees |
#        awaiting_stage_approval | executing_stage | stage_complete |
#        retrospective | publishing | escalated

sprint_id: ""                    # Set from sprint.yaml
sprint_branch: ""                # Set during creating_sprint_branch (e.g., "sprint/S1")

stages:
  total: 0                       # Total number of stages
  current: 0                     # Current stage number (1-indexed)
  definitions:
    # Populated during computing_stages. Each stage is a group of independent tasks.
    # 1: { tasks: ["S1.1", "S1.2"], status: pending }
    # 2: { tasks: ["S1.3", "S1.4", "S1.5"], status: pending }
    # 3: { tasks: ["S1.6"], status: pending }

task_states:
  # Per-task state tracking, populated during stage execution.
  # "S1.1": { status: pending, branch: "", worktree_path: "", attempt_counter: 0 }
  # Status: pending | building | reviewing | completed | escalated | blocked | design_issue

blocked_tasks:
  # Tasks in later stages blocked by escalated dependencies.
  # "S1.6": { reason: "depends_on S1.5 which is escalated", blocked_by: "S1.5" }

design_issues:
  # Tasks halted due to design-level problems.
  # "S1.3": { issue_id: "DI-001", summary: "Auth/DB boundary violation" }

max_attempts: 3                  # Escalate when attempt_counter >= max_attempts

last_transition:
  from: ""
  to: ""
  timestamp: ""
  reason: ""

history:
  # Append-only log of state transitions
  - from: "idle"
    to: "computing_stages"
    timestamp: "YYYY-MM-DDTHH:MM:SS"
    reason: "Pipeline started by user"
```

## Stage Definitions Example

After `computing_stages` completes:

```yaml
stages:
  total: 3
  current: 1
  definitions:
    1: { tasks: ["S1.1", "S1.2"], status: pending }
    2: { tasks: ["S1.3", "S1.4", "S1.5"], status: pending }
    3: { tasks: ["S1.6"], status: pending }

task_states:
  "S1.1": { status: pending, branch: "", worktree_path: "", attempt_counter: 0 }
  "S1.2": { status: pending, branch: "", worktree_path: "", attempt_counter: 0 }
```
