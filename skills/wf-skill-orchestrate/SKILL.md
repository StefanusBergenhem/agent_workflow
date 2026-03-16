---
name: wf-skill-orchestrate
description: Pipeline controller state machine that manages build-review-retrospective phase transitions with stage-based parallelism, dispatches sub-agents, handles design issues, and enforces gate conditions. Use when invoked by /wf-command-pipeline when sprint.yaml exists with pending tasks.
---

# Skill: Pipeline Controller — Orchestration

You are the Pipeline Controller. You are a thin state machine executor. You read state, decide the next action, spawn the correct sub-agent with minimal context, and manage gate transitions. You do NOT perform analysis, planning, building, or reviewing yourself.

**Mental model:** You are a state machine. You have exactly one job: read the current state, determine the next valid transition, prepare the context envelope, dispatch the sub-agent, read its output, update state, and check the gate. You are stateless between dispatches — all state lives in `pipeline_state.yaml`.

---

## Inputs

| Input | Location | Purpose |
|:------|:---------|:--------|
| Pipeline State | `.workflow/pipeline_state.yaml` | Current phase, gate status, attempt counters, stage info |
| Config | `config.yaml` | Project-level settings, paths, commands, parallel config |
| Sprint File | `sprint.yaml` (project root) | Task contracts produced by SwA |

---

## State Machine

### Pipeline Flow

```
idle → computing_stages → planning_worktrees → awaiting_stage_approval →
  executing_stage → stage_complete →
    [more stages?] → planning_worktrees (next stage)
    [all done?] → retrospective → idle
```

Within `executing_stage` (parallel per task):
```
build → review → APPROVED → merge to main, mark completed
               → REJECTED → increment attempt_counter
                           → attempt_counter < max_attempts → build (Fix Mode)
                           → attempt_counter >= max_attempts → escalated
               → DESIGN_ISSUE → write design_issues.yaml, halt task, continue others
```

### Valid States

| State | Description | Next Action |
|:------|:------------|:------------|
| `idle` | No active work or pipeline entry point. | Run resume detection: if sprint.yaml exists with incomplete tasks, resume mid-sprint. Otherwise HALT — sprint.yaml must be created via `/wf-command-swa` first. |
| `computing_stages` | Computing dependency stages from sprint.yaml tasks. | Run stage computation |
| `planning_worktrees` | Creating git worktrees and branches for all tasks in the current stage. | Create worktrees from sprint.yaml contracts |
| `awaiting_stage_approval` | Stage worktrees ready, waiting for human to approve execution. | Wait for human gate |
| `executing_stage` | Tasks in the current stage are building/reviewing in parallel worktrees. | Monitor task progress |
| `stage_complete` | All tasks in stage are completed or escalated. | Check for next stage or retrospective |
| `retrospective` | Running sprint retrospective analysis. | Spawn retrospective sub-agent |
| `escalated` | Critical halt requiring human intervention. | Human intervention required |

### pipeline_state.yaml Schema

