# Workflow Guide

This is the practical guide to using the workflow system. It covers installation, daily usage, and what to do when things go wrong.

---

## Installation

### 1. Install the toolkit

```bash
cd ~/repos/Claude_code_workflow
./install.sh
```

This symlinks skills and commands into `~/.claude/`, installs hooks into `~/.claude/settings.json`, and appends global rules to `~/.claude/CLAUDE.md`. Safe to re-run.

### 2. Bootstrap a project

In any project directory:

```
/init
```

This creates:
- `.workflow/config.yaml` — project settings (language, test commands, paths)
- `.workflow/pipeline_state.yaml` — pipeline state tracker
- `.workflow/` added to `.gitignore`

Review and customize `.workflow/config.yaml` — especially the `commands` and `paths` sections.

### 3. Create your docs

The workflow expects these files to exist (paths configurable in `config.yaml`):

| File | Purpose |
|:-----|:--------|
| `docs/ROADMAP.md` | Feature backlog — what needs to be built |
| `docs/SPRINT.md` | Current sprint — tasks being worked on |
| `docs/STATE.md` | System state — known issues, deferred items |
| `docs/CONVENTIONS.md` | Coding standards and patterns |
| `docs/ARCHITECTURE.md` | Domain model, ADRs, constraints |

---

## The Pipeline

The pipeline uses **stage-based parallelism**: tasks are grouped into dependency stages via topological sort, tasks within a stage run in parallel (in separate git worktrees), and stages execute serially.

```
/analyse → approve sprint → compute stages →
  plan stage → approve stage → execute stage (parallel builds + reviews) →
    [more stages?] → plan next stage →
    [all done?] → idle
```

Within each stage execution (parallel per task):
```
Each task: build → review → approve → merge to main
                          → reject  → retry build (max 3x, then escalate)
```

### Running the full pipeline

```
/pipeline
```

This starts the orchestrator, which:
1. Runs `/analyse` to cut a sprint, then pauses for your approval
2. Computes dependency stages (topological sort of sprint tasks)
3. For each stage: plans all tasks as a batch, pauses for your approval, then executes all tasks in parallel
4. Approved tasks merge to main immediately; rejected tasks retry up to 3 times

### Running phases individually

You can also run each phase manually:

```
/analyse    # Cut a sprint from the backlog
/plan       # Create task contracts for the current stage
/build      # Execute a task contract (TDD)
/review     # Validate the build against the contract
```

This is useful when you want more control, or when resuming after an interruption.

### Checking status

```
/status
```

Reports: current phase, stage progress (N of M), per-task status within the active stage (building/reviewing/completed/escalated), blocked tasks, worktree locations, and next action.

---

## Phase Details

### /analyse — Sprint Cutting

**What it does:** Reads your roadmap and current state, then proposes a sprint cut — a set of sized, ordered, dependency-aware tasks.

**You'll be asked to approve** the sprint before anything is written.

**What to look for:**
- Are tasks sized correctly? (max 3 files, max 150 lines each)
- Are dependencies explicit and ordered correctly?
- Are high-risk tasks scheduled early?
- Is anything missing from the backlog?

**Output:** Sprint written to your sprint file.

### /plan — Task Contracts (Stage Mode)

**What it does:** Takes all tasks in the current dependency stage and produces task contracts for each — files to touch, files to read for context, acceptance criteria, and a testing mandate. Creates one git worktree per task.

**You'll be asked to approve** all contracts for the stage as a batch before execution begins.

**What to look for:**
- Are the right files in `context_to_load`? (max 5 per task)
- Are the right files in `files_to_touch`? (max 3 per task)
- Are acceptance criteria clear and testable?
- Is the testing mandate complete (happy path, edge cases, error paths)?
- Are `out_of_scope` boundaries clear?
- Are blocked tasks (from escalated dependencies) correctly excluded?

**Output:** `.workflow/stage_manifest.yaml` (listing all worktrees and contracts) + one `.workflow/current_task.yaml` per worktree + feature branches created.

### /build — TDD Execution

