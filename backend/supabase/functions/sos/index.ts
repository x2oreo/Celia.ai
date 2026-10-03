// `sos` Edge Function: alerts emergency contacts when the watch sends an SOS.
//
// Called by the `watch_metrics_sos_notify` trigger (migration 20261003200000_sos_dispatch.sql) with
// `{ "record": <watch_metrics row> }` and the `x-sos-secret` header. Deploy with --no-verify-jwt: the shared secret
// is the auth, not a user JWT.
//
// Flow: verify secret → parse row → cooldown check → load contacts + patient context → deterministic message →
// Twilio SMS + call per contact → audit row in sos_dispatches. Without Twilio secrets it runs in dry-run mode and
// only records what it would have sent, so the emulator demo never fails.
import { createClient } from 'npm:@supabase/supabase-js@2';
import {
  buildSosMessage,
  type Genotype,
  isE164,
  type LastDose,
  parseSosPayload,
  type PatientContext,
  type RecentSymptom,
  SYMPTOM_WINDOW_MS,
} from './message.ts';
import { placeCall, type SendResult, sendSms, twilioConfigFromEnv } from './twilio.ts';

const COOLDOWN_MINUTES = 10;
const MAX_CONTACTS = 5;

interface SosRecord {
  id: number;
  device_id: string;
  type: string;
  payload: unknown;
  source: string;
}

interface ContactResult {
  name: string;
  sms: SendResult;
  call: SendResult;
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

/** Constant-time string comparison for the shared secret. */
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function parseRecord(body: unknown): SosRecord | null {
  if (body === null || typeof body !== 'object') {
    return null;
  }
  const r = (body as { record?: unknown }).record;
  if (r === null || typeof r !== 'object') {
    return null;
  }
  const o = r as Record<string, unknown>;
  if (typeof o.id !== 'number' || typeof o.device_id !== 'string' || o.type !== 'sos') {
    return null;
  }
  return {
    id: o.id,
    device_id: o.device_id,
    type: o.type,
    payload: o.payload,
    source: typeof o.source === 'string' ? o.source : 'watch',
  };
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') {
    return json(405, { error: 'POST only' });
  }
  const secret = Deno.env.get('SOS_WEBHOOK_SECRET');
  if (!secret || !safeEqual(req.headers.get('x-sos-secret') ?? '', secret)) {
    return json(401, { error: 'unauthorized' });
  }

