# Run commands

Run these from the repo root unless a command says otherwise. The API listens on port 3000.

## Backend (Nest.js)

From the repo root:

```bash
pnpm dev
```

From `apps/api`:

```bash
pnpm dev
pnpm start
pnpm start:dev
pnpm start:debug
pnpm build
pnpm start:prod
```

| Command | What it does |
| --- | --- |
| `pnpm dev` | Start the API in watch mode (`nest start --watch`) |
| `pnpm start` | Start the API once |
| `pnpm start:dev` | Same as `pnpm dev` |
| `pnpm start:debug` | Start in watch mode with the Node debugger |
| `pnpm build` | Compile to `apps/api/dist` |
| `pnpm start:prod` | Run the compiled app (`node dist/main`) |

Check that it is up:

```bash
curl http://127.0.0.1:3000
```

The API listens on all network interfaces, so a phone on the same Wi-Fi can call `http://<your-lan-ip>:3000`.

## Supabase

Create `apps/api/.env` from `apps/api/.env.example` and set:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (server only; do not put this in the Flutter app)

Then run [apps/api/supabase/schema.sql](apps/api/supabase/schema.sql) in the Supabase SQL editor. That creates accounts, categories, and transactions, and seeds the categories. In the Supabase dashboard, email confirmation can stay off because the API confirms the user when they first sign in.

## Email code sign-in (Resend)

There is no password. The app sends the email to `POST /auth/email/code`; Nest asks Supabase for a one-time code (Supabase does not send any email itself) and mails it with [Resend](https://resend.com). The app then posts the code to `POST /auth/email/verify` and gets the session token. A new email gets an account automatically.

1. Create a key at [resend.com/api-keys](https://resend.com/api-keys).
2. Add to `apps/api/.env`:

   ```bash
   RESEND_API_KEY=re_...
   RESEND_FROM=Finance Track <onboarding@resend.dev>
   ```

   Until you verify a domain in Resend, `onboarding@resend.dev` can only deliver to the email address of your own Resend account. After verifying a domain, use something like `Finance Track <login@yourdomain.com>`.
3. Restart `pnpm dev`.

The code length (6 to 10 digits) and how long it stays valid come from Supabase: Authentication → Providers → Email → Email OTP Length / Email OTP Expiration. Each email can ask for a new code every 30 seconds, at most 5 times an hour, and gets 5 wrong tries per code.

## AI spend parser

Swiping right on Home and typing a sentence such as `Spent 450 rupees on pizza last night` goes to `POST /transactions/parse`. Nest asks an LLM to read the amount, merchant, date, and category (from your categories table), and saves the transaction. Only when the LLM gives no usable category does it ask Hugging Face `facebook/bart-large-mnli`; if that is unavailable too, the spend goes to Other. The AI keys stay in `apps/api/.env`; the app only sends the text with the sign-in token.

1. Get a free key from [Google AI Studio](https://aistudio.google.com/apikey) and, as automatic backups, from [Groq](https://console.groq.com/keys) and [OpenRouter](https://openrouter.ai/keys). Google free Flash-Lite allows about 500 requests a day. Each Groq chat model allows 1,000 requests and 200,000 tokens a day; a short reply uses about 2,000 tokens, so the practical cap is about 80–120 turns, and that cap is shared by every user of the app. The spend parser uses `gpt-oss-120b` then `qwen3.8-27b`. The chatbot uses only `openai/gpt-oss-20b`, so the two do not share one model’s daily tokens. OpenRouter free models allow 50 a day (1,000 after a one-time $10 credit purchase). A [Hugging Face token](https://huggingface.co/settings/tokens) is optional: free Hugging Face accounts have had no inference credit since 7 October 2026, so it only helps on PRO or with bought credits.
2. Add to `apps/api/.env`:

   ```bash
   LLM_PROVIDER=google            # tried first; then google, groq, openrouter
   GOOGLE_AI_API_KEY=...
   GROQ_API_KEY=...               # optional backup
   OPENROUTER_API_KEY=...         # optional backup
   GOOGLE_AI_MODEL=               # optional; default gemini-flash-lite-latest
   GROQ_MODEL=                    # optional parser override; default gpt-oss-120b, then qwen3.8-27b. Chat always uses gpt-oss-20b.
   OPENROUTER_MODEL=              # optional; default free Gemma 4, then Nemotron
   HF_TOKEN=...                   # optional
   ```

3. Restart `pnpm dev` (Nest only reads `.env` at startup), then hot restart the Flutter app.

If Google is over its limit, down, or slow, the same message goes to Groq, then OpenRouter (45 seconds in total). If all fail (or no key is set), the API answers 503 and the app saves with its on-device keyword parser instead, so `150 food` still works with no keys.

## Flutter app

From the repo root:

```bash
pnpm dev:mobile
pnpm dev:mobile:device
```

`pnpm dev:mobile:device` runs Flutter on a physical phone. An Android phone on USB uses `http://127.0.0.1:3000` through `adb reverse`, so it does not depend on Wi-Fi. Otherwise it uses this computer's LAN IP, and the phone must be on the same Wi-Fi. Pass a device id when more than one is connected:

```bash
pnpm dev:mobile:device -- -d <device-id>
API_HOST=192.168.1.20 pnpm dev:mobile:device
```

From `apps/mobile`:

```bash
pnpm dev
pnpm dev:device
flutter run
flutter devices
flutter run -d <device-id>
flutter run -d ios
flutter run -d android
flutter build apk
flutter build ios
pnpm build:share
pnpm build:share:clean
pnpm dev:mobile:device
```

From the repo root, the share commands are:

```bash
pnpm build:apk
pnpm build:apk:fresh
```

| Command | What it does |
| --- | --- |
| `pnpm dev:mobile` | Run the app from the repo root (`flutter run`) |
| `pnpm dev:mobile:device` | Run on a phone, using this computer's LAN IP as the API URL |
| `pnpm dev` | Same as `flutter run`, from `apps/mobile` |
| `pnpm dev:device` | Same as `pnpm dev:mobile:device`, from `apps/mobile` |
| `flutter devices` | List simulators and connected phones |
| `flutter run -d <device-id>` | Run on a specific device |
| `flutter build apk` | Build an Android APK into the Flutter build folder |
| `flutter build ios` | Build the iOS app |
| `pnpm build:apk` | Build a release APK and copy it to `share-apk/finance-track-release.apk` |
| `pnpm build:apk:fresh` | Build a release APK, delete old APKs in `share-apk`, then copy the new one |
| `pnpm build:share` | Same as `pnpm build:apk`, run from `apps/mobile` |
| `pnpm build:share:clean` | Same as `pnpm build:apk:fresh`, run from `apps/mobile` |

`flutter run` needs a booted simulator or a connected phone. Use `flutter devices` to get the id for `-d`.