**What it does:** Executes the task contract using strict TDD:
1. Writes tests first, confirms they FAIL (red phase)
2. Implements code to make tests pass (green phase)
3. Refactors (refactor phase)
4. Runs preflight, writes completion claim

**Runs automatically** — no approval gate. Proceeds directly to review. During stage execution, each build runs in its own git worktree.

**Two modes:**
- **Build mode** — fresh implementation from the contract
- **Fix mode** — activated when `feedback.yaml` exists from a prior review rejection. Addresses only the listed failures.

**Output:** Code changes + `<worktree>/.workflow/review_ready.yaml`.

### /review — QA Validation

**What it does:** Adversarial review of the build against the contract. Checks (in priority order):

| Priority | Checks |
|:---------|:-------|
| P0 (critical) | Security scan, scope audit, acceptance criteria |
| P1 (tests) | Test existence, test quality, TDD evidence, suppression scan |
| P2 (quality) | Documentation, conventions, clean code |
| P3 (integration) | Independent preflight run |

**Runs automatically** after build.

**On approval:** Pushes the branch, merges to main (with conflict detection), cleans up the worktree, and updates sprint status.

**On rejection:** Writes `.workflow/feedback.yaml` with specific failures. Build re-runs in fix mode. Max 3 attempts per task before escalating. Other tasks in the stage continue unaffected.

---

## Hooks — Mechanical Enforcement

Hooks run automatically during Claude's work. You don't invoke them — they fire on tool use events.

| Hook | Triggers on | What it catches |
|:-----|:------------|:----------------|
| `post-build-scope-audit.sh` | Every Edit/Write | Files modified outside `files_to_touch` |
| `post-build-suppression-scan.sh` | Every Edit/Write | `nolint`, `eslint-disable`, `@ts-ignore`, etc. |
| `post-build-tdd-evidence.sh` | Manual check | Missing or fake TDD red-phase evidence |
| `retry-loop-detector.sh` | Every Bash command | Same command run 3+ times consecutively |

Hooks that detect a violation **block Claude** (exit code 2) and display a clear error message with required actions.

### Disabling hooks temporarily

If a hook is blocking legitimate work, you can comment it out in `~/.claude/settings.json` under the `hooks` key. Re-enable it after.

---

## State Files

All workflow state lives in `.workflow/` (gitignored). These files drive the pipeline:

| File | Written by | Read by | Purpose |
|:-----|:-----------|:--------|:--------|
| `config.yaml` | `/init` (you edit) | All phases | Project config — paths, commands, limits, parallel settings |
| `pipeline_state.yaml` | Orchestrator | Orchestrator | Current phase, stages, per-task states, blocked tasks, history |
| `stage_manifest.yaml` | `/plan` | Orchestrator, `/build` | Active stage: worktree paths, branches, task contracts |
| `current_task.yaml` | `/plan` (per worktree) | `/build`, `/review` | The task contract — scope, tests, criteria |
| `review_ready.yaml` | `/build` (per worktree) | `/review` | Build completion claim with TDD evidence |
| `feedback.yaml` | `/review` (per worktree) | `/build` (fix mode) | Rejection details with required fixes |

### Pipeline lifecycle

```
idle → analysing → awaiting_analyse_approval → computing_stages →
  planning_stage → awaiting_stage_approval → executing_stage → stage_complete →
    [more stages?] → planning_stage (next stage)
    [all done?] → idle
```

### Per-task lifecycle (within a stage)

```
pending → building → reviewing → completed (merge to main)
                               → rejected → building (fix mode)
                                          → attempt_counter >= 3 → escalated
```

Escalated tasks propagate blocks to their dependents in later stages.

---

## Parallel Execution

Tasks within a dependency stage run in parallel, each in its own git worktree. Configure this in `.workflow/config.yaml`:

```yaml
parallel:
  enabled: true
  worktree_base: ".claude/worktrees"    # Where worktrees are created
  merge_strategy: "branch-push"          # or "direct-merge"
  max_concurrent_tasks: 4                # Limit simultaneous tasks
```

### How stages work

1. **Stage computation** — After sprint approval, tasks are topologically sorted by their `depends_on` declarations into stages:
   - Stage 1: tasks with no dependencies
   - Stage 2: tasks depending only on stage 1 tasks
   - Stage N: tasks whose dependencies are all in earlier stages

