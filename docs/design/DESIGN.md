# Celia.ai Design System (v0.1)

> **Calm, warm, trustworthy.**

Heart-safety companion for people with Long QT syndrome (LQTS). Targets:

- **Phone**: HarmonyOS, 360 × 780 vp
- **Watch**: round AMOLED, 466 × 466 px

Everything is built natively in ArkUI, so we use only stacks, lists, cards, tabs and sheets. No blur stacks, shaders
or web-only effects. Visual source of truth is the design file *Celia Directions*: `docs/design/v2/` (screens 01–07,
orb states 09) is the **current direction** for the phone, specified in [10.1a](#101a-v2-layout-current-direction).
`docs/design/v1/` (B1–B6 phone + widgets, W1–W7 watch) stays the reference for the watch, the widgets and every
component v2 does not redraw. Where 10.1a and an older section disagree, 10.1a wins.

Units: lengths in `vp`, font sizes in `fp` (ArkUI). The design file uses px/dp, and they map 1:1.

---

## 1. Principles

| Principle | Meaning |
|---|---|
| **Calm, not clinical** | Soft warm surfaces and generous space. Premium health product, not a hospital system. |
| **Red is for danger** | Brand coral is identity and primary actions. Risk red appears only in verdicts and emergencies. |
| **Never colour alone** | Every risk = colour + shape + word. Users may be colour-blind and stressed. |
| **Unknown is never safe** | Grey, dashed, worded "Couldn't identify". "Not listed" still carries a caveat. |
| **The agent is a companion** | A breathing avatar and a caring voice, not a chatbot widget. Called "the agent" for now. |
| **Voice first** | You talk to the agent and it talks back. Both sides are written out as they speak. Typing is the second mode of the same conversation. |
| **Never QT, never an ECG** | The app shows what the watch reports: heart rate and the signals around it (resting rate, HRV, oxygen, breathing, sleep, steps, stress). It never measures or diagnoses QT and never draws an ECG trace. The watch face itself still shows heart rate only. |

---

## 2. Colour

Brand coral is for identity and primary actions only. It must never be mistaken for Known-risk red. Buttons inside
verdicts are neutral ink.

### 2.1 Brand and neutrals (light)

| Token | Hex | Use | Resource |
|---|---|---|---|
| `bg` | `#F8F5F2` | App background | `bg` |
| `surface` | `#FFFFFF` | Cards, bars | `surface` |
| `surface-alt` | `#F3EFEB` | Quiet buttons, wells | `surface_alt` |
| `border` | `#ECE6E1` | 1 vp card outline | `border` |
| `border-strong` | `#D9D1CA` | Secondary buttons, chip outlines | `border_strong` |
| `divider` | `#F1ECE8` | Row dividers inside a card | `divider` |
| `ink` | `#1F1A17` | Primary text, ink buttons, user bubble | `ink` |
| `ink-2` | `#3D3530` | Body copy | `ink_2` |
| `ink-3` | `#6B625C` | Secondary text (AA on white) | `ink_3` |
| `ink-4` | `#8A817B` | Fine print, placeholders | `ink_4` |
| `brand` | `#E5484D` | Primary action, agent | `brand_accent` ✅ |
| `brand-text` | `#C7353A` | Coral text and links (AA) | `brand_text` |
| `brand-tint` | `#FDECEC` | Emergency tab pill, hero card | `brand_accent_soft` ✅ |
| `on-brand` | `#FFFFFF` | Text/icons on coral or ink | `on_accent` ✅ |

✅ = already in `app/entry/src/main/resources/base/element/color.json`. Others are to be added under the listed name.

### 2.1a Chat and status resources (in `color.json`)

| Resource | Light | Dark | Use |
|---|---|---|---|
| `chat_user_bg` | `#1F1A17` (`ink`) | `#F5F0EC` | User bubble, ink buttons inside agent cards |
| `chat_user_text` | `#FFFFFF` | `#1F1A17` | Text on `chat_user_bg` |
| `status_offline_bg` | `#EFEAE6` | `#2A2421` | Offline / live-voice strip (6.7) |
| `status_offline_text` | `#4A423D` | `#D6CCC6` | Text on the offline strip |

### 2.2 Dark mode (phone)

Proposals, not yet drawn. Override the same resource names in `resources/dark/element/color.json`.

| Token | Hex | Use |
|---|---|---|
| `bg` | `#14100F` | App background |
| `surface` | `#1F1A17` | Cards, bars |
| `border` | `#332C28` | 1 vp outline |
| `ink` (text) | `#F5F0EC` | Primary text |
| `ink-3` (text-2) | `#B8AEA8` | Secondary text |
| `brand` | `#F26B6F` | Coral on dark |

Risk surfaces on dark: tint = ~14% of the risk colour over `#1A1614`. Keep the icon and label at full strength.

### 2.3 Watch (true-black AMOLED only)

The watch is the phone's dark mode on true black: the same warm neutrals, the same coral, the same risk language.
Tokens live in `watch/entry/src/main/ets/components/Theme.ets` (and `color.json` for the start window); screens
use the names, never a hex.

| Token | Hex | Use |
|---|---|---|
| `BG` | `#000000` | Screen background (pixels off) |
| `RING_TRACK` | `#1A1614` | Empty bezel ring, chart band |
| `SURFACE` | `#1F1A17` | Rows, tiles, cards (phone dark `surface`) |
| `BUTTON` | `#2A2421` | Secondary pill, icon wells |
| `BORDER` | `#332C28` | 1 vp outlines, dashed demo panel, grid lines |
| `TEXT` | `#F5F0EC` | Primary text (phone dark `ink`) |
| `TEXT_2` | `#B8AEA8` | Secondary text, units |
| `TEXT_3` | `#8A817B` | Fine print, caps labels |
| `BRAND` | `#F26B6F` | Coral on dark: primary non-risk actions, chart series, the agent |
| `CALM` | `#12B76A` | Ring and status "All good" |
| `ELEVATED` | `#FDB022` | Ring and text near a limit, low HR, amber badges |
| `ALERT` | `#F04438` | Alert ring, Need help, SOS |
| `*_TINT` | ~18% of the colour on black | Fills behind status pills and feel buttons (`CALM_TINT` `#0B2A1C`, `ELEVATED_TINT` `#33240A`, `ALERT_TINT` `#33100D`) |
| `CHART_BAR` | `#4A423D` | Trend range capsules (grey, so only slots over the max turn red) |
| `RISK_*_TEXT` | Known `#F97066`, Possible `#FDB022`, Conditional `#FAC515` | Verdict words on black (the §3 text colours are for light tints) |

Risk verdicts on the watch use the §3 solids and shapes unchanged (`ic_risk_*`).

---

## 3. Risk language (fixed, semantic)

**Never colour alone.** Every verdict = colour + **shape** + **word**. Unknown is grey and dashed so it never reads
as safe. These values are fixed. Do not restyle them per screen.

| Verdict | Label | Shape | Solid | Tint (bg) | Text | Resource | Meaning |
|---|---|---|---|---|---|---|---|
| Known risk | `KNOWN RISK` | Octagon + ✕ | `#D92D20` | `#FEE4E2` | `#B42318` | `risk_known` ✅ | Listed as known to prolong QT. Avoid; ask doctor. |
| Possible risk | `POSSIBLE RISK` | Triangle + ! | `#F79009` | `#FEF0C7` | `#93370D` | `risk_possible` ✅ | Possible QT effect. Check with doctor. |
| Conditional | `CONDITIONAL` | Diamond | `#EAAA08` | `#FEF7C3` | `#854A0E` | `risk_conditional` ✅ | Risky only in some situations (dose, other drugs, low potassium). |
| Not listed | `NOT LISTED` | Circle + ✓ | `#12B76A` | `#DCFAE6` | `#067647` | `risk_not_listed` ✅ | Not on the QT list. Always add "Not listed doesn't guarantee safety." |
| Unknown | `UNKNOWN` | Dashed circle + ? | `#667085` | `#EAECF0` | `#475467` | `risk_unknown` ✅ | Couldn't identify. Never styled like safe. |

Add tint and text variants as `risk_<level>_tint` and `risk_<level>_text`.

Extra risk-adjacent values:

- Known-risk card border: `#F4B5AF`. Known-risk subtitle text: `#912018`.
- Possible-risk chip border (out-of-range HR chip): `#FEC84B`.

**Risk badge (pill):** height 32, radius 16, padding 4 left / 12 right, gap 8. Shape icon 24 × 24 with a white glyph
on the solid colour. Label 13 fp, weight 800, letter-spacing +0.03em, text colour on tint background.

Verdicts are produced by deterministic data. The LLM only explains them (see `CLAUDE.md`). UI must never derive a
verdict colour from model output.

---

## 4. Typography

**HarmonyOS Sans** in production (system default, no font bundling). Design previews use Figtree as a stand-in.
A monospace face (JetBrains Mono in previews, system mono on device) is for tiny technical badges only:
`WATCH`, `SIMULATED`, `ON-DEVICE`.

| Style | Size / line height | Weight | Use | Sample |
|---|---|---|---|---|
| `display` | 60 / 60 | 800 | Phone HR hero | 72 bpm |
| `title-1` | 28 / 32 | 800 | Screen titles | Medicines |
| `title-2` | 24 / 30 | 700 | Section / prompt titles | What's on your mind? |
| `title-3` | 20 / 26 | 700 | Greeting | Good afternoon, Ola |
| `headline` | 17 / 22 | 700 | Drug name | Klacid → clarithromycin |
| `body` | 16 / 23 | 500 | Agent text | Your heart rate jumped while you were resting. |
| `body-sm` | 14 / 20 | 500 | Card copy | Not known to affect QT. Tell your doctor what you take. |
| `label` | 12–13 | 700 | Caps labels, +0.04em | KNOWN RISK · MY MEDICINES |
| `caption` | 11 / 15 | 500 | Disclaimer, source line | CredibleMeds-derived list · Not a medical device. |

Existing resources: `font_title` (24 fp = `title-2`), `font_body` (16 fp = `body`), `font_caption` (12 fp = `label`).
Add `font_display`, `font_title_1`, `font_title_3`, `font_headline`, `font_body_sm` and `font_micro` (11 fp) as needed.

---

## 5. Spacing, radius, elevation

### 5.1 Spacing (8 vp grid, with 4 and 12 half-steps)

| Value | Use | Resource |
|---|---|---|
| 4 | Icon gaps | `space_xs` ✅ |
| 8 | Chip gaps, inner rows | `space_s` ✅ |
| 12 | Card inner gaps | `space_sm` |
| 16 | Card padding | `space_m` ✅ |
| 20 | Screen side margin | `space_screen` |
| 24 | Section gaps | `space_l` ✅ |
| 32 | Large breaks | `space_xl` ✅ |

### 5.2 Radius

| Value | Use | Resource |
|---|---|---|
| 6 | Bubble tail corner | `radius_xs` |
| 12 | Small buttons, strips, verdict actions | `radius_s` |
| 16 | Buttons, list cards | `radius_m` ✅ |
| 20 | Chat bubbles, showcase cards | `radius_ml` |
| 24 | Cards, widgets | `radius_l` |
| 28 | Bottom sheet top corners | `radius_sheet` |
| pill | Chips, input bar (use `height / 2`) | - |

### 5.3 Elevation

- **E0 (default): flat.** Surfaces separate with a 1 vp `border` (`#ECE6E1`), not a shadow.
- **E1: sheets and floating widgets only.** Shadow `0 8 24 rgba(31,26,23,0.14)`
  → ArkUI `.shadow({ radius: 24, color: '#241F1A17', offsetX: 0, offsetY: 8 })`.
- **Scrim** behind sheets: `rgba(31,26,23,0.45)` → `#731F1A17`.

### 5.4 Touch targets

Minimum **48 vp**. 44 vp is allowed only for chips inside cards and quick replies.

---

## 6. Components

### 6.1 Buttons

| Variant | Fill | Text | Use |
|---|---|---|---|
| **Primary** | `brand` | white, 15 fp / 700 | Scan, mic, send |
| **Ink (verdict action)** | `ink` | white, 15 fp / 700 | Ask your doctor, Add to meds (inside verdicts) |
| **Secondary** | transparent, 1.5 vp `border-strong` | `ink`, 15 fp / 600 | Alternatives |
| **Danger** | `risk_known` `#D92D20` | white, 15 fp / 800 | Real emergencies only ("Call 112") |

Height 48 (52 in sheets), radius 14–16, horizontal padding 20. Never use coral for verdict buttons. Never use red for
non-risk UI.

### 6.2 Heart-rate chip and source badge

- HR chip: height 36, pill (radius 18), padding 0 12, gap 6, `surface` + 1 vp `border`. Heart glyph in `brand`, value
  14 fp / 600, unit "bpm" 500 in `ink-3`.
- Heart glyph pulses (see [Motion](#8-motion)) only while a live source is connected.
- **Source badge**, mono 9 fp / 700, radius 4, padding 3 × 5:
  - `WATCH`: solid `ink` background, white text.
  - `SIMULATED`: outlined, white background, 1 vp `ink` border, `ink` text.
- **Out-of-range HR chip**: takes the risk tint and its shape (e.g. Possible: `#FEF0C7` bg, `#FEC84B` border,
  `#93370D` text, triangle icon), height 32, 13 fp / 700.

### 6.3 Chat bubbles and quick replies

- **User bubble**: `ink` fill, white text 15 fp, padding 10 × 14, radius 20 / 20 / 6 / 20 (tail bottom-right),
  aligned end.
- **Agent text**: plain `body` text in `ink`, aligned start, no bubble (locked direction).
- **Quick-reply chips**: height 44, pill, padding 0 16, gap 8, 15 fp / 600.
  - Default: white, 1.5 vp `border-strong`.
  - Selected / emphasised: `ink` fill, white text.
  - **Escalation** ("Call for help"): outlined danger (1.5 vp `#D92D20`, text `#B42318`, 700). **Never filled.**

### 6.4 Verdict card

Anatomy, top to bottom:

1. **Header band**: risk tint background, padding 12 × 14, gap 10. Shape icon 32 × 32 + word (16 fp / 800,
   risk text colour) + one-line subtitle (12 fp, e.g. "Can affect heart rhythm").
2. **Name → ingredient**: `headline` (e.g. "Klacid → clarithromycin").
3. **Reason**: 1–2 plain-English sentences, 14 fp, `ink-2`, line height 1.45. Never blaming.
4. **Actions**: row, gap 8. Ink button (flex 1, "Ask your doctor") + secondary ("Add to meds"). Height 44, radius 12.
5. **Source + disclaimer**: 11 fp, `ink-4`. "CredibleMeds-derived list · Not a medical device. Always ask your doctor
   or pharmacist." Quiet grey text, **never a banner**.

Container: radius 20, 1.5 vp border in a risk-tinted colour (Known: `#F4B5AF`), body on `surface`, padding 12 × 14,
gap 6.

Three sizes: **inline chat card**, **full-screen sheet**, **2 × 2 widget**.

**Interactions with my medicines** (sheet size): one Possible-tint row per interacting medicine (Possible shape 20,
bold title in `risk_possible_text`, the deterministic reason in `body-sm` `ink-2`, radius 12, padding 12), enzyme
interactions first. Any interaction raises the **header band** one level (Not listed or Conditional → Possible,
Possible → Known; Unknown never changes), and the subtitle then reads "Higher with your medicines". The reason
line and the doctor question keep the medicine's own category. The chat card and the sheet use the same rule, so
they always show the same word.

### 6.5 Tab bar

Four tabs and the agent in the middle: **Today · Medicines · (orb) · Health · Emergency**.

- Bar: `surface`, 1 vp top `border`, height `tab_bar_height` (64). Five equal slots; the middle one is the orb.
- Tab: 24 vp icon over an 11 fp label. Inactive: 600, `tab_inactive`. Active: 700, `brand_text`, icon in `brand`.
- **Orb** (middle): the silk orb at `avatar_tab` (56) on a 68 vp `surface` disc, raised so about half of it stands
  above the bar. Label "Talk" under it. Tap: opens the agent stage (10.1a). It is not a tab and never looks selected.
  A 12 vp `ink` dot with a 2 vp `surface` ring at its top-right means the agent has something to say (a dose is due
  or was missed); the same sentence is the agent line on Today.
- **Emergency** is always tinted: a `brand-tint` pill (height 24, radius 12) reading `SOS` (10 fp / 800, +0.06em),
  label in `risk_known_text`. Selected: the pill turns solid `danger` with white text. Long press starts the SOS
  countdown (the same 30 s, cancellable countdown as the Start SOS tile).

### 6.6 Agent avatar: the silk orb

- Name: "the agent" (persona name not final).
- **Orb (locked): the silk orb, palette "Dawn".** A soft sphere with no hard outline, silky white bands that wrap and
  turn around it, and colour that drifts inside: coral shifting to peach with a touch of rose-violet. No rings, no
  orbit arc: the orb itself carries the state.
- Palette (RGB, in `components/SilkOrb.ets`; the body stops are also `orb_light` / `orb_mid` / `orb_dark`):

| Part | Value |
|---|---|
| Body, radial, highlight up-left | `#FFCEB0` → `#F27470` (60%) → `#D4609C` |
| Drifting blobs | `#FFDCAA` 80%, `#C460B2` 50%, `#FF8C76` 70% |
| Bands | `#FFF6F0`, 0.8–1.9 vp wide, 16–66% opacity |
| Own glow under the orb | `#F27470` at 16% |
| Halo | `#F27470` (the agent) or `ink-4` (the user), up to 26% |

- Build: one ArkUI `Canvas`, 2D context. Body gradient, three soft blobs, three groups of eight bands (latitude
  circles of a sphere whose axis slowly tumbles, front half only; four per group at tab size), then a radial alpha
  mask (`destination-in`) for the soft edge, and the glow and halo painted behind (`destination-over`). No shader,
  no blur.
- Sizes: **104** in the stage dock, **56** tab bar (animated, four bands per group).
  **28 / 40** inline (`components/AgentAvatar.ets`): a still Dawn gradient with the sheen, no bands.
- Idle: one slow breath (4 s). Never a double beat that could read as a pulse; nothing that looks like an ECG.

### 6.6a Voice orb (hero of the conversation)

The orb is the agent's face while you talk. `components/SilkOrb.ets`, placed by `components/agent/OrbDock.ets`.

| State | The orb | Label under the orb |
|---|---|---|
| Off | bands faint, turning slowly, slow single breath | "Tap to talk" |
| Connecting | bands brighten and pick up speed | "Connecting…" |
| Listening (waiting for you) | calm; a soft neutral halo appears behind it | "I'm listening" |
| Hearing (you are speaking) | neutral halo follows your voice, bands ripple with it, orb draws in slightly | "Listening…" |
| Thinking | all bands line up and spin together on one axis, slightly dimmer | "Thinking…" or the running tool step |
| Speaking | orb swells with the agent's voice, bands bright and fast, warm halo | "Speaking" |
| Muted | faded (45%) and still | "Muted. Tap the mic to unmute." |

Neutral halo means "your voice", warm means "the agent". The label always says the state in words, so it never
depends on colour or motion alone. While live the label carries a 8 vp dot in the same colour family
(`brand` for the agent, `ink-4` for you). On the stage the orb sits in the dock at the bottom (10.1a, screens 02
and 03), floating over the conversation with a soft glow behind it.

### 6.6b Icons: Lucide

One icon set everywhere: **Lucide** (lucide.dev, ISC licence), 24 × 24, 2 px stroke, round caps and joins. Chosen
from the *Celia Icons* comparison (Phosphor, Tabler, Lucide).

- Files: `app/entry/src/main/resources/base/media/ic_*.svg`, from `lucide-static` 1.51.0. Each file names its
  Lucide source in a comment.
- **Strokes are outlined to fills.** ArkUI `Image.fillColor` tints fills only: a stroke icon keeps a black stroke
  and gets its inside flooded. So every icon is converted once (stroke → filled outline, `fill-rule="evenodd"`) and
  then tints like any other glyph. To add one: download the Lucide SVG, run `npx oslllo-svg-fixer -s in -d out`,
  wrap the resulting path as `<path fill="#000000" fill-rule="evenodd" d="…"/>`, save as `ic_<name>.svg`.
- Colour comes from `fillColor` with a token, never from the file. Sizes: 24 in the tab bar and dock, 20–22 in
  buttons and tiles, 16–18 for chevrons and inline marks.
- Selected state is colour, not a second glyph: an active tab tints its outline icon `brand`. The one solid glyph
  is `ic_heart_fill` (live heart rate).
- The **risk shapes** (`ic_risk_*`) are not from the set and never will be: they are the fixed verdict language
  of §3.

| Job | Lucide | File |
|---|---|---|
| Today · Medicines · Health · Emergency | `house` · `pill` · `heart` · `siren` | `ic_tab_home` · `ic_tab_medicines` (`ic_pill`) · `ic_tab_heart` · `ic_tab_emergency` |
| Settings · History · Chats | `settings` · `history` · `message-circle` | `ic_settings` · `ic_history` · `ic_chat` |
| Scan a box · Camera · Search · Add | `scan-barcode` · `camera` · `search` · `plus` | `ic_scan` · `ic_camera` · `ic_search` · `ic_plus` |
| Reminder · Alarm · Dose taken · Check | `bell` · `alarm-clock` · `circle-check` · `check` | `ic_bell` · `ic_alarm` · `ic_circle_check` · `ic_check` |
| Trends · Log how I feel · Doctor visit · Watch | `chart-column` · `smile` · `stethoscope` · `watch` | `ic_chart` · `ic_smile` · `ic_doctor` · `ic_watch` |
| Talk · Muted · Type · Voice · Read aloud · Send | `mic` · `mic-off` · `keyboard` · `audio-lines` · `volume-2` · `send` | `ic_mic` · `ic_mic_off` · `ic_keyboard` · `ic_wave` · `ic_volume` · `ic_send` |
| Call · Responder · Medical card · QR · Language | `phone` · `hand-heart` · `id-card` · `qr-code` · `languages` | `ic_phone` · `ic_hand` · `ic_id_card` · `ic_qr` · `ic_languages` |
| Hospital · Pharmacy · AED · First aid · Place · Travel | `hospital` · `store` · `zap` · `briefcase-medical` · `map-pin` · `plane` | `ic_hospital` · `ic_store` · `ic_zap` · `ic_first_aid` · `ic_location` · `ic_plane` |
| Back · Forward · Expand · Close · Share · Copy · Delete · Lock · Notes · Box | `chevron-left` · `chevron-right` · `chevron-down` · `x` · `share-2` · `copy` · `trash-2` · `lock` · `notebook-pen` · `package` | `ic_chevron_left` · `ic_chevron_right` · `ic_chevron_down` · `ic_close` · `ic_share` · `ic_copy` · `ic_delete` · `ic_lock` · `ic_notes` · `ic_box` |
| Person | `user` | `ic_user` |

### 6.7 States

| State | Style | Example copy |
|---|---|---|
| **Offline** | Neutral grey strip: `#EFEAE6` bg, 8 vp `ink-4` dot, 13 fp / 600 `#4A423D`, radius 12. Not an error. | "I'm offline, but medicine checks still work." |
| **Error** | Amber strip: `#FEF0C7` bg, `#93370D` text, radius 12, always with a fallback action. **Never red.** | "Couldn't read that box. Type the name instead?" |
| **Empty** | Dashed card: 2 vp dashed `border-strong`, radius 16, centred 13 fp `ink-3`, plus one primary button. | "No medicines yet. Add one or scan a box." |

### 6.8 Tool steps and agent cards

What the agent does is always visible. `components/AgentCards.ets`. All of it is built from deterministic tool
results, never from model text.

- **Tool step**: pill, height 36, `surface` + 1 vp `border`. Icon well 28 (`surface-alt`, radius 8, 14 vp icon in
  `ink-2`), label 13 fp / 500, then three typing dots while it runs or a 16 vp check when done. Running copy is
  present tense in `ink` ("Checking Klacid against the QT list"), finished copy is past tense in `ink-3`
  ("Checked Klacid against the QT list"). **Neutral ink only**: a finished step is not a verdict, so it never
  uses a risk colour or risk shape. Steps stay above the reply they belong to.
- **Card shell**: `surface`, 1 vp `border`, radius 20, padding 14, gap 12, with the verdict-reveal motion.
- **Confirm card** (add a medicine, share the emergency card): icon well 40 + `headline` title + `body-sm` detail,
  the compact risk badge of the medicine when there is one, then `Confirm` (ink) + `Cancel` (secondary). After the
  tap the buttons become one quiet line: "Confirmed" with a check, or "Cancelled". Never coral.
- **Medicines card**: caps label "MY MEDICINES · N", one row per medicine (name 15 fp / 700, dose in `ink-3`,
  compact risk badge at the end), `divider` between rows, secondary `Open medicines`.
- **Options card** (alternatives): caps label, "Instead of X" in `headline`, chips with the Not-listed shape and
  the name, the note, and always the caption "Not listed doesn't guarantee safety. Only a doctor can switch your
  medicine." With no verified option it says so and shows no chips.
- **Emergency notice**: risk-known tint, 1 vp `risk_known_border`, radius 16, phone icon + bold line + outlined
  danger chip `Open SOS`. After the countdown is cancelled it turns neutral (`surface-alt`, `ink-3`) with no chip.
- **Action tile** (open the scanner, open the emergency card): icon well 40, title 15 fp / 700, subtitle in
  `ink-3`, chevron.

### 6.9 Medicine cards, detail sheet and dose status

Everything a medicine card says comes from data: class, risk and interactions from the QT dataset, "what it's for",
"how it works" and tips from `drugs/DrugInfo.ets` (public patient leaflets). An AI explanation is optional,
labelled and separate.

- **Grid card** (Medicines, B4): height 164, compact risk badge, name in `headline`, "what it's for" in `caption`
  `ink-3` (2 lines), dose as a small `surface-alt` pill. Tap opens the detail sheet; long press keeps the menu.
- **Detail sheet** (`components/MedicineDetailSheet.ets`, large detent): pill icon well 52 on `brand-tint`, name in
  `title-2`, "ingredient · class · dose" in `ink-3`. Then, in order:
  1. **Risk band**: full risk badge + the dataset reason, `surface`, radius 20, 1.5 vp border (`risk_known_border`
     for Known, dashed for Unknown).
  2. **What it's for**: caps label, use in `headline`, how it works in `body-sm` `ink-3`, divider, "Good to know"
     tip rows (icon well 28 + `body-sm`).
  3. **With your medicines**: one row per deterministic interaction (Possible shape 20 + "+ other drug" in
     `risk_possible_text` + reason), or one quiet line when there is none. Alternatives as "Ask your doctor about".
  4. **Also sold as**: brand chips, height 32, pill, `surface-alt`.
  5. **AI explanation**: a quiet button "Explain it in plain words". While loading, typing dots with a label. The
     result sits on `surface-alt` (no border) with a solid `AI SUMMARY` source badge, body text, "What's in it",
     tips, and the 11 fp caption saying it is generated and that the badge above is from the QT list. It enters
     with the verdict-reveal motion. **AI text never sets a colour, shape or badge.**
  6. Actions: ink `Full check` + secondary `Remind me` (opens Reminders with the medicine picked), then a full-width
     quiet `Ask the agent` (opens the chat and sends "Tell me about X…"), then the source caption.
- **Add-medicine preview** (`AddMedForm`): once the name resolves, a `surface` box (radius 12, 1 vp `border`, padding
  12) shows the ingredient (`body` / 700), class in `caption`, compact risk badge, "what it's for" in `body-sm` and
  the first tip. It fades in over 180 ms. An unknown name keeps the one-line "not recognised" row. When the
  medicine interacts with one already saved, each interaction follows inside the box as a row: Possible shape 20,
  "With your medicines" in `caption` / 700 `risk_possible_text`, the reason in `body-sm` `ink-2`. The agent's
  confirm card shows the badge after the same rule.
- **Dose status** (Reminders) is not a verdict, so it never uses risk red or risk shapes:

| Status | Rail dot | Word (caps, 11 fp / 700) | Card |
|---|---|---|---|
| Taken | 20 vp `ink` circle + white check | `TAKEN`, `ink-3` | 72% opacity |
| Due now | 14 vp solid `brand` dot | `DUE NOW`, `brand-text` | 1.5 vp `brand` border, coral `Taken` pill |
| Missed | 12 vp hollow `risk_possible` ring | `MISSED`, `risk_possible_text` | coral `Taken` pill |
| Later | 12 vp hollow `border-strong` ring | `LATER`, `ink-3` | quiet `Taken` pill (`surface-alt`) |

The `Taken` pill is 44 vp tall (`chip_height`, radius 22) so a dose is logged with one thumb.


### 6.10 Health charts and the status box

One chart system for every watch metric (`components/MetricChart.ets`, maths in `vitals/Metrics.ets`). Built from
ArkUI shapes so every colour is a resource and dark mode follows.

**Form follows the number**

| Form | Metrics | Marks |
|---|---|---|
| Line | Resting heart rate, HRV, blood oxygen, breathing, live heart rate | 2 vp `brand` line, smoothed without overshoot, `brand` area at 8% under it. A day with no reading breaks the line; it is never bridged. A lone day is a 6 vp dot. |
| Range | Heart rate per day | 6 vp capsule from the day's lowest to highest reading (`brand` at 30%), 6 vp `brand` dot at the average. |
| Bars | Sleep, steps, stress time | Bars from zero, 4 vp rounded top, 2 vp gap minimum, `brand` at 35%; the selected bar solid `brand`. |

**Anatomy, top to bottom**

1. **Readout**: the selected day's value in `headline` / 700 with the unit and the date in `body-sm` `ink-3`. It
   starts on the latest reading. Touching or dragging across the plot moves it: a 1 vp `border-strong` crosshair and
   a 10 vp `brand` dot with a 2 vp `surface` ring. The readout is the tooltip, so nothing floats over the data.
2. **Plot** (160 on a detail page): the **usual range** as a `surface-alt` band behind the marks, up to six 1 vp
   `border` grid lines with their values in `micro` `ink-4` on the left. One y axis, never two.
3. **Dates**: first, middle, last in `micro` `ink-3`.
4. **Legend line**: a `surface-alt` swatch + "Your usual range: 53–63 bpm" (own baseline) or "Usual range: 95–100 %"
   (fixed reference).
5. Resting heart rate only: the dose and symptom rows of 10.2 Trends, aligned to the same days, ink marks.

Series colour is always `brand`; values and labels stay ink. Mini charts on cards (36 high) keep the same form with
no axes and one emphasised last mark.

**Metric card** (Health grid): `surface`, 1 vp `border`, `radius_ml`, padding 14. Caps label + `SIMULATED` badge
when the signal is simulated, value in `title-2` / 800 with the unit in `caption`, the change ("↑ 3") at its
right, the mini chart, then the status pill. Whole card is the touch target.

**Status** is a fixed rule on the user's own numbers, never model output and never a diagnosis. Word + shape + tint,
never colour alone:

| Level | Word | Shape | Tint / text |
|---|---|---|---|
| Good | `Good` | Circle + ✓ | `risk_not_listed_tint` / `risk_not_listed_text` |
| Okay | `Okay` | Ring with a bar | `surface-alt` / `ink-2` |
| Attention | `Worth a look` | Triangle + ! | `risk_possible_tint` / `risk_possible_text` |
| No data | `No data` | Dashed ring | `surface-alt` / `ink-3` |

Never red: red stays with alerts and verdicts. Pill height 28 (24 on cards), radius 14, shape 16.

Rules (`metricBand`, `levelFor`): inside the usual range = Good, a little outside = Okay, well outside = Worth a
look. Resting and daily heart rate and HRV use the user's own baseline (median of the days before the last two,
at least five days); oxygen, breathing, sleep and stress time use fixed reference values; steps are never judged
past Okay. Change is the last 7 days against the days before ("Up 3 bpm from the week before").

**What this means box**: card with the status pill and the change chip on one row, one or two fixed sentences
(`body` `ink`), a `divider`, caps "ABOUT THIS NUMBER" and one plain-English paragraph (`body-sm` `ink-2`), then
the caption "Fixed rules on your own numbers. Not a diagnosis. Always ask your doctor." Signals the watch can only
simulate today (HRV, oxygen, breathing) always carry the `SIMULATED` badge and the line "Simulated signal".

---

### 6.11 Settings list (grouped rows)

Settings is an index, never a form: every editable thing opens its own page or sheet and saves on change there.

- **Group** (`components/SettingsList.ets` `SettingsGroup`): caps label above (`CapsLabel`), then one `surface`
  card, 1 vp `border`, `radius_l`, no inner padding. Rows are separated by a 1 vp `divider` inset 64 vp from the left
  (it starts after the icon well). 24 vp between groups.
- **Row** (`SettingsRow`): min height 60 vp, padding 12 / 16. Icon well 36 on `surface_alt`, `radius_s`, glyph 20 in
  `ink_2`. Title in `body` / 500 `ink`; value line under it in `caption` `ink_3`, one line, ellipsis. The value says
  the current state in words ("Germany · 112", "2 people", "Paired with 1a2b3c4d"), never a repeat of the title.
  Trailing chevron 18 in `ink_4`. **Danger** variant (clear data): well on `risk_known_tint`, glyph and title in
  `risk_known`, no chevron. Whole row is one touch target with the light click effect.
- **Profile card** (top of Settings): `surface`, 1 vp `border`, `radius_l`, padding 16. Avatar circle 56 on
  `brand_accent_soft` with the first letter of the name in `title-3` / 800 `brand_text` (no name: `ic_user` in
  `brand_text`). Name in `headline` (or "Add your name" in `ink_3`), then chips: genotype ("LQT2", "Genotype not
  set") and "ICD" when set, each `caption` / 600 on `surface_alt`, pill, 24 vp high. Under them the account line in
  `caption` `ink_3` ("Backed up to your account" / "On this phone only"; the email itself is on the Account row). Chevron right. Opens **Your profile**.
- **Choice sheet** (emergency number): `bindSheet` on `bg`, `SheetSize.LARGE`, close button, a 48 vp search field
  on `surface_alt`, then rows (60 vp, name in `body`, number in `body` / 600 `ink_2` on the right, selected row
  ends in `ic_check` `brand_text`). Picking saves and closes.
- Footer under the last group: the disclaimer in `caption` `ink_4`, centred.

## 7. Watch

Round 466 × 466 px AMOLED = **233 × 233 vp** (density 2). All sizes below are vp / fp. **Design file:
`docs/design/v2-watches/` (screens 01-18) is the current watch direction**; this section is its spec. `v1` W1-W7 is
superseded for the watch.

**Round-screen rules**

- Content lives inside the inscribed square (~165 vp) or follows the circle. Nothing important within 16 vp of
  the edge except the bezel ring.
- One idea per screen, glanceable in two seconds: one number, one word, one action.
- Lists (`ArcList`, crown scrolls, arc scroll bar on the right) start with a centred `CAPS` title in `TEXT_2`. Rows
  have no fill: label `SMALL` `TEXT_2`, value `TITLE`+ bold, a 1 vp `BORDER` divider between rows, 48 vp of air at
  the end.
- Actions are centred **pills** (height 40, radius 20): one pill alone (Got it, Done, Cancel, Not now) or two side by
  side (I'm OK / Need help, Took it / Not yet, New code / Close). Secondary = `BUTTON` fill; primary non-risk =
  `BRAND` fill; Need help = `ALERT` fill; SOS Cancel = white fill with dark text (the easiest target on screen).
- Touch targets at least 40 vp.
- Never colour alone: every status is word + shape + colour, exactly as on the phone (§3, §6.10).

**Type** (HarmonyOS Sans)

| Style | Size | Weight | Use |
|---|---|---|---|
| `HERO` | 64 | 800 | Home bpm, alert number, SOS seconds, fall seconds |
| `NUMBER` | 34 | 800 | Trend average; pairing code is 40 medium, +2 letter-spacing |
| `TITLE` | 17 | 700 | Screen titles, list values, drug name |
| `BODY` | 14 | 600 | Context lines, buttons |
| `SMALL` | 12 | 500 | Units, sub-lines, row labels |
| `CAPS` | 11 | 700, +1 letter-spacing | Caps titles (LAST 10 MIN, VITALS, HEART RATE HIGH) |
| `MICRO` | 9 | 700 mono | `SIM` / `DEMO DATA` outlined badges only |

**Bezel** (`components/Parts.ets` `Bezel`, one Canvas): an 8 vp ring 6 vp inside the screen edge over a
`RING_TRACK` track. Modes:

- **Gauge** (Home only): a 290° arc open at the bottom (the page dots sit in the gap). It fills from your min (left
  end) to your max (right end) at the live bpm. Above the max = full and red. Below the min = one dot at the left
  end. No reading = dashed.
- **Ring**: full circle in a zone colour. `ALERT` heart rate high; `ELEVATED` low heart rate and every signal alert;
  `BRAND` coral = Celia asking (check-in, missed dose), not an alarm; `CALM` done (SOS sent, paired).
- **Countdown**: the ring drains clockwise from 12 o'clock (fall 30 s, SOS 10 s, pairing code 5 min).
- **Spinner**: a short `BRAND` arc turning (getting a pairing code).
- **Dashed**: grey `BORDER` = no reading / nothing wrong (waiting, not on wrist, code expired); `ELEVATED` = needs a
  fix (SOS saved but not delivered, pairing failed).

**Status marks** (16 vp, before a word): filled dot = good, ▲ = near / above / worth a look, ▼ = below / low,
hollow circle = waiting / no data. Shapes are drawn (`StatusMark`), not font glyphs.

**Badges and chips**: chips are `SURFACE` capsules, 22 high, `SMALL` bold `TEXT` ("LQT2", "Phone ✓", "Syncing...",
"Offline", "No genotype" in `TEXT_2`). Outlined badges (`MICRO` mono, 1 vp `TEXT_3` border, radius 4) mark scripted
data: `DEMO DATA` on Home, `SIM` on every simulated signal. The simulator title is the same badge with a dashed border.

**Pages** (horizontal swiper; dots in the gauge gap, the current one a 12 × 5 capsule; the simulator is the last page
and exists only in a `DEMO_MODE` build):

| # | Page | Content |
|---|---|---|
| 1 | Home | Gauge, optional top badge (risky medicine, else `DEMO DATA`), status mark + word, `HERO` bpm, "bpm", "At rest · max 110" ("Asleep · min 45" when asleep or below the min), chips: genotype, phone. Waiting: dashed ring, "Waiting", two grey bars for the number, "Waiting for heart rate". Off the wrist: dashed ring, bars, "Not on wrist" + one line; alerts pause. |
| 2 | Heart rate · 10 min | Caps "LAST 10 MIN", `NUMBER` average + "avg bpm", "Range 66-118 · ▲ 3 over max" (the count in `ALERT` only when > 0). 20 slots × 30 s: a grey `CHART_BAR` capsule lowest-highest with a white average tick; slots that cross the max are `ALERT`. Dashed `TEXT_3` lines at your min and max with their numbers on the right, "10 min ago / now", "Resting 62 bpm" + `EST` until measured. Empty: a dashed box "Collecting readings..." + "Your chart fills in as readings arrive." Never a trace. |
| 3 | Vitals | List: Resting HR, HRV, Blood oxygen, Breathing, Rhythm, Stress, Recovery, State, Steps. Status on the right = mark + word (Good, Okay, Worth a look, No data). HRV, oxygen, breathing and rhythm carry `SIM`. State and Steps carry no status. Footer "Heart rate only. Never QT." |
| 4 | Log | Caps "LOG", "How do you feel?", Fine / Dizzy / Racing (52 circles, tint fill, 1.5 vp ring in the colour), a full-width `BRAND` "Took Nadolol" pill, an outlined SOS pill (`ALERT_TINT` fill, `ALERT` border and text). A tap replaces the title with "Logged: Dizzy" for 3 s, fills the chosen circle, dims the others and shows "14:32 · sent to your phone". After the dose the pill becomes `SURFACE` "✓ Nadolol taken 08:04" in `CALM` until midnight. |
| 5 | Settings | List: Phone ("✓ Paired" + phone and sync line; unpaired = "Pair with phone" in `BRAND`, the row opens pairing), Limits now ("45-100 bpm" + genotype · state · lowered for a medicine), Genotype ("Not set on phone" when empty), Dose reminder, Watch ID, footer "Not a medical device. Heart rate only, never QT or an ECG." |
| 6 | Simulator (demo) | Dashed badge "SIMULATOR · DEMO BUILD" and the running line in `ELEVATED` ("▶ LQT2 startle · 0:42"; an event shows here once). Labelled chip groups, selected chip = white fill, dark text: Source, Scenario, Speed, Events (Fall, Irregular rhythm, Low HRV, Low oxygen, Take watch off / Put watch on), State, Genotype, Risky medicine, Beta-blocker, then Dose nudge now / Reminder in 10 s. Every demo control lives here and only here. |

**Full-screen moments** (most urgent wins: SOS > fall/alert > check-in > dose nudge > verdict > pairing):

- **Heart rate alerts (7-8)**: zone ring, caps title with ▲ / ▼, `HERO` number in the zone colour, "bpm · at rest",
  then the limit and why ("Limit 110 · LQT2 at rest", "Limit 100 · lowered for Clarithromycin"), I'm OK / Need help.
  Low while asleep is amber with "))) Gentle wake-up tone" and never the alarm sound.
- **Signal alerts (9)**: amber ring, value or word ("Irregular"), unit + `SIM` + context ("· at rest", "· usual 45"),
  one line of advice. Slow recovery shows the drop ("-8", "bpm in 1 min", "Usually -20 after exercise.").
- **Fall (10)**: `ALERT` countdown over 30 s, caps "FALL DETECTED" in `BRAND`, "Are you OK?", seconds + "s",
  "No answer sends an SOS", I'm OK / Need help.
- **Check-in (11)** after I'm OK: `BRAND` ring, "How do you feel?", the three circles, "Racing = palpitations",
  Not now. Dizzy or Racing logs it and then offers Need help next to Done.
- **SOS (12-13)**: countdown 10 s, caps "SOS", "Sending SOS", `HERO` seconds, white Cancel. Sent: `CALM` ring, check
  disc, "SOS sent", the bystander card (`ALERT_TINT`, `TITLE` bold: "I have Long QT syndrome. Call 112.", the biggest
  text on screen), Done. Saved: dashed amber ring, warning triangle, "SOS saved", "Not sent yet. Retrying when your
  phone is in reach...", the same card. The watch never calls 112 itself.
- **Verdict (14)**: no ring; the §3 shape (40 vp), drug name, the level word in its dark-mode risk text colour
  (`RISK_*_TEXT`), "Ask your doctor before you take it.", "Your watch now watches more closely.", Got it.
- **Missed dose (15)**: `BRAND` ring, caps "DAILY DOSE", "Did you take Nadolol?", "Skipped beta-blocker doses raise
  the risk.", Took it / Not yet (snoozes 30 min; the second ask reads "Later").
- **Pairing (16)**: spinner + "Getting a code..." + Cancel; code ring drains over 5 min with "PAIR WITH PHONE",
  the code, "Type this code in Celia on your phone", "Expires in 3:45"; Paired = `CALM` ring + check disc; Code
  expired = dashed grey (nothing is wrong with your heart); Pairing failed = dashed amber + the reason, New code /
  Close.
- **System surfaces (17-18)**: notifications use the pattern "shape + title" / "value + state + limit", `SIM` marked
  ("▲ Heart rate high" / "165 bpm at rest. Limit 110. Tap to open."). The daily reminder is a system reminder:
  "Time for Nadolol" / "Your daily dose", Done / Snooze (10 min); ignored, the missed-dose nudge follows.

- The watch shows **heart rate and the signals around it. Never QT, never an ECG trace.**

---

## 8. Motion

| Pattern | Spec |
|---|---|
| **Heartbeat pulse** | Live HR icon scales 1 → 1.25 → 1 → 1.15 → 1 over ~1.1 s (keyframes at 0 / 15 / 30 / 45 / 100%). Home ring pulses opacity in time. Stops when the source disconnects. |
| **Agent breathing** | Avatar scale 0.92 ↔ 1.04 (opacity 0.92 ↔ 1) over 4 s ease-in-out, infinite. |
| **Voice orb** | Canvas frames every 33 ms (50 ms at tab size); values ease towards the state (≈ 170 ms time constant), the voice level a little faster. Thinking: bands align and turn at 2.4 rad/s. The stage eases between its sizes in 320 ms. Reduced motion: one settled frame per state, labels stay. |
| **Live words** | The user's bubble sits at 60% opacity while the words are still being recognised (three dots before the first word), then becomes solid. The agent's text grows word by word. No cursor, no typewriter effect. |
| **Typing** | Three 7 vp dots, 1.2 s loop, staggered 150 ms. Pair with a label like "Reading the box…" when the wait is known. |
| **Verdict reveal** | Card slides up 12 vp and fades in over 240 ms. Badge settles 100 ms later. No bounce or shake, even for Known risk. |
| **Sheets** | Bottom sheets rise over 280 ms with a 45% scrim. SOS countdown ring drains linearly over 30 s (10 s for Test SOS). Every sheet body is a full-height `Scroll` (`height('100%')`), so long content scrolls inside the sheet instead of being clipped. One `bindSheet` per node. |

In ArkUI, use `animateTo` / `.animation()` with `Curve.EaseInOut` and `iterations: -1` for loops, and
`keyframeAnimateTo` for the heartbeat. Respect the system reduced-motion setting by dropping loops to static.

**Reduced motion** (`common/Motion.ets`, read once at start and on change):

- API 23 and later: the system "reduce animations" accessibility setting
  (`accessibility.isAnimationReduceEnabledSync()`, `onAnimationReduceStateChange`).
- API 20 to 22 (our minimum is 20): the SDK has no reduce-motion query. The fallback is the animation duration
  scale (`settings.display.ANIMATOR_DURATION_SCALE`); a value of 0 counts as reduced.
- When reduced: breathing, the sheen turn and the thinking arc stay still. Halos still follow the voice level (a
  response to sound, not a loop), and every state keeps its text label.
- Neither path has been seen switching on a device yet; on the API 24 emulator the setting reads "off".

A size or radius that changes with the orb must not sit under a looping `.animation()`: give it its own one-shot
`.animation()` above the loop, or it keeps swinging between the old and the new value.

---

## 9. Voice and content

**Do**

- Plain, short English. Explain any medical term in one line.
- Supportive tone: "Let's check that with your doctor."
- Use real drug names: clarithromycin, ondansetron, domperidone, ibuprofen, nadolol.
- Show the disclaimer quietly wherever a verdict appears: "Not a medical device. Always ask your doctor or pharmacist."
- Offer a next step on every card (Ask your doctor, Add to meds, Call 112).
- Keep touch targets ≥ 48 vp and text contrast at WCAG AA.

**Don't**

- Never blame ("You shouldn't have…").
- Never show a risk by colour alone.
- Never style Unknown like safe, or present Not listed as a guarantee.
- Never use coral for verdict buttons, or red for non-risk UI.
- Never show QT values, ECG-style traces of the user's heart, or diagnostic claims.
- Never use heavy blur, shaders or web-only effects. Everything has to rebuild in ArkUI.
- Never use em dashes (the long dash) in copy, UI strings, prompts or agent replies. Use a normal dash "-" with
  spaces around it, or split the sentence. The agent is told the same, and `plainDashes` swaps any it still writes.

---

## 10. Locked layout and screen specs

### 10.1 Direction (locked)

- **Home** (B1), superseded by 10.1a; kept for the look of the pieces that moved. Was the Agent tab: date, "Hi {name}", genotype chip, settings gear. Heart-rate ring (track `border`,
  arc `brand`, `display` bpm, "bpm · resting", source badge), status chips, then the **agent card** (orb 28, name,
  time, `body` message, `Scan a box` primary + `Ask something` quiet).
  Below it, the **tip of the day** (F-39 genotype coach, `coach/Coach.ets`, static and sourced, no AI): `surface` card
  with 1 vp `border`, `radius_l`, padding 16. Caps label "TIP FOR {LQT2}" (or "TIP OF THE DAY" when the genotype is
  unknown) in `label` `ink_3`, the tip title in `headline`, the body in `body-sm` `ink_2`. One tip per day; not
  tappable, so no press state. Never uses risk colours.
  **Travel banner** (T23, only when the phone is in another country than Settings and location was already allowed):
  above the HR ring, `surface` card, 1 vp `border`, `radius_m`, padding 14, location icon 18 `ink_2`, "You're in
  {Germany}" in `headline`, "Emergency {112} · Pharmacy card in {Deutsch}" in `body-sm` `ink_2`; the whole card
  (min 44 vp) opens the pharmacy card. The pharmacy card then shows the local language large and English small.
- **Conversation** (B2, revised: voice first) was a pushed page; it is now tab 0 without the back / title header
  (10.1a). The modes, thread and dock below are unchanged. Header: back, "The agent", `ON-DEVICE`
  badge when there is no backend, then two 44 icon buttons in `ink_2`: **Chats** (history icon, opens the chats list)
  and **New chat** (plus). New chat saves the open chat and returns to the empty state (orb 168, starters). It has two modes over the same thread.
  - **Voice (default)**: the voice orb (6.6a) with its state label, then the thread, then the dock: 52 camera
    circle, **72 coral mic**, and a 52 circle that is the keyboard (switch to typing) while idle and ✕ (end) while
    a conversation is running. Before anything is said the orb is 168 with the label in `title-3`, a one-line hint
    and three starter chips. One tap on the mic or the orb starts the conversation; the microphone never opens by
    itself. While live, the mic button mutes (outlined, struck mic). When live voice is unavailable the same
    button records one question: tap, speak, tap again (ink button with the send icon).
  - **Chat**: orb 40 in the header, thread, input bar: 48 camera circle, pill input, 48 coral button that sends
    when there is text and otherwise goes back to voice (wave icon).
  - **Thread** (both modes): user bubble is `ink`, agent text is plain with no bubble, tool steps above the reply
    (6.8), then one card per tool result (verdict card 6.4, agent cards 6.8). Words appear live while they are
    spoken (see Motion).
- **Avatar**: orb (6.6), sizes 24 / 28 / 40 / 96.
- **Tabs**: Agent · Medicines · Heart · Emergency (6.5).
- **Check-in** (B3): bottom sheet over home when the heart rate is out of range. Agent header "from your watch",
  out-of-range HR chip, question (`title-3`), `I'm fine` (secondary), `I feel dizzy` (ink), `Call for help`
  (danger), caption "If I don't hear back, I'll check again in 2 minutes." No answer → SOS countdown.
- **Medicines** (B4): `title-1`, a 56 vp outlined "Can I take…" search field + 56 coral camera button, "RECENTLY
  CHECKED" chips (risk shape + name), "MY MEDICINES · N" 2-column grid (small badge, `headline` name, dose in
  `ink-3`), dashed "Add a medicine" tile.
- **Scan** (B5): dark camera surface, close button, green "Found: X" pill, verdict sheet (sheet-size verdict card).
- **Widgets** (B6): "Can I take this?" 2 × 2 (ink card, orb corner, coral `Scan or type`) and Medical alert 2 × 4
  (coral-ringed "Call 112" circle, `MEDICAL ALERT` label, condition, ICD + meds, AVOID line, quiet ICE button).

### 10.1a v2 layout (current direction)

Source: `docs/design/v2/` (01 Today, 02 agent stage empty, 03 agent stage live, 04 Health, 05 Medicines,
06 Emergency, 07 Doctor visit; the doctor pages were redesigned after the drawing, see 07 below). The feeling, the order and the positions are the spec; the content is ours (more
than one health metric, the travel banner, interactions, the extra tools).

**Shared rules**

- Tab pages: `title-1` title, a 44 vp round `surface` settings button (1 vp `border`) on the right.
- Pushed pages: back chevron + `headline` title, **one primary action pinned at the bottom** on a `bg` strip with a
  1 vp top `border`, padding 16.
- Cards: `surface`, 1 vp `border`, `radius_l`, padding 16. Caps labels: 12 fp / 700, +0.06em, `ink-3`.
- Dose styling is neutral, never a risk colour (6.9).

**01 Today (tab 0, cold start)**. Everything above the fold on 360 × 780, top to bottom:

1. Header: date (`body-sm`, `ink-3`), greeting in `title-3` / 800 ("Good afternoon, Ola"; 00:00–04:59 a plain
   "Hi, Ola"), genotype chip, settings button.
2. Travel banner (only abroad, unchanged from T23).
3. **Agent line**: card, orb 40, one sentence from deterministic data (`components/agent/HomeBrief.ets`: a dose due
   or missed, then an interaction, then a known-risk medicine, else a calm line), chevron. Tap: the agent stage.
4. **Next dose**: caps "NEXT DOSE" + coral link "All reminders ›". Pill well 44, name + dose in `headline`,
   "Due at 14:00 · in 10 min" in `body-sm` `ink-3`, ink `Taken` pill (44). After the last dose: "All done for
   today". No reminders: one line and the link "Set a reminder".
5. **Resting · 7 days**: ring 84 with the live bpm and its source badge, the mini chart of the Health tab's
   resting heart rate card (6.10: the same component, `brand` line, last day as a dot) at 40 vp, "64 avg · 2 lower
   than last week" in `body-sm`. Tap: Health. The line joins daily averages, never a trace.
6. **Quick actions**, 2 × 2 tiles (height 64, icon well 36 on `brand-tint`, 15 fp / 700): Scan a box, Log how I
   feel, Doctor visit, Check a medicine.
7. Medicines chip ("All 3 medicines checked" with the Not-listed shape, or "N to review" with the worst risk
   shape). Interactions between the user's medicines follow as Possible-tint rows.
8. **Tip** (collapsed): `surface-alt` row, caps "TIP" + the title + chevron; open shows the body.

**02 Agent stage, empty** (pushed full screen from the orb, the agent line, or "Ask the agent"). The owner's
revision of the drawing: **the orb lives at the bottom centre, where a mic button would be**, and everything else
sits above it.

- Header: chevron-down (close), then `Chats` pill and a round `+` (new chat), both `surface` with 1 vp `border`.
- Content, top-aligned: the agent line of Today centred in `title-3`; caps "ASK ME" with starter chips stacked,
  start-aligned (white, 1.5 vp `border-strong`); caps "OR GO STRAIGHT TO" with feature chips on `surface-alt`, no
  border (Scan a box, Log how I feel, Doctor visit, Trends), wrapping.
- **Orb dock** (`components/agent/OrbDock.ets`): state label ("Tap to talk", `brand_text` 15 fp / 700), then a row:
  60 round `surface` scan button, **the orb at 104**, 60 round `surface` "Aa" (typing). Tap the orb: start talking.
  The microphone only opens on that tap.
- **The dock floats.** The conversation runs the full height of the stage underneath it and leaves 250 vp at its
  end, so the last line scrolls clear of the orb. No bar, no divider.
- **Backdrop** (`OrbBackdrop`): over the bottom 310 vp the conversation fades into `bg` (`bg_clear` → `bg` by 30%),
  and a 300 vp radial glow sits centred on the orb, `orb_glow` → `orb_glow_clear`, at 30% when idle. Only light: no
  rings, no lines.

**03 Agent stage, live voice**:

- Header: chevron-down, then mono caps "VOICE · 0:42" centred (elapsed time of the session).
- Before the first words the state stands alone in `title-2`, centred ("I'm listening").
- **Captions** instead of a chat list: "You: …" in `body` `ink-3`, the agent's sentence in `title-2` / 700 growing
  word by word (18 fp above 140 characters), the tool step pill, then the cards of this turn (verdict card,
  confirm cards, tiles) sliding in under the captions. A verdict never needs a page change.
- A round button at the right of the header (chat glyph) swaps the captions for the full thread; the same button
  (voice glyph) swaps back. Typing mode always shows the thread and the chat bar instead of the dock.
- Orb dock, live: state label with its 8 vp dot (`brand` for the agent, `ink-4` for you) and the hint "Tap the orb
  to mute". Row: 60 round **ink `End`** (✕ over the word; ink, not red: ending a call is not an emergency), the orb,
  60 round "Aa". **Tap the orb: mute / unmute** (the orb fades and stills when muted; the label says "Muted").
  Recording one question (tap-to-talk fallback): cancel ✕, orb (tap: send), "Aa".
- Light: the glow turns neutral (`orb_glow_user`) while you are heard and warm while the agent speaks, and pushes
  out slightly from the orb with the voice level (opacity 60–100%, scale 1.1–1.3, 160 ms ease-out). Muted: 10%.
  Nothing else moves around the orb.
- Leaving the stage (close, a pushed page, the app going to the background) ends the live session.

**04 Health (tab 2)**: every watch metric, one tap from its graph (6.10).

1. "Now" card: heart glyph in `brand`, bpm in `title-1`, "bpm now", source badge and one line in words on the right
   ("In your usual range", "Above your usual range at rest", "Asleep", "Active"). Under it the live line of the last
   minutes (plot 96) and a quiet "Rhythm · regular" row. Tap: Heart rate detail.
2. Caps "FROM YOUR WATCH · 14 DAYS", then the **metric cards** (6.10): Resting heart rate full width, then a
   2-column grid: HRV, Blood oxygen, Breathing, Sleep, Steps, Stress time. Tap: the metric's detail page.
3. "WHAT STANDS OUT" (fixed-rule findings), alerts, then demo controls.
   Demo controls (dashed card, collapsed): caps "DATA SOURCE" with two quick-reply chips, `Watch` / `Simulated`
   (selected style on the active one; shown when the watch's Supabase project can be reached), then the scenario
   chips, which only show for the simulated source. Switching restarts the live line and reloads the metric cards.
4. Pinned above the tab bar: coral `Log how I feel` + secondary `Doctor visit`, so they are never hunted for.

**04a Metric detail (pushed)**: header with the metric name. Big value + unit with the source badge, segmented
control `14 days · 30 days` (Heart rate adds `Now` first), the chart card (6.10) with the dose and symptom rows on
Resting heart rate, the **What this means** box, three stat tiles (average, lowest, highest), the fixed-rules
caption. Pinned: coral `Ask the agent about this`.

**05 Medicines (tab 1)**: header with a round History button next to settings; "Can I take…" field + coral camera
stay first. **Today's doses** (caps + "All ›" to Reminders) as a sideways row of 132 vp cards: taken (`surface-alt`,
"✓ Taken 08:04"), due (1.5 vp `ink` border, ink `Taken` pill), missed (same, word "Missed" in `risk_possible_text`),
later (dashed border, "Later"). Then recently checked, then the grid.

**06 Emergency (tab 3)**, new order: `Start SOS` tile (`danger` fill, "30 s countdown, you can cancel") next to a
`Call 112` tile (`surface`, 1.5 vp `danger` border, number in `risk_known_text`); **Show responder view** (ink tile,
caps "FOR THE PERSON HELPING ME"); **Medical card** summary (caps in `risk_known_text`, condition, facts, "Inside:
languages, read aloud, QR, share") whose "Open ›" unfolds the full card with its language row, read aloud and QR;
contact call buttons; Pharmacy card row; Help guide row (same style, opens the bystander steps + CPR); NEARBY (Hospital, Pharmacy, AED); "Test SOS (nothing is sent)" last and
small. Layout only: every action keeps its logic.

**07 Doctor visits (pushed, three pages)**. A visit is one saved page per doctor; the old single brief with
specialty chips is gone. Everything is fixed data (profile, medicine list, event log, the visit plan built from the
QT dataset); the only model text is the labelled AI summary.

- **Gallery** (`pages/DoctorVisitsPage.ets`): header "Doctor visits", one `body-sm` intro line. Caps "LATEST" + the
  newest visit as a full-width card (icon well 44 on `brand-tint`, specialty in `headline`, "Dr X · Today" in
  `caption`, the reason in `body-sm` on two lines, chevron). Caps "EARLIER · N" + a two-column grid of 172 vp cards
  (well 40, date top right, specialty, reason, then the pills) ending in a dashed "New visit" tile. Pills: the
  **avoid count** (Known-risk shape 16 + "6 to avoid" on the Known tint, height 24) and a quiet "Shared" word. Tap
  opens the visit, long press offers Delete (asks first). Empty: dashed card with the well, `title-3`
  "Prepare your first visit" and one line. Pinned: coral `New visit`.
- **New visit** (`pages/NewVisitPage.ets`): caps "WHO ARE YOU SEEING?" + a two-column grid of specialty tiles (height
  64, well 36, name 15 fp / 700; selected = 1.5 vp `ink` border). Caps "WHY ARE YOU GOING?" + a 96 vp text area
  (`surface`, 1.5 vp `border-strong`) and starter chips on `surface-alt` that add plain words to it. Then the
  **guess card** on `surface-alt`, radius 20: caps "LOOKS LIKE", one row per purpose (title 15 fp / 700, what is
  likely in `caption`; "From your words" in `brand-text` when the reason named it, otherwise "Usual for this
  doctor"), a Known-tint strip with the shape and "N known-risk medicines will be flagged for the doctor", and a
  caption that says the match is fixed rules on this phone. It updates while typing. Then caps "WHEN" + a 56 vp
  `surface` row (1 vp `border`, `radius_m`): the date in `headline` ("Today" by default) and "Change date" in
  `brand-text`, which opens the system date picker (one year back, two ahead). Caps "WHAT WORRIES YOU? (OPTIONAL)"
  + a 72 vp text area like the reason's. Optional doctor's name last. Pinned: coral `Create visit page`. The cards
  and the visit header show the visit date, not the day it was created.
- **Visit page** (`pages/DoctorVisitPage.ets`), the page handed to the doctor. **Share is in the header**, not
  pinned at the bottom: back, specialty in `headline` over "Dr X · date" in `caption`, then a coral `Share` pill
  (height 44, share icon). This is the one exception to the pinned-action rule: the screen is read top-down by
  someone else, so the action stays out of the content. Top to bottom:
  1. **At a glance** card: well 44, patient name in `title-3` / 800, "Long QT syndrome · LQT2 · ICD: no" in
     `brand-text`; divider; caps "HERE FOR" + the reason in `body` / 500 + the purposes as quiet pills (height 28,
     `surface-alt`); when given, caps "WHAT WORRIES ME" + the words in `body`; divider; caps "TAKES NOW" + up to four medicines, each with its compact risk badge; profile
     notes in a `surface-alt` well.
  2. **Don't prescribe** card: the verdict-card container (radius 20, 1.5 vp `risk_known_border`). Header band on
     the Known tint: octagon 32, "Please don't prescribe" 16 fp / 800, "On the known-risk QT list". Body: one caps
     label per purpose and the known-risk medicines as name chips (height 30, `surface-alt`, 14 fp / 700). Divider,
     then a fold-open row "Check first · N" with the Possible shape (possible and conditional risk; open = one row
     per medicine with its compact badge). Divider, then "Not on the QT lists" with the Not-listed shape, the names
     per purpose, and always the caption "Not listed doesn't guarantee safety. The choice is the doctor's."
  3. **AI summary** on `surface-alt` under the mono caps "AI SUMMARY · CHECK BEFORE SHARING", fetched once and kept
     with the visit; typing dots while it loads, a quiet retry button when it fails.
  4. Caps "IN DEPTH": the rest of the brief as folded rows (`surface`, 1 vp `border`, radius 16, min height 52: title
     15 fp / 700, a count pill, chevron down / up). Open shows the lines in `body-sm`.
  5. Secondary `Copy link` + `Copy text`, the coral text link "Share as text", the 48 h caption, the disclaimer, and
     an underlined quiet "Delete visit".

Rules kept from the earlier direction: one conversation in the app (`Routes.AGENT_CHAT` is the stage; "Ask the
agent" from any screen opens it with the question); every control has an `accessibilityText`; verdict colours come
from deterministic payloads only.

### 10.2 Screens without a drawing (derived)

- **Heart**: `title-1`, ring hero shared with Home, stats row (resting HR, HRV, rhythm) as three quiet cells, recent
  alerts as rows with an out-of-range HR chip, links to Symptom log and Doctor report, then "Demo controls" collapsed.
  The chart is a trend line in `brand` on `surface`, with dashed `border_strong` guides at 60 and 120. Never ECG-like.
- **Trends** (pushed from Heart and from the agent's tile): range chips (14 / 30 days, selected = ink) with the
  `SIMULATED` badge on the right when the data is demo data. One card: "Resting heart rate" (`headline`), a daily
  trend line in `brand` with a dot per day, three dashed `border_strong` guides, min/max labels in `micro`, first and
  last date under the plot. Two rows aligned to the same days: dose logged (8 vp square, filled `ink-2` = yes,
  outlined = no) and symptom reported (8 vp `ink` dot). Marks are ink, never risk colours, and each row has a text
  label. Caption "This is not an ECG". Then four stat tiles (average resting, last 7 days vs before, days with a
  dose, days with a symptom) and "What stands out": fixed-rule findings as neutral cards with a `NOTE` / `IMPORTANT`
  word. Findings report numbers; the good / okay / worth-a-look status lives in the metric status box (6.10).
- **Emergency (calm)**: `title-1`, the Medical alert card (as the widget), a danger "Call 112" button, then rows for
  Bystander guide, Pharmacy card, Offline QR and Test SOS. The full emergency card stays always light (`card_fixed_*`).
  Above the full card: a **card language** row (horizontal chips, height 44, pill, `surface` + 1 vp `border`; selected
  = `ink` fill + `on_accent` text; each chip shows the language in its own name, e.g. "Polski") and a secondary
  **Read aloud** button (wave icon; `Stop` while speaking). The choice is saved as the card language. Read aloud speaks
  only the medical part (title, condition, genotype, ICD, avoid, treatment, medicines), never name or contacts; it
  is hidden when no voice is available. **Nearby help** row: three 44 vp quiet buttons "Hospital", "Pharmacy",
  "Defibrillator (AED)" that open a map search around the phone. "Remove this link" asks first (dialog, danger).
- **Emergency (active / SOS)**: `bg` surface, `EMERGENCY` label, "Are you OK?" (`title-1`), a 200 vp ring in
  `risk_known` draining linearly, big seconds number, white secondary `I'm OK` (52) and danger `Send now`.
- **Onboarding**: 8 steps - see 11 "Onboarding (S3, B3)" (progress segments in `brand`, orb 96 on step 1,
  `title-1` per step, primary `Continue`).
- **Doctor report**: specialty chips (6.3), sections as `surface` cards with bullets, primary `Share`, secondary `Copy`.
- **Medicines empty**: dashed empty card "No medicines yet. Add one or scan a box." + primary `Add a medicine`.
- **I took it** (`components/IntakeCard.ets`; Check result under the verdict card, and the medicine detail sheet above
  its actions; only for Known / Possible / Conditional risk or a risky combination): a `surface` card: "Already took it?" in `headline`, one `body-sm` line in `ink-3` that says the watch
  will watch more closely and that this doesn't mean it's safe, and an ink `I took it` (pill icon). Tapping asks
  first (system dialog: "Log X as taken now?", Cancel / Log it). After logging: check icon + "Logged as taken at
  HH:MM" in `body` medium and "Your watch is watching more closely until …" in `ink-3`; if the watch couldn't be
  reached, the 6.7 error strip with `Send to watch`. Never a risk colour on this card: logging is not a verdict.
- **Settings** (pushed from the round settings button): the 6.11 list, in this order. Profile card. SAFETY:
  Emergency contacts (`ic_phone`, "2 people · watch alerts on" / "No one yet"), Emergency details (`ic_id_card`,
  "What a paramedic sees"), Emergency number (`ic_location`, "Germany · 112", opens the choice sheet), Test SOS
  (`ic_bell`, "Practise the SOS flow - marked as TEST"). DEVICES: Watch (`ic_watch`, paired / not paired line).
  ACCOUNT AND PRIVACY: Account (`ic_user`, email / "Not signed in"), Privacy and app lock (`ic_lock`, "App lock on"
  / "App lock off"). Then a lone danger group with "Clear all data on this phone" (confirm dialog), and the footer.
- **Your profile** (Settings → profile card): the onboarding "About you" fields without the step heading (name,
  date of birth, genotype chips + help, ICD switch + model). Saved on change (debounced 400 ms, flushed on leave),
  caption "Saved on this phone". No Save button.
- **Emergency contacts** (Settings → Emergency contacts): intro in `body-sm` `ink_2`. One 6.11 group of contacts:
  avatar circle 36 (`surface_alt`, initial in `ink_2`), name (+ relation) in `body` / 500, phone · email in
  `caption` `ink_3`, a 48 vp delete target (`ic_delete` 20, `ink_4`) that asks first. Empty: the 6.7 dashed card.
  Then SOS ALERTS FROM YOUR WATCH: the consent card (moved here from Account; signed out = one `body-sm` line and a
  secondary `Log in`). Pinned primary `Add a contact` opens a sheet (name, phone, relation, e-mail optional; primary
  `Add`, inactive until name and a valid phone).
- **Pair watch** (Settings → Watch): when paired, a `surface` card with a check icon, "Paired with watch
  {first 8 chars of the id}" (`body` bold), "Since …" in `ink-3` and a secondary `Unpair`. Below it, always, the code
  card: one `body` intro line, two `body-sm` steps in `ink-3`, a 56 vp `surface-alt` input centred in `title-2`, the
  error strip from 6.7 when a code fails (neutral offline strip when there is no backend), and a primary `Pair`
  that stays inactive until 6 digits are typed. Pairing again replaces the old pairing.
- **Reminders** (pushed page): summary card (bell well 48 on `brand-tint`, "2 of 4 taken today" in `title-3`,
  "Next: X at 20:00", a segmented bar with one 6 vp segment per dose: `brand` taken, `risk_possible` missed,
  `border` open). Then the TODAY timeline: time column 48 (`headline`, tabular figures), a 2 vp `border` rail with
  the status dot (6.9), and a card per dose (risk shape 16 + name, status word, "what it's for", first tip, `Taken`
  pill). Long press deletes. Empty: dashed card with a bell. NEW REMINDER card: horizontal medicine chips (148 wide,
  `surface-alt`, selected = `surface` + 1.5 vp `ink`; risk shape + name + class), time chips Morning 08:00 · Midday
  13:00 · Evening 20:00 · Night 22:00 · Other (selected = `ink` fill; Other reveals the time picker), primary
  "Remind me daily at HH:MM", and the gentle-alarm caption.
- **Chats** (pushed page): back + `title-1` "Chats", primary `New chat` (plus icon), then one row per saved chat on
  `surface` with a 1 vp `border`, `radius_m`, 14 padding: title in `headline` (one line, ellipsis; "New chat" when
  untitled), caption in `ink_3` "{N} messages · {Today 14:05 | 2 Oct}". The open chat shows an `Open now` caption in
  `brand_text`. Tap opens the chat; long press opens a menu with `Rename` and `Delete` (Delete in `danger`). Empty
  state: dashed card "No chats yet. Ask the agent something to start one." Chats are on this phone only, said once in
  a caption under the list.
- **Scan → box we don't know yet** (online lookup, on the scan sheet, `bg`, radius 28, 20 padding):
  - **Looking up**: `LoadingProgress` 32 in `brand_accent` + `headline` "Looking this box up…" + caption in `ink_3` with
    the barcode and country. After the quick lookup misses: "Searching pharmacies on the web…" + caption "This can
    take up to 20 seconds." A `Type the name instead` secondary button stays visible the whole time.
  - **Found**: `title-3` "Is this your box?", brand in `headline`, ingredients in `body` `ink`, strength · form in
    `ink_3`, then the source line (11 fp, `ink_4`, e.g. "FDA drug label (openFDA)"). A web-search find adds the
    outlined `SourceBadge` `AI · WEB` next to the title and the caption "Found by a web search. Check the name
    matches your box." Ingredients we could not confirm are listed in `ink_3` ("Not confirmed: …"); the verdict
    then says Unknown for them. Actions: ink `Yes, check it` (flex 1) + secondary `Not my box` (opens the teach
    form). Never a risk colour on this sheet: identification is not a verdict.
  - **Not found / offline**: straight to the teach form (unchanged).

### 10.2a Shared web pages (opened from a link on any device)

Static pages in `site/` (Vercel). Same tokens as the app, written as CSS custom properties in
`site/assets/celia.css`; system font stack (HarmonyOS Sans, then the platform UI font), no web fonts so nothing is
fetched from a third party. Data comes end-to-end encrypted from the Supabase `share` function and is decrypted in
the browser; the page itself never sees anything until the key in the link's `#` opens it.

- **Web card** (read by a stranger or paramedic, often outdoors, under stress): always light (`card_fixed_*`).
  Max width 520. Top: the card itself, same layout as the app's Medical alert card: `card_fixed_alert` header band
  with the heart mark and "MEDICAL ALERT" (`label`, +0.08em) and the patient name (`title-1`), then condition
  (`title-3`, alert colour), genotype + ICD chips, the "Do NOT give QT-prolonging drugs" panel (`card_fixed_alert_tint`,
  6 vp alert rule on the left), treatment (`body`), medicines and notes. Below the card: a 64 vp `danger` call
  button "Call 112 · {country}" and, when different, a secondary outlined "Ambulance {number}" button; contacts as
  outlined tap-to-call rows. Language picker top right (13 languages). States: loading (skeleton bars in
  `surface_alt`), link removed ("This card link was replaced or removed" + the 112 button), cannot open
  (corrupt/foreign link) with the same 112 button. Footer caption: "Encrypted on the owner's phone. Only people with
  this link can read it."
- **Web report** (read by a doctor on a phone or desktop, printable): `bg` page, content column 760 max, light and
  dark (`prefers-color-scheme`). Header: "Long QT safety report" `label` in `brand_text`, patient name `title-1`,
  facts line (condition · genotype · ICD), "Prepared for {specialist} · {date}" and an expiry pill
  ("Link expires in 47 h"). Summary strip: four `surface` tiles with big numbers (`title-1`, tabular figures):
  medicines with QT risk, interactions, heart alerts (90 d), symptoms logged. Sections as `surface` cards with
  `border` and `radius_l`: Current medicines (each row with the risk badge: colour + shape + word, never colour
  alone), Interactions, Flagged checks (dated rows), Resting heart rate (SVG line in `brand` over 30 days, dashed
  `border_strong` guides at 60 and 120, the median as a caption, `SIMULATED` mono badge when any day is
  simulated, and "Heart rate only - this is not an ECG"), Heart alerts & SOS and Symptoms as a dated timeline,
  Dose adherence (taken / skipped of scheduled, last 14 days), For the {specialist} (watch-outs), Questions.
  Footer: "Prepared with Celia from the patient's own records. Not a medical device." Print: white background, no
  shadows, cards become bordered blocks, URL and expiry printed in the footer, sections avoid page breaks.
- **Motion (both pages)**: content groups fade and rise 8 px once on load, 220 ms `cubic-bezier(0.23, 1, 0.32, 1)`,
  40 ms stagger, at most 5 groups; buttons scale 0.97 on press (120 ms ease-out). Nothing loops. With
  `prefers-reduced-motion`, opacity only.

### 10.3 Still open

- Persona name for the agent (UI says "the agent").
- Dark-mode screens are derived from 2.2 and not drawn.

### 10.4 Extra resource names

`radius_btn` 14, `button_height_sheet` 52, `chip_height` 44, `font_button` 15, `font_badge` 13, `font_mono` 9,
`avatar_*` (incl. `avatar_tab` 56, `avatar_hero` 168), `dock_side` 60, `dock_main` 80, `risk_<level>_border`, `danger`, `scrim`,
`shadow_sheet`, `bg_clear`, `orb_light/mid/dark`, `orb_sheen`, `orb_sheen_clear`, `orb_glow`, `orb_glow_clear`,
`orb_glow_user`, `orb_glow_user_clear`, and `card_fixed_*`
(always-light emergency card, the same in dark mode).

## 11. Workstream B screens

Specs written by the Workstream B streams (`docs/workflow/b-*.md`) for the screens they added. Same tokens and
components as above; no new colours or sizes.

### Doctor visits and feeling diary (S5, B6/B15)

- **Doctor visits** (pushed page, route `visits`; also "My visits" `NavRow` at the top of Doctor report): intro in
  `body` `ink_3`, primary `Add a visit` (plus icon), then `UPCOMING` / `PAST` caps headers and one card per visit
  (`surface`, 1 vp `border`, `radius_m`, 14 padding): specialty in `headline`, date in `body-sm` (`brand_text` when
  upcoming, `ink_3` when past), reason in `ink_2` (2 lines), "AI summary saved" caption, a 48 vp bin button in
  `ink_3` (asks first; Delete in `danger`). Empty: dashed card with `Add a visit`.
  Add form (same page): `title-3` "New visit", specialty chips (6.3, selected = ink), a 48 vp date row (date in
  `headline`, "Change date" in `brand_text`, opens the system date picker), reason input and worries area on
  `surface_alt`, privacy caption in `ink_3`, primary `Save and build the brief`, quiet `Cancel`.
- **Doctor report on a visit**: title "{Specialty} · {date}", no specialty chips, the visit sections first; the AI
  block caption says the summary is saved with the visit.
- **How are you feeling?** (route `feeling`): intro, five mood chips (44 vp, pill, ink when selected - moods are
  not verdicts, never risk colours), a neutral `surface` card offering `Log a symptom` for Low / Unwell, note
  area on `surface_alt`, primary `Save to diary` (inactive until a mood is picked), `RECENT` rows like the symptom log.
- **Feeling widget (2×2)**: `surface` card, `CELIA` caption in `ink_3`, "How are you feeling?" in `headline`, ink
  pill "Add entry" with plus icon.

### SOS sent state (S4, B8)

**SOS sent state** (extends 10.2 "Emergency (active / SOS)"): after the countdown (or straight away for a watch SOS)
the page shows the title (`title-1`; "Your watch sent an SOS" when the watch sent it, else "Get help now"), the
subtitle in `ink_3`, then a **status card**: `surface`, 1 vp `border`, `radius_m`, padding `space_m`, three rows
separated by `divider` - caps label (`font_caption`, bold, `ink_3`: WHAT WAS SENT · TO WHOM · STILL NEEDS A TAP) over
`font_small` `ink_2` text. Never a risk colour on the card: it is a report, not a verdict. Below it: danger "Call
ambulance", secondary "Send SOS message", one secondary "Call {name}" per contact, secondary **For first
responders** (doctor icon), the location line and the message preview.

### Accounts (S1, B1/B2)

- **Welcome** (first launch, signed out, nothing on the phone): `bg`, orb 96, "Celia" in `title-1`, tagline in
  `body` `ink_2`, a `surface` card (1 vp `border`, `radius_l`, padding 16) with three rows (icon well 36 on
  `surface_alt` + `font_small` text): medicine check offline, watch heart rate, emergency card offline. Bottom:
  primary `Create an account`, secondary `I already have an account`, quiet `Set up without an account` with a caption
  that the profile then stays on the phone, then the disclaimer caption in `ink_4`. Back does nothing.
- **Sign up / Log in**: title in `title-1`, one `font_small` `ink_3` line on what the account is for, then the form:
  labelled 48 vp inputs on `surface_alt` (`radius_m`), primary button (inactive until both fields have text), a
  `brand_text` link to switch mode, disclaimer caption. Errors use the amber 6.7 strip in plain words, never red;
  "check your email" uses the neutral strip. While working: `LoadingProgress` 28 in `brand_accent` + "One moment…".
- **Account** (Settings → Account): signed in - `surface` card with "Signed in as" caption, email in `headline`, the
  backup line (`font_small`; offline → neutral strip, failure → amber strip), secondary `Back up now`; secondary
  `Sign out` (dialog: keep data / delete from this phone, the latter in `risk_known` text); "WHERE YOUR DATA IS" card;
  a centred `risk_known` text action "Delete my data from my account" with a confirm dialog. Signed out - one body
  line, primary `Log in`, secondary `Create an account`, the same data card.

### Emergency details and first-responder view (S2, B4/B5)

#### Emergency details (Settings → Emergency details)
`bg` page, intro in `body-sm` `ink_2`. One `surface` group per field (1 vp `border`, `radius_m`, padding 16): caps
label in `label` `ink_3` with a "Show on card" switch (`brand_accent`) on the right; inputs 48 vp on `surface_alt`,
`radius_s`; single-choice chips 44 vp pill (selected = `ink` fill). Invalid date: one `risk_possible_text` caption
(no red). Extra fields as label/value rows with a 48 vp delete target. Saved on change; caption "Saved on this phone".

#### For first responders (route `responder`): the full emergency card (v3)
One card, read in layers, so a stranger gets the point in 10 seconds and a clinician finds detail below. Always light
(`card_fixed_*`), no title bar. Everything is fixed data (`emergency/LqtsFacts.ets`, `emergency/Responder.ets`, the
QT dataset); no LLM text. Treatment lines name drugs only, never doses. Plain design-system shapes only: cards with a
1 vp border, caps labels, the risk shape + word. No coloured header bands and no side rules.
Parts live in `components/EmergencyCardParts.ets`.

1. **Glance.** Back chevron + caps "MEDICAL ALERT" in `card_fixed_alert`. Identity row: 48 vp initial avatar
   (`card_fixed_alert_tint` circle, initial in `title-3` 800 `card_fixed_alert`; heart icon without a name), name in
   `title-2` 800, condition in `body-sm` `card_fixed_ink_2`. Chips (age, genotype, ICD): height 28, 1 vp
   `card_fixed_border`, radius 14. A 56 vp `danger` "Call {112}" button. Then **Do not give** as the Known-risk
   notice: `card_fixed_alert_tint`, 1 vp `card_fixed_alert_border` (`#F4B5AF`), radius 16, Known-risk shape +
   heading; the first 4 drug groups (antiemetics, stimulants, macrolides, fluoroquinolones), "Show all N drug
   groups" for the rest.
2. **Critical.** Caps-labelled sections: emergency contacts (cardiologist first) as 52 vp outlined call rows;
   medicines with the compact risk badge and, when one is Known risk or avoid-in-congenital, a notice line "Takes a
   QT-prolonging medicine" (same notice style); the "Recent QT-risk medicine" box when inside 72 h; details.
3. **For clinicians.** One `card_fixed_bg` card, 1 vp `card_fixed_border`, radius 20, padding 16. Caps "IF
   UNRESPONSIVE OR COLLAPSED" in alert colour; numbered steps (24 vp ink circles, step in `body` bold, detail in
   `body-sm` `card_fixed_ink_2`); then, split by dividers, caps sections Torsades de pointes (A, B, C in `ink_3`),
   Do not use (✕ in alert colour) and Notes for {type}. "Use instead" groups follow under their caps label.
4. **About long QT.** A plain card folded by default (48 vp header row, chevron). Inside: overview paragraphs, then
   "This person's type": name in `headline`, gene and share in `body-sm` `ink_3`, Triggers (bullets), ECG pattern,
   Treatment. Unknown genotype shows "General precautions".

Footer: source and "works offline" in `micro`. Card text follows the card language for the glance layer (13
languages); layers 3 and 4 stay English until a checked translation exists.

#### Emergency tab card
The unfolded card on the Emergency tab is the glance layer of the same design: a `card_fixed_bg` card, 1.5 vp
`card_fixed_alert_border`, radius 20. Heart icon + caps title in alert colour, the identity row and chips, the
translated "Do NOT give" sentence in the Known-risk notice (shape + sentence, no separate heading, so it stays in
the card language), treatment line, medicines with the compact risk badge, contacts and notes, then "Open the full
card ›" to `responder`.

### Onboarding (S3, B3)

Replaces the "Onboarding" line in 10.2.

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
