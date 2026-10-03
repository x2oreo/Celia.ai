// Deterministic wording for verdicts. Used for offline replies, fallbacks, and to replace model text that
// contradicts a verdict. Never says "safe" (lqts-domain safety design).

import { VerdictCardPayload, InteractionFinding } from '../model/AgentTypes';

export const ASK_DOCTOR: string = 'Please confirm with your doctor or pharmacist.';

function displayName(v: VerdictCardPayload): string {
  return v.ingredient !== '' ? v.ingredient : v.query;
}

export function riskSentence(name: string, risk: string): string {
  switch (risk) {
    case 'KNOWN_RISK':
      return `${name} is on the known-risk list for QT prolongation. Avoid it unless your cardiologist says otherwise.`;
    case 'POSSIBLE_RISK':
      return `${name} has a possible risk of QT prolongation. Use caution and check with your doctor before taking it.`;
    case 'CONDITIONAL_RISK':
      return `${name} can prolong the QT interval under certain conditions. Check with your doctor before taking it.`;
    case 'NOT_LISTED':
      return `${name} is not on the QT-risk lists.`;
    default:
      return `I couldn't find ${name} in my medicine list, so I can't check it. Ask a pharmacist before taking it.`;
  }
}

export function findingsSentence(findings: InteractionFinding[]): string {
  if (findings.length === 0) {
    return '';
  }
  return findings.map((f: InteractionFinding) => f.detail).join(' ');
}

export function verdictText(v: VerdictCardPayload): string {
  const parts: string[] = [riskSentence(displayName(v), v.risk)];
  if (v.findings.length > 0) {
    parts.push(findingsSentence(v.findings));
    if (v.combinedRisk !== v.risk) {
      parts.push('Together with your current medicines, treat it as a higher risk.');
    }
  }
  parts.push(ASK_DOCTOR);
  return parts.join(' ');
}
