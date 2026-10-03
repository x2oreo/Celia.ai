// Emergency card text in 13 languages (F-29). Static and pre-translated — no AI and no network at emergency
// time. User data (name, medicines, notes) is shown as entered. Medical wording follows standard guidance for
// long QT: avoid QT-prolonging drugs, magnesium for torsades, CPR + defibrillation in arrest.

export interface CardText {
  code: string;
  language: string;      // name of the language in that language
  title: string;
  condition: string;
  avoid: string;
  treatment: string;
  icdYes: string;
  icdNo: string;
  genotype: string;
  meds: string;
  contacts: string;
  notes: string;
  noMeds: string;
}

function t(code: string, language: string, title: string, condition: string, avoid: string, treatment: string,
  icdYes: string, icdNo: string, genotype: string, meds: string, contacts: string, notes: string,
  noMeds: string): CardText {
  const x: CardText = {
    code: code, language: language, title: title, condition: condition, avoid: avoid, treatment: treatment,
    icdYes: icdYes, icdNo: icdNo, genotype: genotype, meds: meds, contacts: contacts, notes: notes, noMeds: noMeds
  };
  return x;
}

export const CARD_TEXTS: CardText[] = [
  t('en', 'English', 'MEDICAL ALERT', 'Long QT syndrome (LQTS) — inherited heart rhythm disorder',
    'Do NOT give QT-prolonging drugs (e.g. ondansetron, macrolide or quinolone antibiotics, haloperidol, ' +
      'methadone). Check every drug at crediblemeds.org.',
    'Torsades de pointes: IV magnesium sulfate, keep potassium high-normal. Cardiac arrest: CPR and defibrillation.',
    'Has an implanted defibrillator (ICD)', 'No implanted defibrillator', 'Genotype', 'Current medicines',
    'Emergency contacts', 'Notes', 'None'),
  t('pl', 'Polski', 'ALERT MEDYCZNY', 'Zespół długiego QT (LQTS) — wrodzone zaburzenie rytmu serca',
    'NIE podawać leków wydłużających QT (np. ondansetron, antybiotyki makrolidowe lub chinolony, haloperydol, ' +
      'metadon). Każdy lek sprawdzić na crediblemeds.org.',
    'Torsades de pointes: siarczan magnezu i.v., utrzymać potas w górnej normie. Zatrzymanie krążenia: RKO i ' +
      'defibrylacja.',
    'Ma wszczepiony kardiowerter-defibrylator (ICD)', 'Brak wszczepionego defibrylatora', 'Genotyp', 'Aktualne leki',
    'Kontakty alarmowe', 'Uwagi', 'Brak'),
  t('bg', 'Български', 'МЕДИЦИНСКО ПРЕДУПРЕЖДЕНИЕ', 'Синдром на удължен QT интервал (LQTS) — вродено нарушение ' +
    'на сърдечния ритъм',
    'НЕ давайте лекарства, удължаващи QT (напр. ондансетрон, макролидни или хинолонови антибиотици, халоперидол, ' +
      'метадон). Проверете всяко лекарство на crediblemeds.org.',
    'Torsades de pointes: магнезиев сулфат i.v., калий в горна норма. Сърдечен арест: КПР и дефибрилация.',
    'Има имплантиран дефибрилатор (ICD)', 'Няма имплантиран дефибрилатор', 'Генотип', 'Текущи лекарства',
    'Контакти при спешност', 'Бележки', 'Няма'),
  t('de', 'Deutsch', 'MEDIZINISCHER NOTFALLAUSWEIS', 'Long-QT-Syndrom (LQTS) — angeborene Herzrhythmusstörung',
    'KEINE QT-verlängernden Medikamente geben (z. B. Ondansetron, Makrolid- oder Chinolon-Antibiotika, ' +
      'Haloperidol, Methadon). Jedes Medikament auf crediblemeds.org prüfen.',
    'Torsade de pointes: Magnesiumsulfat i.v., Kalium hochnormal halten. Herzstillstand: Reanimation und ' +
      'Defibrillation.',
    'Hat einen implantierten Defibrillator (ICD)', 'Kein implantierter Defibrillator', 'Genotyp',
    'Aktuelle Medikamente', 'Notfallkontakte', 'Hinweise', 'Keine'),
  t('fr', 'Français', 'ALERTE MÉDICALE', 'Syndrome du QT long (SQTL) — trouble héréditaire du rythme cardiaque',
    'NE PAS administrer de médicaments allongeant le QT (ex. ondansétron, antibiotiques macrolides ou ' +
      'quinolones, halopéridol, méthadone). Vérifier chaque médicament sur crediblemeds.org.',
    'Torsades de pointes : sulfate de magnésium IV, maintenir le potassium dans la norme haute. Arrêt cardiaque : ' +
      'RCP et défibrillation.',
    'Porteur d\'un défibrillateur implantable (DAI)', 'Pas de défibrillateur implanté', 'Génotype',
    'Traitements en cours', 'Contacts d\'urgence', 'Remarques', 'Aucun'),
  t('es', 'Español', 'ALERTA MÉDICA', 'Síndrome de QT largo (SQTL) — trastorno hereditario del ritmo cardíaco',
    'NO administrar fármacos que prolonguen el QT (p. ej. ondansetrón, antibióticos macrólidos o quinolonas, ' +
      'haloperidol, metadona). Comprobar cada fármaco en crediblemeds.org.',
    'Torsade de pointes: sulfato de magnesio IV, mantener el potasio en rango alto-normal. Parada cardíaca: RCP y ' +
      'desfibrilación.',
    'Lleva un desfibrilador implantable (DAI)', 'Sin desfibrilador implantado', 'Genotipo', 'Medicación actual',
    'Contactos de emergencia', 'Notas', 'Ninguna'),
  t('it', 'Italiano', 'ALLERTA MEDICA', 'Sindrome del QT lungo (LQTS) — disturbo ereditario del ritmo cardiaco',
    'NON somministrare farmaci che allungano il QT (es. ondansetron, antibiotici macrolidi o chinoloni, ' +
      'aloperidolo, metadone). Verificare ogni farmaco su crediblemeds.org.',
    'Torsione di punta: magnesio solfato e.v., mantenere il potassio nella norma alta. Arresto cardiaco: RCP e ' +
      'defibrillazione.',
    'Portatore di defibrillatore impiantabile (ICD)', 'Nessun defibrillatore impiantato', 'Genotipo',
    'Farmaci attuali', 'Contatti di emergenza', 'Note', 'Nessuno'),
  t('uk', 'Українська', 'МЕДИЧНЕ ПОПЕРЕДЖЕННЯ', 'Синдром подовженого інтервалу QT (LQTS) — спадкове порушення ' +
    'ритму серця',
    'НЕ вводити препарати, що подовжують QT (напр. ондансетрон, макроліди чи фторхінолони, галоперидол, ' +
      'метадон). Перевіряйте кожен препарат на crediblemeds.org.',
    'Torsades de pointes: магнію сульфат в/в, калій у верхній межі норми. Зупинка серця: СЛР і дефібриляція.',
    'Має імплантований дефібрилятор (ICD)', 'Немає імплантованого дефібрилятора', 'Генотип', 'Поточні ліки',
    'Екстрені контакти', 'Примітки', 'Немає'),
  t('ro', 'Română', 'ALERTĂ MEDICALĂ', 'Sindrom de QT lung (LQTS) — tulburare ereditară de ritm cardiac',
    'NU administrați medicamente care prelungesc QT (ex. ondansetron, antibiotice macrolide sau chinolone, ' +
      'haloperidol, metadonă). Verificați fiecare medicament pe crediblemeds.org.',
    'Torsada vârfurilor: sulfat de magneziu i.v., potasiu la limita superioară a normalului. Stop cardiac: RCP și ' +
      'defibrilare.',
    'Are un defibrilator implantabil (ICD)', 'Fără defibrilator implantat', 'Genotip', 'Medicație curentă',
    'Contacte de urgență', 'Note', 'Niciuna'),
  t('cs', 'Čeština', 'ZDRAVOTNÍ UPOZORNĚNÍ', 'Syndrom dlouhého QT (LQTS) — vrozená porucha srdečního rytmu',
    'NEPODÁVEJTE léky prodlužující QT (např. ondansetron, makrolidová nebo chinolonová antibiotika, haloperidol, ' +
      'metadon). Každý lék ověřte na crediblemeds.org.',
    'Torsades de pointes: síran hořečnatý i.v., draslík v horní polovině normy. Zástava oběhu: KPR a defibrilace.',
    'Má implantovaný defibrilátor (ICD)', 'Bez implantovaného defibrilátoru', 'Genotyp', 'Současné léky',
    'Nouzové kontakty', 'Poznámky', 'Žádné'),
  t('nl', 'Nederlands', 'MEDISCHE WAARSCHUWING', 'Lang-QT-syndroom (LQTS) — erfelijke hartritmestoornis',
    'GEEN QT-verlengende middelen geven (bv. ondansetron, macrolide- of chinolonantibiotica, haloperidol, ' +
      'methadon). Controleer elk middel op crediblemeds.org.',
    'Torsade de pointes: magnesiumsulfaat i.v., kalium hoog-normaal houden. Hartstilstand: reanimatie en ' +
      'defibrillatie.',
    'Heeft een geïmplanteerde defibrillator (ICD)', 'Geen geïmplanteerde defibrillator', 'Genotype',
    'Huidige medicatie', 'Noodcontacten', 'Opmerkingen', 'Geen'),
  t('pt', 'Português', 'ALERTA MÉDICO', 'Síndrome do QT longo (SQTL) — doença hereditária do ritmo cardíaco',
    'NÃO administrar fármacos que prolonguem o QT (ex. ondansetrom, antibióticos macrólidos ou quinolonas, ' +
      'haloperidol, metadona). Verificar cada fármaco em crediblemeds.org.',
    'Torsade de pointes: sulfato de magnésio EV, manter o potássio no limite alto do normal. Paragem cardíaca: ' +
      'SBV/RCP e desfibrilhação.',
    'Tem um cardioversor-desfibrilhador implantado (CDI)', 'Sem desfibrilhador implantado', 'Genótipo',
    'Medicação atual', 'Contactos de emergência', 'Notas', 'Nenhuma'),
  t('tr', 'Türkçe', 'TIBBİ UYARI', 'Uzun QT sendromu (LQTS) — kalıtsal kalp ritim bozukluğu',
    'QT\'yi uzatan ilaçlar VERMEYİN (ör. ondansetron, makrolid veya kinolon antibiyotikler, haloperidol, ' +
      'metadon). Her ilacı crediblemeds.org üzerinden kontrol edin.',
    'Torsades de pointes: IV magnezyum sülfat, potasyumu normalin üst sınırında tutun. Kalp durması: KPR ve ' +
      'defibrilasyon.',
    'İmplante defibrilatörü (ICD) var', 'İmplante defibrilatör yok', 'Genotip', 'Kullandığı ilaçlar',
    'Acil durum kişileri', 'Notlar', 'Yok')
];

