# Workflow Guide

This is the practical guide to using the workflow system. It covers installation, daily usage, and what to do when things go wrong.

---

## Installation

### 1. Install the toolkit

```bash
cd ~/repos/Claude_code_workflow
./install.sh
```

This copies skills and commands into `~/.claude/` and appends global rules to `~/.claude/CLAUDE.md`. Safe to re-run.

### 2. Bootstrap a project

In any project directory:

```
/wf-command-init
```

Init acts as an **interactive setup wizard** — it detects your project's language, framework, and dependencies, then walks you through each config section with explanations and smart suggestions. At each checkpoint you can confirm, adjust, or say "skip" to accept all defaults.

This creates:
- `.workflow/config.yaml` — project settings (language, test commands, paths)
- `.workflow/pipeline_state.yaml` — pipeline state tracker
- `COMPONENTS.yaml` — empty component registry
- `master_backlog.yaml` — empty backlog
- `docs/MEMORY.yaml` — structured lessons store
- `docs/STATE.md` — infrastructure facts and known issues
- `docs/CONVENTIONS.md` — code style and patterns
- `TARGET_ARCHITECTURE.md` — target end-state vision (empty template)
- `docs/adrs/` — directory for Architecture Decision Records
- `.workflow/` added to `.gitignore` (includes retrospective output)

For existing codebases, use deep mode:
```
/wf-command-init deep
```
This additionally generates `COMPONENTS.yaml` with discovered modules (including `summary` fields) and an `architecture_audit.md` report. The wizard guides you through component boundary review and audit prioritization.

For repos already using the workflow that need updating after a toolkit change:
```
/wf-command-init migrate
```
This non-destructively scans existing structure, reports what's outdated, and applies targeted upgrades. The wizard walks through each new config section before applying, suggests renames for mismatched fields (fuzzy matching against the template schema), and optionally offers a full config review after migration.

---

## Role Hierarchy

The workflow uses a **layered role hierarchy**. The top three roles are invoked manually; the bottom three run as an automated pipeline.

| Role | Command | Input | Output |
|:-----|:--------|:------|:-------|
| **Product Strategist** | `/wf-command-strategist` | Conversation, `roadmap.yaml` | `roadmap.yaml` |
| **Solution Architect** | `/wf-command-sa` | `roadmap.yaml` (optional), `master_backlog.yaml`, `COMPONENTS.yaml`, `TARGET_ARCHITECTURE.md` | `master_backlog.yaml`, `COMPONENTS.yaml` (with summaries), `TARGET_ARCHITECTURE.md` (roadmap mode) |
| **Software Architect** | `/wf-command-swa` | `master_backlog.yaml`, source code | `sprint.yaml` (with task contracts) |
| **Developer** | (automated) | `sprint.yaml` task contracts | Code + `review_ready.yaml` |
| **Reviewer** | (automated) | Code diff, task contract | APPROVED / REJECTED / DESIGN_ISSUE |
| **Retrospective** | (automated) | Pipeline state, sprint data | `.workflow/retrospective/<sprint-id>.md` |

### Manual Phases (you decide when)

```
/wf-command-strategist  →  roadmap.yaml
/wf-command-sa          →  master_backlog.yaml + COMPONENTS.yaml (with summaries) + TARGET_ARCHITECTURE.md (roadmap mode)
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
  → after all stages: run e2e validation (fix cycle if failing)
  → run retrospective → produce .workflow/retrospective/<sprint-id>.md
  → extract lessons into docs/MEMORY.yaml (continuous learning)
  → archive retrospective + metrics to archive directories
  → idle (run /wf-command-ship to push + create PR)
```

---

## Flow Diagram

Complete workflow from product strategy through sprint delivery:

