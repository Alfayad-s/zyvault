# Environment variables

Set these on the Railway API and worker. Do not put them in `NEXT_PUBLIC_` variables. The marketing site does not receive them.

| Name | Where | Notes |
| --- | --- | --- |
| SUPABASE_URL | API and worker | Existing |
| SUPABASE_SERVICE_ROLE_KEY | API and worker | Server only |
| PORT | Injected by Railway | Listen on this value. Do not hardcode a public port |
| REDIS_URL | API and worker | Private Railway URL. Empty locally is valid |
| GROQ_API_KEY | API and worker | Advisor explanations. The deterministic reply is used when it is missing |
| GOOGLE_AI_API_KEY | API | Existing parser and bills. Not required for the advisor |
| OPENROUTER_API_KEY | API | Existing parser fallback |
| FIREBASE_SERVICE_ACCOUNT_JSON | API and worker | Existing start script writes the file when this is set |

`apps/api/.env.example` lists `REDIS_URL` with the other server keys.
