// Genotype trigger coach (F-39). Short, static tips keyed by LQTS genotype — no AI. Content follows published
// genotype–trigger patterns (Schwartz et al., Circulation 2001; HRS/EHRA/APHRS expert consensus 2013):
// LQT1 — exertion, especially swimming; LQT2 — sudden noise / emotional stress, postpartum; LQT3 — rest and sleep.

import { Genotype } from '../model/Profile';

export interface CoachTip {
  title: string;
  body: string;
}

function tip(title: string, body: string): CoachTip {
  const t: CoachTip = { title: title, body: body };
  return t;
}

const GENERAL: CoachTip[] = [
  tip('Check before you take', 'Antibiotics, anti-nausea and cold medicines are common QT risks. Check every new ' +
    'medicine here first.'),
  tip('Vomiting or diarrhoea?', 'Losing fluids lowers potassium and magnesium, which raises the risk. Drink, and ' +
    'call your doctor if it lasts.'),
  tip('Never skip the beta-blocker', 'Missed doses are a known cause of events. Set a reminder in Medicines.'),
  tip('Carry your card', 'Your emergency card works offline and as a QR code — show it at any ER.')
];

const BY_GENOTYPE: Map<Genotype, CoachTip[]> = new Map<Genotype, CoachTip[]>([
  ['LQT1', [
    tip('LQT1: exertion is your trigger', 'Warm up, avoid sudden all-out efforts and competitive sport unless ' +
      'your cardiologist has cleared it.'),
    tip('LQT1: never swim alone', 'Swimming is the classic LQT1 trigger. Swim with someone who knows about your ' +
      'condition.')
  ]],
  ['LQT2', [
    tip('LQT2: avoid sudden loud sounds', 'Use a gentle, gradually louder alarm and put the phone on silent at ' +
      'night. This app never plays sudden sounds.'),
    tip('LQT2: stress and startle', 'Sudden fright or anger can trigger events. Keep potassium in the normal ' +
      'range — ask about it at check-ups.')
  ]],
  ['LQT3', [
    tip('LQT3: rest and sleep', 'Events tend to happen at rest or asleep. Keep night-time heart monitoring on.'),
    tip('LQT3: ask about mexiletine', 'Some LQT3 patients benefit from it. Ask your cardiologist whether it suits ' +
      'you.')
  ]]
]);

export function tipsFor(genotype: Genotype): CoachTip[] {
  return (BY_GENOTYPE.get(genotype) ?? []).concat(GENERAL);
}

// One tip per day, stable for the whole day.
export function tipOfTheDay(genotype: Genotype, now: number): CoachTip {
  const tips: CoachTip[] = tipsFor(genotype);
  const day: number = Math.floor(now / 86400000);
  return tips[day % tips.length];
}
