/**
 * Config Diff — Deep Path Diffing for Configuration Objects
 *
 * Extracted from: OpenClaw src/gateway/config-reload.ts (diffConfigPaths)
 *                 OpenClaw src/gateway/config-reload-plan.ts (buildReloadPlan)
 * Original: ~200 LOC combined, zero external dependencies
 * License: MIT (OpenClaw project)
 *
 * Purpose: Compare two configuration objects and return the list of changed
 * dot-notation paths. Used to drive hot-reload decisions: classify each changed
 * path as "restart required", "hot-reloadable", or "no-op" to minimize service
 * disruption during config changes.
 *
 * Usage:
 *   const prev = { gateway: { port: 8080 }, hooks: { gmail: true } };
 *   const next = { gateway: { port: 9090 }, hooks: { gmail: false } };
 *
 *   const changed = diffConfigPaths(prev, next);
 *   // => ["gateway.port", "hooks.gmail"]
 *
 *   const plan = buildReloadPlan(changed, RELOAD_RULES);
 *   // => { restart: ["gateway.port"], hot: ["hooks.gmail"], noop: [] }
 */

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isDeepEqual(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (typeof a !== typeof b) return false;
  if (a === null || b === null) return false;
  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) return false;
    return a.every((item, i) => isDeepEqual(item, b[i]));
  }
  if (isPlainObject(a) && isPlainObject(b)) {
    const keysA = Object.keys(a);
    const keysB = Object.keys(b);
    if (keysA.length !== keysB.length) return false;
    return keysA.every((key) => key in b && isDeepEqual(a[key], b[key]));
  }
  return false;
}

/**
 * Recursively diff two config objects, returning changed dot-notation paths.
 * Pure function, zero side effects.
 */
export function diffConfigPaths(prev: unknown, next: unknown, prefix = ""): string[] {
  if (prev === next) return [];

  if (isPlainObject(prev) && isPlainObject(next)) {
    const keys = new Set([...Object.keys(prev), ...Object.keys(next)]);
    const paths: string[] = [];
    for (const key of keys) {
      const prevValue = prev[key];
      const nextValue = next[key];
      if (prevValue === undefined && nextValue === undefined) continue;
      const childPrefix = prefix ? `${prefix}.${key}` : key;
      paths.push(...diffConfigPaths(prevValue, nextValue, childPrefix));
    }
    return paths;
  }

  if (Array.isArray(prev) && Array.isArray(next)) {
    if (isDeepEqual(prev, next)) return [];
  }

  return [prefix || "<root>"];
}

// --- Reload Plan Builder ---

export type ReloadRule = {
  /** Dot-notation config path prefix to match */
  prefix: string;
  /** "restart" = requires full restart, "hot" = can hot-reload, "none" = no action needed */
  kind: "restart" | "hot" | "none";
  /** Optional action tags to collect (e.g., "reload-hooks", "restart-cron") */
  actions?: string[];
};

export type ReloadPlan = {
  changedPaths: string[];
  requiresRestart: boolean;
  restartReasons: string[];
  hotReasons: string[];
  noopPaths: string[];
  actions: Set<string>;
};

function matchRule(path: string, rules: ReloadRule[]): ReloadRule | null {
  for (const rule of rules) {
    if (path === rule.prefix || path.startsWith(`${rule.prefix}.`)) {
      return rule;
    }
  }
  return null;
}

/**
 * Given a list of changed config paths and reload rules, produce a reload plan
 * that classifies each path and collects required actions.
 */
export function buildReloadPlan(changedPaths: string[], rules: ReloadRule[]): ReloadPlan {
  const plan: ReloadPlan = {
    changedPaths,
    requiresRestart: false,
    restartReasons: [],
    hotReasons: [],
    noopPaths: [],
    actions: new Set(),
  };

  for (const path of changedPaths) {
    const rule = matchRule(path, rules);
    if (!rule) {
      // Unknown path defaults to restart
      plan.requiresRestart = true;
      plan.restartReasons.push(path);
      continue;
    }
    if (rule.kind === "restart") {
      plan.requiresRestart = true;
      plan.restartReasons.push(path);
    } else if (rule.kind === "hot") {
      plan.hotReasons.push(path);
      for (const action of rule.actions ?? []) {
        plan.actions.add(action);
      }
    } else {
      plan.noopPaths.push(path);
    }
  }

  return plan;
}
