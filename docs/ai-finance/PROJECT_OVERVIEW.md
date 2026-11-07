# Project overview

ZYVault is the Android and iOS finance app in `apps/mobile`, with a Nest API in `apps/api` and a marketing site in `apps/website`. The intelligence work adds forecasts, safe-to-spend, a health score, a read-only advisor, simulators, and anomaly notes on top of the ledger that already exists.

Money stays in integer paise. Arithmetic lives in `apps/api/src/finance/engine.ts` and does not call a model. The advisor in `advisor.graph.ts` may only explain numbers the tools already returned.

The existing chat at `POST /chat` can still prepare a transaction. The new advisor at `POST /finance/chat` cannot.

Screens live in the Flutter app, opened from the Intelligence icon. The website stays a marketing site and now mentions the forecast.
