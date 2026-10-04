# Watch background monitoring on a real watch

> Status (4 Oct 2026): research only. The watch app monitors while it is on screen; nothing below is built.
> Moved here from the former `watch/README.md`.

**Question:** can a third-party wearable app keep reading heart rate and raising alarms after it leaves the screen,
and what would it need?

**Findings** (sources at the end of this section):

1. **Apps are suspended in the background.** "Typically, the application process is suspended after the application
   runs in the background for a while … After being suspended, the application process cannot use software resources
   (such as common events and timers) or hardware resources (such as CPU, network, GPS, and Bluetooth)." Only the
   constrained background task types keep it alive [B1].
2. **No continuous-task mode covers health monitoring.** The modes are `dataTransfer`, `audioPlayback`,
   `audioRecording`, `location`, `bluetoothInteraction`, `multiDeviceConnection`, `wifiInteraction` (system apps),
   `voip`, `taskKeeping`, and from API 22 `avPlaybackAndRecord` / `specialScenarioProcessing` (the latter phones,
   tablets and PCs only) [B2].
3. **Declaring a mode we don't use gets the app suspended.** "If an application requests a continuous task but does
   not carry out the relevant service, the system imposes restrictions … the application will be suspended when it
   returns to the background", and the same for a service that doesn't match the type [B2]. So "location" or
   "audioPlayback" as a keep-alive trick is not an option (and would fail store review).
4. **`taskKeeping`** ("computing tasks") is the only generic mode: from API 21 it works on non-PC devices only with the
   restricted ACL permission `ohos.permission.KEEP_BACKGROUND_RUNNING_SYSTEM`; on API 20 and earlier it is PC/2-in-1
   only [B2]. Our minimum is API 20, so it would also need a runtime guard (`backgroundTaskManager.isModeSupported`,
   API 21 [B3]). ACL permissions are granted by Huawei per app on request.
5. **A continuous task needs** `ohos.permission.KEEP_BACKGROUND_RUNNING`, the mode under `backgroundModes` in
   `module.json5`, and `startBackgroundRunning(context, mode, wantAgent)`; it shows a notification, and the user can
   end it by removing that notification. API 20 allows one task per UIAbility [B2].
6. **Deferred tasks** (`WorkSchedulerExtensionAbility`) can sync history on a schedule, not monitor: at most 10 tasks,
   minimum interval 2 h for an *active* app (up to 48 h, or never, for rarely used apps), 2 min per run [B4].
7. **Health Service Kit** (the system's own all-day heart-rate data) "provides a platform for ecosystem apps to access
   users' health and fitness data based on users' HUAWEI ID and authorization"; access is applied for in AppGallery
   Connect, restricted scopes such as heart rate and blood oxygen are **manually reviewed**, and the kit is
   "available only in the Chinese mainland" [H1][H2]. The HarmonyOS atomic-service page lists phones and tablets
   and says it is not supported on the emulator [H1]; the HMS page lists WATCH 3/4 on HarmonyOS 3.0+ [H2]. We could
   not load the current HarmonyOS-app guide page to confirm wearable support for API 20+ - **unverified**.
8. **Already works without approval:** system reminders (`reminderAgentManager`) fire while the app is frozen or
   closed (verified on the emulator, the watch's daily medication reminder); the sensor and alarm logic runs while the
   app is on screen.

**Recommended production design** (unchanged in spirit, now with the constraints):
1. Foreground: our own loop, rules and upload, as today (with the energy savings in the root README, "Watch app").
2. Background: the **system** keeps measuring HR all day; the app reads that history through **Health Service Kit**
   on open and from a deferred task (≥ 2 h), and uploads it through the same outbox.
3. Live alarms while the app is closed: the system's own HR alarms, forwarded to the phone by Wear Engine
   (to confirm in `docs/research/phone-watch-link.md`, stream S7).
4. Only if Huawei grants the ACL: a `taskKeeping` continuous task during an explicit "monitor me now" session
   (e.g. after a risky drug), shown as a notification, ended by the user.

**Needs:**
- AppGallery Connect project for `ai.celia.watch`, signed with a release profile.
- Health Service Kit application (developer qualifications, heart-rate / SpO2 scopes → manual review); account in
  the Chinese mainland region, or a decision to ship there first.
- Confirmation from Huawei that Health Service Kit reads all-day HR on HarmonyOS 6 wearables (API 20+).
- Optional: ACL `ohos.permission.KEEP_BACKGROUND_RUNNING_SYSTEM` request with a medical justification, a
  `backgroundModes: ["taskKeeping"]` declaration and `KEEP_BACKGROUND_RUNNING`.
- Wear Engine access (phone side) for live system alarms.
- A real HarmonyOS watch for every item above (the emulator has no HR sensor, wear sensor or Health app).

**Sources** (read 2026-10-04):
- [B1] OpenHarmony docs, *Background Tasks overview*,
  `en/application-dev/task-management/background-task-overview.md` (gitcode.com/openharmony/docs)
- [B2] same repo, *Continuous Task (ArkTS)*, `en/application-dev/task-management/continuous-task.md`
- [B3] same repo, `en/application-dev/reference/apis-backgroundtasks-kit/js-apis-resourceschedule-backgroundTaskManager.md`
- [B4] same repo, *Deferred Task*, `en/application-dev/task-management/work-scheduler.md`
- [S1] same repo, `en/application-dev/device/sensor/sensor-guidelines.md` and
  `reference/apis-sensor-service-kit/js-apis-sensor.md` (`Options.interval`)
- [S2] same repo, `en/application-dev/reference/apis-network-kit/js-apis-http.md`
- [H1] Huawei, *Health Service Kit - About This Kit* (atomic services),
  https://developer.huawei.com/consumer/en/doc/atomic-guides/health-service-kit-ability-as
- [H2] Huawei, *Introduction to Health Service Kit*,
  https://developer.huawei.com/consumer/en/doc/HMSCore-Guides/description-0000001558389985
- Remote Communication Kit: the DevEco SDK's `hms/ets/api/@hms.collaboration.rcp.d.ts` and
  `hms/ets/api/device-define/wearable-hmos.json`
