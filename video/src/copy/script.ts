// Every on-screen line, with timings, in one place. Spoken lines live in vo.json, scene lengths in timeline.json.
// Product facts come from README.md's feature table; app copy is taken from the app's strings and data
// (DrugChecker.reasonFor, string.json, gtin_pl.json, card/data.js) and the v2 design (docs/design/v2,
// v2-watches). No em dashes (DESIGN §9). Frames are at 30 fps.
import timeline from './timeline.json';

export type SceneId = 'hook' | 'reveal' | 'ask' | 'verdict' | 'scan' | 'watch' | 'emergency' | 'trust' | 'end';

export interface SceneCopy {
  id: SceneId;
  kicker: string;
  lines: string[];
  caption?: string;
}

export const scenes: Record<SceneId, SceneCopy> = {
  hook: {
    id: 'hook',
    kicker: 'LONG QT SYNDROME',
    lines: ['1 in 2,000 people have Long QT syndrome.', 'Hundreds of everyday medicines can trigger it.'],
  },
  reveal: {
    id: 'reveal',
    kicker: 'MEET',
    lines: ['Celia.ai', 'A heart-safety companion you can talk to.'],
  },
  ask: {
    id: 'ask',
    kicker: 'ASK THE AGENT',
    lines: ['Just say what the doctor gave you.', 'It answers out loud, and shows its work.'],
  },
  verdict: {
    id: 'verdict',
    kicker: 'MEDICINE CHECK',
    lines: ['Verdicts come from fixed medical data.', 'The AI only explains.'],
    caption: 'Not a medical device. Always ask your doctor or pharmacist.',
  },
  scan: {
    id: 'scan',
    kicker: 'SCAN A BOX',
    lines: ['Scan any box.', '~68,000 Polish packs, offline.'],
  },
  watch: {
    id: 'watch',
    kicker: 'WATCH GUARD',
    lines: ['It watches your heart rate,', 'and checks in.'],
    caption: 'Heart rate only. Simulated scenario shown.',
  },
  emergency: {
    id: 'emergency',
    kicker: 'EMERGENCY',
    lines: ['If you can’t answer,', 'it speaks for you. In 13 languages.'],
  },
  trust: {
    id: 'trust',
    kicker: 'PRIVACY',
    lines: ['Your safety core runs on your phone.'],
  },
  end: {
    id: 'end',
    kicker: '',
    lines: ['Celia.ai', 'Know before you take it.'],
    caption: 'Not a medical device. Always ask your doctor or pharmacist.',
  },
};

// Scene lengths (frames) from timeline.json. Hero ≈ 74.5 s, vertical ≈ 29.9 s.
export const HERO_XFADE = timeline.hero.xfade;
export const heroOrder = timeline.hero.scenes as { id: SceneId; frames: number }[];
export const VERT_XFADE = timeline.vertical.xfade;
export const vertOrder = timeline.vertical.scenes as { id: SceneId; frames: number }[];

export const totalFrames = (order: { frames: number }[], xfade: number): number =>
  order.reduce((sum, s) => sum + s.frames, 0) - xfade * (order.length - 1);

// ---- In-app copy -------------------------------------------------------------------------------------------

export const chat = {
  user: 'The doctor gave me Klacid for a sinus infection.',
  toolRunning: 'Checking the QT list',
  toolDone: 'Checked the QT list',
  // v2 drawing 03, spoken by the agent (vo.json ask_agent).
  agent: "Klacid is clarithromycin. It's on the known-risk list, so please don't start it before you talk to your doctor.",
  orbLabels: {
    off: 'Tap to talk',
    listening: "I'm listening",
    hearing: 'Listening…',
    thinking: 'Checking the QT list…',
    speaking: 'Speaking',
  },
  dockHint: 'Tap the orb to mute',
  agentLine: 'Ask me about a medicine, a symptom or your heart.',
  starters: ['Can I take ibuprofen?', 'How was my heart this week?'],
  features: ['Scan a box', 'Log how I feel', 'Doctor visit', 'Trends'],
  details: 'Details',
  showConversation: 'Show conversation',
};

// Today (v2 01). Ola and her medicines are fictional.
export const today = {
  date: 'Saturday, 3 October',
  greeting: 'Good afternoon, Ola',
  genotype: 'LQT2',
  agentLine: 'Your 14:00 nadolol is due soon. Want me to log it with you?',
  nextDose: 'NEXT DOSE',
  allReminders: 'All reminders ›',
  doseName: 'Nadolol 40 mg',
  doseDue: 'Due at 14:00 · in 10 min',
  taken: 'Taken',
  resting: 'RESTING · 7 DAYS',
  restingNote: '64 avg · 2 lower than last week',
  restingBars: [60, 64, 62, 68, 63, 61, 72],
  actions: [
    { icon: 'scan', label: 'Scan a box' },
    { icon: 'tabHeart', label: 'Log how I feel' },
    { icon: 'plus', label: 'Doctor visit' },
    { icon: 'pill', label: 'Check a medicine' },
  ],
  medsChip: 'All 3 medicines checked',
  tabs: { today: 'Today', medicines: 'Medicines', talk: 'Talk', health: 'Health', emergency: 'Emergency' },
} as const;

