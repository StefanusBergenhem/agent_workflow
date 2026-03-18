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
/wf-command-init
```

This creates:
- `.workflow/config.yaml` — project settings (language, test commands, paths)
- `.workflow/pipeline_state.yaml` — pipeline state tracker
- `COMPONENTS.yaml` — empty component registry
- `master_backlog.yaml` — empty backlog
- `.workflow/` added to `.gitignore`

For existing codebases, use deep mode:
```
/wf-command-init deep
```
This additionally generates `COMPONENTS.yaml` with discovered modules, per-module `ARCHITECTURE.md` files, and an `architecture_audit.md` report.

Review and customize `.workflow/config.yaml` — especially the `commands` and `paths` sections.

---

## Role Hierarchy

The workflow uses a **layered role hierarchy**. The top three roles are invoked manually; the bottom three run as an automated pipeline.

| Role | Command | Input | Output |
|:-----|:--------|:------|:-------|
| **Product Strategist** | `/wf-command-strategist` | Conversation, `roadmap.yaml` | `roadmap.yaml` |
| **Solution Architect** | `/wf-command-sa` | `roadmap.yaml` (optional), `master_backlog.yaml`, `COMPONENTS.yaml`, `ARCHITECTURE.md` | `master_backlog.yaml`, `COMPONENTS.yaml`, `ARCHITECTURE.md` |
| **Software Architect** | `/wf-command-swa` | `master_backlog.yaml`, source code | `sprint.yaml` (with task contracts) |
| **Developer** | (automated) | `sprint.yaml` task contracts | Code + `review_ready.yaml` |
| **Reviewer** | (automated) | Code diff, task contract | APPROVED / REJECTED / DESIGN_ISSUE |
| **Retrospective** | (automated) | Pipeline state, sprint data | `retrospective/<sprint-id>.md` |

### Manual Phases (you decide when)

```
/wf-command-strategist  →  roadmap.yaml
/wf-command-sa          →  master_backlog.yaml + COMPONENTS.yaml + ARCHITECTURE.md
/wf-command-swa         →  sprint.yaml (with task contracts)
```

### Automated Pipeline

```
/wf-command-pipeline reads sprint.yaml
  → create sprint branch from main (sprint/<sprint-id>)
  → compute stages (dependency sort)
  → for each stage:
      → create worktrees + branches per task (from sprint branch)
      → spawn parallel build agents
      → spawn review agent per completed build
      → merge approved tasks to sprint branch
      → halt tasks with design issues → write design_issues.yaml
      → escalate tasks with 3 failures
  → after all stages: run retrospective
  → produce retrospective/<sprint-id>.md
  → push sprint branch + create PR to main
  → idle
```

---

## The Pipeline

The automated pipeline uses **stage-based parallelism**: tasks are grouped into dependency stages via topological sort, tasks within a stage run in parallel (in separate git worktrees), and stages execute serially.

### Running the pipeline

```
/wf-command-pipeline
```

**Prerequisites:** `sprint.yaml` must exist (produced by `/wf-command-swa`). If missing, the pipeline HALTs and tells you to run `/wf-command-swa`.

The orchestrator runs **resume detection first**:
- If `sprint.yaml` exists with incomplete tasks → resumes mid-sprint at the correct phase
- If no `sprint.yaml` exists → HALTs

After resume detection:
1. Creates a sprint branch from main (`sprint/<sprint-id>`)
2. Computes dependency stages (topological sort of sprint tasks)
3. For each stage: creates worktrees (from sprint branch), then executes all tasks in parallel
4. Approved tasks merge to the sprint branch immediately; rejected tasks retry up to 3 times
5. Design issues halt the affected task (no retries — requires architect fix)
6. After all stages: runs retrospective, then pushes sprint branch and creates a PR to main

### Within each stage execution (parallel per task)

```
build → review → APPROVED → merge to sprint branch
               → REJECTED → retry build (max 3x, then escalate)
               → DESIGN_ISSUE → halt task, write design_issues.yaml
