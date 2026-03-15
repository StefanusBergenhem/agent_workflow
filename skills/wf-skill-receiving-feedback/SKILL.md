---
name: wf-skill-receiving-feedback
description: Cross-cutting protocol for processing review rejections. Activates when feedback.yaml is present or a review returns REJECT. Enforces surgical fixes and escalation after 3 failed attempts.
user-invocable: false
---

# Receiving Feedback — How to Process Review Rejection

## Purpose

Define a disciplined protocol for responding to review feedback. This skill prevents the two most common failure modes: (1) ignoring feedback and resubmitting unchanged work, and (2) panicking and restarting from scratch, discarding good work along with the bad.

## When This Skill Activates

- A review phase returns a `REJECT` verdict.
- A `feedback.yaml` file is present with actionable items.
- The user provides corrections or change requests on submitted work.

## Protocol

### Step 0: Read the Feedback First

**Before doing ANYTHING else**, read `feedback.yaml` completely.

Do not:
- Start fixing things based on the rejection title alone.
- Assume you know what's wrong from the verdict.
- Begin re-running tests before understanding what failed.

Read the entire feedback file. Understand every item. Then proceed.

### Step 1: Acknowledge What Went Wrong

Before fixing, state explicitly what the issue was and why it happened. This is not performative — it builds better context for the fix.

**Format:**
```
FEEDBACK RECEIVED:
  Attempt: <N of 3>
  Items: <count>

  Item 1: <summary of feedback point>
    My understanding: <what went wrong and why>
    Category: [logic error | missing requirement | scope violation | test gap | style issue]

  Item 2: <summary of feedback point>
    My understanding: <what went wrong and why>
    Category: [logic error | missing requirement | scope violation | test gap | style issue]
```

This acknowledgment serves two purposes:
1. It forces you to understand the feedback before acting on it.
2. It creates a record that helps diagnose patterns if the same issue recurs.

### Step 2: Scope the Response

Address **ONLY** the listed failures. Do not:

- Fix things that weren't mentioned in feedback (scope creep).
- Refactor working code while fixing a bug (bundling).
- Restart implementation from scratch (nuclear option).
- Re-run passing tests unless the feedback specifically says they are wrong.

**Decision framework:**

| Feedback says... | You should... |
|-----------------|--------------|
| "Test X fails" | Fix the code or test that causes X to fail. Do not touch other tests. |
| "Missing edge case" | Add the specific edge case. Do not reorganize existing cases. |
| "Wrong approach" | Understand why the approach is wrong. Adjust the approach minimally. |
| "Style/formatting" | Apply the specific style fix. Do not reformat the entire file. |
| "Scope violation" | Revert the out-of-scope change. Do not replace it with a different out-of-scope change. |

### Step 3: Fix With Differentiation

Each fix attempt **must be different** from the previous one. If your last attempt didn't work, doing the same thing again will not help.

Before applying a fix, check:
- What did I try last time?
- Why didn't it work?
- What is specifically different about this attempt?

If you cannot articulate what is different, **stop and rethink**.

**Format:**
```
FIX PLAN:
  Item 1: <feedback point>
    Previous attempt: <what was tried before, or "first attempt">
    Why it failed: <reason, or "N/A">
    This attempt: <what will be done differently>
    Rationale: <why this should work>
```

### Step 4: Apply Fixes Incrementally

Do not batch all fixes into one big change. Fix one feedback item at a time:

1. Apply fix for item 1.
2. Verify item 1 is resolved (run the relevant check).
3. Apply fix for item 2.
4. Verify item 2 is resolved.
5. Continue until all items are addressed.
6. Run the full verification checklist (see Verification skill).

This prevents fix interactions — where fixing item 2 breaks the fix for item 1.

### Step 5: Track Attempt Number

Maintain a running count of attempts on the current task:

- **Attempt 1:** Normal fix cycle. Apply the protocol above.
- **Attempt 2:** Elevated attention. Before fixing, re-read the original specification to ensure you haven't drifted from the requirements. Consider whether the approach itself is flawed, not just the implementation.
- **Attempt 3:** **HALT.** Do not attempt a fix.

### Attempt 3 Escalation Protocol

If this is the third rejection on the same task:

1. **STOP all work.** Do not apply any more changes.
2. Compile a diagnostic summary:

```
ESCALATION — ATTEMPT 3 REACHED

Task: <task identifier>
Original requirement: <what was being built>

Attempt 1:
  What was done: <summary>
  Why it was rejected: <feedback summary>

Attempt 2:
  What was done differently: <summary>
  Why it was rejected: <feedback summary>

Attempt 3 analysis:
  Pattern: <what pattern do you see across the rejections?>
  Possible root cause: <why is this task repeatedly failing?>
  Recommendation: <what should change — approach, scope, specification?>
```

3. Present this to the user for guidance. The user may:
   - Clarify the requirement (it may have been ambiguous).
   - Adjust the scope (the task may be too large).
   - Provide a specific approach to follow.
   - Take over the problematic section manually.

## Rules for Preserving Good Work

When responding to feedback, protect what already works:

- **Do not modify files that aren't mentioned in feedback** — even if you notice something.
- **Do not re-run passing tests** unless feedback specifically questions their validity.
- **Do not remove or rewrite passing code** to fix a different issue.
- **Do not change the public API** of something that has passing consumers, unless feedback requires it.

The goal is a **surgical response**, not a renovation.

## Anti-Patterns

| Anti-Pattern | Why It's Bad | What To Do Instead |
|-------------|-------------|-------------------|
| "Let me start over" | Discards working code, resets progress, likely introduces new issues | Fix only what's broken |
| "I'll also fix this other thing" | Scope creep during fixes creates new failure surfaces | One feedback item at a time |
| "Running all tests to be safe" | Wastes time, may surface unrelated pre-existing failures that distract | Run only relevant tests, then full suite at the end |
| Repeating the same fix | Insanity. If it didn't work, it won't work. | Articulate what's different this time |
| Ignoring feedback reasoning | Treating feedback as a checklist without understanding the "why" | Read and acknowledge before fixing |
| Silent disagreement | Changing something other than what feedback requested because you think feedback is wrong | If you disagree, say so explicitly with reasoning. Do not silently substitute your judgment. |

## Relationship to Other Skills

- **Verification** provides the evidence standard for confirming each fix worked.
- **Root Cause Tracing** applies when feedback identifies a bug — use the 4-phase protocol to fix it properly.
- **Scope Guard** prevents fix attempts from touching files outside the contract.
