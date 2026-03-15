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

The full pipeline runs four phases sequentially. You can run them individually or let the orchestrator manage the flow.

```
/analyse → /plan → /build → /review
                     ↑         │
                     └─reject──┘  (max 3x, then escalate)
```

### Running the full pipeline

```
/pipeline
```

This starts the orchestrator, which runs each phase as a sub-agent and manages gates between them. It will pause for your approval after analyse and plan, then auto-proceed through build and review.

### Running phases individually

You can also run each phase manually:

```
/analyse    # Cut a sprint from the backlog
/plan       # Create a task contract for the next sprint item
/build      # Execute the task contract (TDD)
/review     # Validate the build against the contract
```

This is useful when you want more control, or when resuming after an interruption.

### Checking status

```
/status
```

Reports: current phase, active task, sprint progress, attempt count, and next action.

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

### /plan — Task Contract

**What it does:** Takes the next unfinished sprint item and produces a precise task contract — files to touch, files to read for context, acceptance criteria, and a testing mandate.

**You'll be asked to approve** the contract before the branch is created.

**What to look for:**
- Are the right files in `context_to_load`? (max 5)
- Are the right files in `files_to_touch`? (max 3)
- Are acceptance criteria clear and testable?
- Is the testing mandate complete (happy path, edge cases, error paths)?
- Are `out_of_scope` boundaries clear?

**Output:** `.workflow/current_task.yaml` + feature branch created.

### /build — TDD Execution

**What it does:** Executes the task contract using strict TDD:
1. Writes tests first, confirms they FAIL (red phase)
2. Implements code to make tests pass (green phase)
3. Refactors (refactor phase)
4. Runs preflight, writes completion claim

**Runs automatically** — no approval gate. Proceeds directly to review.

**Two modes:**
- **Build mode** — fresh implementation from the contract
- **Fix mode** — activated when `feedback.yaml` exists from a prior review rejection. Addresses only the listed failures.

**Output:** Code changes + `.workflow/review_ready.yaml`.

### /review — QA Validation

**What it does:** Adversarial review of the build against the contract. Checks (in priority order):

| Priority | Checks |
|:---------|:-------|
| P0 (critical) | Security scan, scope audit, acceptance criteria |
| P1 (tests) | Test existence, test quality, TDD evidence, suppression scan |
| P2 (quality) | Documentation, conventions, clean code |
| P3 (integration) | Independent preflight run |

**Runs automatically** after build.

**On approval:** Commits, pushes the branch, cleans up workflow files, updates sprint status.

**On rejection:** Writes `.workflow/feedback.yaml` with specific failures. Build re-runs in fix mode. Max 3 attempts before escalating to you.

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
| `config.yaml` | `/init` (you edit) | All phases | Project config — paths, commands, limits |
| `pipeline_state.yaml` | Orchestrator | Orchestrator | Current phase, attempt counter, history |
| `current_task.yaml` | `/plan` | `/build`, `/review` | The task contract — scope, tests, criteria |
| `review_ready.yaml` | `/build` | `/review` | Build completion claim with TDD evidence |
| `feedback.yaml` | `/review` | `/build` (fix mode) | Rejection details with required fixes |

### Task lifecycle

```
backlog → analysed → planned → building → built → approved → completed
                                  ↑          │
                                  └─rejected──┘ (max 3x → escalated)
```

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
/analyse
```
Review the sprint cut, approve it, then:
```
/plan
```
Review the first task contract, approve it, then:
```
/build
```
Build runs, then review runs automatically. On approval, run `/plan` for the next task.

### Resuming after an interruption

```
/status
```
This tells you where you left off. Then run the appropriate command for the current phase.

### Build was rejected

The review wrote `.workflow/feedback.yaml`. Just run:
```
/build
```
It detects fix mode automatically and addresses only the listed failures.

### Task is stuck (3 rejections)

The system escalates to you. Options:
- Re-plan the task with `/plan` (different approach, smaller scope)
- Fix the issue manually and clear `.workflow/feedback.yaml`
- Skip the task and move on

### Adding a new project

```
cd /path/to/new-project
/init
```
Then edit `.workflow/config.yaml` to match your project's setup.

### Skipping a phase

You can run phases out of order if needed. Just make sure the required state files exist:
- `/build` needs `current_task.yaml`
- `/review` needs `current_task.yaml` + `review_ready.yaml`

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

### Want to start fresh on a task
Delete `.workflow/current_task.yaml`, `.workflow/review_ready.yaml`, and `.workflow/feedback.yaml`. Then run `/plan` to re-plan.
