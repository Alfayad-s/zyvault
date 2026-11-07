# Task tracker

Statuses: NOT_STARTED, IN_PROGRESS, BLOCKED, COMPLETED.

Tests for the engine and graph are Vitest. Flutter analyzer covers the new screens.

## P0-1 Documentation

- Description: Write this directory from the real repo, not a Prisma design.
- Priority: High. Dependencies: none.
- Files: `docs/ai-finance/*`.
- Result: Sixteen documents naming real modules.
- Acceptance: The audit says there is no Prisma client.
- Testing: Read the audit against `schema.sql` and `package.json`.
- Status: COMPLETED.

## P0-2 Decisions

- Description: Record the Railway port blocker and the debt-versus-balance gap.
- Priority: High. Dependencies: P0-1.
- Files: `DECISIONS_LOG.md`.
- Result: Both decisions are written.
- Acceptance: Safe-to-spend does not change `GET /summary`.
- Testing: Engine test keeps lending out of balance.
- Status: COMPLETED.

## P1-1 Redis clients

- Description: Add `ioredis` and `bullmq` to `apps/api` and read `REDIS_URL`.
- Priority: High. Dependencies: P0-1.
- Files: `package.json`, `finance.cache.ts`, `finance.queue.ts`, `.env.example`.
- Result: API boots when Redis is unset.
- Acceptance: No connection attempt without `REDIS_URL`.
- Testing: Existing Vitest suite still passes.
- Status: COMPLETED.

## P1-2 Worker process

- Description: `src/worker.ts`, `start:worker`, and `scripts/railway-start-worker.sh`.
- Priority: High. Dependencies: P1-1.
- Files: `worker.ts`, `worker.module.ts`, `Dockerfile`.
- Result: Worker health is separate from the public controllers.
- Acceptance: Worker module does not import `FinanceController`.
- Testing: `tsc -p tsconfig.build.json --noEmit`.
- Status: COMPLETED. Creating the Railway service is an operator step in the deployment guide.

## P1-3 Jobs

- Description: `finance_jobs` and idempotent enqueue.
- Priority: High. Dependencies: P1-1.
- Files: `schema.sql`, `finance.service.ts`.
- Result: A running job is returned instead of duplicated.
- Acceptance: Completing a job frees the idempotency key.
- Testing: Typecheck. SQL is applied by hand.
- Status: COMPLETED.

## P2-1 Pure overview

- Description: Overview, budgets, and obligations in paise with no I/O.
- Priority: High. Dependencies: P0-1.
- Files: `engine.ts`, `engine.spec.ts`.
- Result: Lending is reported beside balance.
- Acceptance: Balance input is returned unchanged.
- Testing: Vitest.
- Status: COMPLETED.

## P2-2 Overview route

- Description: `GET /finance/overview` from summary, budgets, schedules, goals, and debts.
- Priority: High. Dependencies: P2-1.
- Files: `finance.service.ts`, `finance.controller.ts`.
- Result: Authenticated overview.
- Acceptance: Uses `SummaryService` for the cash balance.
- Testing: Typecheck.
- Status: COMPLETED.

## P3-1 Forecast

- Description: Five horizons with confirmed and estimated lines.
- Priority: High. Dependencies: P2-1.
- Files: `engine.ts`.
- Result: Estimated income is not added to the projected balance.
- Acceptance: Engine test for a monthly rent plan.
- Testing: Vitest.
- Status: COMPLETED.

## P3-2 Safe-to-spend

- Description: Subtract essentials, reserve, and this month’s goal.
- Priority: High. Dependencies: P3-1, P2-2.
- Files: `engine.ts`, `GET /finance/safe-to-spend`.
- Result: Each subtracted line is in the response.
- Acceptance: 100000 − 20000 − 10000 − 30000 = 40000 in the fixture.
- Testing: Vitest.
- Status: COMPLETED.

## P3-3 Forecast jobs

- Description: Persist snapshots and refresh through `cash-flow-forecast`.
- Priority: Medium. Dependencies: P1-3, P3-1.
- Files: `finance.service.ts`, `schema.sql`.
- Result: `POST /finance/forecast/refresh` enqueues or runs inline.
- Acceptance: Stored forecast younger than six hours is reused.
- Testing: Typecheck.
- Status: COMPLETED.

## P4-1 LangGraph

- Description: One graph, ten tools, `LlmClient` for the explanation.
- Priority: High. Dependencies: P2-2, P3-2.
- Files: `advisor.graph.ts`.
- Result: Tool arguments cannot carry a user id.
- Acceptance: Zod strict parse rejects `userId`.
- Testing: `advisor.graph.spec.ts`.
- Status: COMPLETED.

