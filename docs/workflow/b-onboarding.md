# S3 onboarding

## AI_WORKFLOW entry
### 2026-10-03 — Georgi + Claude Code: 8-step onboarding (branch `georgi/b-onboarding`)
- Asked: brief B3 — a simple onboarding that still gathers everything: welcome + consent, account, about you,
  medicines, emergency contacts, emergency details, permissions, watch. Progress shown, Skip on optional steps,
  nothing lost when going back, under 2 minutes; move the launch-time notification ask into the permissions step.
- Produced: `onboarding/OnboardingFlow.ets` (pure step rules and profile-draft helpers), `onboarding/Permissions.ets`
  (check/request notifications, microphone, location), `components/onboarding/` (`OnbParts`, `StepAbout`,
  `StepContacts`, `StepPermissions`), rewritten `pages/OnboardingPage.ets`, `string_onboarding.json`,
  `test/Onboarding.test.ets` (11 tests). `pages/Index.ets` no longer asks for notifications on every launch.
- Validated: phone unit tests 222/222. Emulator (phone, API 20 image, fresh install each time):
  - Continue stays inactive until consent is ticked; one tap on the checkbox ticks it once.
  - Every step shown with progress and "Step N of 8"; Skip on steps 2 and 4-8; the date picker fills date of birth;
    ICD model field appears with the switch.
  - A saved contact and a half-typed second name both survive Back → Continue.
  - Permissions: no notification prompt at launch any more; each Allow opens its system dialog only on tap;
    granted shows "Allowed", a denied microphone shows the Settings hint.
  - Pair a watch opens the Pair watch page and Back returns to step 8; Finish lands on Home ("Hi Ola", LQT2 chip);
    relaunch goes straight to Home.
  - Timing: a scripted fresh-install run entering name, birth date, genotype, ICD + model, one medicine, one contact
    and all three permission dialogs took **27 s** (app log: "onboarding took 29 s"). That is tap speed, not human
    reading speed; with reading and typing by hand it is still well under the 2-minute target (14 inputs, 3 system
    dialogs, nothing required beyond the consent tick).
  - Screenshots: `docs/screenshots/b/onboarding-1-welcome.jpeg` … `onboarding-9-home.jpeg`
    (+ `onboarding-7a-notification-dialog.jpeg`).
