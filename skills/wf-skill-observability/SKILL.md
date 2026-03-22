---
name: wf-skill-observability
description: Cross-cutting metrics collection and cost estimation. Instruments pipeline execution with timing, attempt counts, and context size tracking. Produces structured metrics consumed by retrospective.
user-invocable: false
---

# Observability — Pipeline Metrics Collection

## Purpose

Instrument the pipeline with structured metrics so the retrospective can produce quantitative analysis and trends can be tracked across sprints. This skill defines what data the orchestrator must capture and where to write it.

**Mental model:** You are a flight recorder. You capture timestamps, counts, and sizes at every state transition — silently, reliably, and without interfering with the pipeline. If metrics collection fails, the pipeline continues. Metrics are best-effort, never blocking.

---

## When This Skill Activates

This skill is **always active** during orchestrator execution when `config.observability.enabled` is `true` (default). It adds structured writes at natural state transition points in the dispatch protocol.

If `config.observability.enabled` is `false` or the `observability` section is missing from config, skip all metrics operations. The pipeline runs identically without metrics.

---

## Metrics Directory

All metrics files live in the directory specified by `observability.metrics_dir` in config (default: `.workflow/metrics/`), gitignored with the rest of `.workflow/`.

Create this directory at pipeline start if it doesn't exist.

---

## Collection Points

The orchestrator must record metrics at these points. Each maps to an existing dispatch protocol step or state transition.

### 1. Pipeline Start (Resume Detection)

When transitioning from `idle` to any active state:

1. Create `.workflow/metrics/` directory if it doesn't exist.
2. Initialize `.workflow/metrics/sprint-<sprint-id>.yaml` with:
   ```yaml
   sprint_id: "<sprint-id>"
   started_at: "<ISO 8601 timestamp>"
   completed_at: ""
   duration_minutes: 0
   pipeline_phases: {}
   stages: { total: 0, durations: {} }
   tasks: {}
   cost_estimate:
     total_dispatches: 0
     estimated_context_tokens: { build_avg: 0, review_avg: 0, retrospective: 0 }
     models_used: { build: "", review: "", retrospective: "" }
   summary: {}
   ```
3. Record `models_used` from `config.yaml → models`.

If resuming mid-sprint and the metrics file already exists, do NOT overwrite — continue appending to the existing file.

### 2. Phase Transitions

When recording a state transition in `pipeline_state.yaml`, also record it in the metrics file:

```yaml
pipeline_phases:
  <phase_name>:
    started_at: "<timestamp>"    # Set when entering the phase
    completed_at: "<timestamp>"  # Set when leaving the phase
    duration_seconds: <computed>  # completed_at - started_at
```

Record `started_at` when entering a phase. Record `completed_at` and compute `duration_seconds` when leaving it.

### 3. Stage Boundaries

When a stage starts (entering `planning_worktrees` or `executing_stage` for a new stage):
```yaml
stages:
  durations:
    <stage_number>:
      started_at: "<timestamp>"
      tasks_count: <number of tasks in stage>
```

When a stage completes (`stage_complete`):
```yaml
stages:
  durations:
    <stage_number>:
      completed_at: "<timestamp>"
      duration_seconds: <computed>
```

### 4. Sub-Agent Dispatch (Dispatch Protocol Steps 5 and 9)

**At Step 5 (Announce transition) — record dispatch start:**

For the current task, record in the metrics file:
```yaml
tasks:
  "<task_id>":
    component: "<from sprint.yaml>"       # First dispatch only
    risk: "<from sprint.yaml>"            # First dispatch only
    estimated_complexity: "<from task>"   # First dispatch only
    current_dispatch_started: "<timestamp>"
```

Increment `cost_estimate.total_dispatches`.

**At Step 3 (Assemble context envelope) — estimate context tokens:**

If `config.observability.cost_estimation.enabled` is true (default), estimate the total token count after assembling the context envelope:
- Sum the byte sizes of all files in the envelope
- Divide by `config.observability.cost_estimation.token_ratio` (default: 4)
- Record as a running average in `cost_estimate.estimated_context_tokens.<phase>_avg`

If `cost_estimation.enabled` is false, skip token estimation — leave `cost_estimate` fields at their initial values.