```
  ╔══════════════════════════════════════════════════════════════════╗
  ║  Manual Phases (human-paced, approval-gated)                   ║
  ║                                                                ║
  ║  +---------------------------+                                 ║
  ║  | /wf-command-strategist    |                                 ║
  ║  | Product Strategist        |                                 ║
  ║  +-------------+-------------+                                 ║
  ║                | roadmap.yaml                                  ║
  ║                v                                               ║
  ║  +---------------------------+                                 ║
  ║  | /wf-command-sa            |                                 ║
  ║  | Solution Architect        |                                 ║
  ║  | Ground → Diagnose →      |                                 ║
  ║  | Design → Plan → Commit   |                                 ║
  ║  +-------------+-------------+                                 ║
  ║                | master_backlog.yaml + COMPONENTS.yaml         ║
  ║                | + TARGET_ARCHITECTURE.md (roadmap mode)       ║
  ║                v                                               ║
  ║  +---------------------------+                                 ║
  ║  | /wf-command-swa           |                                 ║
  ║  | Software Architect        |                                 ║
  ║  | Reads source, consults    |                                 ║
  ║  | MEMORY.yaml, sizes tasks  |                                 ║
  ║  +-------------+-------------+                                 ║
  ║                | sprint.yaml (with task contracts)             ║
  ╚════════════════|═══════════════════════════════════════════════╝
                   v
  +-------------------------------+
  | /wf-command-pipeline          |
  | Orchestrator — state machine  |
  +---------------+---------------+
                  |
                  v
  +-------------------------------+
  | Create sprint branch          |
  | sprint/<sprint-id>            |
  +---------------+---------------+
                  |
                  v
  +-------------------------------+
  | Compute stages                |
  | (topological sort)            |
  +---------------+---------------+
                  |
                  v
  +-------------------------------+
  | Plan worktrees                |     <--------------------+
  | (one per task)                |                          |
  +---------------+---------------+                          |
                  |                                          |
                  v                                          |
  ╔═══════════════════════════════════════════════╗          |
  ║  Stage Execution (parallel per task)          ║          |
  ║                                               ║          |
  ║  +------------------+                         ║          |
  ║  | Build            |                         ║          |
  ║  | Red → Green →    |                         ║          |
  ║  | Refactor →       |  <---+                  ║          |
  ║  | Preflight        |      |                  ║          |
  ║  +--------+---------+      |                  ║          |
  ║           |                |                  ║          |
  ║           v                |                  ║          |
  ║  +------------------+      |                  ║          |
  ║  | Review           |      |                  ║          |
  ║  | P0: Security,    |      |                  ║          |
  ║  |     Scope, Arch  |      |                  ║          |
  ║  | P1: Test quality |      |                  ║          |
  ║  | P2: Conventions  |      |                  ║          |
  ║  | P3: Preflight    |      |                  ║          |
  ║  +---+---------+----+      |                  ║          |
  ║      |    |    |           |                  ║          |
  ║      |    |    +-- REJECTED (feedback.yaml)   ║          |
  ║      |    |        Attempt < 3? --Yes---------+          |
  ║      |    |        No --> Halt + Escalate     ║          |
  ║      |    |                                   ║          |
  ║      |    +--- DESIGN_ISSUE                   ║          |
  ║      |         (design_issues.yaml)           ║          |
  ║      |         Halt task, block dependents    ║          |
  ║      |         ....> Requires SA resolution   ║          |
  ║      |                                        ║          |
  ║      +-- APPROVED                             ║          |
  ║          |                                    ║          |
  ║          v                                    ║          |
  ║  +------------------+                         ║          |
  ║  | Merge --no-ff    |                         ║          |
  ║  | to sprint branch |                         ║          |
  ║  +--------+---------+                         ║          |
  ║           |                                   ║          |
  ║       Conflict? --Yes--> Abort + Escalate     ║          |
  ║           |No                                 ║          |
  ║           v                                   ║          |
  ║     Task completed                            ║          |
  ╚═══════════════════════════════════════════════╝          |
                  |                                          |
            More stages? --Yes----------------------------->-+
                  |No
                  v
  +-------------------------------+
  | E2E Validation                |
  | Run commands.test_e2e on      |
  | merged sprint branch          |
  +---+-----------+---------------+
      |           |
    Pass        Fail
      |           +---> Build/Review fix cycle
      |           |     (max 3 attempts, then escalate)
      |           +---> Re-run e2e on success
      |           |
      +<----------+
      |
      v
  +-------------------------------+
  | Retrospective                 |
  | Analyse patterns, metrics,   |
  | generate improvements         |
  +---------------+---------------+
                  | .workflow/retrospective/<sprint-id>.md
                  v
  +-------------------------------+
  | Continuous Learning           |
  | Extract lessons → deduplicate |
  | → enforce capacity → archive  |
  +---------------+---------------+
                  | docs/MEMORY.yaml (updated)
                  | ....> Lessons feed next SWA sprint
                  v
            [Pipeline idle]
            Run /wf-command-ship to push + create PR

  Cross-cutting skills (consulted by build + review):
    Scope Guard | Verification | Root-Cause Tracing
    Receiving Feedback | Testing Anti-Patterns | Observability
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
6. After all stages: runs e2e validation (with fix cycle if failing), then retrospective
7. Pipeline ends at idle — run `/wf-command-ship` to validate, push, and create a PR to main

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

The SA thinks out loud — showing reasoning, presenting alternatives with tradeoffs, and using ASCII art diagrams to make architecture visible during the conversation.

**You decide when to run this.** After strategist (roadmap mode), or whenever architecture needs updating and you want to cut the next sprint (ongoing mode).

**How it works (5 phases with interactive checkpoints):**

1. **Ground** — Loads context (including TARGET_ARCHITECTURE.md if it exists), orients you on what exists, the target vision, and what needs to happen
2. **Diagnose** — Runs architecture health checks (including current-vs-target gap analysis), shows a component dependency diagram with issues annotated, discusses findings with you before proceeding
3. **Design** — *Roadmap mode:* walks through features one at a time with diagrams and design decisions. *Ongoing mode:* reviews components touched by the next sprint for architecture drift, stale items, and new technical decisions needed.
3b. **Update Target Architecture** (roadmap mode only) — Codifies agreed design decisions into TARGET_ARCHITECTURE.md as a coherent narrative
4. **Plan** — Updates architecture artifacts, builds/updates the master backlog, shows a sprint cut visualization, discusses sprint boundaries with you
5. **Commit** — Summarizes decisions, writes artifacts on your approval

Diagrams are ephemeral conversation tools — they help you see the system during the session but are not persisted into files. Agents consume the YAML artifacts.

**Output:** `master_backlog.yaml`, updated `COMPONENTS.yaml` (with `summary` fields per component), `TARGET_ARCHITECTURE.md` (roadmap mode).

### /wf-command-swa — Software Architecture

**What it does:** Takes the next sprint from the master backlog, reads actual source code in affected components, and produces detailed `sprint.yaml` with full task contracts.

**You decide when to run this.** After SA, or when ready to start the next sprint.

**What to look for:**
- Are tasks sized correctly? (per `task_sizing` in config — default: max 3 files, max 150 lines each)
- Are acceptance criteria clear and testable?
- Are component boundaries respected?
- Are there design issues flagged?

**Output:** `sprint.yaml` with inline task contracts, optionally `design_issues.yaml`.

### /wf-command-pipeline — Automated Execution

**What it does:** Reads `sprint.yaml` and executes the full build→review→merge pipeline.

**Runs fully autonomously** — no human approval gates during execution.

**Output:** Sprint branch with merged code and `.workflow/retrospective/<sprint-id>.md`. Run `/wf-command-ship` after to push and create a PR to main.

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

**Architecture compliance:** Verifies modified files belong to the correct component per `COMPONENTS.yaml`, checks import directions against `dependency_rules`, validates component summaries.

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

`COMPONENTS.yaml` now includes a `summary` field per component (2-3 sentences covering responsibility and key interfaces), replacing per-module ARCHITECTURE.md files.

### TARGET_ARCHITECTURE.md

The target architecture document captures the desired end-state of the system — what it should look like when all planned work is complete. It complements COMPONENTS.yaml (current state) and ADRs (individual decisions).

- **Produced by:** SA skill in roadmap mode (Phase 3b)
- **Consumed by:** SA (gap analysis in ongoing mode), SWA (contract quality context), Strategist (awareness)
- **Format:** Human-readable markdown narrative with diagrams, not machine-parseable YAML
- **Lifecycle:** Updated when the roadmap changes or major design decisions are made. Not updated during sprint execution.
- **Relationship to ADRs:** Complementary. TARGET_ARCHITECTURE.md is a living, cohesive narrative. ADRs are individual, formal, immutable records. Decisions in TARGET_ARCHITECTURE.md may reference ADRs. Once a target decision is implemented, it should get a corresponding ADR.

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

## External Skills

The workflow supports **external skill plugins** configured in `.workflow/config.yaml` under `external_skills`. These are project-specific skill files that the build and review skills load for domain-specific guidance.

Skills are organized into two layers:

- **`defaults`** — applied to ALL tasks regardless of domain (e.g., TDD, code review)
- **`domains`** — matched by file path globs against `files_to_touch` (e.g., Go backend, React frontend)

Three skill slots are available per layer:

| Slot | Loaded by | Purpose |
|:-----|:----------|:--------|
| `implementation` | Build | Language/framework-specific coding guidance |
| `testing` | Build | Testing strategy, framework conventions, coverage rules |
| `review` | Review | Project-specific review criteria and quality gates |

Skills are merged: defaults + all matching domain skills = union. Each slot references installed skill names (from `~/.claude/skills/`). If a slot is empty, it is simply skipped. This allows projects to inject domain knowledge without modifying the core workflow skills.

### Domain-Specific Commands

For full-stack projects where different domains need different test/lint commands, add `commands:` to domain entries:

```yaml
external_skills:
  domains:
    backend:
      match: ["backend/**", "**/*.go"]
      skills:
        implementation: ["golang-patterns"]
        testing: ["golang-testing"]
      commands:
        test_unit: "go test ./..."
        test_integration: "go test -tags=integration ./..."
        lint: "golangci-lint run"
    frontend:
      match: ["frontend/**", "**/*.tsx"]
      skills:
        implementation: ["frontend-patterns"]
        testing: ["vitest"]
      commands:
        test_unit: "npx vitest run"
        lint: "npx eslint ."
