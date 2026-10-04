---
name: harmonyos-app-model
description: HarmonyOS project structure and Stage application model - app.json5, module.json5, build-profile.json5, oh-package.json5, hvigorfile.ts, UIAbility/ExtensionAbility lifecycle, windows, Want, context, permissions (declare + runtime request), HAP/HAR/HSP module types, atomic services. Use when creating/editing project config, adding abilities or permissions, or when an app crashes on launch / API returns 201 (permission denied).
---

# Stage model & project layout

```
MyApp/
├─ AppScope/app.json5               # bundleName, versionCode/Name, icon, label (app-wide)
├─ AppScope/resources/
├─ build-profile.json5              # products, signingConfigs, targetSdkVersion/compatibleSdkVersion, modules list
├─ hvigorfile.ts / hvigor/hvigor-config.json5
├─ oh-package.json5                 # project deps (ohpm)
└─ entry/                           # main module (HAP, type "entry")
   ├─ build-profile.json5, hvigorfile.ts, oh-package.json5
   └─ src/main/
      ├─ module.json5               # abilities, permissions, pages, deviceTypes
      ├─ ets/entryability/EntryAbility.ets
      ├─ ets/pages/Index.ets
      └─ resources/base/{element,media,profile}/   # profile/main_pages.json lists @Entry pages
```

Module types: **HAP** `entry` (installable main) / `feature`; **HAR** static library (compiled in);
**HSP** shared dynamic library. Hackathon: one `entry` HAP is enough.

Atomic service ("meta-service", 元服务): install-free, small, launched from search/cards. Separate
project template in DevEco ("Atomic Service"). Different signing/limits - only pick if the idea needs it.

## module.json5 essentials

```json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    "mainElement": "EntryAbility",
    "deviceTypes": ["phone", "tablet", "2in1"],      // 2in1 = PC/foldable PC; also "wearable", "tv", "car"
    "pages": "$profile:main_pages",
    "abilities": [{
      "name": "EntryAbility",
      "srcEntry": "./ets/entryability/EntryAbility.ets",
      "exported": true,
      "launchType": "singleton",
      "continuable": true,                            // for cross-device continuation
      "skills": [{ "entities": ["entity.system.home"], "actions": ["ohos.want.action.home"] }]
    }],
    "requestPermissions": [
      { "name": "ohos.permission.INTERNET" },
      { "name": "ohos.permission.CAMERA",
        "reason": "$string:camera_reason",
        "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" } }
    ]
  }
}
```
Keys change between API levels - verify against `module-configuration-file` doc.

## UIAbility lifecycle

```ts
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {}
  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => { /* err.code */ });
  }
  onForeground(): void {}
  onBackground(): void {}
  onWindowStageDestroy(): void {}
  onDestroy(): void {}
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {}   // singleton relaunch
}
```
Context in a component: `this.getUIContext().getHostContext() as common.UIAbilityContext`
(older: `getContext(this)`). Start another ability: `context.startAbility(want)`.
ExtensionAbilities: `FormExtensionAbility` (widgets), `BackupExtensionAbility`,
`WorkSchedulerExtensionAbility`, `AgentExtensionAbility` (HMAF agent, see harmonyos-kits), etc.

## Permissions - three steps (not Android manifest!)

1. Declare in `module.json5` `requestPermissions` (user_grant ones need `reason` + `usedScene`).
2. Check + request at runtime (user_grant only: CAMERA, MICROPHONE, LOCATION, APPROXIMATELY_LOCATION,
   READ_CALENDAR, ACTIVITY_MOTION, DISTRIBUTED_DATASYNC, ...):
```ts
import { abilityAccessCtrl, Permissions, common } from '@kit.AbilityKit';
const perms: Permissions[] = ['ohos.permission.CAMERA'];
const atManager = abilityAccessCtrl.createAtManager();
const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
const res = await atManager.requestPermissionsFromUser(ctx, perms);
const granted = res.authResults.every((r: number) => r === 0);
```
3. If denied permanently → `atManager.requestPermissionOnSetting(ctx, perms)`.
`ohos.permission.INTERNET` is system_grant (declare only). Location requires APPROXIMATELY_LOCATION
together with LOCATION. Some permissions are ACL/restricted - avoid in a 24h hackathon.

Many features avoid permissions entirely via **pickers / security controls**: `PhotoViewPicker`,
`DocumentViewPicker`, `SaveButton`, `PasteButton`, `LocationButton`, camera picker
(`cameraPicker.pick`). Prefer these - faster, no review, nicer UX.

## Versions

`build-profile.json5` → `"compatibleSdkVersion": "6.0.0(20)"` (**task rule: min API must be 20 - don't raise it**),
`"targetSdkVersion"` may be higher. Any API newer than 20 needs a runtime guard (`canIUse('SystemCapability.X')`
or `deviceInfo.sdkApiVersion`) + fallback, or the app breaks on API 20 devices. Must be ≤ the
device's API level (check: `hdc shell param get const.ohos.apiversion`). If event devices run an older
release, lower `compatibleSdkVersion` and avoid newer APIs (docs mark "Since API x").