export const verdict = {
  name: 'Klacid',
  ingredient: 'clarithromycin',
  // DrugChecker.reasonFor() for a Known-risk entry in class "Macrolide antibiotic".
  reason: 'Macrolide antibiotic. Prolongs the QT interval with a known risk of torsades de pointes.',
  alternativesLabel: 'Ask your doctor about',
  alternatives: 'amoxicillin · cefuroxime · doxycycline',
  howWeKnow: 'How we know',
  trace: ['klacid → clarithromycin', 'Listed: known risk of torsades', 'Bundled list · works offline'],
  confidence: '95%',
  askDoctor: 'Ask your doctor',
  addToMeds: 'Add to meds',
  source: 'CredibleMeds-derived list · Not a medical device. Always ask your doctor or pharmacist.',
  sourceShort: 'CredibleMeds-derived list · Not a medical device.',
};

// gtin_pl.json, URPL register snapshot 2026-10-03.
export const box = {
  gtin: '5909990331710',
  found: 'Found: clarithromycin',
  boxLabel: 'Clarithromycin',
  boxStrength: '125 mg / 5 ml',
  boxForm: 'Granules for oral suspension',
  about: [
    { k: 'Substance', v: 'clarithromycin' },
    { k: 'Strength', v: '125 mg / 5 ml' },
    { k: 'Form', v: 'Granules for oral suspension' },
    { k: 'Pack', v: '1 bottle 60 ml · Rx' },
    { k: 'ATC', v: 'J01FA09 · Macrolides' },
  ],
  register: 'Polish medicines register (URPL) · on the phone',
};

// Watch v2 (docs/design/v2-watches 1.1, 1.2, 7, 13.1).
export const watch = {
  calmLabel: 'All good',
  nearLabel: 'Near your max',
  aboveLabel: 'Above your max',
  context: 'At rest · max 110',
  chips: ['LQT2', 'Phone ✓'],
  demo: 'DEMO DATA',
  alertTitle: 'HEART RATE HIGH',
  alertSub: 'bpm · at rest',
  alertLimit: 'Limit 110 · LQT2 at rest',
  ok: "I'm OK",
  help: 'Need help',
  sosSent: 'SOS sent',
  sosSentSub: 'Your phone is alerting your contacts.',
  bystander: 'I have Long QT syndrome. Call 112.',
  done: 'Done',
  checkInFrom: '14:32 · from your watch',
  checkInChipTitle: 'High for resting',
  checkInQuestion: 'Your heart rate jumped to 165 while resting. Are you OK?',
  fine: "I'm fine",
  dizzy: 'I feel dizzy',
  callHelp: 'Call for help',
  checkAgain: "If I don't hear back, I'll check again in 2 minutes.",
};

export const sos = {
  label: 'EMERGENCY',
  title: 'Are you OK?',
  sub: 'Sending SOS to your contacts',
  tab: {
    title: 'Emergency',
    start: 'Start SOS',
    startSub: '30 s countdown, you can cancel',
    call: 'Call',
    number: '112',
    responderCaps: 'FOR THE PERSON HELPING ME',
    responder: 'Show responder view',
    responderSub: 'Big text, what to do, what to avoid',
    cardCaps: 'MEDICAL CARD',
    open: 'Open ›',
    cardTitle: 'Long QT syndrome, type 2',
    cardFacts: 'Nadolol 40 mg · No ICD · Avoid QT drugs',
    cardInside: 'Inside: languages, read aloud, QR, share',
  },
  imOk: "I'm OK",
  sendNow: 'Send now',
  qrTitle: 'Emergency card',
  qrSub: 'Any phone camera opens it, in the reader’s language.',
};

// Fictional patient. Card text from site/card/data.js (pl).
export const card = {
  patient: 'Ola Nowak',
  languages: ['English', 'Polski', 'Български', 'Deutsch', 'Français', 'Español', 'Italiano', 'Українська',
    'Română', 'Čeština', 'Nederlands', 'Português', 'Türkçe'],
  pl: {
    title: 'ALERT MEDYCZNY',
    condition: 'Zespół długiego QT (LQTS) - wrodzone zaburzenie rytmu serca',
    genotype: 'Genotyp LQT2',
    icd: 'Brak wszczepionego defibrylatora',
    avoid: 'NIE podawać leków wydłużających QT (np. ondansetron, antybiotyki makrolidowe lub chinolony, haloperydol, metadon).',
    call: 'Zadzwoń 112 · Polska',
    meds: 'Aktualne leki',
    medsValue: 'nadolol 40 mg',
    contact: 'Mama (ICE)',
    footer: 'Zaszyfrowane na telefonie właściciela.',
  },
};

export const ledger = {
  title: 'What left my phone',
  sub: 'Field names and sizes. Never values.',
  rows: [
    { time: '14:05', endpoint: '/drug-check', fields: 'query', size: '64 B' },
    { time: '14:05', endpoint: '/agent', fields: 'condition, genotype, meds, messages', size: '1.8 KB' },
    { time: '14:32', endpoint: 'watch metrics', fields: 'device_id, hr, ts', size: '212 B' },
    { time: '14:33', endpoint: '/share', fields: 'card (encrypted)', size: '2.4 KB' },
  ],
  never: 'Never uploaded in the clear: name, phone numbers, contacts, notes.',
  badges: ['ON-DEVICE', 'OFFLINE CORE', '211 TESTS'],
};

export const endCard = {
  wordmark: 'Celia',
  wordmarkDot: '.ai',
  tagline: 'Know before you take it.',
  built: 'Built natively on HarmonyOS',
  event: 'HackYeah 2026',
  url: '',
};