Formula for running average:
```
new_avg = ((old_avg * (dispatch_count - 1)) + new_value) / dispatch_count
```

**At Step 9 (Update state) — record dispatch completion:**

```yaml
tasks:
  "<task_id>":
    attempts: <current attempt_counter>
    build_durations: [<append seconds>]     # If this was a build dispatch
    review_durations: [<append seconds>]    # If this was a review dispatch
    outcome: "<current status>"             # Updated each dispatch
    rejection_types: [<append type>]        # If review returned REJECTED
    actual_files_modified: <count>          # From review_ready.yaml files_modified
```

Duration is computed from `current_dispatch_started` to now.

If the review returned REJECTED, extract the rejection type from `feedback.yaml → failures[0].type` and append to `rejection_types`.

### 5. Metrics Finalization (Before Retrospective Dispatch)

Before spawning the retrospective sub-agent, finalize the metrics file:

1. Set `completed_at` to current timestamp.
2. Compute `duration_minutes` from `started_at` to `completed_at`.
3. Compute `summary`:
   ```yaml
   summary:
     tasks_planned: <total tasks in sprint.yaml>
     tasks_completed: <tasks with outcome "completed">
     tasks_escalated: <tasks with outcome "escalated">
     tasks_blocked: <tasks with outcome "blocked">
     tasks_design_issue: <tasks with outcome "design_issue">
     first_attempt_pass_rate: <tasks completed with attempts=1 / tasks_completed>
     avg_attempts: <mean of attempts across completed tasks>
     longest_task: { id: "<task_id>", duration_seconds: <max total_duration_seconds> }
     rejection_type_counts: <aggregate rejection_types across all tasks>
   ```
4. Compute `total_duration_seconds` per task (sum of build_durations + review_durations).

### 6. Trends Append (Publishing Phase)

If `config.observability.trends.enabled` is true (default), after the retrospective completes, before or during the publishing phase, append a summary entry to `<metrics_dir>/trends.yaml`:

```yaml
sprints:
  - sprint_id: "<sprint-id>"
    completed_at: "<timestamp>"
    duration_minutes: <from metrics>
    tasks_planned: <from summary>
    tasks_completed: <from summary>
    first_attempt_pass_rate: <from summary>
    avg_attempts: <from summary>
    tasks_escalated: <from summary>
    total_dispatches: <from cost_estimate>
    component_health:
      <component>:
        tasks: <count of tasks in this component>
        pass_rate: <completed / total for this component>
        avg_attempts: <mean attempts for this component>
```

If `trends.yaml` doesn't exist, create it with a `sprints: []` list and append.

If `trends.yaml` has more entries than `config.observability.trends.max_sprints` (default: 20), remove the oldest entries to stay within the limit.

If `trends.enabled` is false, skip the trends append entirely.

---

## File Schemas

See the template files for full schemas:
- `templates/sprint-metrics.yaml.tmpl` — per-sprint metrics
- `templates/trends.yaml.tmpl` — cross-sprint trends

---

## Integration with Retrospective

The retrospective sub-agent receives the metrics files in its context envelope (added to DISPATCH.md). The retrospective skill uses these files to produce a "Quantitative Metrics" section in the retrospective report.

If the metrics files don't exist (backward compatibility or `observability.enabled: false`), the retrospective proceeds with qualitative analysis only.

---

## Hard Constraints

- **Never block the pipeline.** If a metrics write fails (file permission, corrupt YAML, missing directory), log the issue and continue. Metrics are best-effort.
- **Never modify pipeline state.** Metrics files are separate from `pipeline_state.yaml`. The orchestrator's state machine is unaffected by metrics.
- **Append-only for trends.** Never delete or modify existing entries in `trends.yaml` (except trimming old entries beyond `max_sprints`).
- **No sub-agent spawns.** This skill does not dispatch agents. It adds write operations to the orchestrator's existing state transitions.
- **Backward compatible.** All consumers (retrospective, status) must handle the case where metrics files don't exist.
- **Timestamps are ISO 8601.** Always use `YYYY-MM-DDTHH:MM:SS` format, consistent with `pipeline_state.yaml`.
- **Cost estimates are approximate.** The bytes-to-tokens heuristic is for trending, not billing. Document this in the metrics file header.
