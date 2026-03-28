/**
 * Tool Loop Detection
 *
 * Extracted from: OpenClaw src/agents/tool-loop-detection.ts
 * Original: ~624 LOC, zero external dependencies (crypto for hashing)
 * License: MIT (OpenClaw project)
 *
 * Purpose: Detect when an AI agent is stuck in a repetitive tool call loop that
 * burns context tokens without making progress. Three detector types:
 *
 *   1. Generic Repeat — same tool+args called N times (warning only)
 *   2. Known Poll No-Progress — polling tool returns identical results (warning → critical)
 *   3. Ping-Pong — alternating between two tool calls with no progress (warning → critical)
 *   4. Global Circuit Breaker — absolute cap on any single pattern (critical, blocks execution)
 *
 * Uses a sliding window of recent tool calls with SHA-256 hashing for efficient
 * pattern matching. Results are hashed to detect "no progress" (same output each time).
 *
 * Usage:
 *   const state: LoopDetectionState = { toolCallHistory: [] };
 *   const config = { enabled: true, historySize: 30, warningThreshold: 10, criticalThreshold: 20 };
 *
 *   // Before each tool call:
 *   const result = detectToolCallLoop(state, "bash", { cmd: "curl ..." }, config);
 *   if (result.stuck && result.level === "critical") {
 *     // Block execution, inform user
 *   }
 *
 *   // Record the call:
 *   recordToolCall(state, "bash", { cmd: "curl ..." }, "call-123", config);
 *
 *   // After getting result:
 *   recordToolCallOutcome(state, { toolName: "bash", toolParams: { cmd: "curl ..." },
 *     toolCallId: "call-123", result: { output: "..." }, config });
 */

import { createHash } from "node:crypto";

// --- Types ---

export type LoopDetectorKind =
  | "generic_repeat"
  | "known_poll_no_progress"
  | "global_circuit_breaker"
  | "ping_pong";

export type LoopDetectionResult =
  | { stuck: false }
  | {
      stuck: true;
      level: "warning" | "critical";
      detector: LoopDetectorKind;
      count: number;
      message: string;
      pairedToolName?: string;
      warningKey?: string;
    };

export type LoopDetectionConfig = {
  enabled: boolean;
  historySize?: number;
  warningThreshold?: number;
  criticalThreshold?: number;
  globalCircuitBreakerThreshold?: number;
  detectors?: {
    genericRepeat?: boolean;
    knownPollNoProgress?: boolean;
    pingPong?: boolean;
  };
};

export type ToolCallRecord = {
  toolName: string;
  argsHash: string;
  toolCallId?: string;
  resultHash?: string;
  timestamp: number;
};

export type LoopDetectionState = {
  toolCallHistory?: ToolCallRecord[];
};

// --- Config Resolution ---

const DEFAULTS = {
  historySize: 30,
  warningThreshold: 10,
  criticalThreshold: 20,
  globalCircuitBreakerThreshold: 30,
};

type ResolvedConfig = Required<LoopDetectionConfig> & {
  detectors: Required<NonNullable<LoopDetectionConfig["detectors"]>>;
};

function asPositiveInt(value: number | undefined, fallback: number): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value <= 0) return fallback;
  return value;
}

function resolveConfig(config?: LoopDetectionConfig): ResolvedConfig {
  let warningThreshold = asPositiveInt(config?.warningThreshold, DEFAULTS.warningThreshold);
  let criticalThreshold = asPositiveInt(config?.criticalThreshold, DEFAULTS.criticalThreshold);
  let globalCircuitBreakerThreshold = asPositiveInt(
    config?.globalCircuitBreakerThreshold,
    DEFAULTS.globalCircuitBreakerThreshold,
  );

  if (criticalThreshold <= warningThreshold) criticalThreshold = warningThreshold + 1;
  if (globalCircuitBreakerThreshold <= criticalThreshold)
    globalCircuitBreakerThreshold = criticalThreshold + 1;

  return {
    enabled: config?.enabled ?? false,
    historySize: asPositiveInt(config?.historySize, DEFAULTS.historySize),
    warningThreshold,
    criticalThreshold,
    globalCircuitBreakerThreshold,
    detectors: {
      genericRepeat: config?.detectors?.genericRepeat ?? true,
      knownPollNoProgress: config?.detectors?.knownPollNoProgress ?? true,
      pingPong: config?.detectors?.pingPong ?? true,
    },
  };
}

// --- Hashing ---

