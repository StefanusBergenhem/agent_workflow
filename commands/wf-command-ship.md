---
name: wf-command-ship
description: "Host-side validation gate. Runs full test suite (unit + integration + e2e + coverage + DB validation) and pushes to GitHub on success. Run this on the host after the pipeline completes in Docker."
---

Ship the sprint branch after full validation. This command runs on the **host machine** (not in Docker) where infrastructure (database, services) and GitHub access are available.

## Prerequisites

- The pipeline must have completed (all stages done, retrospective finished, phase is `idle`)
- You must be on the sprint branch (or it must exist locally)
- Infrastructure (DB, services) must be running for integration/e2e tests
- GitHub CLI (`gh`) must be configured for push and PR creation

## Steps

### 1. Verify pipeline completed

Read `.workflow/pipeline_state.yaml`. Check that `current_phase` is `idle`. If the pipeline is in any other phase (`executing_stage`, `e2e_validation`, `retrospective`, etc.), HALT and report: "Pipeline is still running. Wait for completion before shipping."

### 2. Identify sprint branch

Read `sprint_branch` from `.workflow/pipeline_state.yaml`. Check out the sprint branch if not already on it:
```bash
git checkout <sprint_branch>
```

### 3. Run full validation suite

Run each command from `.workflow/config.yaml` in order. Stop at the first failure. Pipe all output to `/tmp/` log files.

#### 3a. Unit tests
```bash
<commands.test_unit> > /tmp/ship-test-unit.log 2>&1
```
Read the log. If tests fail: print the failure summary and STOP. Do not continue.

#### 3b. Integration tests
```bash
<commands.test_integration> > /tmp/ship-test-integration.log 2>&1
```
Read the log. If tests fail: print the failure summary and STOP. Do not continue.

If `commands.test_integration` is not configured or empty, skip with a warning: "No integration test command configured. Skipping."

#### 3c. End-to-end tests
```bash
<commands.test_e2e> > /tmp/ship-test-e2e.log 2>&1
```
Read the log. If tests fail: print the failure summary and STOP. Do not continue.

If `commands.test_e2e` is not configured or empty, skip with a warning: "No e2e test command configured. Skipping."

#### 3d. Coverage check
```bash
<commands.coverage> > /tmp/ship-coverage.log 2>&1
```
Read the log. Parse coverage for all source files changed in this sprint (use `git diff main --name-only` to identify them). If any file is below `coverage.threshold` from config (default 90%), print the under-covered files with their percentages and STOP.

If `commands.coverage` is not configured, skip with a warning: "No coverage command configured. Skipping."

#### 3e. Database validation
```bash
<commands.db_validate> > /tmp/ship-db-validate.log 2>&1
```
Read the log. If validation fails: print the failure details and STOP.

If `commands.db_validate` is not configured or empty, skip silently.

### 4. Report results

Print a summary table:

```
=== Ship Validation Results ===

  Check              Status    Details
  Unit tests         PASS      42 tests passed
  Integration tests  PASS      8 tests passed
  E2E tests          SKIP      Not configured
  Coverage           PASS      All files >= 90%
  DB validation      PASS      Schema up to date

All checks passed.
```

### 5. Push and create PR

If all checks pass:
```bash
git push -u origin <sprint_branch>
```

Then create a pull request:
```bash
gh pr create \
  --base main \
  --head ${SPRINT_BRANCH} \
  --title "Sprint <sprint_id>: <sprint summary from sprint.yaml>" \
  --body "$(cat <<'EOF'
## Sprint Summary
<bullet list of completed tasks with their titles>

## Results
- **Completed:** <N> / <total> tasks
- **Escalated:** <list or "none">
- **Design issues:** <list or "none">

## Retrospective
See `.workflow/retrospective/<sprint-id>.md` for details.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Print the PR URL to the user.

### On failure

Print a clear report showing:
- Which check failed
- The last 20 lines of the relevant log file
- The full log file path for detailed inspection

Do NOT attempt to fix anything. Do NOT push. The user investigates and re-runs `/wf-command-ship` after fixing.

---

## Hard Constraints

- **Never push on failure.** Any single check failing means no push, no PR.
- **Never auto-fix.** Report and stop. The user or pipeline handles fixes.
- **Run checks in order.** Unit → Integration → E2E → Coverage → DB. Stop at first failure.
- **Log everything.** All command output goes to `/tmp/ship-*.log` files.
- **Host-only.** This command expects infrastructure access. If a test fails because infrastructure is unavailable, report it clearly — don't treat it as a test failure.
- **Always create a PR on success.** The pipeline no longer publishes — this command is the single entry point for pushing and creating PRs.
