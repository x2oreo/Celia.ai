import { Genotype } from '../model/WatchMetric';
import { Logger } from '../common/Logger';
import { RestClient } from './RestClient';

/** Row of `watch_context`, written by the phone app (profile + drug scans). */
interface ContextRow {
  genotype: string;
  risky_drug: string | null;
  risky_drug_risk: string | null;
  risky_drug_at: string | null;
}

export interface PatientContext {
  genotype: Genotype;
  /** Name of a QT-risk drug taken in the last 72 h, '' if none. */
  riskyDrug: string;
  riskyDrugRisk: string;
  /** When it was taken (epoch ms, from the phone's "I took it"); 0 if none. */
  riskyDrugAt: number;
}

/** A scanned drug counts as "recent" for this long. */
const RECENT_DRUG_MS = 72 * 3600 * 1000;

function toGenotype(s: string): Genotype {
  return s === 'LQT1' || s === 'LQT2' || s === 'LQT3' ? s : 'UNKNOWN';
}

/** Polls `GET /rest/v1/watch_context?device_id=eq.X` so the watch knows the genotype and recent risky drugs. */
export class PatientContextClient {
  private client: RestClient;
  private path: string;

  constructor(client: RestClient, deviceId: string) {
    this.client = client;
    this.path = `/rest/v1/watch_context?device_id=eq.${encodeURIComponent(deviceId)}&select=*`;
  }

  /** Undefined when the request fails or no row exists (keep the previous context). */
  async fetch(): Promise<PatientContext | undefined> {
    const resp = await this.client.get(this.path);
    if (resp.status === 0) {
      Logger.warn(`context fetch failed: ${resp.body}`);
      return undefined;
    }
    if (resp.status !== 200) {
      Logger.warn(`context HTTP ${resp.status}`);
      return undefined;
    }
    try {
      const rows = JSON.parse(resp.body) as ContextRow[];
      if (!Array.isArray(rows) || rows.length === 0) {
        return undefined;
      }
      const row = rows[0];
      const at = row.risky_drug_at !== null ? Date.parse(row.risky_drug_at) : NaN;
      const recent = row.risky_drug !== null && row.risky_drug.length > 0 && !isNaN(at) &&
        Date.now() - at < RECENT_DRUG_MS;
      const ctx: PatientContext = {
        genotype: toGenotype(typeof row.genotype === 'string' ? row.genotype : ''),
        riskyDrug: recent && row.risky_drug !== null ? row.risky_drug : '',
        riskyDrugRisk: recent && row.risky_drug_risk !== null ? row.risky_drug_risk : '',
        riskyDrugAt: recent ? at : 0
      };
      return ctx;
    } catch (e) {
      Logger.warn('context fetch failed: bad JSON');
      return undefined;
    }
  }
}
