// Fixed long QT facts for the full emergency card (DESIGN.md §11, "For first responders" v3): the clinician
// protocol, the torsades list, genotype notes and the "About long QT" reference. Static and English; no LLM text
// and no network. Drug names only, never doses.
//
// Sources (as cited in the lqts-domain skill): ESC 2022 guideline on ventricular arrhythmias and sudden cardiac
// death; ERC 2021 resuscitation guidelines (CPR, AED, torsades); CredibleMeds QTdrugs lists; Schwartz et al.
// genotype-phenotype work for triggers and Moss et al. (1995) for the ECG T-wave patterns. The "do not use" list
// for the clinician block is built from the drug dataset (emergency/Responder.ets doNotGive), not from this file.

import { Genotype } from '../model/Profile';

export interface ProtocolStep {
  step: string;     // the action, short
  detail: string;   // one sentence of why or how
}

export interface GenotypeFacts {
  genotype: Genotype;
  name: string;            // e.g. 'Long QT syndrome type 1 (LQT1)'
  gene: string;            // gene and channel, e.g. 'KCNQ1 gene, slow potassium channel (IKs)'
  share: string;           // share of genotyped cases, '' for unknown
  triggers: string[];
  ecg: string;             // typical T-wave pattern, '' for unknown
  treatment: string;
  emergencyNotes: string[];  // what a clinician should know for this type, shown in the protocol block
}

export const LQTS_OVERVIEW: string[] = [
  'Long QT syndrome (LQTS) is an inherited condition of the heart\'s electrical recharging. The QT interval on the ' +
    'ECG is longer than normal.',
  'A long QT raises the chance of torsades de pointes, a fast and chaotic rhythm. It can cause fainting, ' +
    'seizure-like episodes or cardiac arrest. About 1 in 2,000 people have LQTS.',
  'Many common medicines prolong the QT further, among them some antibiotics, anti-sickness medicines, ' +
    'antidepressants and antipsychotics. Low potassium or magnesium, fever and some triggers for each type add to ' +
    'the risk.'
];

export const GENERAL_PRECAUTIONS: string[] = [
  'Treat every QT-prolonging medicine as dangerous.',
  'Keep potassium and magnesium normal; vomiting, diarrhoea and diuretics lower them.',
  'Take the beta-blocker every day.',
  'Tell every doctor, dentist and pharmacist about long QT.',
  'Fainting, a seizure-like episode or palpitations with dizziness need urgent care.'
];

const LQT1: GenotypeFacts = {
  genotype: 'LQT1',
  name: 'Long QT syndrome type 1 (LQT1)',
  gene: 'KCNQ1 gene, slow potassium channel (IKs)',
  share: 'About 35-40% of genotyped cases',
  triggers: [
    'Exercise, especially swimming',
    'Sudden exertion or diving into cold water',
    'Adrenaline surges, such as fear or anger during activity'
  ],
  ecg: 'Broad-based T waves',
  treatment: 'Beta-blockers (nadolol or propranolol) protect well. An ICD for those at high risk.',
  emergencyNotes: [
    'Events typically happen during exercise or swimming. A swimming accident may be an arrhythmia.',
    'Adrenaline-driven: avoid catecholamines unless life-saving.',
    'Beta-blocker adherence matters most for this type.'
  ]
};

const LQT2: GenotypeFacts = {
  genotype: 'LQT2',
  name: 'Long QT syndrome type 2 (LQT2)',
  gene: 'KCNH2 (hERG) gene, rapid potassium channel (IKr)',
  share: 'About 30-35% of genotyped cases',
  triggers: [
    'Sudden loud noise, such as an alarm clock or a phone ringing',
    'Being startled or strong emotion',
    'The months after giving birth'
  ],
  ecg: 'Low, notched or double-humped T waves',
  treatment: 'Beta-blockers (nadolol preferred). Potassium kept high-normal. An ICD for those at high risk.',
  emergencyNotes: [
    'Most QT-prolonging drugs block the same channel: this type is very sensitive to them.',
    'Low potassium is dangerous. Correct it early.',
    'Keep the room calm and quiet. Avoid sudden alarms near the patient.'
  ]
};

