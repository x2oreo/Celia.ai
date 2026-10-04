// Plain-English "about this medicine" facts for every ingredient in DrugDataset: what it is used for, how it works
// in one line, and up to three general tips from public patient leaflets (EMA / national registers). General
// information only - never a safety verdict (that comes from DrugDataset) and never a dose instruction.
//
// Rules checked by test/MedInfo.test.ets (DrugInfo suite): every DRUGS ingredient has an entry, at most three tips, each line short.

export interface DrugInfo {
  ingredient: string;   // DrugEntry.ingredient
  usedFor: string;      // "Bacterial infections of the chest, throat and skin"
  howItWorks: string;   // one line
  tips: string[];       // <= 3 general tips
}

export const INFO_TIP_MAX: number = 3;
export const INFO_LINE_MAX: number = 100;

function i(ingredient: string, usedFor: string, howItWorks: string, tips: string[]): DrugInfo {
  const e: DrugInfo = { ingredient: ingredient, usedFor: usedFor, howItWorks: howItWorks, tips: tips };
  return e;
}

// Shared tips, worded once.
const T_COURSE: string = 'Finish the full course, even if you feel better.';
const T_QT_STACK: string = 'Tell every doctor you have long QT before a new prescription.';
const T_K_MG: string = 'Vomiting or diarrhoea lowers potassium - ask about checking it.';
const T_ALCOHOL: string = 'Avoid alcohol while taking it.';
const T_DROWSY: string = 'May make you drowsy - take care driving.';
const T_NO_STOP: string = 'Do not stop suddenly; your doctor will taper the dose.';
const T_WEEKS: string = 'Takes a few weeks to work fully.';
const T_FOOD: string = 'Take with food to protect your stomach.';
const T_STOMACH: string = 'Can irritate the stomach; avoid if you have ulcers.';
const T_SUN: string = 'Can make skin sensitive to sun - use sunscreen.';
const T_GRAPEFRUIT: string = 'Avoid grapefruit juice.';
const T_HOSPITAL: string = 'Given in hospital under monitoring.';
const T_ECG: string = 'Usually started with ECG checks.';
const T_LYTES: string = 'Can lower potassium and magnesium; blood tests may be needed.';
const T_COLD: string = 'Often hidden in cold and flu mixes - read the label.';
const T_STIM: string = 'Stimulant: can raise heart rate.';
const T_EMPTY: string = 'Take on an empty stomach, 30 minutes before food.';
const T_MORNING: string = 'Take in the morning so it does not keep you up at night.';
const T_BB_STOP: string = 'Never stop suddenly - it can trigger a fast heart rate.';
const T_BB_DAILY: string = 'Take at the same time every day; missed doses matter in LQTS.';
const T_DIZZY: string = 'Stand up slowly at first; it can make you dizzy.';
const T_SUGAR: string = 'Can hide signs of low blood sugar.';

