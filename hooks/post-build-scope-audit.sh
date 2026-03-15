#!/usr/bin/env bash
# post-build-scope-audit.sh
# Verifies that all modified files are listed in the task contract's files_to_touch.
# Fails (exit 2) if any modified file is outside scope.
# Exit 2 = blocking error in Claude Code hooks.

set -euo pipefail

TASK_FILE=".workflow/current_task.yaml"

# ---- Guard: only run during active build phase ----
if [ ! -f "$TASK_FILE" ]; then
    # No active task contract — nothing to audit.
    exit 0
fi

# ---- Parse files_to_touch from YAML ----
# Handles both formats:
#   files_to_touch:
#     - "file.ts"              (simple list)
#     - path: "file.ts"       (path-keyed list)
# Also handles nested under scope: block.
PARSING=false
ALLOWED_FILES=()

while IFS= read -r line; do
    # Detect start of files_to_touch block (at any indent level).
    if echo "$line" | grep -qE '^\s*files_to_touch:'; then
        PARSING=true
        continue
    fi

    # Stop parsing at next key at same or lower indent level.
    if $PARSING && echo "$line" | grep -qE '^[a-zA-Z_]'; then
        break
    fi
    if $PARSING && echo "$line" | grep -qE '^\s{1,2}[a-zA-Z_]' && ! echo "$line" | grep -qE '^\s*-'; then
        break
    fi

    # Collect list entries — handle both "- path: X" and "- X" formats.
    if $PARSING && echo "$line" | grep -qE '^\s*-\s+'; then
        # Try "- path: X" format first.
        FILE_ENTRY=$(echo "$line" | sed -n 's/.*path:\s*["'\'']\?\([^"'\'']*\)["'\'']\?.*/\1/p' | xargs 2>/dev/null || true)
        if [ -z "$FILE_ENTRY" ]; then
            # Fall back to "- X" format.
            FILE_ENTRY=$(echo "$line" | sed 's/^\s*-\s*//' | sed 's/^["'\'']//' | sed 's/["'\'']\s*$//' | xargs 2>/dev/null || true)
        fi
        if [ -n "$FILE_ENTRY" ]; then
            ALLOWED_FILES+=("$FILE_ENTRY")
        fi
    fi
done < "$TASK_FILE"

if [ ${#ALLOWED_FILES[@]} -eq 0 ]; then
    echo "SCOPE AUDIT: No files_to_touch found in $TASK_FILE — skipping audit."
    exit 0
fi

# ---- Determine base branch ----
BASE_BRANCH="main"
if git rev-parse --verify origin/main >/dev/null 2>&1; then
    BASE_BRANCH="origin/main"
elif git rev-parse --verify origin/master >/dev/null 2>&1; then
    BASE_BRANCH="origin/master"
elif git rev-parse --verify main >/dev/null 2>&1; then
    BASE_BRANCH="main"
elif git rev-parse --verify master >/dev/null 2>&1; then
    BASE_BRANCH="master"
fi

# ---- Get modified files ----
MODIFIED_FILES=$(git diff --name-only "$BASE_BRANCH" 2>/dev/null || git diff --name-only HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)

if [ -z "$MODIFIED_FILES" ]; then
    # Also check staged files.
    MODIFIED_FILES=$(git diff --name-only --cached 2>/dev/null || true)
fi

if [ -z "$MODIFIED_FILES" ]; then
    exit 0
fi

# ---- Compare: find unauthorized modifications ----
VIOLATIONS=()

while IFS= read -r modified_file; do
    [ -z "$modified_file" ] && continue

    FOUND=false
    for allowed in "${ALLOWED_FILES[@]}"; do
        if [ "$modified_file" = "$allowed" ]; then
            FOUND=true
            break
        fi
    done

    if ! $FOUND; then
        VIOLATIONS+=("$modified_file")
    fi
done <<< "$MODIFIED_FILES"

# ---- Report ----
if [ ${#VIOLATIONS[@]} -gt 0 ]; then
    echo "==========================================="
    echo "SCOPE AUDIT FAILED"
    echo "==========================================="
    echo ""
    echo "The following files were modified but are NOT listed in files_to_touch:"
    echo ""
    for v in "${VIOLATIONS[@]}"; do
        echo "  - $v"
    done
    echo ""
    echo "Authorized files (from $TASK_FILE):"
    for a in "${ALLOWED_FILES[@]}"; do
        echo "  + $a"
    done
    echo ""
    echo "ACTION REQUIRED:"
    echo "  1. Revert unauthorized changes: git checkout -- <file>"
    echo "  2. If the file genuinely needs changing, request a scope expansion."
    echo "  3. Do NOT proceed until scope is resolved."
    echo ""
    echo "==========================================="
    exit 2
fi

exit 0