  const record = parseRecord(await req.json().catch(() => null));
  if (record === null) {
    return json(400, { error: 'expected { record: watch_metrics row with type "sos" }' });
  }
  const payload = parseSosPayload(record.payload);
  if (payload === null) {
    return json(400, { error: 'invalid sos payload' });
  }

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  });

  const audit = async (status: string, detail: Record<string, unknown>): Promise<void> => {
    const { error } = await db.from('sos_dispatches').insert({
      metric_id: record.id,
      device_id: record.device_id,
      status,
      detail,
    });
    if (error) {
      console.error(`[sos] audit insert failed: ${error.message}`);
    }
  };

  // Cooldown: one alert round per device per window, so a flapping watch can't spam contacts.
  const since = new Date(Date.now() - COOLDOWN_MINUTES * 60_000).toISOString();
  const { count, error: cooldownError } = await db.from('sos_dispatches')
    .select('id', { count: 'exact', head: true })
    .eq('device_id', record.device_id)
    .in('status', ['sent', 'partial', 'dry_run'])
    .gte('created_at', since);
  if (cooldownError) {
    // Fail open: a missed alert is worse than a duplicate one.
    console.error(`[sos] cooldown check failed, sending anyway: ${cooldownError.message}`);
  } else if ((count ?? 0) > 0) {
    await audit('skipped_cooldown', { cooldownMinutes: COOLDOWN_MINUTES });
    return json(200, { status: 'skipped_cooldown' });
  }

  const symptomSince = new Date(Date.now() - SYMPTOM_WINDOW_MS).toISOString();
  const [contactsRes, contextRes, doseRes, symptomRes] = await Promise.all([
    db.from('emergency_contacts').select('name, phone').eq('device_id', record.device_id)
      .order('priority', { ascending: true }).limit(MAX_CONTACTS),
    db.from('watch_context').select('patient_name, genotype, risky_drug, risky_drug_at')
      .eq('device_id', record.device_id).maybeSingle(),
    // Optional extras from the watch views; an error here must never block the alert.
    db.from('watch_doses').select('name, taken_at').eq('device_id', record.device_id)
      .order('taken_at', { ascending: false }).limit(1).maybeSingle(),
    db.from('watch_symptoms').select('kind, bpm, recorded_at').eq('device_id', record.device_id)
      .neq('kind', 'fine').gte('recorded_at', symptomSince)
      .order('recorded_at', { ascending: false }).limit(1).maybeSingle(),
  ]);
  if (contactsRes.error) {
    console.error(`[sos] contacts query failed: ${contactsRes.error.message}`);
    await audit('failed', { error: 'contacts query failed' });
    return json(502, { status: 'failed', error: 'contacts unavailable' });
  }
  const contacts = (contactsRes.data ?? []).filter((c) => typeof c.phone === 'string' && isE164(c.phone));
  if (contacts.length === 0) {
    await audit('no_contacts', { reason: payload.reason });
    return json(200, { status: 'no_contacts' });
  }

  const c = contextRes.data;
  // Only mention a risky drug scanned in the last 24 h; older scans are noise in an emergency text.
  const drugFresh = c?.risky_drug_at ? Date.now() - Date.parse(c.risky_drug_at) < 24 * 3600_000 : false;
  const dose: LastDose | null = doseRes.data && typeof doseRes.data.name === 'string'
    ? { name: doseRes.data.name, at: Date.parse(doseRes.data.taken_at) }
    : null;
  const symptom: RecentSymptom | null = symptomRes.data && typeof symptomRes.data.kind === 'string'
    ? { kind: symptomRes.data.kind, bpm: Number(symptomRes.data.bpm) || 0, at: Date.parse(symptomRes.data.recorded_at) }
    : null;
  if (doseRes.error || symptomRes.error) {
    console.warn(`[sos] watch extras unavailable: ${doseRes.error?.message ?? ''} ${symptomRes.error?.message ?? ''}`);
  }
  const ctx: PatientContext = {
    lastDose: dose,
    recentSymptom: symptom,
    name: c?.patient_name ?? null,
    genotype: (['LQT1', 'LQT2', 'LQT3'].includes(c?.genotype) ? c?.genotype : 'UNKNOWN') as Genotype,
    riskyDrug: drugFresh ? (c?.risky_drug ?? null) : null,
  };
  const message = buildSosMessage(payload, ctx);

  const twilio = twilioConfigFromEnv((k) => Deno.env.get(k));
  if (twilio === null) {
    console.warn('[sos] Twilio secrets missing: dry run, nothing sent');
    await audit('dry_run', { contacts: contacts.length, sms: message.sms, source: record.source });
    return json(200, { status: 'dry_run', contacts: contacts.length, sms: message.sms });
  }

  const results: ContactResult[] = await Promise.all(contacts.map(async (contact) => {
    const [sms, call] = await Promise.all([
      sendSms(twilio, contact.phone, message.sms),
      placeCall(twilio, contact.phone, message.voice),
    ]);
    return { name: contact.name, sms, call };
  }));

  const delivered = results.filter((r) => r.sms.ok || r.call.ok).length;
  const status = delivered === results.length ? 'sent' : delivered > 0 ? 'partial' : 'failed';
  // Phone numbers stay out of the audit log; names and Twilio results are enough to debug.
  await audit(status, { results, source: record.source });
  if (status !== 'sent') {
    console.error(`[sos] ${status}: ${JSON.stringify(results)}`);
  }
  return json(200, { status, delivered, contacts: results.length });
});