```

**How resolution works:**
- Top-level `commands` are the defaults for all tasks
- When a task's `files_to_touch` match a domain with `commands`, those commands override the top-level defaults for that task only
- Only specified keys are overridden — unspecified commands keep their top-level values
- Skills merge from all matching domains; commands come from the single best-matching domain (most file matches, ties broken alphabetically)
- The ship command and post-merge validation always use top-level commands (full-project scope)

**When to use:** When your project has distinct toolchains per domain (e.g., Go backend + React frontend). If your project is single-language, top-level commands are sufficient.

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
| `metrics/sprint-<id>.yaml` | Orchestrator | Retrospective | Per-sprint timing, costs, task metrics |
| `metrics/trends.yaml` | Orchestrator | Retrospective | Cross-sprint trend data (append-only) |
| `archive/lessons-archived.yaml` | Retrospective (learning) | Human (reference) | Pruned lessons from memory file |
| `archive/metrics/sprint-<id>.yaml` | Retrospective (learning) | Human (reference) | Archived sprint metrics |

### Architecture files (project root, committed to git)

| File | Written by | Read by | Purpose |
|:-----|:-----------|:--------|:--------|
| `roadmap.yaml` | `/wf-command-strategist` | SA | Product roadmap with epics and features |
| `TARGET_ARCHITECTURE.md` | `/wf-command-sa` (roadmap mode) | SA (gap analysis), SWA (contract context), Strategist (awareness) | Target end-state architecture vision |
| `COMPONENTS.yaml` | `/wf-command-sa` (or `/wf-command-init deep`) | SwA, Build, Review | Component registry and dependency rules |
| `master_backlog.yaml` | `/wf-command-sa` | SwA | Ordered backlog with sprint groupings |
| `sprint.yaml` | `/wf-command-swa` | Pipeline | Sprint with full inline task contracts |
| `design_issues.yaml` | Build, Review, SwA | Human, SA, SwA | Design-level problems requiring architect resolution |
| `docs/MEMORY.yaml` | Retrospective (learning), Review | Build, Review, SwA | Structured lessons from past sprints |

### Pipeline lifecycle

```
idle → creating_sprint_branch → computing_stages → planning_worktrees →
  executing_stage → stage_complete →
    [design issues from this stage?] → HALT (wait for human resolution)
    [more stages?] → planning_worktrees (next stage)
    [all done?] → e2e_validation → retrospective (+ learning) → idle
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

