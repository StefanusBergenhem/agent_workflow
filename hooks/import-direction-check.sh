#!/usr/bin/env bash
# import-direction-check.sh
# Enforces dependency_rules from COMPONENTS.yaml by checking import/require
# statements in modified files against allowed component dependencies.
# Exit 2 = blocking error in Claude Code hooks.

set -euo pipefail

# ---- Guard: pipeline-only — skip during manual/exploratory work ----
if [ ! -f ".workflow/pipeline_state.yaml" ] && [ ! -f ".workflow/current_task.yaml" ]; then
    exit 0
fi

COMPONENTS_FILE="COMPONENTS.yaml"

# ---- Guard: only run if COMPONENTS.yaml exists ----
if [ ! -f "$COMPONENTS_FILE" ]; then
    exit 0
fi

# ---- Parse dependency_rules from COMPONENTS.yaml ----
# Extract rules like: "ui must not import from database"
RULES=()
IN_RULES=false

while IFS= read -r line; do
    if echo "$line" | grep -qE '^\s*dependency_rules:'; then
        IN_RULES=true
        continue
    fi
    # Stop at next top-level key
    if $IN_RULES && echo "$line" | grep -qE '^[a-zA-Z_]'; then
        break
    fi
    if $IN_RULES && echo "$line" | grep -qE '^\s*-\s+'; then
        RULE=$(echo "$line" | sed 's/^\s*-\s*//' | sed 's/^["'\'']//' | sed 's/["'\'']\s*$//' | xargs 2>/dev/null || true)
        if [ -n "$RULE" ]; then
            RULES+=("$RULE")
        fi
    fi
done < "$COMPONENTS_FILE"

