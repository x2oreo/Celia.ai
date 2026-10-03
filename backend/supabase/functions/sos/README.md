# `sos` Edge Function

Alerts emergency contacts when the watch's SOS countdown runs out ("Need help", or a fall nobody answered).
HarmonyOS apps can't place calls or send SMS silently (`SEND_MESSAGES` is system-only, `call.makeCall` only opens
the dialer), so the automatic part runs here.

```
watch inserts watch_metrics{type:'sos'}
  → trigger watch_metrics_sos_notify (pg_net, async)
  → POST /functions/v1/sos  {record}  + x-sos-secret
  → 10 min cooldown per device
  → Twilio SMS (with maps link) + voice call to each emergency_contacts row
  → audit row in sos_dispatches
```

The message text is deterministic (`message.ts`); no LLM is involved.

## Setup (once per Supabase project)

```bash
cd backend
supabase db push                                   # applies 20261003200000_sos_dispatch.sql
supabase secrets set SOS_WEBHOOK_SECRET=<random>   # e.g. openssl rand -hex 24
supabase secrets set TWILIO_ACCOUNT_SID=... TWILIO_AUTH_TOKEN=... TWILIO_FROM_NUMBER=+1...
supabase functions deploy sos --no-verify-jwt      # auth is the shared secret, not a user JWT
```

Then in the SQL editor (values stay in Vault, never in git):

```sql
select vault.create_secret('https://<project-ref>.supabase.co/functions/v1/sos', 'sos_function_url');
select vault.create_secret('<same value as SOS_WEBHOOK_SECRET>', 'sos_webhook_secret');
insert into emergency_contacts (device_id, name, phone) values ('demo-watch-1', 'Mom', '+48123456789');
update watch_context set patient_name = 'Mark' where device_id = 'demo-watch-1';
```

**Without Twilio secrets** the function runs in dry-run mode: it builds the message and stores it in
`sos_dispatches` with `status = 'dry_run'`, but sends nothing. A **Twilio trial** account only reaches verified
numbers, so verify the demo phones first.

## Test

```bash
npx -y deno test --no-lock backend/supabase/functions/sos/   # message building, validation, TwiML escaping
```

Manual end-to-end: insert a row as the watch would and check `sos_dispatches`:

```sql
insert into watch_metrics (device_id, type, payload, recorded_at, source)
values ('demo-watch-1', 'sos', '{"reason":"fall","bpm":172,"lat":50.0614,"lon":19.9366}', now(), 'simulated');
select status, detail, created_at from sos_dispatches order by id desc limit 1;
```

## Payload

`payload` is the watch's `SosValues`: `{ reason: "need_help" | "fall", bpm, activity?, lat?, lon?, accuracyM? }`.
Location is optional; without it the SMS says "Location unknown."
