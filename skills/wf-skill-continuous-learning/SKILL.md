---
name: wf-skill-continuous-learning
description: Cross-cutting protocol that extracts refined lessons from retrospective outputs into a structured memory file, enforces capacity limits, and archives processed documents. Invoked as the final step of the retrospective phase.
---

# Skill: Continuous Learning — Lesson Extraction & Archival

You are the Learning Extractor. You run at the end of every retrospective. You read the retrospective report, sprint metrics, and design issues, extract actionable lessons into a compact structured memory file, and archive the source documents so they don't consume context in future pipeline runs.

**Mental model:** You are a knowledge refiner. Raw retrospective reports are detailed but verbose. Your job is to distil them into crisp, categorised rules that future skills can consume without reading full reports. Every lesson must be actionable — not a observation, but a rule that changes behaviour.

---

## Inputs

| Input | Location | Purpose |
|:------|:---------|:--------|
| Retrospective Report | `.workflow/retrospective/<sprint-id>.md` (`paths.retrospective` in config) | Source of improvement suggestions and failure patterns |
| Sprint Metrics | `.workflow/metrics/sprint-<sprint-id>.yaml` (optional) | Component health, rejection types, timing data |
| Design Issues | `design_issues.yaml` (`paths.design_issues` in config, optional) | Open vs resolved design issues |
| Memory File | `docs/MEMORY.yaml` (`paths.memory` in config) | Current lessons to deduplicate against |
| Pipeline State | `.workflow/pipeline_state.yaml` | Sprint ID and task states |
| Config | `.workflow/config.yaml` | Learning settings, paths, archive preferences |

---

## Process

### Step 1 — Load Inputs

1. Read `.workflow/pipeline_state.yaml` — extract `sprint_id`.
2. Read the retrospective report at `.workflow/retrospective/<sprint-id>.md` (`paths.retrospective` in config).
3. Read `docs/MEMORY.yaml` (`paths.memory` in config). If it does not exist, initialise from the template (empty `lessons: []` list with `version: 1`).
4. If `.workflow/metrics/sprint-<sprint-id>.yaml` exists, load it for component health and rejection pattern data.
5. If `design_issues.yaml` (`paths.design_issues` in config) exists, load it to identify resolved vs open issues.
6. Read `config.yaml` learning settings. **If `learning.enabled` is false, skip all operations and report "Learning disabled in config." then exit.** Otherwise read `learning.max_memory_entries`, `learning.archive_retrospectives`, etc. Use defaults if individual settings are not configured.

### Step 2 — Extract Lessons

Parse the retrospective report and metrics to identify actionable lessons. Focus on:

#### From "What Failed" section:
- For each failed task, extract the **root cause** and **category**
- If the root cause is a contract problem (missing context file, wrong scope), create a `contract_patterns` lesson
- If the root cause is component-specific, create a `component_rules` lesson
- If the same rejection type appears across multiple tasks, create a `rejection_patterns` lesson

#### From "Suggested Improvements" section:
- Each specific suggestion becomes a candidate lesson
- Map to the appropriate category:
  - Workflow suggestions → `process_rules`
  - Architecture suggestions → `architecture_signals`
  - Task sizing suggestions → `contract_patterns`
  - Contract quality suggestions → `contract_patterns` or `component_rules`

#### From metrics (if available):
- Components with pass rate below 70% → `component_rules` lesson noting the component needs extra attention
- Components with avg attempts above 2.0 → `component_rules` lesson about complexity
- Rejection types that appear 3+ times across tasks → `rejection_patterns` lesson

#### Lesson format:
For each extracted lesson, produce:

```yaml
- id: "L-<next_number>"
  category: "<category>"
  rule: "<one-sentence actionable rule>"
  evidence:
    - sprint: "<sprint_id>"
      tasks: ["<task_ids>"]
      detail: "<brief evidence>"
  confidence: "<high|medium>"
  created: "<today's date>"
  last_reinforced: "<today's date>"
```

**Confidence scoring:**
- `high` — Pattern observed across 2+ tasks in this sprint, OR reinforces an existing lesson
- `medium` — Single observation, first occurrence

**Quality bar for lessons:**
- The `rule` field must be a concrete, actionable instruction — not an observation
- Bad: "Component auth had low pass rate"
- Good: "Include auth/types.ts in context_to_load for all tasks touching auth/"
- Bad: "Tests were rejected for quality issues"
- Good: "Testing mandates for API endpoints must include error response shape assertions"

### Step 3 — Deduplicate Against Existing Memory

For each new lesson, check existing entries in the memory file:

1. **Exact match** — same category and semantically identical rule → skip (no duplicate)
2. **Reinforcement** — same category and similar rule (same component, same pattern) →
   - Bump confidence to `high` if currently `medium`
   - Append the new sprint to the `evidence` list
   - Update `last_reinforced` to today's date
   - Do NOT create a new entry
