// UTF-8 + base64url (RFC 4648 §5, no padding) in plain ArkTS — used for the emergency-card link. Pure and
// dependency-free so it behaves the same on device and in local unit tests.

const ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

export function utf8Encode(text: string): number[] {
  const out: number[] = [];
  for (let i = 0; i < text.length; i++) {
    let cp: number = text.charCodeAt(i);
    if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < text.length) {
      const lo: number = text.charCodeAt(i + 1);
      if (lo >= 0xDC00 && lo <= 0xDFFF) {
        cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
        i++;
      }
    }
    if (cp < 0x80) {
      out.push(cp);
    } else if (cp < 0x800) {
      out.push(0xC0 | (cp >> 6), 0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
      out.push(0xE0 | (cp >> 12), 0x80 | ((cp >> 6) & 0x3F), 0x80 | (cp & 0x3F));
    } else {
      out.push(0xF0 | (cp >> 18), 0x80 | ((cp >> 12) & 0x3F), 0x80 | ((cp >> 6) & 0x3F), 0x80 | (cp & 0x3F));
    }
  }
  return out;
}

// Throws on malformed input.
export function utf8Decode(bytes: number[]): string {
  let out: string = '';
  let i: number = 0;
  while (i < bytes.length) {
    const b: number = bytes[i];
    let cp: number;
    let extra: number;
    if (b < 0x80) {
      cp = b;
      extra = 0;
    } else if ((b & 0xE0) === 0xC0) {
      cp = b & 0x1F;
      extra = 1;
    } else if ((b & 0xF0) === 0xE0) {
      cp = b & 0x0F;
      extra = 2;
    } else if ((b & 0xF8) === 0xF0) {
      cp = b & 0x07;
      extra = 3;
    } else {
      throw new Error('bad utf-8');
    }
    if (i + extra >= bytes.length) {
      throw new Error('truncated utf-8');
    }
    for (let k = 1; k <= extra; k++) {
      const c: number = bytes[i + k];
      if ((c & 0xC0) !== 0x80) {
        throw new Error('bad utf-8');
      }
      cp = (cp << 6) | (c & 0x3F);
    }
    i += extra + 1;
    out += String.fromCodePoint(cp);
  }
  return out;
}

export function base64UrlEncode(bytes: number[]): string {
  let out: string = '';
  for (let i = 0; i < bytes.length; i += 3) {
    const b1: number = i + 1 < bytes.length ? bytes[i + 1] : 0;
    const b2: number = i + 2 < bytes.length ? bytes[i + 2] : 0;
    const n: number = (bytes[i] << 16) | (b1 << 8) | b2;
    out += ALPHABET.charAt((n >> 18) & 63) + ALPHABET.charAt((n >> 12) & 63);
    if (i + 1 < bytes.length) {
      out += ALPHABET.charAt((n >> 6) & 63);
    }
    if (i + 2 < bytes.length) {
      out += ALPHABET.charAt(n & 63);
    }
  }
  return out;
}

// Throws on characters outside the base64url alphabet.
export function base64UrlDecode(text: string): number[] {
  const out: number[] = [];
  let buffer: number = 0;
  let bits: number = 0;
  for (let i = 0; i < text.length; i++) {
    const v: number = ALPHABET.indexOf(text.charAt(i));
    if (v < 0) {
      throw new Error('bad base64url');
    }
    buffer = ((buffer << 6) | v) & 0xFFFFFF;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push((buffer >> bits) & 0xFF);
    }
  }
  return out;
}
