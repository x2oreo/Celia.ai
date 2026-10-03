---
name: harmonyos-build-deploy
description: Build, sign, install, run and debug HarmonyOS apps from the terminal and DevEco Studio — DevEco install/setup on macOS, hvigorw build commands, ohpm packages, hdc device commands (install, launch, logs, screenshots, files), emulator, automatic signing, CI-style loops. Use whenever Claude needs to compile, deploy to a device/emulator, read hilog, or fix build/sign/install errors.
---

# Build & deploy toolchain

| Tool | Role | Android analogue |
|---|---|---|
| DevEco Studio | IDE (IntelliJ-based), SDK manager, emulator, previewer, auto-signing | Android Studio |
| hvigor / `hvigorw` | Build system (TS config: `hvigorfile.ts`) | Gradle |
| ohpm | Package manager, `oh-package.json5`, registry ohpm.openharmony.cn | npm/maven |
| hdc | Device bridge | adb |
| hilog | Logging | logcat |
| codelinter | ArkTS lint | lint |

## Setup (macOS, Apple Silicon OK)

1. HUAWEI ID at developer.huawei.com (do it NOW — **overseas accounts need real-name/identity
   verification to use the emulator**, review can take time). Ask Huawei mentors at HackYeah if blocked;
   they likely bring devices/accounts.
2. Download DevEco Studio (Download Center, login required) → install to `/Applications`.
   Bundles SDK, Node, hvigor, ohpm, emulator. Standalone "Command Line Tools" package may be
   CN-account-only — just use the IDE's bundled tools.
3. First launch: sign in (top-right), let it download SDK, create project via
   *File → New → Create Project → Empty Ability* (Application, ArkTS, Stage model).

## Terminal env (so Claude can build without clicking)

Tool locations differ between DevEco versions — discover, don't guess:
```bash
DEVECO=/Applications/DevEco-Studio.app/Contents
find "$DEVECO" -maxdepth 5 \( -name hvigorw -o -name ohpm -o -name hdc -o -name 'hvigorw.js' \) -type f 2>/dev/null
```
Typical (5.x/6.x): `$DEVECO/tools/hvigor/bin/hvigorw`, `$DEVECO/tools/ohpm/bin/ohpm`,
`$DEVECO/tools/node/bin/node`, `$DEVECO/sdk/default/openharmony/toolchains/hdc`.
```bash
export DEVECO_SDK_HOME="$DEVECO/sdk"
export PATH="$DEVECO/tools/hvigor/bin:$DEVECO/tools/ohpm/bin:$DEVECO/tools/node/bin:$DEVECO/sdk/default/openharmony/toolchains:$PATH"
```
Put this in a project `env.sh` and `source` it in each Bash call (shell state doesn't persist).
Use DevEco's bundled node for hvigor, not the system node.

## Build

```bash
ohpm install                                              # deps (run in project root)
hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon
hvigorw --mode module -p product=default -p buildMode=release assembleHap   # release
hvigorw clean
hvigorw --mode project -p product=default assembleApp     # .app for store (not needed at hackathon)
```
Output: `entry/build/default/outputs/default/entry-default-signed.hap` (or `-unsigned.hap` if no
signingConfig). Compile errors print file:line + rule id (`arkts-no-...`) → see `arkts-language`.
If CLI build complains about missing `buildConfig.json`/SDK, do one build from the IDE first.

## Signing

Debug on emulator or real device needs a signature. Easiest: DevEco *File → Project Structure →
Signing Configs → Automatically generate signature* (logged-in HUAWEI ID, device connected for real
devices). It writes `signingConfigs` into root `build-profile.json5` (paths to .p12/.cer/.p7b in
`~/.ohos/config`). Don't commit those secrets publicly — judges need the repo, not your certs.
Changing devices → regenerate. "Signature mismatch" on install → `hdc uninstall <bundle>` first.

## Device / emulator (hdc)

```bash
hdc list targets                                  # connected devices / emulator
hdc -t <serial> <cmd>                             # pick device when several
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc uninstall com.example.app
hdc shell aa start -a EntryAbility -b com.example.app
hdc shell aa force-stop com.example.app
hdc shell param get const.ohos.apiversion          # device API level
hdc shell bm dump -n com.example.app              # installed bundle info
hdc shell snapshot_display -f /data/local/tmp/s.jpeg && hdc file recv /data/local/tmp/s.jpeg ./s.jpeg  # screenshot
hdc file send ./local /data/local/tmp/x ; hdc file recv /data/local/tmp/x ./x
hdc tconn 192.168.x.x:port                        # wireless debugging (enable in Developer options)
```
Real phone: Settings → About → tap build number 7× → Developer options → USB debugging.

Emulator: DevEco *Device Manager* → create Phone/Tablet/2in1/Foldable → start. Needs login +
(overseas) verified account. Some kits (Map, Push, Account, Payment, parts of Core Vision/Speech,
Agent Framework) need a real device and/or AppGallery Connect config — check doc "Constraints".

## Logs

```bash
hdc shell hilog -r                                # clear buffer
hdc hilog | grep -i "MyTag"                       # stream, filter by tag
hdc hilog -L E                                    # errors only (hilog flags vary; see `hdc shell hilog -h`)
hdc shell ls /data/log/faultlog/faultlogger/      # crash (cppcrash/jscrash) files → hdc file recv
```
JS crash stack points to compiled `.ts`/`.ets` lines; open the jscrash file, find `at ... (entry/src/main/ets/...)`.

## Fast inner loop for Claude

```bash
source env.sh && hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon \
 && hdc install -r entry/build/default/outputs/default/entry-default-signed.hap \
 && hdc shell aa start -a EntryAbility -b $(grep -o '"bundleName": *"[^"]*"' AppScope/app.json5 | cut -d'"' -f4)
```
Then screenshot via `snapshot_display` + Read the jpeg to verify UI visually.

## Tests (judges want "some tests")

Unit tests: `entry/src/test/` (local, no device) and instrumented `entry/src/ohosTest/` (on device/emulator),
framework `@ohos/hypium` (`describe/it/expect`). Put pure logic (drug lookup, rule engine, AI-output validators)
in plain `.ets` classes without UI so they're testable locally. Run from DevEco (gutter ▶) or CLI — verify the
exact hvigor test task name in Context7 (`ide-hvigor-commandline`, search "test"). Paste results into README.

## Release .hap for judges

Deliverable is a working `.hap`. Build signed debug (or release) HAP, copy to `release/<app>-<version>.hap` or
attach to a GitHub Release, and document install: `hdc install -r <file>.hap`. Debug signatures are tied to our
HUAWEI ID profile (real devices: registered UDIDs) — another machine may reject the install. Ask mentors which
signing judges expect; always also document the build-from-source path in README.

## ohpm

```bash
ohpm install @ohos/axios          # adds to oh-package.json5 dependencies
ohpm uninstall <pkg>
ohpm config set registry https://ohpm.openharmony.cn/ohpm/
```
Check package supports your API level and ArkTS strict mode before relying on it.

## Common failures

- `Cannot find module '@kit.X'` / unknown API → SDK too old or API > compatibleSdkVersion.
- Installs but white screen → crash in `aboutToAppear`/build; read hilog / faultlog.
- `201` error code at runtime → permission not declared/granted (`harmonyos-app-model`).
- Kit returns "service not supported" on emulator → needs real device.
- hvigor daemon weirdness → `--no-daemon`, `hvigorw clean`, delete `.hvigor/` and `build/`.
