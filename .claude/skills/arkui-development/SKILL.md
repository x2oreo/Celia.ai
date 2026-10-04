---
name: arkui-development
description: ArkUI declarative UI for HarmonyOS - @Entry/@Component(V2) structs, build(), layout containers, lists, state-management decorators (V1 @State/@Prop/@Link vs V2 @Local/@Param/@Event/@ObservedV2/@Trace), Navigation/NavPathStack routing, @Builder, resources, dialogs, animation, Web component. Use when building or debugging any HarmonyOS screen. Not React/Flutter/SwiftUI - do not port their idioms.
---

# ArkUI (declarative)

Looks like SwiftUI, behaves differently. Re-render is driven only by **decorated** state; plain fields
never refresh UI. Look up exact component attributes in Context7 `harmonyos-references` before using.

## Component skeleton (prefer V2 for new code)

```ts
@Entry                // only on page roots
@ComponentV2
struct Index {
  @Local count: number = 0;              // internal state
  build() {                               // exactly ONE root node
    Column({ space: 12 }) {
      Text(`Count ${this.count}`).fontSize(24).fontWeight(FontWeight.Bold)
      Counter({ value: this.count, onInc: () => this.count++ })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(16)
  }
}

@ComponentV2
struct Counter {
  @Param value: number = 0;               // read-only input from parent (needs default or @Require)
  @Event onInc: () => void = () => {};    // output callback
  build() { Button(`+1 (${this.value})`).onClick(() => this.onInc()) }
}
```

`build()` is NOT normal code: only UI components, `if/else`, `ForEach`/`LazyForEach`/`Repeat`, and
`@Builder` calls. No `let`, no `console.log`, no arbitrary statements inside it.

## State decorators - don't mix V1 and V2 in one component

| Purpose | V1 (`@Component`) | V2 (`@ComponentV2`) |
|---|---|---|
| Own state | `@State` | `@Local` |
| Parent → child one-way | `@Prop` | `@Param` (+ `@Once` to init only once, `@Require` to force) |
| Two-way parent↔child | `@Link` (`$var` / `this.var` ref) | `@Param` + `@Event` callback (or `!!` syntax) |
| Ancestor → descendant | `@Provide` / `@Consume` | `@Provider()` / `@Consumer()` |
| Deep-observed class | `@Observed` class + `@ObjectLink` | `@ObservedV2` class + `@Trace` fields |
| React to change | `@Watch('fn')` | `@Monitor('field')` method |
| Derived value | getter (not cached) | `@Computed get x()` |
| App-global | `AppStorage` + `@StorageLink/@StorageProp` | `AppStorageV2.connect(...)` |
| Persisted | `PersistentStorage.persistProp` | `PersistenceV2.connect(...)` |

Pitfalls LLMs hit:
- V1 `@State arr: Item[]` only re-renders on array ops (push/splice/reassign), NOT `arr[0].name = 'x'`.
  Fix: V1 `@Observed` + `@ObjectLink` child, or V2 `@ObservedV2` + `@Trace`.
- Replace objects immutably when unsure: `this.items = [...this.items, n]` (array spread is allowed).
- `@Param` is read-only in the child; mutate via `@Event`.
- Not `useState`, no hooks, no effects. Lifecycle: `aboutToAppear()`, `aboutToDisappear()`,
  page-only `onPageShow()/onPageHide()/onBackPress()` (for Navigation use NavDestination `onShown/onHidden`).

## Layout & common components

Containers: `Column`, `Row`, `Stack`, `Flex`, `RelativeContainer`, `Grid/GridItem`, `List/ListItem`,
`Scroll`, `Tabs/TabContent`, `WaterFlow`, `Swiper`, `SideBarContainer`.
Basics: `Text`, `Image($r('app.media.x'))`, `Button`, `TextInput`, `TextArea`, `Toggle`, `Slider`,
`Checkbox`, `Select`, `Progress`, `LoadingProgress`, `Search`, `Divider`, `Blank`, `Canvas`, `XComponent`,
`Video`, `Web` (`@kit.ArkWeb`), `RichEditor`, `Refresh` (pull-to-refresh).
Sizes: numbers = vp; strings `'100%'`, `'16fp'`; `layoutWeight(1)` = flex-grow.

Lists - big data → `LazyForEach` (needs an `IDataSource` impl) or V2 `Repeat(...).virtualScroll()`:
```ts
List({ space: 8 }) {
  ForEach(this.items, (it: Item) => {
    ListItem() { Text(it.title) }
  }, (it: Item) => it.id)                // key generator: ALWAYS provide stable key
}.layoutWeight(1)
```

Reuse UI: `@Builder` (function-like fragments), `@BuilderParam` (slots), `@Styles` / `@Extend(Text)`
(shared styling), `AttributeModifier` (dynamic styling).

## Navigation (current recommended; `router` is legacy)

```ts
@Entry @ComponentV2
struct Index {
  @Local stack: NavPathStack = new NavPathStack();
  @Builder pageMap(name: string, param: Object) {
    if (name === 'Detail') { DetailPage() }
  }
  build() {
    Navigation(this.stack) {
      Button('Open').onClick(() => this.stack.pushPathByName('Detail', 'id-42'))
    }
    .title('Home')
    .navDestination(this.pageMap)
  }
}

@ComponentV2
struct DetailPage {
  @Local id: string = '';
  build() {
    NavDestination() { Text(this.id) }
      .title('Detail')
      .onReady((ctx: NavDestinationContext) => { this.id = ctx.pathInfo.param as string })
  }
}
```
Pop: `stack.pop()`, `stack.clear()`, `replacePathByName`. Large apps: system route table
(`route_map.json` + `routerMap` in module.json5).

## Resources

`resources/base/element/string.json`, `color.json`, `float.json`; `resources/base/media/` images;
`resources/rawfile/` arbitrary files. Use `$r('app.string.title')`, `$r('app.color.primary')`,
`$r('app.media.logo')`, `$rawfile('data.json')`. System tokens: `$r('sys.color.ohos_id_color_primary')`.
Dark mode: `resources/dark/element/color.json`. Locales: `resources/en_US/...`, `resources/pl_PL/...`.

## Feedback / dialogs

```ts
this.getUIContext().getPromptAction().showToast({ message: 'Saved', duration: 2000 });
```
Also `showDialog`, `openCustomDialog`, `@CustomDialog` + `CustomDialogController`, `bindSheet`,
`bindPopup`, `bindMenu` / `bindContextMenu`.

## Animation

`animateTo({ duration: 300, curve: Curve.EaseOut }, () => { this.x = 100 })` (or
`this.getUIContext().animateTo`), `.animation({...})` attribute, `.transition(TransitionEffect.OPACITY)`,
`geometryTransition('id')` shared-element, `Lottie` via ohpm `@ohos/lottie`.

## Adaptive (phone / foldable / tablet / PC)

`GridRow/GridCol` breakpoints, `BreakpointSystem` via `window` size listener, `Navigation` auto
split-view on wide screens (`.mode(NavigationMode.Auto)`), `SideBarContainer`. Judges like
multi-device demos - "one app, many screens" is a HarmonyOS selling point.

## Immersive / safe area

`.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])` or
`window.getLastWindow(ctx)` → `setWindowLayoutFullScreen(true)`.

## Debug UI

DevEco Previewer (`@Preview` decorator on a struct) - fast but no device APIs. ArkUI Inspector in
DevEco for live tree. Re-render issues → check decorator first.
