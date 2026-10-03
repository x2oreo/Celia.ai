# Celia.ai

Agent-first heart-safety companion for people with Long QT syndrome — HarmonyOS (API 20+), HackYeah 2026 Huawei task.

## Team docs
- [Product spec](docs/PRODUCT.md) — locked decisions, screens, feature catalogue, demo
- [Idea](docs/IDEA.md) — what we build and why, MVP scope, demo story
- [Architecture](docs/ARCHITECTURE.md) — big picture, ownership, shared contracts, API
- [Plan](docs/PLAN.md) — checkpoints, mentor questions, submission checklist
- [Tasks](docs/TASKS.md) — feature expansion (F-19..F-34) as implementable tasks
- Per person: [Kaloyan — agent](docs/team/kaloyan-agent.md) · [Georgie — app](docs/team/georgie-app.md) · [Mark — data & watch](docs/team/mark-data-watch.md)
- Background: [task text](docs/hackathon/huawei-task.txt) · [condition research](docs/hackathon/conditions-research.md)

## Build & run

Native HarmonyOS app: ArkTS + ArkUI, Stage model, **minimum and target API 20** (`6.0.0(20)`).
Project lives in [`app/`](app) — open that folder in DevEco Studio 6.x.

```bash
source app/env.sh          # puts DevEco's hvigorw / ohpm / hdc on PATH (override DEVECO=... if installed elsewhere)
app/scripts/test.sh        # local unit tests (Hypium, no device needed); non-zero exit on failure
app/scripts/run.sh         # build → install → launch → screenshot on a running emulator/device (needs signing)
```

On the first build `entry/hvigorfile.ts` creates `app/entry/src/main/ets/common/LocalConfig.ets` from
`LocalConfig.example.ets`. That file is gitignored — put the backend URL / Supabase anon key there. Without it the
app runs fully offline (deterministic drug check, emergency card).

### Signing

`hvigorw assembleHap` without signing produces only `entry-default-unsigned.hap`, which cannot be installed.

1. DevEco Studio → File → Project Structure → Signing Configs → sign in with a Huawei ID →
   **Automatically generate signature** (works for the emulator and for a real device).