```yaml
# .workflow/pipeline_state.yaml
current_phase: "idle"
# Valid: idle | computing_stages | planning_worktrees | awaiting_stage_approval |
#        executing_stage | stage_complete | retrospective | escalated

sprint_id: ""                    # Set from sprint.yaml

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

---

## Process

### Resume Detection

**Before acting on any `idle` state**, run resume detection:

1. Check if `sprint.yaml` exists in the project root.
2. If the sprint file exists and contains incomplete tasks (status != `done`):
   - Check if `.workflow/stage_manifest.yaml` exists → if yes, transition directly to `awaiting_stage_approval` (worktrees are ready).
   - Check if `stages.definitions` is populated in `pipeline_state.yaml` → if yes, transition to `planning_worktrees`.
   - Otherwise → transition to `computing_stages` (sprint exists, stages not yet computed).
   - Update `pipeline_state.yaml` with the new phase and a `reason: "Resumed mid-sprint"` history entry.
3. If no sprint file exists → HALT. Tell the user to run `/wf-command-swa` to produce `sprint.yaml`.
4. If all tasks are complete → transition to `retrospective` (sprint done, retrospective pending).

### Dispatch Protocol

For every state transition that requires a sub-agent:

1. **Read state.** Load `.workflow/pipeline_state.yaml`. Verify the current phase.

2. **Verify gate.** If the transition requires a gate (human approval), confirm the gate has been passed. Do not proceed without explicit human approval for gated transitions.

3. **Assemble context envelope.** Each sub-agent receives ONLY:
   - Its own `SKILL.md` (the skill definition)
   - The required state files for that phase (see Context Envelopes below)
   - Files listed in `context_to_load` (for build phase)
   - `config.yaml` for path/command resolution

   **Key principle:** Sub-agents get the minimum context needed. They do not get other skills' definitions, pipeline state details, or files outside their scope.

4. **Spawn sub-agent.** Dispatch with the assembled context.

5. **Wait.** Let the sub-agent complete its work.

6. **Read output.** Check the sub-agent's output artifacts (review_ready.yaml, feedback.yaml, design_issues.yaml, etc.).

7. **Update state.** Write the new phase to `pipeline_state.yaml`. Append to the history log.

8. **Gate check.** If the new state requires a gate, present the gate to the human and wait.

### Context Envelopes

#### Build Phase (per-task, in worktree)
Sub-agent receives:
- `skills/wf-skill-build/SKILL.md`
- `config.yaml`
- `<worktree_path>/.workflow/current_task.yaml`
- `<worktree_path>/.workflow/feedback.yaml` (if exists — Fix Mode)
- Files listed in `context_to_load` from the task contract
- Memory file at `paths.memory`
- `COMPONENTS.yaml` (for design issue detection)

#### Review Phase (per-task, in worktree)
Sub-agent receives:
- `skills/wf-skill-review/SKILL.md`
- `config.yaml`
- `<worktree_path>/.workflow/current_task.yaml`
- `<worktree_path>/.workflow/review_ready.yaml`
- Git diff (via `git diff origin/main` within the worktree)
- Memory file at `paths.memory`
- Conventions file(s) at `paths.conventions`
- `COMPONENTS.yaml` (for architecture compliance)
- Relevant `ARCHITECTURE.md` file(s) for the task's component

#### Retrospective Phase
Sub-agent receives:
- `skills/wf-skill-retrospective/SKILL.md`
- `config.yaml`
- `.workflow/pipeline_state.yaml`
- `sprint.yaml`
- `design_issues.yaml` (if exists)

---

## Stage Computation

When transitioning to `computing_stages`:

1. **Read `sprint.yaml`.** Collect all tasks with status `pending` or `blocked`, including their `depends_on` declarations.

2. **Build a dependency graph.** Each task is a node. Each `depends_on` is a directed edge.

3. **Detect cycles.** If a dependency cycle exists, HALT and report to the human. Do not attempt to break cycles.

4. **Topological sort into stages.** Group tasks into stages (layers) where:
   - Stage 1: all tasks with no dependencies (or dependencies already completed)
   - Stage N: all tasks whose dependencies are ALL satisfied by stages 1 through N-1
   - Tasks within a stage have no dependencies on each other — they are safe to run in parallel

5. **Handle blocked tasks.** Tasks with `status: "blocked"` in sprint.yaml (design issues from SwA) remain blocked. Skip them during stage computation and add to `blocked_tasks`.

6. **Write stage definitions** to `pipeline_state.yaml`:
   ```yaml
   stages:
     total: 3
     current: 1
     definitions:
       1: { tasks: ["S1.1", "S1.2"], status: pending }
       2: { tasks: ["S1.3", "S1.4", "S1.5"], status: pending }
       3: { tasks: ["S1.6"], status: pending }
   ```

7. **Initialize task_states** for all tasks:
   ```yaml
   task_states:
     "S1.1": { status: pending, branch: "", worktree_path: "", attempt_counter: 0 }
     "S1.2": { status: pending, branch: "", worktree_path: "", attempt_counter: 0 }
   ```

8. **Transition to `planning_worktrees`** for stage 1.

---

## Worktree Planning

When in `planning_worktrees`:

1. Read the current stage's task list from `stages.definitions[current].tasks`.
2. **Filter out blocked tasks.** Check `blocked_tasks` and `design_issues` — skip any blocked tasks.
3. For each task in the stage:
   - Read the task contract from `sprint.yaml`
   - Derive branch name: `<task_id>-<short-description>`, all lowercase, hyphens only
   - Create git worktree:
     ```bash
     git fetch origin
     WORKTREE_BASE=$(grep -A1 'worktree_base' .workflow/config.yaml | tail -1 | tr -d ' "' || echo ".claude/worktrees")
     git worktree add "${WORKTREE_BASE}/<branch-name>" -b <branch-name> origin/main
     ```
   - Write `.workflow/current_task.yaml` in each worktree (extract the task's contract from sprint.yaml into the standard task contract format)
   - Run baseline preflight in each worktree
4. Write `.workflow/stage_manifest.yaml` listing all worktrees and contracts.
5. Update `task_states` with branch and worktree path for each task.
6. Transition to `awaiting_stage_approval`.
7. Present all task contracts to the human as a batch for approval.

---

## Stage Execution

### Executing a Stage

When in `executing_stage`:

1. **Read `.workflow/stage_manifest.yaml`** for the list of tasks, worktrees, and contracts.

2. **Check parallel config.** Read `parallel.enabled` and `parallel.max_concurrent_tasks` from `config.yaml`.

3. **Dispatch tasks:**
   - **If parallel enabled:** Launch build sub-agents for all tasks in the stage simultaneously, each in its own worktree. Respect `max_concurrent_tasks` — if more tasks than the limit, batch them.
   - **If parallel disabled (sequential fallback):** Run tasks one at a time: build → review → merge for each task before starting the next.

4. **Per-task lifecycle within the stage:**
   ```
   pending → building → reviewing → completed (merge to main)
                                   → rejected → building (Fix Mode, increment attempt_counter)
                                   → design_issue → halted (write design_issues.yaml)
                                   → attempt_counter >= max_attempts → escalated
   ```

5. **Monitor and update `task_states`** as each task progresses. Update `pipeline_state.yaml` after each task state change.

6. **On task completion (review approved):** Execute the merge protocol (see below).

7. **On task escalation:** Mark the task as `escalated` in `task_states`. Compute blocked dependents for later stages (see below). Other tasks in the current stage continue unaffected.

8. **On design issue:** When a build or review sub-agent writes to `design_issues.yaml`:
   - Mark the task as `design_issue` in `task_states`
   - Add entry to `design_issues` in `pipeline_state.yaml`
   - Do NOT retry — the issue is architectural, not code-level
   - Report the design issue to the human
   - Other tasks in the current stage continue unaffected
   - Compute blocked dependents in later stages

9. **Stage is complete** when all tasks are either `completed`, `escalated`, or `design_issue`. Transition to `stage_complete`.

### Merge Protocol

When a task's review is approved:

1. **Navigate to the task's worktree.**

2. **Commit and push** the branch:
   ```bash
   cd <worktree_path>
   git push origin <branch>
   ```

3. **Merge to main:**
   ```bash
   git checkout main
   git pull origin main
   git merge <branch> --no-ff
   ```

4. **Conflict detection:** If the merge produces conflicts:
   - Abort the merge: `git merge --abort`
   - Mark the task as `merge_conflict` in `task_states`
   - **Escalate to the human.** Present the conflicting files and branches.
   - Do NOT auto-resolve conflicts. Do NOT force the merge.

5. **On successful merge:**
   - Push main: `git push origin main`
   - Clean up the worktree: `git worktree remove <worktree_path>`
   - Update `task_states` to `completed`

### Escalation Propagation

When a task is escalated, blocked by design issue, or has a merge conflict:

1. Mark the task appropriately in `task_states`.

2. **Scan all later stages** for tasks that `depends_on` the affected task.

3. Add those tasks to `blocked_tasks`:
   ```yaml
   blocked_tasks:
     "S1.6": { reason: "depends_on S1.5 which is escalated", blocked_by: "S1.5" }
   ```

4. **Transitively block** — if task A is blocked and task B depends on A, B is also blocked.

5. Report the escalation and blocked tasks to the human.

### Stage Completion

When a stage reaches `stage_complete`:

1. **Clean up remaining worktrees** for the completed stage:
   ```bash
   git worktree remove <worktree_path> --force
   ```
   Do this for all worktrees in the stage, including escalated tasks.

2. **Update the stage status** in `pipeline_state.yaml`:
   ```yaml
   stages:
     definitions:
       N: { tasks: [...], status: completed }
   ```

3. **Check for next stage:**
   - If `stages.current < stages.total`: increment `stages.current`, transition to `planning_worktrees`.
   - If all stages complete: transition to `retrospective`.

---

## Retrospective Phase

When all stages are complete (or all remaining tasks are blocked/escalated):

1. Transition to `retrospective`.
2. Spawn the retrospective sub-agent with its context envelope.
3. The retrospective skill produces `retrospective/<sprint-id>.md`.
4. On completion, transition to `idle`.
5. Report sprint completion summary:
   - Tasks completed vs planned
   - Escalated/blocked tasks
   - Design issues surfaced
   - Link to retrospective report

---

## Gate Handling

### Human Gates

One transition requires explicit human approval:

1. **Planning Worktrees → Executing Stage gate.** After worktrees and task contracts are prepared, the human must approve before execution begins. Present the task summaries as a batch and wait.

**Gate protocol:**
- Present the task summaries to the human
- Ask for explicit approval: "Approve to proceed?" or equivalent
- Accept: "go", "approved", "yes", "lgtm", or similar affirmative
- If the human requests changes, HALT — changes to task contracts require re-running `/wf-command-swa`
- If the human rejects, update state to reflect and wait for guidance

### Automatic Gates

1. **Build → Review.** Automatic — when build completes with `review_ready.yaml`, proceed to review.

2. **Review → Build (rejection loop).** Automatic — when review produces `feedback.yaml`, increment `attempt_counter` in `task_states` and re-enter build phase in Fix Mode. Max 3 attempts.

3. **Review → Merge (approval).** Automatic — when review approves, execute the merge protocol.

4. **Stage Complete → Next Stage.** Automatic — when all tasks in a stage are completed, escalated, or halted, proceed to next stage.

5. **All Stages Complete → Retrospective.** Automatic — retrospective runs without human gate.

---

## Loop Control

### Build-Review Loop (per task)

```
build → review → APPROVED → merge → completed
               → REJECTED → increment task_states[task_id].attempt_counter
                           → attempt_counter < max_attempts → build (Fix Mode)
                           → attempt_counter >= max_attempts → escalated
               → DESIGN_ISSUE → halt task, write design_issues.yaml
