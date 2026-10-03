# Running Celia on a real Huawei phone

Everything needed to get the phone app from this repo onto a physical device. The emulator path is in the
[README](../README.md#build--run); this file is only about a real phone.

Short version, once the one-time setup below is done:

```bash
app/scripts/device.sh check   # preflight: phone, API level, signing, backend
app/scripts/device.sh         # build → install → launch → screenshot
```

## 1. What the phone must be

| Requirement | Why |
|---|---|
| **HarmonyOS 6.0 or newer** (API 20+) | `compatibleSdkVersion` is `6.0.0(20)` — a hard task requirement. Phones on HarmonyOS 4.x / EMUI (Android-based) cannot install the app at all. Check: Settings → About phone → HarmonyOS version. |
| Developer mode on | Settings → About phone → tap **Build number** 7× → back → System → **Developer options** → **USB debugging** on. |
| USB cable that carries data | Accept the "Allow USB debugging?" prompt on the phone when it appears. |
| A screen lock (PIN) | Only for App lock (F-46); the rest works without it. |

`deviceTypes` is `["phone"]`, so tablets and 2-in-1s are refused by the installer.

## 2. One-time setup on the laptop

1. **Connect and check the bridge**
   ```bash
   source app/env.sh
   hdc list targets          # the phone shows up as a serial number; the emulator is 127.0.0.1:5555
   ```
   Nothing listed → replug, re-accept the prompt, or `hdc kill && hdc start`.
   Wireless instead of USB: Developer options → Wireless debugging → `hdc tconn <ip>:<port>`.

2. **Sign the app** (a real phone refuses unsigned HAPs — the emulator does not, which is why it worked there)
   - Open `app/` in DevEco Studio, sign in with a Huawei ID (top right). Overseas accounts need identity
     verification before signing works.
   - With the phone connected: File → Project Structure → Signing Configs → **Automatically generate signature**.
     DevEco registers the phone's UDID in a debug profile and writes a `signingConfigs` entry into
     `app/build-profile.json5`.
   - That hunk holds local cert paths and encrypted passwords. Keep it out of git:
     ```bash
     git update-index --skip-worktree app/build-profile.json5
     git config core.hooksPath .githooks      # pre-commit hook refuses signing material
     ```
   - The debug profile is tied to **this Huawei ID and this phone**. Another phone → connect it and generate again.
     A HAP signed for one phone will not install on another.

3. **Point the app at the deployed backend**
   `127.0.0.1` on a phone is the phone itself, so the local dev backend is unreachable there. In the gitignored
   `app/entry/src/main/ets/common/LocalConfig.ets`:
   ```ts
   static readonly BACKEND_URL: string = 'https://<project-ref>.supabase.co';   // no trailing slash, no /functions/v1
   static readonly SUPABASE_ANON_KEY: string = '<publishable key>';             // SUPABASE_PUBLISHABLE_KEY in .env.local
   ```
   Use the publishable key only — never the secret key or the OpenAI key; those stay in Supabase function secrets.
   Leaving both empty is fine: the app then runs fully offline. A placeholder key such as `local-dev` also breaks
   share links (card QR, doctor report), because they fall back to the same key.

## 3. Install

```bash
app/scripts/device.sh
```

It stops with a clear message when the phone is missing, below API 20, unsigned, or the backend points at the laptop.
Several devices attached (phone + emulator is handled; two phones is not): `HDC_TARGET=<serial> app/scripts/device.sh`.

By hand:
```bash
source app/env.sh && cd app
hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon
hdc -t <serial> install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc -t <serial> shell aa start -a EntryAbility -b com.celiaai.app
```

## 4. What to test on the phone

Works the same as on the emulator — run the [README feature table](../README.md#how-to-verify-each-feature-emulator)
once. The items below are the ones a real phone adds or changes:

| Area | On a real phone |
|---|---|
| Barcode / box scan (F-36) | Real camera. Scan a Polish medicine box; an unknown box opens "teach this barcode". |
| Voice (agent, live voice) | Real microphone — grant the permission on first use. Needs the backend. |
| Read the card aloud (T25) | On-device voice if the phone has an English TTS voice, cloud `/speak` otherwise. |
| Location / travel banner (T23) | Real position — grant "while in use". The country is resolved on the phone; nothing is uploaded. |
| App lock (F-46) | Fingerprint / face / PIN via the system prompt. Needs a screen lock set. |
| Haptics | CPR metronome (110/min) and alert vibration are only felt on hardware. |
| SOS call | **The call button opens the real dialler with the real emergency number. Do not place the call.** Use Settings → Test SOS. |
| Widgets (F-12) | Long-press the home screen → add "Check a medicine" (2×2) and "Medical alert" (2×4). |
| Celia intents (F-11) | Only testable here: ask Celia/Xiaoyi "can I take ibuprofen". Needs a region and system version where Celia routes to third-party intents — not guaranteed. |
| Reminders (F-38) | System agent reminders need an AppGallery Connect quota; without it the in-app fallback notifies while the app runs. |
| Emergency card QR | Scan it with a second phone on mobile data to prove the link works off the local network. |
| Watch pairing | Heart data stays `SIMULATED` unless a paired watch app uploads to the same Supabase project. |

## 5. When it fails

| Symptom | Cause → fix |
|---|---|
| `hdc list targets` → `[Empty]` | USB debugging off, prompt not accepted, charge-only cable. |
| Only `entry-default-unsigned.hap` is built | No signing config (§2.2). |
| `install failed due to the signature is invalid` / `no signature file` | Unsigned HAP, or the profile does not contain this phone's UDID → regenerate the signature with this phone connected. |
| `signature mismatch` / `install failed due to check signature` | An older build signed with another identity is installed → `hdc uninstall com.celiaai.app`, install again (this wipes app data). |
| `compatibleSdkVersion ... higher than the device` | Phone is below HarmonyOS 6.0. No workaround — the minimum API is a task rule. |
| Installs, white screen | Crash at launch: `hdc hilog \| grep -i celiaai`, crash files in `/data/log/faultlog/faultlogger/`. |
| Agent says it is offline | `BACKEND_URL` empty or `127.0.0.1`, or the phone has no internet. |
| Share link / card QR fails to upload | `SUPABASE_ANON_KEY` is a placeholder (§2.3). |
| A feature returns error `201` | Permission denied — grant it in Settings → Apps → Celia. |

## 6. Verified before a phone was attached (3 Oct 2026)

| Check | Result |
|---|---|
| Phone unit tests (`app/scripts/test.sh`) | 206 run, 0 failures |
| Backend tests (`deno test backend/supabase/functions/`) | 68 passed, 0 failed |
| Strict ArkTS build (`assembleHap`) | builds; unsigned HAP, 7.3 MB |
| Install + launch on the emulator (API 24) | Home renders, no crash log |
| Deployed edge functions | all 11 respond; `drug-check` returns `KNOWN_RISK` for clarithromycin with the publishable key |
| `device.sh check` | correctly refuses: no phone, no signing, laptop-only backend |

Not verified, because it needs the hardware and a Huawei ID: the signed build, the install on a phone, and every row
of §4.
