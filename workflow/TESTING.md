# Testing Strategy & Commands

<agent_log_warning>
**CRITICAL FOR AI AGENTS:** 
To prevent context window exhaustion, NEVER run raw test commands if they might output thousands of lines. 
ALWAYS pipe test output to `.dems/test.log`, then read the file to analyze failures.
Example: `go test ./... > ../.dems/test.log`
</agent_log_warning>

<test_levels>
### Level 1 — Unit Tests (Always Required)
**Backend:** `cd backend && go test ./...`
**Frontend:** `cd frontend && npm test` (uses `vitest run` — single-pass, no flag needed)
- Covers: `internal/engine/`, `internal/importer/`, and React components/hooks.
- Rule: Handlers are tested via in-package stubs. No DB used here.

### Level 2 — Integration Tests (DB Touched)
**Backend:** `cd backend && DB_TEST_URL=postgres://dems:dems_local@localhost:5432/dems_test go test -tags=integration ./...`
- Covers: Real PostgreSQL DB, repository logic, migrations.
- Rule: Required if `.up.sql`, `repository/*.go`, or `handlers/*.go` are modified.
- Prerequisite: `docker compose up -d`

### Level 2b — Status Lifecycle Integration Tests (Mandatory for Validation Path)
A cross-boundary test that runs the full pipeline: engine → `SaveValidationResult` → `GetDoor` (or `ListDoors`) → assert `lastValidationStatus` on the response.

**Required when ANY of the following are modified:**
- `engine/engine.go` or any `engine/*.go` that touches `ValidationReport`
- `repository/door.go` (`SaveValidationResult`, `ListDoors`, `GetDoor`)
- Any handler that calls `SaveValidationResult`
- `getDoorComplianceStatus` in the frontend

**Mandatory cases (all three must exist as named integration test cases):**
1. Door with all required fields set + no conflicts → `lastValidationStatus = "pass"` in DB
2. Door with missing required fields + no conflicts → `lastValidationStatus = "incomplete"` in DB
3. Door with a critical conflict → `lastValidationStatus = "fail"` in DB with the failure in `lastValidationFailures`

These tests must be tagged `//go:build integration` and live in `backend/internal/repository/` or `backend/internal/handlers/`.

### Level 3 — E2E Tests
Playwright runs headlessly against the full stack. Two execution contexts:

**Local (pre-review — Developer runs this):**
`cd e2e && npm run test:e2e:local > ../.dems/e2e.log 2>&1`
- Requires `docker compose up -d --build` (already step 1 of preflight).
- Playwright will start containers automatically via `webServer` if not already running.

**Post-deploy (Architect runs after Railway deploy):**
`cd e2e && BASE_URL=https://frontend-production-27f75.up.railway.app npm run test:e2e:prod`
- See `doc/workflow/DEPLOY.md` for the full deploy + verify sequence.

**Required when ANY of the following are true:**
- A new page or route is added.
- A user-visible action is added or changed (button, form, panel, modal, sidebar).
- A critical path is touched: door import, validation, impact preview, door detail save.

**Not required when:**
- Only backend logic or DB schema changed with no UI surface change.
- A component is refactored but its visible behavior is identical.
- Only types, API client functions, or utility functions changed — **unless** those changes affect status display, filter logic, or compliance computation (e.g. `getDoorComplianceStatus`, `ListTab` status column, `ComplianceSummaryBar`). Changes to those always require E2E.
</test_levels>

### Level 2c — List/Detail Field Parity Tests
For any `ListDoors` or list-endpoint change: a test must assert that fields known to be used by the frontend (e.g. `notApplicableFields`, `lastValidationStatus`, `lastValidationFailures`) are present and non-null in the list response for a door that has those values set.

**Rule:** If `repository/door.go` (specifically `ListDoors`) is modified, or a new field is added to the `Door` domain type, add/update a parity integration test that fetches the same door via both `ListDoors` and `GetDoor` and asserts the field values match.

---

<preflight_sequence>
The Developer MUST execute these successfully before writing `.dems/review_ready.xml`:
1. `docker compose up -d --build`  ← rebuilds backend/frontend images from source before starting
2. `cd backend && go test ./... > /tmp/dems-test.log 2>&1`
3. `cd backend && DB_TEST_URL=... go test -tags=integration ./... > /tmp/dems-test-integration.log 2>&1`
4. `cd frontend && npm test > /tmp/dems-test-frontend.log 2>&1` (vitest run — single-pass)
5. `cd frontend && npm run build`
6. If e2e is required (see Level 3 rules): `cd e2e && npm run test:e2e:local > /tmp/dems-e2e.log 2>&1`

**Note:** If the task touches validation logic, `SaveValidationResult`, `ListDoors`, or `getDoorComplianceStatus`, Level 2b and/or 2c integration tests must also pass — confirm they exist and are covered by step 3 above.
</preflight_sequence>