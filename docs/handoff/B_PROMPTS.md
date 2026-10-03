# Workstream B — agent prompts

Paste one prompt per terminal. Start each Claude Code session **inside its worktree** (create it first with
`scripts/worktree.sh <stream>` from the main checkout). The plan they follow is `docs/handoff/B_PLAN.md`.

Every prompt has the same frame; only the stream block differs.

---

## S1 — accounts

```
cd ../Celia.ai-wt/accounts — you are stream S1 "accounts" of Workstream B, on branch georgi/b-accounts.

Read fully, in this order: CLAUDE.md, docs/handoff/GEORGI_account_and_emergency.md (the brief), docs/handoff/B_PLAN.md
(sections 1-4 and your stream S1), docs/design/DESIGN.md. B_PLAN §3 rules override your defaults: stay on your branch,
commit small with no AI attribution, never push, never apply migrations or deploy (write them; the coordinator
applies), strings in string_accounts.json, notes in docs/workflow/b-accounts.md, emulator only under
app/scripts/emu.sh lock.

Your Phase 1: brief B1 + B2. Load skills first: arkts-language, arkui-development, harmonyos-app-model,
harmonyos-build-deploy, supabase-postgres-best-practices (and supabase for Auth). Confirm the Supabase Auth REST
endpoints (signup, token?grant_type=password, token?grant_type=refresh_token, logout, user) in the Supabase docs before
coding; verify the encrypted RDB and http APIs in Context7. The live project already has a broken auth trigger
(see B_PLAN S1 "Facts found") — your first migration fixes it.

Order: (1) migration file, (2) AuthClient + response parsing + tests, (3) Session with persistence, refresh and
offline behaviour + tests, (4) Net.ets JWT header + Ledger named exception, (5) ProfileSync last-write-wins + tests,
(6) AuthForm, WelcomePage, AuthPage, AccountPage, launch routing in Index.ets, (7) brief §8 privacy docs.
Steps 1-5 need no emulator. Real sign-up from the emulator works only after the coordinator applies your migration:
when you reach that point, report "Coordinator actions needed: apply <file>" and wait.

Finish with the READY FOR MERGE report from B_PLAN §3.11. Do not start Phase 2 (B10, B9) until told.
```

## S2 — emergency

```
cd ../Celia.ai-wt/emergency — you are stream S2 "emergency" of Workstream B, on branch georgi/b-emergency.

Read fully, in this order: CLAUDE.md, docs/handoff/GEORGI_account_and_emergency.md (the brief), docs/handoff/B_PLAN.md
(sections 1-4 and your stream S2), docs/design/DESIGN.md. B_PLAN §3 rules override your defaults: stay on your branch,
commit small with no AI attribution, never push, strings in string_emergency.json (keys em_), notes in
docs/workflow/b-emergency.md, emulator only under app/scripts/emu.sh lock.

Your Phase 1: brief B4 + B5. Load skills first: lqts-domain (all medical content comes from it, DrugDataset.ets and
ConditionFacts.ets — cite sources in comments, nothing from memory), arkts-language, arkui-development,
harmonyos-build-deploy. Profile fields and CardField ids already exist (model/Profile.ets) — use them, do not rename.

Order: (1) defaults on read in LocalStore.getProfile + test that an old stored profile loads, (2) emergency/Responder.ets
pure functions (do-not-give, use-instead grouped by what they replace, care notes) + unit tests, (3)
EmergencyDetailsForm (the contract in the stub stays: @Param profile, @Event onChange, never saves) and
EmergencyProfilePage + one Settings row, (4) card rendering of the new fields in fixed order with empty fields hidden
and hiddenOnCard respected, CardStrings English labels with English fallback, (5) versioned share/QR payload +
site/card/index.html, old links still open, QR fallback size measured in a test, (6) ResponderPage (always-light
card_fixed_* colours, large type, no network request — check the ledger) and its entry points: Emergency tab top,
LockScreen, AlertCard widget. S4 adds the SOS-page button. Screenshot every new screen.

Finish with the READY FOR MERGE report from B_PLAN §3.11. Do not start Phase 2 (B14) until told.
```

## S3 — onboarding

