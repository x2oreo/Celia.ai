---
pdf_options:
  format: A4
  margin: 18mm 16mm
  printBackground: true
  displayHeaderFooter: true
  headerTemplate: '<div></div>'
  footerTemplate: '<div style="font-size:8px;width:100%;text-align:center;color:#888;">HackYeah 2026 · Huawei "Imagine What''s Next" · Condition research · <span class="pageNumber"></span>/<span class="totalPages"></span></div>'
stylesheet: []
css: |-
  body { font-family: -apple-system, "Helvetica Neue", Arial, sans-serif; font-size: 10.5pt; line-height: 1.45; color: #1d1d1f; }
  h1 { font-size: 22pt; color: #c7000b; border-bottom: 3px solid #c7000b; padding-bottom: 6px; margin-top: 0; }
  h2 { font-size: 15pt; color: #c7000b; border-bottom: 1px solid #e5e5e5; padding-bottom: 4px; margin-top: 26px; page-break-after: avoid; }
  h3 { font-size: 12.5pt; color: #1d1d1f; margin-top: 20px; page-break-after: avoid; }
  h4 { font-size: 10.5pt; color: #555; margin: 10px 0 4px; text-transform: uppercase; letter-spacing: .04em; page-break-after: avoid; }
  table { border-collapse: collapse; width: 100%; font-size: 9pt; margin: 8px 0 14px; page-break-inside: auto; }
  tr { page-break-inside: avoid; }
  th { background: #c7000b; color: #fff; text-align: left; padding: 5px 6px; }
  td { border-bottom: 1px solid #e5e5e5; padding: 4px 6px; vertical-align: top; }
  tr:nth-child(even) td { background: #fafafa; }
  blockquote { border-left: 4px solid #c7000b; background: #fff5f5; margin: 10px 0; padding: 8px 12px; color: #333; }
  code { background: #f2f2f2; padding: 1px 4px; border-radius: 3px; font-size: 9pt; }
  .pb { page-break-after: always; }
  ul { margin-top: 2px; }
  li { margin-bottom: 2px; }
---

# Beyond LQTS: Conditions for a HarmonyOS Health App

> Status (4 Oct 2026): historical research brief from the start of the hackathon, used to choose LQTS. Not a description of the built app.

**HackYeah 2026 · Huawei "Imagine What's Next" task · Research brief**<br>
Prepared 3 Oct 2026 · Target hardware: Huawei Watch GT 5 Pro + GT 6 Pro + HarmonyOS phone/tablet

> **One-line takeaway.** LQTS is a strong fit because the condition has **(1) a known list of dangerous triggers, mainly drugs, (2) a signal a wearable can watch, and (3) a sudden, preventable emergency.** This brief looks for other conditions with the same shape. The strongest are **Brugada syndrome, CPVT, adrenal insufficiency, myasthenia gravis and POTS**. The strongest *pitch* is to treat LQTS + Brugada + CPVT as one **"inherited arrhythmia" companion** sharing one engine.

*Not medical advice. Every number below is cited at the end. Any shipped product would be a medical device under EU MDR. For the hackathon, present it as decision support that always says "ask your doctor".*

## Contents

1. What makes LQTS a good fit (the pattern to copy)
2. Features you can reuse for any condition
3. What the GT 5 Pro / GT 6 Pro can actually provide to a third-party app
4. Tier A conditions (deep dives): Brugada, CPVT, adrenal insufficiency, myasthenia gravis, POTS, acute hepatic porphyria, epilepsy, ME/CFS & Long COVID
5. Tier B conditions (shorter): Parkinson's, heart failure, MS heat sensitivity, G6PD deficiency, malignant hyperthermia, others
6. Scoring matrix
7. Recommendations and demo scripts
8. Drug-list data sources and licensing
9. Sources

<div class="pb"></div>

## 1. What makes LQTS a good fit

**Long QT syndrome (LQTS)** is an inherited ion-channel disease. After each heartbeat, the heart takes too long to "recharge", which shows up as a long QT interval on an ECG. About **1 in 2,000** people have it. It can trigger *torsades de pointes*, a chaotic rhythm that causes fainting or sudden death. Triggers depend on the genetic type. LQT1 is triggered by exercise, especially swimming. LQT2 is triggered by sudden noise or emotion. LQT3 is triggered by sleep and rest. On top of that, **hundreds of common drugs lengthen the QT interval** (CredibleMeds list), and so do low potassium and low magnesium from vomiting or diarrhoea.

Why it works as a hackathon topic:

| Ingredient | LQTS example | Why judges like it |
|---|---|---|
| A known list of dangerous triggers | QT-prolonging drugs (CredibleMeds) | The AI "med check" is useful in an obvious way and easy to demo |
| A signal a wearable can watch | ECG/QT, heart rate | Shows the hardware working, which is what Huawei wants |
| A sudden, preventable emergency | Torsades → fainting or sudden death | Emotional stakes; clear "this saves lives" story |
| Rare and under-served | ~1:2,000; general health apps ignore it | Novel, and no big competitor |
| Clear user + clear clinician | Patient + electrophysiologist | Clean persona; "doctor report" feature |

**Use these five ingredients to filter the candidates.** Each section below rates the condition on them.

## 2. Features you can reuse for any condition

An AI medicine check is the core for LQTS. Treat each feature below as a reusable building block. A condition becomes a **"condition pack"** that configures the blocks: which drug list to use, which sensor rules to run, which emergency steps to show.

| # | Feature | What it does | HarmonyOS feature it shows off |
|---|---|---|---|
| F1 | **AI Med Check** | Photograph or scan a box or leaflet → OCR → active ingredient (INN) → check the condition's drug list → plain-language verdict + "ask your doctor" note | Core Vision Kit (OCR, on-device), Scan Kit (barcode), LLM only for the explanation |
| F2 | **Brand ↔ ingredient across countries** | A Polish brand maps to its ingredient, then to the equivalent in Germany or the UK. Solves "I'm abroad, what is this pill?" | Global-market story (Huawei is expanding to EU) |
| F3 | **Trigger radar (watch rules)** | Per-condition rules on heart rate, skin temperature, motion, SpO2, sleep → vibration + phone alert | Watch ↔ phone (Wear Engine), background tasks |
| F4 | **Sick-day / illness mode** | Fever, vomiting or diarrhoea detected or logged → condition-specific steps (antipyretic, electrolytes, double steroid dose, ER) | Live View / persistent notification |
| F5 | **Emergency card, multilingual** | Lock-screen / watch card: diagnosis, drugs to avoid, ICE contacts, a doctor's letter, auto-translated into the local language | Lock-screen widget, Form Kit, translation |
| F6 | **Pre-procedure briefing** | Before surgery or the dentist: a one-page "anaesthetics/drugs to avoid" sheet for the anaesthetist | Share Kit, PDF, cross-device to PC |
| F7 | **Caregiver / family link** | Parent's phone or tablet gets live alerts (child with CPVT or epilepsy) | Distributed data object, cross-device |
| F8 | **Doctor report** | Weekly PDF: episodes, triggers, med adherence, HR trends; opens on tablet/PC by "continuing" from the phone | App continuation (`onContinue`), adaptive layouts |
| F9 | **Voice assistant / agent** | "Celia, can I take ibuprofen?" → app intent answers using F1 | Intents Kit / HMAF agent (HarmonyOS 6) |
| F10 | **On-device symptom tests** | Camera or voice tests, e.g. eyelid droop (myasthenia), speech slurring, tremor | Core Vision face landmarks, Core Speech, MindSpore Lite |
| F11 | **Med adherence on wrist** | Watch reminder + "taken" tap; missed beta-blocker / steroid / antiepileptic → escalate | Watch app + reminders |

> **Design rule from medical-app practice:** the *verdict* (safe / avoid / caution) must come from a **deterministic list lookup**. The LLM only explains it and drafts the question for the doctor. Say this explicitly in the pitch. It shows judges you thought about hallucination.

<div class="pb"></div>

## 3. What the watches can give a third-party app

Hardware is not the hard part. **API access** is. Summary of public info as of Oct 2026. Ask the Huawei mentors to confirm every "?".

| Signal | GT 5 Pro / GT 6 Pro has it? | Can *your* app read it? | Confidence |
|---|---|---|---|
| Heart rate (PPG), real-time | Yes | **Yes.** Lite-wearable JS sensor API on the watch; Health Service Kit real-time HR on the phone | High |
| Accelerometer / gyroscope | Yes | **Yes**, lite-wearable JS sensor API | High |
| PPG arrhythmia (AFib screening) | Yes (Huawei's own feature) | Results maybe readable via Health Kit; raw algorithm no | Low |
| Single-lead ECG (30 s) | Yes; CE-certified in Europe for GT 5 Pro | **Probably not** for third parties. Use the exported ECG PDF or a simulation in the demo | Low |
| HRV / R-R intervals | Computed internally | **No.** Huawei forum: "no plan to open HRV and R-R" | High (that it's closed) |
| Skin temperature | Yes | **?** Possibly as a Health Kit data type; not in the lite-wearable sensor list | Unknown |
| SpO2 | Yes | **?** Likely a Health Kit sampled type (permission needed) | Medium |
| Sleep, stress, steps | Yes | Sampled data via Health Kit (needs scope approval) | Medium |
| Watch ↔ phone messaging | Yes | **Yes**, Wear Engine (needs a permission request in the Huawei console) | High, but approval takes time |

**What this means for the choice:**
- Conditions that rely on **heart rate + motion** are safe bets: CPVT, POTS, epilepsy, Parkinson's, ME/CFS, heart failure trends.
- Conditions that rely on **temperature** (Brugada fever, adrenal sick-day, MS heat) are strong stories, but **plan a fallback**: Bluetooth thermometer, manual entry, or a "simulate fever" debug button for the demo.
- **Don't promise ECG interpretation.** Use ECG as "tap to record on your Huawei watch, then attach the PDF to your report".
- Apply for **Wear Engine + Health Service Kit** permissions **today**.

<div class="pb"></div>

## 4. Tier A conditions (deep dives)

### 4.1 Brugada syndrome · the closest sibling to LQTS

**What it is.** An inherited ion-channel disease, most often affecting the SCN5A sodium channel. The heart's structure is normal, but the electrical pattern in the right ventricle is abnormal. The typical ECG shows a "coved" ST elevation in leads V1–V2. It can cause **ventricular fibrillation and sudden death, usually at rest or during sleep**. It is a leading cause of sudden death in young men in Southeast Asia, where it is known as "sudden unexplained nocturnal death syndrome".

**Who / how many.** About **1 in 2,000**; ECG-pattern prevalence 0.1–1% depending on population. Mostly men aged 30–50. Treatment: avoid triggers; an ICD (implantable defibrillator) for high-risk patients; quinidine in some cases.

**Triggers / dangers.**
- **Fever.** A well-known trigger; guidelines say treat fever aggressively and get an ECG.
- **Drugs.** BrugadaDrugs.org keeps a **red list (avoid)** and an **orange list (preferably avoid)**. They include certain antiarrhythmics (flecainide, propafenone), anaesthetics (propofol, bupivacaine), psychotropics (lithium, tricyclic antidepressants), and some antihistamines.
- Large meals, alcohol, cocaine and cannabis; vagal states such as sleep.

**What the watch can see.**
- **Skin-temperature rise → fever alert**: "Brugada + fever = take paracetamol now, get an ECG if > 38.5 °C."
- Night-time heart-rate patterns.
- Fainting / falls (accelerometer).

Wrist single-lead ECG **cannot** reliably see a Brugada pattern, because it needs the right-precordial leads. Say so in the pitch; it shows you know the medicine.

**AI Med Check fit: ★★★★★.** Same engine as LQTS with a different list. Many drugs are on both lists, so a cross-check is easy.

**Other features.** Fever-mode Live View; pre-anaesthesia sheet (propofol and bupivacaine matter); family cascade screening reminder ("first-degree relatives should get an ECG"); alcohol / big-meal log.

**Demo moment.** Scan a box of a common antidepressant → 🔴 "Avoid – Brugada red list". Then "simulate fever" on the watch → phone shows the fever protocol and the translated emergency card.

**Risks.** Temperature API access; rare condition, so explain it in one sentence.

---

### 4.2 CPVT (catecholaminergic polymorphic VT)

**What it is.** An inherited calcium-handling defect, usually in the RYR2 gene. **Adrenaline from exercise or emotion** triggers dangerous fast rhythms (bidirectional or polymorphic VT) in a structurally normal heart. It typically shows up in **children and teenagers** as fainting during sport or fright, and is a cause of sudden death in young people.

**Who / how many.** About **1 in 10,000**. Treatment: beta-blockers, which **must not be missed**; flecainide; sometimes surgical cardiac denervation; an ICD.

**Key fact for a wearable.** On exercise tests, arrhythmias appear above a **heart-rate threshold of about 120–130 bpm**, and **each patient's threshold is fairly consistent**. That makes it an ideal rule for a watch: the doctor sets a personal HR ceiling, and the watch warns *before* it is crossed.

**What the watch can see.** Real-time heart rate against the personal ceiling (warnings at 90% and 100%); sport-session detection; beta-blocker adherence; heart-rate surges during emotional stress.

**AI Med Check fit: ★★★☆☆.** Avoid sympathomimetics: decongestants (pseudoephedrine), ADHD stimulants, some asthma relievers (use with caution), energy drinks and caffeine. The checker is useful but the list is shorter than for LQTS or Brugada.

**Other features.** **Parent mode** (F7): parent's phone or tablet gets alerts during PE class; a coach / school card; beta-blocker "taken?" prompt on the watch.

**Demo moment.** Teammate jogs on the spot → watch vibrates at the personal threshold (e.g. 125 bpm) → parent's tablet shows a live alert. **This is the most dependable live demo in the list**, because it only uses real-time heart rate, which you can certainly access.

**Risks.** Very rare; ethics of a teenage user (frame it as parent + teen).

---

### 4.3 Adrenal insufficiency (Addison's disease and steroid dependence)

**What it is.** The adrenal glands don't make enough **cortisol** (and in Addison's, also aldosterone). Causes: autoimmune Addison's, pituitary disease, congenital adrenal hyperplasia, and, most commonly, **long-term steroid use** that suppresses the glands. Patients take hydrocortisone every day. During illness or injury the body needs much more cortisol. If they don't increase the dose, an **adrenal crisis** follows: vomiting, low blood pressure, shock, death.

**Who / how many.** Primary AI is ~100–140 per million, secondary is more common, and steroid-induced AI is far more common again (people on long-term prednisolone). **Adrenal crisis occurs in ~6–8 per 100 patients per year**, with real mortality.

**Triggers / dangers.**
- Infection, fever, vomiting or diarrhoea (the tablets aren't absorbed), surgery, trauma.
- Missed doses.
- **Drug interactions**: rifampicin, phenytoin and carbamazepine (CYP3A4 inducers) speed up cortisol breakdown; stopping steroids suddenly is dangerous.

**Sick-day rules** (UK Society for Endocrinology, 2025):
- **Fever or illness → double the daily dose.**
- **≥ 39 °C → 20 mg hydrocortisone every 6 h + seek advice.**
- **Vomiting twice → 100 mg IM hydrocortisone injection + emergency.**

These are **deterministic**, so they are perfect for an app.

**What the watch can see.** Skin-temperature rise → prompts the "Sick Day Rule 1" checklist; resting HR up + SpO2 down → escalate; fall / collapse detection.

**AI Med Check fit: ★★★★☆.** Interactions (inducers), plus "does this new prescription contain a steroid?" and "is it safe to stop?".

**Other features.** **Sick-day wizard** (F4); **step-by-step emergency injection guide** on the watch and phone (a caregiver can follow it); **multilingual steroid emergency card** for paramedics abroad (F5), which suits Huawei's global push; surgery cover sheet (F6).

**Demo moment.** Fever detected → watch: "Sick day? Double your dose" → user taps "vomited twice" → phone switches to emergency mode: injection guide + Polish/English paramedic card + one-tap 112.

**Risks.** Temperature API (fallback: thermometer input). Strong, under-served story; few competitors.

<div class="pb"></div>

### 4.4 Myasthenia gravis (MG)

**What it is.** An autoimmune disease in which antibodies block the junction between nerve and muscle, usually the acetylcholine receptor. The hallmark is **muscle weakness that gets worse with use**: drooping eyelids (ptosis), double vision, slurred speech, trouble swallowing, weak limbs. A **myasthenic crisis**, where the breathing muscles fail and ventilation is needed, happens to ~15–20% of patients at some point.

**Who / how many.** About **15–20 per 100,000**. Two age peaks: women under 40, men over 60.

**Triggers / dangers.** **Very drug-sensitive:**
- **Fluoroquinolones** (FDA boxed warning; exacerbation within ~1 day, ~30% progressed to crisis in FDA reports).
- Aminoglycosides; macrolides (azithromycin, clarithromycin).
- **IV magnesium**; beta-blockers; quinine / chloroquine / hydroxychloroquine.
- Botulinum toxin; neuromuscular blockers; checkpoint-inhibitor cancer drugs.
- Also infection, surgery, heat, stress.

**What the watch can see.** Limited. SpO2 and breathing rate drop *late*. Real-time heart rate can show tachycardia from respiratory distress.

**The interesting part is phone AI, not the watch:**
- **Camera ptosis test**: face landmarks measure eyelid opening during a 60-second "look up" fatigue test (Core Vision, on-device). An objective score that tracks fatigue.
- **Voice bulbar test**: count aloud from 1 to 50. Speech analysis detects nasal or slurred speech getting worse, and the count reached on one breath is a known bedside test of breathing strength.
- Daily **MG-ADL** score; trend → doctor report.

**AI Med Check fit: ★★★★★.** A long, well-documented avoid list, often prescribed by GPs and dentists who don't know about the MG.

**Demo moment.** Scan ciprofloxacin → 🔴 "Boxed warning for MG". Then a 20-second camera eyelid test with a live overlay showing the eyelid gap shrinking.

**Huawei angle.** Shows **on-device AI privacy** (face and voice never leave the phone). This is the strongest on-device-AI showcase in the list.

**Risks.** The watch plays a smaller role. Pitch it as "phone + watch" with the phone leading.

---

### 4.5 POTS (postural orthostatic tachycardia syndrome)

**What it is.** A dysfunction of the autonomic nervous system. On standing, **heart rate jumps by ≥ 30 bpm (≥ 40 in ages 12–19) within 10 minutes**, without a drop in blood pressure. Symptoms: dizziness, palpitations, brain fog, fatigue, fainting. It often follows viral illness, **including COVID-19**, and often occurs alongside Ehlers-Danlos syndrome.

**Who / how many.** Estimates of **~1–3% after COVID**; 3–6 million in the US; mostly women aged 15–50. **Diagnostic delay is typically years**; many patients are first told it's anxiety.

**Triggers / dangers.** Standing still, heat, dehydration, big carb-heavy meals, alcohol, menstruation, deconditioning. Drugs that worsen it: vasodilators, diuretics, some antidepressants that raise heart rate (SNRIs, tricyclics), stimulants. Not life-threatening, but severely disabling.

**What the watch can see.** **Best signal in the list:** accelerometer posture change + heart-rate jump = automatic detection of orthostatic episodes. **Guided 10-minute active-stand (NASA lean) test** on the watch. Heat (weather API) and fluid/salt intake.

**AI Med Check fit: ★★☆☆☆.** Moderate. Some HR-raising drugs; interactions with POTS meds (ivabradine, midodrine, fludrocortisone).

**Other features.** Pre-diagnosis "evidence pack" PDF for the GP (the biggest real-world value: shortening the diagnostic delay); salt and fluid tracker; trigger diary.

**Demo moment.** Presenter lies down, then stands **on stage** → live heart-rate graph jumps → app labels it an "orthostatic event +34 bpm". A real reaction with real data. *(Healthy people often rise 10–20 bpm, so pre-record a backup, or pick a team member with a big natural rise.)*

**Risks.** Not a sudden-death condition (lower stakes). Some competition (Visible app for pacing), but none on HarmonyOS.

<div class="pb"></div>

### 4.6 Acute hepatic porphyria (AHP, mainly AIP)

**What it is.** An inherited defect in the liver's **heme-production pathway**. When something increases demand on the pathway, toxic intermediates (ALA, PBG) build up and cause **acute neurovisceral attacks**: severe abdominal pain, fast heart rate, high blood pressure, low sodium, confusion, seizures, muscle weakness and paralysis. Urine may turn dark or reddish. It is famous for being **misdiagnosed for years**.

**Who / how many.** The gene variant is fairly common (~1 in 1,700 carriers), but symptomatic disease is ~1 in 100,000. Mostly women aged 15–45. Treatment: hemin, givosiran.

**Triggers / dangers.**
- **Drugs** (the classic example): barbiturates, carbamazepine, phenytoin, sulfonamides, progestogens, some antibiotics.
- **Fasting / low-carb diets**, alcohol, smoking, infection, stress, the menstrual cycle (luteal phase).

**Drug database.** **NAPOS** (Norwegian Porphyria Centre / European Porphyria Network) grades each drug: Safe / Probably safe / Possibly unsafe / Probably unsafe / Unsafe. A well-structured graded list, ideal for F1.

**What the watch can see.** Rising resting heart rate (tachycardia is the most common early sign); sleep disruption; cycle tracking; fasting tracker (missed-meal reminders).

**AI Med Check fit: ★★★★★.** The best structured database of any condition here.

**Demo moment.** Scan an anticonvulsant → 🔴 "Unsafe (NAPOS)" + safer alternatives to discuss with the doctor. Fasting-day warning → "eat carbohydrates now".

**Risks.** Very rare; the watch signal is weaker. Excellent for the "med check" part, weaker for the "watch" part.

---

### 4.7 Epilepsy

**What it is.** A tendency to recurrent seizures caused by abnormal electrical activity in the brain. The most dangerous are **generalised tonic-clonic seizures** (full-body convulsions), especially **at night**, which carry the risk of **SUDEP** (sudden unexpected death in epilepsy).

**Who / how many.** About **50 million people worldwide**; ~1/3 don't respond fully to medication.

**Triggers / dangers.** **Missed medication** (number one), **sleep deprivation**, alcohol, stress, flashing lights (photosensitive ~3%), fever in children. **Drug interactions**: tramadol and bupropion lower the seizure threshold; hormonal contraceptives lower lamotrigine levels; enzyme inducers interact with many drugs. Interactions matter a lot in epilepsy.

**What the watch can see.** **Accelerometer convulsion pattern + heart-rate spike** → automatic caregiver alert with GPS location; sleep-debt tracking; medication adherence.

**AI Med Check fit: ★★★★☆.** Interactions plus threshold-lowering drugs.

**Demo moment.** Simulated convulsion (shaking the wrist rhythmically for 15 s) → 10-second "Are you OK?" countdown on the watch → caregiver tablet alert with location.

**Risks.** **Crowded field**: Empatica EpiMonitor, EpiWatch (Apple Watch, FDA), NightWatch. Detection accuracy is hard; false alarms. Novelty is lower, but "first on HarmonyOS" works if you need it.

---

### 4.8 ME/CFS and Long COVID (post-exertional malaise)

**What it is.** **ME/CFS** is a chronic illness whose defining feature is **post-exertional malaise (PEM)**: a "crash" 12–72 h after exceeding one's energy limit, lasting days to weeks. Long COVID shares this in a large subgroup. Research shows a **very low anaerobic threshold**, and HRV that takes **~24 h** to recover after effort (vs 3–6 h in healthy people).

**Who / how many.** ME/CFS ~0.4–1%; Long COVID affects many millions. Many are young, working-age adults.

**Triggers / dangers.** Any physical, cognitive or emotional effort above the threshold. "Pacing" (staying below a personal heart-rate limit) is the main self-management tool, and a 2025 UK feasibility study supports **heart-rate-monitor pacing**.

**What the watch can see.** **Real-time heart rate vs the pacing ceiling** (a common rule: resting HR + 15, or ~50–60% of max); daily "energy envelope" budget; morning resting HR as a recovery check. HRV isn't open to third parties, so use resting-HR trends.

**AI Med Check fit: ★☆☆☆☆.** Low.

**Other features.** Crash prediction from a load history (rolling "exertion debt"); symptom diary by voice; AI weekly summary for the doctor or a benefits application.

**Demo moment.** Walk around → the "battery" drains live → watch vibrates "slow down" → next-day crash-risk forecast.

**Risks.** No med check; existing apps (Visible). Strong community need and Long COVID relevance in Europe.

<div class="pb"></div>

## 5. Tier B conditions (shorter)

### 5.1 Parkinson's disease
**What it is.** A progressive neurodegenerative disease with loss of dopamine neurons. Main symptoms: resting **tremor at 4–6 Hz**, slowness, stiffness, falls; later, **"wearing-off"** between levodopa doses and **dyskinesia** (involuntary movements) as a side effect of medication. More than 10 million people worldwide.
**Wearable.** Excellent. The accelerometer measures tremor and dyskinesia, the same approach as FDA-cleared Apple Watch tools (StrivePD, Kneu Health 2026). **Fall detection.**
**Med check.** ★★★★☆. **Dopamine-blocking drugs are dangerous**: haloperidol, metoclopramide, prochlorperazine (common anti-nausea drugs in hospitals!). MAO-B inhibitor + serotonergic interactions. **Levodopa dose timing** ("time critical medication") and protein in meals reduce absorption.
**Verdict.** Strong and demo-able (shake your hand → tremor score). The weakness is crowded competition on Apple; the strength is that nothing like it exists on HarmonyOS. A good **backup pick**.

### 5.2 Heart failure (decompensation early warning)
**What it is.** The heart can't pump enough. Patients go in and out of hospital with fluid overload. About 64 million people worldwide; a huge cost to health systems.
**Wearable.** Rising resting heart rate, less activity, rising night-time breathing rate, lower SpO2, **weight gain > 2 kg in 3 days** → **Huawei smart scale + watch + phone = a true multi-device showcase.**
**Med check.** ★★★★☆. **NSAIDs (ibuprofen!)**, some calcium-channel blockers, thiazolidinediones, decongestants, high-sodium effervescent tablets.
**Verdict.** The best fit with Huawei's *device ecosystem*. Older users and less "hackathon-sexy", but practical value scores well.

### 5.3 Multiple sclerosis heat sensitivity (Uhthoff's phenomenon)
**What it is.** MS is an autoimmune disease that strips the myelin coating from nerves. ~75% of patients have **symptoms that temporarily get worse with even a small rise in core temperature** (exercise, hot weather, hot showers, fever).
**Wearable.** Skin temperature + heart rate + weather → "pre-cool now" alerts. Temperature API risk again.
**Med check.** ★★☆☆☆. Low (some interactions with disease-modifying therapies).
**Verdict.** A good secondary pack, not a lead.

### 5.4 G6PD deficiency
**What it is.** The **most common enzyme deficiency in the world (~400–500 million people)**, especially around the Mediterranean, Africa, the Middle East and Asia. Red blood cells burst (haemolysis) when exposed to oxidative triggers.
**Triggers.** **Fava (broad) beans**, primaquine, dapsone, rasburicase, nitrofurantoin, methylene blue, some sulfonamides, naphthalene (mothballs).
**Wearable.** Weak (heart rate rises with anaemia).
**Med check + food scan.** ★★★★★. Scan a food label for fava beans or broad-bean flour, plus a drug check.
**Verdict.** Huge global population, but little for the watch to do. Good as an **extra pack** to show the engine scales.

### 5.5 Malignant hyperthermia susceptibility (MHS)
**What it is.** An inherited muscle disorder (RYR1). Certain **anaesthetic gases and succinylcholine** set off a runaway rise in muscle metabolism: high temperature, rigidity, death if untreated. About **1 in 2,000** carry the susceptibility. Related to exertional heat stroke and muscle breakdown (rhabdomyolysis).
**Fit.** F6 (pre-surgery sheet) + F5 (card) + exertional heat alerts from the watch. Niche.

### 5.6 Others considered (and why they rank lower)
| Condition | Why lower |
|---|---|
| Atrial fibrillation | Huawei already does AFib screening; crowded field. *Anticoagulant interaction checker* is still useful |
| Type 1 diabetes | CGM devices dominate; insulin-dose advice is high liability |
| Sleep apnoea | Huawei watch already screens for it |
| Hypertrophic cardiomyopathy (1:500) | Good drug list (nitrates, PDE5 inhibitors, dehydration), but the wearable signal is weak |
| Hereditary angioedema | ACE-inhibitor / oestrogen triggers; no watch signal |
| Sickle cell disease | Hydration, cold, altitude and SpO2 triggers; strong global need. Worth a look if your team has a personal link |
| WPW syndrome | Treated with ablation; low ongoing need |

<div class="pb"></div>

## 6. Scoring matrix

Scores 1–5. **Watch** = useful signal with *accessible* APIs. **Med** = strength of the drug list for the AI med check. **Stakes** = sudden, preventable harm. **Demo** = live, reliable stage moment. **Novel** = lack of competitors. **HOS** = how well it shows HarmonyOS features (devices working together, on-device AI, agent).

| Condition | Watch | Med | Stakes | Demo | Novel | HOS | **Total /30** |
|---|---|---|---|---|---|---|---|
| **Inherited arrhythmia pack (LQTS + Brugada + CPVT)** | 4 | 5 | 5 | 5 | 5 | 5 | **29** |
| CPVT alone | 5 | 3 | 5 | 5 | 5 | 4 | **27** |
| Adrenal insufficiency | 3* | 4 | 5 | 4 | 5 | 5 | **26** |
| Myasthenia gravis | 2 | 5 | 5 | 5 | 5 | 5 | **27** |
| Brugada alone | 3* | 5 | 5 | 4 | 5 | 4 | **26** |
| Parkinson's | 5 | 4 | 3 | 5 | 3 | 4 | **24** |
| Heart failure | 4 | 4 | 4 | 3 | 3 | 5 | **23** |
| POTS | 5 | 2 | 2 | 5 | 4 | 4 | **22** |
| Acute hepatic porphyria | 2 | 5 | 4 | 3 | 5 | 3 | **22** |
| Epilepsy | 4 | 4 | 5 | 4 | 2 | 4 | **23** |
| ME/CFS / Long COVID | 4 | 1 | 2 | 4 | 3 | 3 | **17** |
| G6PD deficiency | 1 | 5 | 3 | 3 | 4 | 3 | **19** |
| MS heat sensitivity | 3* | 2 | 2 | 3 | 4 | 3 | **17** |

\* depends on access to skin temperature. If it isn't available, subtract 1–2.

## 7. Recommendations

### Option 1 (recommended): "Inherited arrhythmia companion": LQTS + Brugada + CPVT
**Why.** One drug-check engine and pitch covers all three. These three syndromes are **managed by the same specialists (inherited-arrhythmia / electrophysiology clinics)**, run in families, and each has a **different watch-detectable trigger**. One app, three rule sets:

| Syndrome | Watch rule | Med list | Special feature |
|---|---|---|---|
| LQTS | HR/exertion rules by genetic type (LQT1 swim/exercise, LQT2 alarm-clock/noise), vomiting/diarrhoea → electrolyte warning | CredibleMeds QT list | "Don't use a loud alarm" tip (LQT2) |
| Brugada | **Skin-temp fever → protocol** | BrugadaDrugs red/orange | Fever Live View |
| CPVT | **Personal HR ceiling** | Sympathomimetics | Parent / school mode |

Plus **family cascade screening**: one diagnosis → invite relatives to get an ECG, with a share link. A good "social" HarmonyOS feature.
**Pitch line:** *"One app guards three silent killers of young people, from your Huawei watch to your doctor's tablet."*

### Option 2: Adrenal insufficiency "sick-day guardian"
Deterministic sick-day rules + a step-by-step emergency injection guide + a translated emergency card. Few competitors, life-saving, simple to build correctly. Best if the judges value **practical applicability**.

### Option 3: Myasthenia gravis "fatigue lens"
Best for **on-device AI**: camera eyelid-droop test + voice breathing/speech test + a strong drug-avoid list. The watch is secondary. Best if the Huawei mentors say watch APIs are blocked or slow to approve.

### Demo script (Option 1, 3 minutes)
1. **Hook (20 s).** "A 15-year-old collapses in PE class. A 40-year-old dies in his sleep after a fever. A woman's heart stops after a routine antibiotic. Three different gene defects; all three deaths were preventable."
2. **Med check (40 s).** Scan a real box (e.g. a macrolide antibiotic) → 🔴 QT risk → explanation + "question for your doctor" + alternative classes to discuss.
3. **CPVT live (40 s).** Teammate runs on the spot → watch buzzes at 125 bpm → parent's tablet shows the alert (devices working together).
4. **Brugada fever (30 s).** Simulated temperature rise → fever protocol Live View → emergency card in Polish.
5. **Agent (20 s).** "Celia, can I take this cough syrup?" → app intent answers.
6. **Doctor (30 s).** Continue onto the tablet → doctor report with events and adherence.

## 8. Drug-list data sources and licensing

| List | Condition | Access | Hackathon approach |
|---|---|---|---|
| CredibleMeds (QTdrugs) | LQTS | Free registration; **API / redistribution need a licence** | Hand-curate ~50 common drugs, cite the source |
| BrugadaDrugs.org | Brugada | Free web, red/orange lists | Curate red + orange, cite |
| NAPOS Drug Database | Acute porphyria | Free web, graded S/PRS/PSU/PRU/U | Curate top 50 |
| MGFA "Drugs to avoid" | Myasthenia gravis | Free PDF | Curate classes + examples |
| g6pd.org / WHO | G6PD | Free | Curate |
| Society for Endocrinology sick-day rules | Adrenal insufficiency | Free leaflet | Encode rules |
| RxNorm / openFDA / EMA | Brand → ingredient mapping | Free APIs | For F1/F2 lookup |

**Licensing note:** for a demo, a cited, hand-curated subset is fine. A production version would need data licences and EU MDR certification (likely class IIa or higher for decision support). Mention this on the "next steps" slide. It shows maturity.

<div class="pb"></div>

## 9. Sources

**Watch and platform**
- GSMArena: Huawei Watch GT 6 Pro review: https://www.gsmarena.com/huawei_watch_gt_6_pro_review-news-69885.php
- Smartwatch Specifications: GT 6 Pro sensors: https://www.smartwatchspecifications.com/huawei-watch-gt-6-pro-smartwatch-specifications-and-features/
- TechRadar: GT 5 Pro review (ECG, TruSense): https://www.techradar.com/health-fitness/smartwatches/huawe-watch-gt5-pro-review
- Huawei: Watch GT 5 Pro product page: https://consumer.huawei.com/eg-en/wearables/watch-gt5-pro/
- Huawei Developer Forum: HRV / R-R not opened in Health Kit: https://forums.developer.huawei.com/forumPortal/en/topic/0201119084708813150
- Huawei Health Kit (HarmonyOS JS) API overview: https://developer.huawei.com/consumer/en/doc/hmscore-references/harmonyos-overview-0000001181132236
- Wear Engine: https://developer.huawei.com/consumer/en/hms/huawei-wearengine
- Lite-wearable sensor sample (HR, accelerometer): https://github.com/espinr/litewearable
- Wear Engine lite-wearable ↔ phone sample: https://github.com/Explore-In-HMOS-Wearable/wear-engine-lite-wearable-to-mobile

**Conditions**
- BrugadaDrugs.org: https://www.brugadadrugs.org/
- Postema et al., Drugs and Brugada syndrome patients (Heart Rhythm): https://www.sciencedirect.com/science/article/abs/pii/S1547527109007395
- Brugada syndrome overview (Cleveland Clinic): https://my.clevelandclinic.org/health/diseases/16813-brugada-syndrome
- Fever-induced Brugada pattern: https://www.revportcardiol.org/en-fever-induced-type-1-brugada-pattern-articulo-S2174204915000562
- CPVT HR threshold (Heart Rhythm / PMC): https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6219810/
- CPVT review (J Clin Med 2024): https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10971616/
- CPVT (NIH GARD): https://rarediseases.info.nih.gov/diseases/4421/catecholaminergic-polymorphic-ventricular-tachycardia
- POTS state-of-the-art review: https://www.sciencedirect.com/science/article/pii/S1443950625016543
- POTS critical assessment (PMC): https://pmc.ncbi.nlm.nih.gov/articles/PMC9012474/
- POTS diagnostic delays case series: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12726858/
- Myasthenia gravis & crisis (EMCrit IBCC): https://emcrit.org/ibcc/myasthenia/
- MGFA: drugs to avoid (PDF): https://www.myastheniagravis.org/wp-content/uploads/2021/03/September-2019-drugs-to-avoid.pdf
- Pharmacy Times: antibiotics that aggravate MG: https://www.pharmacytimes.com/view/antibiotics-that-aggravate-myasthenia-gravis
- NAPOS drug database (GPAC): https://www.gpac-porphyria.org/napos
- American Porphyria Foundation drug database: https://porphyriafoundation.org/for-healthcare-professionals/drug-safety1/
- Empatica EpiMonitor: https://www.empatica.com/en/epimonitor/
- EpiWatch FDA clearance (AHA): https://www.aha.org/aha-center-health-innovation-market-scan/2025-04-08-fda-clears-apple-watch-powered-platform-seizure-monitoring
- Multimodal seizure detection wearable study: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8418082/
- ME Association: HR-monitor pacing feasibility study: https://meassociation.org.uk/2025/10/research-pacing-with-a-heart-rate-monitor-for-people-with-me-cfs-and-long-covid-a-feasibility-study/
- HRV & PEM thresholds in Long COVID (medRxiv): https://www.medrxiv.org/content/10.1101/2025.03.18.25320115.full.pdf
- CDC: managing PEM: https://www.cdc.gov/me-cfs/pdfs/toolkit/Managing-PEM_508.pdf
- NICE / NCBI: adrenal insufficiency identification & management: https://www.ncbi.nlm.nih.gov/books/NBK609655/
- Society for Endocrinology: sick day rules leaflet (2025): https://www.endocrinology.org/media/atsfelcr/ai-leaflet-final-9th-july-2025.pdf
- Pituitary Foundation: hydrocortisone sick day rules: https://www.pituitary.org.uk/information/hydrocortisone-sick-day-rules/
- Kneu Health Parkinson's Apple Watch FDA clearance (2026): https://hitconsultant.net/2026/09/03/fda-clears-kneu-health-apple-watch-parkinsons-tremor-dyskinesia-monitoring/
- Wearable sensors for Parkinson's (npj Parkinson's Disease): https://www.nature.com/articles/s41531-023-00585-y
- MS Trust: Uhthoff's phenomenon: https://mstrust.org.uk/a-z/uhthoffs-phenomenon

*Figures without a link (LQTS 1:2,000, MG prevalence, G6PD 400–500 M, MHS 1:2,000, epilepsy 50 M (WHO), heart failure 64 M, Parkinson's > 10 M) are widely cited textbook / WHO estimates. Check them before putting them on a slide.*