export function cardText(code: string | undefined): CardText {
  return CARD_TEXTS.find((x: CardText) => x.code === code) ?? CARD_TEXTS[0];
}

// Country → most likely card language, for travel mode (F-40) and defaults.
export function languageForCountry(country: string): string {
  switch (country.toUpperCase()) {
    case 'PL':
      return 'pl';
    case 'BG':
      return 'bg';
    case 'DE':
    case 'AT':
    case 'CH':
      return 'de';
    case 'FR':
    case 'BE':
    case 'LU':
      return 'fr';
    case 'ES':
    case 'MX':
    case 'AR':
      return 'es';
    case 'IT':
      return 'it';
    case 'UA':
      return 'uk';
    case 'RO':
    case 'MD':
      return 'ro';
    case 'CZ':
    case 'SK':
      return 'cs';
    case 'NL':
      return 'nl';
    case 'PT':
    case 'BR':
      return 'pt';
    case 'TR':
      return 'tr';
    default:
      return 'en';
  }
}

// Labels for the emergency details (Workstream B4). English only for now: a language gets its own entry here only
// once a checked translation exists — we never invent one, and every other language falls back to English.
export interface CardLabels {
  code: string;
  dateOfBirth: string;
  age: string;
  sex: string;
  female: string;
  male: string;
  other: string;
  bloodType: string;
  allergies: string;
  icdModel: string;
  cardiologist: string;
  hospital: string;
}

export const CARD_LABELS: CardLabels[] = [
  {
    code: 'en', dateOfBirth: 'Date of birth', age: 'age', sex: 'Sex', female: 'Female', male: 'Male', other: 'Other',
    bloodType: 'Blood type', allergies: 'Allergies', icdModel: 'ICD model', cardiologist: 'Cardiologist',
    hospital: 'Hospital'
  }
];

export function cardLabels(code: string | undefined): CardLabels {
  return CARD_LABELS.find((x: CardLabels) => x.code === code) ?? CARD_LABELS[0];
}