```

### Running phases individually

You can also run each phase manually:

```
/wf-command-build      # Execute a task contract (TDD)
/wf-command-review     # Validate the build against the contract
```

This is useful when you want more control, or when resuming after an interruption.

### Checking status

```
/wf-command-status
```

Reports: current phase, stage progress (N of M), per-task status within the active stage (building/reviewing/completed/escalated/design_issue), blocked tasks, worktree locations, and next action.

---

## Phase Details

### /wf-command-strategist — Product Strategy

**What it does:** Freeform conversation partner for product thinking. Takes unstructured input (stakeholder requests, user feedback, ideas) and helps structure it into a prioritized roadmap.

**You decide when to run this.** Typically at the start of a project or when new requirements arrive.

**Output:** `roadmap.yaml` — structured file with epics, features, priorities, dependencies.

### /wf-command-sa — Solution Architecture

**What it does:** Interactive architecture session. Supports two modes:
- **Roadmap mode** (when `roadmap.yaml` exists) — translates roadmap into technical strategy
- **Ongoing mode** (when only `master_backlog.yaml` exists) — evaluates system health, updates architecture, cuts next sprint from existing backlog

The SA thinks out loud — showing reasoning, presenting alternatives with tradeoffs, and using Mermaid diagrams to make architecture visible during the conversation.

**You decide when to run this.** After strategist (roadmap mode), or whenever architecture needs updating and you want to cut the next sprint (ongoing mode).

**How it works (5 phases with interactive checkpoints):**

1. **Ground** — Loads context, orients you on what exists and what needs to happen (roadmap features or backlog state)
2. **Diagnose** — Runs architecture health checks, shows a component dependency diagram with issues annotated, discusses findings with you before proceeding
3. **Design** — *Roadmap mode:* walks through features one at a time with diagrams and design decisions. *Ongoing mode:* reviews components touched by the next sprint for architecture drift, stale items, and new technical decisions needed.
4. **Plan** — Updates architecture artifacts, builds/updates the master backlog, shows a sprint cut visualization, discusses sprint boundaries with you
5. **Commit** — Summarizes decisions, writes artifacts on your approval

Diagrams are ephemeral conversation tools — they help you see the system during the session but are not persisted into files. Agents consume the YAML artifacts.

**Output:** `master_backlog.yaml`, updated `COMPONENTS.yaml`, updated `ARCHITECTURE.md` files.

### /wf-command-swa — Software Architecture

**What it does:** Takes the next sprint from the master backlog, reads actual source code in affected components, and produces detailed `sprint.yaml` with full task contracts.

**You decide when to run this.** After SA, or when ready to start the next sprint.

**What to look for:**
- Are tasks sized correctly? (max 3 files, max 150 lines each)
- Are acceptance criteria clear and testable?
- Are component boundaries respected?
- Are there design issues flagged?

**Output:** `sprint.yaml` with inline task contracts, optionally `design_issues.yaml`.

### /wf-command-pipeline — Automated Execution

**What it does:** Reads `sprint.yaml` and executes the full build→review→merge pipeline.

**Runs fully autonomously** — no human approval gates during execution.

**Output:** Sprint branch with merged code, `retrospective/<sprint-id>.md`, and a pull request to main.

### /wf-command-build — TDD Execution

**What it does:** Executes a task contract using strict TDD:
1. Writes tests first, confirms they FAIL (red phase)
2. Implements code to make tests pass (green phase)
3. Refactors (refactor phase)
4. Runs preflight, writes completion claim

**Two modes:**
- **Build mode** — fresh implementation from the contract
- **Fix mode** — activated when `feedback.yaml` exists from a prior review rejection

**Design issue detection:** If the developer discovers an architectural problem during implementation (wrong boundary, missing interface, impossible constraint), they write to `design_issues.yaml` and halt — no retries.

**Output:** Code changes + `.workflow/review_ready.yaml`.

### /wf-command-review — QA Validation

**What it does:** Adversarial review of the build against the contract. Checks (in priority order):

| Priority | Checks |
|:---------|:-------|
| P0 (critical) | Security scan, scope audit, acceptance criteria, **architecture compliance** |
| P1 (tests) | Test existence, test quality, TDD evidence, suppression scan |
| P2 (quality) | Documentation, conventions, clean code |
| P3 (integration) | Independent preflight run |

**Architecture compliance (new):** Verifies modified files belong to the correct component per `COMPONENTS.yaml`, checks import directions against `dependency_rules`, validates ownership per `ARCHITECTURE.md`.

**On approval:** Pushes the branch, merges to the sprint branch, cleans up the worktree.

**On rejection:** Writes `.workflow/feedback.yaml` with specific failures. Build re-runs in fix mode. Max 3 attempts.

**On design issue:** Writes `design_issues.yaml`. Task is halted, not retried.

---

## Architecture Governance

### COMPONENTS.yaml

The component registry defines system structure, boundaries, and rules:

```yaml
components:
  auth:
    path: src/auth/
    owns: [authentication, session-management]
    exposes: [AuthMiddleware, SessionStore]
    depends_on: [database, user-service]
    constraints:
      max_source_files: 20
      max_exported_symbols: 15

