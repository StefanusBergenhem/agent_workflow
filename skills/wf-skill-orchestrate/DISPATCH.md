# Dispatch Protocol & Context Envelopes

## Dispatch Protocol

For every state transition that requires a sub-agent:

1. **Read state.** Load `.workflow/pipeline_state.yaml`. Verify the current phase.
2. **Verify gate.** Confirm all automatic gate conditions are met for this transition.
3. **Assemble context envelope.** Each sub-agent receives ONLY the files listed below for its phase. Sub-agents do not get other skills' definitions, pipeline state details, or files outside their scope.
   - **Metrics (observability):** After assembling the envelope, if `config.observability.enabled`, estimate context tokens by summing envelope file sizes and dividing by `config.observability.cost_estimation.token_ratio` (default: 4). Update the running average in `.workflow/metrics/sprint-<id>.yaml → cost_estimate.estimated_context_tokens.<phase>_avg`. Increment `cost_estimate.total_dispatches`.
4. **Select model.** Read `models.<phase>` from `config.yaml` (e.g., `models.build`, `models.review`). Pass this as the `model` parameter when spawning the Agent. If the key is missing, omit the model parameter (inherits the parent's model).
5. **Announce transition.** State: "Dispatching [skill] for task [task_id] with model [model] — transitioning from [old_phase] to [new_phase]."
   - **Metrics (observability):** If `config.observability.enabled`, record `started_at` timestamp for this dispatch in `.workflow/metrics/sprint-<id>.yaml → tasks.<task_id>.current_dispatch_started`.
6. **Spawn sub-agent.** Dispatch with the assembled context and the selected model.
7. **Wait.** Let the sub-agent complete its work.
8. **Read output.** Check the sub-agent's output artifacts (review_ready.yaml, feedback.yaml, design_issues.yaml, etc.).
9. **Update state.** Write the new phase to `pipeline_state.yaml`. Append to the history log.
   - **Metrics (observability):** If `config.observability.enabled`, compute dispatch duration from `current_dispatch_started` to now. Append to `tasks.<task_id>.build_durations` or `review_durations`. Update `attempts`, `outcome`, and `actual_files_modified`. If review returned REJECTED, append `feedback.yaml → failures[0].type` to `rejection_types`. See `skills/wf-skill-observability/SKILL.md` for full details.
10. **Gate check.** Verify automatic gate conditions are satisfied before proceeding.

## Context Envelopes

### Build Phase (per-task, in worktree)
Model: `config.yaml → models.build` (default: `sonnet`)
Sub-agent receives:
- `skills/wf-skill-build/SKILL.md`
- `skills/wf-skill-testing-anti-patterns/SKILL.md` (cross-cutting test quality rules)
- `config.yaml`
- `<worktree_path>/.workflow/current_task.yaml`
- `<worktree_path>/.workflow/feedback.yaml` (if exists — Fix Mode)
- Files listed in `context_to_load` from the task contract
- Memory file at `paths.memory`
- `COMPONENTS.yaml` (for design issue detection)
- External skills config from `config.external_skills` (if configured)

### Review Phase (per-task, in worktree)
Model: `config.yaml → models.review` (default: `sonnet`)
Sub-agent receives:
- `skills/wf-skill-review/SKILL.md`
- `skills/wf-skill-testing-anti-patterns/SKILL.md` (cross-cutting test quality rules)
- `config.yaml`
- `<worktree_path>/.workflow/current_task.yaml`
- `<worktree_path>/.workflow/review_ready.yaml`
- Git diff (via `git diff origin/<sprint_branch>` within the worktree)
- Memory file at `paths.memory`
- Conventions file(s) at `paths.conventions`
- `COMPONENTS.yaml` (for architecture compliance)
- External skills config from `config.external_skills` (if configured)

### Retrospective Phase
Model: `config.yaml → models.retrospective` (default: `sonnet`)
Sub-agent receives:
- `skills/wf-skill-retrospective/SKILL.md`
- `skills/wf-skill-continuous-learning/SKILL.md` (for lesson extraction at end of retrospective)
- `config.yaml`
- `.workflow/pipeline_state.yaml`
- `sprint.yaml`
- `design_issues.yaml` (if exists)
- `.workflow/metrics/sprint-<sprint-id>.yaml` (if exists — observability metrics)
- `.workflow/metrics/trends.yaml` (if exists — cross-sprint trends)
- Memory file at `paths.memory` (for deduplication during lesson extraction)
