# Dispatch Protocol & Context Envelopes

## Dispatch Protocol

For every state transition that requires a sub-agent:

1. **Read state.** Load `.workflow/pipeline_state.yaml`. Verify the current phase.
2. **Verify gate.** Confirm all automatic gate conditions are met for this transition.
3. **Assemble context envelope.** Each sub-agent receives ONLY the files listed below for its phase. Sub-agents do not get other skills' definitions, pipeline state details, or files outside their scope.
4. **Announce transition.** State: "Dispatching [skill] for task [task_id] — transitioning from [old_phase] to [new_phase]."
5. **Spawn sub-agent.** Dispatch with the assembled context.
6. **Wait.** Let the sub-agent complete its work.
7. **Read output.** Check the sub-agent's output artifacts (review_ready.yaml, feedback.yaml, design_issues.yaml, etc.).
8. **Update state.** Write the new phase to `pipeline_state.yaml`. Append to the history log.
9. **Gate check.** Verify automatic gate conditions are satisfied before proceeding.

## Context Envelopes

### Build Phase (per-task, in worktree)
Sub-agent receives:
- `skills/wf-skill-build/SKILL.md`
- `config.yaml`
- `<worktree_path>/.workflow/current_task.yaml`
- `<worktree_path>/.workflow/feedback.yaml` (if exists — Fix Mode)
- Files listed in `context_to_load` from the task contract
- Memory file at `paths.memory`
- `COMPONENTS.yaml` (for design issue detection)

### Review Phase (per-task, in worktree)
Sub-agent receives:
- `skills/wf-skill-review/SKILL.md`
- `config.yaml`
- `<worktree_path>/.workflow/current_task.yaml`
- `<worktree_path>/.workflow/review_ready.yaml`
- Git diff (via `git diff origin/<sprint_branch>` within the worktree)
- Memory file at `paths.memory`
- Conventions file(s) at `paths.conventions`
- `COMPONENTS.yaml` (for architecture compliance)
- Relevant `ARCHITECTURE.md` file(s) for the task's component

### Retrospective Phase
Sub-agent receives:
- `skills/wf-skill-retrospective/SKILL.md`
- `config.yaml`
- `.workflow/pipeline_state.yaml`
- `sprint.yaml`
- `design_issues.yaml` (if exists)
