---
name: wf-command-init
description: "Bootstrap .workflow/ in a new project — detect framework, create config, set up structure"
---

Initialize the workflow system for the current project.

## Steps

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
Pre-fill with detected values:
```yaml
project:
  name: <detected from directory name or manifest>
  language: <detected>
  framework: <detected>

paths:
  roadmap: "doc/ROADMAP.md"       # Adjust to project conventions
  sprint: "doc/SPRINT.md"
  state: "doc/STATE.md"
  architecture: []                 # List of architecture doc paths
  codebase: []                     # List of codebase doc paths

commands:
  test: <detected test command>    # e.g., "go test ./...", "npm test", "cargo test"
  lint: <detected lint command>
  build: <detected build command>
  preflight: ""                    # Custom preflight script path

workflow:
  max_review_attempts: 3
  max_files_per_task: 3
  max_lines_per_task: 150
  task_file: "current_task.yaml"
  review_file: "review_ready.yaml"
  feedback_file: "feedback.yaml"
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

### 6. Generate starter CLAUDE.md (if none exists)
If no `CLAUDE.md` exists in the project root, create one with:
- Project name and detected language/framework
- Reference to the workflow system
- TDD and clean code rules from global-claude.md
- Detected test/build/lint commands

If `CLAUDE.md` already exists, do NOT overwrite it. Report that it exists and suggest the user review it.

### 7. Create .claude/skills/ directory
Create `.claude/skills/` for per-project skill overrides. Project-level skills take precedence over global skills.

### 8. Report
Print a summary of what was created and detected. Suggest next steps:
- Review and customize `.workflow/config.yaml`
- Create roadmap/sprint/state docs if they do not exist
- Run `/wf-command-analyse` to cut the first sprint