const LQT3: GenotypeFacts = {
  genotype: 'LQT3',
  name: 'Long QT syndrome type 3 (LQT3)',
  gene: 'SCN5A gene, sodium channel (INa)',
  share: 'About 5-10% of genotyped cases',
  triggers: [
    'Rest and sleep, often at night',
    'Slow heart rate'
  ],
  ecg: 'Long flat ST segment with a late T wave',
  treatment: 'Beta-blockers, sometimes mexiletine. An ICD is often recommended.',
  emergencyNotes: [
    'Events typically happen at rest or during sleep, when the heart rate is slow.',
    'A slow heart rate makes it worse. Pacing to raise the rate helps.',
    'Mexiletine may be part of this person\'s treatment.'
  ]
};

const UNKNOWN: GenotypeFacts = {
  genotype: 'UNKNOWN',
  name: 'Long QT syndrome, type not known',
  gene: '',
  share: '',
  triggers: [
    'Exercise and swimming',
    'Sudden loud noise or strong emotion',
    'Rest and sleep with a slow heart rate',
    'Low potassium or magnesium, fever'
  ],
  ecg: '',
  treatment: 'Beta-blockers for most people, plus avoiding QT-prolonging medicines. An ICD for those at high risk.',
  emergencyNotes: [
    'Type not known: treat every trigger and every QT-prolonging drug as relevant.'
  ]
};

export const GENOTYPE_FACTS: GenotypeFacts[] = [LQT1, LQT2, LQT3, UNKNOWN];

export function genotypeFacts(g: Genotype): GenotypeFacts {
  switch (g) {
    case 'LQT1':
      return LQT1;
    case 'LQT2':
      return LQT2;
    case 'LQT3':
      return LQT3;
    default:
      return UNKNOWN;
  }
}

/**
 * Numbered steps for the person who arrives first, then the clinician. `emergencyNumber` is the local ambulance
 * number (common/EmergencyNumbers.ets).
 */
export function protocolSteps(emergencyNumber: string, hasIcd: boolean): ProtocolStep[] {
  const steps: ProtocolStep[] = [
    {
      step: 'Check response and breathing',
      detail: `Unresponsive and not breathing normally: call ${emergencyNumber} and start CPR.`
    },
    {
      step: 'Use an AED as soon as possible',
      detail: 'Defibrillation is safe in long QT and ends torsades de pointes or ventricular fibrillation.'
    }
  ];
  if (hasIcd) {
    steps.push({
      step: 'Has an implanted defibrillator (ICD)',
      detail: 'It may shock on its own. Still use an AED and CPR if the person stays unresponsive.'
    });
  }
  steps.push(
    {
      step: 'Record a 12-lead ECG',
      detail: 'Look for torsades de pointes and a long QTc. 500 ms or more is high risk.'
    },
    {
      step: 'Give IV magnesium sulfate for torsades',
      detail: 'First line, even when serum magnesium is normal.'
    },
    {
      step: 'Correct potassium and magnesium',
      detail: 'Keep both high-normal. Low potassium makes torsades much more likely.'
    },
    {
      step: 'Stop every QT-prolonging drug',
      detail: 'Check each drug before giving it. The "Do not give" list above is a starting point.'
    }
  );
  return steps;
}

export const TORSADES_INTRO: string = 'If the ECG shows torsades de pointes (polymorphic VT with a twisting axis):';

export const TORSADES_STEPS: string[] = [
  'IV magnesium sulfate.',
  'Unstable or pulseless: unsynchronised defibrillation.',
  'Potassium and magnesium to high-normal.',
  'Recurrent torsades: temporary overdrive pacing to raise the heart rate.',
  'Isoproterenol is for acquired long QT. In congenital long QT, only on a cardiologist\'s advice.'
];

// Fixed "do not use" lines for the clinician block. The full drug list is the dataset's doNotGive().
export const DO_NOT_USE: string[] = [
  'Amiodarone, sotalol, procainamide or other QT-prolonging antiarrhythmics.',
  'Ondansetron, droperidol or domperidone for nausea.',
  'Haloperidol or droperidol for agitation.',
  'Macrolide or fluoroquinolone antibiotics.',
  'Catecholamines, unless life-saving.'
];
