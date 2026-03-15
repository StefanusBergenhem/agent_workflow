---
description: "Run the build phase — execute the current task contract using TDD"
---

Load and execute the build skill.

1. Read `.workflow/config.yaml` for project paths and settings
2. Read `current_task.yaml` to load the active task contract
3. Check for `feedback.yaml`:
   - If it exists: enter **Fix Mode** — read feedback, focus only on listed failures, do not restart from scratch
   - If it does not exist: enter **Build Mode** — execute the full task contract
4. Follow the instructions in the `build` skill (skills/build/SKILL.md)
5. Execute TDD workflow: Red (write failing tests) -> Green (implement until tests pass) -> Refactor (clean up)
6. Run preflight checks and verification
7. On success, write `review_ready.yaml` with:
   - Files modified
   - TDD confirmation (red phase evidence, green phase evidence)
   - Preflight results
   - Test coverage claim
   - Doc updates applied
8. Update `.workflow/pipeline_state.yaml` to `phase: review`