## Model Selection

Sub-agents use lighter models than the orchestrator since task contracts tightly constrain their work. Configure in `.workflow/config.yaml`:

```yaml
models:
  build: "sonnet"            # Model for build sub-agents
  review: "sonnet"           # Model for review sub-agents
  retrospective: "sonnet"    # Model for retrospective sub-agents
```

The orchestrator (and the manual roles — SA, SWA, Strategist) run on opus, which is better suited for architectural reasoning and judgment calls. Build and review sub-agents default to sonnet because the task contracts specify exactly what to do, making the work more about execution than reasoning.

If a `models.<phase>` key is missing, the sub-agent inherits the parent's model.

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

4. **Stage completion** — When all tasks in a stage are completed, escalated, or halted (design issue), worktrees are cleaned up. Post-merge validation runs on the sprint branch: unit tests, integration tests, coverage, and lint. If any check fails, the pipeline halts — this is a cross-task integration issue. If any design issues were raised during this stage, the pipeline halts for human resolution before advancing. Otherwise, the next stage begins.

5. **E2E Validation** — After all stages, e2e tests run on the merged sprint branch. Failures trigger a build/review fix cycle (max 3 attempts). On pass or escalation, the pipeline proceeds to retrospective.

6. **Ship** — After the pipeline completes (idle), run `/wf-command-ship` to validate, push, and create a PR to main.

