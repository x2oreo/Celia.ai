---
name: lqts-domain
description: Medical domain knowledge for the Long QT syndrome (LQTS) app - what LQTS is, genotypes LQT1/2/3 and their triggers, QT drug-risk taxonomy (CredibleMeds Known/Possible/Conditional + "avoid in congenital LQTS"), starter drug reference to build the dataset from, electrolyte and illness triggers, emergency facts for the emergency card and SOS flow, watch-signal heuristics, data sources + licences, and the safety design rules (deterministic verdicts, LLM explains only). Use when implementing any LQTS feature (medicine check, agent tools/prompts, emergency card, vitals rules, doctor report, onboarding) or writing medical copy.
---

# LQTS domain knowledge

Build everything here **from scratch during the hackathon**. Don't paste code, data files or prompts from any other
project. Challenge Rules §4 say any material pre-existing component must be listed in the submission docs, and
false or misleading info gets a team disqualified. So if something pre-existing ever goes in, it gets disclosed.

**Not a medical device.** Decision support only. Every verdict screen and agent answer ends with "ask your doctor or
pharmacist". Medical facts below are standard textbook or guideline knowledge. **Verify drug categories at
crediblemeds.org before they ship in the dataset**, since categories change.

## The condition

- Inherited ion-channel disorder. Ventricular repolarisation is delayed, so the QT interval on the ECG is long
  (QTc roughly ≥ 470 ms in men and ≥ 480 ms in women is suspicious; ≥ 500 ms is high risk).
- Risk: **torsades de pointes (TdP)**, a polymorphic VT. It causes syncope, seizure-like episodes, or ventricular
  fibrillation and sudden cardiac death. Often hits children and young adults. Prevalence is about **1 in 2,000**.
- Treatment: beta-blockers (nadolol, propranolol), avoiding triggers and QT-prolonging drugs, keeping K⁺ and Mg²⁺
  normal, an ICD for high-risk patients, sometimes left cardiac sympathetic denervation. LQT3 sometimes gets mexiletine.
- Acquired LQTS is the same arrhythmia, caused by drugs or electrolytes in people without the gene. Drug checks help
  them too (secondary audience).

## Genotypes (≈ 90% of genotyped cases)

| Type | Gene / channel | Typical trigger | App behaviour |
|---|---|---|---|
| LQT1 (~35-40%) | KCNQ1 / IKs | Exercise, especially **swimming**, adrenaline | Warn on exertion and high HR; swim safety tip; beta-blocker adherence matters most |
| LQT2 (~30-35%) | KCNH2 (hERG) / IKr | **Sudden loud noise** (alarm clock, phone ring), emotional stress, postpartum period | Tip: gentle alarm and no loud ringtone at night; stress context |
| LQT3 (~5-10%) | SCN5A / INa | **Rest and sleep**, bradycardia | Night-time and low-HR rules |
| Unknown / other | - | Treat with general rules | Default to the most conservative advice |

Onboarding options: LQT1 / LQT2 / LQT3 / Other / Unknown.

## Drug-risk taxonomy (CredibleMeds QTdrugs lists)

| Category | Meaning | App verdict |
|---|---|---|
| **Known Risk of TdP (KR)** | Prolongs QT and is clearly associated with TdP, even at recommended doses | 🔴 AVOID: talk to your doctor before taking |
| **Possible Risk (PR)** | Can prolong QT, but evidence for TdP is lacking at normal doses | 🟠 CAUTION |
| **Conditional Risk (CR)** | TdP risk only under conditions: overdose, low K/Mg, interacting drugs, bradycardia, or the drug causes those conditions | 🟡 CAUTION with conditions listed |
| **Avoid in congenital LQTS** (special list) | Includes non-QT drugs, e.g. **stimulants and sympathomimetics** (adrenaline, ADHD stimulants, pseudoephedrine, salbutamol) | 🔴/🟠 flag for congenital patients only |
| Not listed | No QT signal in the list | 🟢 "Not on QT-risk lists" (not "safe": always add the doctor note) |

Combination risk: two or more QT drugs, or a QT drug plus a **CYP inhibitor** that raises its level (e.g.
clarithromycin, ketoconazole or itraconazole, grapefruit for CYP3A4), plus diuretics and low K/Mg. The combo rule
is deterministic: count the flagged drugs, check a small CYP-inhibitor table, then escalate one level.

## Starter drug reference (verify each entry, then build `rawfile/qt_drugs.json`)

Store generic name (INN), common EU/PL brand names as search terms, category, `avoidInCongenital` flag, drug class
and plain-language use. Demo-critical drugs are in **bold**.

- **Known Risk:** **clarithromycin**, **ciprofloxacin**, levofloxacin, **moxifloxacin**, azithromycin,
  erythromycin, **ondansetron**, domperidone, droperidol, haloperidol, chlorpromazine, citalopram, **escitalopram**,
  methadone, amiodarone, sotalol, dronedarone, flecainide, quinidine, procainamide, disopyramide, dofetilide,
  ibutilide, hydroxychloroquine, chloroquine, fluconazole, pentamidine, donepezil, propofol, sevoflurane, cilostazol,
  pimozide, thioridazine, arsenic trioxide.
