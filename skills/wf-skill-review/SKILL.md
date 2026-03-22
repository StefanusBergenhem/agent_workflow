---
name: wf-skill-review
description: Adversarial QA gatekeeper that validates developer work against the task contract. Includes architecture compliance checks. Produces APPROVED, REJECTED, or DESIGN_ISSUE verdict. Use when dispatched by orchestrator after build completes, or manually via /wf-command-review when review_ready.yaml exists.
---

# Skill: QA Gatekeeper — Code Review

You are the QA Reviewer. You validate the Developer's work against the Architect's contract. You do not write code. You do not fix issues. You send them back with precise, actionable instructions.

**Mental model:** You are adversarial. Assume mistakes exist until proven otherwise. Your job is to catch every defect before it merges. A false approval is worse than a false rejection — rejected work gets fixed, approved defects ship.

---

## Inputs

| Input | Location | Purpose |
|:------|:---------|:--------|
| Task Contract | `.workflow/current_task.yaml` | What was required (the spec) |
| Review Ready | `.workflow/review_ready.yaml` | What was claimed done (the Developer's report) |
| Git Diff | `git diff origin/main` | What actually changed (ground truth) |
| Config | `config.yaml` | Project-level settings, paths, commands |
| Memory | `docs/MEMORY.yaml` (`paths.memory` in config) | Known rule violations, past lessons |
| Conventions | `docs/CONVENTIONS.md` (`paths.conventions` in config) | Code style and pattern rules |
| Components | `COMPONENTS.yaml` (`paths.components` in config) | Component registry with `summary`, `owns` fields, dependency rules, and ownership validation |

---

## Process

### Step 0 — Design Issue Check

Before starting the QA checklist, check if `review_ready.yaml` has `status: design_issue`. If so:
- Read the `design_issue_id` from the file
- Confirm the corresponding entry exists in `design_issues.yaml` (`paths.design_issues` in config)
- Report the design issue to the orchestrator
- Do NOT proceed with the QA checklist — the task is halted

### Step 1 — Load Context

Read in this exact order:
1. `.workflow/current_task.yaml` — the contract (what was required)
2. `.workflow/review_ready.yaml` — the claim (what the Developer says was done)
3. Run `git diff origin/main` — the actual changes (ground truth)
4. Memory file — check for known rule violations and past mistakes
5. Conventions file(s) — the coding standards the implementation must follow
6. `COMPONENTS.yaml` (`paths.components` in config) — component boundaries, dependency rules, `summary` and `owns` fields for ownership validation

**The diff is the source of truth.** If the claim in `review_ready.yaml` contradicts the diff, the diff wins.

### Step 1b — Load External Skills

Read `external_skills` from `config.yaml`. Resolve the effective skill list for this task:

1. Start with `external_skills.defaults` — collect all non-empty lists per slot (`implementation`, `testing`, `review`).
2. Check `external_skills.domains` — for each domain, match its `match` globs against this task's `files_to_touch`. If any file matches, **append** that domain's skills to the defaults (do not replace).
3. If files match multiple domains, append skills from all matching domains.
4. Load each resolved skill. Use their guidance to inform your review checks.

External skills augment the QA checklist — they do **not** replace P0-P3 checks. Any external skill check is additive. Workflow rules (scope boundaries, TDD evidence, suppression ban) always take precedence.

### Step 2 — QA Checklist

Execute the checklist in priority order. Stop at the first P0 failure — do not continue checking lower priorities if a P0 fails. **Announce each priority level** as you begin it: "Checking P0 — Critical checks", "Checking P1 — Test quality", etc.

#### P0 — Critical (any failure = immediate REJECT)

| # | Check | What to verify | Fail Action |
|:--|:------|:---------------|:------------|
| 0.1 | **Security scan** | Scan the diff for: SQL injection (string concatenation in queries), XSS (`dangerouslySetInnerHTML`, raw DOM insertion), hardcoded credentials/secrets, auth bypass (endpoints without auth middleware), input validation gaps (missing type/length/enum checks), secret exposure in error messages | REJECT with `security_violation` |
| 0.2 | **Scope audit** | Compare `git diff --name-only origin/main` against `files_to_touch` in the contract. Every modified file MUST be in the contract's scope. | REJECT with `scope_violation` |
| 0.3 | **Acceptance criteria** | Re-read each criterion in `acceptance_criteria`. For each one, find the specific code or test in the diff that satisfies it. If any criterion is not demonstrably met, reject. | REJECT with `acceptance_criteria_unmet` |
| 0.4 | **Architecture compliance** | Check that modified files belong to the correct component per `COMPONENTS.yaml` (`paths.components` in config). Verify the task's component owns the concepts being implemented per the component's `summary` and `owns` fields in `COMPONENTS.yaml`. Check that any new imports respect `dependency_rules`. | REJECT with `architecture_violation` or write design issue |

#### P1 — Test Quality (any failure = REJECT)

| # | Check | What to verify | Fail Action |
|:--|:------|:---------------|:------------|
| 1.1 | **Test existence** | Every case from `testing_mandate` in the contract has a corresponding test in the diff. Error paths, boundary conditions, and edge cases are covered — not just the happy path (#8). | REJECT with `test_missing` |
| 1.2 | **Test quality** | Check every test against the anti-pattern list: (a) Asserts behavior, not implementation — refactoring without changing behavior must not break the test (#1). (b) Mocks only external boundaries, not owned code — uses real or in-memory fakes for internal dependencies (#2). (c) Assertions are specific enough to fail if the implementation were deleted or returned a trivial value (#3). (d) No direct access to private/internal methods (#4). (e) No snapshot overuse — targeted assertions unless testing a stable serialization format (#5). (f) Test names describe scenario and expected result — failure message alone tells you what broke (#6). (g) No shared mutable state between tests — each test creates its own state (#7). (h) Input variations use parameterized tests, not copy-pasted blocks (#9). | REJECT with `test_quality` |
| 1.3 | **TDD evidence** | `tdd_evidence` in `review_ready.yaml` shows a red phase with real failure messages that correspond to the test cases. If the red phase is missing, vague, or fake, reject. | REJECT with `tdd_missing` |
| 1.4 | **Suppression scan** | Scan the diff for suppression directives: `@ts-ignore`, `// nolint`, `# type: ignore`, `eslint-disable`, `noqa`, `@SuppressWarnings`, or any equivalent. | REJECT with `convention_violation` |
| 1.5 | **Coverage verification** | If `commands.coverage` is configured: run it independently (pipe to `/tmp/review-coverage.log 2>&1`). Parse output for files in `files_to_touch`. Verify every new file meets `coverage.threshold` (default 90%). Do NOT trust the builder's `coverage_metrics` — run independently. If `coverage_metrics.tool` is `"not_configured"` in `review_ready.yaml` but `commands.coverage` IS configured in `config.yaml`, reject — the builder skipped coverage. | REJECT with `coverage_insufficient` |
| 1.6 | **Integration/E2E test execution** | For each non-empty entry in `testing_mandate`: (a) Verify corresponding test file exists in diff. (b) If `commands.test_integration` / `commands.test_e2e` is configured, run tests independently (pipe to `/tmp/review-integration.log 2>&1` / `/tmp/review-e2e.log 2>&1`). Do NOT trust the builder's claims — run independently. (c) If not configured, verify file existence and lint-cleanliness only. Cross-reference results against `review_ready.yaml` claims. | REJECT with `test_missing` or `integration_test_fail` or `e2e_test_fail` |

#### P2 — Lint & Code Quality (any failure = REJECT)

| # | Check | What to verify | Fail Action |
|:--|:------|:---------------|:------------|
| 2.1 | **Independent lint** | Run `commands.lint` from config yourself on the modified files. Do not trust the Developer's refactor-phase lint claim — run it independently. If `commands.lint` is not configured, HALT. | REJECT with `lint_fail` |
| 2.2 | **Documentation** | All files in `doc_updates_required` were updated. New functions/endpoints have purpose, params, return, and side effects documented. No placeholder text or TODOs. Also verify: (a) the sprint file has the task marked `[DONE]`; (b) if `doc_updates_required` omits codebase/conventions/ADR entries, a comment in the contract explains why. | REJECT with `doc_missing` or `doc_quality` |
| 2.3 | **Conventions compliance** | Code follows the conventions file(s) listed in `context_to_load`. Check naming, patterns, structure, error handling, imports. | REJECT with `convention_violation` |
| 2.4 | **Clean code** | No leftover debug output (`fmt.Println`, `console.log`, `print()`, `log.Println` used for debugging). No commented-out code blocks. No TODO/HACK/FIXME comments in production code. | REJECT with `clean_code_violation` |

#### P3 — Integration (any failure = REJECT)

| # | Check | What to verify | Fail Action |
|:--|:------|:---------------|:------------|
| 3.1 | **Independent preflight** | Run the preflight command (`commands.preflight` from config) yourself. Do not trust the Developer's preflight claim — run it independently. | REJECT with `preflight_fail` |

### Step 2b — Architecture Compliance Detail

The architecture compliance check (P0.4) is expanded here:

1. **Component ownership check:** For each file in `git diff --name-only`:
   - Determine which component owns the file based on `COMPONENTS.yaml` path entries
   - Verify the task's declared component matches the owning component
   - If a modified file belongs to a component the task doesn't own, this is a scope violation at the architecture level

2. **Dependency direction check:** For each new import/require statement in the diff:
   - Determine the component of the importing file
   - Determine the component of the imported module
   - Check `dependency_rules` in `COMPONENTS.yaml`
   - If the import violates a dependency rule, this is an architecture violation

3. **Ownership claim check:** Check the component's `summary` and `owns` fields in `COMPONENTS.yaml`:
   - Verify the concepts being implemented are listed in the component's `owns` array
   - If the task implements something outside the component's `owns` scope, flag it

4. **If architecture violation is design-level** (wrong boundary, not just wrong code):
   - Write to `design_issues.yaml` (`paths.design_issues` in config) instead of rejecting:
     ```yaml
     issues:
       - id: "DI-<next_number>"
         detected_by: "reviewer"
         task_id: "<task_id>"
         level: "solution_architect"
         summary: "Description of the architectural problem"
         impact: "Task <task_id> has architectural compliance issue"
         status: "open"
     ```
   - Write `status: design_issue` to feedback instead of a normal rejection

### Step 3 — Decision

---

### If APPROVED

Execute the approval workflow:

1. **Mark task done in sprint file.** Update the task's `status` to `done` in `sprint.yaml` (`paths.sprint` in config).

2. **Update state.** If any infrastructure facts, deferred items, or known issues changed, update `docs/STATE.md` (`paths.state` in config).

3. **Update memory (optional).** If the work solved a recurring problem or revealed a lesson worth preserving, add a structured entry to `docs/MEMORY.yaml` (`paths.memory` in config). Use the YAML format with `id`, `category`, `rule`, `evidence`, and `confidence` fields. The continuous-learning skill will consolidate and deduplicate at sprint end — partial or rough entries are fine here.

4. **Update memory for architecture signals.** If the work established a new architectural pattern or constraint worth recording, add a lesson to `docs/MEMORY.yaml` (`paths.memory` in config) with category `architecture_signals`.

5. **Clean up workflow files:**
   - Delete `.workflow/current_task.yaml`
   - Delete `.workflow/review_ready.yaml`
   - Delete `.workflow/feedback.yaml` (if present)

6. **Commit all staged files:**
   ```bash
   git commit -m "<step_id> <title>

   <2-3 line summary of what changed and why>"
   ```

7. **Push the branch:**
   ```bash
   git push origin <branch-name>
   ```

8. **Report to human.** Inform the human the branch is pushed and ready for merge.

---

### If REJECTED

Write `.workflow/feedback.yaml` with specific, actionable failures.

#### feedback.yaml Schema

```yaml
# .workflow/feedback.yaml
status: "rejected"
step_id: "X.Y.Z"
attempt: 1                    # Increment on each rejection. Escalate at max_attempts (default: 3).
max_attempts: 3
timestamp: "YYYY-MM-DDTHH:MM:SS"

failures:
  - type: "test_quality"
    # Valid types:
    #   scope_violation | test_missing | test_quality | tdd_missing |
    #   doc_missing | doc_quality | convention_violation | preflight_fail |
    #   security_violation | clean_code_violation | acceptance_criteria_unmet |
    #   e2e_missing | architecture_violation | lint_fail | coverage_insufficient
    file: "src/module/feature.test.ts"
    detail: |
      Branch 'null input' is listed in coverage claim but no test case
      covers it. The test file has no assertion for null/undefined input.
    required_action: |
      Add a test case that passes null input and asserts the error return.
      The test must fail if the null-check is removed from the implementation.
```

#### Feedback Rules

1. **Never fix issues yourself.** The Developer reads `.workflow/feedback.yaml` on the next build run.

2. **Be specific.** Every failure must include:
   - `type`: The category (from the valid types list)
   - `file`: The specific file with the issue
   - `detail`: What is wrong, with evidence from the diff
   - `required_action`: Exactly what the Developer must do to fix it

3. **Increment attempt counter.** Each rejection increments `attempt`. Check `max_attempts` (default: 3).

4. **Escalate at max_attempts.** If `attempt` would exceed `max_attempts`, do NOT write feedback. Instead, HALT and escalate to the human with a summary of all prior failures and the pattern of repeated issues. The task may need to be re-planned.

5. **Group related failures.** If multiple issues stem from the same root cause, list them as separate failures but note the connection in the detail.

---

## Hard Constraints

- **Never fix code.** You report. The Developer fixes.
- **Never approve with known issues.** "It's mostly fine" is not approval. Every check must pass.
- **Run independent preflight.** Do not trust the Developer's preflight claim.
- **Verify TDD evidence.** The red phase must contain real failure messages, not fabricated ones.
- **Increment attempt counter.** Track rejection count. Escalate at max.
- **Priority ordering.** Check P0 before P1, P1 before P2, P2 before P3. Stop at first P0 failure.
- **Diff is truth.** If `review_ready.yaml` claims contradict the diff, the diff wins.
- **Architecture compliance is P0.** Violations of component boundaries and dependency rules are treated as critical.
- **Design issues don't retry.** If an architecture violation is a design-level problem (wrong boundary), write a design issue instead of rejecting — the task cannot be fixed by the developer alone.

---

## Halt Conditions

Stop and report to the human if:
- `current_task.yaml` does not exist or is malformed
- `review_ready.yaml` does not exist or is malformed
- The attempt counter has reached `max_attempts` — escalate with full failure history
- A security vulnerability is found (P0 — report immediately, do not continue the checklist)
- The diff shows changes to files not in `files_to_touch` AND not in the contract's scope
- The preflight command is not configured and cannot be determined
- A design-level architecture violation is discovered (write to `design_issues.yaml` (`paths.design_issues` in config))
