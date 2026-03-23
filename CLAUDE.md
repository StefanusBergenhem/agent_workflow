# Claude Code Workflow Toolkit

A portable, project-agnostic skills framework for Claude Code. The workflow uses a layered role hierarchy (Strategist → Solution Architect → Software Architect → Developer → Reviewer → Retrospective) with clear artifact handoffs, architecture governance, and design-flaw feedback loops.

## Directory Structure

```
skills/              # Cognitive modes — each has a SKILL.md
  wf-skill-strategist/        # Product strategist (roadmap planning)
  wf-skill-sa/                # Solution architect (technical strategy, components)
  wf-skill-swa/               # Software architect (sprint detailing, task contracts)
  wf-skill-build/             # Disciplined developer (TDD execution)
  wf-skill-review/            # QA gatekeeper (adversarial review + architecture compliance)
  wf-skill-orchestrate/       # Pipeline controller (state machine + DISPATCH.md, SCHEMAS.md)
  wf-skill-retrospective/     # Sprint retrospective (analysis + improvement suggestions)
  wf-skill-scope-guard/       # Cross-cutting: file boundary enforcement
  wf-skill-root-cause-tracing/  # Cross-cutting: 4-phase debugging
  wf-skill-verification/      # Cross-cutting: evidence-based completion
  wf-skill-receiving-feedback/  # Cross-cutting: processing rejections
  wf-skill-testing-anti-patterns/  # Cross-cutting: test quality rules
  wf-skill-observability/    # Cross-cutting: pipeline metrics and cost estimation
  wf-skill-continuous-learning/  # Cross-cutting: lesson extraction, memory management, archival

commands/            # Slash commands (thin wrappers invoking skills)
  wf-command-strategist.md    # Product strategy session
  wf-command-sa.md            # Solution architecture session
  wf-command-swa.md           # Software architecture session
  wf-command-pipeline.md      # Run automated pipeline
  wf-command-build.md         # Manual build trigger
  wf-command-review.md        # Manual review trigger
  wf-command-status.md        # Pipeline status report
  wf-command-init.md          # Project bootstrap (standard + deep + migrate mode)
  wf-command-ship.md          # Host-side validation gate (test suite + push)

templates/           # Project bootstrapping templates
  workflow-config.yaml.tmpl    # .workflow/config.yaml starter
  task-contract.yaml.tmpl      # Task contract skeleton
  project-claude.md.tmpl       # Project CLAUDE.md starter
  components.yaml.tmpl         # COMPONENTS.yaml starter
  master-backlog.yaml.tmpl     # master_backlog.yaml starter
  design-issues.yaml.tmpl      # design_issues.yaml starter
  sprint.yaml.tmpl             # sprint.yaml starter
  sprint-metrics.yaml.tmpl     # .workflow/metrics/sprint-<id>.yaml schema
  trends.yaml.tmpl             # .workflow/metrics/trends.yaml schema
  memory.yaml.tmpl             # docs/MEMORY.yaml starter (structured lessons)
  state.md.tmpl                # docs/STATE.md starter (infrastructure facts)
  conventions.md.tmpl          # docs/CONVENTIONS.md starter (code style and patterns)

docs/                # Authoring guides and workflow documentation
  persuasion-principles.md    # Persuasion psychology for skill design
  anthropic-best-practices.md # Official Anthropic skill authoring guide
  WORKFLOW.md                 # Workflow documentation

evaluations/         # Skill evaluation scenarios (per Anthropic best practices)
  build-skill.json          # 3 scenarios: TDD red phase, fix mode, design issue detection
  review-skill.json         # 3 scenarios: scope violation, weak tests, clean approval
  orchestrate-skill.json    # 3 scenarios: stage computation, escalation, resume

workflow/            # Legacy DEMS workflow docs (kept for reference)
```

## Role Hierarchy

```
Manual (you decide when):
  /wf-command-strategist  →  roadmap.yaml
  /wf-command-sa          →  master_backlog.yaml + COMPONENTS.yaml (with summaries)
  /wf-command-swa         →  sprint.yaml (with task contracts)

Automated (runs autonomously via /wf-command-pipeline):
  compute stages → plan worktrees → approve → execute (build + review) → merge
  → retrospective (+ lesson extraction & archival) → idle
```

## Skill Authoring Guides

When creating or modifying skills, consult these two docs:

- `docs/persuasion-principles.md` — Which persuasion principles to apply per skill type (authority for discipline, unity for collaboration, etc.)
- `docs/anthropic-best-practices.md` — Official Anthropic guidance: conciseness, degrees of freedom, progressive disclosure, description quality, evaluations

## Key Conventions

