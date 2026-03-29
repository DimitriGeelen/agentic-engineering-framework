/**
 * DM/Group Access Policy — ACL Compilation & Evaluation
 *
 * Extracted from: OpenClaw src/security/dm-policy-shared.ts
 * Original: ~333 LOC, zero external dependencies
 * License: MIT (OpenClaw project)
 *
 * Purpose: Compile DM (direct message) and group access policies into a fast
 * evaluation function. Supports multiple policy modes (open, disabled, allowlist,
 * pairing) with per-channel allowlist merging from config and runtime stores.
 *
 * The key insight is the multi-source allowlist merge: config-defined allowFrom +
 * runtime pairing store + group-specific overrides, all normalized and deduplicated
 * before evaluation. This pattern generalizes to any system where access rules
 * come from multiple sources that must be merged consistently.
 *
 * Usage:
 *   const decision = resolveDmGroupAccessDecision({
 *     isGroup: false,
 *     dmPolicy: "pairing",
 *     groupPolicy: "allowlist",
 *     effectiveAllowFrom: ["user123", "user456"],
 *     effectiveGroupAllowFrom: ["admin1"],
 *     isSenderAllowed: (list) => list.includes(senderId),
 *   });
 *   // => { decision: "allow", reasonCode: "dm_policy_allowlisted", reason: "..." }
 */

// --- Types ---

export type AccessDecision = "allow" | "block" | "pairing";

export type GroupPolicy = "open" | "disabled" | "allowlist";

export const ACCESS_REASON = {
  GROUP_POLICY_ALLOWED: "group_policy_allowed",
  GROUP_POLICY_DISABLED: "group_policy_disabled",
  GROUP_POLICY_EMPTY_ALLOWLIST: "group_policy_empty_allowlist",
  GROUP_POLICY_NOT_ALLOWLISTED: "group_policy_not_allowlisted",
  DM_POLICY_OPEN: "dm_policy_open",
  DM_POLICY_DISABLED: "dm_policy_disabled",
  DM_POLICY_ALLOWLISTED: "dm_policy_allowlisted",
  DM_POLICY_PAIRING_REQUIRED: "dm_policy_pairing_required",
  DM_POLICY_NOT_ALLOWLISTED: "dm_policy_not_allowlisted",
} as const;

export type AccessReasonCode = (typeof ACCESS_REASON)[keyof typeof ACCESS_REASON];

// --- Helpers ---

function normalizeEntries(entries: Array<string | number> | undefined): string[] {
  if (!entries) return [];
  return [...new Set(entries.map((e) => String(e).trim().toLowerCase()).filter(Boolean))];
}

function evaluateGroupAccess(params: {
  groupPolicy: GroupPolicy;
  allowlistConfigured: boolean;
  allowlistMatched: boolean;
}): { allowed: boolean; reason?: "disabled" | "empty_allowlist" | "not_allowlisted" } {
  if (params.groupPolicy === "open") return { allowed: true };
  if (params.groupPolicy === "disabled") return { allowed: false, reason: "disabled" };
  // allowlist mode
  if (!params.allowlistConfigured) return { allowed: false, reason: "empty_allowlist" };
  if (!params.allowlistMatched) return { allowed: false, reason: "not_allowlisted" };
  return { allowed: true };
}

// --- Multi-Source Allowlist Merge ---

/**
 * Merge DM allowFrom from config + runtime pairing store.
 * When dmPolicy is "allowlist" (strict), pairing store is excluded.
 */
export function mergeDmAllowFromSources(params: {
  allowFrom?: Array<string | number>;
  storeAllowFrom?: Array<string | number>;
  dmPolicy?: string;
}): string[] {
  const config = normalizeEntries(params.allowFrom);
  if (params.dmPolicy === "allowlist") return config;
  const store = normalizeEntries(params.storeAllowFrom);
  return [...new Set([...config, ...store])];
}

/**
 * Resolve group allowFrom with optional fallback to DM allowFrom.
 */
export function resolveGroupAllowFromSources(params: {
  allowFrom?: Array<string | number>;
  groupAllowFrom?: Array<string | number>;
  fallbackToAllowFrom?: boolean;
}): string[] {
  const explicit = normalizeEntries(params.groupAllowFrom);
  if (explicit.length > 0) return explicit;
  if (params.fallbackToAllowFrom !== false) return normalizeEntries(params.allowFrom);
  return [];
}

// --- Main Access Decision ---

export function resolveDmGroupAccessDecision(params: {
  isGroup: boolean;
  dmPolicy?: string | null;
  groupPolicy?: string | null;
  effectiveAllowFrom: Array<string | number>;
  effectiveGroupAllowFrom: Array<string | number>;
  isSenderAllowed: (allowFrom: string[]) => boolean;
}): {
  decision: AccessDecision;
  reasonCode: AccessReasonCode;
  reason: string;
} {
  const dmPolicy = params.dmPolicy ?? "pairing";
  const groupPolicy: GroupPolicy =
    params.groupPolicy === "open" || params.groupPolicy === "disabled"
      ? params.groupPolicy
      : "allowlist";

  const effectiveAllowFrom = normalizeEntries(params.effectiveAllowFrom);
  const effectiveGroupAllowFrom = normalizeEntries(params.effectiveGroupAllowFrom);

  // Group access evaluation
  if (params.isGroup) {
    const groupAccess = evaluateGroupAccess({
      groupPolicy,
      allowlistConfigured: effectiveGroupAllowFrom.length > 0,
      allowlistMatched: params.isSenderAllowed(effectiveGroupAllowFrom),
    });

    if (!groupAccess.allowed) {
      const reasonMap = {
        disabled: { code: ACCESS_REASON.GROUP_POLICY_DISABLED, text: "groupPolicy=disabled" },
        empty_allowlist: {
          code: ACCESS_REASON.GROUP_POLICY_EMPTY_ALLOWLIST,
          text: "groupPolicy=allowlist (empty)",
        },
        not_allowlisted: {
          code: ACCESS_REASON.GROUP_POLICY_NOT_ALLOWLISTED,
          text: "groupPolicy=allowlist (not listed)",
        },
      };
      const info = reasonMap[groupAccess.reason!];
      return { decision: "block", reasonCode: info.code, reason: info.text };
    }

    return {
      decision: "allow",
      reasonCode: ACCESS_REASON.GROUP_POLICY_ALLOWED,
      reason: `groupPolicy=${groupPolicy}`,
    };
  }

  // DM access evaluation
  if (dmPolicy === "disabled") {
    return { decision: "block", reasonCode: ACCESS_REASON.DM_POLICY_DISABLED, reason: "dmPolicy=disabled" };
  }
  if (dmPolicy === "open") {
    return { decision: "allow", reasonCode: ACCESS_REASON.DM_POLICY_OPEN, reason: "dmPolicy=open" };
  }
  if (params.isSenderAllowed(effectiveAllowFrom)) {
    return {
      decision: "allow",
      reasonCode: ACCESS_REASON.DM_POLICY_ALLOWLISTED,
      reason: `dmPolicy=${dmPolicy} (allowlisted)`,
    };
  }
  if (dmPolicy === "pairing") {
    return {
      decision: "pairing",
      reasonCode: ACCESS_REASON.DM_POLICY_PAIRING_REQUIRED,
      reason: "dmPolicy=pairing (not allowlisted)",
    };
  }
  return {
    decision: "block",
    reasonCode: ACCESS_REASON.DM_POLICY_NOT_ALLOWLISTED,
    reason: `dmPolicy=${dmPolicy} (not allowlisted)`,
  };
}
