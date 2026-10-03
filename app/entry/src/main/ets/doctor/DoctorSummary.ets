// Optional AI summary at the top of the doctor brief (T13 LLM part, backend /doctor-summary). The brief is
// deterministic and complete without it. Only non-personal lines of the brief go out (medicines with their risk
// words, interactions, flagged checks, counts) — never the Patient section (name, notes) or symptom notes. The
// reply is checked again here (same rules as doctor-summary/logic.ts) and dropped when it fails.
// For a saved visit (B6) the reason and worries go too, after doctor/Redact.ets has removed names, phone numbers,
// e-mails and links; the field names `reason` / `worries` pass the ledger's FORBIDDEN_FIELDS guard by design.

import { Config } from '../common/Config';
import { NetResult, postJson } from '../common/Net';
import { BriefSection, Specialty, specialtyName, VisitAnswers } from './DoctorPrep';
import { redactPersonal } from './Redact';

const SUMMARY_MAX: number = 420;
const BANNED: RegExp =
  /\b(safe|safer|harmless|no risk|not risky|fine to take|ok to take|stop taking|start taking|discontinue|\d+([.,]\d+)?\s?(mg|mcg|µg|ml)\b)/i;

export type SummaryResult = 'OK' | 'REJECTED' | 'OFFLINE' | 'FAILED';

export class SummaryOutcome {
  result: SummaryResult;
  text: string;

  constructor(result: SummaryResult, text: string) {
    this.result = result;
    this.text = text;
  }
}

interface SummaryReply {
  summary?: string;
}

function linesOf(sections: BriefSection[], titleStart: string): string[] {
  const s: BriefSection | undefined = sections.find((x: BriefSection) => x.title.startsWith(titleStart));
  return s === undefined ? [] : s.lines;
}

// Pure: what is sent. Exported for tests (they check that nothing personal is included).
export function summaryFields(sections: BriefSection[], specialty: Specialty, genotype: string,
  visit?: VisitAnswers, personal: string[] = []): Record<string, string> {
  const fields: Record<string, string> = {
    'specialty': specialtyName(specialty),
    'genotype': genotype,
    'medicines': linesOf(sections, 'Current medicines').join('\n'),
    'interactions': linesOf(sections, 'Interactions').join('\n'),
    'flagged': linesOf(sections, 'Medicines I was offered').join('\n'),
    'heartAlerts': `${linesOf(sections, 'Heart alerts').length}`,
    'symptoms': `${linesOf(sections, 'Symptoms I logged').length}`
  };
  if (visit !== undefined) {
    fields['reason'] = redactPersonal(visit.reason, personal);
    fields['worries'] = redactPersonal(visit.worries, personal);
  }
  return fields;
}

// Pure: server body → outcome. Exported for tests.
export function parseSummary(body: string): SummaryOutcome {
  let r: SummaryReply;
  try {
    r = JSON.parse(body) as SummaryReply;
  } catch (e) {
    return new SummaryOutcome('REJECTED', '');
  }
  const t: string = typeof r.summary === 'string' ? r.summary.trim().replace(/\s+/g, ' ') : '';
  if (t.length < 20 || t.length > SUMMARY_MAX || BANNED.test(t)) {
    return new SummaryOutcome('REJECTED', '');
  }
  return new SummaryOutcome('OK', t);
}

export class DoctorSummary {
  static available(): boolean {
    return Config.hasBackend();
  }

  static async fetch(sections: BriefSection[], specialty: Specialty, genotype: string, visit?: VisitAnswers,
    personal: string[] = []): Promise<SummaryOutcome> {
    if (!Config.hasBackend()) {
      return new SummaryOutcome('OFFLINE', '');
    }
    const res: NetResult = await postJson('/functions/v1/doctor-summary',
      summaryFields(sections, specialty, genotype, visit, personal), 22000);
    if (!res.ok) {
      return new SummaryOutcome(res.status === 0 ? 'OFFLINE' : 'FAILED', '');
    }
    return parseSummary(res.body);
  }
}
