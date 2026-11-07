# Database design

Existing ledger tables are unchanged. New tables are appended in `apps/api/supabase/schema.sql`. Amounts are `integer` paise. Every table has `user_id` referencing `auth.users` with cascade delete, RLS, and a user index.

| Table | Role |
| --- | --- |
| financial_profiles | Emergency reserve, optional monthly cap, essential category names |
| financial_forecasts | One snapshot per generation, horizon 7, 15, 30, 60, or 90 |
| forecast_daily_points | Daily confirmed and estimated flows. Unique per forecast and date |
| financial_insights | Short titles and bodies |
| insight_evidence | The numbers behind an insight |
| financial_scenarios | Simulator input and result. No ledger write |
| spending_anomalies | Unique per user and fingerprint. Severity `info` or `watch` |
| ai_conversations | Advisor threads only. The old phone chat is not migrated |
| ai_messages | User and assistant turns, with language |
| agent_runs | One row per advisor turn |
| agent_tool_calls | Tool name and status. No SMS, OTP, or email |
| financial_feedback | `up` or `down` on an insight or message |
| finance_jobs | Queue status. Completing a job rewrites `idempotency_key` to the job id so the next run can reuse the stable key |

Apply the file in the Supabase SQL editor. The API does not run DDL. Until then, overview and forecast still calculate, and profile, chat history, and feedback return a clear error or an empty list.

Nothing in this change drops a column or retypes `amount`.
