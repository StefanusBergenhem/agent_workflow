#!/usr/bin/env bash
# component-size-check.sh
# Warns when a component exceeds max_source_files or max_exported_symbols
# from COMPONENTS.yaml constraints.
# Exit 0 = non-blocking warning (agent should flag for SA review).
# This hook never blocks (never exit 2) — it only warns.

set -euo pipefail

COMPONENTS_FILE="COMPONENTS.yaml"

# ---- Guard: only run if COMPONENTS.yaml exists ----
if [ ! -f "$COMPONENTS_FILE" ]; then
    exit 0
fi

# ---- Parse components with their paths and constraints ----
declare -A COMPONENT_PATHS
declare -A COMPONENT_MAX_FILES
declare -A COMPONENT_MAX_EXPORTS
CURRENT_COMPONENT=""
IN_COMPONENTS=false
IN_CONSTRAINTS=false

while IFS= read -r line; do
    if echo "$line" | grep -qE '^\s*components:'; then
        IN_COMPONENTS=true
        continue
    fi
    # Stop at next top-level key
    if $IN_COMPONENTS && echo "$line" | grep -qE '^[a-zA-Z_]' && ! echo "$line" | grep -qE '^\s'; then
        break
    fi
    # Detect component name
    if $IN_COMPONENTS && echo "$line" | grep -qE '^\s{2}[a-zA-Z_][a-zA-Z0-9_-]*:'; then
        CURRENT_COMPONENT=$(echo "$line" | sed 's/^\s*//' | sed 's/:\s*$//')
        IN_CONSTRAINTS=false
    fi
    # Detect path
    if $IN_COMPONENTS && [ -n "$CURRENT_COMPONENT" ] && echo "$line" | grep -qE '^\s+path:'; then
        COMP_PATH=$(echo "$line" | sed 's/.*path:\s*//' | sed 's/^["'\'']//' | sed 's/["'\'']\s*$//' | xargs 2>/dev/null || true)
        if [ -n "$COMP_PATH" ]; then
            COMPONENT_PATHS["$CURRENT_COMPONENT"]="$COMP_PATH"
        fi
    fi
    # Detect constraints block
    if $IN_COMPONENTS && [ -n "$CURRENT_COMPONENT" ] && echo "$line" | grep -qE '^\s+constraints:'; then
        IN_CONSTRAINTS=true
        continue
    fi
    # Parse constraint values
    if $IN_CONSTRAINTS && echo "$line" | grep -qE '^\s+max_source_files:'; then
        MAX_FILES=$(echo "$line" | sed 's/.*max_source_files:\s*//' | xargs 2>/dev/null || true)
        if [ -n "$MAX_FILES" ]; then
            COMPONENT_MAX_FILES["$CURRENT_COMPONENT"]="$MAX_FILES"
        fi
    fi
    if $IN_CONSTRAINTS && echo "$line" | grep -qE '^\s+max_exported_symbols:'; then
        MAX_EXPORTS=$(echo "$line" | sed 's/.*max_exported_symbols:\s*//' | xargs 2>/dev/null || true)
        if [ -n "$MAX_EXPORTS" ]; then
            COMPONENT_MAX_EXPORTS["$CURRENT_COMPONENT"]="$MAX_EXPORTS"
        fi
    fi
    # End constraints on de-indent
    if $IN_CONSTRAINTS && echo "$line" | grep -qE '^\s{4}[a-zA-Z_]' && ! echo "$line" | grep -qE 'max_'; then
        IN_CONSTRAINTS=false
    fi
done < "$COMPONENTS_FILE"

if [ ${#COMPONENT_PATHS[@]} -eq 0 ]; then
    exit 0
fi

# ---- Check each component ----
WARNINGS=()

for comp in "${!COMPONENT_PATHS[@]}"; do
    COMP_PATH="${COMPONENT_PATHS[$comp]}"

    # Skip if directory doesn't exist
    [ ! -d "$COMP_PATH" ] && continue

    # Count source files (common extensions)
    FILE_COUNT=$(find "$COMP_PATH" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.go" -o -name "*.py" -o -name "*.rs" -o -name "*.java" -o -name "*.kt" -o -name "*.cs" \) ! -name "*.test.*" ! -name "*.spec.*" ! -name "*_test.*" 2>/dev/null | wc -l)

    # Count exported symbols (grep for export/public patterns)
    EXPORT_COUNT=$(grep -rE '^\s*(export\s+(default\s+)?(function|class|const|let|var|type|interface|enum)|pub\s+(fn|struct|enum|trait)|public\s+(class|interface|enum|static|void|int|string|bool|async)|func\s+[A-Z])' "$COMP_PATH" 2>/dev/null | grep -v "test\|spec\|_test" | wc -l || echo 0)

    # Check against max_source_files
    MAX_FILES="${COMPONENT_MAX_FILES[$comp]:-20}"
    if [ "$FILE_COUNT" -gt "$MAX_FILES" ]; then
        WARNINGS+=("Component '$comp': $FILE_COUNT source files (max: $MAX_FILES) — consider splitting")
    fi

    # Check against max_exported_symbols
    MAX_EXPORTS="${COMPONENT_MAX_EXPORTS[$comp]:-15}"
    if [ "$EXPORT_COUNT" -gt "$MAX_EXPORTS" ]; then
        WARNINGS+=("Component '$comp': ~$EXPORT_COUNT exported symbols (max: $MAX_EXPORTS) — consider narrowing interface")
    fi
done

# ---- Report (non-blocking) ----
if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "==========================================="
    echo "COMPONENT SIZE WARNING"
    echo "==========================================="
    echo ""
    for w in "${WARNINGS[@]}"; do
        echo "  ⚠ $w"
    done
    echo ""
    echo "NOTE: This is a non-blocking warning. The component may need restructuring."
    echo "Flag this for Solution Architect review via /wf-command-sa."
    echo ""
    echo "==========================================="
fi

exit 0
