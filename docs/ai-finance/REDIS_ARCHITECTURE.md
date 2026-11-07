# Redis architecture

`REDIS_URL` is read by `FinanceCache` and `FinanceQueueClient`. Leave it empty in local development. On Railway, use the private URL from a Redis service in the same project. Do not attach a public TCP proxy.

Redis holds:

- BullMQ queues
- Overview cache keys `fin:{userId}:overview` for 60 seconds
- Rate counters `fin:{userId}:rate:chat` and `fin:{userId}:rate:simulate`, 30 and 20 per hour

Ledger writes in transactions, schedules, budgets, goals, debts, and account clear call `invalidate`, which deletes `fin:{userId}:*`.

Postgres remains the source of truth for balances, forecasts, insights, scenarios, anomalies, transcripts, and job rows. Redis is not authoritative.

If Redis is down, cache and enqueue fall back to this process: the API computes the job immediately and the worker logs that it is idle.
