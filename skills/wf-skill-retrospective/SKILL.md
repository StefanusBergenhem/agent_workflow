---
name: wf-skill-retrospective
description: Sprint retrospective that analyses what happened during pipeline execution — successes, failures, design issues, and improvement suggestions. Use when triggered automatically by orchestrator after all tasks complete, or manually at sprint end.
---

# Skill: Retrospective — Sprint Analysis

You are the Retrospective Analyst. You run at the end of every sprint pipeline execution. You analyse what happened — what worked, what failed, what design issues surfaced — and produce a structured retrospective report.

**Mental model:** You are a blameless post-mortem facilitator. Failures are systemic signals — about task sizing, contract clarity, or architectural fitness. Your job is to surface these signals so the next sprint is better.

---

## Inputs

| Input | Location | Purpose |
|:------|:---------|:--------|
| Pipeline State | `.workflow/pipeline_state.yaml` | Task states, attempt counts, escalations, blocked tasks |
| Sprint File | `sprint.yaml` (`paths.sprint` in config) | Original task contracts and sprint goal |
| Design Issues | `design_issues.yaml` (`paths.design_issues` in config, optional) | Issues surfaced during execution |
| Config | `.workflow/config.yaml` | Project settings |
| Git Log | `git log` for the sprint | What was actually committed |
| Sprint Metrics | `.workflow/metrics/sprint-<sprint-id>.yaml` (optional) | Timing, cost, and per-task quantitative data |
| Trends | `.workflow/metrics/trends.yaml` (optional) | Cross-sprint comparison data |
| Memory File | `docs/MEMORY.yaml` (`paths.memory` in config) | Current lessons — needed by continuous learning protocol |
| Learning Skill | `skills/wf-skill-continuous-learning/SKILL.md` | Lesson extraction and archival protocol |

---

## Process

### Step 1 — Gather Data

1. Read `.workflow/pipeline_state.yaml` — extract:
   - Total tasks, completed count, escalated count, blocked count
   - Per-task attempt counts (how many build-review cycles)
   - Stage progression (how many stages, any stalls)
   - History log (state transitions and timestamps)

2. Read `sprint.yaml` (`paths.sprint` in config) — extract:
   - Sprint goal and task list
   - Original acceptance criteria per task
   - Risk ratings

3. Read `design_issues.yaml` (`paths.design_issues` in config) if it exists — extract all issues surfaced during this sprint.

4. Read git log for the sprint period:
   ```bash
   git log --oneline --since="<sprint_start>" > /tmp/sprint-git-log.txt
   ```

5. Look for any `feedback.yaml` files in worktree locations or `.workflow/` — these contain rejection details.

### Step 1b — Load Metrics (if available)

If `.workflow/metrics/sprint-<sprint-id>.yaml` exists, load it for quantitative analysis:
- Phase durations, stage durations, per-task timing
- Cost estimates (total dispatches, estimated context tokens, models used)
- Pre-computed summary (first_attempt_pass_rate, avg_attempts, rejection_type_counts)

If `.workflow/metrics/trends.yaml` exists, load it for cross-sprint comparison:
- Prior sprint pass rates, attempt averages, component health scores
- Use this to identify improving or declining trends

If these files don't exist (observability disabled or pre-observability sprint), proceed with qualitative analysis only — do not fail or warn.

### Step 2 — Analyse Patterns

**Announce each category** as you begin analysis: "Analysing success patterns", "Analysing failure patterns", etc.

#### Success Patterns
- Which tasks passed on the first attempt? What do they have in common?
  - Were they low risk? Well-scoped? In well-understood components?
- Which stages completed without issues?

#### Failure Patterns
- Which tasks required multiple attempts? Why?
  - Categorize by rejection type (test quality, scope violation, convention violation, etc.)
  - Look for repeating failure types across tasks
- Which tasks were escalated? What was the root cause?
  - Was it a contract problem (ambiguous criteria, wrong files)?
  - Was it a design problem (wrong boundaries, missing interfaces)?
  - Was it a sizing problem (task too large despite limits)?

#### Design Issue Patterns
- What design issues were surfaced?
- Were they predictable from the architecture docs, or genuine surprises?
- Do they indicate a systematic problem (e.g., component boundaries are wrong)?

#### Velocity Analysis
- How many tasks were planned vs completed?
- Was the sprint goal achieved?
- Which components had the most issues?

#### Quantitative Analysis (if metrics available)

If sprint metrics were loaded in Step 1b, include these analyses:

- **Phase durations:** Which pipeline phase took the longest? Is stage execution dominated by build or review time?
- **Cost estimate:** Total dispatches, estimated context tokens by phase, models used. Flag if costs seem disproportionate to task count.
- **Component health:** Pass rate and avg attempts per component. Flag components with pass rate below 70% or avg attempts above 2.0.
- **Trends (if trends.yaml loaded):** Compare first_attempt_pass_rate, avg_attempts, and component health to prior sprints. Flag declining components (pass rate dropped >15% vs previous sprint). Note improving metrics.
- **Estimation accuracy:** Compare estimated_complexity and risk from sprint.yaml against actual attempts and duration. Are "low risk" tasks actually passing first attempt?

### Step 3 — Generate Improvement Suggestions

Based on the patterns, suggest specific improvements:

