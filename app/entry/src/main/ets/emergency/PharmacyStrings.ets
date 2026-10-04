// "Pharmacy card" text in the 13 emergency-card languages (F-40). Static, pre-translated.

export interface PharmacyText {
  code: string;
  headline: string;
  body: string;
}

function p(code: string, headline: string, body: string): PharmacyText {
  const x: PharmacyText = { code: code, headline: headline, body: body };
  return x;
}

export const PHARMACY_TEXTS: PharmacyText[] = [
  p('en', 'I have long QT syndrome.', 'Please check the QT risk of any medicine before you give it to me ' +
    '(crediblemeds.org). I must avoid QT-prolonging drugs. My current medicines are below.'),
  p('pl', 'Mam zespół długiego QT.', 'Proszę sprawdzić ryzyko wydłużenia QT każdego leku, zanim mi go Pani/Pan ' +
    'wyda (crediblemeds.org). Muszę unikać leków wydłużających QT. Moje obecne leki są poniżej.'),
  p('bg', 'Имам синдром на удължен QT интервал.', 'Моля, проверете риска от удължаване на QT на всяко ' +
    'лекарство, преди да ми го дадете (crediblemeds.org). Трябва да избягвам лекарства, удължаващи QT. ' +
    'Текущите ми лекарства са по-долу.'),
  p('de', 'Ich habe ein Long-QT-Syndrom.', 'Bitte prüfen Sie vor der Abgabe jedes Medikament auf QT-Risiko ' +
    '(crediblemeds.org). Ich muss QT-verlängernde Medikamente meiden. Meine aktuellen Medikamente stehen unten.'),
  p('fr', 'J\'ai un syndrome du QT long.', 'Merci de vérifier le risque d\'allongement du QT de tout médicament ' +
    'avant de me le délivrer (crediblemeds.org). Je dois éviter les médicaments qui allongent le QT. Mes ' +
    'traitements actuels sont ci-dessous.'),
  p('es', 'Tengo síndrome de QT largo.', 'Por favor, compruebe el riesgo de prolongación del QT de cualquier ' +
    'medicamento antes de dármelo (crediblemeds.org). Debo evitar los fármacos que prolongan el QT. Mi ' +
    'medicación actual está abajo.'),
  p('it', 'Ho la sindrome del QT lungo.', 'Per favore verifichi il rischio di allungamento del QT di ogni farmaco ' +
    'prima di darmelo (crediblemeds.org). Devo evitare i farmaci che allungano il QT. I miei farmaci attuali ' +
    'sono qui sotto.'),
  p('uk', 'У мене синдром подовженого QT.', 'Будь ласка, перевірте ризик подовження QT для будь-яких ліків, перш ' +
    'ніж видати їх мені (crediblemeds.org). Я маю уникати препаратів, що подовжують QT. Мої поточні ліки - нижче.'),
  p('ro', 'Am sindromul de QT lung.', 'Vă rog verificați riscul de prelungire a QT al oricărui medicament înainte ' +
    'de a mi-l da (crediblemeds.org). Trebuie să evit medicamentele care prelungesc QT. Medicația mea actuală ' +
    'este mai jos.'),
  p('cs', 'Mám syndrom dlouhého QT.', 'Prosím, ověřte riziko prodloužení QT u každého léku, než mi ho vydáte ' +
    '(crediblemeds.org). Musím se vyhýbat lékům prodlužujícím QT. Moje současné léky jsou níže.'),
  p('nl', 'Ik heb het lang-QT-syndroom.', 'Controleer alstublieft het QT-risico van elk geneesmiddel voordat u het ' +
    'meegeeft (crediblemeds.org). Ik moet QT-verlengende middelen vermijden. Mijn huidige medicatie staat hieronder.'),
  p('pt', 'Tenho síndrome do QT longo.', 'Por favor verifique o risco de prolongamento do QT de qualquer ' +
    'medicamento antes de mo dispensar (crediblemeds.org). Tenho de evitar fármacos que prolongam o QT. A minha ' +
    'medicação atual está abaixo.'),
  p('tr', 'Uzun QT sendromum var.', 'Lütfen bana vermeden önce her ilacın QT riskini kontrol edin ' +
    '(crediblemeds.org). QT\'yi uzatan ilaçlardan kaçınmam gerekiyor. Kullandığım ilaçlar aşağıda.')
];

export function pharmacyText(code: string): PharmacyText {
  return PHARMACY_TEXTS.find((t: PharmacyText) => t.code === code) ?? PHARMACY_TEXTS[0];
}
