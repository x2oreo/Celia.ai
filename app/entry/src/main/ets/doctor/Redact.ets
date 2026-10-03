// Strips names and contact details from the visit's free text before it goes to /doctor-summary (B6). Same idea as
// the privacy ledger's FORBIDDEN_FIELDS (privacy/Ledger.ets), applied to values: e-mail addresses, web links and
// phone numbers by pattern, plus the profile's own names and numbers as literal strings (the patient, the emergency
// contacts, the cardiologist, the hospital). Pure and unit-tested. The server scrubs patterns again
// (backend/supabase/functions/doctor-summary/logic.ts).

import { Contact, Profile } from '../model/Profile';

export const REDACTED: string = '[removed]';

const EMAIL: RegExp = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
const URL: RegExp = /\b(https?:\/\/|www\.)\S+/gi;
// A run of digits with phone punctuation. Only replaced when it has 7+ digits and is not a date (see isPhone).
const PHONE_LIKE: RegExp = /\+?\d[\d\s().\/-]{4,}\d/g;
const DATE_LIKE: RegExp = /^(\d{4}[-.\/]\d{1,2}[-.\/]\d{1,2}|\d{1,2}[-.\/]\d{1,2}[-.\/]\d{2,4})$/;
const MIN_PART: number = 3;   // name parts shorter than this ("Jo", "Li") are too likely to hit ordinary words
const NOT_NAMES: string[] = ['the', 'and', 'mrs', 'miss', 'prof', 'doctor', 'hospital', 'clinic', 'mom', 'mum', 'dad'];

function digitCount(s: string): number {
  let n: number = 0;
  for (let i = 0; i < s.length; i++) {
    const c: string = s.charAt(i);
    if (c >= '0' && c <= '9') {
      n++;
    }
  }
  return n;
}

function isPhone(s: string): boolean {
  return digitCount(s) >= 7 && !DATE_LIKE.test(s.trim());
}

// Letters of any script (a character with case) and digits count as word characters, so "Anna" is found in
// "Anna's" but not in "Annabelle", and Polish or Cyrillic names work without regex Unicode classes.
function isWordChar(c: string): boolean {
  return c.toLowerCase() !== c.toUpperCase() || (c >= '0' && c <= '9');
}

function addTerm(out: string[], t: string | undefined): void {
  if (t === undefined) {
    return;
  }
  const v: string = t.trim().replace(/\s+/g, ' ');
  if (v.length >= MIN_PART && !out.includes(v)) {
    out.push(v);
  }
}

function addName(out: string[], name: string | undefined): void {
  if (name === undefined) {
    return;
  }
  addTerm(out, name);
  for (const part of name.split(/[\s,.-]+/)) {
    if (part.length >= MIN_PART && !NOT_NAMES.includes(part.toLowerCase())) {
      addTerm(out, part);
    }
  }
}

// The literal strings to remove for this profile: full names and their parts, phone numbers and e-mails.
export function personalTerms(p: Profile | undefined): string[] {
  const out: string[] = [];
  if (p === undefined) {
    return out;
  }
  addName(out, p.name);
  addName(out, p.cardiologistName);
  addTerm(out, p.cardiologistPhone);
  addTerm(out, p.hospital);
  p.contacts.forEach((c: Contact) => {
    addName(out, c.name);
    addTerm(out, c.phone);
    addTerm(out, c.email);
  });
  return out;
}

function replaceLiteral(text: string, term: string): string {
  const lower: string = text.toLowerCase();
  const needle: string = term.toLowerCase();
  if (needle.length === 0 || lower.length !== text.length) {
    return text;   // a case mapping changed the length; the pattern pass still applies
  }
  let out: string = '';
  let from: number = 0;
  let at: number = lower.indexOf(needle, from);
  while (at >= 0) {
    const before: string = at > 0 ? text.charAt(at - 1) : ' ';
    const end: number = at + needle.length;
    const after: string = end < text.length ? text.charAt(end) : ' ';
    if (!isWordChar(before) && !isWordChar(after)) {
      out += text.substring(from, at) + REDACTED;
      from = end;
    }
    at = lower.indexOf(needle, at + 1);
    if (at >= 0 && at < from) {
      at = lower.indexOf(needle, from);
    }
  }
  return out + text.substring(from);
}

export function redactPersonal(text: string, terms: string[]): string {
  let out: string = text.replace(EMAIL, REDACTED).replace(URL, REDACTED)
    .replace(PHONE_LIKE, (m: string) => isPhone(m) ? REDACTED : m);
  // Longest first, so "Anna Kowalska" goes as one piece before "Anna" alone.
  const sorted: string[] = terms.slice().sort((a: string, b: string) => b.length - a.length);
  for (const t of sorted) {
    out = replaceLiteral(out, t);
  }
  return out;
}
