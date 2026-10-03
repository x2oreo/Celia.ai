# Celia.ai Design System (v0.1)

> **Calm, warm, trustworthy.**

Heart-safety companion for people with Long QT syndrome (LQTS). Targets:

- **Phone**: HarmonyOS, 360 × 780 vp
- **Watch**: round AMOLED, 466 × 466 px

Everything is built natively in ArkUI, so we use only stacks, lists, cards, tabs and sheets. No blur stacks, shaders
or web-only effects. Visual source of truth is the design file *Celia Directions*, exported as the three screenshots in
`docs/design/` (B1–B6 phone + widgets, W1–W7 watch). That is the **locked direction** (see [Locked layout](#10-locked-layout-and-screen-specs)).

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
| **Heart rate only** | Never imply the app measures or diagnoses QT. The watch shows heart rate and nothing more. |

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

| Token | Hex | Use |
|---|---|---|
| `black` | `#000000` | Screen background |
| `ring-track` | `#161616` | Empty bezel ring |
| `button` | `#2A2A2A` | Secondary pill |
| `calm` | `#12B76A` | Ring, "All good" |
| `elevated` | `#FDB022` | Ring, low/high HR text |
| `alert` | `#F04438` | SOS ring, danger text |

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
| pill | Chips, input bar (use `height / 2`) | — |

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

### 6.5 Tab bar

Four tabs: **Agent · Medicines · Heart · Emergency**.

- Bar: `surface`, 1 vp top border, padding 8 × 6.
- Labels 11 fp. Inactive: 600, `#7A716B`. Active: 700, `brand-text` + filled icon.
- Agent tab icon is the small agent avatar (24 vp).
- **Emergency** is always tinted: a `brand-tint` pill (height 24, radius 12) reading `SOS` (10 fp / 800, +0.06em),
  label in `#B42318`. Findable but calm.

### 6.6 Agent avatar

- Name: "the agent" (persona name not final).
- **Orb (locked)**: radial gradient `#FFC2BE` → `#E5484D` (68%) → `#C7353A`, highlight at 35% / 30%.
- Sizes: **28 / 40 / 96** vp.
- Idle: breathing ~4 s.
- A soft sheen (`orb_sheen` → `orb_sheen_clear`, a second radial gradient at 30% / 24%) sits on top of the body.
- Pulse-line avatar is rejected for now because it reads as an ECG.

### 6.6a Voice orb (hero of the conversation)

The orb is the agent's face while you talk. `components/VoiceOrb.ets`. Size **168** before anything is said
(`avatar_hero`), **84** once the conversation has content. Plain shapes and gradients only.

Layers, back to front:

1. **Halos**: two circles the size of the core, at 8% and 14% opacity, resting at scale 1.2 and 1.08. They swell
   with the loudness of whoever is talking (up to +0.42 and +0.2).
2. **Core**: the locked orb gradient, the sheen turning slowly (14 s), breathing as in 6.6. A soft coral glow
   underneath (`orb_glow`, radius 0.28 × size, offset 0.08 × size) is the one shadow allowed outside sheets.
3. **Orbit arc**: a 3 vp coral arc circling at 1.16 × size, 1.6 s per turn.

| State | Halo colour | Motion | Label under the orb |
|---|---|---|---|
| Off | coral, half strength | breathing only | "Tap to talk" (`title-3` when the screen is empty) |
| Connecting | coral | orbit arc | "Connecting…" |
| Listening (waiting for you) | `ink-4` | halos follow the room at half gain | "I'm listening" |
| Hearing (you are speaking) | `ink-4` | halos follow your voice | "Listening…" |
| Thinking | coral | orbit arc | "Thinking…" or the running tool step |
| Speaking | coral | halos and core follow the agent's voice | "Speaking" |
| Muted | — | core at 50% opacity, halos still | "Muted. Tap the mic to unmute." |

Neutral halos mean "your voice", coral means "the agent". The label always says the state in words, so it never
depends on colour or motion alone.

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

---

## 7. Watch

- **Ring motif.** A 12 px bezel ring is the zone signal: green = calm, amber = elevated, risk-red = alert,
  coral = agent. Pulse speed rises with state (1.1 s calm → 0.5 s alert). A countdown is the same ring draining.
- **Type.** BPM 80–96 px ExtraBold. Titles 20–30 px. Labels never below 12 px caps.
- **Layout.** One action per screen. Buttons are 52 px pills. Every alert has at least two (I'm OK / Need help).
- **Screens (7).** Home, HR high, HR low (gentle wake-up tone), How do you feel (Fine / Dizzy / Racing),
  SOS countdown ("Calling 112 in 10 s" + Cancel), Verdict glance, Not on wrist.
- The watch shows **heart rate only. Never QT.**

---

## 8. Motion

| Pattern | Spec |
|---|---|
| **Heartbeat pulse** | Live HR icon scales 1 → 1.25 → 1 → 1.15 → 1 over ~1.1 s (keyframes at 0 / 15 / 30 / 45 / 100%). Home ring pulses opacity in time. Stops when the source disconnects. |
| **Agent breathing** | Avatar scale 0.92 ↔ 1.04 (opacity 0.92 ↔ 1) over 4 s ease-in-out, infinite. |
| **Voice orb** | Halos and core follow the voice level with a 160 ms ease-out. Sheen turns once in 14 s, the thinking arc once in 1.6 s, both linear. The orb eases between 168 and 84 in 320 ms when the conversation starts. |
| **Live words** | The user's bubble sits at 60% opacity while the words are still being recognised (three dots before the first word), then becomes solid. The agent's text grows word by word. No cursor, no typewriter effect. |
| **Typing** | Three 7 vp dots, 1.2 s loop, staggered 150 ms. Pair with a label like "Reading the box…" when the wait is known. |
| **Verdict reveal** | Card slides up 12 vp and fades in over 240 ms. Badge settles 100 ms later. No bounce or shake, even for Known risk. |
| **Sheets** | Bottom sheets rise over 280 ms with a 45% scrim. SOS countdown ring drains linearly over 10 s. |

In ArkUI, use `animateTo` / `.animation()` with `Curve.EaseInOut` and `iterations: -1` for loops, and
`keyframeAnimateTo` for the heartbeat. Respect the system reduced-motion setting by dropping loops to static.

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

---

## 10. Locked layout and screen specs

### 10.1 Direction (locked)

- **Home** (B1) = the Agent tab: date, "Hi {name}", genotype chip, settings gear. Heart-rate ring (track `border`,
  arc `brand`, `display` bpm, "bpm · resting", source badge), status chips, then the **agent card** (orb 28, name,
  time, `body` message, `Scan a box` primary + `Ask something` quiet).
- **Conversation** (B2, revised: voice first) is a pushed page, not a tab. Header: back, "The agent", `ON-DEVICE`
  badge when there is no backend. It has two modes over the same thread.
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

### 10.2 Screens without a drawing (derived)

- **Heart**: `title-1`, ring hero shared with Home, stats row (resting HR, HRV, rhythm) as three quiet cells, recent
  alerts as rows with an out-of-range HR chip, links to Symptom log and Doctor report, then "Demo controls" collapsed.
  The chart is a trend line in `brand` on `surface`, with dashed `border_strong` guides at 60 and 120. Never ECG-like.
- **Emergency (calm)**: `title-1`, the Medical alert card (as the widget), a danger "Call 112" button, then rows for
  Bystander guide, Pharmacy card, Offline QR and Test SOS. The full emergency card stays always light (`card_fixed_*`).
- **Emergency (active / SOS)**: `bg` surface, `EMERGENCY` label, "Are you OK?" (`title-1`), a 200 vp ring in
  `risk_known` draining linearly, big seconds number, white secondary `I'm OK` (52) and danger `Send now`.
- **Onboarding**: progress segments in `brand`, orb 96 on step 1, `title-1` per step, primary `Continue`.
- **Doctor report**: specialty chips (6.3), sections as `surface` cards with bullets, primary `Share`, secondary `Copy`.
- **Medicines empty**: dashed empty card "No medicines yet. Add one or scan a box." + primary `Add a medicine`.

### 10.3 Still open

- Persona name for the agent (UI says "the agent").
- Dark-mode screens are derived from 2.2 and not drawn.

### 10.4 Extra resource names

`radius_btn` 14, `button_height_sheet` 52, `chip_height` 44, `font_button` 15, `font_badge` 13, `font_mono` 9,
`avatar_*` (incl. `avatar_hero` 168), `dock_side` 52, `dock_main` 72, `risk_<level>_border`, `danger`, `scrim`,
`shadow_sheet`, `orb_light/mid/dark`, `orb_sheen`, `orb_sheen_clear`, `orb_glow`, and `card_fixed_*`
(always-light emergency card, the same in dark mode).
