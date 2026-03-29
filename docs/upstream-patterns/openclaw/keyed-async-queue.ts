/**
 * Keyed Async Queue
 *
 * Extracted from: OpenClaw src/plugin-sdk/keyed-async-queue.ts
 * Original: ~50 LOC, zero dependencies
 * License: MIT (OpenClaw project)
 *
 * Purpose: Serialize async work per key while allowing unrelated keys to run
 * concurrently. Essential for preventing race conditions in per-entity operations
 * (e.g., per-user message processing, per-session state updates) without
 * blocking unrelated entities.
 *
 * Usage:
 *   const queue = new KeyedAsyncQueue();
 *
 *   // These run concurrently (different keys):
 *   queue.enqueue("user-1", () => processMessage(msg1));
 *   queue.enqueue("user-2", () => processMessage(msg2));
 *
 *   // This waits for user-1's first task to finish (same key):
 *   queue.enqueue("user-1", () => processMessage(msg3));
 */

export type KeyedAsyncQueueHooks = {
  onEnqueue?: () => void;
  onSettle?: () => void;
};

/** Serialize async work per key while allowing unrelated keys to run concurrently. */
export function enqueueKeyedTask<T>(params: {
  tails: Map<string, Promise<void>>;
  key: string;
  task: () => Promise<T>;
  hooks?: KeyedAsyncQueueHooks;
}): Promise<T> {
  params.hooks?.onEnqueue?.();
  const previous = params.tails.get(params.key) ?? Promise.resolve();
  const current = previous
    .catch(() => undefined)
    .then(params.task)
    .finally(() => {
      params.hooks?.onSettle?.();
    });
  const tail = current.then(
    () => undefined,
    () => undefined,
  );
  params.tails.set(params.key, tail);
  void tail.finally(() => {
    if (params.tails.get(params.key) === tail) {
      params.tails.delete(params.key);
    }
  });
  return current;
}

export class KeyedAsyncQueue {
  private readonly tails = new Map<string, Promise<void>>();

  enqueue<T>(key: string, task: () => Promise<T>, hooks?: KeyedAsyncQueueHooks): Promise<T> {
    return enqueueKeyedTask({
      tails: this.tails,
      key,
      task,
      ...(hooks ? { hooks } : {}),
    });
  }
}
