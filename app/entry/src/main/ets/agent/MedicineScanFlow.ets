// OWNER: Kaloyan — "show Celia the medicine box".
//   1. On-device OCR (Core Vision) → every word is looked up in DrugChecker → known medicines become candidates.
//   2. Nothing recognised (or OCR unavailable) → downscaled JPEG → /vision-extract, which only READS names.
//   3. The user confirms one candidate; only then does the agent check it (confirmCandidate → AgentCore).
// Neither OCR nor the vision model ever decides risk.

import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { OcrService } from '../drugs/OcrService';
import { DrugChecker } from '../drugs/DrugChecker';
import { DrugVerdict } from '../model/DrugVerdict';
import { AgentReply } from '../model/AgentTypes';
import { BackendClient } from './BackendClient';
import { AgentCore } from './AgentCore';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('MedicineScan');

const MAX_TOKENS: number = 60;
const MAX_CANDIDATES: number = 5;
const MAX_IMAGE_SIDE: number = 1280;

export type ScanSource = 'ON_DEVICE_OCR' | 'CLOUD_VISION' | 'NONE';

export interface ScanCandidate {
  name: string;        // as printed on the box
  ingredient: string;  // resolved INN, '' if not in the list
  risk: string;        // RiskLevel of the drug alone (the full check happens after confirmation)
}

export interface ScanOutcome {
  source: ScanSource;
  candidates: ScanCandidate[];
  message: string;     // what to show when there are no candidates
}

interface VisionDrug {
  name: string;
  strength: string;
  confidence: string;
}

interface VisionResponse {
  drugs: VisionDrug[];
  imageQuality: string;
}

interface VisionRequest {
  imageBase64: string;
}

// Words from OCR text that could be medicine names (letters only, ≥ 4 chars, de-duplicated). Pure, unit-tested.
export function ocrTokens(text: string): string[] {
  const seen: Set<string> = new Set<string>();
  const out: string[] = [];
  const words: string[] = text.toLowerCase().split(/[^a-ząćęłńóśźż]+/);
  for (const w of words) {
    if (w.length >= 4 && !seen.has(w)) {
      seen.add(w);
      out.push(w);
      if (out.length >= MAX_TOKENS) {
        break;
      }
    }
  }
  return out;
}

async function resolveNames(names: string[], keepUnknown: boolean): Promise<ScanCandidate[]> {
  const out: ScanCandidate[] = [];
  const seen: Set<string> = new Set<string>();
  for (const name of names) {
    const v: DrugVerdict = await DrugChecker.get().check(name);
    const key: string = v.ingredient !== '' ? v.ingredient : name.toLowerCase();
    if ((v.ingredient === '' && !keepUnknown) || seen.has(key)) {
      continue;
    }
    seen.add(key);
    const c: ScanCandidate = { name: name, ingredient: v.ingredient, risk: v.risk };
    out.push(c);
    if (out.length >= MAX_CANDIDATES) {
      break;
    }
  }
  return out;
}

function outcome(source: ScanSource, candidates: ScanCandidate[], message: string): ScanOutcome {
  const o: ScanOutcome = { source: source, candidates: candidates, message: message };
  return o;
}

export class MedicineScanFlow {
  static async scan(pixelMap: image.PixelMap): Promise<ScanOutcome> {
    // 1. On-device first.
    const text: string = await OcrService.get().recognize(pixelMap);
    if (text.length > 0) {
      const found: ScanCandidate[] = await resolveNames(ocrTokens(text), false);
      if (found.length > 0) {
        return outcome('ON_DEVICE_OCR', found, '');
      }
    }
    // 2. Cloud fallback: names only.
    if (!BackendClient.available()) {
      return outcome('NONE', [], 'I couldn\'t read a medicine name. Try again in better light, or type the name.');
    }
    const jpeg: string = await MedicineScanFlow.toJpegBase64(pixelMap);
    if (jpeg.length === 0) {
      return outcome('NONE', [], 'I couldn\'t process the photo. Please type the medicine name.');
    }
    const req: VisionRequest = { imageBase64: jpeg };
    const raw: string | undefined = await BackendClient.postJson('vision-extract', JSON.stringify(req), 25000);
    if (raw === undefined) {
      return outcome('NONE', [], 'I couldn\'t read the box right now. Please type the medicine name.');
    }
    let res: VisionResponse;
    try {
      res = JSON.parse(raw) as VisionResponse;
    } catch (e) {
      log.warn('vision-extract returned invalid JSON');
      return outcome('NONE', [], 'I couldn\'t read the box. Please type the medicine name.');
    }
    if (!Array.isArray(res.drugs) || res.drugs.length === 0) {
      return outcome('CLOUD_VISION', [], 'I can\'t see a medicine name on this photo. Try a closer shot of the box.');
    }
    const names: string[] = res.drugs
      .filter((d: VisionDrug) => typeof d.name === 'string' && d.name.trim().length > 0)
      .map((d: VisionDrug) => d.name.trim().slice(0, 80));
    // Keep unknown names: the user should see what was read; the check will say UNKNOWN_DRUG, never "safe".
    return outcome('CLOUD_VISION', await resolveNames(names, true), '');
  }

  // The user tapped "Yes, that's it" on a candidate. The full check (interactions, explanation) runs in the agent.
  static async confirmCandidate(candidate: ScanCandidate): Promise<AgentReply> {
    const name: string = candidate.ingredient !== '' ? candidate.ingredient : candidate.name;
    return await AgentCore.get().send(`I scanned a medicine box: ${name}. Can I take it?`);
  }

  private static async toJpegBase64(pixelMap: image.PixelMap): Promise<string> {
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      const info: image.ImageInfo = await pixelMap.getImageInfo();
      const longest: number = Math.max(info.size.width, info.size.height);
      if (longest > MAX_IMAGE_SIDE) {
        const f: number = MAX_IMAGE_SIDE / longest;
        await pixelMap.scale(f, f); // in place: OCR has already used the full-size image
      }
      const opts: image.PackingOption = { format: 'image/jpeg', quality: 80 };
      const data: ArrayBuffer = await packer.packToData(pixelMap, opts);
      return new util.Base64Helper().encodeToStringSync(new Uint8Array(data));
    } catch (e) {
      log.warn(`JPEG encode failed: ${String(e)}`);
      return '';
    } finally {
      packer.release();
    }
  }
}
