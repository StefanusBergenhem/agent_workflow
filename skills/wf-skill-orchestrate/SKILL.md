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
| Sprint File | `sprint.yaml` (`paths.sprint` in config) | Task contracts produced by SwA |

---

## State Machine

### Pipeline Flow

```
idle → creating_sprint_branch → computing_stages → planning_worktrees →
  executing_stage → stage_complete →
    [more stages?] → planning_worktrees (next stage)
    [all done?] → retrospective → publishing → idle
```

Within `executing_stage` (parallel per task):
```
build → review → APPROVED → merge to sprint branch, mark completed
               → REJECTED → increment attempt_counter
                           → attempt_counter < max_attempts → build (Fix Mode)
                           → attempt_counter >= max_attempts → escalated
               → DESIGN_ISSUE → write to design_issues.yaml, halt task, continue others
```

### Valid States

| State | Description | Next Action |
|:------|:------------|:------------|
| `idle` | No active work or pipeline entry point. | Run resume detection. |
| `creating_sprint_branch` | Creating a dedicated branch for the sprint. | Create branch from main, record in state. See [GIT_OPERATIONS.md](GIT_OPERATIONS.md). |
| `computing_stages` | Computing dependency stages from sprint file tasks. | Run stage computation. |
| `planning_worktrees` | Creating git worktrees for all tasks in the current stage. | See [GIT_OPERATIONS.md](GIT_OPERATIONS.md). |
| `executing_stage` | Tasks in the current stage are building/reviewing in parallel worktrees. | Monitor task progress. |
| `stage_complete` | All tasks in stage are completed or escalated. | Check for next stage or retrospective. |
| `retrospective` | Running sprint retrospective analysis. | Spawn retrospective sub-agent. |
| `publishing` | Pushing sprint branch and creating pull request. | See [GIT_OPERATIONS.md](GIT_OPERATIONS.md). |
| `escalated` | Critical halt requiring human intervention. | Human intervention required. |

### Schemas

See [SCHEMAS.md](SCHEMAS.md) for `pipeline_state.yaml` schema and examples.

Key fields: `current_phase`, `sprint_branch`, `stages.definitions`, `task_states`, `blocked_tasks`, `design_issues`, `max_attempts`, `history`.

---

## Process

### Resume Detection

**Before acting on any `idle` state**, run resume detection:

1. Check if `sprint.yaml` (`paths.sprint` in config) exists.
2. If `sprint.yaml` exists and contains incomplete tasks (status != `done`):
   - Check if `sprint_branch` is set in `pipeline_state.yaml` — if not, transition to `creating_sprint_branch`.
   - Check if `.workflow/stage_manifest.yaml` exists → if yes, transition directly to `executing_stage` (worktrees are ready).
   - Check if `stages.definitions` is populated in `pipeline_state.yaml` → if yes, transition to `planning_worktrees`.
   - Otherwise → transition to `computing_stages` (sprint exists, stages not yet computed).
   - Update `pipeline_state.yaml` with the new phase and a `reason: "Resumed mid-sprint"` history entry.
3. If `sprint.yaml` does not exist → HALT. Tell the user to run `/wf-command-swa` to produce `sprint.yaml`.
4. If all tasks are complete → transition to `retrospective` (sprint done, retrospective pending).

**Metrics initialization:** If `config.observability.enabled` is true (default), create `.workflow/metrics/` directory if needed and initialize `.workflow/metrics/sprint-<sprint-id>.yaml` with sprint metadata and model config. If resuming mid-sprint and the metrics file already exists, do not overwrite. See `skills/wf-skill-observability/SKILL.md` for the initialization schema.

### Dispatch Protocol

See [DISPATCH.md](DISPATCH.md) for the full dispatch protocol, context envelopes, and per-phase file lists.

**Key principle:** Sub-agents get the minimum context needed. They do not get other skills' definitions, pipeline state details, or files outside their scope. Announce every state transition before dispatching.