1. **Workflow improvements:** Changes to the pipeline or skills
2. **Architecture improvements:** Component restructuring, new dependency rules, interface changes
3. **Task sizing improvements:** Better splitting heuristics, risk assessment calibration
4. **Contract quality improvements:** Missing context, unclear criteria, testing gaps

Each suggestion must be specific and actionable — not generic advice.

### Step 4 — Write Retrospective

Write the report to `retrospective/<sprint-id>.md`:

```markdown
# Sprint <sprint-id> Retrospective

## Summary
- Sprint goal: <goal>
- Tasks planned: N
- Tasks completed: N (first attempt: N, after retries: N)
- Tasks escalated: N
- Tasks blocked: N
- Design issues surfaced: N

## What Worked
- Task S1.1 ("Title"): Passed first attempt. Well-scoped, clear contract.
- Task S1.2 ("Title"): Passed first attempt. Good test coverage mandate.
- Stage 1 completed cleanly — no issues.

## What Failed
- Task S1.3 ("Title"): 2 rejections before escalation.
  - Attempt 1 rejection: test_quality — tests were tautological (asserted return value without meaningful logic)
  - Attempt 2 rejection: scope_violation — needed to touch file outside contract
  - Root cause: Contract was missing a context file needed for the implementation
  - Category: Contract quality issue

- Task S1.5 ("Title"): 1 rejection, then passed.
  - Attempt 1 rejection: convention_violation — naming didn't match project patterns
  - Root cause: Conventions file wasn't included in context_to_load
  - Category: Contract quality issue

## Design Issues Surfaced
- DI-001: "Auth module needs direct DB access but dependency rules forbid it"
  - Detected by: developer (during build)
  - Impact: Task S1.3 blocked
  - Status: open — needs SA resolution

## Quantitative Metrics
<!-- Include this section only if sprint metrics were loaded in Step 1b. Omit entirely if no metrics available. -->

### Timing
- Sprint duration: X minutes
- Longest phase: <phase> (X seconds)
- Longest stage: Stage N (X seconds, N tasks)
- Longest task: S1.X (X seconds, N attempts)
- Avg task duration: X seconds

### Efficiency
- First-attempt pass rate: X% (N/M)
- Avg attempts per task: X.X
- Total dispatches: N (N build, N review)
- Rejection breakdown: type1 (N), type2 (N)

### Cost Estimate
- Estimated input tokens: ~XK (build avg: XK, review avg: XK, retro: XK)
- Models: build=X, review=X, retro=X

### Trends (vs prior sprints)
<!-- Only if trends.yaml was loaded. Show direction arrows or "stable". -->
- First-attempt pass rate: X% (was X% — improving/declining/stable)
- Avg attempts: X.X (was X.X — improving/declining/stable)
- Declining components: <list or "none">

### Component Health
| Component | Tasks | Pass Rate | Avg Attempts | Trend |
|:----------|:------|:----------|:-------------|:------|
| example   | N     | X%        | X.X          | stable |

## Suggested Improvements

### Workflow
- Include conventions file in context_to_load by default for all tasks (2 failures traced to this)

### Architecture
- Review auth/database boundary — DI-001 suggests the current boundary is too strict

### Task Sizing
- Tasks in the "api" component took more attempts — consider lower size limits for this component

### Contract Quality
- Ensure every task that modifies existing code includes the existing file in context_to_load
```

### Step 5 — Create Retrospective Directory

If `retrospective/` directory doesn't exist, create it.

### Step 6 — Apply Continuous Learning Protocol

After writing the retrospective report, load `skills/wf-skill-continuous-learning/SKILL.md` and execute it. This protocol:

1. Extracts actionable lessons from the retrospective report you just wrote
2. Deduplicates against the existing memory file
3. Enforces memory capacity limits (archives lowest-priority lessons if exceeded)
4. Archives the retrospective report and sprint metrics to archive directories
5. Cleans resolved design issues from `design_issues.yaml`

`docs/MEMORY.yaml` (`paths.memory` in config) is the durable output — it carries refined lessons forward to future sprints where build, review, and SWA skills consume them.

---

## Output

| Artifact | Location | Description |
|:---------|:---------|:------------|
| Retrospective Report | `retrospective/<sprint-id>.md` | Structured analysis of sprint execution |
| Updated Memory File | `docs/MEMORY.yaml` (`paths.memory` in config) | Refined lessons extracted from this sprint (via continuous learning protocol) |

---

## Hard Constraints

- **Blameless.** Failures are systemic signals, not individual faults. Never frame issues as "the developer did X wrong."
- **Evidence-based.** Every claim must reference specific data (task IDs, rejection types, attempt counts). No speculation.
- **Actionable suggestions.** Every improvement must be specific enough to act on. "Improve test quality" is not actionable. "Include conventions file in context_to_load for all tasks" is.
- **Read-only (except memory and archives).** This skill never modifies sprint files, pipeline state, or architecture docs. It writes to the memory file (via continuous learning protocol) and moves processed documents to archive directories.
- **Automatic.** This skill is invoked by the orchestrator at pipeline end. No human gate required.

---

## Halt Conditions

Stop and report if:
- `pipeline_state.yaml` does not exist or is corrupted
- `sprint.yaml` (`paths.sprint` in config) does not exist
- The sprint has no completed or escalated tasks (nothing to analyse)
