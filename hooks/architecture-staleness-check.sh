#!/usr/bin/env bash
# architecture-staleness-check.sh
# Warns if source files in a component changed but its ARCHITECTURE.md wasn't updated.
# Exit 0 = non-blocking warning (reviewer will catch if significant).
# This hook never blocks (never exit 2) — it only warns.

set -euo pipefail

COMPONENTS_FILE="COMPONENTS.yaml"

# ---- Guard: only run if COMPONENTS.yaml exists ----
if [ ! -f "$COMPONENTS_FILE" ]; then
    exit 0
fi

# ---- Parse component paths from COMPONENTS.yaml ----
declare -A COMPONENT_PATHS
CURRENT_COMPONENT=""
IN_COMPONENTS=false

while IFS= read -r line; do
    if echo "$line" | grep -qE '^\s*components:'; then
        IN_COMPONENTS=true
        continue
    fi
    if $IN_COMPONENTS && echo "$line" | grep -qE '^[a-zA-Z_]' && ! echo "$line" | grep -qE '^\s'; then
        break
    fi
    if $IN_COMPONENTS && echo "$line" | grep -qE '^\s{2}[a-zA-Z_][a-zA-Z0-9_-]*:'; then
        CURRENT_COMPONENT=$(echo "$line" | sed 's/^\s*//' | sed 's/:\s*$//')
    fi
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

# ---- Get all modified files ----
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

# ---- Check each component for stale ARCHITECTURE.md ----
WARNINGS=()

for comp in "${!COMPONENT_PATHS[@]}"; do
    COMP_PATH="${COMPONENT_PATHS[$comp]}"
    ARCH_FILE="${COMP_PATH}ARCHITECTURE.md"

    # Check if any source files in this component were modified
    SOURCE_CHANGED=false
    while IFS= read -r modified_file; do
        [ -z "$modified_file" ] && continue
        if echo "$modified_file" | grep -q "^${COMP_PATH}" && ! echo "$modified_file" | grep -q "ARCHITECTURE.md"; then
            SOURCE_CHANGED=true
            break
        fi
    done <<< "$MODIFIED_FILES"

    if ! $SOURCE_CHANGED; then
        continue
    fi

    # Check if ARCHITECTURE.md exists and was NOT modified
    if [ -f "$ARCH_FILE" ]; then
        ARCH_MODIFIED=false
        while IFS= read -r modified_file; do
            if [ "$modified_file" = "$ARCH_FILE" ]; then
                ARCH_MODIFIED=true
                break
            fi
        done <<< "$MODIFIED_FILES"

        if ! $ARCH_MODIFIED; then
            WARNINGS+=("Component '$comp': source files changed in $COMP_PATH but $ARCH_FILE was not updated")
        fi
    fi
done

# ---- Report (non-blocking) ----
if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "==========================================="
    echo "ARCHITECTURE STALENESS WARNING"
    echo "==========================================="
    echo ""
    for w in "${WARNINGS[@]}"; do
        echo "  ⚠ $w"
    done
    echo ""
    echo "NOTE: This is a non-blocking warning. If the changes are significant"
    echo "(new interfaces, changed responsibilities, modified invariants),"
    echo "update the ARCHITECTURE.md file. The reviewer will check."
    echo ""
    echo "==========================================="
fi

exit 0
