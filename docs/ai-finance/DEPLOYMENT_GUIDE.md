# Deployment guide

## API service

Leave the existing Railway service on root directory `apps/api`, Dockerfile `Dockerfile`, and start command `sh scripts/railway-start.sh`.

In Networking, set the target port on `api-zyvault-production.clawdage.com` to the same value as `PORT`. `GET /health` should return `{"status":"ok"}` before the phone is expected to work.

## Database

Run the full `apps/api/supabase/schema.sql` in the Supabase SQL editor once. It is additive. Confirm `financial_profiles` and `finance_jobs` exist. The API cannot create them.

## Redis

Add a Redis service in the same Railway project. Do not enable public networking. Copy its private URL into `REDIS_URL` on both the API and the worker.

## Worker service

Create a second Railway service from the same repo and the same `apps/api` root.

- Start command: `sh scripts/railway-start-worker.sh`
- Health check path: `/health`
- Same Supabase variables as the API
- `REDIS_URL` set to the private URL

The image copies `scripts/railway-start-worker.sh`. The worker listens on `PORT` and does not publish the ledger routes.

Locally, after `npm run build` in `apps/api`:

```
npm run start:worker
```

Without `REDIS_URL` the process stays up and logs that it is idle.
