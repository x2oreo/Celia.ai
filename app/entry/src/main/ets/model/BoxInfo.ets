// What we know about a scanned medicine box (F-36). Facts from the national register or from the user — never
// a safety statement; the verdict (DrugVerdict) stays the only safety answer.

export type BoxSource = 'PL_REGISTER' | 'LEARNED' | 'DEMO';

export interface BoxInfo {
  gtin: string;            // 13-digit GTIN from the barcode
  brand: string;           // name on the box, e.g. "Klacid"
  substance: string;       // active substance as registered (Latin INN in PL), e.g. "Clarithromycinum"
  ingredients: string;     // English INNs joined by " + " — what DrugChecker checks
  strength: string;        // e.g. "500 mg"
  form: string;            // e.g. "Film-coated tablets"
  pack: string;            // e.g. "14 tabl."
  atc: string;             // WHO ATC code, e.g. "J01FA09"; '' if unknown
  holder: string;          // marketing-authorisation holder
  rxCategory: string;      // PL availability: Rp, Rpz, Rpw, Lz, OTC; '' if unknown
  leafletUrl: string;      // patient leaflet (PDF) in the register; '' if none
  country: string;         // ISO code of the GS1 prefix, e.g. 'PL', 'BG'; '' if unknown
  source: BoxSource;
  sourceDate: string;      // register snapshot date (YYYY-MM-DD) or the date the user added it
}
