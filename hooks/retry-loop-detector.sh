#!/usr/bin/env bash
# retry-loop-detector.sh
# Detects when the same bash command has been run 3+ times consecutively,
# which indicates a retry loop. Warns Claude to stop and diagnose.
# Exit 0 always — this is a warning, not a blocker.

set -euo pipefail

HISTORY_FILE="/tmp/.workflow-cmd-history"
MAX_HISTORY=20
CONSECUTIVE_THRESHOLD=3

# Read hook input from stdin (Claude Code passes JSON on stdin).
HOOK_INPUT=$(cat 2>/dev/null || true)

# Extract the tool input (the bash command) from the JSON.
# The JSON has a "tool_input" field with the command details.
LAST_CMD=""
if [ -n "$HOOK_INPUT" ]; then
    # Try to extract command from tool_input.command using basic parsing.
    LAST_CMD=$(echo "$HOOK_INPUT" | sed -n 's/.*"command"\s*:\s*"\([^"]*\)".*/\1/p' | head -1 || true)
fi

# If we could not determine the command, skip silently.
if [ -z "$LAST_CMD" ]; then
    exit 0
fi

# Append the command to history file.
echo "$LAST_CMD" >> "$HISTORY_FILE"

# Trim history file to last MAX_HISTORY entries to prevent unbounded growth.
if [ -f "$HISTORY_FILE" ]; then
    TOTAL_LINES=$(wc -l < "$HISTORY_FILE")
    if [ "$TOTAL_LINES" -gt "$MAX_HISTORY" ]; then
        tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp"
        mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
    fi
fi

# Read the last 5 entries and check for consecutive duplicates.
LAST_ENTRIES=$(tail -n 5 "$HISTORY_FILE" 2>/dev/null || true)

if [ -z "$LAST_ENTRIES" ]; then
    exit 0
fi

# Count consecutive identical commands from the end.
LAST_ENTRY=$(tail -n 1 "$HISTORY_FILE")
CONSECUTIVE=0

while IFS= read -r line; do
    if [ "$line" = "$LAST_ENTRY" ]; then
        CONSECUTIVE=$((CONSECUTIVE + 1))
    else
        CONSECUTIVE=0
    fi
done <<< "$LAST_ENTRIES"

if [ "$CONSECUTIVE" -ge "$CONSECUTIVE_THRESHOLD" ]; then
    echo "==========================================="
    echo "WARNING: RETRY LOOP DETECTED"
    echo "==========================================="
    echo ""
    echo "The same command has been executed ${CONSECUTIVE} times consecutively:"
    echo "  $LAST_ENTRY"
    echo ""
    echo "ACTION REQUIRED: HALT immediately."
    echo "  1. Do NOT run this command again."
    echo "  2. Invoke root-cause-tracing to diagnose the underlying issue."
    echo "  3. Identify WHY the command keeps failing or producing unsatisfactory results."
    echo "  4. Try a fundamentally different approach."
    echo ""
    echo "==========================================="
    # Exit 0 — this is a warning, not a blocker. The message itself instructs Claude to stop.
    exit 0
fi

exit 0
