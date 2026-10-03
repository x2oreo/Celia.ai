// Minimal Twilio REST client (SMS + voice call with inline TwiML). Plain fetch, no SDK.
import { escapeXml } from './message.ts';

export interface TwilioConfig {
  accountSid: string;
  authToken: string;
  /** Twilio phone number in E.164, used as the sender for SMS and calls. */
  from: string;
}

export interface SendResult {
  ok: boolean;
  /** Twilio SID on success, error text on failure. */
  detail: string;
}

const TIMEOUT_MS = 10_000;

/** Reads Twilio secrets; returns null when any is missing (the function then runs in dry-run mode). */
export function twilioConfigFromEnv(get: (key: string) => string | undefined): TwilioConfig | null {
  const accountSid = get('TWILIO_ACCOUNT_SID');
  const authToken = get('TWILIO_AUTH_TOKEN');
  const from = get('TWILIO_FROM_NUMBER');
  if (!accountSid || !authToken || !from) {
    return null;
  }
  return { accountSid, authToken, from };
}

async function post(cfg: TwilioConfig, resource: 'Messages' | 'Calls', form: Record<string, string>): Promise<SendResult> {
  const url = `https://api.twilio.com/2010-04-01/Accounts/${cfg.accountSid}/${resource}.json`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${btoa(`${cfg.accountSid}:${cfg.authToken}`)}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams(form),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    const body = await res.json().catch(() => ({})) as { sid?: string; message?: string };
    if (!res.ok) {
      return { ok: false, detail: `HTTP ${res.status}: ${body.message ?? 'unknown error'}` };
    }
    return { ok: true, detail: body.sid ?? '' };
  } catch (e) {
    return { ok: false, detail: e instanceof Error ? e.message : String(e) };
  }
}

export function sendSms(cfg: TwilioConfig, to: string, body: string): Promise<SendResult> {
  return post(cfg, 'Messages', { To: to, From: cfg.from, Body: body });
}

/** Calls `to` and reads `text` twice, so a contact who picks up mid-sentence still hears it. */
export function placeCall(cfg: TwilioConfig, to: string, text: string): Promise<SendResult> {
  const say = `<Say voice="alice" language="en-GB">${escapeXml(text)}</Say>`;
  const twiml = `<Response>${say}<Pause length="1"/>${say}</Response>`;
  return post(cfg, 'Calls', { To: to, From: cfg.from, Twiml: twiml });
}