```
cd ../Celia.ai-wt/onboarding — you are stream S3 "onboarding" of Workstream B, on branch georgi/b-onboarding.

Read fully, in this order: CLAUDE.md, docs/handoff/GEORGI_account_and_emergency.md (the brief), docs/handoff/B_PLAN.md
(sections 1-4 and your stream S3), docs/design/DESIGN.md. B_PLAN §3 rules override your defaults: stay on your branch,
commit small with no AI attribution, never push, strings in string_onboarding.json (keys onb_), notes in
docs/workflow/b-onboarding.md, emulator only under app/scripts/emu.sh lock.

Your Phase 1: brief B3, the 8-step onboarding. Load skills first: arkui-development, arkts-language,
harmonyos-app-model (runtime permission requests: notifications, microphone, location — verify each API in Context7),
harmonyos-build-deploy, lqts-domain (for the genotype step wording).

You build against two stubs other streams are filling in parallel: components/AuthForm.ets (S1) and
components/EmergencyDetailsForm.ets (S2). Use only their contract (props and events in the stub); do not edit them.
Keep the step state in one place so going back loses nothing; optional steps have Skip; show progress. Move the
notification permission ask out of pages/Index.ets aboutToAppear into the permissions step (that is the only Index.ets
change you make). Keep a fresh install finishing in under 2 minutes: time it on the emulator and screenshot each step.

Finish with the READY FOR MERGE report from B_PLAN §3.11. Phase 2 (the QA pass) starts only when told.
```

## S4 — notifications + SOS

```
cd ../Celia.ai-wt/notify-sos — you are stream S4 "notify-sos" of Workstream B, on branch georgi/b-notify-sos.

Read fully, in this order: CLAUDE.md, docs/handoff/GEORGI_account_and_emergency.md (the brief), docs/handoff/B_PLAN.md
(sections 1-4 and your stream S4), docs/design/DESIGN.md. B_PLAN §3 rules override your defaults: stay on your branch,
commit small with no AI attribution, never push, strings in string_notify.json (keys ntf_), notes in
docs/workflow/b-notify-sos.md, emulator only under app/scripts/emu.sh lock.

Your Phase 1: brief B7 + B8. Load skills first: harmonyos-kits, harmonyos-app-model, arkts-language,
arkui-development, harmonyos-build-deploy. Notification Kit is where training data is most wrong: confirm in Context7
(/websites/developer_huawei_consumer_cn_doc_harmonyos-references and -guides) the slot types, NotificationRequest
fields, actionButtons + wantAgent, and how an action reaches the app (open the app on a page vs. act in the
background). Write what you confirmed, with doc links, into your notes before coding. Build only what API 20 allows;
where a button must open the app, make it open the right page and say so.

B8: trace how a watch SOS reaches the phone today (vitals/WatchCloudSource.ets → Index.ets onAlert → SosController /
SosPage) and remove the second countdown; the SOS page opens in a "sent" state that says what was sent, to whom, and
what still needs a tap. Add a "For first responders" button (Routes.RESPONDER; S2 builds that page) once the countdown
ends. Unit-test the controller state changes. Screenshot each SOS state and each notification kind.

Finish with the READY FOR MERGE report from B_PLAN §3.11. Phase 2 starts only when told.
```

## S5 — doctor visits + diary

```
cd ../Celia.ai-wt/doctor — you are stream S5 "doctor" of Workstream B, on branch georgi/b-doctor.

Read fully, in this order: CLAUDE.md, docs/handoff/GEORGI_account_and_emergency.md (the brief), docs/handoff/B_PLAN.md
(sections 1-4 and your stream S5), docs/design/DESIGN.md. B_PLAN §3 rules override your defaults: stay on your branch,
commit small with no AI attribution, never push, never deploy functions (the coordinator does), strings in
string_doctor.json (keys doc_), notes in docs/workflow/b-doctor.md, emulator only under app/scripts/emu.sh lock.

Your Phase 1: brief B6 (doctor visits with questions) and B15 (feeling diary + daily counts for Trends). Load skills
first: arkts-language, arkui-development, lqts-domain, harmonyos-build-deploy, celia-agent (AI-safety rules for
/doctor-summary).

Visits: "Add a visit" → specialty (the 7 in doctor/DoctorPrep.ets), date, reason, worries → deterministic brief →
AI summary from /doctor-summary. Saved list in VisitsPage (reopen, delete). Strip names and contacts from free text
before it leaves the phone (pure function + tests), extend the function's request validation + Deno tests, keep the
banned-word and dose rejection. The agent tile (DoctorPrepParam) must still open prep on a specialty.
Diary: FeelingPage (mood + optional note) stored as an AppEvent; pure dailyCounts for diary + symptoms + tests.
Run app/scripts/test.sh and `npx -y deno test --no-lock backend/supabase/functions/`. Screenshot the flow (the AI
summary needs the deployed function; until then show the deterministic brief and mark the summary unverified).

Finish with the READY FOR MERGE report from B_PLAN §3.11.
```