const BETA_TIPS: string[] = [T_BB_DAILY, T_BB_STOP, T_DIZZY];
const MACROLIDE_TIPS: string[] = [T_COURSE, T_QT_STACK, T_K_MG];
const QUINOLONE_TIPS: string[] = [T_COURSE, 'Stop and call a doctor if a tendon (heel, ankle) hurts.', T_QT_STACK];
const AZOLE_TIPS: string[] = ['Interacts with many medicines - show your list to the pharmacist.', T_QT_STACK];
const SETRON_TIPS: string[] = ['Often given before surgery or chemotherapy - mention your long QT.', T_K_MG];
const PPI_TIPS: string[] = [T_EMPTY, 'Long use can lower magnesium; ask about a blood test.'];
const SSRI_TIPS: string[] = [T_WEEKS, T_NO_STOP, T_ALCOHOL];
const TCA_TIPS: string[] = [T_DROWSY, T_NO_STOP, T_ALCOHOL];
const AP_TIPS: string[] = [T_DROWSY, T_NO_STOP, T_ECG];
const AA_TIPS: string[] = [T_ECG, 'Keep regular check-ups and blood tests.', T_NO_STOP];
const DIURETIC_TIPS: string[] = [T_MORNING, T_LYTES];
const AH_SEDATING_TIPS: string[] = [T_DROWSY, T_ALCOHOL];
const AH_TIPS: string[] = ['Usually once a day.', 'Some people still feel a little sleepy.'];
const OPIOID_TIPS: string[] = [T_DROWSY, T_ALCOHOL, 'Can cause constipation.'];
const BETA2_TIPS: string[] = ['Can raise heart rate and lower potassium.', 'Rinse your mouth after using the inhaler.'];
const DECONGESTANT_TIPS: string[] = [T_COLD, T_STIM];
const ADHD_STIM_TIPS: string[] = [T_STIM, T_MORNING, 'Needs heart-rate and blood-pressure checks.'];
const NSAID_TIPS: string[] = [T_FOOD, T_STOMACH, 'Can raise blood pressure with long use.'];
const PEN_TIPS: string[] = [T_COURSE, 'Tell your doctor about any penicillin allergy.'];
const CEPH_TIPS: string[] = [T_COURSE, 'Tell your doctor about any penicillin allergy.'];
const STATIN_TIPS: string[] = ['Report unexplained muscle pain.', 'Keep taking it even when you feel well.'];
const ACE_TIPS: string[] = [T_DIZZY, 'A dry cough is a common side effect.'];
const OAB_TIPS: string[] = ['Can cause a dry mouth and constipation.'];
const ANAESTHESIA_TIPS: string[] = [T_HOSPITAL, 'Tell the anaesthetist about your long QT beforehand.'];
const SUPPLEMENT_TIPS: string[] = ['Only take as advised; levels are checked with a blood test.'];

