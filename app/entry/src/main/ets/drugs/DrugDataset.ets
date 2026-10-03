// Curated LQTS drug dataset, bundled in the app so drug checks work offline.
//
// Risk categories follow the public CredibleMeds QTdrugs lists (crediblemeds.org): Known Risk of TdP,
// Possible Risk, Conditional Risk, plus the "Drugs to Avoid in Congenital Long QT" list (adrenergic
// stimulants). Brand names: public national medicine registers (URPL for Poland, BDA for Bulgaria) and
// common EU brands. CYP data: public drug-interaction tables (FDA "Drug Development and Drug
// Interactions"). This is a demo subset for decision support, not a complete list — verify before relying
// on it. Generic names are listed in English, Polish and Bulgarian (Cyrillic) where they differ.
//
// Rules checked by test/DrugData.test.ets: every alias maps to exactly one ingredient, every alternative is
// itself in the dataset and NOT_LISTED.

import { RiskLevel } from '../model/DrugVerdict';

export const DATA_SOURCE: string = 'CredibleMeds QTdrugs categories (crediblemeds.org), curated demo subset';

export interface DrugEntry {
  ingredient: string;        // INN, lower case — the canonical key
  risk: RiskLevel;           // never UNKNOWN_DRUG here
  drugClass: string;         // short, human readable
  aliases: string[];         // brands + other-language generic names, lower case
  cypSubstrate: string[];    // enzymes that clear this drug, e.g. ['CYP3A4']
  cypInhibitor: string[];    // enzymes this drug strongly/moderately inhibits
  alternatives: string[];    // NOT_LISTED ingredients from the same use, to ask the doctor about
  avoidCongenital: boolean;  // on the "avoid in congenital long QT" list
}

function d(ingredient: string, risk: RiskLevel, drugClass: string, aliases: string[], cypSubstrate: string[],
  cypInhibitor: string[], alternatives: string[], avoidCongenital: boolean): DrugEntry {
  const e: DrugEntry = {
    ingredient: ingredient,
    risk: risk,
    drugClass: drugClass,
    aliases: aliases,
    cypSubstrate: cypSubstrate,
    cypInhibitor: cypInhibitor,
    alternatives: alternatives,
    avoidCongenital: avoidCongenital
  };
  return e;
}

const KR: RiskLevel = 'KNOWN_RISK';
const PR: RiskLevel = 'POSSIBLE_RISK';
const CR: RiskLevel = 'CONDITIONAL_RISK';
const NL: RiskLevel = 'NOT_LISTED';
const NONE: string[] = [];
const ANTIBIOTIC_ALTS: string[] = ['amoxicillin', 'cefuroxime', 'doxycycline'];
const ANTIHISTAMINE_ALTS: string[] = ['cetirizine', 'loratadine', 'fexofenadine'];

