# API design

All routes use the existing bearer auth. The user id comes from the token. Conversation, job, and message lookups also filter `user_id`.

| Method | Path | Behavior |
| --- | --- | --- |
| GET | /finance/overview | Month summary, budgets, 30 days of plans, goals, lending |
| GET | /finance/forecast?days= | 7, 15, 30, 60, or 90. Returns a snapshot under 6 hours old, otherwise computes |
| POST | /finance/forecast/refresh | Enqueues `cash-flow-forecast` |
| GET | /finance/safe-to-spend | Balance minus essentials, reserve, and this month’s goal set-aside |
| GET | /finance/health | Weighted score and each component |
| GET | /finance/insights | Stored insights, or drafts when none are stored |
| GET | /finance/anomalies | Unusual lines versus this user’s history |
| GET | /finance/profile | Reserve and essential categories |
| PUT | /finance/profile | Saves the reserve. Requires the new tables |
| POST | /finance/simulate | What-if. Stores a scenario when the table exists. Does not post a transaction |
| POST | /finance/chat | Read-only advisor |
| GET | /finance/chat | Advisor thread list |
| GET | /finance/chat/:id | One thread, owned by the caller |
| POST | /finance/feedback | up or down |
| POST | /finance/jobs | 202 and a job row |
| GET | /finance/jobs/:jobId | Status for that user |

Chat is limited to 30 calls an hour and simulate to 20. Both return 429 when exceeded.

`POST /chat` and `POST /chat/apply` are unchanged.