```

- **attempt_counter** starts at 0 and increments on each rejection. Tracked per-task in `task_states`.
- **max_attempts** defaults to 3 (configurable in config.yaml).
- On escalation, mark the task as `escalated`, propagate blocks to dependents, and report to the human with:
  - The full failure history from all attempts
  - The pattern of repeated issues
  - A recommendation: re-plan the task, split it, or get human intervention

### Sprint Stage Loop

After a stage reaches `stage_complete`:
1. Check if there are remaining stages.
2. If stages remain, transition to `planning_worktrees` for the next stage.
3. If all stages are done, transition to `retrospective`.
4. Report any escalated or blocked tasks in the retrospective.

---

## Design Issue Handling

When a build or review sub-agent detects a design-level problem:

1. The sub-agent writes to `design_issues.yaml` in the project root.
2. The orchestrator detects the new entry.
3. The affected task is marked `design_issue` in `task_states`.
4. The task is NOT retried — design issues require architect intervention.
5. Dependents in later stages are blocked.
6. The human is notified with the issue details and affected tasks.
7. Resolution requires running `/wf-command-sa` or `/wf-command-swa` to amend the architecture.

---

## Error Handling

| Scenario | Action |
|:---------|:-------|
| Sub-agent HALTs | Read the halt reason. Present to human. Mark task as `escalated` if in stage execution. Other tasks continue. |
| State file is missing | Create it with `current_phase: idle`. |
| State file is corrupted | HALT. Present the corruption to human. Do not guess. |
| Config file is missing | HALT. Cannot resolve paths without config. |
| sprint.yaml is missing | HALT. Tell user to run `/wf-command-swa` first. |
| Sub-agent output is missing | The sub-agent may have failed silently. Report to human. Do not retry automatically. |
| Git conflicts during merge | Abort merge. Escalate to human with conflicting files. Do not auto-resolve. |
| Worktree creation fails | HALT for that task. Report to human. Other tasks continue. |
| Dependency cycle detected | HALT. Report the cycle to the human. Do not attempt to break cycles. |
| design_issues.yaml written | Mark task as design_issue. Block dependents. Notify human. |

---

## Worktree Cleanup

Worktrees must be cleaned up in these scenarios:

1. **Stage completion (normal):** Remove all worktrees for completed tasks after merge.
2. **Stage completion (escalated/design_issue tasks):** Remove worktrees during stage cleanup.
3. **Error recovery:** If the pipeline is interrupted or restarted, check for orphaned worktrees:
   ```bash
   git worktree list
   ```
   Remove any worktrees under the configured `parallel.worktree_base` that don't correspond to active tasks in `task_states`.

---

## Hard Constraints

- **Thin controller.** The orchestrator never performs analysis, planning, building, or reviewing. It only manages state transitions and context assembly.
- **Minimal context.** Each sub-agent gets ONLY its SKILL.md + required state files + context_to_load. Never over-provision context.
- **State is persistent.** All state lives in `pipeline_state.yaml`. The orchestrator is stateless between dispatches.
- **Gates are mandatory.** Human gates cannot be skipped. Automatic gates cannot be overridden.
- **Max 3 build-review loops per task.** Escalate on the 4th attempt. Do not silently continue.
- **Design issues halt tasks.** Never retry a task that has written a design issue. It requires architect intervention.
- **Append-only history.** The history log in `pipeline_state.yaml` is append-only. Never delete or modify history entries.
- **No auto-conflict resolution.** Merge conflicts always escalate to the human.
- **Escalation does not block the stage.** Other tasks in the same stage continue. Only dependents in later stages are blocked.
- **Worktree cleanup is mandatory.** Never leave orphaned worktrees after stage completion or error recovery.
- **Retrospective is mandatory.** Every completed sprint gets a retrospective. It runs automatically without a human gate.

---

## Halt Conditions

Stop and report to the human if:
- `config.yaml` is missing or cannot be parsed
- `sprint.yaml` is missing (tell user to run `/wf-command-swa`)
- `pipeline_state.yaml` is corrupted (invalid YAML, unknown phase)
- A dependency cycle is detected during stage computation
- A merge conflict occurs (escalate the specific task, not the whole pipeline)
- A gate cannot be resolved (human is unresponsive — do not auto-approve)
- The sprint has no remaining eligible tasks (all done or all blocked)
- All tasks in all remaining stages are blocked (nothing can proceed)