2. **Planning** — All tasks in a stage are planned as a batch. One worktree and branch per task.

3. **Execution** — All tasks build and review in parallel. Approved tasks merge to main immediately.

4. **Stage completion** — When all tasks in a stage are completed or escalated, worktrees are cleaned up and the next stage begins.

### Merge protocol

When a task's review is approved:
1. Push the branch from the worktree
2. Merge to main with `--no-ff`
3. If conflicts occur: abort merge, escalate to human (no auto-resolution)
4. On success: push main, remove the worktree

### Escalation propagation

When a task is escalated (3 failed attempts):
- The task is marked `escalated` in pipeline state
- All tasks in later stages that depend on it (directly or transitively) are marked as `blocked`
- Other tasks in the current stage continue unaffected
- Blocked tasks are reported in the sprint completion summary

---

## Per-Project Overrides

Any skill can be overridden per-project by creating a matching file:

```
your-project/.claude/skills/build/SKILL.md
```

This overrides the global `~/.claude/skills/build/SKILL.md` for this project only. Useful for project-specific test commands, conventions, or workflow tweaks.

**Resolution order:** Project `.claude/skills/` → Global `~/.claude/skills/` → Error

---

## Common Scenarios

### Starting a new sprint

```
/pipeline
```
Or step by step:
1. `/analyse` — review the sprint cut, approve it
2. The orchestrator computes dependency stages automatically
3. For each stage: review the batch of task contracts, approve them
4. Tasks build and review in parallel. Approved tasks merge to main.
5. When a stage completes, the next stage is planned automatically.

### Resuming after an interruption

```
/status
```
This tells you where you left off — including which stage you're on, per-task status, and active worktrees. Then run `/pipeline` to resume from the current state.

### Build was rejected

Handled automatically during stage execution. The orchestrator re-runs the build in fix mode using `.workflow/feedback.yaml`. Max 3 attempts per task.

### Task is stuck (3 rejections)

The task is escalated. Other tasks in the stage continue. Options:
- Re-plan the task with a different approach
- Fix the issue manually in the worktree
- Skip the task (dependents in later stages will be blocked)

### Merge conflict during stage execution

The merge is aborted and escalated to you. You'll see which files conflict and which branches are involved. Resolve manually, then the pipeline continues.

### Adding a new project

```
cd /path/to/new-project
/init
```
Then edit `.workflow/config.yaml` — especially the `parallel` section for worktree settings.

### Skipping a phase

You can run phases out of order if needed. Just make sure the required state files exist:
- `/build` needs `current_task.yaml` (in the worktree)
- `/review` needs `current_task.yaml` + `review_ready.yaml` (in the worktree)

---

## Troubleshooting

### "No config.yaml found"
Run `/init` first to bootstrap the project.

### Hook keeps blocking edits
Check which hook is firing from the error message. If it's the scope audit, you may need to update `files_to_touch` in the task contract. If it's the suppression scan, fix the underlying lint issue instead of suppressing it.

### "HALT: Same command 3 times"
Claude is in a retry loop. The root-cause-tracing skill will be invoked. If you want to override, clear `/tmp/.workflow-cmd-history`.

### Pipeline state is corrupted
Delete `.workflow/pipeline_state.yaml` and run `/status` — it will be recreated with `idle` state.

### Orphaned worktrees after interruption
Run `git worktree list` to see active worktrees. Remove any under the configured `parallel.worktree_base` that don't correspond to active tasks:
```bash
git worktree remove <path> --force
```

### Merge conflict blocks a task
The orchestrator aborts the merge and escalates. Resolve the conflict manually in the worktree, then push. The pipeline will detect the resolution.

### All tasks in a stage are blocked
If every task in remaining stages depends on an escalated task, the pipeline transitions to `idle` and reports what's blocked. Resolve the escalated task first, then re-run `/pipeline`.

### Want to start fresh on a task
Delete the task's worktree (`git worktree remove <path>`), clear its entry from `pipeline_state.yaml` task_states, and re-plan.
