// Verified plain-language LQTS facts for the explain_condition tool (source: lqts-domain skill — ESC 2022
// ventricular arrhythmia guideline, CredibleMeds, Schwartz et al.). The model may only rephrase these.

import { Genotype } from '../model/Profile';

export const CONDITION_TOPICS: string[] = ['overview', 'genotype', 'triggers', 'sick_day', 'emergency', 'beta_blockers'];

const OVERVIEW: string =
  'Long QT syndrome (LQTS) is an inherited condition of the heart\'s electrical recharging. A longer QT interval on ' +
    'the ECG raises the chance of a fast, chaotic rhythm called torsades de pointes, which can cause fainting or ' +
    'cardiac arrest. It affects about 1 in 2,000 people. With beta-blockers, avoiding QT-prolonging medicines and ' +
    'keeping potassium and magnesium normal, most people live full lives.';

const TRIGGERS: string =
  'Common triggers: medicines that prolong the QT interval; low potassium or magnesium (often after vomiting, ' +
    'diarrhoea or diuretics); fever; and genotype-specific triggers — exercise and swimming for LQT1, sudden loud ' +
    'noises (like alarm clocks) and strong emotions for LQT2, and rest or sleep with a slow heart rate for LQT3.';

const SICK_DAY: string =
  'Sick-day rules: vomiting, diarrhoea, fever or not eating can lower potassium and magnesium and make the QT ' +
    'longer. Drink fluids with electrolytes, keep taking your beta-blocker, and contact your doctor early. Many ' +
    'anti-sickness medicines (for example ondansetron and domperidone) prolong the QT — check before taking any.';

const EMERGENCY: string =
  'Warning signs: fainting (especially during exercise, after a sudden noise, or in sleep), seizure-like episodes, ' +
    'or palpitations with dizziness. Call the emergency number straight away. Bystanders should start CPR if the ' +
    'person is unresponsive and not breathing normally, and use an AED (defibrillator) as soon as one is available.';

const BETA_BLOCKERS: string =
  'Beta-blockers (most often nadolol or propranolol) are the main treatment for LQTS. They lower the chance of ' +
    'dangerous rhythms, especially in LQT1 and LQT2. Missing doses is a well-known risk, so take them every day and ' +
    'never stop without talking to your cardiologist.';

function genotypeFacts(genotype: Genotype): string {
  switch (genotype) {
    case 'LQT1':
      return 'LQT1 (KCNQ1 gene, about 35-40% of genotyped cases): events are typically triggered by exercise, ' +
        'especially swimming. Beta-blockers protect well. Ask your cardiologist which activities are fine for you.';
    case 'LQT2':
      return 'LQT2 (KCNH2/hERG gene, about 30-35%): events are typically triggered by sudden loud noises such as ' +
        'alarm clocks or phones, and by strong emotions; the period after childbirth is also higher risk. Gentle ' +
        'alarms and keeping potassium normal help.';
    case 'LQT3':
      return 'LQT3 (SCN5A gene, about 5-10%): events are more likely at rest or during sleep, when the heart rate ' +
        'is slow. Treatment is individual; some patients receive mexiletine in addition to other therapy.';
    default:
      return 'Your genotype is not recorded. Without it, every known trigger should be treated as relevant: ' +
        'exercise, sudden noises, strong emotions and slow heart rate at rest.';
  }
}

export function conditionFacts(topic: string, genotype: Genotype): string {
  switch (topic) {
    case 'overview':
      return OVERVIEW;
    case 'genotype':
      return genotypeFacts(genotype);
    case 'triggers':
      return TRIGGERS;
    case 'sick_day':
      return SICK_DAY;
    case 'emergency':
      return EMERGENCY;
    case 'beta_blockers':
      return BETA_BLOCKERS;
    default:
      return OVERVIEW;
  }
}
