#!/usr/bin/env bash
# post-build-tdd-evidence.sh
# Verifies that TDD evidence exists in review_ready.yaml before allowing
# the build phase to complete. Ensures the red phase was actually run
# and produced real test failures.

set -euo pipefail

# ---- Guard: pipeline-only — skip during manual/exploratory work ----
if [ ! -f ".workflow/pipeline_state.yaml" ] && [ ! -f ".workflow/current_task.yaml" ]; then
    exit 0
fi

REVIEW_FILE=".workflow/review_ready.yaml"

# ---- Check review_ready.yaml exists ----
if [ ! -f "$REVIEW_FILE" ]; then
    echo "==========================================="
    echo "TDD EVIDENCE CHECK FAILED"
    echo "==========================================="
    echo ""
    echo "File not found: $REVIEW_FILE"
    echo ""
    echo "The build phase must produce a review_ready.yaml with TDD evidence"
    echo "before the review phase can begin."
    echo ""
    echo "ACTION REQUIRED:"
    echo "  Write $REVIEW_FILE with tdd_evidence section including:"
    echo "    - tdd_evidence.red_phase.ran: true"
    echo "    - tdd_evidence.red_phase.failure_output: <actual test failure output>"
    echo ""
    echo "==========================================="
    exit 2
fi

# ---- Check tdd_evidence.red_phase.ran = true ----
RAN_VALUE=$(grep -A5 'red_phase:' "$REVIEW_FILE" | grep 'ran:' | head -1 | sed 's/.*ran:\s*//' | xargs || true)

if [ "$RAN_VALUE" != "true" ]; then
    echo "==========================================="
    echo "TDD EVIDENCE CHECK FAILED"
    echo "==========================================="
    echo ""
    echo "tdd_evidence.red_phase.ran is not 'true' in $REVIEW_FILE"
    echo "Found value: '${RAN_VALUE:-<missing>}'"
    echo ""
    echo "The red phase (writing failing tests before implementation) is mandatory."
    echo "You must run tests BEFORE writing the implementation and record the failures."
    echo ""
    echo "==========================================="
    exit 2
fi

# ---- Check failure_output is non-empty and contains failure indicators ----
# Extract failure_output value. Handle both single-line and multi-line (block scalar) formats.
FAILURE_OUTPUT=""

# Try single-line format: failure_output: "some text"
FAILURE_OUTPUT=$(grep 'failure_output:' "$REVIEW_FILE" | head -1 | sed 's/.*failure_output:\s*//' | sed 's/^["'\'']//' | sed 's/["'\'']\s*$//' | xargs || true)

# If single-line was empty, try multi-line block scalar (|, |-, >).
if [ -z "$FAILURE_OUTPUT" ]; then
    CAPTURE=false
    BLOCK_CONTENT=""
    while IFS= read -r line; do
        if echo "$line" | grep -qE '^\s*failure_output:\s*[|>]'; then
            CAPTURE=true
            continue
        fi
        if $CAPTURE; then
            # Stop at next key at same or lower indent level.
            if echo "$line" | grep -qE '^\s{0,4}[a-zA-Z_]' && [ -n "$BLOCK_CONTENT" ]; then
                break
            fi
            BLOCK_CONTENT="${BLOCK_CONTENT}${line}"$'\n'
        fi
    done < "$REVIEW_FILE"
    FAILURE_OUTPUT=$(echo "$BLOCK_CONTENT" | xargs || true)
fi

if [ -z "$FAILURE_OUTPUT" ]; then
    echo "==========================================="
    echo "TDD EVIDENCE CHECK FAILED"
    echo "==========================================="
    echo ""
    echo "tdd_evidence.red_phase.failure_output is empty in $REVIEW_FILE"
    echo ""
    echo "You must include the actual test failure output from the red phase."
    echo "This proves tests were written and run before the implementation."
    echo ""
    echo "==========================================="
    exit 2
fi

# ---- Check failure output contains actual failure indicators ----
FAILURE_INDICATORS="FAIL\|Error\|error\|failed\|assertion\|AssertionError\|FAILED\|expect\|Expected"

if ! echo "$FAILURE_OUTPUT" | grep -qiE "FAIL|Error|failed|assertion"; then
    echo "==========================================="
    echo "TDD EVIDENCE CHECK FAILED"
    echo "==========================================="
    echo ""
    echo "tdd_evidence.red_phase.failure_output does not contain failure indicators."
    echo ""
    echo "Expected at least one of: FAIL, Error, error, failed, assertion"
    echo ""
    echo "Content found:"
    echo "  $FAILURE_OUTPUT"
    echo ""
    echo "This suggests the red phase did not produce genuine test failures."
    echo "Paste the ACTUAL failing test output, not a summary."
    echo ""
    echo "==========================================="
    exit 2
fi

# All checks passed.
echo "TDD Evidence: PASSED — Red phase failures verified."
exit 0