## S6 — watch

```
cd ../Celia.ai-wt/watch — you are stream S6 "watch" of Workstream B, on branch georgi/b-watch.

Read fully, in this order: CLAUDE.md, docs/handoff/GEORGI_account_and_emergency.md (the brief, especially B16 and the
watch facts in §4), docs/handoff/B_PLAN.md (sections 1-3 and your stream S6), watch/README.md. B_PLAN §3 rules override
your defaults: stay on your branch, commit small with no AI attribution, never push, notes in docs/workflow/b-watch.md.
You do not change how the watch screens look (Workstream A).

Your work: brief B16. Load skills first: arkts-language, harmonyos-kits (sensor, background tasks), harmonyos-app-model,
harmonyos-build-deploy. Verify sensor intervals, continuous task / background modes for wearables and Health Service Kit
in Context7 before writing about them.

Order: (1) watch/scripts/run.sh (build → install on the Huawei_Wearable emulator → screenshot), (2) characterisation
tests around WatchController behaviour you are about to move, (3) split WatchController into sensors, rules, SOS,
sync, pairing with no behaviour change — all 43 existing tests plus yours pass after each step, (4) energy: lower
accelerometer rate at rest, outbox written once per sync, one reused HTTP client, (5) background monitoring research
into watch/README.md with sources and a "needs: …" list. Screenshot the watch before and after: it must look and
behave the same.

Finish with the READY FOR MERGE report from B_PLAN §3.11.
```

## S7 — research

```
cd ../Celia.ai-wt/research — you are stream S7 "research" of Workstream B, on branch georgi/b-research.

Read fully: CLAUDE.md, docs/handoff/GEORGI_account_and_emergency.md (the brief: B11, B12, B13, B17, B18),
docs/handoff/B_PLAN.md (sections 1-3 and your stream S7). Rules: docs only, no app code; commit small with no AI
attribution; never push; notes in docs/workflow/b-research.md.

Load skills first: harmonyos-docs (doc sources), harmonyos-kits, celia-agent, hackyeah-huawei. Use Context7
(/websites/developer_huawei_consumer_cn_doc_harmonyos-guides and -references) and web search on official Huawei
developer pages. Read the code each topic touches (emergency/LiveStatus.ets, entryformability/, watch sync,
backend/supabase/functions/sos) so the docs match what exists.

Write: docs/research/push-kit.md (AGC project/app id, enabling Push Kit, client_id in module.json5, getting the token
with @kit.PushKit, storing it under the account, sending from a Supabase Edge Function via the Push REST API with OAuth
client credentials, emulator support), docs/research/live-view.md (applying for the Live View scenario, which type
fits an emergency countdown, capsule and lock-screen content, real-phone test steps; plus whether a third-party app
can show a medical-ID card on the lock screen: Form Kit lock-screen cards, widgets), docs/research/phone-watch-link.md
(Wear Engine, distributed data objects, today's cloud relay, recommendation), docs/research/account-kit.md (Huawei
Account Kit as a second sign-in: AGC needs, scopes, ID token → Supabase). Each: sources with links, what works on the
emulator vs a real phone, exact steps, and a "needs: …" list naming every account, approval or credential we lack.
Write each so the S4 agent can implement from it without re-researching. B11: summarise what sos/twilio.ts does and
what it lacks, then ask Georgi for the Cardbeat reference before proposing a conversational call.

Finish with the READY FOR MERGE report from B_PLAN §3.11 (tests: "not touched").
```

---

## Follow-up messages (paste into a running session)

- **Phase 2 go:** `Phase 1 is merged into georgi/integration. Run git merge georgi/integration, re-run the tests, then
  start your Phase 2 from B_PLAN §4. Same rules, same report.`
- **Pick up others' work:** `georgi/integration has new merges you depend on. Run git merge georgi/integration, fix
  anything that breaks in your files, re-run the tests.`
- **Merge conflict handed back:** `The coordinator could not merge your branch cleanly: <files>. Run git merge
  georgi/integration, resolve keeping both sides' intent, re-run the tests, report again.`
