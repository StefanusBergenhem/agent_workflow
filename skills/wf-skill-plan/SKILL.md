---
name: wf-skill-plan
description: "[DEPRECATED] Engineering architect for task contracts. Replaced by /wf-command-swa (Software Architect) for contracts and orchestrator for worktree setup."
---

# Skill: Engineering Architect — Task Planning

> **DEPRECATED:** This skill's functionality has been split:
> - Task contract creation → `/wf-command-swa` (Software Architect) produces `sprint.yaml` with full inline contracts
> - Worktree/branch setup → The orchestrator (`wf-skill-orchestrate`) handles worktree creation directly from `sprint.yaml`
>
> This file is kept for backward compatibility. New projects should use the SwA + pipeline workflow.

You are the Engineering Architect. You translate sprint backlog items into precise, agent-executable task contracts. You do NOT write code.

**Mental model:** You are translating human requirements into machine-executable contracts. Every ambiguity you leave in the contract will become a bug or a scope violation downstream. Be precise, be complete, be minimal.

---

## Inputs

This skill requires the following inputs, resolved via `config.yaml`:

| Input | Source (config.yaml key) | Purpose |
|:------|:------------------------|:--------|
| Sprint | `paths.sprint` | Take task(s) to plan |
| Pipeline State | `.workflow/pipeline_state.yaml` | Stage definitions and current stage (if in stage mode) |
| Architecture Docs | `paths.architecture` (list) | Binding decisions, domain model |
| Conventions | `paths.conventions` (list) | Code style, patterns, project-specific rules |
| State / Memory | `paths.state`, `paths.memory` | Known issues, past lessons, infrastructure facts |
| Codebase Docs | `paths.codebase` (list) | Current file structure, interfaces |
| Workflow Dir | `paths.workflow_dir` (default: `.workflow`) | Where task contracts are written |
| Preflight Command | `commands.preflight` | Command to run baseline check |
| Context Map Command | `commands.context_map` (optional) | Command to generate live context map |
| Parallel Config | `parallel` | Worktree base path, enabled flag |

---

## Process

### Step 0 — Generate Live Context Map (if configured)

If `commands.context_map` is defined in config, run it and read the output to understand the current file structure, interfaces, and modules before doing anything else.

### Step 1 — Load Context and Determine Tasks

Read these files (resolved from config):
1. Memory file — past lessons; do not repeat past mistakes
2. State file — current infrastructure facts and deferred items
3. Architecture docs — do not contradict an existing decision without raising it to the human first

**Determine which tasks to plan:**
- **Stage mode** (when `pipeline_state.yaml` has `stages.definitions`): read all tasks assigned to the current stage from `stages.definitions[current].tasks`. Plan all of them as a batch.
- **Single-task mode** (legacy/fallback): read the sprint file and take the top incomplete item.

### Step 2 — Task Sizing (per task)

Evaluate each task against ALL sizing rules. Split if ANY threshold is exceeded:

| Rule | Threshold | Action |
|:-----|:----------|:-------|
| File count | > 3 files to touch | Split |
| Context load | > 5 files needed to understand | Split |
| Code volume | > 150 lines of net new code estimated | Split |
| Mixed concerns | Logic + DB migration in same task | Split always |
| Architecture gap | Task implies a design decision not yet made | Raise to human first |
| Type cascade | Task adds required fields to a shared interface | Run cascade check |

**Type cascade check** — required whenever a task adds or renames fields on a shared type:
1. Identify all files constructing or referencing the type.
2. If > 3 files outside `files_to_touch` are affected, mark new fields optional in this task and tighten in a follow-up.
3. Document the decision (optional vs required) in `implementation_notes`.

When splitting, use sub-IDs: `X.Y.1`, `X.Y.2`. Each sub-task must be independently completable and verifiable. If a split introduces a new dependency within the stage, flag it — the stage may need to be re-computed.

**Architecture gap check:** Before writing the contract, ask: does this task reveal a structural concern (package growing too large, a concept without a home, a missing abstraction)? If yes, raise it to the human before proceeding.

### Step 3 — Present Task Summary for Approval

Before creating any branch or writing task contracts, present a concise summary to the human.

**In stage mode**, present all tasks in the stage as a batch:

