// Minimal typed listener list. Services use it for onSample/onAlert/onProactive-style subscriptions.

export type Listener<T> = (value: T) => void;

export class Listeners<T> {
  private items: Listener<T>[] = [];

  add(listener: Listener<T>): () => void {
    this.items.push(listener);
    return () => {
      this.items = this.items.filter((l: Listener<T>) => l !== listener);
    };
  }

  emit(value: T): void {
    const snapshot: Listener<T>[] = this.items.slice();
    for (const listener of snapshot) {
      listener(value);
    }
  }

  size(): number {
    return this.items.length;
  }

  clear(): void {
    this.items = [];
  }
}