**Model selection:** Read `models.<phase>` from `config.yaml` to determine the model for each sub-agent (build, review, retrospective). Pass this as the `model` parameter on the Agent tool call. If the key is missing, omit the parameter (inherits the parent's model). The orchestrator itself runs on opus; sub-agents use lighter models because task contracts constrain their work.

---

## Stage Computation

When transitioning to `computing_stages`:

1. **Read `sprint.yaml`** (`paths.sprint` in config). Collect all tasks with status `pending` or `blocked`, including their `depends_on` declarations.

2. **Build a dependency graph.** Each task is a node. Each `depends_on` is a directed edge.

3. **Detect cycles.** If a dependency cycle exists, HALT and report to the human. Do not attempt to break cycles.

4. **Topological sort into stages.** Group tasks into stages (layers) where:
   - Stage 1: all tasks with no dependencies (or dependencies already completed)
   - Stage N: all tasks whose dependencies are ALL satisfied by stages 1 through N-1
   - Tasks within a stage have no dependencies on each other — they are safe to run in parallel

5. **Handle blocked tasks.** Tasks with `status: "blocked"` in `sprint.yaml` (design issues from SwA) remain blocked. Skip them during stage computation and add to `blocked_tasks`.

6. **Write stage definitions** and **initialize task_states** in `pipeline_state.yaml` (see [SCHEMAS.md](SCHEMAS.md) for format).

7. **Transition to `planning_worktrees`** for stage 1.

---

## Worktree Planning

When in `planning_worktrees`:

1. Read the current stage's task list from `stages.definitions[current].tasks`.
2. **Filter out blocked tasks.** Check `blocked_tasks` and `design_issues` — skip any blocked tasks.
3. For each task in the stage:
   - Read the task contract from `sprint.yaml`
   - Create git worktree — see [GIT_OPERATIONS.md](GIT_OPERATIONS.md) for commands
   - Write `.workflow/current_task.yaml` in each worktree (extract the task's contract from `sprint.yaml` into the standard task contract format)
   - Run baseline preflight in each worktree
4. Write `.workflow/stage_manifest.yaml` listing all worktrees and contracts.
5. Update `task_states` with branch and worktree path for each task.
6. Transition to `executing_stage`.

---

## Stage Execution

When in `executing_stage`:

1. **Read `.workflow/stage_manifest.yaml`** for the list of tasks, worktrees, and contracts.

2. **Check parallel config.** Read `parallel.enabled` and `parallel.max_concurrent_tasks` from `config.yaml`.

3. **Dispatch tasks:**
   - **If parallel enabled:** Launch build sub-agents for all tasks in the stage simultaneously, each in its own worktree. Respect `max_concurrent_tasks` — if more tasks than the limit, batch them.
   - **If parallel disabled (sequential fallback):** Run tasks one at a time: build → review → merge for each task before starting the next.

4. **Monitor and update `task_states`** as each task progresses. Update `pipeline_state.yaml` after each task state change.

5. **On task completion (review approved):** Execute the merge protocol — see [GIT_OPERATIONS.md](GIT_OPERATIONS.md).

6. **On task escalation:** Mark the task as `escalated` in `task_states`. Run escalation propagation (see below). Other tasks in the current stage continue unaffected.

7. **On design issue:** When a build or review sub-agent writes to `design_issues.yaml` (`paths.design_issues` in config):
   - Mark the task as `design_issue` in `task_states`
   - Add entry to `design_issues` in `pipeline_state.yaml`
   - Do NOT retry — the issue is architectural, not code-level
   - Report the design issue to the human
   - Run escalation propagation for blocked dependents

8. **Stage is complete** when all tasks are either `completed`, `escalated`, or `design_issue`. Transition to `stage_complete`.

### Escalation Propagation

When a task is escalated, has a design issue, or has a merge conflict:

1. Mark the task appropriately in `task_states`.
2. **Scan all later stages** for tasks that `depends_on` the affected task.
3. Add those tasks to `blocked_tasks` with reason and `blocked_by` fields.
4. **Transitively block** — if task A is blocked and task B depends on A, B is also blocked.
5. Report the escalation and blocked tasks to the human.

### Stage Completion

When a stage reaches `stage_complete`:

1. **Clean up worktrees** — see [GIT_OPERATIONS.md](GIT_OPERATIONS.md).
2. **Post-merge validation.** After all approved tasks in the stage have merged to the sprint branch, run validation on the merged result:
   - Run `commands.test_unit` (if configured) on the sprint branch. Pipe output to `/tmp/pipeline-postmerge-stage-<N>.log 2>&1`.
   - Run `commands.lint` (if configured) on the sprint branch. Pipe output to `/tmp/pipeline-postmerge-lint-<N>.log 2>&1`.
   - **Commands used:** top-level `commands` from config (NOT domain-specific overrides). Post-merge validation tests the combined sprint branch across all domains.
   - If either fails: HALT. Report which tests/lint checks broke after merge (these passed in isolation but fail when combined). Escalate to human — this is a cross-task integration issue that cannot be auto-resolved.
   - If both pass: continue.
3. **Update the stage status** in `pipeline_state.yaml` to `completed`.
4. **Write stage summary** — follow the Context Hygiene Protocol (see below). Write compact `stage_summaries` entry to `pipeline_state.yaml`.
5. **Record stage metrics:** If `config.observability.enabled`, record `completed_at` and compute `duration_seconds` for this stage in `.workflow/metrics/sprint-<sprint-id>.yaml → stages.durations.<N>`.
6. **Check for next stage:**
   - If `stages.current < stages.total`: increment `stages.current`, transition to `planning_worktrees`.
   - If all stages complete: transition to `retrospective`.

---

## Context Hygiene Protocol

The orchestrator runs as a single invocation across all stages. To keep context usage manageable, follow these rules strictly.

### During Stage Execution

- Pipe all sub-agent output to `/tmp/pipeline-<sprint_id>-<task_id>.log`. Read only the outcome (APPROVED/REJECTED/DESIGN_ISSUE/ESCALATED), not the full output.
- Do not echo sub-agent diffs, test output, or review details — record only the status in `task_states`.
- When dispatching sub-agents, capture their full output in log files. Extract and retain only the verdict and any file paths needed for merge.

### At Stage Boundaries

After `stage_complete`, before proceeding to `planning_worktrees` for the next stage:

1. **Re-read this skill file** (`skills/wf-skill-orchestrate/SKILL.md`) from disk. This refreshes the orchestration instructions in the context window, protecting against compression discarding them during long-running sprints.
2. Write a compact stage summary to `pipeline_state.yaml` under `stage_summaries`:
   ```yaml
   stage_summaries:
     1:
       completed: ["S1.1", "S1.2"]
       escalated: ["S1.3"]
       design_issues: []
       merged_branches: ["s1.1-add-parser", "s1.2-update-config"]
   ```
3. This summary is the **only** record needed for subsequent stages. All prior dispatch details, sub-agent outputs, and intermediate states are no longer needed.
4. Announce: "Stage N complete. Summary written to pipeline_state.yaml. Proceeding to stage N+1."

### Hard Rules

- Never reference build/review details from a prior stage when executing the current stage.
- Never re-read sub-agent log files from prior stages.
- The stage summary in `pipeline_state.yaml` is the single source of truth for completed stages.

---

## Retrospective Phase

When all stages are complete (or all remaining tasks are blocked/escalated):

1. **Finalize metrics:** If `config.observability.enabled`, compute summary aggregates in `.workflow/metrics/sprint-<sprint-id>.yaml` — tasks_planned, tasks_completed, first_attempt_pass_rate, avg_attempts, longest_task, rejection_type_counts. Set `completed_at` and compute `duration_minutes`. See `skills/wf-skill-observability/SKILL.md § Metrics Finalization` for the full computation.
2. Transition to `retrospective`.
3. Spawn the retrospective sub-agent with its context envelope (includes metrics files — see [DISPATCH.md](DISPATCH.md)).
4. The retrospective skill produces `retrospective/<sprint-id>.md`.
5. **Append trends:** If `config.observability.enabled`, append a summary entry to `.workflow/metrics/trends.yaml`. Trim to `config.observability.trends.max_sprints` entries if exceeded. See `skills/wf-skill-observability/SKILL.md § Trends Append` for the schema.
6. **Continuous learning:** If `config.learning.enabled` is true (default), invoke the continuous-learning skill to extract lessons, enforce memory capacity, and archive retrospective documents. If `learning.enabled` is false, skip this step.
7. On completion, transition to `publishing`. See [GIT_OPERATIONS.md](GIT_OPERATIONS.md) for the publishing protocol.

---

## Gate Handling

### Automatic Gates

1. **Build → Review.** When build completes with `review_ready.yaml`, proceed to review.
2. **Review → Build (rejection).** When review produces `feedback.yaml`, increment `attempt_counter` and re-enter build in Fix Mode. Escalate when `attempt_counter >= max_attempts` (read from `review.max_attempts` in config, default: 3).
3. **Review → Merge (approval).** When review approves, execute merge protocol.
4. **Stage Complete → Next Stage.** When all tasks resolved, proceed to next stage.
5. **All Stages Complete → Retrospective.** Automatic, no human gate.
6. **Retrospective → Publishing.** Automatic, no human gate.

---

## Error Handling

| Scenario | Action |
|:---------|:-------|
| Sub-agent HALTs | Read halt reason. Present to human. Mark task as `escalated`. Other tasks continue. |
| State file missing | Create with `current_phase: idle`. |
| State file corrupted | HALT. Present to human. Do not guess. |
| Config file missing | HALT. Cannot resolve paths without config. |
| `sprint.yaml` missing | HALT. Tell user to run `/wf-command-swa`. |
| Sub-agent output missing | Report to human. Do not retry automatically. |
| Git conflicts during merge | Abort merge. Escalate to human. Do not auto-resolve. |
| Worktree creation fails | HALT for that task. Other tasks continue. |
| Dependency cycle detected | HALT. Report cycle to human. |
| `design_issues.yaml` written | Mark task as design_issue. Block dependents. Notify human. |
| Sprint branch creation fails | HALT. Ask human whether to reuse or rename. |
| PR creation fails | HALT. Report to human (e.g., `gh` not authenticated). |

---

## Hard Constraints

- **Thin controller.** Never perform analysis, planning, building, or reviewing. Only manage state transitions and context assembly.
- **Minimal context.** Each sub-agent gets ONLY its SKILL.md + required state files + context_to_load.
- **State is persistent.** All state lives in `pipeline_state.yaml`. The orchestrator is stateless between dispatches.
- **Automatic gates are mandatory and cannot be overridden.** Error-path escalations (merge conflicts, design issues, max-retry) require human intervention.
- **Max 3 build-review loops per task.** Escalate on the 4th attempt.
- **Design issues halt tasks.** Never retry a task with a design issue. Requires architect intervention.
- **Append-only history.** Never delete or modify history entries in `pipeline_state.yaml`.
- **Context hygiene is mandatory.** Sub-agent output goes to /tmp log files, not inline. At stage boundaries, write a compact stage summary and do not reference prior stage details.
- **No auto-conflict resolution.** Merge conflicts always escalate to the human.
- **Escalation does not block the stage.** Other tasks continue. Only dependents in later stages are blocked.
- **Worktree cleanup is mandatory.** Never leave orphaned worktrees.
- **Retrospective is mandatory.** Every completed sprint gets a retrospective.
- **Sprint branch is mandatory.** All work happens on a sprint branch, never directly on main.
- **Publishing is mandatory.** Every sprint must push and create a PR. Pipeline is not done until the PR URL is reported.
