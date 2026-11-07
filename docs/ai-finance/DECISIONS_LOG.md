# Decisions log

## 2026-11-07 Railway port

`GET /health` on the public API domain was Railway’s 502 “Application failed to respond” while Nest logged a successful start. The app already listens on `process.env.PORT` and `0.0.0.0`. The domain target port must match that `PORT`. This is an operator fix, not an intelligence code change. Do not deploy the worker until the API health URL returns `{"status":"ok"}`.

## 2026-11-07 Debts and balance

`debts` rows do not insert `transactions`. `GET /summary` therefore ignores lending. Intelligence does not change that balance. It shows outstanding lent and borrowed as separate lines. Safe-to-spend uses the summary balance and says lending is not included.

## 2026-11-07 No Prisma

The repo has no Prisma client. New tables are SQL in `schema.sql`. HTTP validation stays `class-validator`. Zod is only used for advisor tool arguments.

## 2026-11-07 Screens

The product UI is Flutter. The Next.js app stays the marketing site. Intelligence screens are not a second signed-in website.

## 2026-11-07 Estimated income

Scheduled income is confirmed. Income inferred from history is estimated and is not added to the projected balance or to safe-to-spend.

## 2026-11-07 Health weights

Savings consistency 20, spending against income 25, budget discipline 20, recurring plans 15, emergency reserve 20. A component with no data is null and its weight is left out of the average. Three months of typical spending covered by the reserve scores 100 on that part.

## 2026-11-07 Anomalies

Flags are `info` or `watch`. Copy says they are not fraud alerts. An unusual amount needs at least eight earlier expenses in that category, above the 90th percentile, and more than twice the median.

## 2026-11-07 Advisor writes

`POST /chat/apply` can still save a transaction after the user confirms. `POST /finance/chat` and `POST /finance/simulate` cannot insert a transaction.

## 2026-11-07 One chat

The existing Chat screen is the only conversation. A question about the figures is answered by the intelligence graph. A message that records a spend, plan, budget, goal, or debt still shows a line to confirm. There is no second advisor screen.
