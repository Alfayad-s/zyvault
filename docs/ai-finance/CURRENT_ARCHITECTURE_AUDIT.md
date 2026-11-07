# Current architecture audit

There is no Prisma schema and no prior Zod usage. The database is `apps/api/supabase/schema.sql`, applied by hand in the Supabase SQL editor. The API uses the Supabase service role and filters every query with the signed-in user id.

Existing tables: `categories`, `accounts`, `transactions`, `budgets`, `scheduled_transactions`, `debts`, `goals`, `goal_entries`, `device_tokens`, `push_log`. Amounts are positive integers plus `kind` of `income` or `expense`. `goal_entries.amount` may be negative.

`SummaryService` builds balance from opening balances plus every transaction. Debt rows do not insert transactions, so `GET /summary` ignores lending. That balance is left unchanged. Intelligence reports lent and borrowed beside it.

Schedules are `once` or `monthly`. EMI is a category plus those schedules, not its own table.

AI is `apps/api/src/agent/llm.client.ts`. Parsing tries Google, then Groq, then OpenRouter. Chat is reserved to Groq `openai/gpt-oss-20b`. Phone chat history is in `apps/mobile/lib/chat_store.dart`, not Postgres.

The product UI is Flutter. `apps/website` is Next.js marketing: home, about, privacy, terms, install. It has no login.

Railway builds `apps/api/Dockerfile` with root directory `apps/api` and starts `sh scripts/railway-start.sh`. Do not switch that service to `npm run start:prod`.

Validation on HTTP bodies is `class-validator`. Zod is used only for advisor tool arguments.