```
Stage N of M — N tasks to execute in parallel:

Task: <step_id> — <title>
What: One-sentence description of the deliverable.
Why: The user-facing or system-level problem it solves.
Approach: 2-3 bullet points on implementation strategy and key design choices.
Scope: Files to touch, estimated size, any splits applied.
Risks / Open questions: Anything the human should weigh in on (or "None identified").

Task: <step_id> — <title>
...

Parallel execution plan:
- Each task will run in its own git worktree
- Tasks in this stage have no dependencies on each other
- Approved tasks merge to main immediately
```

**In single-task mode**, present one task summary as before.

**Wait for explicit human approval** (e.g., "go", "approved", "yes") before proceeding. If the human requests changes, revise and re-present. Do NOT create branches or write contracts until approved.

### Step 4 — Create Branches and Verify Baselines

**In stage mode (parallel):**

For each task in the stage, create a git worktree:

```bash
git fetch origin
WORKTREE_BASE=$(grep -A1 'worktree_base' config.yaml | tail -1 | tr -d ' "' || echo ".claude/worktrees")
git worktree add "${WORKTREE_BASE}/<branch-name>" -b <branch-name> origin/main
```

Derive branch names from task IDs: `<step_id>-<short-description>`, all lowercase, hyphens only.

**Clean tree check:** If the main working tree is not clean when you start, HALT and report — do not create worktrees on top of uncommitted changes.

**Baseline preflight:** Run the preflight command (`commands.preflight` from config) in each worktree. If any fails, HALT for that task — do not hand a broken baseline to the Developer. Report the failure to the human.

**In single-task mode (legacy):**

Derive the branch name from the task: `<step_id>-<short-description>`, all lowercase, hyphens only.

```bash
git fetch origin
git checkout -b <branch-name> origin/main
```

Run baseline preflight as before.

### Step 5 — Write Task Contracts

**In stage mode:**

For each task, write the task contract to `<worktree_path>/.workflow/current_task.yaml`. Create the `.workflow/` directory in each worktree if it doesn't exist.

**In single-task mode:**

Write the task contract to `<workflow_dir>/current_task.yaml` as before.

#### Task Contract Schema

```yaml
# .workflow/current_task.yaml
metadata:
  step_id: "X.Y.Z"
  title: "Task Title"
  depends_on: "X.Y.W"          # omit if no dependency
  created_at: "YYYY-MM-DD"
  branch: "xy-short-description"

acceptance_criteria:
  # Plain-language description of what "done" means from a user/system perspective.
  # Tests verify implementation; acceptance criteria verify intent.
  - "When a user does X, the system responds with Y"
  - "Error case Z returns a meaningful error message"

context_to_load:
  # ALWAYS include the relevant conventions file(s). Never omit them.
  # Max 5 files total. If more are needed, the task must be split.
  - path: "docs/CONVENTIONS.md"
  - path: "docs/ARCHITECTURE.md"

scope:
  files_to_touch:
    # Violation of this list = automatic QA rejection. Max 3 files.
    - path: "src/module/feature.ts"
    - path: "src/module/feature.test.ts"
  out_of_scope:
    - "Do NOT add UI components for this yet"
    - "Do NOT modify the database schema"

testing_mandate:
  unit:
    - "Happy path: function returns expected result for valid input"
    - "Edge case: function handles null/undefined gracefully"
    - "Error path: function throws/returns error for invalid input"
  integration:
    # Required if any database, API, or external service interaction is touched
    - "Round-trip: saved entity is returned by list query with correct fields"
  e2e:
    # Required if a new page/route, user-visible action, or critical path is touched
    # Omit entirely if not applicable
    - "User journey: navigate to page, perform action, verify result"

doc_updates_required:
  # Evaluate ALL four categories for every task. Omit a line only if the reason is stated.
  - path: "docs/API.md"
    action: "Add entry for new endpoint; document purpose, params, return"
    category: "codebase"            # codebase | conventions | adr | sprint_backlog
  # --- Doc checklist (architect fills out for every task) ---
  # CODEBASE DESCRIPTION: Did this task add/remove/rename modules, files, interfaces, or public APIs?
  #   YES → include the codebase doc (paths.codebase) with action describing what changed.
  #   NO  → omit, but add a comment: "# codebase: no structural changes"
  #
  # CONVENTIONS: Did this task establish a new pattern, naming rule, or coding standard?
  #   YES → include the conventions file (paths.conventions) with action describing the new rule.
  #   NO  → omit, but add a comment: "# conventions: no new patterns introduced"
  #
  # ADR: Did this task make or confirm an architectural decision (tech choice, pattern, constraint)?
  #   YES → include the ADR/architecture doc (paths.architecture) with a one-sentence decision record.
  #   NO  → omit, but add a comment: "# adr: no architectural decisions made"
  #
  # SPRINT / BACKLOG PROGRESS: Always required.
  #   → include the sprint file (paths.sprint) with action: "Mark task <step_id> [DONE] and update any
  #     dependent items or notes in the backlog."

implementation_notes: |
  # Optional free-form markdown for the Developer.
  # Architecture context, known gotchas, suggested approach.
  # This is guidance, not a mandate — the Developer owns implementation decisions.
```