dependency_rules:
  - "ui must not import from database"
  - "no circular dependencies"
```

### ARCHITECTURE.md (per module)

Each component can have an `ARCHITECTURE.md` documenting its responsibility, ownership boundaries, key interfaces, and invariants.

### design_issues.yaml

Written by the developer or reviewer when they discover a design-level problem that can't be fixed at the code level:

```yaml
issues:
  - id: "DI-001"
    detected_by: "developer"
    task_id: "S1.3"
    level: "solution_architect"
    summary: "Auth module needs direct DB access but dependency rules forbid it"
    impact: "Task S1.3 blocked"
    status: "open"
```

Design issues require resolution via `/wf-command-sa` or `/wf-command-swa`.

---

## Hooks — Mechanical Enforcement

Hooks run automatically during Claude's work. You don't invoke them — they fire on tool use events.

| Hook | Triggers on | What it catches | Blocking? |
|:-----|:------------|:----------------|:----------|
| `post-build-scope-audit.sh` | Every Edit/Write | Files modified outside `files_to_touch` | Yes (exit 2) |
| `post-build-suppression-scan.sh` | Every Edit/Write | `nolint`, `eslint-disable`, `@ts-ignore`, etc. | Yes (exit 2) |
| `import-direction-check.sh` | Every Edit/Write | Import statements violating `COMPONENTS.yaml` dependency_rules | Yes (exit 2) |
| `component-size-check.sh` | Every Edit/Write | Components exceeding max_source_files or max_exported_symbols | No (warning only) |
| `architecture-staleness-check.sh` | Every Edit/Write | Source changes without ARCHITECTURE.md update | No (warning only) |
| `post-build-tdd-evidence.sh` | Manual check | Missing or fake TDD red-phase evidence | Yes (exit 2) |
| `retry-loop-detector.sh` | Every Bash command | Same command run 3+ times consecutively | Yes (exit 2) |

### Disabling hooks temporarily

If a hook is blocking legitimate work, you can comment it out in `~/.claude/settings.json` under the `hooks` key. Re-enable it after.

---

## State Files

All workflow state lives in `.workflow/` (gitignored). These files drive the pipeline:

| File | Written by | Read by | Purpose |
|:-----|:-----------|:--------|:--------|
| `config.yaml` | `/wf-command-init` (you edit) | All phases | Project config — paths, commands, limits, parallel settings |
| `pipeline_state.yaml` | Orchestrator | Orchestrator | Current phase, stages, per-task states, design issues, blocked tasks, history |
| `stage_manifest.yaml` | Orchestrator | Orchestrator, Build, Review | Active stage: worktree paths, branches, task contracts |
| `current_task.yaml` | Orchestrator (per worktree) | Build, Review | The task contract — scope, tests, criteria |
| `review_ready.yaml` | Build (per worktree) | Review | Build completion claim with TDD evidence |
| `feedback.yaml` | Review (per worktree) | Build (fix mode) | Rejection details with required fixes |

### Architecture files (project root, committed to git)

| File | Written by | Read by | Purpose |
|:-----|:-----------|:--------|:--------|
| `roadmap.yaml` | `/wf-command-strategist` | SA | Product roadmap with epics and features |
| `COMPONENTS.yaml` | `/wf-command-sa` (or `/wf-command-init deep`) | SwA, Build, Review, Hooks | Component registry and dependency rules |
| `*/ARCHITECTURE.md` | `/wf-command-sa` (or `/wf-command-init deep`) | SwA, Review | Per-module architecture docs |
| `master_backlog.yaml` | `/wf-command-sa` | SwA | Ordered backlog with sprint groupings |
| `sprint.yaml` | `/wf-command-swa` | Pipeline | Sprint with full inline task contracts |
| `design_issues.yaml` | Build, Review, SwA | Human, SA, SwA | Design-level problems requiring architect resolution |

### Pipeline lifecycle

```
idle → creating_sprint_branch → computing_stages → planning_worktrees →
  executing_stage → stage_complete →
    [more stages?] → planning_worktrees (next stage)
    [all done?] → retrospective → publishing (push + PR) → idle