function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;
  const obj = value as Record<string, unknown>;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(obj[k])}`).join(",")}}`;
}

function digestStable(value: unknown): string {
  try {
    return createHash("sha256").update(stableStringify(value)).digest("hex");
  } catch {
    return createHash("sha256").update(String(value)).digest("hex");
  }
}

export function hashToolCall(toolName: string, params: unknown): string {
  return `${toolName}:${digestStable(params)}`;
}

// --- Detection Helpers ---

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Override this to recognize your own polling tools. */
function isKnownPollToolCall(toolName: string, params: unknown): boolean {
  if (toolName === "command_status") return true;
  if (toolName !== "process" || !isPlainObject(params)) return false;
  const action = params.action;
  return action === "poll" || action === "log";
}

function getNoProgressStreak(
  history: ToolCallRecord[],
  toolName: string,
  argsHash: string,
): { count: number; latestResultHash?: string } {
  let streak = 0;
  let latestResultHash: string | undefined;

  for (let i = history.length - 1; i >= 0; i--) {
    const record = history[i];
    if (!record || record.toolName !== toolName || record.argsHash !== argsHash) continue;
    if (typeof record.resultHash !== "string" || !record.resultHash) continue;

    if (!latestResultHash) {
      latestResultHash = record.resultHash;
      streak = 1;
      continue;
    }
    if (record.resultHash !== latestResultHash) break;
    streak++;
  }

  return { count: streak, latestResultHash };
}

function getPingPongStreak(
  history: ToolCallRecord[],
  currentSignature: string,
): { count: number; pairedToolName?: string; noProgressEvidence: boolean } {
  const last = history.at(-1);
  if (!last) return { count: 0, noProgressEvidence: false };

  let otherSignature: string | undefined;
  let otherToolName: string | undefined;
  for (let i = history.length - 2; i >= 0; i--) {
    const call = history[i];
    if (!call) continue;
    if (call.argsHash !== last.argsHash) {
      otherSignature = call.argsHash;
      otherToolName = call.toolName;
      break;
    }
  }

  if (!otherSignature || !otherToolName) return { count: 0, noProgressEvidence: false };

  let alternatingTailCount = 0;
  for (let i = history.length - 1; i >= 0; i--) {
    const call = history[i];
    if (!call) continue;
    const expected = alternatingTailCount % 2 === 0 ? last.argsHash : otherSignature;
    if (call.argsHash !== expected) break;
    alternatingTailCount++;
  }

  if (alternatingTailCount < 2) return { count: 0, noProgressEvidence: false };
  if (currentSignature !== otherSignature) return { count: 0, noProgressEvidence: false };

  // Check if results are identical across alternating calls
  const tailStart = Math.max(0, history.length - alternatingTailCount);
  let firstHashA: string | undefined;
  let firstHashB: string | undefined;
  let noProgressEvidence = true;

  for (let i = tailStart; i < history.length; i++) {
    const call = history[i];
    if (!call?.resultHash) { noProgressEvidence = false; break; }
    if (call.argsHash === last.argsHash) {
      if (!firstHashA) firstHashA = call.resultHash;
      else if (firstHashA !== call.resultHash) { noProgressEvidence = false; break; }
    } else if (call.argsHash === otherSignature) {
      if (!firstHashB) firstHashB = call.resultHash;
      else if (firstHashB !== call.resultHash) { noProgressEvidence = false; break; }
    } else { noProgressEvidence = false; break; }
  }

  if (!firstHashA || !firstHashB) noProgressEvidence = false;

  return {
    count: alternatingTailCount + 1,
    pairedToolName: last.toolName,
    noProgressEvidence,
  };
}

// --- Main Detection Function ---

/**
 * Detect if an agent is stuck in a repetitive tool call loop.
 */