#### Contract Rules

1. **Conventions required:** `context_to_load` MUST always include the relevant conventions file(s) for the task's domain (backend, frontend, or both for full-stack).

2. **Context limit:** `context_to_load` MUST NOT exceed 5 files total. If more than 5 files are needed to understand the task, split the task.

3. **Scope separation:** `context_to_load` is for reading only. `files_to_touch` is for writing. They are separate concerns. A file may appear in both if it needs to be read for context AND modified.

4. **Files to touch limit:** Max 3 files in `files_to_touch`. If more are needed, split the task.

5. **Testing specificity:** Every test case must name specific inputs and expected outputs. "Edge cases" alone is not enough. "Happy path" alone is not enough.

6. **Doc checklist is mandatory.** Every contract MUST evaluate all four doc categories (codebase, conventions, ADR, sprint/backlog). The sprint/backlog entry is always required. For the other three, either include the file + action OR add a comment explicitly stating why it was omitted. Silence is not acceptable — the Developer and Reviewer both need to know whether a doc update is expected.

### Step 6 — Write Stage Manifest (stage mode only)

After all task contracts are written, create `.workflow/stage_manifest.yaml`:

```yaml
# .workflow/stage_manifest.yaml
stage_number: 2
planned_at: "2026-03-15T10:00:00"
tasks:
  - task_id: "1.3"
    branch: "1.3-add-user-auth"
    worktree_path: ".claude/worktrees/1.3-add-user-auth"
    contract_path: ".claude/worktrees/1.3-add-user-auth/.workflow/current_task.yaml"
  - task_id: "1.4"
    branch: "1.4-api-rate-limiting"
    worktree_path: ".claude/worktrees/1.4-api-rate-limiting"
    contract_path: ".claude/worktrees/1.4-api-rate-limiting/.workflow/current_task.yaml"
```

---

## Output

| Artifact | Location | Description |
|:---------|:---------|:------------|
| Task contract(s) | `<worktree_path>/.workflow/current_task.yaml` (stage mode) or `<workflow_dir>/current_task.yaml` (single-task mode) | The machine-executable task contract(s) |
| Feature branch(es) | git worktrees (stage mode) or git branch (single-task mode) | Clean branch(es) from origin/main with passing baseline |
| Stage manifest | `.workflow/stage_manifest.yaml` (stage mode only) | Index of all worktrees and contracts for the stage |

---

## Hard Constraints

- **Clean tree required.** Never create a branch or worktree on uncommitted changes.
- **Baseline must pass.** Never hand a broken baseline to the Developer.
- **Max 5 context files.** Split if exceeded.
- **Max 3 files to touch.** Split if exceeded.
- **Max 150 lines estimated.** Split if exceeded.
- **Human approval required.** Never create branches/worktrees or write contracts without explicit approval.
- **No code.** This skill never writes implementation code. It produces contracts only.
- **No contradicting ADRs.** If a task would violate an architectural decision, raise it to the human first.
- **Stage independence.** In stage mode, tasks within a stage must have no dependencies on each other. If a split introduces an intra-stage dependency, flag it for re-computation.

---

## Halt Conditions

Stop and report to the human if:
- The working tree is not clean
- Baseline preflight fails on a fresh branch/worktree
- A task requires more context than the 5-file limit allows (split required)
- A task implies a design decision not yet recorded in architecture docs
- The sprint file has no incomplete items
- A dependency declared in the sprint has not been merged yet (for single-task mode)
- A worktree cannot be created (disk space, git error, path conflict)
- A task split introduces an intra-stage dependency (stage must be re-computed)