- Found and fixed while testing: the last step still said "Continue". `components/Common.ets` `PrimaryButton`
  passes its label to a by-value `@Builder`, which does not re-render when the label changes; the page now uses two
  button instances. Every other caller of `PrimaryButton` with a changing label has the same bug (not fixed here —
  Common.ets is Workstream A's; fix: pass `$$`-style by-reference params or rebuild the label in the struct).
- Not validated: the account step and the emergency-details step run against S1's `AuthForm` and S2's
  `EmergencyDetailsForm` stubs; the real forms arrive at merge. The returning-user skip
  (`shouldFinishAfterSignIn`) is unit-tested, not run end to end (needs S1's ProfileSync).
- HarmonyOS APIs were checked against the API 20 SDK `.d.ts` files in DevEco (Context7 was not connected in this
  session): `abilityAccessCtrl.checkAccessToken` / `requestPermissionsFromUser` (since 11),
  `notificationManager.isNotificationEnabled` / `requestEnableNotification(context)` (since 12),
  `UIContext.showDatePickerDialog` (since 11). `requestPermissionOnSetting` is API 21, so it is not used.

## README "How to verify" rows
| Onboarding (B3) | Fresh install (`hdc uninstall com.celiaai.app`, then `app/scripts/run.sh`): 8 steps with a progress bar and "Step N of 8". Continue stays inactive until the consent box is ticked. Type a contact name, go Back and forward again: the text is still there. Skip on steps 2 and 4-8. Permissions step: each Allow opens the system dialog only when tapped. Finish lands on Home; relaunch does not show onboarding again. |
| No notification prompt on launch | Relaunch the app after onboarding: no notification dialog appears (it is asked only in onboarding step 7). |

## DESIGN.md subsection (new screens only)

Replaces the "Onboarding" line in 10.2:

- **Onboarding** (8 steps, pushed on first launch): top: 8 progress segments (4 vp, `brand` done / `border_strong`
  to do) and "Step N of 8" in `caption` `ink_3`. Each step: `title-1` heading + `body-sm` subtitle in `ink_3`, then
  its fields; bottom: primary `Continue` (`Finish` on the last step; inactive until the step is valid), a row with
  `Back` (left, from step 2) and `Skip` (right, optional steps), and the disclaimer in `caption` `ink_4`. Side margin
  `space_screen`. Text fields: 48 vp `surface_alt`, `radius_s`. Choice chips (genotype, account mode): 44 vp,
  selected = `ink` fill + `on_accent` text, otherwise `surface` + 1.5 vp `border_strong`.
  1. **Welcome**: orb 96, "Your heart-safety companion", what the app does, "about two minutes", and the consent row
     (`surface` card, checkbox + "I understand this app is not a medical device…"; the whole card toggles it, its
     border turns `ink` when ticked).
  2. **Account**: chips "Create account" / "I have an account" above `AuthForm`; signed in = check icon + "Signed in
     as {email}" card. Caption: no account still works.
  3. **About you**: name field; date of birth card (value or "Not set" in `ink_4`, quiet `Choose` button → system
     date picker); genotype chips LQT1 / LQT2 / LQT3 / Not sure + caption from `lqts-domain`; ICD card (switch, and
     an ICD model field when on).
  4. **Medicines**: `AddMedForm`, then one row per medicine with its compact risk badge.
  5. **Contacts**: name / phone / relation fields, primary `Add contact` (inactive until valid), rows with a remove ✕
     (48 vp hit area).
  6. **Emergency details**: country select (sets the emergency number) and `EmergencyDetailsForm`.
  7. **Permissions**: three `surface` cards: 44 vp `brand_accent_soft` icon well (bell, mic, location in
     `brand_text`), `headline` title, one `body-sm` sentence of why in `ink_2`, and an ink `Allow` (48 vp). Granted =
     check + "Allowed" in `ink_2`. Refused = caption "Not allowed. You can turn it on in the phone's Settings." No
     risk colours anywhere in onboarding.
  8. **Watch**: secondary `Pair a watch` (opens Pair watch), caption that it can be done later, privacy caption.

## ARCHITECTURE notes
- **One draft, steps kept alive.** `OnboardingPage` holds a single `Profile` draft (`@Local`) plus the consent flag.
  Step components take `@Param profile` and hand back a new copy with `@Event onChange` (the same contract as
  `EmergencyDetailsForm`). All eight steps are built once and hidden with `visibility(None)` except the current one,
  so half-typed fields (a contact, the AuthForm email) survive Back. Saved once, on Finish (`finalProfile` trims
  text, drops an ICD model without an ICD and an invalid birth date). Medicines are saved by `AddMedForm` as they are
  added, as before.
- `withDetails(draft, fromForm)` takes only the B4 fields (+ `notes`) from `EmergencyDetailsForm`'s output, so the
  form can never overwrite genotype, contacts or country.
- Finish and the returning-user path call `navStack.clear()` (lands on the tabs, also when the Welcome page sits
  under onboarding). Back on step 1 pops only when the page below is `Routes.WELCOME`; otherwise it is swallowed so
  the app is never entered without a profile.
- Returning user: after `AuthForm` reports `onDone(true)`, the page reads `LocalStore.getProfile()`; a profile there
  (restored by S1's ProfileSync) ends onboarding. S1 must restore **before** calling `onDone(true)`.
- `validPhone` moved to `onboarding/OnboardingFlow.ets`; `OnboardingPage` re-exports it so `SettingsPage` is
  unchanged.
- The old final step's free-text "notes for paramedics" field is gone from onboarding; it belongs to the
  emergency-details editor (S2). If S2's form has no notes field, the coordinator should add it there.
- Location is no longer asked silently after Finish (old behaviour); it is asked in step 7 with its reason.

## For Workstream A (routes, functions, contracts)
- No new routes. Onboarding stays at `Routes.ONBOARDING`.
- For S1 (launch routing): Welcome → onboarding should push `Routes.ONBOARDING`; the account step is inside
  onboarding, so Welcome's "Get started" does not need its own sign-up page. A user who already signed in on
  `AuthPage` sees "Signed in as …" on step 2.