export function detectToolCallLoop(
  state: LoopDetectionState,
  toolName: string,
  params: unknown,
  config?: LoopDetectionConfig,
): LoopDetectionResult {
  const cfg = resolveConfig(config);
  if (!cfg.enabled) return { stuck: false };

  const history = state.toolCallHistory ?? [];
  const currentHash = hashToolCall(toolName, params);
  const noProgress = getNoProgressStreak(history, toolName, currentHash);
  const knownPollTool = isKnownPollToolCall(toolName, params);
  const pingPong = getPingPongStreak(history, currentHash);

  // Global circuit breaker
  if (noProgress.count >= cfg.globalCircuitBreakerThreshold) {
    return {
      stuck: true,
      level: "critical",
      detector: "global_circuit_breaker",
      count: noProgress.count,
      message: `CRITICAL: ${toolName} repeated ${noProgress.count} times with no progress. Blocked by circuit breaker.`,
    };
  }

  // Known poll: critical
  if (knownPollTool && cfg.detectors.knownPollNoProgress && noProgress.count >= cfg.criticalThreshold) {
    return {
      stuck: true,
      level: "critical",
      detector: "known_poll_no_progress",
      count: noProgress.count,
      message: `CRITICAL: ${toolName} polled ${noProgress.count} times with no progress. Stuck polling loop.`,
    };
  }

  // Known poll: warning
  if (knownPollTool && cfg.detectors.knownPollNoProgress && noProgress.count >= cfg.warningThreshold) {
    return {
      stuck: true,
      level: "warning",
      detector: "known_poll_no_progress",
      count: noProgress.count,
      message: `WARNING: ${toolName} polled ${noProgress.count} times with identical results.`,
    };
  }

  // Ping-pong: critical
  if (cfg.detectors.pingPong && pingPong.count >= cfg.criticalThreshold && pingPong.noProgressEvidence) {
    return {
      stuck: true,
      level: "critical",
      detector: "ping_pong",
      count: pingPong.count,
      message: `CRITICAL: Alternating tool calls (${pingPong.count} consecutive) with no progress. Blocked.`,
      pairedToolName: pingPong.pairedToolName,
    };
  }

  // Ping-pong: warning
  if (cfg.detectors.pingPong && pingPong.count >= cfg.warningThreshold) {
    return {
      stuck: true,
      level: "warning",
      detector: "ping_pong",
      count: pingPong.count,
      message: `WARNING: Alternating tool calls (${pingPong.count} consecutive). Possible ping-pong loop.`,
      pairedToolName: pingPong.pairedToolName,
    };
  }

  // Generic repeat: warning
  const recentCount = history.filter((h) => h.toolName === toolName && h.argsHash === currentHash).length;
  if (!knownPollTool && cfg.detectors.genericRepeat && recentCount >= cfg.warningThreshold) {
    return {
      stuck: true,
      level: "warning",
      detector: "generic_repeat",
      count: recentCount,
      message: `WARNING: ${toolName} called ${recentCount} times with identical arguments.`,
    };
  }

  return { stuck: false };
}

/**
 * Record a tool call in the session history (sliding window).
 */
export function recordToolCall(
  state: LoopDetectionState,
  toolName: string,
  params: unknown,
  toolCallId?: string,
  config?: LoopDetectionConfig,
): void {
  const cfg = resolveConfig(config);
  if (!state.toolCallHistory) state.toolCallHistory = [];

  state.toolCallHistory.push({
    toolName,
    argsHash: hashToolCall(toolName, params),
    toolCallId,
    timestamp: Date.now(),
  });

  if (state.toolCallHistory.length > cfg.historySize) {
    state.toolCallHistory.shift();
  }
}

/**
 * Record a completed tool call outcome for no-progress detection.
 */
export function recordToolCallOutcome(
  state: LoopDetectionState,
  params: {
    toolName: string;
    toolParams: unknown;
    toolCallId?: string;
    result?: unknown;
    error?: unknown;
    config?: LoopDetectionConfig;
  },
): void {
  const cfg = resolveConfig(params.config);
  const resultHash = params.error !== undefined
    ? `error:${digestStable(params.error)}`
    : digestStable(params.result);

  if (!state.toolCallHistory) state.toolCallHistory = [];

  const argsHash = hashToolCall(params.toolName, params.toolParams);
  let matched = false;
  for (let i = state.toolCallHistory.length - 1; i >= 0; i--) {
    const call = state.toolCallHistory[i];
    if (!call) continue;
    if (params.toolCallId && call.toolCallId !== params.toolCallId) continue;
    if (call.toolName !== params.toolName || call.argsHash !== argsHash) continue;
    if (call.resultHash !== undefined) continue;
    call.resultHash = resultHash;
    matched = true;
    break;
  }

  if (!matched) {
    state.toolCallHistory.push({
      toolName: params.toolName,
      argsHash,
      toolCallId: params.toolCallId,
      resultHash,
      timestamp: Date.now(),
    });
  }

  if (state.toolCallHistory.length > cfg.historySize) {
    state.toolCallHistory.splice(0, state.toolCallHistory.length - cfg.historySize);
  }
}
