/**
 * Skills/Content Budget Algorithm
 *
 * Extracted from: OpenClaw src/agents/skills/workspace.ts (applySkillsPromptLimits)
 * Original: ~100 LOC, zero external dependencies
 * License: MIT (OpenClaw project)
 *
 * Purpose: Fit a list of content items into a character budget using a 3-tier
 * degradation strategy:
 *   Tier 1: Full format (name + description + metadata)
 *   Tier 2: Compact format (name + location only, no descriptions)
 *   Tier 3: Binary search — find the largest subset that fits in compact format
 *
 * This prevents token overflow in LLM prompts when injecting dynamic content
 * (skills, tools, context) while preserving maximum awareness of available items.
 *
 * Usage:
 *   const items = loadAllSkills(); // Could be 100+ items
 *   const result = applyBudget({
 *     items,
 *     maxChars: 30_000,
 *     maxCount: 150,
 *     formatFull: (items) => items.map(i => `${i.name}: ${i.desc}`).join("\n"),
 *     formatCompact: (items) => items.map(i => i.name).join("\n"),
 *   });
 *   // result.items — the items that fit
 *   // result.truncated — whether items were dropped
 *   // result.compact — whether compact format was used
 */

export type BudgetItem = {
  name: string;
  [key: string]: unknown;
};

export type BudgetOptions<T extends BudgetItem> = {
  items: T[];
  maxChars: number;
  maxCount?: number;
  /** Render items in full format (with descriptions). Return the formatted string. */
  formatFull: (items: T[]) => string;
  /** Render items in compact format (name only). Return the formatted string. */
  formatCompact: (items: T[]) => string;
  /** Reserved chars for warning/notice text prepended by the caller. Default: 150 */
  compactOverhead?: number;
};

export type BudgetResult<T extends BudgetItem> = {
  items: T[];
  truncated: boolean;
  compact: boolean;
};

/**
 * Apply a 3-tier budget to a list of items:
 *  1. Try full format — if it fits, done
 *  2. Try compact format with all items — if it fits, use compact
 *  3. Binary search for the largest compact subset that fits
 */
export function applyBudget<T extends BudgetItem>(opts: BudgetOptions<T>): BudgetResult<T> {
  const maxCount = opts.maxCount ?? Infinity;
  const compactOverhead = opts.compactOverhead ?? 150;
  const total = opts.items.length;

  // Apply count limit first
  const byCount = opts.items.slice(0, Math.max(0, maxCount));
  let items = byCount;
  let truncated = total > byCount.length;
  let compact = false;

  const fitsFull = (candidates: T[]): boolean =>
    opts.formatFull(candidates).length <= opts.maxChars;

  const compactBudget = opts.maxChars - compactOverhead;
  const fitsCompact = (candidates: T[]): boolean =>
    opts.formatCompact(candidates).length <= compactBudget;

  if (!fitsFull(items)) {
    // Tier 2: try compact format with all items
    if (fitsCompact(items)) {
      compact = true;
    } else {
      // Tier 3: binary search for largest compact subset
      compact = true;
      let lo = 0;
      let hi = items.length;
      while (lo < hi) {
        const mid = Math.ceil((lo + hi) / 2);
        if (fitsCompact(items.slice(0, mid))) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      items = items.slice(0, lo);
      truncated = true;
    }
  }

  return { items, truncated, compact };
}
