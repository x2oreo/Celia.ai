import { ScanVia } from '../model/ScanRecord';

// Route names for NavDestinations pushed onto the root NavPathStack (see pages/Index.ets).

export class Routes {
  static readonly ONBOARDING: string = 'onboarding';
  static readonly CHECK_RESULT: string = 'checkResult';   // param: CheckParam
  static readonly HISTORY: string = 'history';
  static readonly SETTINGS: string = 'settings';
  static readonly DOCTOR_PREP: string = 'doctorPrep';
  static readonly SOS: string = 'sos';                     // param: SosParam
  static readonly BYSTANDER: string = 'bystander';
  static readonly PHARMACY_CARD: string = 'pharmacyCard';
  static readonly PRIVACY: string = 'privacy';
  static readonly SYMPTOM_LOG: string = 'symptomLog';
  static readonly REMINDERS: string = 'reminders';
  static readonly CARD_VIEW: string = 'cardView';         // param: CardPayload (scanned card QR)
  static readonly AGENT_CHAT: string = 'agentChat';    // param: AskParam | null
  static readonly CHATS: string = 'chats';               // saved agent chats
  static readonly SCAN: string = 'scan';
  static readonly PAIR_WATCH: string = 'pairWatch';
  static readonly TRENDS: string = 'trends';
  // Workstream B (docs/handoff/B_PLAN.md). Pages exist as stubs until their stream fills them in.
  static readonly WELCOME: string = 'welcome';                    // first launch, signed out
  static readonly AUTH: string = 'auth';                          // param: AuthParam
  static readonly ACCOUNT: string = 'account';                    // Settings → Account
  static readonly EMERGENCY_PROFILE: string = 'emergencyProfile'; // edit the emergency details (B4)
  static readonly RESPONDER: string = 'responder';                // first-responder view (B5)
  static readonly VISITS: string = 'visits';                      // saved doctor visits (B6)
  static readonly FEELING: string = 'feeling';                    // "How are you feeling?" diary entry (B15)
}

export type AuthMode = 'SIGN_UP' | 'LOG_IN';

export class AuthParam {
  mode: AuthMode;

  constructor(mode: AuthMode) {
    this.mode = mode;
  }
}

// Tab indexes of components/MainTabs.ets. The first tab is the agent's home; the chat itself is a pushed page
// (Routes.AGENT_CHAT).
export class TabIndex {
  static readonly HOME: number = 0;
  static readonly MEDICINES: number = 1;
  static readonly HEART: number = 2;
  static readonly EMERGENCY: number = 3;
}

// Opens doctor prep on this specialty (doctor/DoctorPrep Specialty), e.g. from the agent's tile.
export class DoctorPrepParam {
  specialty: string;

  constructor(specialty: string) {
    this.specialty = specialty;
  }
}

export class SosParam {
  test: boolean;
  reason: string;   // e.g. "heart rate 165 at rest" — shown on screen and in the message
  auto: boolean;    // started by a vitals alert (true) or by the user (false)

  constructor(test: boolean, reason: string, auto: boolean = false) {
    this.test = test;
    this.reason = reason;
    this.auto = auto;
  }
}

export class CheckParam {
  query: string;
  log: boolean;   // false when re-opening a past check from history
  via: ScanVia;

  constructor(query: string, log: boolean, via: ScanVia = 'TEXT') {
    this.query = query;
    this.log = log;
    this.via = via;
  }
}

// Opens the agent chat and sends this question right away (e.g. "Ask the agent" in the medicine sheet).
export class AskParam {
  question: string;

  constructor(question: string) {
    this.question = question;
  }
}