```

### Per-task lifecycle (within a stage)

```
pending → building → reviewing → completed (merge to sprint branch)
                               → rejected → building (fix mode)
                                          → attempt_counter >= 3 → escalated
                               → design_issue → halted (needs architect)
```

Escalated and design-issue tasks propagate blocks to their dependents in later stages.

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

1. **Stage computation** — Tasks are topologically sorted by their `depends_on` declarations into stages:
   - Stage 1: tasks with no dependencies
   - Stage 2: tasks depending only on stage 1 tasks
   - Stage N: tasks whose dependencies are all in earlier stages

2. **Worktree planning** — The orchestrator creates one worktree and branch per task, writes task contracts to each worktree.

3. **Execution** — All tasks build and review in parallel. Approved tasks merge to the sprint branch immediately.

4. **Stage completion** — When all tasks in a stage are completed, escalated, or halted (design issue), worktrees are cleaned up and the next stage begins.

5. **Publishing** — After retrospective, the sprint branch is pushed and a PR is created to main with a sprint summary.

### Context management

The orchestrator uses a self-compacting strategy to manage context usage across multi-stage sprints. Sub-agent output is piped to `/tmp/pipeline-<sprint_id>-<task_id>.log` files — the orchestrator reads only the verdict, not the full output. At each stage boundary, a compact summary is written to `pipeline_state.yaml` under `stage_summaries`, and prior stage details are not referenced again. This keeps the orchestrator's context window usage manageable even for sprints with many stages.

### Merge protocol

When a task's review is approved:
1. Push the branch from the worktree
2. Merge to the sprint branch with `--no-ff`
3. If conflicts occur: abort merge, escalate to human (no auto-resolution)
4. On success: push sprint branch, remove the worktree

### Escalation propagation

When a task is escalated (3 failed attempts) or halted (design issue):
- The task is marked appropriately in pipeline state
- All tasks in later stages that depend on it (directly or transitively) are marked as `blocked`
- Other tasks in the current stage continue unaffected
- Blocked tasks are reported in the sprint completion summary and retrospective

---

## Retrospective

At the end of every sprint pipeline run, a retrospective is automatically generated:

```
retrospective/<sprint-id>.md
```

The retrospective includes:
- **Summary:** Tasks planned vs completed, first-attempt passes, escalations
- **What worked:** Tasks that passed first attempt and why
- **What failed:** Rejection patterns, root causes, categorized by failure type
- **Design issues surfaced:** From `design_issues.yaml`
- **Suggested improvements:** Specific, actionable changes to workflow, architecture, task sizing, or contract quality

The retrospective runs without a human gate. Review it after each sprint to improve the next one.

---

## Deprecated Commands

The following commands are deprecated but kept for backward compatibility:

| Deprecated | Replaced by |
|:-----------|:------------|
| `/wf-command-analyse` | `/wf-command-sa` + `/wf-command-swa` |
| `/wf-command-plan` | `/wf-command-swa` (contracts) + pipeline (worktrees) |

---

## Per-Project Overrides

Any skill can be overridden per-project by creating a matching file:

```
your-project/.claude/skills/wf-skill-build/SKILL.md
```

This overrides the global `~/.claude/skills/wf-skill-build/SKILL.md` for this project only. Useful for project-specific test commands, conventions, or workflow tweaks.

**Resolution order:** Project `.claude/skills/` → Global `~/.claude/skills/` → Error

---

## Common Scenarios

### Starting a new project

1. `/wf-command-init` (or `/wf-command-init deep` for existing code)
2. `/wf-command-strategist` — discuss product goals, produce `roadmap.yaml`
3. `/wf-command-sa` — define architecture, produce `master_backlog.yaml`
4. `/wf-command-swa` — detail first sprint, produce `sprint.yaml`
5. `/wf-command-pipeline` — execute the sprint

### Starting the next sprint

1. `/wf-command-swa` — detail the next sprint from master backlog
2. `/wf-command-pipeline` — execute it

### Reassessing architecture mid-project

1. `/wf-command-sa` — runs in ongoing mode (no roadmap needed), evaluates system health, updates architecture, re-cuts the backlog
2. `/wf-command-swa` — detail the next sprint from the updated backlog
3. `/wf-command-pipeline` — execute it

### Handling design issues

When the pipeline surfaces a design issue:
1. Review `design_issues.yaml`
2. Run `/wf-command-sa` to amend architecture if needed
3. Run `/wf-command-swa` to re-detail affected tasks
4. Run `/wf-command-pipeline` to re-execute

### Resuming after an interruption

```
/wf-command-pipeline
```
The orchestrator automatically detects the in-progress sprint and resumes from the correct phase. Run `/wf-command-status` first if you want to see where things stand.

### Build was rejected

Handled automatically during stage execution. The orchestrator re-runs the build in fix mode using `.workflow/feedback.yaml`. Max 3 attempts per task.

### Task is stuck (3 rejections)

The task is escalated. Other tasks in the stage continue. Options:
- Re-plan the task with a different approach (run `/wf-command-swa`)
- Fix the issue manually in the worktree
- Skip the task (dependents in later stages will be blocked)

### Merge conflict during stage execution

The merge is aborted and escalated to you. You'll see which files conflict and which branches are involved. Resolve manually, then the pipeline continues.

---

## Troubleshooting

### "No sprint.yaml found"
Run `/wf-command-swa` to produce `sprint.yaml` from the master backlog.

### "No master_backlog.yaml found"
Run `/wf-command-sa` to create the master backlog from the roadmap.

### "No roadmap.yaml found"
Either run `/wf-command-strategist` to create a product roadmap, or if you already have a `master_backlog.yaml`, run `/wf-command-sa` directly — it will operate in ongoing mode without a roadmap.

### "No config.yaml found"
Run `/wf-command-init` first to bootstrap the project.

### Hook keeps blocking edits
Check which hook is firing from the error message. If it's the scope audit, you may need to update `files_to_touch` in the task contract. If it's the import direction check, the dependency rules in `COMPONENTS.yaml` need amending via `/wf-command-sa`. If it's the suppression scan, fix the underlying lint issue instead of suppressing it.

### "HALT: Same command 3 times"
Claude is in a retry loop. The root-cause-tracing skill will be invoked. If you want to override, clear `/tmp/.workflow-cmd-history`.

### Pipeline state is corrupted
Delete `.workflow/pipeline_state.yaml` and run `/wf-command-status` — it will be recreated with `idle` state.

### Orphaned worktrees after interruption
Run `git worktree list` to see active worktrees. Remove any under the configured `parallel.worktree_base` that don't correspond to active tasks:
```bash
git worktree remove <path> --force
```

### Design issue blocks a task
The task is halted — it cannot be retried. Resolve the design issue via `/wf-command-sa` (architecture change) or `/wf-command-swa` (task re-plan), then re-run the pipeline.

### All tasks in a stage are blocked
If every task in remaining stages depends on an escalated or design-issue task, the pipeline transitions to `retrospective` → `publishing` → `idle`. Resolve the blocking issue first, then re-run `/wf-command-pipeline`.

### Want to start fresh on a task
Delete the task's worktree (`git worktree remove <path>`), clear its entry from `pipeline_state.yaml` task_states, and re-plan.
