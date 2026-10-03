// Short toast message; never throws (showToast can fail while the UI is being torn down).

export function toast(ctx: UIContext, message: ResourceStr): void {
  try {
    ctx.getPromptAction().showToast({ message: message, duration: 2000 });
  } catch (e) {
    console.error(`toast failed: ${JSON.stringify(e)}`);
  }
}
