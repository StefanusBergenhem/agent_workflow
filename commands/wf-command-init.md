---
name: wf-command-init
description: "Bootstrap .workflow/ in a new project — detect framework, create config, set up structure. Supports deep mode for existing codebases."
---

Initialize the workflow system for the current project.

## Mode Detection

- **`/wf-command-init`** — Standard init for a new or simple project
- **`/wf-command-init deep`** — Deep architectural analysis for existing codebases (generates `COMPONENTS.yaml`, per-module `ARCHITECTURE.md`, and architecture audit)

---

## Standard Init Steps

### 1. Create .workflow/ directory structure
```
.workflow/
  config.yaml          # Project-specific configuration
  pipeline_state.yaml  # Current pipeline state (phase, attempt count, etc.)
```

### 2. Detect language and framework
Scan the project root for:
- `package.json` -> Node.js (check for react, next, vue, angular, etc.)
- `go.mod` -> Go
- `Cargo.toml` -> Rust
- `pyproject.toml` / `requirements.txt` / `setup.py` -> Python
- `pom.xml` / `build.gradle` -> Java/Kotlin
- `*.csproj` / `*.sln` -> .NET

Record detected language and framework in config.

### 3. Generate .workflow/config.yaml
Use `templates/workflow-config.yaml.tmpl` as the source. Substitute template variables with detected values:
```yaml
version: 2

project:
  name: <detected from directory name or manifest>
  language: <detected>

paths:
  roadmap: "roadmap.yaml"
  sprint: "sprint.yaml"
  state: "docs/STATE.md"
  memory: "docs/MEMORY.md"
  architecture: "docs/ARCHITECTURE.md"
  conventions: "docs/CONVENTIONS.md"
  components: "COMPONENTS.yaml"
  master_backlog: "master_backlog.yaml"
  design_issues: "design_issues.yaml"

commands:
  test_unit: <detected>            # e.g., "go test ./...", "npm test", "cargo test"
  test_integration: ""             # fill in if applicable
  test_e2e: ""                     # fill in if applicable
  lint: <detected>
  type_check: <detected>           # e.g., "tsc --noEmit"
  compile_check: <detected>        # e.g., "go build ./..."
  preflight: <detected or "">      # combined pre-commit check
  context_map: ""                  # command to generate dependency map

review:
  max_attempts: 3
  escalation: halt

parallel:
  enabled: true
  worktree_base: ".claude/worktrees"
  merge_strategy: "branch-push"
  max_concurrent_tasks: 4

task_sizing:
  max_files_to_touch: 3
  max_context_files: 5
  max_estimated_lines: 150
```

### 4. Initialize pipeline state
Write `.workflow/pipeline_state.yaml`:
```yaml
phase: idle
active_task: null
attempt_count: 0
last_action: "Project initialized"
last_updated: <timestamp>
```

### 5. Add .workflow/ to .gitignore
Append `.workflow/` to `.gitignore` if not already present. The workflow state is local and should not be committed.

### 6. Scaffold architecture files
Create empty starter files:
- `COMPONENTS.yaml` — from `templates/components.yaml.tmpl` (empty component registry)
- `master_backlog.yaml` — from `templates/master-backlog.yaml.tmpl` (empty backlog)

### 7. Generate starter CLAUDE.md (if none exists)
If no `CLAUDE.md` exists in the project root, create one with:
- Project name and detected language/framework
- Reference to the workflow system
- TDD and clean code rules from global-claude.md
- Detected test/build/lint commands

If `CLAUDE.md` already exists, do NOT overwrite it. Report that it exists and suggest the user review it.

### 8. Create .claude/skills/ directory
Create `.claude/skills/` for per-project skill overrides. Project-level skills take precedence over global skills.

### 9. Report
Print a summary of what was created and detected. Suggest next steps:
- Review and customize `.workflow/config.yaml`
- Run `/wf-command-strategist` to create a product roadmap
- Run `/wf-command-sa` to define components and master backlog
- Run `/wf-command-swa` to detail the first sprint
- Run `/wf-command-pipeline` to execute the sprint

---

## Deep Init Mode (`/wf-command-init deep`)

For existing codebases that need architectural analysis. Performs all standard init steps PLUS:

### Step D1 — Spawn parallel Explore agents (up to 3)

Launch sub-agents to explore the existing codebase concurrently:

- **Agent 1 — Structure mapper:** Scan directory tree, identify top-level modules/packages, map import/dependency relationships between them. Produce a dependency graph.
- **Agent 2 — Responsibility analyzer:** For each module, read key files (entry points, main exports, route handlers, service classes) and summarize what each module does. Identify overlapping responsibilities.
- **Agent 3 — Size & complexity profiler:** Count source files per module, count exported symbols, identify large files (>300 lines), identify modules with high fan-in/fan-out.

### Step D2 — Generate `COMPONENTS.yaml`

Based on agent findings, produce initial `COMPONENTS.yaml`:
- One component per discovered module/package
- `owns` derived from responsibility analysis
- `depends_on` derived from import graph
- `exposes` derived from exported symbols
- `constraints` set to defaults (max 20 files, max 15 exports) — flag if already exceeded

### Step D3 — Generate per-module `ARCHITECTURE.md` files

For each component, create an `ARCHITECTURE.md` in the component's directory with:
- Responsibility summary (from Agent 2)
- Owns / Does NOT Own (inferred from imports and responsibility boundaries)
- Key Interfaces (from exported symbols)
- Invariants (left as TODOs for human to fill — agent can't reliably infer these)

### Step D4 — Produce Architecture Audit Checklist

Write `architecture_audit.md` in the project root identifying where the existing codebase violates guidelines:

```markdown
# Architecture Audit — <project name>

## Component Health

| Component | Files | Exports | Max Files | Max Exports | Status |
|-----------|-------|---------|-----------|-------------|--------|
| auth      | 12    | 8       | 20        | 15          | OK     |
| api       | 34    | 22      | 20        | 15          | OVER   |

## Separation of Concerns Issues
- Issues found with reasoning and suggested splits

## Dependency Direction Violations
- Import violations with specifics

## Duplication Concerns
- Duplicate logic across components

## Recommended Actions (Priority Order)
1. [ ] Prioritized action items
```

This checklist becomes input for the first `/wf-command-sa` session.

### Step D5 — Update config and report

- Update `.workflow/config.yaml` with component and audit paths
- Print summary of findings and suggested next steps:
  - "Review `COMPONENTS.yaml` — adjust component boundaries as needed"
  - "Review `architecture_audit.md` — prioritize cleanup items"
  - "Run `/wf-command-sa` to create master backlog addressing audit findings"