## P4-2 Runs and validation

- Description: Persist runs and tool names. Reject invented rupee amounts.
- Priority: High. Dependencies: P4-1.
- Files: `advisor.graph.ts`, `finance.service.ts`, `schema.sql`.
- Result: A bad model amount is replaced by the deterministic reply.
- Acceptance: The spec reply contains the tool figure and not 9999.
- Testing: Vitest.
- Status: COMPLETED.

## P5-1 Advisor API

- Description: `POST /finance/chat` and `GET /finance/chat/:id` for en, ml, and hinglish.
- Priority: High. Dependencies: P4-2.
- Files: `finance.controller.ts`.
- Result: Language is stored on the turn when the tables exist.
- Acceptance: Malayalam fixture contains Malayalam text.
- Testing: Graph spec.
- Status: COMPLETED.

## P5-2 Advisor screen

- Description: Flutter advisor. Existing Chat stays.
- Priority: High. Dependencies: P5-1.
- Files: `intelligence_screen.dart`, `shell.dart`.
- Result: Language chips and a thread that does not open the old chat.
- Acceptance: Analyzer has no new issues in the new file.
- Testing: `flutter analyze`.
- Status: COMPLETED.

## P6-1 Health

- Description: Weighted score. Missing income leaves that component null.
- Priority: High. Dependencies: P2-1.
- Files: `engine.ts`, `GET /finance/health`.
- Result: Weights 20, 25, 20, 15, 20.
- Acceptance: Expense-to-income is null when income is 0.
- Testing: Vitest.
- Status: COMPLETED.

## P6-2 Insights

- Description: `ai-insights` job and `GET /finance/insights`.
- Priority: Medium. Dependencies: P1-3, P4-1, P6-1.
- Files: `engine.ts`, `finance.service.ts`.
- Result: Drafts when nothing is stored. Evidence rows when the job runs.
- Acceptance: Insight text uses `rupees()` on calculated values.
- Testing: Typecheck.
- Status: COMPLETED.

## P7-1 Simulator

- Description: Purchase, extra spend, income change, savings, emergency, and EMI on a forecast.
- Priority: Medium. Dependencies: P3-1.
- Files: `engine.ts`, `POST /finance/simulate`.
- Result: A purchase of 30000 paise drops the end balance by that amount. No transaction insert.
- Acceptance: Scenario assumptions say it is a what-if.
- Testing: Vitest.
- Status: COMPLETED.

## P7-2 Simulator screens

- Description: Purchase and savings screens.
- Priority: Medium. Dependencies: P7-1.
- Files: `intelligence_screen.dart`.
- Result: The screen states that accounts are unchanged.
- Acceptance: Analyzer clean for the new file.
- Testing: `flutter analyze`.
- Status: COMPLETED.

## P8-1 Anomalies

- Description: User-relative rules. Never labeled as fraud.
- Priority: Medium. Dependencies: P2-1, P1-3.
- Files: `engine.ts`, `GET /finance/anomalies`.
- Result: Eight prior amounts are required before an unusual amount flag.
- Acceptance: The reason says it is not a fraud warning.
- Testing: Vitest.
- Status: COMPLETED.

## P9-1 Remaining screens

- Description: Dashboard, forecast, safe-to-spend, health, insights, anomalies, history.
- Priority: Medium. Dependencies: the matching GET routes.
- Files: `intelligence_screen.dart`.
- Result: One destination list opens each screen.
- Acceptance: Loading, empty, and error states are present.
- Testing: `flutter analyze`.
- Status: COMPLETED.

## P9-2 Website copy

- Description: Marketing sentences only.
- Priority: Low. Dependencies: P9-1.
- Files: `apps/website/lib/site.js`, `app/page.js`, `app/privacy/page.js`.
- Result: A forecast feature card and a privacy line.
- Acceptance: No signed-in website route.
- Testing: Copy review.
- Status: COMPLETED.

## P10-1 Hardening

- Description: Cache, invalidation, rate limits, worker shutdown, deploy note.
- Priority: High. Dependencies: P1-2 through P9-1.
- Files: `finance.cache.ts`, ledger services, `DEPLOYMENT_GUIDE.md`.
- Result: Ledger writes drop `fin:{userId}:*`. Chat and simulate are limited.
- Acceptance: Worker `onApplicationShutdown` closes workers.
- Testing: API Vitest, 129 tests.
- Status: COMPLETED.
