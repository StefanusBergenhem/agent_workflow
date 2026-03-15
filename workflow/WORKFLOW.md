# DEMS — Operations Guide

## The Pipeline

```
/proj-analyse  →  /proj-plan  →  /proj-build  →  /proj-review
                            ^           |
                            |  rejected |
                            +-----------+
```

## Commands

| Command | Role | Reads | Writes |
| :--- | :--- | :--- | :--- |
| `/proj-analyse` | Analyst | `doc/system/MASTER_BACKLOG.md`, `STATE.md`, `CODEBASE.md` | Sprint cut → `SPRINT.md` (after your approval) |
| `/proj-plan` | Architect | `SPRINT.md`, live map, `MEMORY.md`, conventions | `.dems/current_task.xml` |
| `/proj-build` | Developer | `current_task.xml` or `feedback.xml` | code + tests + `.dems/review_ready.xml` |
| `/proj-review` | Reviewer | `current_task.xml`, `review_ready.xml`, `git diff` | approval or `.dems/feedback.xml` |
| `/proj-deploy` | Deploy Operator | `git status`, Railway | production deployment + E2E verification |

---

## Starting a New Sprint

1. Run `/proj-analyse` — Analyst reads the roadmap and proposes a sprint cut
2. Review the proposal; adjust if needed; confirm
3. Analyst writes it to `doc/system/SPRINT.md`

## Executing a Task

1. Run `/proj-plan` — Architect generates `.dems/current_task.xml`
2. Review the task contract; adjust if needed
3. Run `/proj-build` — Developer runs TDD loop + preflight + commits
4. Run `/proj-review` — Reviewer validates the work
   - **Approved:** `.dems/` files cleared; commit message suggested
   - **Rejected:** `.dems/feedback.xml` written; run `/proj-build` again

## After Review Approval

```bash
git push origin HEAD
```
Then follow `doc/workflow/GIT.md` for PR + merge. After merge, run `/proj-deploy`.

---

## Key Files

| File | Owner | Purpose |
| :--- | :--- | :--- |
| `doc/system/MASTER_BACKLOG.md` | You | Long-term roadmap |
| `doc/system/SPRINT.md` | Analyst | Active sprint |
| `doc/system/STATE.md` | Reviewer | Infrastructure facts, deferred items, known issues |
| `doc/system/MEMORY.md` | Reviewer | Cross-session lessons learned |
| `.dems/current_task.xml` | Architect | Active task contract |
| `.dems/review_ready.xml` | Developer | Handoff document |
| `.dems/feedback.xml` | Reviewer | Rejection reasons |
| `scripts/preflight.sh` | Developer | Quality gate |
| `scripts/map.sh` | Architect | Live context generator |

## Scripts

```bash
./scripts/preflight.sh          # Run backend + frontend checks
./scripts/preflight.sh backend  # Backend only
./scripts/preflight.sh frontend # Frontend only
./scripts/preflight.sh e2e      # E2E only (requires stack running)
./scripts/preflight.sh all      # Everything including e2e

./scripts/map.sh > .dems/context_map.txt  # Generate live map for /plan
```

## Guiding stars
* Agent-first. The repo is developed soley by claude code agents. Architectual desisions need to be taken with that in mind. Context window, seperation of concerns, rock solid validation strategy
* Validation is everything. Everything we do should have automatic test for everything from unit level (happy path, error path, edge cases), integration level and e2e. We should also have all best practice validation strategies like lint, static code analysis and so on.
* Built for production. Production grade code and procedures always
* Architecture that can scale. We still expect to potentially get more usecase, and we might need to scale also in deployment.
* Seperation of concern. No big monolith. 