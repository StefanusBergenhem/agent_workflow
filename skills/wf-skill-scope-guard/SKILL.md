---
name: wf-skill-scope-guard
description: Cross-cutting file boundary enforcement. Ensures the agent only modifies files listed in files_to_touch and reads files listed in context_to_load from the task contract.
user-invocable: false
---

# Scope Guard — File Boundary Enforcement

## Purpose

Ensure the agent only modifies files explicitly listed in `files_to_touch` and only reads files listed in `context_to_load` from the active task contract. This prevents scope creep at the file level — the most common way agentic work silently derails.

## When This Skill Activates

This skill is **always active** during any build or fix phase. It runs as a background constraint, not as an explicit step. Every file operation must pass through this gate.

## The Contract

The task contract (from the plan phase) contains two authoritative lists:

- **`files_to_touch`** — Files the agent is authorized to create or modify.
- **`context_to_load`** — Files the agent is authorized to read for understanding. These are read-only; modifying them is a violation.

If either list is missing from the contract, **HALT immediately** and request clarification. Do not infer scope.

## Protocol

### Before Every File Edit

1. Check: Is this file path in `files_to_touch`?
2. If **YES** — proceed with the edit.
3. If **NO** — do NOT edit. Instead:
   - HALT the current operation.
   - Report the violation: which file, why you believe it needs changing, and what change you intended.
   - Wait for explicit authorization before proceeding.
   - If authorized, note the scope expansion in the task log.

### Before Every File Read

1. Check: Is this file path in `files_to_touch` OR `context_to_load`?
2. If **YES** — proceed with the read.
3. If **NO** — you may read it for orientation (e.g., understanding an import chain), but:
   - Do not treat its contents as part of the task scope.
   - Do not modify it under any circumstances.
   - If the file turns out to be essential context, report it as a missing dependency: "File X should be added to `context_to_load` because Y."

### After Every Edit Session (Self-Check)

Run the following verification before claiming any step is complete:

```bash
# Get list of files actually modified
git diff --name-only

# If there are staged changes too
git diff --name-only --cached
```

Compare the output against `files_to_touch`. The sets must match:

- **Files modified but NOT in `files_to_touch`** — This is a scope violation. Revert the unauthorized change immediately with `git checkout -- <file>` and report why the change seemed necessary.
- **Files in `files_to_touch` but NOT modified** — This is acceptable (not every listed file must change), but note it. If a file was listed as needing changes but didn't require any, that's useful feedback for the plan.

### On Scope Expansion Requests

Sometimes you genuinely discover that a file outside scope needs changing (e.g., a shared utility has a bug, a type definition is wrong). The correct response is:

1. **Do not fix it silently.** This is the cardinal rule.
2. Document the discovery: what file, what's wrong, why it matters for the current task.
3. Propose a scope expansion with justification.
4. Wait for approval.
5. If approved, add the file to the working `files_to_touch` list and proceed.
6. If denied, find a workaround within the current scope or mark the task as blocked.

## Common Violations to Watch For

| Violation | Example | Correct Response |
|-----------|---------|-----------------|
| Drive-by fix | Fixing a typo in an unrelated file while passing through | Revert. Log the typo for a separate task. |
| Implicit dependency edit | Changing a shared config because your feature needs a new setting | HALT. Report the dependency. Request scope expansion. |
| Test file drift | Adding tests in a file not listed in `files_to_touch` | HALT. The test file should have been in the plan. |
| Refactoring temptation | Cleaning up code you read in `context_to_load` | Do not touch. `context_to_load` is read-only. |
| New file creation | Creating a helper file that wasn't planned | HALT. New files must be explicitly authorized. |

## Component Ownership Resolution

When determining which component owns a file (used by build, review, and swa skills):

1. **Longest prefix match**: A file belongs to the component whose `path` in `COMPONENTS.yaml` (`paths.components` in config) is the longest prefix match for that file's path.
2. **No match**: If no component path matches, the file is unowned — HALT and report.
3. **Shared utilities**: Ownership belongs to the component that *defines* the interface, not its consumers.

This is the authoritative definition. All skills referencing "component ownership" defer to this rule.

## Integration with Verification

The verification skill's completion checklist includes a scope check. This skill provides the mechanism; verification provides the gate. They work together — scope-guard prevents violations in real-time, verification catches any that slipped through.

## Key Principle

**The plan decides what to touch. The builder decides how to touch it.** If you find yourself wanting to change the "what," you are no longer building — you are replanning. Stop and escalate.
