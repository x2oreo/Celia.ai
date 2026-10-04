# S2 emergency

## AI_WORKFLOW entry
### 2026-10-04 - Georgi + Claude Code: configurable emergency profile and first-responder view (branch `georgi/b-emergency`)
- Asked: brief B4 (configurable emergency profile, card, versioned share payload) and B5 (first-responder view with
  "do not give", "use instead", care notes, reachable from the Emergency tab, lock screen, alert widget and SOS).
- Produced:
  - `LocalStore.parseStoredProfile`: defaults applied when a stored profile is read, so profiles saved before B4
    still load (lists default to `[]`, missing text stays absent, corrupt values fall back).
  - `emergency/Responder.ets` (pure): `doNotGive` (every Known-risk drug by class plus the avoid-in-congenital list;
    antiemetics first, then "Stimulants and catecholamines - avoid unless life-saving"), `useInstead` (dataset
    `alternatives[]` grouped by the option set, with the drugs and classes they replace), `careNotes` (lqts-domain
    emergency facts; ICD, beta-blocker and genotype trigger follow the profile), `ageYears`, `medRows`,
    `recentRiskyIntake` (72 h watch window).
  - `emergency/EmergencyDetails.ets` (pure): fixed card order, `detailRows`, `cloneProfile`, show-on-card helpers,
    list and birth-date parsing. `CardStrings.cardLabels`: English labels for the new fields, every other language
    falls back to English (no invented translations).
  - `components/EmergencyDetailsForm.ets` (contract kept: `@Param profile`, `@Event onChange`, never saves),
    `pages/EmergencyProfilePage.ets` (debounced save), one Settings row.
  - Emergency card renders the details between treatment and medicines; empty fields hidden; `hiddenOnCard`
    respected for name, contacts, notes and every detail field.
  - Card payload v2 (`emergency/CardLink.ets`): optional short fields `d s b a k r h e`. App, scanned-card page and
    `site/card/index.html` read v1 and v2. Hidden fields never enter the payload. QR fallback limit unchanged
    (900 chars); trimming drops the least urgent fields first and keeps genotype, ICD, blood type, first allergies.
  - `pages/ResponderPage.ets`: always light (`card_fixed_*`), large type, order of the brief, call buttons. Entry
    points: top of the Emergency tab, app lock screen, tap on the facts of the 2×4 alert widget.
- Validated: phone unit tests 233/233 (new suites StoredProfile, EmergencyDetails, Responder, CardPayloadV2).
  Emulator (Pura 90, API 20), screenshots in `docs/screenshots/b/`:
  - an existing profile saved by the old code opened with defaults (no crash, card intact);
  - Settings → Emergency details: date of birth, sex, blood type, allergies, cardiologist, hospital and two extra
    fields entered and kept across an app restart (`emergency-details-edit.jpeg`, `-extra.jpeg`);
  - Emergency tab: "For first responders" row at the top (`emergency-tab-responder-row.jpeg`), the card shows the
    details in order (`emergency-card-details.jpeg`);
  - responder page top to bottom (`emergency-responder-top.jpeg`, `-scroll.jpeg`, `-bottom.jpeg`); hilog showed no
    app network activity while it opened;
  - widget target: a cold start with the alert-card want `{"target":"responder"}` lands on the responder page;
  - web viewer in a browser with a v1 and a v2 link (`emergency-web-card-v1.png`, `-v2.png`).
  - Two refresh bugs found and fixed on the emulator (chips and text fields in the form were @Builder by-value).
- Not validated: the physical tap on the alert widget from a home screen (the want it sends was replayed instead);
  the lock-screen button with the app lock on (the emulator has no screen lock to enable it); "show on card"
  switches on the emulator (unit-tested only).
### 2026-10-04 - Georgi + Claude Code: NFC handover of the emergency card, B14 (branch `georgi/b-emergency`)
- Asked: brief B14, write the card link as an NDEF URI record to a tag from a "Write to NFC tag" action next to the
  QR; guard on NFC availability; mark built, unverified.
- Produced: `emergency/NfcCard.ets` (foreground `tag.on('readerMode')` for NDEF and NDEF-formatable tags, one
  `makeUriRecord` message, `writeNdef` or `format` for blank tags; pure `ndefUriBytes`, `smallestTagFor`,
  `resultForError`), the action in the Emergency tab's QR panel, `ohos.permission.NFC_TAG` in `module.json5`.
  APIs checked against the API 20 SDK declarations in DevEco (`@ohos.nfc.tag.d.ts`, `tag/nfctech.d.ts`,
  `@ohos.nfc.controller.d.ts`); the Context7 MCP was not connected in this session.
  The tag gets the same link as the QR: the encrypted short link (97 bytes, fits an NTAG213) when sharing is on,
  else the in-link card (NTAG215/216, or refused when too long).
