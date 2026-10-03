// End-to-end encryption for shared links (emergency card, doctor report): AES-256-GCM with a fresh random key per
// share. Output layout matches WebCrypto (iv | ciphertext | tag), so the viewer page decrypts it with
// crypto.subtle in any browser. The key only ever travels in the link's #fragment — never to a server.

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { base64UrlDecode, base64UrlEncode, utf8Decode, utf8Encode } from '../common/Base64Url';

const IV_BYTES: number = 12;
const TAG_BYTES: number = 16;
const KEY_BYTES: number = 32;

export class Sealed {
  ciphertext: string;   // base64url(iv | ciphertext | tag)
  key: string;          // base64url(32-byte AES key)

  constructor(ciphertext: string, key: string) {
    this.ciphertext = ciphertext;
    this.key = key;
  }
}

function blob(bytes: number[]): cryptoFramework.DataBlob {
  const b: cryptoFramework.DataBlob = { data: new Uint8Array(bytes) };
  return b;
}

function gcmParams(iv: number[], tag: number[]): cryptoFramework.GcmParamsSpec {
  const p: cryptoFramework.GcmParamsSpec = {
    algName: 'GcmParamsSpec',
    iv: blob(iv),
    aad: blob([]),
    authTag: blob(tag)
  };
  return p;
}

function toArray(d: cryptoFramework.DataBlob | null): number[] {
  return d === null ? [] : Array.from(d.data);
}

async function aesKey(raw: number[]): Promise<cryptoFramework.SymKey> {
  return await cryptoFramework.createSymKeyGenerator('AES256').convertKey(blob(raw));
}

export class ShareCrypto {
  static randomBytes(n: number): number[] {
    return Array.from(cryptoFramework.createRandom().generateRandomSync(n).data);
  }

  static async seal(plaintext: string): Promise<Sealed> {
    const raw: number[] = ShareCrypto.randomBytes(KEY_BYTES);
    const iv: number[] = ShareCrypto.randomBytes(IV_BYTES);
    const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, await aesKey(raw), gcmParams(iv, new Array<number>(TAG_BYTES).fill(0)));
    const body: number[] = toArray(await cipher.update(blob(utf8Encode(plaintext))));
    const tag: number[] = toArray(await cipher.doFinal(null));   // GCM encrypt: doFinal returns the auth tag
    return new Sealed(base64UrlEncode(iv.concat(body, tag)), base64UrlEncode(raw));
  }

  // undefined if the key is wrong or the data was changed (GCM tag check fails).
  static async open(ciphertext: string, key: string): Promise<string | undefined> {
    try {
      const all: number[] = base64UrlDecode(ciphertext);
      const raw: number[] = base64UrlDecode(key);
      if (all.length < IV_BYTES + TAG_BYTES || raw.length !== KEY_BYTES) {
        return undefined;
      }
      const iv: number[] = all.slice(0, IV_BYTES);
      const tag: number[] = all.slice(all.length - TAG_BYTES);
      const body: number[] = all.slice(IV_BYTES, all.length - TAG_BYTES);
      const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
      await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, await aesKey(raw), gcmParams(iv, tag));
      const plain: number[] = toArray(await cipher.update(blob(body))).concat(toArray(await cipher.doFinal(null)));
      return utf8Decode(plain);
    } catch (e) {
      return undefined;
    }
  }
}
