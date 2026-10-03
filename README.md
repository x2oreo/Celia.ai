# Celia.ai

Agent-first heart-safety companion for people with Long QT syndrome — HarmonyOS (API 20+), HackYeah 2026 Huawei task.

## Team docs
- [Product spec](docs/PRODUCT.md) — locked decisions, screens, feature catalogue, demo
- [Idea](docs/IDEA.md) — what we build and why, MVP scope, demo story
- [Architecture](docs/ARCHITECTURE.md) — big picture, ownership, shared contracts, API
- [Plan](docs/PLAN.md) — checkpoints, mentor questions, submission checklist
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

## AI usage

How AI tools were used, and which pre-existing components are reused: [`AI_WORKFLOW.md`](AI_WORKFLOW.md).

**Pre-existing / third-party components (Challenge Rules §4):** DevEco Studio's Empty Ability template
(hvigor files, `EntryAbility` skeleton, Hypium test harness) and the `@ohos/hypium` / `@ohos/hamock` test libraries.
App code, data and prompts are written in this repo.
