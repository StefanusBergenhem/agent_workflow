---
description: "Run the review phase — validate the build against the task contract"
---

Load and execute the review skill.

1. Read `.workflow/config.yaml` for project paths and settings
2. Read `current_task.yaml` (the contract — what was required)
3. Read `review_ready.yaml` (the claim — what was done)
4. Run `git diff` against the base branch to see the actual changes
5. Follow the instructions in the `review` skill (skills/review/SKILL.md)
6. Execute the full QA checklist: scope, acceptance criteria, test existence, test quality, TDD confirmation, docs, conventions, preflight, clean code, security
7. Decision:
   - **APPROVED:** Mark sprint step as done, commit, push branch, clean up task files, update `.workflow/pipeline_state.yaml` to `phase: plan` (or `phase: done` if sprint is complete)
   - **REJECTED:** Write `feedback.yaml` with precise failure descriptions and required actions, update `.workflow/pipeline_state.yaml` to `phase: build`, increment `attempt_count`
