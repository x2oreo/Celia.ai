---
name: arkts-language
description: ArkTS language rules for HarmonyOS (.ets files) — the strict, statically-typed TypeScript dialect. Use whenever writing or fixing ArkTS code, porting TS/JS logic into a HarmonyOS app, or when the compiler reports `arkts-no-*` / 106050xx errors. Covers what TS features are banned and the idiomatic replacement, async/concurrency (TaskPool, Worker), error handling, and JSON.
---

# ArkTS language

ArkTS = TypeScript with dynamic features removed so the Ark compiler can AOT-compile it. Files: `.ets`
(ArkTS + ArkUI) and `.ts` (still checked). **Code that compiles in tsc often fails in ArkTS.** Write
it strict from the start; don't "write TS then fix".

Docs: `typescript-to-arkts-migration-guide`, `arkts-more-cases` (see `harmonyos-docs`).

## Banned → use instead

| Banned (rule id) | Replacement |
|---|---|
| `any`, `unknown` (arkts-no-any-unknown) | Concrete type, union, generic, or `Object`/`ESObject` only at interop edges |
| Untyped object literal `const o = {a: 1}` (arkts-no-untyped-obj-literals) | Declare `interface`/`class` and annotate: `const o: Point = { x: 1, y: 2 }` |
| Object literal *as a type* `let p: {x: number}` (arkts-no-obj-literals-as-types) | Named `interface` |
| Index signature `{[k: string]: T}` (arkts-no-indexed-signatures) | `Record<string, T>` (literal keys must be quoted strings) or `Map<K,V>` |
| Dynamic prop access `obj[key]` on class objects (arkts-no-props-by-index) | `Record`/`Map`, or explicit fields |
| Destructuring `const {a, b} = o`, `[x, y] = arr`, destructured params (arkts-no-destruct-*) | `const a = o.a`; pass a typed options object |
| `var` (arkts-no-var) | `let` / `const` |
| `function () {}` expressions (arkts-no-func-expressions) | Arrow functions |
| `this` in standalone functions (arkts-no-standalone-this) | Class methods |
| Structural typing — assigning unrelated class with same shape (arkts-no-structural-typing) | Common `interface` both implement / explicit conversion |
| `delete obj.x` (arkts-no-delete) | Optional field set to `undefined`, or `Map.delete` |
| `for (k in obj)` (arkts-no-for-in) | `for...of` over arrays / `Object.keys()` / `Map.forEach` |
| `in` operator (arkts-no-in) | `instanceof`, or a discriminator field |
| `typeof x` in type position, `as const`, conditional/mapped/intersection types, `keyof` tricks | Explicit types; utility types allowed: `Partial`, `Required`, `Readonly`, `Record` |
| Spread of objects `{...a, b}` (arkts-no-spread for non-arrays) | Construct new object explicitly / `Object.assign` into typed target |
| `throw 'msg'` (arkts-limited-throw) | `throw new Error('msg')` |
| `catch (e: BusinessError)` type annotation | `catch (e) { const err = e as BusinessError; err.code; err.message }` |
| Class expressions, declaration merging, namespaces as values, `globalThis`, `Symbol()` (except `Symbol.iterator`), generators, `with`, `require`, `import x = ` | Plain classes/modules; ES `import`; `AppStorage` for global state |
| Uninitialized class fields | Initialize in declaration or constructor (strictPropertyInitialization + strictNullChecks always on) |
| Implicit `any` in callbacks of untyped APIs | Annotate params: `(err: BusinessError, data: string) => {}` |

## JSON

```ts
interface User { id: number; name: string }
const u: User = JSON.parse(text) as User;            // cast, no runtime validation
const body: string = JSON.stringify(u);
```
Nested JSON → interfaces for every level. For unknown-shape JSON use `Record<string, Object>`.

## Errors

Most system APIs throw/reject `BusinessError` from `@kit.BasicServicesKit` with numeric `code`:

```ts
import { BusinessError } from '@kit.BasicServicesKit';
try { ... } catch (e) {
  const err = e as BusinessError;
  hilog.error(0x0000, 'TAG', `fail ${err.code} ${err.message}`);
}
promise.then(...).catch((err: BusinessError) => { ... });
```
Look up error codes in the module's API reference ("Error Codes" page).

## Async & concurrency

- `async/await` + `Promise` fine on UI thread for I/O (http, file, RDB are async natively).
- CPU-heavy work → **TaskPool** (preferred) or **Worker**. Functions sent to TaskPool must be
  top-level and marked `@Concurrent`; args must be serializable or `@Sendable` classes.

```ts
import { taskpool } from '@kit.ArkTS';
@Concurrent
function heavy(n: number): number { let s = 0; for (let i = 0; i < n; i++) s += i; return s; }
const r = await taskpool.execute(heavy, 1_000_000) as number;
```
- No shared memory between threads except `SharedArrayBuffer` / `@Sendable` objects.
- Timers: `setTimeout`/`setInterval` exist. No `fetch`, no DOM, no Node APIs (`fs`, `path`, `process`).

## Logging

```ts
import { hilog } from '@kit.PerformanceAnalysisKit';
hilog.info(0x0000, 'MyTag', 'value=%{public}s', String(v));   // %{public} or it prints <private>
```
`console.info/error` also works (lands in hilog, tag `JSAPP`). Filter with `hdc hilog | grep MyTag`.

## Modules

- `.ets` may import `.ts`/`.js`; `.ts` must NOT import `.ets`.
- System APIs: `import { x } from '@kit.SomeKit'` (modern). Legacy `@ohos.xxx` still compiles; prefer kits.
- 3rd-party: ohpm packages (`oh-package.json5`), not npm. Pure-JS npm libs usually fail strict checks;
  look for an ohpm port (`@ohos/axios`, `@ohos/crypto-js`, `@ohos/lottie`...).

## Self-check before compiling

1. Any object literal without a declared type? 2. Any destructuring? 3. Any `any`/`unknown`/index
signature? 4. Every callback param typed? 5. Fields initialized? 6. Thrown values are `Error`?
