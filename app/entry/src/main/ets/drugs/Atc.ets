// WHO Anatomical Therapeutic Chemical (ATC) classification — level 1 (anatomical main group) and level 2
// (therapeutic subgroup) names in English, from the public WHO Collaborating Centre ATC index (whocc.no).
// Used only to say "what kind of medicine" a scanned box is; never for safety decisions.

const LEVEL1: Map<string, string> = new Map<string, string>([
  ['A', 'Alimentary tract and metabolism'],
  ['B', 'Blood and blood forming organs'],
  ['C', 'Cardiovascular system'],
  ['D', 'Dermatologicals'],
  ['G', 'Genito-urinary system and sex hormones'],
  ['H', 'Systemic hormonal preparations'],
  ['J', 'Anti-infectives for systemic use'],
  ['L', 'Antineoplastic and immunomodulating agents'],
  ['M', 'Musculo-skeletal system'],
  ['N', 'Nervous system'],
  ['P', 'Antiparasitic products, insecticides and repellents'],
  ['R', 'Respiratory system'],
  ['S', 'Sensory organs'],
  ['V', 'Various']
]);

const LEVEL2: Map<string, string> = new Map<string, string>([
  ['A01', 'Stomatological preparations'],
  ['A02', 'Drugs for acid related disorders'],
  ['A03', 'Drugs for functional gastrointestinal disorders'],
  ['A04', 'Antiemetics and antinauseants'],
  ['A05', 'Bile and liver therapy'],
  ['A06', 'Drugs for constipation'],
  ['A07', 'Antidiarrheals, intestinal anti-inflammatory/anti-infective agents'],
  ['A08', 'Antiobesity preparations'],
  ['A09', 'Digestives, incl. enzymes'],
  ['A10', 'Drugs used in diabetes'],
  ['A11', 'Vitamins'],
  ['A12', 'Mineral supplements'],
  ['A14', 'Anabolic agents for systemic use'],
  ['A16', 'Other alimentary tract and metabolism products'],
  ['B01', 'Antithrombotic agents'],
  ['B02', 'Antihemorrhagics'],
  ['B03', 'Antianemic preparations'],
  ['B05', 'Blood substitutes and perfusion solutions'],
  ['B06', 'Other hematological agents'],
  ['C01', 'Cardiac therapy'],
  ['C02', 'Antihypertensives'],
  ['C03', 'Diuretics'],
  ['C04', 'Peripheral vasodilators'],
  ['C05', 'Vasoprotectives'],
  ['C07', 'Beta blocking agents'],
  ['C08', 'Calcium channel blockers'],
  ['C09', 'Agents acting on the renin-angiotensin system'],
  ['C10', 'Lipid modifying agents'],
  ['D01', 'Antifungals for dermatological use'],
  ['D02', 'Emollients and protectives'],
  ['D03', 'Preparations for treatment of wounds and ulcers'],
  ['D04', 'Antipruritics, incl. antihistamines, anesthetics, etc.'],
  ['D05', 'Antipsoriatics'],
  ['D06', 'Antibiotics and chemotherapeutics for dermatological use'],
  ['D07', 'Corticosteroids, dermatological preparations'],
  ['D08', 'Antiseptics and disinfectants'],
  ['D10', 'Anti-acne preparations'],
  ['D11', 'Other dermatological preparations'],
  ['G01', 'Gynecological antiinfectives and antiseptics'],
  ['G02', 'Other gynecologicals'],
  ['G03', 'Sex hormones and modulators of the genital system'],
  ['G04', 'Urologicals'],
  ['H01', 'Pituitary and hypothalamic hormones and analogues'],
  ['H02', 'Corticosteroids for systemic use'],
  ['H03', 'Thyroid therapy'],
  ['H04', 'Pancreatic hormones'],
  ['H05', 'Calcium homeostasis'],
  ['J01', 'Antibacterials for systemic use'],
  ['J02', 'Antimycotics for systemic use'],
  ['J04', 'Antimycobacterials'],
  ['J05', 'Antivirals for systemic use'],
  ['J06', 'Immune sera and immunoglobulins'],
  ['J07', 'Vaccines'],
  ['L01', 'Antineoplastic agents'],
  ['L02', 'Endocrine therapy'],
  ['L03', 'Immunostimulants'],
  ['L04', 'Immunosuppressants'],
  ['M01', 'Anti-inflammatory and antirheumatic products'],
  ['M02', 'Topical products for joint and muscular pain'],
  ['M03', 'Muscle relaxants'],
  ['M04', 'Antigout preparations'],
  ['M05', 'Drugs for treatment of bone diseases'],
  ['M09', 'Other drugs for disorders of the musculo-skeletal system'],
  ['N01', 'Anesthetics'],
  ['N02', 'Analgesics'],
  ['N03', 'Antiepileptics'],
  ['N04', 'Anti-parkinson drugs'],
  ['N05', 'Psycholeptics'],
  ['N06', 'Psychoanaleptics'],
  ['N07', 'Other nervous system drugs'],
  ['P01', 'Antiprotozoals'],
  ['P02', 'Anthelmintics'],
  ['P03', 'Ectoparasiticides, incl. scabicides, insecticides and repellents'],
  ['R01', 'Nasal preparations'],
  ['R02', 'Throat preparations'],
  ['R03', 'Drugs for obstructive airway diseases'],
  ['R05', 'Cough and cold preparations'],
  ['R06', 'Antihistamines for systemic use'],
  ['R07', 'Other respiratory system products'],
  ['S01', 'Ophthalmologicals'],
  ['S02', 'Otologicals'],
  ['S03', 'Ophthalmological and otological preparations'],
  ['V01', 'Allergens'],
  ['V03', 'All other therapeutic products'],
  ['V04', 'Diagnostic agents'],
  ['V06', 'General nutrients'],
  ['V07', 'All other non-therapeutic products'],
  ['V08', 'Contrast media'],
  ['V09', 'Diagnostic radiopharmaceuticals'],
  ['V10', 'Therapeutic radiopharmaceuticals']
]);

export function isAtcCode(code: string): boolean {
  return /^[A-Z]([0-9]{2}([A-Z]([A-Z]([0-9]{2})?)?)?)?$/.test(code);
}

// Most specific group name we know for an ATC code: level 2, else level 1, else ''.
export function atcGroup(code: string): string {
  const c: string = code.trim().toUpperCase();
  if (c.length === 0 || !isAtcCode(c)) {
    return '';
  }
  return LEVEL2.get(c.substring(0, 3)) ?? LEVEL1.get(c.substring(0, 1)) ?? '';
}

export function atcMain(code: string): string {
  const c: string = code.trim().toUpperCase();
  return c.length === 0 ? '' : (LEVEL1.get(c.substring(0, 1)) ?? '');
}

export function atcLevel2Codes(): string[] {
  return Array.from(LEVEL2.keys());
}
