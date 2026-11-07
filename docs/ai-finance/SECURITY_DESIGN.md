# Security design

The service role bypasses RLS, so every new query includes `.eq('user_id', userId)`. Loading a conversation or job with another user’s id returns 404.

Tool schemas reject `userId`. The graph state is the only place the id exists, and it is set from `AuthGuard`.

Advisor prompts contain the message, the language, and the tool JSON. They do not include email, SMS bodies, OTPs, or bank credentials. Tool logs store the tool name and status, not the payload.

The advisor cannot insert into `transactions`. Simulation writes `financial_scenarios` only.

Rate limits apply per user on chat and simulate. Cache keys are prefixed by user id.

Production still depends on the Railway domain target port matching `PORT`. Until `GET /health` returns `{"status":"ok"}`, the phone cannot reach these routes.
