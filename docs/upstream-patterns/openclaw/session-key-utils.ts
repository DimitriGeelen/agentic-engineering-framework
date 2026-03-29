/**
 * Session Key Derivation & Parsing
 *
 * Extracted from: OpenClaw src/sessions/session-key-utils.ts
 * Original: ~133 LOC, zero dependencies
 * License: MIT (OpenClaw project)
 *
 * Purpose: Parse and classify hierarchical session keys for multi-agent isolation.
 * Session keys encode routing context (agent, channel, chat type, thread, cron, subagent)
 * in a colon-delimited format: "agent:<agentId>:<channel>:<accountId>:<chatType>".
 *
 * This enables per-session workspace isolation — each conversation gets its own
 * derived key, preventing state leakage between users, channels, and agents.
 *
 * Usage:
 *   const parsed = parseAgentSessionKey("agent:main:discord:12345:direct");
 *   // => { agentId: "main", rest: "discord:12345:direct" }
 *
 *   const chatType = deriveSessionChatType("agent:main:discord:guild-1:channel-2");
 *   // => "channel"
 *
 *   const depth = getSubagentDepth("agent:main:subagent:child1:subagent:child2");
 *   // => 2
 */

export type ParsedAgentSessionKey = {
  agentId: string;
  rest: string;
};

export type SessionKeyChatType = "direct" | "group" | "channel" | "unknown";

/**
 * Parse agent-scoped session keys in a canonical, case-insensitive way.
 * Returns null if the key doesn't match the "agent:<id>:<rest>" format.
 */
export function parseAgentSessionKey(
  sessionKey: string | undefined | null,
): ParsedAgentSessionKey | null {
  const raw = (sessionKey ?? "").trim().toLowerCase();
  if (!raw) return null;

  const parts = raw.split(":").filter(Boolean);
  if (parts.length < 3) return null;
  if (parts[0] !== "agent") return null;

  const agentId = parts[1]?.trim();
  const rest = parts.slice(2).join(":");
  if (!agentId || !rest) return null;

  return { agentId, rest };
}

/**
 * Best-effort chat-type extraction from session keys.
 * Handles both canonical (token-based) and legacy (pattern-based) formats.
 */
export function deriveSessionChatType(sessionKey: string | undefined | null): SessionKeyChatType {
  const raw = (sessionKey ?? "").trim().toLowerCase();
  if (!raw) return "unknown";

  const scoped = parseAgentSessionKey(raw)?.rest ?? raw;
  const tokens = new Set(scoped.split(":").filter(Boolean));

  if (tokens.has("group")) return "group";
  if (tokens.has("channel")) return "channel";
  if (tokens.has("direct") || tokens.has("dm")) return "direct";

  // Legacy format detection
  if (/^discord:(?:[^:]+:)?guild-[^:]+:channel-[^:]+$/.test(scoped)) {
    return "channel";
  }

  return "unknown";
}

/** Check if a session key represents a cron job execution. */
export function isCronRunSessionKey(sessionKey: string | undefined | null): boolean {
  const parsed = parseAgentSessionKey(sessionKey);
  if (!parsed) return false;
  return /^cron:[^:]+:run:[^:]+$/.test(parsed.rest);
}

/** Check if a session key is cron-related (any cron scope). */
export function isCronSessionKey(sessionKey: string | undefined | null): boolean {
  const parsed = parseAgentSessionKey(sessionKey);
  if (!parsed) return false;
  return parsed.rest.toLowerCase().startsWith("cron:");
}

/** Check if a session key represents a subagent execution. */
export function isSubagentSessionKey(sessionKey: string | undefined | null): boolean {
  const raw = (sessionKey ?? "").trim();
  if (!raw) return false;
  if (raw.toLowerCase().startsWith("subagent:")) return true;
  const parsed = parseAgentSessionKey(raw);
  return Boolean((parsed?.rest ?? "").toLowerCase().startsWith("subagent:"));
}

/** Count how many levels of subagent nesting exist in a session key. */
export function getSubagentDepth(sessionKey: string | undefined | null): number {
  const raw = (sessionKey ?? "").trim().toLowerCase();
  if (!raw) return 0;
  return raw.split(":subagent:").length - 1;
}

/** Resolve the parent session key by stripping thread/topic suffixes. */
export function resolveThreadParentSessionKey(
  sessionKey: string | undefined | null,
): string | null {
  const raw = (sessionKey ?? "").trim();
  if (!raw) return null;

  const normalized = raw.toLowerCase();
  const markers = [":thread:", ":topic:"];
  let idx = -1;
  for (const marker of markers) {
    const candidate = normalized.lastIndexOf(marker);
    if (candidate > idx) idx = candidate;
  }

  if (idx <= 0) return null;
  const parent = raw.slice(0, idx).trim();
  return parent || null;
}