- **Skills** are SKILL.md files — pure markdown instructions that define a cognitive mode
- **State files** use YAML (`.workflow/current_task.yaml`, `review_ready.yaml`, `feedback.yaml`, `pipeline_state.yaml`, `metrics/sprint-<id>.yaml`, `metrics/trends.yaml`)
- **Architecture files** are committed to git: `COMPONENTS.yaml` (with `summary` fields), `master_backlog.yaml`, `sprint.yaml`, `roadmap.yaml`
- **Commands** have YAML frontmatter with a `description` field, then markdown body
- **Design issues** are written to `design_issues.yaml` when build/review encounter architectural problems that can't be fixed at the code level
- **Retrospectives** are generated automatically at pipeline end in `retrospective/<sprint-id>.md`, then archived to `retrospective/archive/` after lessons are extracted
- **Memory file** (`docs/MEMORY.yaml`) stores structured lessons extracted from retrospectives — consumed by build, review, and SWA skills
- **External skills** are configured in `config.yaml` under `external_skills` with `defaults` (applied to all tasks) and `domains` (matched by file path globs against `files_to_touch`). Skills are merged: defaults + matching domains = union. Build and review skills load the resolved set

## Architecture Governance

- `COMPONENTS.yaml` — component registry with boundaries, constraints, and dependency rules. `COMPONENTS.yaml` includes a `summary` field per component (2-3 sentences covering responsibility and key interfaces), replacing per-module ARCHITECTURE.md files
- The review skill checks architecture compliance as a P0 check

## Testing Changes

- **Skills**: Dry-run on a real project via `/wf-command-init` then `/wf-command-pipeline`. Verify sub-agents receive only their mandated context.
- **Install script**: Run `./install.sh` — it's idempotent (safe to re-run).

## Consistency Checks

When adding or modifying skills, commands, templates, or config fields, **always verify**:

- **`install.sh`** — Does it handle the new/changed artifact? Skills and commands are glob-based (auto-discovered), and the summary output should reflect any new artifact categories.
- **`commands/wf-command-init.md`** — Does the init command's example config, directory scaffolding, and `.gitignore` entries reflect the change? New config sections need to appear in the example block. New directories the pipeline expects must be created during init. New generated output directories should be gitignored.
- **`templates/workflow-config.yaml.tmpl`** — Is the canonical config template in sync with what init documents?

### Config ↔ Skill Consistency (mandatory on every update)

Every config field in `templates/workflow-config.yaml.tmpl` must be **read by at least one skill or command**. Every config field referenced by a skill must **exist in the template**. When modifying any skill or the config template:

1. **Forward check:** grep the template for all field names → confirm each is consumed by at least one skill/command. Flag any field with zero consumers as dead — either wire it or remove it.
2. **Reverse check:** grep all skills for `config.*`, `commands.*`, `paths.*`, `task_sizing.*`, `review.*`, `learning.*`, `observability.*`, `coverage.*`, `models.*`, `parallel.*` references → confirm each referenced field exists in the template with the exact same name (watch for snake_case mismatches).
3. **No hardcoded defaults that shadow config:** if a skill uses a value that is also in config (e.g., max attempts, sizing limits, directory paths), it must read from config with a fallback default — never hardcode the value and ignore the config field.

### Init Command: Zero-Config Setup Wizard

`commands/wf-command-init.md` must function as a **complete setup wizard**. After running `/wf-command-init` (any mode), the project must be fully ready to run the workflow toolkit with no further manual file creation. This means:

- **Every file referenced by `paths.*` in config** must either be scaffolded by init (from a template) or explicitly detected as already existing. If a skill expects a file at a config path and init doesn't create it, that's a bug.
- **Every directory the pipeline writes to** (`.workflow/metrics/`, `retrospective/`, `docs/adrs/`, etc.) must be created by init.
- **All three modes must stay in sync:** standard, deep, and migrate. When a new config section, template, scaffolded file, or directory is added:
  - Standard mode must scaffold it.
  - Deep mode must scaffold it (inherits from standard).
  - Migrate mode must detect its absence and add it.
- **The init config block must match `templates/workflow-config.yaml.tmpl` exactly** — no fields present in one but missing from the other.

## Collaboration Posture

When reviewing or extending the plan, your posture depends on what is needed:

- **SCOPE EXPANSION**: Build the cathedral. Push scope UP. Ask "what would make this 10x better for 2x the effort?" You have permission to dream.
- **HOLD SCOPE**: Rigorous reviewer. Make it bulletproof — catch every failure mode, test every edge case. Do not silently reduce OR expand.
- **SCOPE REDUCTION**: Surgeon. Find the minimum viable version. Cut everything else. Be ruthless.

Once a mode is selected, COMMIT to it. Do not silently drift. Raise concerns once, then execute faithfully.

Every time there is a update that impacts workflow. update `docs/WORKFLOW.md`.