### Context management

The orchestrator uses a self-compacting strategy to manage context usage across multi-stage sprints. Sub-agents write all output artifacts (feedback.yaml, review_ready.yaml, design_issues.yaml) directly to disk in their worktree — the orchestrator reads only the verdict (APPROVED/REJECTED/DESIGN_ISSUE/ESCALATED), never the artifact contents. Sub-agent text output is piped to `/tmp/pipeline-<sprint_id>-<task_id>.log` files. At each stage boundary, a compact summary is written to `pipeline_state.yaml` under `stage_summaries`, and prior stage details are not referenced again. This keeps the orchestrator's context window usage manageable even for sprints with many stages.

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

## Observability & Metrics

The pipeline collects structured metrics during execution when `config.observability.enabled` is `true` (default). Metrics are best-effort — they never block the pipeline.

### Metrics files

All metrics live in `.workflow/metrics/` (gitignored):

| File | Written by | Purpose |
|:-----|:-----------|:--------|
| `sprint-<sprint-id>.yaml` | Orchestrator | Per-sprint timing, per-task attempts/durations, cost estimates |
| `trends.yaml` | Orchestrator | Cross-sprint summary (append-only, capped at `max_sprints`) |

### What's captured

- **Phase timing** — started_at/completed_at/duration_seconds for each pipeline phase
- **Stage timing** — duration and task count per dependency stage
- **Per-task metrics** — build/review durations per attempt, rejection types, outcome, actual files modified
- **Cost estimation** — estimated context tokens per phase (heuristic: file bytes / `token_ratio`), models used, total dispatch count
- **Summary aggregates** — first_attempt_pass_rate, avg_attempts, longest_task, rejection_type_counts
- **Component health** — pass rate and avg attempts per component (in trends.yaml)

### How it works

The orchestrator records metrics at natural state transition points:
1. **Pipeline start** — initializes the metrics file with sprint metadata
2. **Each dispatch** (steps 3, 5, 9 of the dispatch protocol) — records context size, dispatch timestamp, and completion data
3. **Stage boundaries** — records stage durations
4. **Before retrospective** — finalizes summary aggregates
5. **Publishing phase** — appends a summary entry to trends.yaml

### Cost estimation