- Validated: 4 unit tests (NDEF size layout, tag fit, error mapping). Emulator: the action is hidden because the
  emulator reports no `SystemCapability.Communication.NFC.Tag` (`emergency-nfc-guard-emulator.jpeg`).
- Not validated: **built, unverified** - no real tag written, reader mode and the write path never ran. Known limit:
  editing the card replaces the encrypted link, so a written tag must be written again (the UI says so).

## README "How to verify" rows
| Feature | How to check |
|---|---|
| Emergency details (B4) | Settings → Emergency details → fill blood type, allergies, cardiologist; Emergency tab → full card shows them in a fixed order; switch "Show on card" off → the field disappears from the card and the QR |
| Old profiles load | `app/scripts/test.sh` → `StoredProfile.oldStoredProfileLoadsWithDefaults` |
| Card payload v2 | Emergency tab → QR → open link: details shown; an old v1 link still opens (test `CardPayloadV2.oldV1LinksStillOpen`) |
| First-responder view (B5) | Emergency tab → "For first responders": do not give, use instead, care notes, medicines, details, call buttons; works in airplane mode |
| Responder from lock screen | Privacy → App lock on → background 5 min → lock screen → "For first responders" (built, unverified on the emulator) |
| NFC card tag (B14) | Real phone with NFC: Emergency → Show card as QR → Write to NFC tag → hold an NTAG213+ sticker → tap the tag with another phone (built, unverified) |
| Responder from widget | Add the 2×4 Medical alert card → tap its text (built, unverified) |

## DESIGN.md subsection (new screens only)
### Emergency details (Settings → Emergency details)
`bg` page, intro in `body-sm` `ink_2`. One `surface` group per field (1 vp `border`, `radius_m`, padding 16): caps
label in `label` `ink_3` with a "Show on card" switch (`brand_accent`) on the right; inputs 48 vp on `surface_alt`,
`radius_s`; single-choice chips 44 vp pill (selected = `ink` fill). Invalid date: one `risk_possible_text` caption
(no red). Extra fields as label/value rows with a 48 vp delete target. Saved on change; caption "Saved on this phone".

### For first responders (route `responder`)
Always light (`card_fixed_*`), no title bar. Header band `card_fixed_alert`: back 48 vp, card title in `label`,
name `title-1`, condition `title-3`, chips (age, genotype) on `card_fixed_bg`, ICD line. Then on `card_fixed_bg`:
"Do not give" panel (`card_fixed_alert_tint`, 6 vp alert rule on the left, `title-2` heading in alert colour, groups
in `body` bold + `subtitle` names); "Use instead" groups; numbered care notes (28 vp ink circles); medicines with
the compact risk badge (shape + word) and a tinted "Recent QT-risk medicine" box; details as caps label + `subtitle`
value; contacts and cardiologist as 52 vp outlined call rows. Footer: source and "works offline" in `micro`.

## ARCHITECTURE notes
- Profile read path: `LocalStore.loadAll` → `parseStoredProfile` (defaults). Every screen that edits a profile must
  copy it with `cloneProfile` (keeps all fields). `SettingsPage.save` now starts from the stored profile.
  **S3:** the onboarding rewrite must not build a fresh `Profile` that drops the B4 fields.
- Card payload versions: v1 and v2 readable forever (`READABLE_VERSIONS`). New fields go in a new version.
- The responder view and the card honour `hiddenOnCard` everywhere they can be seen without unlocking.
- Responder opens with no network request: it reads only `LocalStore`, the bundled dataset and `DrugChecker`.

## For Workstream A (routes, functions, contracts)
- Route `responder` (`Routes.RESPONDER`), no param. Use it for the agent tile and home quick action.
- **S4:** on the SOS page after the countdown, push `Routes.RESPONDER` with `null`. Nothing else needed.
- `EmergencyDetailsForm({ profile, onChange })` for onboarding (S3); it never saves.

## Coordinator notes
- Touched outside my files: `pages/SettingsPage.ets` (one row + `save()` copy fix), `pages/CardViewPage.ets`
  (renders v2 rows), `entryability/EntryAbility.ets` (one `responder` tap branch).
- Also touched for B14: `module.json5` (`ohos.permission.NFC_TAG`, system grant, no runtime prompt).
- No backend changes, no migrations, no deploys.
