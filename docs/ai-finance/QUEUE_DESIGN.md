# Queue design

One worker process listens to five queues:

- `financial-analysis` rebuilds the overview cache
- `cash-flow-forecast` stores a forecast snapshot
- `ai-insights` stores insight rows and evidence
- `spending-analysis` upserts anomaly fingerprints
- `scheduled-reports` runs the forecast, insights, and anomalies

Jobs use 3 attempts and exponential backoff starting at 2 seconds. Completed jobs are removed after 24 hours. Failed jobs are kept.

`finance_jobs.idempotency_key` is `{queue}:{days}` while the job is queued or running. A second request returns that row. On completion or failure the key becomes the job id, which frees the name for the next run.

The phone polls `GET /finance/jobs/:jobId`. It never receives a Redis id.

The worker closes BullMQ workers on shutdown. Health is `GET /health` on the worker port so Railway can mark the service up. Concurrency is 2 per queue.

Logs include the queue, job id, and user id. They do not include amounts.