if [ ${#RULES[@]} -eq 0 ]; then
    exit 0
fi

# ---- Parse component paths from COMPONENTS.yaml ----
# Build a map of component_name -> path
declare -A COMPONENT_PATHS
CURRENT_COMPONENT=""
IN_COMPONENTS=false

while IFS= read -r line; do
    if echo "$line" | grep -qE '^\s*components:'; then
        IN_COMPONENTS=true
        continue
    fi
    # Stop at next top-level key (not indented under components)
    if $IN_COMPONENTS && echo "$line" | grep -qE '^[a-zA-Z_]' && ! echo "$line" | grep -qE '^\s'; then
        break
    fi
    # Detect component name (indented exactly 2 spaces, ends with colon)
    if $IN_COMPONENTS && echo "$line" | grep -qE '^\s{2}[a-zA-Z_][a-zA-Z0-9_-]*:$'; then
        CURRENT_COMPONENT=$(echo "$line" | sed 's/^\s*//' | sed 's/:\s*$//')
    fi
    # Detect path under component
    if $IN_COMPONENTS && [ -n "$CURRENT_COMPONENT" ] && echo "$line" | grep -qE '^\s+path:'; then
        COMP_PATH=$(echo "$line" | sed 's/.*path:\s*//' | sed 's/^["'\'']//' | sed 's/["'\'']\s*$//' | xargs 2>/dev/null || true)
        if [ -n "$COMP_PATH" ]; then
            COMPONENT_PATHS["$CURRENT_COMPONENT"]="$COMP_PATH"
        fi
    fi
done < "$COMPONENTS_FILE"

if [ ${#COMPONENT_PATHS[@]} -eq 0 ]; then
    exit 0
fi

# ---- Function: determine component for a file path ----
get_component_for_file() {
    local file_path="$1"
    for comp in "${!COMPONENT_PATHS[@]}"; do
        local comp_path="${COMPONENT_PATHS[$comp]}"
        if echo "$file_path" | grep -q "^${comp_path}"; then
            echo "$comp"
            return
        fi
    done
    echo ""
}

# ---- Get modified files ----
BASE_BRANCH="main"
if git rev-parse --verify origin/main >/dev/null 2>&1; then
    BASE_BRANCH="origin/main"
elif git rev-parse --verify origin/master >/dev/null 2>&1; then
    BASE_BRANCH="origin/master"
fi

MODIFIED_FILES=$(git diff --name-only "$BASE_BRANCH" 2>/dev/null || git diff --name-only HEAD 2>/dev/null || true)
if [ -z "$MODIFIED_FILES" ]; then
    MODIFIED_FILES=$(git diff --name-only --cached 2>/dev/null || true)
fi

if [ -z "$MODIFIED_FILES" ]; then
    exit 0
fi

# ---- Check import statements in modified files ----
VIOLATIONS=()

while IFS= read -r modified_file; do
    [ -z "$modified_file" ] && continue
    [ ! -f "$modified_file" ] && continue

    SOURCE_COMP=$(get_component_for_file "$modified_file")
    [ -z "$SOURCE_COMP" ] && continue

    # Extract import targets from the file
    # Handles: import X from 'path', require('path'), from path import X
    IMPORTS=$(grep -oE "(from\s+['\"][^'\"]+['\"]|require\s*\(\s*['\"][^'\"]+['\"]|from\s+\S+\s+import)" "$modified_file" 2>/dev/null || true)

    while IFS= read -r import_line; do
        [ -z "$import_line" ] && continue
        # Extract the path from the import
        IMPORT_PATH=$(echo "$import_line" | grep -oE "['\"][^'\"]+['\"]" | tr -d "'\"" || true)
        [ -z "$IMPORT_PATH" ] && continue

        # Determine the target component
        TARGET_COMP=$(get_component_for_file "$IMPORT_PATH")
        [ -z "$TARGET_COMP" ] && continue
        [ "$SOURCE_COMP" = "$TARGET_COMP" ] && continue

        # Check against rules
        for rule in "${RULES[@]}"; do
            # Parse "X must not import from Y" pattern
            if echo "$rule" | grep -qiE "must not import from|cannot import from|should not import from"; then
                FORBIDDEN_SOURCE=$(echo "$rule" | awk '{print $1}')
                FORBIDDEN_TARGET=$(echo "$rule" | awk '{print $NF}')
                if [ "$SOURCE_COMP" = "$FORBIDDEN_SOURCE" ] && [ "$TARGET_COMP" = "$FORBIDDEN_TARGET" ]; then
                    VIOLATIONS+=("$modified_file: $SOURCE_COMP imports from $TARGET_COMP (rule: $rule)")
                fi
            fi

            # Parse "no circular dependencies" — check if reverse dependency exists
            if echo "$rule" | grep -qiE "no circular"; then
                # Check if target also imports from source (in already-committed code)
                for target_file in $(find "${COMPONENT_PATHS[$TARGET_COMP]}" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.py" \) 2>/dev/null || true); do
                    if grep -q "${COMPONENT_PATHS[$SOURCE_COMP]}" "$target_file" 2>/dev/null; then
                        VIOLATIONS+=("$modified_file: circular dependency — $SOURCE_COMP imports from $TARGET_COMP, and $TARGET_COMP already imports from $SOURCE_COMP")
                        break
                    fi
                done
            fi
        done
    done <<< "$IMPORTS"
done <<< "$MODIFIED_FILES"

# ---- Report ----
if [ ${#VIOLATIONS[@]} -gt 0 ]; then
    echo "==========================================="
    echo "IMPORT DIRECTION CHECK FAILED"
    echo "==========================================="
    echo ""
    echo "The following imports violate dependency_rules in COMPONENTS.yaml:"
    echo ""
    for v in "${VIOLATIONS[@]}"; do
        echo "  - $v"
    done
    echo ""
    echo "Dependency rules:"
    for r in "${RULES[@]}"; do
        echo "  • $r"
    done
    echo ""
    echo "ACTION REQUIRED:"
    echo "  1. Remove or refactor the violating import"
    echo "  2. If the dependency is genuinely needed, request an amendment to COMPONENTS.yaml dependency_rules via /wf-command-sa"
    echo "  3. Write a design issue if this blocks the task"
    echo ""
    echo "==========================================="
    exit 2
fi

exit 0
