# Georgi — Mobile app & features

**You own:** the DevEco project, app shell, navigation, every screen, visual design, the onboarding flow,
the emergency card + SOS UX, and the home-screen widget. You are the integrator: other people's services plug
into your screens.

Skills to load before coding: `arkui-development`, `arkts-language`, `harmonyos-app-model`,
`harmonyos-build-deploy`.

## First 2 hours (in order)

1. **Create the project** in `app/` with DevEco Studio: *Empty Ability*, Stage model, ArkTS.
   - Bundle name: agree it with the team **now** (e.g. `com.celiaai.heart`). Mark needs it for the Wear Engine
     application, and it is hard to change later.
   - `compatibleSdkVersion` / `targetSdkVersion` = **API 20** (task requirement).
   - Builds and runs on the emulator → commit + push to `main` **before anything else**. Everyone branches from this.
2. **Folder skeleton** exactly as in `ARCHITECTURE.md` (`pages/ components/ model/ agent/ drugs/ vitals/ data/
   common/ insightintents/ widget/`), with empty `index` files, so nobody fights over structure later.
3. **Copy the shared contracts** from `ARCHITECTURE.md` into `model/*.ets` (types only). Push.
4. **Navigation shell** (`Navigation` + `NavPathStack`, or `Tabs`): **Agent (home)**, **Medicines**, **Heart**
   (vitals), **Emergency**, plus an Onboarding route that is shown first. Placeholder content is fine.
5. Pick the look: HarmonyOS system colours/resources (`sys.color.*`), one accent colour (red for heart/emergency),
   light + dark. A consistent, native look counts with Huawei judges.

## Then (T+2h → T+16h), roughly in this order

1. **Agent chat screen** (home): message list, input bar, mic button (hidden until voice works), typing indicator.
   Renders `AgentReply.actions` as cards: `SHOW_VERDICT` → verdict card (colour by risk level), `START_EMERGENCY` →
   navigate to emergency mode. Build it against Kaloyan's `AgentCore` stub.
2. **Verdict card component** (reused in chat, med check, widget): risk badge, ingredient, reason, source,
   "Ask your doctor" button that copies or shares a prepared question.
3. **Medicines screen:** my meds list (Mark's `LocalStore`), add a med, "Check a medicine" via text or a **camera /
   photo picker** (photo → `OcrService` → `DrugChecker`). Use `cameraPicker` or `PhotoViewPicker` (no permission
   hassle).
4. **Onboarding:** condition (LQTS), genotype (LQT1/2/3/unknown), ICD yes/no, current meds, ICE contacts, notes →
   `LocalStore.saveProfile`.
5. **Emergency:** big readable emergency card (diagnosis, "avoid QT-prolonging drugs", current meds, ICD, contacts),
   a large **Call 112** button and a call-contact button. Make it readable for a stranger: big text, high contrast,
   English + Polish.
6. **Heart screen:** live HR number + small chart, source badge (WATCH / SIMULATED), alert list, and a hidden
   **demo panel** to trigger the simulated scenarios (Mark's `runScenario`).
7. **Widget (Form Kit):** 2×2 emergency card / "Check a medicine" shortcut.
8. Error and empty states everywhere: no network, agent offline, no watch, unknown drug. Judges look at these.

## Definition of done

- A fresh install on the emulator → onboarding → chat → med check → emergency, with no crashes.
- Every screen has loading, error and empty states.
- Screenshots for HackTribe (≥ 1 image required; take 5–6 good ones) + the screen-recording parts of the demo video.