export const DRUG_INFO: DrugInfo[] = [
  // ── Antibiotics ─────────────────────────────────────────────────────────────────────────────
  i('clarithromycin', 'Chest, throat, skin infections; stomach H. pylori', 'Stops bacteria making proteins.',
    MACROLIDE_TIPS),
  i('azithromycin', 'Chest, throat, ear and some sexual infections', 'Stops bacteria making proteins.',
    MACROLIDE_TIPS),
  i('erythromycin', 'Chest and skin infections', 'Stops bacteria making proteins.', MACROLIDE_TIPS),
  i('roxithromycin', 'Chest, throat and skin infections', 'Stops bacteria making proteins.', MACROLIDE_TIPS),
  i('ciprofloxacin', 'Urinary, gut and bone infections', 'Blocks the enzyme bacteria use to copy DNA.',
    QUINOLONE_TIPS),
  i('levofloxacin', 'Pneumonia, sinus and urinary infections', 'Blocks the enzyme bacteria use to copy DNA.',
    QUINOLONE_TIPS),
  i('moxifloxacin', 'Pneumonia and sinus infections', 'Blocks the enzyme bacteria use to copy DNA.',
    QUINOLONE_TIPS),
  i('ofloxacin', 'Urinary and eye or ear infections', 'Blocks the enzyme bacteria use to copy DNA.', QUINOLONE_TIPS),
  i('norfloxacin', 'Urinary infections', 'Blocks the enzyme bacteria use to copy DNA.', QUINOLONE_TIPS),
  i('metronidazole', 'Gut, dental and vaginal infections', 'Damages the DNA of certain bacteria and parasites.',
    ['Do not drink any alcohol during and 2 days after.', T_COURSE]),

  // ── Antifungals ─────────────────────────────────────────────────────────────────────────────
  i('fluconazole', 'Thrush and other yeast infections', 'Weakens the fungal cell wall.', AZOLE_TIPS),
  i('ketoconazole', 'Fungal skin and scalp infections', 'Weakens the fungal cell wall.', AZOLE_TIPS),
  i('itraconazole', 'Fungal nail and skin infections', 'Weakens the fungal cell wall.', AZOLE_TIPS),
  i('voriconazole', 'Serious fungal infections', 'Weakens the fungal cell wall.', [T_SUN, AZOLE_TIPS[0]]),
  i('posaconazole', 'Preventing serious fungal infections', 'Weakens the fungal cell wall.', AZOLE_TIPS),

  // ── Antimalarials / antiprotozoals ──────────────────────────────────────────────────────────
  i('hydroxychloroquine', 'Lupus, rheumatoid arthritis, malaria', 'Calms the immune system.',
    ['Needs regular eye checks with long use.', T_ECG]),
  i('chloroquine', 'Malaria prevention and treatment', 'Kills the malaria parasite in blood cells.',
    ['Start before travel as prescribed.', T_ECG]),
  i('quinine', 'Malaria; sometimes leg cramps', 'Kills the malaria parasite.',
    ['Tonic water contains small amounts of quinine.']),
  i('pentamidine', 'Pneumocystis pneumonia and some parasites', 'Kills certain parasites and fungi.', [T_HOSPITAL]),

  // ── Antiemetics and gut ─────────────────────────────────────────────────────────────────────
  i('ondansetron', 'Nausea after surgery or chemotherapy', 'Blocks serotonin signals that trigger vomiting.',
    SETRON_TIPS),
  i('granisetron', 'Nausea from chemotherapy', 'Blocks serotonin signals that trigger vomiting.', SETRON_TIPS),
  i('dolasetron', 'Nausea from chemotherapy or surgery', 'Blocks serotonin signals that trigger vomiting.',
    SETRON_TIPS),
  i('domperidone', 'Nausea and bloating', 'Helps the stomach empty faster.',
    ['Use the lowest dose for the shortest time.', T_K_MG]),
  i('metoclopramide', 'Nausea and slow stomach emptying', 'Speeds up the stomach and blocks nausea signals.',
    ['Short use only (up to 5 days).', T_K_MG]),
  i('droperidol', 'Nausea around surgery', 'Blocks dopamine in the brain\'s vomiting centre.', [T_HOSPITAL]),
  i('promethazine', 'Allergy, nausea, travel sickness, sleep', 'Blocks histamine; strongly sedating.',
    AH_SEDATING_TIPS),
  i('loperamide', 'Short-term diarrhoea', 'Slows down the gut.',
    ['Never take more than the pack says.', T_K_MG]),

  // ── Acid reducers ───────────────────────────────────────────────────────────────────────────
  i('omeprazole', 'Heartburn, reflux, stomach ulcers', 'Turns down acid pumps in the stomach.', PPI_TIPS),
  i('esomeprazole', 'Heartburn, reflux, stomach ulcers', 'Turns down acid pumps in the stomach.', PPI_TIPS),
  i('pantoprazole', 'Heartburn, reflux, stomach ulcers', 'Turns down acid pumps in the stomach.', PPI_TIPS),
  i('lansoprazole', 'Heartburn, reflux, stomach ulcers', 'Turns down acid pumps in the stomach.', PPI_TIPS),
  i('famotidine', 'Heartburn and ulcers', 'Blocks histamine signals that make acid.', ['Works within an hour.']),

  // ── Antidepressants and mood ────────────────────────────────────────────────────────────────
  i('citalopram', 'Depression and anxiety', 'Raises serotonin levels in the brain.', SSRI_TIPS),
  i('escitalopram', 'Depression and anxiety', 'Raises serotonin levels in the brain.', SSRI_TIPS),
  i('fluoxetine', 'Depression, OCD, bulimia', 'Raises serotonin levels in the brain.', SSRI_TIPS),
  i('paroxetine', 'Depression, anxiety, panic', 'Raises serotonin levels in the brain.', SSRI_TIPS),
  i('sertraline', 'Depression, anxiety, PTSD', 'Raises serotonin levels in the brain.', SSRI_TIPS),
  i('fluvoxamine', 'Depression and OCD', 'Raises serotonin levels in the brain.', SSRI_TIPS),
  i('venlafaxine', 'Depression and anxiety', 'Raises serotonin and noradrenaline.', SSRI_TIPS),
  i('mirtazapine', 'Depression, often with poor sleep', 'Boosts serotonin and noradrenaline signals.',
    [T_DROWSY, 'Can increase appetite.']),
  i('trazodone', 'Depression and sleep problems', 'Changes serotonin signalling; sedating.', TCA_TIPS),
  i('amitriptyline', 'Nerve pain, migraine, depression', 'Raises serotonin and noradrenaline; sedating.', TCA_TIPS),
  i('clomipramine', 'Depression and OCD', 'Raises serotonin and noradrenaline.', TCA_TIPS),
  i('doxepin', 'Depression, anxiety, sleep', 'Raises serotonin and noradrenaline; sedating.', TCA_TIPS),
  i('lithium', 'Bipolar disorder', 'Steadies mood signalling in the brain.',
    ['Needs regular blood level checks.', 'Drink enough water; dehydration raises levels.']),
  i('bupropion', 'Depression; helps stop smoking', 'Raises dopamine and noradrenaline.',
    [T_MORNING, T_ALCOHOL]),

  // ── Antipsychotics ──────────────────────────────────────────────────────────────────────────
  i('haloperidol', 'Psychosis, severe agitation, delirium', 'Blocks dopamine in the brain.', AP_TIPS),
  i('chlorpromazine', 'Psychosis, severe agitation', 'Blocks dopamine in the brain.', AP_TIPS),
  i('thioridazine', 'Schizophrenia (rarely used now)', 'Blocks dopamine in the brain.', AP_TIPS),
  i('pimozide', 'Tourette\'s and some psychoses', 'Blocks dopamine in the brain.', AP_TIPS),
  i('sulpiride', 'Schizophrenia, sometimes dizziness', 'Blocks dopamine in the brain.', AP_TIPS),
  i('levomepromazine', 'Psychosis, pain and nausea in palliative care', 'Blocks dopamine; strongly sedating.',
    AP_TIPS),
  i('quetiapine', 'Schizophrenia, bipolar, sometimes sleep', 'Blocks dopamine and serotonin.', AP_TIPS),
  i('olanzapine', 'Schizophrenia and bipolar', 'Blocks dopamine and serotonin.',
    [T_DROWSY, 'Can increase appetite and weight.']),
  i('risperidone', 'Schizophrenia, bipolar, agitation', 'Blocks dopamine and serotonin.', AP_TIPS),
  i('ziprasidone', 'Schizophrenia and bipolar', 'Blocks dopamine and serotonin.',
    ['Take with a meal so it is absorbed.', T_ECG]),
  i('amisulpride', 'Schizophrenia', 'Blocks dopamine in the brain.', AP_TIPS),
  i('aripiprazole', 'Schizophrenia, bipolar, add-on for depression', 'Balances dopamine signalling.',
    [T_NO_STOP]),
  i('clozapine', 'Schizophrenia when others failed', 'Blocks dopamine and serotonin.',
    ['Needs regular blood counts.', T_NO_STOP]),
  i('paliperidone', 'Schizophrenia', 'Blocks dopamine and serotonin.', AP_TIPS),

  // ── Heart rhythm and heart medicines ────────────────────────────────────────────────────────
  i('amiodarone', 'Serious heart rhythm problems', 'Slows electrical signals in the heart.',
    [T_SUN, 'Needs thyroid, liver and lung checks.', T_ECG]),
  i('sotalol', 'Heart rhythm problems', 'Beta blocker that also lengthens the heart\'s recharge time.', AA_TIPS),
  i('dronedarone', 'Atrial fibrillation', 'Slows electrical signals in the heart.', [T_GRAPEFRUIT, T_ECG]),
  i('flecainide', 'Fast heart rhythms', 'Slows the spread of the heart\'s electrical signal.', AA_TIPS),
  i('quinidine', 'Heart rhythm problems', 'Slows electrical signals in the heart.', AA_TIPS),
  i('procainamide', 'Heart rhythm problems', 'Slows electrical signals in the heart.', [T_HOSPITAL]),
  i('disopyramide', 'Heart rhythm problems', 'Slows electrical signals in the heart.', AA_TIPS),
  i('dofetilide', 'Atrial fibrillation', 'Lengthens the heart\'s recharge time.', [T_HOSPITAL, T_ECG]),
  i('ibutilide', 'Converting atrial fibrillation', 'Lengthens the heart\'s recharge time.', [T_HOSPITAL]),
  i('ivabradine', 'Angina and heart failure', 'Slows the heart\'s natural pacemaker.',
    ['Can cause brief flashes of light in vision.', T_GRAPEFRUIT]),
  i('ranolazine', 'Chronic angina', 'Helps heart muscle use energy under strain.', [T_GRAPEFRUIT]),
  i('cilostazol', 'Leg pain when walking (claudication)', 'Widens leg arteries and thins platelets.',
    ['Take 30 minutes before or 2 hours after food.', T_GRAPEFRUIT]),
  i('diltiazem', 'High blood pressure, angina, rhythm control', 'Relaxes blood vessels and slows the heart.',
    [T_DIZZY, T_GRAPEFRUIT]),
  i('verapamil', 'High blood pressure, angina, rhythm control', 'Relaxes blood vessels and slows the heart.',
    [T_DIZZY, T_GRAPEFRUIT]),

  // ── Diuretics ───────────────────────────────────────────────────────────────────────────────
  i('furosemide', 'Fluid build-up, heart failure', 'Makes the kidneys pass more water and salt.', DIURETIC_TIPS),
  i('torasemide', 'Fluid build-up, high blood pressure', 'Makes the kidneys pass more water and salt.',
    DIURETIC_TIPS),
  i('hydrochlorothiazide', 'High blood pressure', 'Makes the kidneys pass more water and salt.', DIURETIC_TIPS),
  i('indapamide', 'High blood pressure', 'Makes the kidneys pass more water and salt.', DIURETIC_TIPS),

  // ── Antihistamines, sleep ───────────────────────────────────────────────────────────────────
  i('hydroxyzine', 'Anxiety, itching, sleep', 'Blocks histamine; calming.', AH_SEDATING_TIPS),
  i('diphenhydramine', 'Allergy, itching, sleep aid', 'Blocks histamine; sedating.',
    [T_DROWSY, 'Found in many night-time cold remedies.']),

  // ── Pain, opioids, anaesthesia ──────────────────────────────────────────────────────────────
  i('methadone', 'Opioid addiction treatment, severe pain', 'Acts on opioid receptors for a long time.',
    [T_ECG, T_DROWSY, T_ALCOHOL]),
  i('tramadol', 'Moderate to severe pain', 'Acts on opioid receptors and raises serotonin.', OPIOID_TIPS),
  i('buprenorphine', 'Severe pain, opioid addiction treatment', 'Partly activates opioid receptors.', OPIOID_TIPS),
  i('propofol', 'General anaesthesia and sedation', 'Puts you to sleep quickly for a procedure.',
    ANAESTHESIA_TIPS),
  i('sevoflurane', 'General anaesthesia', 'Inhaled gas that keeps you asleep during surgery.', ANAESTHESIA_TIPS),

  // ── Other ───────────────────────────────────────────────────────────────────────────────────
  i('donepezil', 'Alzheimer\'s dementia', 'Boosts acetylcholine, a memory messenger.',
    ['Usually taken at bedtime.', 'Can slow the heart rate.']),
  i('tacrolimus', 'Preventing transplant rejection', 'Calms the immune system.',
    ['Needs regular blood level checks.', T_GRAPEFRUIT]),
  i('tamoxifen', 'Breast cancer treatment and prevention', 'Blocks oestrogen in breast tissue.',
    ['Usually taken for several years.']),
  i('tizanidine', 'Muscle stiffness and spasms', 'Calms nerve signals to muscles.', [T_DROWSY, T_DIZZY]),
  i('solifenacin', 'Overactive bladder', 'Relaxes the bladder muscle.', OAB_TIPS),
  i('tolterodine', 'Overactive bladder', 'Relaxes the bladder muscle.', OAB_TIPS),
  i('mirabegron', 'Overactive bladder', 'Relaxes the bladder so it holds more.',
    ['Can raise blood pressure; check it regularly.']),
  i('atomoxetine', 'ADHD', 'Raises noradrenaline (not a stimulant).',
    ['Can raise heart rate slightly.', T_WEEKS]),
  i('ritonavir', 'HIV; boosts other antivirals', 'Blocks the enzyme that breaks many drugs down.',
    ['Interacts with many medicines - always show your list.']),

  // ── Asthma and stimulants ───────────────────────────────────────────────────────────────────
  i('salbutamol', 'Asthma and COPD attacks (reliever)', 'Opens the airways quickly.', BETA2_TIPS),
  i('salmeterol', 'Asthma and COPD (long-acting)', 'Keeps airways open for 12 hours.', BETA2_TIPS),
  i('terbutaline', 'Asthma attacks (reliever)', 'Opens the airways quickly.', BETA2_TIPS),
  i('pseudoephedrine', 'Blocked nose from colds', 'Narrows blood vessels in the nose.', DECONGESTANT_TIPS),
  i('phenylephrine', 'Blocked nose from colds', 'Narrows blood vessels in the nose.', DECONGESTANT_TIPS),
  i('ephedrine', 'Low blood pressure in anaesthesia; congestion', 'Stimulates adrenaline receptors.',
    [T_STIM]),
  i('adrenaline', 'Severe allergic reaction (anaphylaxis)', 'Raises blood pressure and opens airways.',
    ['In anaphylaxis, use it and call the emergency number.']),
  i('methylphenidate', 'ADHD', 'Raises dopamine and noradrenaline.', ADHD_STIM_TIPS),
  i('amphetamine', 'ADHD', 'Releases dopamine and noradrenaline.', ADHD_STIM_TIPS),

  // ── Painkillers ─────────────────────────────────────────────────────────────────────────────
  i('paracetamol', 'Pain and fever', 'Lowers pain signals and fever in the brain.',
    ['Check other products for paracetamol so you do not double up.', 'Keep below the daily maximum.']),
  i('ibuprofen', 'Pain, fever, inflammation', 'Blocks the enzymes that cause inflammation.', NSAID_TIPS),
  i('naproxen', 'Pain and inflammation', 'Blocks the enzymes that cause inflammation.', NSAID_TIPS),
  i('metamizole', 'Strong pain and fever', 'Lowers pain signals and fever.',
    ['Rarely lowers white blood cells - report fever or sore throat.']),
  i('aspirin', 'Pain; low dose to prevent clots', 'Blocks inflammation and makes platelets less sticky.',
    [T_FOOD, T_STOMACH]),

  // ── Safer antibiotics ───────────────────────────────────────────────────────────────────────
  i('amoxicillin', 'Chest, ear, throat and urinary infections', 'Breaks down bacterial cell walls.', PEN_TIPS),
  i('cefuroxime', 'Chest, ear, throat and urinary infections', 'Breaks down bacterial cell walls.', CEPH_TIPS),
  i('cefalexin', 'Skin and urinary infections', 'Breaks down bacterial cell walls.', CEPH_TIPS),
  i('doxycycline', 'Chest infections, acne, Lyme disease', 'Stops bacteria making proteins.',
    [T_SUN, 'Take with a full glass of water, sitting up.', T_COURSE]),
  i('nitrofurantoin', 'Bladder infections', 'Damages bacteria in the urine.',
    ['Take with food.', 'Can turn urine dark yellow - harmless.']),

  // ── Antihistamines (non-sedating) ───────────────────────────────────────────────────────────
  i('cetirizine', 'Hay fever, hives, allergies', 'Blocks histamine.', AH_TIPS),
  i('levocetirizine', 'Hay fever, hives, allergies', 'Blocks histamine.', AH_TIPS),
  i('loratadine', 'Hay fever, hives, allergies', 'Blocks histamine.', AH_TIPS),
  i('desloratadine', 'Hay fever, hives, allergies', 'Blocks histamine.', AH_TIPS),
  i('fexofenadine', 'Hay fever, hives, allergies', 'Blocks histamine.',
    ['Avoid fruit juice within 4 hours - it lowers absorption.']),

  // ── Beta blockers and LQTS-friendly heart medicines ─────────────────────────────────────────
  i('nadolol', 'Long QT protection, blood pressure, angina',
    'Blocks adrenaline so the heart beats slower and steadier.', BETA_TIPS),
  i('propranolol', 'Long QT, blood pressure, tremor, migraine',
    'Blocks adrenaline so the heart beats slower and steadier.', [T_BB_DAILY, T_BB_STOP, T_SUGAR]),
  i('bisoprolol', 'High blood pressure, heart failure', 'Blocks adrenaline at the heart.', BETA_TIPS),
  i('metoprolol', 'High blood pressure, angina, rhythm', 'Blocks adrenaline at the heart.', BETA_TIPS),
  i('atenolol', 'High blood pressure, angina', 'Blocks adrenaline at the heart.', BETA_TIPS),
  i('mexiletine', 'Long QT type 3, some rhythm problems', 'Blocks the late sodium current in heart cells.',
    [T_FOOD, T_ECG]),
  i('spironolactone', 'Heart failure, fluid, high blood pressure', 'Passes water but keeps potassium.',
    ['Avoid potassium supplements unless prescribed.']),
  i('amlodipine', 'High blood pressure, angina', 'Relaxes and widens blood vessels.',
    ['Ankle swelling is a common side effect.']),
  i('ramipril', 'High blood pressure, heart protection', 'Relaxes blood vessels.', ACE_TIPS),
  i('lisinopril', 'High blood pressure, heart failure', 'Relaxes blood vessels.', ACE_TIPS),
  i('losartan', 'High blood pressure, kidney protection', 'Blocks a hormone that narrows vessels.', [T_DIZZY]),
  i('atorvastatin', 'High cholesterol', 'Lowers cholesterol made by the liver.', STATIN_TIPS),
  i('rosuvastatin', 'High cholesterol', 'Lowers cholesterol made by the liver.', STATIN_TIPS),
  i('metformin', 'Type 2 diabetes', 'Lowers sugar made by the liver.', [T_FOOD, T_ALCOHOL]),
  i('levothyroxine', 'Underactive thyroid', 'Replaces thyroid hormone.',
    [T_EMPTY, 'Keep 4 hours apart from iron, calcium or antacids.']),
  i('montelukast', 'Asthma prevention, hay fever', 'Blocks leukotrienes that narrow airways.',
    ['Usually taken in the evening.', 'Report mood or sleep changes.']),
  i('budesonide', 'Asthma prevention; some gut conditions', 'Calms inflammation (a steroid).',
    ['Rinse your mouth after inhaling.', 'Use daily, even when well.']),
  i('potassium', 'Low potassium', 'Tops up potassium, which steadies heart rhythm.', SUPPLEMENT_TIPS),
  i('magnesium', 'Low magnesium, cramps', 'Tops up magnesium, which steadies heart rhythm.', SUPPLEMENT_TIPS),
  i('grapefruit', 'A fruit and juice, not a medicine', 'Blocks an enzyme (CYP3A4) that clears many medicines.',
    ['Can raise the level of some medicines for a day or more.', 'Ask your pharmacist if it mixes with yours.'])
];

const BY_INGREDIENT: Map<string, DrugInfo> = new Map<string, DrugInfo>();
for (const e of DRUG_INFO) {
  BY_INGREDIENT.set(e.ingredient, e);
}

export function drugInfo(ingredient: string): DrugInfo | undefined {
  return BY_INGREDIENT.get(ingredient.trim().toLowerCase());
}
