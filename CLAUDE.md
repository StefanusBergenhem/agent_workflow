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
  wf-skill-orchestrate/       # Pipeline controller (state machine)
  wf-skill-retrospective/     # Sprint retrospective (analysis + improvement suggestions)
  wf-skill-scope-guard/       # Cross-cutting: file boundary enforcement
  wf-skill-root-cause-tracing/  # Cross-cutting: 4-phase debugging
  wf-skill-verification/      # Cross-cutting: evidence-based completion
  wf-skill-receiving-feedback/  # Cross-cutting: processing rejections
  wf-skill-testing-anti-patterns/  # Cross-cutting: test quality rules
  wf-skill-analyse/           # [DEPRECATED] Replaced by SA + SwA
  wf-skill-plan/              # [DEPRECATED] Replaced by SwA + orchestrator

commands/            # Slash commands (thin wrappers invoking skills)
  wf-command-strategist.md    # Product strategy session
  wf-command-sa.md            # Solution architecture session
  wf-command-swa.md           # Software architecture session
  wf-command-pipeline.md      # Run automated pipeline
  wf-command-build.md         # Manual build trigger
  wf-command-review.md        # Manual review trigger
  wf-command-status.md        # Pipeline status report
  wf-command-init.md          # Project bootstrap (standard + deep mode)
  wf-command-analyse.md       # [DEPRECATED]
  wf-command-plan.md          # [DEPRECATED]

hooks/               # Mechanical enforcement (shell scripts)
  hooks.json                   # Hook config (merges into settings.json)
  post-build-scope-audit.sh   # File boundary enforcement (blocking)
  post-build-suppression-scan.sh  # Lint suppression detection (blocking)
  import-direction-check.sh   # Dependency rule enforcement (blocking)
  component-size-check.sh     # Component size warnings (non-blocking)
  architecture-staleness-check.sh  # ARCHITECTURE.md staleness warnings (non-blocking)
  post-build-tdd-evidence.sh  # TDD evidence verification
  retry-loop-detector.sh      # Retry loop detection (blocking)

templates/           # Project bootstrapping templates
  workflow-config.yaml.tmpl    # .workflow/config.yaml starter
  task-contract.yaml.tmpl      # Task contract skeleton
  project-claude.md.tmpl       # Project CLAUDE.md starter
  components.yaml.tmpl         # COMPONENTS.yaml starter
  architecture.md.tmpl         # Per-module ARCHITECTURE.md starter
  master-backlog.yaml.tmpl     # master_backlog.yaml starter
  design-issues.yaml.tmpl      # design_issues.yaml starter
  sprint.yaml.tmpl             # sprint.yaml starter

workflow/            # Legacy DEMS workflow docs (kept for reference)
```

## Role Hierarchy

```
Manual (you decide when):
  /wf-command-strategist  →  roadmap.yaml
  /wf-command-sa          →  master_backlog.yaml + COMPONENTS.yaml + ARCHITECTURE.md
  /wf-command-swa         →  sprint.yaml (with task contracts)

Automated (runs autonomously via /wf-command-pipeline):
  compute stages → plan worktrees → approve → execute (build + review) → merge
  → retrospective → idle
```

## Key Conventions

- **Skills** are SKILL.md files — pure markdown instructions that define a cognitive mode
- **State files** use YAML (`.workflow/current_task.yaml`, `review_ready.yaml`, `feedback.yaml`, `pipeline_state.yaml`)
- **Architecture files** are committed to git: `COMPONENTS.yaml`, `*/ARCHITECTURE.md`, `master_backlog.yaml`, `sprint.yaml`, `roadmap.yaml`
- **Hook scripts** must exit 2 to block Claude (not exit 1 — that's non-blocking in Claude Code)
- **Hook input** arrives as JSON on stdin (not environment variables)
- **Schema consistency** matters: the build skill's `review_ready.yaml` uses `tdd_evidence.red_phase.ran: true` — hooks parse this exact structure
- **Commands** have YAML frontmatter with a `description` field, then markdown body
- **Design issues** are written to `design_issues.yaml` when build/review encounter architectural problems that can't be fixed at the code level
- **Retrospectives** are generated automatically at pipeline end in `retrospective/<sprint-id>.md`

## Architecture Governance

- `COMPONENTS.yaml` — component registry with boundaries, constraints, and dependency rules
- `*/ARCHITECTURE.md` — per-module responsibility, ownership, interfaces, invariants
- `dependency_rules` in `COMPONENTS.yaml` are enforced by the `import-direction-check.sh` hook
- Component size constraints are monitored by the `component-size-check.sh` hook
- Architecture staleness is flagged by the `architecture-staleness-check.sh` hook
- The review skill checks architecture compliance as a P0 check

## Testing Changes

- **Hook scripts**: Test against known-good and known-bad git diffs. Each hook should pass cleanly on compliant changes and exit 2 with a clear message on violations.
- **Skills**: Dry-run on a real project via `/wf-command-init` then `/wf-command-pipeline`. Verify sub-agents receive only their mandated context.
- **Install script**: Run `./install.sh` — it's idempotent (safe to re-run).

## Collaboration Posture

When reviewing or extending the plan, your posture depends on what is needed:

- **SCOPE EXPANSION**: Build the cathedral. Push scope UP. Ask "what would make this 10x better for 2x the effort?" You have permission to dream.
- **HOLD SCOPE**: Rigorous reviewer. Make it bulletproof — catch every failure mode, test every edge case. Do not silently reduce OR expand.
- **SCOPE REDUCTION**: Surgeon. Find the minimum viable version. Cut everything else. Be ruthless.

Once a mode is selected, COMMIT to it. Do not silently drift. Raise concerns once, then execute faithfully.

Every time there is a update that impacts workflow. update `docs/WORKFLOW.md`.
