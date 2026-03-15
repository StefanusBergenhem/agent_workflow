# Claude Code Workflow Toolkit

A portable, project-agnostic skills framework for Claude Code. Each pipeline phase (analyse → plan → build → review) runs as a sub-agent with clean context, state persists to disk between phases, and mechanical hooks catch what instructions miss.

## Directory Structure

```
skills/              # Cognitive modes — each has a SKILL.md
  analyse/           # Strategic analyst (sprint cutting)
  plan/              # Engineering architect (task contracts)
  build/             # Disciplined developer (TDD execution)
  review/            # QA gatekeeper (adversarial review)
  orchestrate/       # Pipeline controller (state machine)
  scope-guard/       # Cross-cutting: file boundary enforcement
  root-cause-tracing/  # Cross-cutting: 4-phase debugging
  verification/      # Cross-cutting: evidence-based completion
  receiving-feedback/  # Cross-cutting: processing rejections
  testing-anti-patterns/  # Cross-cutting: test quality rules

commands/            # Slash commands (thin wrappers invoking skills)
  analyse.md, plan.md, build.md, review.md, pipeline.md, status.md, init.md
  proj-*.md          # Legacy DEMS-specific commands (kept for compat)

hooks/               # Mechanical enforcement (shell scripts)
  hooks.json         # Hook config (merges into settings.json)
  *.sh               # Exit 2 = blocking error, exit 0 = pass

templates/           # Project bootstrapping templates
  workflow-config.yaml.tmpl, task-contract.yaml.tmpl, project-claude.md.tmpl

workflow/            # Legacy DEMS workflow docs (kept for reference)
```

## Key Conventions

- **Skills** are SKILL.md files — pure markdown instructions that define a cognitive mode
- **State files** use YAML (`.workflow/current_task.yaml`, `review_ready.yaml`, `feedback.yaml`, `pipeline_state.yaml`)
- **Hook scripts** must exit 2 to block Claude (not exit 1 — that's non-blocking in Claude Code)
- **Hook input** arrives as JSON on stdin (not environment variables)
- **Schema consistency** matters: the build skill's `review_ready.yaml` uses `tdd_evidence.red_phase.ran: true` — hooks parse this exact structure
- **Commands** have YAML frontmatter with a `description` field, then markdown body

## Testing Changes

- **Hook scripts**: Test against known-good and known-bad git diffs. Each hook should pass cleanly on compliant changes and exit 2 with a clear message on violations.
- **Skills**: Dry-run on a real project via `/init` then `/pipeline`. Verify sub-agents receive only their mandated context.
- **Install script**: Run `./install.sh` — it's idempotent (safe to re-run).

## Collaboration Posture

When reviewing or extending the plan, your posture depends on what is needed:

- **SCOPE EXPANSION**: Build the cathedral. Push scope UP. Ask "what would make this 10x better for 2x the effort?" You have permission to dream.
- **HOLD SCOPE**: Rigorous reviewer. Make it bulletproof — catch every failure mode, test every edge case. Do not silently reduce OR expand.
- **SCOPE REDUCTION**: Surgeon. Find the minimum viable version. Cut everything else. Be ruthless.

Once a mode is selected, COMMIT to it. Do not silently drift. Raise concerns once, then execute faithfully.