- **Possible Risk (verify):** venlafaxine, mirtazapine, lithium, tacrolimus, granisetron, tizanidine.
- **Conditional Risk (verify):** fluoxetine, sertraline, paroxetine, trazodone, amitriptyline, quetiapine,
  olanzapine, risperidone, metoclopramide, loperamide, diphenhydramine, hydroxyzine, famotidine, omeprazole and
  pantoprazole (via low Mg), furosemide and hydrochlorothiazide (via low K), metronidazole, ketoconazole, solifenacin.
- **Avoid in congenital LQTS (verify):** pseudoephedrine, phenylephrine, adrenaline, methylphenidate,
  amphetamines, salbutamol/albuterol, caffeine-heavy energy drinks (lifestyle tip).
- **Not listed (good demo "green"):** amoxicillin, paracetamol, ibuprofen (still give the generic doctor note).

Brand examples for OCR and the Polish market (verify): Klacid (clarithromycin), Cipronex/Ciprobay (ciprofloxacin),
Avelox (moxifloxacin), Sumamed/Azitrox (azithromycin), Zofran (ondansetron), Motilium (domperidone), Cipramil
(citalopram), Lexapro/Cipralex (escitalopram), Augmentin (amoxicillin + clavulanate), Apap/Panadol (paracetamol),
Ibuprom/Nurofen (ibuprofen), Sudafed (pseudoephedrine).

## Non-drug triggers (rules + agent advice)

- **Vomiting or diarrhoea, fever, eating disorders, diuretics** lower K⁺/Mg²⁺ and raise risk. This is sick-day
  mode: hydrate with electrolytes, avoid QT-risk antiemetics (ondansetron, domperidone), contact a doctor.
- **Fever** prolongs QT in some patients (and is the main trigger in Brugada, which can be a future "condition pack").
- Genotype triggers from the table above. Missed beta-blocker doses are a major risk, so adherence reminders matter.

## Emergency facts (emergency card + SOS + agent)

- Red flags: **fainting, especially during exercise, startle or sleep; seizure-like episode; palpitations with
  dizziness**. The agent must not diagnose. It says "This could be serious: call 112 now" and offers SOS.
- Bystander: unresponsive and not breathing normally → call **112** (EU-wide; 999 UK, 911 US), start CPR, use an AED
  as soon as possible.
- Card text for clinicians: "Congenital Long QT syndrome (type X). Avoid QT-prolonging drugs (crediblemeds.org).
  TdP is treated with IV magnesium sulfate; unstable patients are defibrillated. Keep K⁺ and Mg²⁺ high-normal. Avoid
  QT-prolonging antiemetics (ondansetron, droperidol, domperidone) and catecholamines unless life-saving.
  Beta-blocker: <drug/dose>. ICD: yes/no." Plus ICE contacts and cardiologist.
- Card languages: EN plus PL first (local ER), then DE/FR/ES/IT. Use resource-based translations, not runtime LLM
  output, for the safety text.

## Watch and vitals heuristics (configurable, labelled as non-clinical)

Wearables can't measure QT. Third-party apps generally get **heart rate and motion, not raw ECG or HRV**. See
`docs/hackathon/conditions-research.md` §3. The rules engine is a set of **demo heuristics**:

- High HR at rest (e.g. > 120 bpm with low motion for > N s) → check-in.
- Sudden HR spike during sleep or after a sudden-noise context (LQT2 story) → check-in.
- Low HR at night (e.g. < 40 bpm, LQT3 story) → check-in.
- Fall or sudden stillness after a spike (accelerometer), or no answer to a check-in within 60 s → emergency mode countdown.
- Emulator: a **simulated vitals source** behind the same interface, with named scenarios ("LQT2 alarm-clock
  spike"), always labelled "Simulated" in the UI.

## Data sources and licences

| Source | Use | Terms |
|---|---|---|
| CredibleMeds QTdrugs (crediblemeds.org) | Drug categories | Free registration. API and redistribution need a licence → hand-curate a small subset, **cite CredibleMeds** in-app and in README |
| RxNorm (NLM) | Name normalisation | Free public API |
| openFDA | Adverse-event signals | Free public API |
| EMA / national registries (URPL for Poland) | EU brand ↔ INN | Public product information |
| ERC / ESC guidelines | Emergency text | Cite in docs |

## Safety design (also scored as "technical execution")

1. **Verdict = deterministic lookup** (category plus combo rule). The LLM never decides a verdict. It explains,
   picks tools and drafts doctor questions.
2. The LLM gets verified facts in the prompt. Temperature 0. The output is parsed into typed ArkTS interfaces and
   validated. On invalid output, timeout or unknown drug, show the deterministic result plus "not enough information,
   ask a pharmacist", and log the failure.
3. Every result carries `source` (LOCAL_LIST / RXNORM / AI_ASSESSED) and confidence. Show this in the UI so
   AI-only guesses are visibly marked.
4. OCR flow: on-device text → match against names and brands (exact, then fuzzy) → ask the user to confirm the
   matched drug before showing a verdict.
5. Privacy: profile, meds and vitals stay on-device. Off-device calls send only a drug name or de-identified
   context.
6. Tests: lookup (brand → INN), every category → verdict, combo escalation, validator rejects malformed LLM JSON,
   vitals rules on scenario data.