2. DevEco writes local cert paths and encrypted passwords into `app/build-profile.json5`. **Never commit that hunk.**
   Right after enabling signing, run once **from the repo root** (the file must already be tracked — it is, once
   you've pulled `main`):
   ```bash
   git update-index --skip-worktree app/build-profile.json5
   ```
   (undo with `--no-skip-worktree` before you intentionally change that file). Certificates (`*.p12`, `*.cer`,
   `*.p7b`, `*.csr`) are gitignored and live outside the repo (`~/.ohos/config`).
3. Safety net — enable the repo's pre-commit hook once per clone; it refuses commits that contain signing
   material, certificates, `LocalConfig.ets` or `.env` files:
   ```bash
   git config core.hooksPath .githooks
   ```
4. `app/scripts/run.sh` now finds `entry-default-signed.hap` and installs it.

## How to verify each feature (emulator)

Everything below runs on the emulator with no backend and no watch. Heart data is **simulated** and labelled so.

| Feature | How to check |
|---|---|
| Onboarding (F-01) | Fresh install → 4 steps (genotype + ICD → medicines → contacts → country). Restart: data is still there (encrypted RDB). |
| Drug check (F-05, F-07, F-20, F-21) | Medicines → type `Klacid`, `Zofran 8 mg`, `Сумамед`, `ondansetrom` (typo) or `xyz` → verdict card; "How we know" shows each step. |
| Interactions (F-19) | Add `Cipralex` to my medicines, then check `ondansetron` (adds up) or `clarithromycin` (CYP3A4). |
| Barcode (F-36) | Medicines → Scan (camera or album). Any Polish box resolves from the bundled register (≈68k packs), e.g. type `5909990331710` (Klacid) or `5909990296026` (Apap) → verdict + "About this medicine" (substance, strength, form, pack, Rx/OTC, ATC group, holder, leaflet). Unknown boxes (e.g. Bulgarian) open "teach this barcode"; the next scan resolves instantly. Demo codes `2000000000015`… still work. Regenerate the register with `python3 data/export_gtins.py`. |
| History, dashboard (F-23, F-24) | Home shows meds by risk, interactions and recent checks; Medicines → Check history (filters). |
| Heart + alerts (F-09, F-32) | Heart → Simulation controls → `lqt2 startle tachy`, `lqt3 night brady`, `lqt1 exercise`, `irregular rhythm`, `watch disconnect`. |
| SOS (F-27, F-28, F-35) | A CRITICAL alert (e.g. `lqt2 startle tachy`) opens the 30 s "Are you OK?" countdown → "I'm OK" or let it run → call / share message / call contacts. Settings → Test SOS runs a 10 s test marked TEST. 10-min cooldown for automatic SOS. |
| Emergency card (F-08, F-26, F-29, F-30) | Emergency tab: country number (e.g. Bulgaria 150, Poland 999), English card, offline QR. (UI is English-only for now; card translations for 12 more languages are kept in `common/CardStrings.ets` for later.) |
| Help guide (F-41) | Emergency → Help guide: 3 steps + CPR metronome 110/min (haptic). Also reachable from the lock screen. |
| Pharmacy card (F-40) | Home → More → Pharmacy card (English for now). |
| Doctor prep (F-31) | Home → Doctor visit prep → pick the specialist → share / copy. No AI: built from your own data. |
| Reminders (F-38) | Medicines → Medicine reminders. See ARCHITECTURE: system reminders need an AGC quota; the in-app fallback notifies while the app runs. |
| Symptom log (F-44, manual) | Home → More → Symptom log; fainting / chest pain shows an SOS button. Appears in the doctor brief. |
| Privacy, app lock (F-45, F-46) | Settings → What left my phone: ledger of outbound requests (empty when offline). App lock needs a screen lock (PIN) on the device. |

Unit tests: `app/scripts/test.sh` — 57 tests (drug data + checker, interactions, alarm rules, SOS state machine and
message, doctor brief, GS1, emergency numbers, card text completeness, dose schedule, privacy guard).

Optional online drug check: create a Supabase project, run `backend/supabase/migrations/0001_drugs.sql` and
`backend/supabase/seed.sql` (regenerate with `python3 data/export_seed.py`), deploy `functions/drug-check`, and put
the URL + anon key in `app/entry/src/main/ets/common/LocalConfig.ets`. Without it the app is fully offline.

## AI usage

How AI tools were used, and which pre-existing components are reused: [`AI_WORKFLOW.md`](AI_WORKFLOW.md).

**Pre-existing / third-party components (Challenge Rules §4):** DevEco Studio's Empty Ability template
(hvigor files, `EntryAbility` skeleton, Hypium test harness) and the `@ohos/hypium` / `@ohos/hamock` test libraries.
App code, data and prompts are written in this repo.

**Data sources:** drug risk categories follow the public CredibleMeds QTdrugs lists (crediblemeds.org); brand names
from the Polish (URPL) and Bulgarian (BDA) medicine registers; emergency numbers from the EU 112 pages and national
regulators; CPR guidance from ERC / AHA public guidelines; genotype triggers from Schwartz et al. (Circulation 2001)
and the HRS/EHRA/APHRS 2013 consensus. Box barcodes, product names, strengths, forms, availability categories and
leaflet links come from the public Polish medicines register export (Rejestr Produktów Leczniczych, URPL —
rejestrymedyczne.ezdrowie.gov.pl, snapshot date stored in `gtin_pl.json`); ATC group names from the WHO ATC index
(whocc.no); GS1 country prefixes from the public GS1 prefix list. The bundled list is a curated demo subset — not a medical device.
