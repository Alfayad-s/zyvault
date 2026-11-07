# Implementation roadmap

The work landed in this order:

1. Audit the Nest API, Supabase SQL, Groq client, and Flutter shell.
2. Pure paise functions and Vitest fixtures.
3. Redis and BullMQ clients that stay idle without `REDIS_URL`.
4. `/finance` routes on the existing API process.
5. A second Nest entry, `src/worker.ts`, that only consumes queues and serves `/health`.
6. One LangGraph advisor over `LlmClient`.
7. Health score, insights, simulation, and anomalies.
8. Flutter Intelligence screens and a short website mention.

Operator steps that are not in git: run the new SQL in Supabase, add a private Redis service, and create a second Railway service with start command `sh scripts/railway-start-worker.sh`. Fix the API domain target port before expecting the phone to succeed.

Do not replace `POST /chat` with the advisor.
