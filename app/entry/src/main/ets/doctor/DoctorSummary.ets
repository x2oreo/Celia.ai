// Optional AI summary at the top of the doctor brief (T13 LLM part, backend /doctor-summary). The brief is
// deterministic and complete without it. Only non-personal lines of the brief go out (medicines with their risk
// words, interactions, flagged checks, counts) — never the Patient section (name, notes) or symptom notes. For a
// visit, the fixed purpose titles and the known-risk medicine names of its plan go too. The reply is checked again
// here (same rules as doctor-summary/logic.ts) and dropped when it fails.
// `visit` (optional) adds the typed reason and worries after doctor/Redact.ets has removed names, phone numbers,
// e-mails and links; the visit page does not send them, so the words the user typed stay on the phone.

import { Config } from '../common/Config';
import { NetResult, postJson } from '../common/Net';
import { BriefSection, Specialty, specialtyName, VisitAnswers } from './DoctorPrep';
import { knownNames, PlanGroup } from './VisitPlan';
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
  plan: PlanGroup[] = [], visit?: VisitAnswers, personal: string[] = []): Record<string, string> {
  const fields: Record<string, string> = {
    'specialty': specialtyName(specialty),
    'genotype': genotype,
    'medicines': linesOf(sections, 'Current medicines').join('\n'),
    'interactions': linesOf(sections, 'Interactions').join('\n'),
    'flagged': linesOf(sections, 'Medicines I was offered').join('\n'),
    'heartAlerts': `${linesOf(sections, 'Heart alerts').length}`,
    'symptoms': `${linesOf(sections, 'Symptoms I logged').length}`,
    'visitFor': plan.map((g: PlanGroup) => g.title).join('\n'),
    'avoid': knownNames(plan).join('\n')
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

  static async fetch(sections: BriefSection[], specialty: Specialty, genotype: string,
    plan: PlanGroup[] = []): Promise<SummaryOutcome> {
    if (!Config.hasBackend()) {
      return new SummaryOutcome('OFFLINE', '');
    }
    const res: NetResult = await postJson('/functions/v1/doctor-summary',
      summaryFields(sections, specialty, genotype, plan), 22000);
    if (!res.ok) {
      return new SummaryOutcome(res.status === 0 ? 'OFFLINE' : 'FAILED', '');
    }
    return parseSummary(res.body);
  }
}
