#!/usr/bin/env bash
# post-build-suppression-scan.sh
# Scans git diff for lint/test suppression directives that should not be committed.
# Fails (exit 2) if any suppression patterns are found.
# Exit 2 = blocking error in Claude Code hooks.

set -euo pipefail

# ---- Suppression patterns to detect ----
# These are directives that silence linters, type checkers, or coverage tools.
PATTERNS=(
    "nolint"
    "eslint-disable"
    "@ts-ignore"
    "@ts-expect-error"
    "noqa"
    "pragma: no cover"
    "istanbul ignore"
    "NOSONAR"
)

# Build a combined grep pattern.
GREP_PATTERN=$(printf "%s\|" "${PATTERNS[@]}")
GREP_PATTERN="${GREP_PATTERN%\\|}"  # Remove trailing \|

# ---- Get the diff of added lines only ----
# We only care about lines being added (starting with +), not removed.
DIFF_OUTPUT=$(git diff 2>/dev/null || true)
CACHED_DIFF=$(git diff --cached 2>/dev/null || true)

COMBINED_DIFF="${DIFF_OUTPUT}${CACHED_DIFF:+$'\n'$CACHED_DIFF}"

if [ -z "$COMBINED_DIFF" ]; then
    exit 0
fi

# ---- Scan for suppressions in added lines ----
# Extract added lines with file context.
VIOLATIONS=$(echo "$COMBINED_DIFF" | grep -n "^+" | grep -v "^[0-9]*:+++" | grep -iE "$GREP_PATTERN" || true)

if [ -z "$VIOLATIONS" ]; then
    exit 0
fi

# ---- Get more precise file:line information ----
# Parse the diff to map violations to actual files and line numbers.
CURRENT_FILE=""
CURRENT_LINE=0
FOUND_VIOLATIONS=()

while IFS= read -r line; do
    # Track file changes.
    if echo "$line" | grep -qE '^\+\+\+ b/'; then
        CURRENT_FILE=$(echo "$line" | sed 's/^+++ b\///')
        continue
    fi

    # Track hunk headers for line numbers.
    if echo "$line" | grep -qE '^@@ '; then
        CURRENT_LINE=$(echo "$line" | sed 's/^@@ .* +\([0-9]*\).*/\1/')
        continue
    fi

    # Check added lines for suppression patterns.
    if echo "$line" | grep -qE '^\+[^+]'; then
        CLEAN_LINE=$(echo "$line" | sed 's/^+//')
        for pattern in "${PATTERNS[@]}"; do
            if echo "$CLEAN_LINE" | grep -qi "$pattern"; then
                FOUND_VIOLATIONS+=("${CURRENT_FILE:-unknown}:${CURRENT_LINE:-?}  ${CLEAN_LINE}")
                break
            fi
        done
    fi

    # Increment line counter for context.
    if echo "$line" | grep -qE '^\+|^ '; then
        CURRENT_LINE=$((CURRENT_LINE + 1))
    fi
done <<< "$COMBINED_DIFF"

if [ ${#FOUND_VIOLATIONS[@]} -eq 0 ]; then
    exit 0
fi

# ---- Report ----
echo "==========================================="
echo "SUPPRESSION SCAN FAILED"
echo "==========================================="
echo ""
echo "Lint/test suppression directives detected in your changes."
echo "These directives mask problems and must not be committed."
echo ""
echo "Violations found:"
echo ""
for v in "${FOUND_VIOLATIONS[@]}"; do
    echo "  $v"
done
echo ""
echo "Scanned patterns: ${PATTERNS[*]}"
echo ""
echo "ACTION REQUIRED:"
echo "  1. Remove each suppression directive."
echo "  2. Fix the underlying lint/type/coverage issue instead."
echo "  3. If suppression is truly necessary, document why and get explicit approval."
echo ""
echo "==========================================="
exit 2
