# Deployment Runbook

> **Agent use:** run `/deploy`. This file is the human reference and rollback reference.

<deploy_rules>
- Deployment is triggered ONLY when a feature is complete and verified by the QA Architect.
- Do NOT deploy mid-step.
- If preflight tests in `TESTING.md` fail, deploy is aborted.
</deploy_rules>

<execution_sequence>
**1. Backend Deploy**
`railway up --service backend`

**2. Backend Health Check (with timeout)**
Railway builds take 2–3 min. Poll until healthy or give up after 3 minutes (18 × 10s):
```bash
for i in $(seq 1 18); do
  curl -sf https://frontend-production-27f75.up.railway.app/health && echo " OK" && break
  echo "  Attempt $i/18 — not ready, waiting 10s..."; sleep 10
done
```
*(Expected: `{"status":"ok"}`. Halt if not healthy after 18 attempts).*

**3. Frontend Deploy**
`railway up --service frontend`

**4. Frontend Readiness Check (with timeout)**
Poll until the frontend returns HTTP 200 or give up after 3 minutes:
```bash
for i in $(seq 1 18); do
  curl -sf -o /dev/null https://frontend-production-27f75.up.railway.app && echo " OK" && break
  echo "  Attempt $i/18 — not ready, waiting 10s..."; sleep 10
done
```
*(Halt if not ready after 18 attempts. Do not run E2E against a down frontend).*

**5. Post-Deploy E2E Verification**
`cd e2e && npm install && npx playwright install chromium`
`cd e2e && BASE_URL=https://frontend-production-27f75.up.railway.app npm run test:e2e:prod > /tmp/dems-e2e-prod.log 2>&1`
</execution_sequence>

<rollback_procedure>
- Code Rollback: Handled via Railway dashboard (Redeploy previous build).
- DB Rollback: No `.down.sql` files exist. Architect must generate manual SQL if a schema rollback is required.
</rollback_procedure>