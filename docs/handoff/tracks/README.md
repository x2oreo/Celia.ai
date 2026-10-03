# Workstream A — parallel tracks

Workstream A (`docs/handoff/KALOYAN_agent_and_ui.md`) is split into three build tracks that run at the same time,
each in its own git worktree and branch, plus one integrator. Read this file first, then your track file.

| Track | Branch | Worktree | Brief |
|---|---|---|---|
| T1 Agent home | `kaloyan/t1-agent-home` | `../Celia.ai-wt/t1` | `T1_agent_home.md` (A3 → A1 → A2) |
| T2 Agent brain | `kaloyan/t2-agent-brain` | `../Celia.ai-wt/t2` | `T2_agent_brain.md` (A4, A10) |
| T3 Screens | `kaloyan/t3-screens` | `../Celia.ai-wt/t3` | `T3_screens.md` (A5, A6) |
| T0 Integrator | `kaloyan/agent-home` | main checkout | merges, emulator regression, A9 / A11 research, docs |

## Scope change from the owner (overrides the workstream brief)

**The visual look is not ours.** The owner designs it in Claude Design and hands it over later. Until then:

- Do: structure, navigation, wiring, logic, accessibility, agent quality, tests.
- Do not: add or change colours, gradients, type sizes, radii, shadows or spacing tokens; restyle a screen; change
  how the orb looks; touch the watch look (A7) or dark mode (A8).
- New layout is composed from components and tokens that already exist (`components/Common.ets`,
  `resources/base/element/*.json`). Keep the look of each new piece inside one small `@Builder` or component so a
  later reskin touches one place.
- DESIGN.md gets structure only (what is on the screen, in what order, what a tap does), no new visual values.

## Rules for every track

- Read `CLAUDE.md`, then `docs/handoff/KALOYAN_agent_and_ui.md` sections 3, 4 and 7. Load the skills it names before
  writing HarmonyOS code. Verify unfamiliar APIs in Context7.
- **Files:** edit only the files your track owns. If you need a change in a file another track owns, do not edit
  it: write the request under "Needs from other tracks" in your log file and tell the owner.
- **Resources:** `string.json` is shared. Insert new keys next to related keys, never at the end of the file, so
  two branches do not collide on the same lines. No new entries in `color.json` or `float.json` (scope change).
- **Git:** commit small and often on your own branch, Conventional Commits, no AI attribution. Stage explicit paths.
  Push your branch. Never push `main` or `kaloyan/agent-home`; the integrator merges. Run
  `git fetch && git merge origin/kaloyan/agent-home` when the owner says a merge landed, and before you ask for one.
- **Before asking for a merge:** `app/scripts/test.sh` passes and `assembleHap` builds. Then tell the owner
  "T<n> ready to merge" with the commit hash and what to look at on the emulator.
- **Emulator:** there is one phone emulator for all tracks. `app/scripts/emu.sh up` starts it. Take the lock only for
  the install / tap / screenshot burst and release it straight after:
  `app/scripts/emu.sh lock T<n> && app/scripts/run.sh shot.jpeg; ...; app/scripts/emu.sh unlock`.
  Never hold it while you write code. The local AI backend on port 8000 is one process too: whoever holds the lock
  may restart it from their own worktree (commands in the workstream brief, section 7).
- **Log, not shared docs:** do not edit `AI_WORKFLOW.md` or `README.md`. Keep `docs/handoff/tracks/T<n>_LOG.md` in
  your branch with: what was asked, what was produced, what was validated and how (screenshot paths), what was not
  validated, README verify-table rows for new or moved features, and "Needs from other tracks". The integrator
  folds these into the real documents.
- **Honesty:** simulated things carry the `SIMULATED` badge; anything not seen working on the emulator is written
  down as unverified. Do not deploy functions or apply migrations; list what the owner must deploy.
- Do not stop at the first finished task. Work down your list in order; when blocked on another track, take the next
  item that is not blocked.

## Order and merge points

1. T1 finishes the `AgentPage` split (A3) first and asks for a merge straight away. T2 and T3 do not touch
   `pages/AgentPage.ets` or `components/agent/*` before that merge.
2. After that merge T2 adds its tiles and the camera change inside `components/agent/*` with small edits.
3. Integrator merges to `main` after each green regression, about every 2-3 hours.
4. Feature freeze Sunday 06:00. After that only fixes, the real-phone pass (08:00) and documents.