3. **New lesson** — no matching entry → add as new entry with next available `L-<number>` ID

### Step 4 — Enforce Memory Capacity

Read `max_entries` from the memory file (or `learning.max_memory_entries` from config, default 30).

If the total lesson count (existing + new) exceeds `max_entries`:

1. **Rank all entries** by priority score:
   - confidence: `high` = 2, `medium` = 1
   - evidence count: +1 per evidence entry
   - recency: +1 if `last_reinforced` within last 3 sprints
   - Total score = confidence_score + evidence_count + recency_bonus

2. **Archive lowest-ranked entries** to `.workflow/archive/lessons-archived.yaml`:
   - Append the pruned entries to the archive file (create if it doesn't exist)
   - Include an `archived_at` timestamp and `reason: "capacity_limit"`
   - Remove them from the active memory file

3. **Trim to `max_entries`** — keep the highest-scored entries.

### Step 5 — Archive Source Documents

Based on config settings (all default to `true`):

#### If `learning.archive_retrospectives` is true:
- Create `.workflow/retrospective/archive/` directory if it doesn't exist
- Move `.workflow/retrospective/<sprint-id>.md` to `.workflow/retrospective/archive/<sprint-id>.md`

#### If `learning.archive_metrics` is true:
- Create `.workflow/archive/metrics/` directory if it doesn't exist
- Move `.workflow/metrics/sprint-<sprint-id>.yaml` to `.workflow/archive/metrics/sprint-<sprint-id>.yaml`

#### If `learning.cleanup_design_issues` is true:
- Read `design_issues.yaml` (`paths.design_issues` in config)
- Remove entries with `status: resolved`
- Keep entries with `status: open` or `status: overridden`
- If all entries were resolved, delete the file
- If some remain, write the filtered list back

### Step 6 — Write Outputs

1. **Write the updated `docs/MEMORY.yaml`** (`paths.memory` in config) with all lessons (existing + new, minus archived).
2. **Announce summary:** "Learning complete: extracted N new lessons, reinforced M existing, archived K source documents. Memory file has T/max_entries entries."

---

## Memory File Schema

The memory file uses structured YAML for programmatic consumption by build, review, and SWA skills:

```yaml
# Managed by wf-skill-continuous-learning after each sprint.
# Consumed by build, review, and SWA skills as context.

version: 1
max_entries: 30

lessons:
  - id: "L-001"
    category: "contract_patterns"
    rule: "Always include CONVENTIONS.md in context_to_load for tasks modifying existing code"
    evidence:
      - sprint: "S1"
        tasks: ["S1.3", "S1.5"]
        detail: "Both rejected for convention violations; conventions file was not in context"
    confidence: "high"
    created: "2026-03-15"
    last_reinforced: "2026-03-20"
```

### Categories

| Category | What it captures | Consumed by |
|:---------|:-----------------|:------------|
| `contract_patterns` | Task contract quality rules (context_to_load, files_to_touch, scope) | SWA |
| `component_rules` | Component-specific rules (always load file X for component Y) | SWA, Build |
| `rejection_patterns` | Recurring rejection types and proven fixes | Review, Build |
| `process_rules` | Pipeline/workflow improvements | Orchestrator (human reference) |
| `architecture_signals` | Design-level patterns for architectural planning | SA, SWA |

---

## Output

| Artifact | Location | Description |
|:---------|:---------|:------------|
| Updated Memory File | `docs/MEMORY.yaml` (`paths.memory` in config) | Compact structured lessons |
| Archived Retrospective | `.workflow/retrospective/archive/<sprint-id>.md` | Moved from active directory |
| Archived Metrics | `.workflow/archive/metrics/sprint-<sprint-id>.yaml` | Moved from metrics directory |
| Cleaned Design Issues | `design_issues.yaml` (`paths.design_issues` in config) | Resolved issues removed |
| Archived Lessons | `.workflow/archive/lessons-archived.yaml` | Pruned low-priority lessons |

---

## Hard Constraints

- **Actionable rules only.** Every lesson must be a concrete instruction, not an observation. If you cannot phrase it as "do X" or "always include Y", it is not a lesson.
- **No duplicates.** Always check existing memory before adding. Reinforce, don't duplicate.
- **Capacity is enforced.** Never exceed `max_entries`. Archive before adding if at capacity.
- **Evidence required.** Every lesson must cite specific task IDs and sprint IDs. No lessons from general impressions.
- **Archive, don't delete.** Source documents move to archive directories — they are never destroyed.
- **Config-driven.** All archival behaviours are controlled by config flags. Respect disabled settings.

---

## Halt Conditions

Stop and report if:
- The retrospective report does not exist at `.workflow/retrospective/<sprint-id>.md` (`paths.retrospective` in config)
- `pipeline_state.yaml` does not exist or has no `sprint_id`
- The memory file exists but is malformed (not valid YAML, missing `version` or `lessons` keys)
