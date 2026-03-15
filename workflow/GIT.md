# Git Workflow

## Architect — During Planning (`/plan`)

1. Fetch origin and create the feature branch from `origin/main`:
   `git fetch origin && git checkout -b <branch-name> origin/main`
2. Branch name: `<step_id>-<short-description>` — all lowercase, hyphens only.
   - Example: `D.4 Frontend Types` → `d4-frontend-types`
3. Write `.dems/current_task.xml` on this branch.

## Developer — Before Handoff (`/build`)

1. Stage and commit all modified files before writing `.dems/review_ready.xml`.
2. Commit message format: `<step_id> <title>` — match the task metadata exactly.
   - Example: `D.4 Frontend Types`
3. Do not push. The human pushes and opens the PR.

## Human — After Review Approval

1. Push the branch: `git push origin HEAD`
2. Open a PR targeting `main`. Title: same as the commit message.
3. Squash merge to keep `main` linear.
4. Delete the feature branch after merge.

## What Never Goes on Main

## What Never Goes on Main

- Failing tests.
- A step that has not passed QA review.
- Direct commits that bypass the task contract (no `current_task.xml` → no commit).
