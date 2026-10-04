# Regression pass - 3 Oct 2026

> **Record of the regression pass on 3 Oct 2026** (branch `app_development`). Numbers and screens below are from
> that day; current test counts and the per-feature check list are in the
> [README](../README.md#how-to-verify-each-feature-emulator). Status of the open findings was re-checked against
> the code on 4 Oct.

After finishing the features the docs still listed as missing (TASKS T7, T11-T13, T15, T20, T22, T23, T25-T27, T29,
T30), we checked that nothing else broke. Several Claude Code sessions worked in the same tree that afternoon (box
barcode identification, encrypted share links, medicine info); this pass covers the combined tree.

## How to run a regression pass

All commands from the repo root. `source app/env.sh` first puts `hvigorw`, `ohpm` and `hdc` on the PATH.

| Step | Command | Expected |
|---|---|---|
| 1. Phone unit tests (Hypium, no device) | `app/scripts/test.sh` | summary with 0 failures; non-zero exit on failure |
| 2. Backend unit tests (Deno) | `npx -y deno test --no-lock backend/supabase/functions/` | 0 failed |
| 3. Backend type check | `npx -y deno check --no-lock backend/supabase/functions/*/index.ts` | clean |
| 4. Watch unit tests | `cd watch && source env.sh && hvigorw test -p module=entry -p coverage=false --no-daemon` | 0 failures |
| 5. Accounts RLS (throw-away local Postgres) | `backend/supabase/tests/run-rls.sh` | `ALL ACCOUNTS RLS CHECKS PASSED` |
| 6. Emulator up and locked (several worktrees share one emulator) | `app/scripts/emu.sh up` then `app/scripts/emu.sh lock <name>` | "Emulator up." / lock taken |
| 7. Build, install, launch, screenshot | `app/scripts/run.sh` | screenshot in `app/build/screenshot.jpeg` |
| 8. Walk the flows from the terminal | `app/scripts/ui.sh list`, `ui.sh tapt "Medicines"`, `ui.sh shot <file>` | screens as in the README table |
| 9. Release the emulator | `app/scripts/emu.sh unlock` | - |

With the watch emulator also attached, set `HDC_TARGET=127.0.0.1:5555` for `run.sh` and `ui.sh`.

## Automated

| Check | Command | Result |
|---|---|---|
| App unit tests (Hypium, local) | `app/scripts/test.sh` | **188 run, 0 failures** (was 157 with 3 failures + 2 errors at the start) |
| Backend unit tests (Deno) | `npx -y deno test --no-lock backend/supabase/functions/` | **59 passed, 0 failed** |
| Backend type check | `npx -y deno check --no-lock backend/supabase/functions/*/index.ts` | clean |
| Strict ArkTS build | `hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon` (inside `app/`) | BUILD SUCCESSFUL, no new warnings (8 pre-existing warnings in `share/ShareCrypto.ets`) |

The 5 failures at the start came from the tests themselves: the "offline" agent suites called the real backend set
in the developer's `LocalConfig.ets`. `Config.forceOffline(true)` in `test/List.test.ets` makes them independent.

## On the emulator (Pura 90, API 24)

Screenshots were saved to `app/build/regression/` (not committed).

| Flow | Result |
|---|---|
| Launch → Home (before the v2 layout) | ✅ ring, status chips, agent card, interactions, **tip of the day** card (`TIP FOR LQT2`) |
| Medicines → medicine sheet | ✅ risk band, what it's for, tips, interactions with my medicines (DESIGN §6.9) |
| Emergency → nearby help, card language, read aloud | ✅ chips for 13 languages, Polish card renders; **bug found and fixed:** card labels (Genotype, Medicines…) stayed in the old language - `@Builder` params are by value, the card is now keyed on the language |
| Emergency → QR → encrypted short link | ✅ `celia-share.vercel.app/card/#<id>.<key>` generated live; **bug found and fixed:** the hint said "nothing is uploaded" for the encrypted link |
| Remove this link → confirm dialog | ✅ dialog with Cancel / Remove link (danger) |
| Card language persists | ✅ Polish still selected after reinstall |

Not walked on the emulator this time, because a teammate was using it by hand (box scan in progress): chats, reminders,
doctor prep summary, symptom log via chat, SOS countdown, bystander, settings/ledger, widgets, intents. Their logic
is covered by the unit tests above; run them with `app/scripts/run.sh` + `app/scripts/ui.sh` when the emulator is free.

## Web viewer (Playwright, Chrome, 390×844)

| Check | Result |
|---|---|
| Card in pl (light), bg (dark), de (light) | ✅ call button in the reader's language ("Zadzwoń 112 · Poland", "Обадете се 112", "Anrufen 112"), no horizontal scroll |
| Removed/unknown link, pl + de | ✅ title, emergency line and call button translated |
| Report page XSS (bpm/day from a crafted payload) | fixed and verified live by the share session |

## Findings from this pass

| # | Finding | Status (4 Oct, from the code) |
|---|---|---|
| 1 | Deploys needed: `agent` + `realtime-session` (new `log_symptom` tool), `med-info`, new `doctor-summary`, Vercel site, GitHub Pages | Deployed on 3 Oct (see below); later agent prompt changes need another deploy (README) |
| 2 | The agent greeted "Morning, Anna" at 01:10 | Fixed: between 00:00 and 05:00 the greeting is plain "Hi" (`components/agent/AgentLogic.ets`) |
| 3 | Card viewer: the line under "This card link was replaced or removed" is still English | Open: `goneBody` in `site/card/index.html` is not in the translation table |
| 4 | The 13-language strings in `site/card/index.html` and the medicine tips in `drugs/DrugInfo.ets` were written by AI | Open: needs a native speaker / team review |
| 5 | Needs approvals or a real device: Live View HR / verdict updates, "Taken" on system reminders (AGC quota), Wear Engine, Map Kit in-app map, Celia routing of the 7 intents, on-device English TTS | Open (built, unverified or fallback) |
| 6 | Not built by decision: SOS SMS from the phone via the backend, F-17 caregiver tablet, F-18 Brugada / CPVT pack, A2A agent | Still not built. Since then the watch SOS goes through the `sos` function to contacts the user opted in (Settings → Account) |

## Code + security review fixes (same day)

A `/code-review high` + security pass over the whole branch found 10 issues; all are fixed and covered by tests where
the logic is pure (app 188 / Deno 65, all green).

| # | Issue | Fix |
|---|---|---|
| 1 | Anyone could rewrite the shared `box_cache` for a barcode (AI web answer + one fake confirmation) and change the ingredients every user's QT check runs on | AI answers need a real web citation of the cited page; the client hint is cleaned and quoted as data; confirmed or deterministic rows are never overwritten; AI rows are shared only after 2 distinct devices confirm (`box_confirmations`, salted address hash); every cached row expires after 30 days (`box-identify/cache.ts`) |
| 2 | Public anon key → fake device + contacts + SOS row → SMS/calls on our Twilio account | Project-wide cap on real alert rounds per hour (`SOS_GLOBAL_MAX_PER_HOUR`, default 10) and max 5 contacts per device (migration `20261004030000`) |
| 3 | A crafted QR ending like a report link opened any site | The app rebuilds the URL from the parsed id + key on our own viewer |
| 4 | DELETE body may be moved into the URL by HarmonyOS http → revokes fail | Revoke by POST `{action:'revoke'}` (server + app), DELETE kept as fallback |
| 5 | Copy after Send made a new report link and revoked the one just sent | The live report link is reused while the brief is unchanged |
| 6 | A card change during an upload was dropped | Dirty flag; re-uploads once the running upload ends |
| 7 | Product-database rows cached forever | 30-day TTL (with #1) |
| 8 | Unlimited share creates with the public key | Per-address limit, 30 creates / 10 min per isolate (last `x-forwarded-for` hop / `cf-connecting-ip`) |
| 9 | A message sent during a cold start could vanish into another chat | Each turn waits for the last chat to be reopened |
| 10 | Answered confirm/SOS cards looked actionable again after returning to the chat | The thread redraws display cards only |

**Deployed (3 Oct, project `jxiggumhircfuhianmel`):** `share` v4, `box-identify` v4, `agent` v2, `realtime-session` v2,
`med-info` v3, new `doctor-summary` v1 and `sos` v1; migrations `box_confirmations`, `sos_abuse_limits` and
`emergency_contacts_limit_no_rpc`. Live checks: share revoke-by-POST and bad-id answers, sos refuses calls without its
secret, box-identify rejects a bad barcode, med-info explains Zofran, doctor-summary keeps the risk words verbatim, the
agent calls `log_symptom` for "I felt dizzy after my alarm", and the 5-contact limit rejects a 6th contact (nothing
written). `drug-check` v5 was already the current code. `sos` stays inert until `SOS_WEBHOOK_SECRET` (and, for real
sends, the Twilio secrets) are set.