export const DRUGS: DrugEntry[] = [
  // ── Antibiotics: macrolides and fluoroquinolones ─────────────────────────────────────────────
  d('clarithromycin', KR, 'Macrolide antibiotic',
    ['klacid', 'fromilid', 'klaritromycyna', 'кларитромицин', 'клацид', 'фромилид'],
    ['CYP3A4'], ['CYP3A4'], ANTIBIOTIC_ALTS, false),
  d('azithromycin', KR, 'Macrolide antibiotic',
    ['sumamed', 'azitrox', 'azycyna', 'zithromax', 'azytromycyna', 'азитромицин', 'сумамед', 'зитромакс'],
    NONE, NONE, ANTIBIOTIC_ALTS, false),
  d('erythromycin', KR, 'Macrolide antibiotic', ['erytromycyna', 'еритромицин'],
    ['CYP3A4'], ['CYP3A4'], ANTIBIOTIC_ALTS, false),
  d('roxithromycin', KR, 'Macrolide antibiotic', ['rulid', 'roksytromycyna', 'рокситромицин'],
    ['CYP3A4'], NONE, ANTIBIOTIC_ALTS, false),
  d('ciprofloxacin', KR, 'Fluoroquinolone antibiotic',
    ['cipro', 'ciprinol', 'cipronex', 'ciprobay', 'cyprofloksacyna', 'ципрофлоксацин', 'ципринол'],
    NONE, ['CYP1A2'], ANTIBIOTIC_ALTS, false),
  d('levofloxacin', KR, 'Fluoroquinolone antibiotic',
    ['tavanic', 'levoxa', 'lewofloksacyna', 'левофлоксацин', 'таваник'], NONE, NONE, ANTIBIOTIC_ALTS, false),
  d('moxifloxacin', KR, 'Fluoroquinolone antibiotic',
    ['avelox', 'moksifloksacyna', 'моксифлоксацин', 'авелокс'], NONE, NONE, ANTIBIOTIC_ALTS, false),
  d('ofloxacin', PR, 'Fluoroquinolone antibiotic', ['tarivid', 'ofloksacyna', 'офлоксацин'],
    NONE, NONE, ANTIBIOTIC_ALTS, false),
  d('norfloxacin', PR, 'Fluoroquinolone antibiotic', ['norfloksacyna', 'норфлоксацин'],
    NONE, NONE, ANTIBIOTIC_ALTS, false),
  d('metronidazole', CR, 'Antibiotic / antiprotozoal', ['metronidazol', 'flagyl', 'метронидазол'],
    NONE, NONE, NONE, false),

  // ── Antifungals ───────────────────────────────────────────────────────────────────────────────
  d('fluconazole', KR, 'Azole antifungal', ['diflucan', 'flukonazol', 'flumycon', 'флуконазол', 'дифлукан'],
    NONE, ['CYP3A4', 'CYP2C9'], NONE, false),
  d('ketoconazole', CR, 'Azole antifungal', ['ketokonazol', 'кетоконазол'], ['CYP3A4'], ['CYP3A4'], NONE, false),
  d('itraconazole', CR, 'Azole antifungal', ['orungal', 'itrakonazol', 'итраконазол'],
    ['CYP3A4'], ['CYP3A4'], NONE, false),
  d('voriconazole', CR, 'Azole antifungal', ['vfend', 'worykonazol', 'вориконазол'],
    ['CYP2C19', 'CYP3A4'], ['CYP3A4'], NONE, false),
  d('posaconazole', CR, 'Azole antifungal', ['noxafil', 'pozakonazol', 'позаконазол'], NONE, ['CYP3A4'], NONE, false),

  // ── Antimalarials / antiprotozoals ────────────────────────────────────────────────────────────
  d('hydroxychloroquine', KR, 'Antimalarial / antirheumatic', ['plaquenil', 'arechin', 'hydroksychlorochina',
    'хидроксихлорохин'], ['CYP2D6', 'CYP3A4'], NONE, NONE, false),
  d('chloroquine', KR, 'Antimalarial', ['chlorochina', 'хлорохин'], ['CYP2D6', 'CYP3A4'], NONE, NONE, false),
  d('quinine', CR, 'Antimalarial', ['chinina', 'хинин'], ['CYP3A4'], NONE, NONE, false),
  d('pentamidine', KR, 'Antiprotozoal', ['pentamidyna', 'пентамидин'], NONE, NONE, NONE, false),

  // ── Antiemetics and gut motility ──────────────────────────────────────────────────────────────
  d('ondansetron', KR, 'Antiemetic (5-HT3 antagonist)', ['zofran', 'atossa', 'ondansetronum', 'ондансетрон',
    'зофран'], ['CYP3A4', 'CYP2D6'], NONE, NONE, false),
  d('granisetron', PR, 'Antiemetic (5-HT3 antagonist)', ['kytril', 'granisetronum', 'гранисетрон'],
    ['CYP3A4'], NONE, NONE, false),
  d('dolasetron', PR, 'Antiemetic (5-HT3 antagonist)', ['anzemet', 'доласетрон'], NONE, NONE, NONE, false),
  d('domperidone', KR, 'Antiemetic / prokinetic', ['motilium', 'domperidon', 'домперидон',
    'мотилиум'], ['CYP3A4'], NONE, NONE, false),
  d('metoclopramide', CR, 'Antiemetic / prokinetic', ['metoclopramidum', 'metoklopramid', 'reglan',
    'метоклопрамид', 'реглан'], ['CYP2D6'], NONE, NONE, false),
  d('droperidol', KR, 'Antiemetic / antipsychotic', ['droperydol', 'дроперидол'], NONE, NONE, NONE, false),
  d('promethazine', PR, 'Antihistamine / antiemetic', ['diphergan', 'prometazyna', 'прометазин'],
    ['CYP2D6'], NONE, ANTIHISTAMINE_ALTS, false),
  d('loperamide', CR, 'Antidiarrhoeal', ['imodium', 'stoperan', 'laremid', 'loperamid', 'лоперамид', 'имодиум'],
    ['CYP3A4'], NONE, NONE, false),

  // ── Acid reducers (risk via low magnesium) ───────────────────────────────────────────────────
  d('omeprazole', CR, 'Proton pump inhibitor', ['polprazol', 'helicid', 'losec', 'bioprazol', 'omeprazol',
    'омепразол', 'лосек'], ['CYP2C19', 'CYP3A4'], NONE, NONE, false),
  d('esomeprazole', CR, 'Proton pump inhibitor', ['nexium', 'emanera', 'esomeprazol', 'езомепразол', 'нексиум'],
    ['CYP2C19'], NONE, NONE, false),
  d('pantoprazole', CR, 'Proton pump inhibitor', ['controloc', 'nolpaza', 'anesteloc', 'pantoprazol',
    'пантопразол', 'контролок', 'нолпаза'], ['CYP2C19'], NONE, NONE, false),
  d('lansoprazole', CR, 'Proton pump inhibitor', ['lanzul', 'lansoprazol', 'лансопразол'],
    ['CYP2C19'], NONE, NONE, false),
  d('famotidine', CR, 'H2 blocker', ['quamatel', 'famotydyna', 'фамотидин', 'квамател'], NONE, NONE, NONE, false),

  // ── Antidepressants ───────────────────────────────────────────────────────────────────────────
  d('citalopram', KR, 'SSRI antidepressant', ['cipramil', 'citaxin', 'cytalopram', 'циталопрам'],
    ['CYP2C19', 'CYP3A4'], NONE, NONE, false),
  d('escitalopram', KR, 'SSRI antidepressant', ['cipralex', 'lexapro', 'elicea', 'escitalopramum',
    'есциталопрам', 'ципралекс'], ['CYP2C19', 'CYP3A4'], NONE, NONE, false),
  d('fluoxetine', CR, 'SSRI antidepressant', ['prozac', 'seronil', 'bioxetin', 'fluoksetyna', 'флуоксетин',
    'прозак'], ['CYP2D6'], ['CYP2D6'], NONE, false),
  d('paroxetine', CR, 'SSRI antidepressant', ['seroxat', 'rexetin', 'paroksetyna', 'пароксетин'],
    ['CYP2D6'], ['CYP2D6'], NONE, false),
  d('sertraline', CR, 'SSRI antidepressant', ['zoloft', 'asertin', 'sertralina', 'сертралин', 'золофт'],
    ['CYP2C19'], NONE, NONE, false),
  d('fluvoxamine', CR, 'SSRI antidepressant', ['fevarin', 'fluwoksamina', 'флувоксамин'],
    NONE, ['CYP1A2', 'CYP2C19'], NONE, false),
  d('venlafaxine', PR, 'SNRI antidepressant', ['efectin', 'velaxin', 'wenlafaksyna', 'венлафаксин'],
    ['CYP2D6'], NONE, NONE, false),
  d('mirtazapine', PR, 'Antidepressant', ['remeron', 'mirzaten', 'mirtazapina', 'миртазапин'],
    ['CYP3A4', 'CYP2D6'], NONE, NONE, false),
  d('trazodone', CR, 'Antidepressant', ['trittico', 'trazodon', 'тразодон', 'тритико'], ['CYP3A4'], NONE, NONE, false),
  d('amitriptyline', CR, 'Tricyclic antidepressant', ['amitryptylina', 'amitriptylinum', 'амитриптилин'],
    ['CYP2D6'], NONE, NONE, false),
  d('clomipramine', CR, 'Tricyclic antidepressant', ['anafranil', 'klomipramina', 'кломипрамин'],
    ['CYP2D6'], NONE, NONE, false),
  d('doxepin', CR, 'Tricyclic antidepressant', ['doksepina', 'доксепин'], ['CYP2D6'], NONE, NONE, false),
  d('lithium', PR, 'Mood stabiliser', ['litium', 'литий'], NONE, NONE, NONE, false),
  d('bupropion', NL, 'Antidepressant', ['wellbutrin', 'elontril', 'бупропион'],
    NONE, ['CYP2D6'], NONE, false),

  // ── Antipsychotics ────────────────────────────────────────────────────────────────────────────
  d('haloperidol', KR, 'Antipsychotic', ['haldol', 'haloperidolum', 'халоперидол'],
    ['CYP3A4', 'CYP2D6'], NONE, NONE, false),
  d('chlorpromazine', KR, 'Antipsychotic', ['fenactil', 'chlorpromazyna', 'хлорпромазин'],
    ['CYP2D6'], NONE, NONE, false),
  d('thioridazine', KR, 'Antipsychotic', ['tiorydazyna', 'тиоридазин'], ['CYP2D6'], NONE, NONE, false),
  d('pimozide', KR, 'Antipsychotic', ['orap', 'pimozyd', 'пимозид'], ['CYP3A4'], NONE, NONE, false),
  d('sulpiride', KR, 'Antipsychotic', ['dogmatil', 'sulpiryd', 'сулпирид'], NONE, NONE, NONE, false),
  d('levomepromazine', KR, 'Antipsychotic', ['tisercin', 'lewomepromazyna', 'левомепромазин'],
    NONE, NONE, NONE, false),
  d('quetiapine', CR, 'Antipsychotic', ['seroquel', 'ketrel', 'kventiax', 'kwetiapina', 'кветиапин', 'сероквел'],
    ['CYP3A4'], NONE, NONE, false),
  d('olanzapine', CR, 'Antipsychotic', ['zyprexa', 'zolafren', 'olanzapina', 'оланзапин'], NONE, NONE, NONE, false),
  d('risperidone', CR, 'Antipsychotic', ['rispolept', 'risperidon', 'рисперидон'], ['CYP2D6'], NONE, NONE, false),
  d('ziprasidone', CR, 'Antipsychotic', ['zeldox', 'zyprasydon', 'зипразидон'], ['CYP3A4'], NONE, NONE, false),
  d('amisulpride', CR, 'Antipsychotic', ['solian', 'amisulpryd', 'амисулприд'], NONE, NONE, NONE, false),
  d('aripiprazole', PR, 'Antipsychotic', ['abilify', 'arypiprazol', 'арипипразол'],
    ['CYP2D6', 'CYP3A4'], NONE, NONE, false),
  d('clozapine', PR, 'Antipsychotic', ['leponex', 'klozapina', 'клозапин'], ['CYP1A2'], NONE, NONE, false),
  d('paliperidone', PR, 'Antipsychotic', ['invega', 'paliperydon', 'палиперидон'], NONE, NONE, NONE, false),

  // ── Heart rhythm and heart drugs ──────────────────────────────────────────────────────────────
  d('amiodarone', KR, 'Antiarrhythmic', ['cordarone', 'opacorden', 'amiokordin', 'amiodaron', 'амиодарон',
    'кордарон'], ['CYP3A4'], ['CYP3A4', 'CYP2D6'], NONE, false),
  d('sotalol', KR, 'Antiarrhythmic / beta blocker', ['sotahexal', 'darob', 'соталол'], NONE, NONE, NONE, false),
  d('dronedarone', KR, 'Antiarrhythmic', ['multaq', 'dronedaron', 'дронедарон'], ['CYP3A4'], ['CYP3A4'], NONE, false),
  d('flecainide', KR, 'Antiarrhythmic', ['tambocor', 'flekainid', 'флекаинид'], ['CYP2D6'], NONE, NONE, false),
  d('quinidine', KR, 'Antiarrhythmic', ['chinidyna', 'хинидин'], ['CYP3A4'], ['CYP2D6'], NONE, false),
  d('procainamide', KR, 'Antiarrhythmic', ['prokainamid', 'прокаинамид'], NONE, NONE, NONE, false),
  d('disopyramide', KR, 'Antiarrhythmic', ['rythmodan', 'dizopiramid', 'дизопирамид'], ['CYP3A4'], NONE, NONE, false),
  d('dofetilide', KR, 'Antiarrhythmic', ['tikosyn', 'дофетилид'], NONE, NONE, NONE, false),
  d('ibutilide', KR, 'Antiarrhythmic', ['corvert', 'ибутилид'], NONE, NONE, NONE, false),
  d('ivabradine', CR, 'Heart-rate lowering', ['procoralan', 'bixebra', 'iwabradyna', 'ивабрадин'],
    ['CYP3A4'], NONE, NONE, false),
  d('ranolazine', CR, 'Antianginal', ['ranexa', 'ranolazyna', 'ранолазин'], ['CYP3A4'], NONE, NONE, false),
  d('cilostazol', KR, 'Antiplatelet / claudication', ['pletal', 'цилостазол'],
    ['CYP3A4'], NONE, NONE, false),
  d('diltiazem', NL, 'Calcium channel blocker', ['dilzem', 'blocalcin', 'дилтиазем'], ['CYP3A4'], ['CYP3A4'], NONE, false),
  d('verapamil', NL, 'Calcium channel blocker', ['isoptin', 'werapamil', 'верапамил', 'изоптин'],
    ['CYP3A4'], ['CYP3A4'], NONE, false),

  // ── Diuretics (risk via low potassium / magnesium) ───────────────────────────────────────────
  d('furosemide', CR, 'Loop diuretic', ['furosemidum', 'furosemid', 'lasix', 'фуроземид'], NONE, NONE, NONE, false),
  d('torasemide', CR, 'Loop diuretic', ['trifas', 'diuver', 'torasemid', 'торасемид'], NONE, NONE, NONE, false),
  d('hydrochlorothiazide', CR, 'Thiazide diuretic', ['hydrochlorotiazyd', 'hct', 'хидрохлоротиазид'],
    NONE, NONE, NONE, false),
  d('indapamide', CR, 'Thiazide-like diuretic', ['tertensif', 'indapen', 'indapamid', 'индапамид', 'тертензиф'],
    NONE, NONE, NONE, false),

  // ── Antihistamines, sedatives, pain ──────────────────────────────────────────────────────────
  d('hydroxyzine', CR, 'Antihistamine / anxiolytic', ['atarax', 'hydroxyzinum', 'hydroksyzyna', 'хидроксизин',
    'атаракс'], NONE, NONE, ANTIHISTAMINE_ALTS, false),
  d('diphenhydramine', CR, 'Antihistamine / sleep aid', ['benadryl', 'difenhydramina', 'дифенхидрамин'],
    ['CYP2D6'], ['CYP2D6'], ANTIHISTAMINE_ALTS, false),
  d('methadone', KR, 'Opioid', ['metadon', 'methadon', 'метадон'], ['CYP3A4', 'CYP2B6'], NONE, NONE, false),
  d('tramadol', PR, 'Opioid painkiller', ['tramal', 'poltram', 'tramadolum', 'трамадол', 'трамал'],
    ['CYP2D6', 'CYP3A4'], NONE, ['paracetamol'], false),
  d('buprenorphine', PR, 'Opioid', ['bunondol', 'transtec', 'buprenorfina', 'бупренорфин'],
    ['CYP3A4'], NONE, NONE, false),
  d('propofol', KR, 'Anaesthetic', ['diprivan', 'пропофол'], NONE, NONE, NONE, false),
  d('sevoflurane', KR, 'Inhaled anaesthetic', ['sevorane', 'sewofluran', 'севофлуран'], NONE, NONE, NONE, false),

  // ── Other ─────────────────────────────────────────────────────────────────────────────────────
  d('donepezil', KR, 'Dementia (cholinesterase inhibitor)', ['aricept', 'yasnal', 'donepezilum', 'донепезил'],
    ['CYP2D6', 'CYP3A4'], NONE, NONE, false),
  d('tacrolimus', PR, 'Immunosuppressant', ['prograf', 'advagraf', 'takrolimus', 'такролимус'],
    ['CYP3A4'], NONE, NONE, false),
  d('tamoxifen', PR, 'Breast cancer (hormone therapy)', ['nolvadex', 'tamoksyfen', 'тамоксифен'],
    ['CYP2D6', 'CYP3A4'], NONE, NONE, false),
  d('tizanidine', PR, 'Muscle relaxant', ['sirdalud', 'tyzanidyna', 'тизанидин'], ['CYP1A2'], NONE, NONE, false),
  d('solifenacin', CR, 'Overactive bladder', ['vesicare', 'solifenacyna', 'солифенацин'], ['CYP3A4'], NONE, NONE, false),
  d('tolterodine', PR, 'Overactive bladder', ['detrusitol', 'tolterodyna', 'толтеродин'],
    ['CYP2D6', 'CYP3A4'], NONE, NONE, false),
  d('mirabegron', PR, 'Overactive bladder', ['betmiga', 'мирабегрон'], NONE, ['CYP2D6'], NONE, false),
  d('atomoxetine', PR, 'ADHD (non-stimulant)', ['strattera', 'atomoksetyna', 'атомоксетин'],
    ['CYP2D6'], NONE, NONE, true),
  d('ritonavir', NL, 'HIV protease inhibitor / booster', ['norvir', 'ритонавир'], ['CYP3A4'], ['CYP3A4', 'CYP2D6'],
    NONE, false),

  // ── Avoid in congenital long QT (adrenergic stimulants — not QT drugs, but can trigger events) ─
  d('salbutamol', CR, 'Asthma reliever (beta-2 agonist)', ['albuterol', 'ventolin', 'buventol', 'salbutamolum',
    'салбутамол', 'вентолин'], NONE, NONE, NONE, true),
  d('salmeterol', CR, 'Long-acting asthma inhaler', ['serevent', 'salmeterolum', 'салметерол'],
    ['CYP3A4'], NONE, NONE, true),
  d('terbutaline', CR, 'Asthma reliever (beta-2 agonist)', ['bricanyl', 'terbutalina', 'тербуталин'],
    NONE, NONE, NONE, true),
  d('pseudoephedrine', CR, 'Decongestant (cold & flu)', ['sudafed', 'gripex', 'cirrus', 'modafen',
    'pseudoefedryna', 'псевдоефедрин'], NONE, NONE, NONE, true),
  d('phenylephrine', CR, 'Decongestant (cold & flu)', ['fenylefryna', 'фенилефрин', 'theraflu'],
    NONE, NONE, NONE, true),
  d('ephedrine', CR, 'Stimulant / decongestant', ['efedryna', 'ефедрин'], NONE, NONE, NONE, true),
  d('adrenaline', CR, 'Adrenaline (epinephrine)', ['epinephrine', 'epipen', 'adrenalina', 'адреналин'],
    NONE, NONE, NONE, true),
  d('methylphenidate', CR, 'ADHD stimulant', ['ritalin', 'concerta', 'medikinet', 'metylofenidat',
    'метилфенидат'], NONE, NONE, NONE, true),
  d('amphetamine', CR, 'ADHD stimulant', ['adderall', 'amfetamina', 'амфетамин'], ['CYP2D6'], NONE, NONE, true),

  // ── Not on the QT lists (common, and used as alternatives) ───────────────────────────────────
  d('paracetamol', NL, 'Painkiller / fever', ['acetaminophen', 'apap', 'panadol', 'calpol', 'tylenol',
    'codipar', 'парацетамол', 'панадол'], NONE, NONE, NONE, false),
  d('ibuprofen', NL, 'Painkiller (NSAID)', ['nurofen', 'ibuprom', 'ibufen', 'advil', 'ибупрофен', 'нурофен'],
    ['CYP2C9'], NONE, NONE, false),
  d('naproxen', NL, 'Painkiller (NSAID)', ['aleve', 'naproksen', 'напроксен'], NONE, NONE, NONE, false),
  d('metamizole', NL, 'Painkiller', ['pyralgina', 'analgin', 'metamizol', 'аналгин', 'метамизол'],
    NONE, NONE, NONE, false),
  d('aspirin', NL, 'Painkiller / antiplatelet', ['acetylsalicylic', 'polopiryna', 'acard', 'аспирин'],
    NONE, NONE, NONE, false),
  d('amoxicillin', NL, 'Penicillin antibiotic', ['amotaks', 'duomox', 'ospamox', 'augmentin', 'amoksiklav',
    'amoksycylina', 'амоксицилин', 'аугментин'], NONE, NONE, NONE, false),
  d('cefuroxime', NL, 'Cephalosporin antibiotic', ['zinnat', 'aksef', 'cefuroksym', 'цефуроксим', 'зинат'],
    NONE, NONE, NONE, false),
  d('cefalexin', NL, 'Cephalosporin antibiotic', ['cephalexin', 'keflex', 'цефалексин'], NONE, NONE, NONE, false),
  d('doxycycline', NL, 'Tetracycline antibiotic', ['doxycyclinum', 'unidox', 'doksycyklina', 'доксициклин'],
    NONE, NONE, NONE, false),
  d('nitrofurantoin', NL, 'Urinary antibiotic', ['nitrofurantoina', 'нитрофурантоин'],
    NONE, NONE, NONE, false),
  d('cetirizine', NL, 'Antihistamine', ['zyrtec', 'allertec', 'cetyryzyna', 'цетиризин', 'зиртек'],
    NONE, NONE, NONE, false),
  d('levocetirizine', NL, 'Antihistamine', ['xyzal', 'lewocetyryzyna', 'левоцетиризин'], NONE, NONE, NONE, false),
  d('loratadine', NL, 'Antihistamine', ['claritine', 'claritin', 'loratadyna', 'лоратадин', 'кларитин'],
    ['CYP3A4'], NONE, NONE, false),
  d('desloratadine', NL, 'Antihistamine', ['aerius', 'dezloratadyna', 'дезлоратадин'], NONE, NONE, NONE, false),
  d('fexofenadine', NL, 'Antihistamine', ['telfast', 'allegra', 'feksofenadyna', 'фексофенадин'],
    NONE, NONE, NONE, false),
  d('nadolol', NL, 'Beta blocker (first choice in LQTS)', ['corgard', 'надолол'], NONE, NONE, NONE, false),
  d('propranolol', NL, 'Beta blocker', ['inderal', 'propranololum', 'пропранолол'], ['CYP2D6', 'CYP1A2'],
    NONE, NONE, false),
  d('bisoprolol', NL, 'Beta blocker', ['concor', 'bisocard', 'бизопролол', 'конкор'],
    NONE, NONE, NONE, false),
  d('metoprolol', NL, 'Beta blocker', ['betaloc', 'metocard', 'метопролол', 'беталок'],
    ['CYP2D6'], NONE, NONE, false),
  d('atenolol', NL, 'Beta blocker', ['tenormin', 'атенолол'], NONE, NONE, NONE, false),
  d('mexiletine', NL, 'Antiarrhythmic (used in LQT3)', ['mexitil', 'meksyletyna', 'мексилетин'],
    ['CYP2D6', 'CYP1A2'], NONE, NONE, false),
  d('spironolactone', NL, 'Potassium-sparing diuretic', ['verospiron', 'spironol', 'спиронолактон'],
    NONE, NONE, NONE, false),
  d('amlodipine', NL, 'Calcium channel blocker', ['norvasc', 'amlozek', 'amlodypina', 'амлодипин'],
    ['CYP3A4'], NONE, NONE, false),
  d('ramipril', NL, 'ACE inhibitor', ['tritace', 'polpril', 'рамиприл'], NONE, NONE, NONE, false),
  d('lisinopril', NL, 'ACE inhibitor', ['prinivil', 'лизиноприл'], NONE, NONE, NONE, false),
  d('losartan', NL, 'Blood pressure (ARB)', ['cozaar', 'lorista', 'лосартан'], NONE, NONE, NONE, false),
  d('atorvastatin', NL, 'Cholesterol (statin)', ['atoris', 'sortis', 'lipitor', 'аторвастатин'],
    ['CYP3A4'], NONE, NONE, false),
  d('rosuvastatin', NL, 'Cholesterol (statin)', ['crestor', 'roswera', 'розувастатин'], NONE, NONE, NONE, false),
  d('metformin', NL, 'Diabetes', ['glucophage', 'siofor', 'metformina', 'метформин'], NONE, NONE, NONE, false),
  d('levothyroxine', NL, 'Thyroid hormone', ['euthyrox', 'letrox', 'lewotyroksyna', 'левотироксин'],
    NONE, NONE, NONE, false),
  d('montelukast', NL, 'Asthma / allergy', ['singulair', 'монтелукаст'], NONE, NONE, NONE, false),
  d('budesonide', NL, 'Inhaled steroid', ['pulmicort', 'будезонид'], NONE, NONE, NONE, false),
  d('potassium', NL, 'Potassium supplement', ['kaldyum', 'kalium', 'kalipoz', 'калий'], NONE, NONE, NONE, false),
  d('magnesium', NL, 'Magnesium supplement', ['magne', 'magnez', 'магнезий'], NONE, NONE, NONE, false)
];