Token counts are estimated, not measured (sub-agents don't report token usage). The heuristic divides context envelope file sizes by `token_ratio` (default: 4 bytes/token). This is approximate but sufficient for identifying trends — if sprint N costs 2x sprint N-1, that's a signal regardless of absolute accuracy.

### Configuration

```yaml
observability:
  enabled: true                    # Set false to skip all metrics
  metrics_dir: ".workflow/metrics"
  cost_estimation:
    enabled: true
    token_ratio: 4                 # Bytes per token estimate
  trends:
    enabled: true
    max_sprints: 20                # Keep last N sprints in trends.yaml
```

### Backward compatibility

All metrics consumers (retrospective, status) handle the case where metrics files don't exist. Sprints run before observability was added, or with `enabled: false`, produce qualitative-only retrospectives.

---

## Retrospective

At the end of every sprint pipeline run, a retrospective is automatically generated:

```
.workflow/retrospective/<sprint-id>.md
```

The retrospective includes:
- **Summary:** Tasks planned vs completed, first-attempt passes, escalations
- **What worked:** Tasks that passed first attempt and why
- **What failed:** Rejection patterns, root causes, categorized by failure type
- **Design issues surfaced:** From `design_issues.yaml`
- **Quantitative metrics** (if observability enabled): Phase/stage/task timing, cost estimates, component health table, cross-sprint trend comparisons
- **Suggested improvements:** Specific, actionable changes to workflow, architecture, task sizing, or contract quality

The retrospective runs without a human gate. Review it after each sprint to improve the next one.

---

## Continuous Learning

After each retrospective, the **continuous learning protocol** automatically closes the feedback loop:

### How it works

1. **Extract** — Parses the retrospective report's "What Failed" and "Suggested Improvements" sections, plus sprint metrics (component health, rejection patterns), and distils them into structured lessons
2. **Deduplicate** — Checks each lesson against the existing memory file. If a pattern already exists, it reinforces confidence and adds evidence instead of duplicating
3. **Enforce capacity** — Memory file is capped at `max_memory_entries` (default 30). Lowest-priority lessons are archived to `.workflow/archive/lessons-archived.yaml`
4. **Archive** — Moves the retrospective report to `.workflow/retrospective/archive/` and sprint metrics to `.workflow/archive/metrics/`, so they don't consume context in future runs
5. **Clean design issues** — Removes resolved entries from `design_issues.yaml`

### Memory file format

Lessons are stored in `docs/MEMORY.yaml` (or wherever `paths.memory` points):

```yaml
version: 1
max_entries: 30

lessons:
  - id: "L-001"
    category: "contract_patterns"     # contract_patterns | component_rules | rejection_patterns | process_rules | architecture_signals
    rule: "Always include CONVENTIONS.md in context_to_load for tasks modifying existing code"
    evidence:
      - sprint: "S1"
        tasks: ["S1.3", "S1.5"]
        detail: "Both rejected for convention violations"
    confidence: "high"                # high | medium
    created: "2026-03-15"
    last_reinforced: "2026-03-20"
```

### Who consumes lessons

| Consumer | Categories used | How |
|:---------|:---------------|:----|
| **SWA** | `contract_patterns`, `component_rules`, `architecture_signals` | Applies lessons when creating task contracts — adds context files, adjusts risk levels, tightens acceptance criteria |
| **Build** | `component_rules`, `rejection_patterns` | Reads lessons for component-specific guidance during implementation |
| **Review** | `rejection_patterns` | Scans for known failure patterns before reviewing |

### Archive locations

| Source | Archive | Preserved in git? |
|:-------|:--------|:------------------|
| `.workflow/retrospective/<id>.md` | `.workflow/retrospective/archive/<id>.md` | No (gitignored) |
| `.workflow/metrics/sprint-<id>.yaml` | `.workflow/archive/metrics/sprint-<id>.yaml` | No (gitignored) |
| Pruned lessons | `.workflow/archive/lessons-archived.yaml` | No (gitignored) |

### Configuration

```yaml
learning:
  enabled: true                    # Set false to skip learning
  max_memory_entries: 30           # Cap on active lessons
  archive_retrospectives: true     # Move reports to archive/
  archive_metrics: true            # Move metrics to archive/
  cleanup_design_issues: true      # Remove resolved issues
```

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
3. `/wf-command-sa` — define architecture, produce `master_backlog.yaml`, `COMPONENTS.yaml`, and `TARGET_ARCHITECTURE.md`
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

### Upgrading after toolkit update

1. Run `install.sh` to update skills and commands
2. In each project: `/wf-command-init migrate` to update config and directory structure

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

### Config is missing new sections (models, learning, observability)
Run `/wf-command-init migrate` — it will detect missing sections and add them with defaults.

### "No config.yaml found"
Run `/wf-command-init` first to bootstrap the project.

### Pipeline state is corrupted
Delete `.workflow/pipeline_state.yaml` and run `/wf-command-status` — it will be recreated with `idle` state.

### Orphaned worktrees after interruption
Run `git worktree list` to see active worktrees. Remove any under the configured `parallel.worktree_base` that don't correspond to active tasks:
```bash
git worktree remove <path> --force
```

### Design issue blocks a task
The task is halted — it cannot be retried. The pipeline also halts at the end of the current stage to give you a chance to resolve the issue before further work proceeds. Resolve the design issue via `/wf-command-sa` (architecture change) or `/wf-command-swa` (task re-plan), remove the resolved entry from `pipeline_state.yaml → design_issues`, then re-run `/wf-command-pipeline` to resume.

### All tasks in a stage are blocked
If every task in remaining stages depends on an escalated or design-issue task, the pipeline transitions to `e2e_validation` → `retrospective` → `idle`. Resolve the blocking issue first, then re-run `/wf-command-pipeline`.

### Want to start fresh on a task
Delete the task's worktree (`git worktree remove <path>`), clear its entry from `pipeline_state.yaml` task_states, and re-plan.
