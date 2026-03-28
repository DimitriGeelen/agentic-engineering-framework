/**
 * Deduplication Cache (In-Memory)
 *
 * Extracted from: OpenClaw src/infra/dedupe.ts
 * Original: ~90 LOC, zero external dependencies
 * License: MIT (OpenClaw project)
 *
 * Purpose: Prevent duplicate processing of events/messages within a time window.
 * Uses TTL-based expiry and LRU-style max-size pruning. The `check` method returns
 * true if the key was already seen (duplicate), false if new (and records it).
 *
 * Usage:
 *   const dedup = createDedupeCache({ ttlMs: 60_000, maxSize: 1000 });
 *
 *   function onMessage(msg: Message) {
 *     if (dedup.check(msg.id)) {
 *       return; // Already processed within last 60s
 *     }
 *     processMessage(msg);
 *   }
 *
 * For persistent (disk-backed) dedup, see OpenClaw's persistent-dedupe.ts which
 * layers file-lock-protected JSON storage on top of this in-memory cache.
 */

export type DedupeCache = {
  /** Returns true if key was already seen within TTL (duplicate). Records key if new. */
  check: (key: string | undefined | null, now?: number) => boolean;
  /** Returns true if key exists without recording it. */
  peek: (key: string | undefined | null, now?: number) => boolean;
  delete: (key: string | undefined | null) => void;
  clear: () => void;
  size: () => number;
};

export type DedupeCacheOptions = {
  ttlMs: number;
  maxSize: number;
};

function pruneMapToMaxSize<K, V>(map: Map<K, V>, maxSize: number): void {
  if (map.size <= maxSize) return;
  const excess = map.size - maxSize;
  let removed = 0;
  for (const key of map.keys()) {
    if (removed >= excess) break;
    map.delete(key);
    removed++;
  }
}

export function createDedupeCache(options: DedupeCacheOptions): DedupeCache {
  const ttlMs = Math.max(0, options.ttlMs);
  const maxSize = Math.max(0, Math.floor(options.maxSize));
  const cache = new Map<string, number>();

  const touch = (key: string, now: number) => {
    cache.delete(key);
    cache.set(key, now);
  };

  const prune = (now: number) => {
    const cutoff = ttlMs > 0 ? now - ttlMs : undefined;
    if (cutoff !== undefined) {
      for (const [entryKey, entryTs] of cache) {
        if (entryTs < cutoff) {
          cache.delete(entryKey);
        }
      }
    }
    if (maxSize <= 0) {
      cache.clear();
      return;
    }
    pruneMapToMaxSize(cache, maxSize);
  };

  const hasUnexpired = (key: string, now: number, touchOnRead: boolean): boolean => {
    const existing = cache.get(key);
    if (existing === undefined) {
      return false;
    }
    if (ttlMs > 0 && now - existing >= ttlMs) {
      cache.delete(key);
      return false;
    }
    if (touchOnRead) {
      touch(key, now);
    }
    return true;
  };

  return {
    check: (key, now = Date.now()) => {
      if (!key) return false;
      if (hasUnexpired(key, now, true)) return true;
      touch(key, now);
      prune(now);
      return false;
    },
    peek: (key, now = Date.now()) => {
      if (!key) return false;
      return hasUnexpired(key, now, false);
    },
    delete: (key) => {
      if (key) cache.delete(key);
    },
    clear: () => cache.clear(),
    size: () => cache.size,
  };
}
