---
name: root-cause-tracing
description: Cross-cutting 4-phase debugging protocol (observe, hypothesise, test, fix). Activates when diagnosing failures to eliminate guess-and-check debugging.
user-invocable: false
---

# Root Cause Tracing — 4-Phase Debugging Protocol

## Purpose

Systematically diagnose failures by identifying the actual root cause before applying any fix. This protocol eliminates guess-and-check debugging, which wastes cycles and often introduces new bugs.

## When This Skill Activates

- A test fails unexpectedly.
- A build or lint command produces errors.
- Runtime behavior deviates from the specification.
- A previously passing check now fails.
- Feedback from review identifies a defect.

## Cardinal Rules

1. **Never guess-and-check.** Every action must test a specific, stated hypothesis.
2. **Never retry the same command hoping for different results.** If a command failed, something must change before running it again. Identify what.
3. **Each attempt must be different from the previous one.** If your fix didn't work, the hypothesis was wrong. Form a new one.
4. **Fix the root cause, not the symptom.** Suppressing an error message is not a fix. Making a test pass by weakening assertions is not a fix.
5. **One variable at a time.** Change one thing, then verify. Multi-variable changes make it impossible to know what worked.

## The 4 Phases

### Phase 1: Reproduce

**Goal:** See the failure yourself with fresh, unambiguous output.

**Steps:**
1. Run the exact failing command. Do not paraphrase it or run a "similar" command.
2. Capture the **complete** output — stdout, stderr, exit code.
3. Identify the **first** error in the output. Later errors are often cascading failures from the first.
4. Note the exact error message, file, and line number.

**Output format:**
```
REPRODUCE:
  Command: <exact command run>
  Exit code: <code>
  First error: <exact error message>
  Location: <file:line if available>
  Full output: <captured output, truncated if extremely long but preserving the error>
```

**Common mistakes in this phase:**
- Running a different command than the one that failed.
- Reading old/cached output instead of running fresh.
- Skipping to Phase 4 because you "already know" what's wrong.

### Phase 2: Hypothesize

**Goal:** Generate at least 3 plausible explanations for the failure, ranked by likelihood.

**Steps:**
1. Read the error message carefully. What is it literally telling you?
2. Read the code at the indicated location (file:line from Phase 1).
3. Trace the data flow backward: what inputs led to this state?
4. Generate **at least 3 hypotheses**. Even if you're 90% sure of one, list alternatives. Tunnel vision is the enemy.
5. Rank by likelihood, but don't discard low-probability options yet.

**Output format:**
```
HYPOTHESES:
  1. [HIGH] <description> — because <reasoning>
  2. [MEDIUM] <description> — because <reasoning>
  3. [LOW] <description> — because <reasoning>
```

**What makes a good hypothesis:**
- It is specific and testable. "Something is wrong with the config" is not a hypothesis. "The database URL is missing the port number" is.
- It explains the specific error, not just the general category.
- It accounts for why this worked before (if it did).

**Common mistakes in this phase:**
- Generating only one hypothesis (confirmation bias).
- Hypotheses that are too vague to test.
- Ignoring the error message in favor of gut feeling.

### Phase 3: Isolate

**Goal:** Determine which hypothesis is correct using minimal, targeted checks.

**Steps:**
1. For each hypothesis (starting with highest likelihood), design a **minimal check** that would confirm or refute it.
2. A check is NOT a fix attempt. It is an observation: reading a value, logging a variable, checking a file's contents, running a targeted subcommand.
3. Execute the check. Record the result.
4. If confirmed — proceed to Phase 4.
5. If refuted — move to the next hypothesis. Update rankings if new information emerges.
6. If ALL hypotheses are refuted — return to Phase 2 with the new information gathered. You now know more than before.

**Output format:**
```
ISOLATION:
  Testing hypothesis 1: <description>
    Check: <what you did>
    Result: <what you observed>
    Verdict: CONFIRMED / REFUTED

  Testing hypothesis 2: <description>
    Check: <what you did>
    Result: <what you observed>
    Verdict: CONFIRMED / REFUTED
```

**Design principles for checks:**
- Read before write. Inspect the current state before changing anything.
- Prefer non-destructive checks (reading files, printing variables) over destructive ones (changing code to see what happens).
- Each check should take seconds, not minutes. If it requires significant effort, break it into a smaller check first.

**Common mistakes in this phase:**
- Skipping isolation and jumping straight to a fix ("let me just try this").
- Running the full test suite instead of a targeted check.
- Changing code during isolation (this contaminates the environment).

### Phase 4: Fix

**Goal:** Apply the **smallest change** that resolves the confirmed root cause.

**Steps:**
1. State the confirmed root cause in one sentence.
2. Design the fix. It should be the minimal change that addresses the root cause.
3. Apply the fix.
4. Re-run the **exact same command** from Phase 1.
5. Verify the original error is gone.
6. Run the broader test suite to check for regressions.

**Output format:**
```
ROOT CAUSE: <one-sentence description>
FIX: <what was changed and why>
VERIFICATION:
  Command: <same command from Phase 1>
  Result: <PASS/FAIL>
  Regression check: <broader test results>
```

**What "smallest change" means:**
- If a variable name is wrong, rename it. Don't restructure the function.
- If an import is missing, add it. Don't reorganize the import block.
- If a condition is inverted, flip it. Don't rewrite the control flow.
- The fix should be obviously correct to a reviewer seeing it in isolation.

**Common mistakes in this phase:**
- Fixing the symptom instead of the cause (e.g., catching and swallowing an exception).
- Making the fix too large (bundling improvements with the bug fix).
- Not verifying with the original failing command.
- Not checking for regressions.

## Escalation

If you reach **3 failed fix attempts** on the same issue:

1. HALT. Do not attempt a 4th fix.
2. Compile a summary: what you tried, what each attempt revealed, your current best understanding.
3. Escalate to the user with this summary.
4. The summary should be useful to a human debugger — include the exact error, confirmed root cause (or best guess), and what has been ruled out.

## Anti-Patterns This Protocol Prevents

| Anti-Pattern | What Happens | Why It's Bad |
|-------------|-------------|-------------|
| Shotgun debugging | Try random changes until something works | You don't know what fixed it, and you may have introduced new bugs |
| Stack Overflow driven development | Copy-paste a solution without understanding the cause | The solution may not match your specific problem |
| Error suppression | Catch the exception / ignore the warning | The bug is still there; you've just hidden it |
| Retry-and-pray | Run the command again unchanged | Non-deterministic passes mask real issues |
| Scope explosion | Rewrite the whole module to fix one bug | Massive risk increase, review burden, potential regressions |
