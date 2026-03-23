#!/usr/bin/env node
/**
 * PostToolUse loop detector — TypeScript prototype for T-586/T-578
 *
 * Detects repetitive tool call patterns:
 *   1. generic_repeat: same tool+params called N times
 *   2. ping_pong: alternating between two tool calls
 *   3. no_progress: same tool+params+result repeated (outcome tracking)
 *
 * State: JSON file at .context/working/.loop-detect.json
 * Input: tool_name and params from Claude Code PostToolUse hook (stdin JSON)
 * Output: JSON with {stuck, level, detector, message} to stderr (additionalContext)
 *
 * Adapted from OpenClaw tool-loop-detection.ts (624 LOC) — simplified for
 * Claude Code hook architecture (no config system, no subsystem logger).
 */

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";

// --- Configuration ---
const HISTORY_SIZE = 30;
const WARNING_THRESHOLD = 5;
const CRITICAL_THRESHOLD = 10;

// --- Types ---
interface ToolCallRecord {
  toolName: string;
  argsHash: string;
  resultHash?: string;
  timestamp: number;
}

interface LoopState {
  history: ToolCallRecord[];
}

type DetectorKind = "generic_repeat" | "ping_pong" | "no_progress";

interface LoopResult {
  stuck: boolean;
  level?: "warning" | "critical";
  detector?: DetectorKind;
  count?: number;
  message?: string;
}

// --- Hashing ---
function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }
  const obj = value as Record<string, unknown>;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(obj[k])}`).join(",")}}`;
}

function digest(value: unknown): string {
  const serialized = stableStringify(value);
  return createHash("sha256").update(serialized).digest("hex").slice(0, 16);
}

function hashToolCall(toolName: string, params: unknown): string {
  return `${toolName}:${digest(params)}`;
}

// --- State Management ---
function getStatePath(): string {
  const projectRoot = process.env.PROJECT_ROOT || process.env.FRAMEWORK_ROOT || process.cwd();
  return resolve(projectRoot, ".context/working/.loop-detect.json");
}

function loadState(): LoopState {
  try {
    const data = readFileSync(getStatePath(), "utf8");
    return JSON.parse(data) as LoopState;
  } catch {
    return { history: [] };
  }
}

function saveState(state: LoopState): void {
  const path = getStatePath();
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(state), "utf8");
}

// --- Detectors ---
function detectGenericRepeat(history: ToolCallRecord[], currentHash: string, toolName: string): LoopResult {
  const count = history.filter((h) => h.argsHash === currentHash).length;

  if (count >= CRITICAL_THRESHOLD) {
    return {
      stuck: true,
      level: "critical",
      detector: "generic_repeat",
      count,
      message: `BLOCKED: ${toolName} called ${count} times with identical arguments. This is a stuck loop — stop retrying and try a different approach.`,
    };
  }
  if (count >= WARNING_THRESHOLD) {
    return {
      stuck: true,
      level: "warning",
      detector: "generic_repeat",
      count,
      message: `WARNING: ${toolName} called ${count} times with identical arguments. If not making progress, try a different approach.`,
    };
  }
  return { stuck: false };
}

function detectPingPong(history: ToolCallRecord[], currentHash: string): LoopResult {
  if (history.length < 4) return { stuck: false };

  // Check if last entries alternate between two patterns
  const last = history[history.length - 1];
  if (!last || last.argsHash === currentHash) {
    // Same as previous — not ping-pong (that's generic_repeat)
    return { stuck: false };
  }

  const patternA = currentHash;
  const patternB = last.argsHash;
  let streak = 0;

  for (let i = history.length - 1; i >= 0; i--) {
    const expected = (history.length - 1 - i) % 2 === 0 ? patternB : patternA;
    if (history[i]?.argsHash !== expected) break;
    streak++;
  }
  streak++; // Include current call

  if (streak >= CRITICAL_THRESHOLD) {
    return {
      stuck: true,
      level: "critical",
      detector: "ping_pong",
      count: streak,
      message: `BLOCKED: Alternating between two tool patterns ${streak} times — stuck ping-pong loop. Stop and try a different approach.`,
    };
  }
  if (streak >= WARNING_THRESHOLD) {
    return {
      stuck: true,
      level: "warning",
      detector: "ping_pong",
      count: streak,
      message: `WARNING: Alternating between two tool patterns ${streak} times. This looks like a ping-pong loop.`,
    };
  }
  return { stuck: false };
}

function detectNoProgress(history: ToolCallRecord[], currentHash: string, toolName: string): LoopResult {
  // Check if same tool+params+result keeps repeating
  const matching = history.filter((h) => h.argsHash === currentHash && h.resultHash);
  if (matching.length < 3) return { stuck: false };

  // Check if all recent results are identical
  const lastResult = matching[matching.length - 1]?.resultHash;
  let sameResultStreak = 0;
  for (let i = matching.length - 1; i >= 0; i--) {
    if (matching[i]?.resultHash !== lastResult) break;
    sameResultStreak++;
  }

  if (sameResultStreak >= CRITICAL_THRESHOLD) {
    return {
      stuck: true,
      level: "critical",
      detector: "no_progress",
      count: sameResultStreak,
      message: `BLOCKED: ${toolName} returning identical results ${sameResultStreak} times — no progress. Stop and try a different approach.`,
    };
  }
  if (sameResultStreak >= WARNING_THRESHOLD) {
    return {
      stuck: true,
      level: "warning",
      detector: "no_progress",
      count: sameResultStreak,
      message: `WARNING: ${toolName} returning identical results ${sameResultStreak} times. Not making progress.`,
    };
  }
  return { stuck: false };
}

// --- Main ---
function main(): void {
  // Read PostToolUse hook input from stdin
  let input: { tool_name?: string; tool_input?: unknown; tool_result?: unknown };
  try {
    input = JSON.parse(readFileSync("/dev/stdin", "utf8"));
  } catch {
    process.exit(0); // Can't parse input — allow
  }

  const toolName = input.tool_name ?? "unknown";
  const params = input.tool_input ?? {};
  const currentHash = hashToolCall(toolName, params);

  // Load state
  const state = loadState();

  // Run detectors (order: most specific first)
  const noProgress = detectNoProgress(state.history, currentHash, toolName);
  if (noProgress.stuck) {
    outputResult(noProgress);
  }

  const pingPong = detectPingPong(state.history, currentHash);
  if (pingPong.stuck) {
    outputResult(pingPong);
  }

  const genericRepeat = detectGenericRepeat(state.history, currentHash, toolName);
  if (genericRepeat.stuck) {
    outputResult(genericRepeat);
  }

  // Record this call
  const resultHash = input.tool_result ? digest(input.tool_result) : undefined;
  state.history.push({
    toolName,
    argsHash: currentHash,
    resultHash,
    timestamp: Date.now(),
  });

  // Trim to window size
  if (state.history.length > HISTORY_SIZE) {
    state.history.splice(0, state.history.length - HISTORY_SIZE);
  }

  saveState(state);
  process.exit(0); // No loop detected
}

function outputResult(result: LoopResult): void {
  // PostToolUse hook: output to stderr as additionalContext
  const output = JSON.stringify({
    additionalContext: result.message,
    loop_detected: true,
    detector: result.detector,
    level: result.level,
    count: result.count,
  });
  process.stderr.write(output + "\n");

  if (result.level === "critical") {
    process.exit(2); // Block
  }
  // Warning: exit 0 but with additionalContext
}

main();
