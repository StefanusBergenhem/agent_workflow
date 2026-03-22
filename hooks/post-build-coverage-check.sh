#!/usr/bin/env bash
# post-build-coverage-check.sh
# Validates that review_ready.yaml contains numeric coverage data (not narrative)
# and that all files meet the configured coverage threshold.
#
# Runs as a PostToolUse hook on Edit/Write.
# Exit 0 = pass, Exit 2 = block (Claude Code convention).
#
# Input: JSON on stdin from Claude Code hook system.

set -euo pipefail

# ---- Guard: pipeline-only — skip during manual/exploratory work ----
if [ ! -f ".workflow/pipeline_state.yaml" ] && [ ! -f ".workflow/current_task.yaml" ]; then
    exit 0
fi

# Only check when review_ready.yaml is being written
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')

if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != *"review_ready.yaml"* ]]; then
  exit 0
fi

# Check if the file exists
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Check if coverage_metrics section exists
if ! grep -q "coverage_metrics:" "$FILE_PATH" 2>/dev/null; then
  echo "BLOCKED: review_ready.yaml is missing 'coverage_metrics' section." >&2
  echo "The build skill must include coverage data. If commands.coverage is not" >&2
  echo "configured, set coverage_metrics.tool to 'not_configured'." >&2
  exit 2
fi

# If tool is "not_configured", that's acceptable — skip further checks
if grep -q 'tool:.*"not_configured"' "$FILE_PATH" 2>/dev/null || grep -q "tool:.*not_configured" "$FILE_PATH" 2>/dev/null; then
  exit 0
fi

# Check for narrative-style coverage (branches with string descriptions instead of numbers)
# This catches the old coverage_claim format that used narrative branch descriptions
if grep -q "coverage_claim:" "$FILE_PATH" 2>/dev/null; then
  if ! grep -q "coverage_metrics:" "$FILE_PATH" 2>/dev/null; then
    echo "BLOCKED: review_ready.yaml uses deprecated 'coverage_claim' format." >&2
    echo "Use 'coverage_metrics' with numeric line_coverage and branch_coverage values." >&2
    exit 2
  fi
fi

# Check that coverage data contains numeric values (line_coverage field)
if grep -q "coverage_metrics:" "$FILE_PATH" 2>/dev/null; then
  if ! grep -q "line_coverage:" "$FILE_PATH" 2>/dev/null; then
    echo "BLOCKED: coverage_metrics exists but contains no 'line_coverage' data." >&2
    echo "Run commands.coverage and record numeric coverage percentages per file." >&2
    exit 2
  fi

  # Check for any file with status: "fail"
  if grep -q 'status:.*"fail"' "$FILE_PATH" 2>/dev/null || grep -q "status:.*fail" "$FILE_PATH" 2>/dev/null; then
    echo "BLOCKED: One or more files in coverage_metrics have status: fail." >&2
    echo "All files in files_to_touch must meet the coverage threshold." >&2
    echo "Fix coverage before submitting for review." >&2
    exit 2
  fi
fi

# Check that test_files_created section exists
if ! grep -q "test_files_created:" "$FILE_PATH" 2>/dev/null; then
  echo "BLOCKED: review_ready.yaml is missing 'test_files_created' section." >&2
  echo "List all test files created, grouped by tier (unit, integration, e2e)." >&2
  exit 2
fi

exit 0
