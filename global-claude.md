# Global Workflow Rules

These rules apply to ALL projects using the Claude Code workflow system.

## TDD is Non-Negotiable

- Every code change must follow Red -> Green -> Refactor.
- Red phase: write tests first, confirm they fail.
- Green phase: write the minimum implementation to pass.
- Refactor phase: clean up without changing behavior.
- No code is considered complete without tests that would fail if the implementation were deleted.

## File Boundaries are Absolute

- Only modify files listed in the task contract (`files_to_touch`).
- If compilation or correctness requires touching another file, HALT and report.
- Do not expand scope independently. Ever.

## No Suppression Directives

These are banned in all code, no exceptions:
- `nolint`, `nolint:xxx` (Go)
- `eslint-disable`, `eslint-disable-next-line` (JavaScript/TypeScript)
- `@ts-ignore`, `@ts-expect-error` (TypeScript)
- `noqa`, `type: ignore` (Python)
- `#pragma warning disable` (.NET)
- Any equivalent in any language

If a linter or type checker flags an issue, fix the underlying problem.

## No Completion Claims Without Fresh Evidence

- Never claim "all tests pass" without running them in the current session.
- Never claim "preflight passes" without fresh output.
- Stale evidence (from a previous session or before recent changes) is not evidence.

## Retry Discipline

- Each retry must use a different approach than the previous attempt.
- On the 2nd consecutive failure, apply root-cause tracing before attempt 3.
- On the 3rd consecutive failure, HALT and escalate to the human.
- Never retry the same fix hoping for a different result.

## Context Window Management

- Pipe all test output to `/tmp` files: `command > /tmp/project-test.log 2>&1`
- Read the log file after, not the raw output.
- This prevents test output from consuming the context window.

## Skill Resolution Order

When loading a skill:
1. Check project-level: `.claude/skills/<skill-name>/` (project overrides)
2. Check global: `~/.claude/skills/<skill-name>/` (installed skills)
3. If neither exists: error — do not guess or improvise

## .workflow/ State Directory

The `.workflow/` directory in each project contains:
- `config.yaml` — project configuration (paths, commands, settings)
- `pipeline_state.yaml` — current pipeline phase and metadata
- `current_task.yaml` — active task contract (written by plan phase)
- `review_ready.yaml` — build completion claim (written by build phase)
- `feedback.yaml` — review rejection details (written by review phase)

These files are local workflow state and should be in `.gitignore`.
