#!/usr/bin/env node

// loop-detect.ts
var import_node_crypto = require("node:crypto");
var import_node_fs = require("node:fs");
var import_node_path = require("node:path");
var HISTORY_SIZE = 30;
var WARNING_THRESHOLD = 5;
var CRITICAL_THRESHOLD = 10;
function stableStringify(value) {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }
  const obj = value;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(obj[k])}`).join(",")}}`;
}
function digest(value) {
  const serialized = stableStringify(value);
  return (0, import_node_crypto.createHash)("sha256").update(serialized).digest("hex").slice(0, 16);
}
function hashToolCall(toolName, params) {
  return `${toolName}:${digest(params)}`;
}
function getStatePath() {
  const projectRoot = process.env.PROJECT_ROOT || process.env.FRAMEWORK_ROOT || process.cwd();
  return (0, import_node_path.resolve)(projectRoot, ".context/working/.loop-detect.json");
}
function loadState() {
  try {
    const data = (0, import_node_fs.readFileSync)(getStatePath(), "utf8");
    return JSON.parse(data);
  } catch {
    return { history: [] };
  }
}
function saveState(state) {
  const path = getStatePath();
  (0, import_node_fs.mkdirSync)((0, import_node_path.dirname)(path), { recursive: true });
  (0, import_node_fs.writeFileSync)(path, JSON.stringify(state), "utf8");
}
function detectGenericRepeat(history, currentHash, toolName) {
  const count = history.filter((h) => h.argsHash === currentHash).length;
  if (count >= CRITICAL_THRESHOLD) {
    return {
      stuck: true,
      level: "critical",
      detector: "generic_repeat",
      count,
      message: `BLOCKED: ${toolName} called ${count} times with identical arguments. This is a stuck loop \u2014 stop retrying and try a different approach.`
    };
  }
  if (count >= WARNING_THRESHOLD) {
    return {
      stuck: true,
      level: "warning",
      detector: "generic_repeat",
      count,
      message: `WARNING: ${toolName} called ${count} times with identical arguments. If not making progress, try a different approach.`
    };
  }
  return { stuck: false };
}
function detectPingPong(history, currentHash) {
  if (history.length < 4) return { stuck: false };
  const last = history[history.length - 1];
  if (!last || last.argsHash === currentHash) {
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
  streak++;
  if (streak >= CRITICAL_THRESHOLD) {
    return {
      stuck: true,
      level: "critical",
      detector: "ping_pong",
      count: streak,
      message: `BLOCKED: Alternating between two tool patterns ${streak} times \u2014 stuck ping-pong loop. Stop and try a different approach.`
    };
  }
  if (streak >= WARNING_THRESHOLD) {
    return {
      stuck: true,
      level: "warning",
      detector: "ping_pong",
      count: streak,
      message: `WARNING: Alternating between two tool patterns ${streak} times. This looks like a ping-pong loop.`
    };
  }
  return { stuck: false };
}
function detectNoProgress(history, currentHash, toolName) {
  const matching = history.filter((h) => h.argsHash === currentHash && h.resultHash);
  if (matching.length < 3) return { stuck: false };
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
      message: `BLOCKED: ${toolName} returning identical results ${sameResultStreak} times \u2014 no progress. Stop and try a different approach.`
    };
  }
  if (sameResultStreak >= WARNING_THRESHOLD) {
    return {
      stuck: true,
      level: "warning",
      detector: "no_progress",
      count: sameResultStreak,
      message: `WARNING: ${toolName} returning identical results ${sameResultStreak} times. Not making progress.`
    };
  }
  return { stuck: false };
}
function main() {
  let input;
  try {
    input = JSON.parse((0, import_node_fs.readFileSync)("/dev/stdin", "utf8"));
  } catch {
    process.exit(0);
  }
  const toolName = input.tool_name ?? "unknown";
  const params = input.tool_input ?? {};
  const currentHash = hashToolCall(toolName, params);
  const state = loadState();
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
  const resultHash = input.tool_result ? digest(input.tool_result) : void 0;
  state.history.push({
    toolName,
    argsHash: currentHash,
    resultHash,
    timestamp: Date.now()
  });
  if (state.history.length > HISTORY_SIZE) {
    state.history.splice(0, state.history.length - HISTORY_SIZE);
  }
  saveState(state);
  process.exit(0);
}
function outputResult(result) {
  const output = JSON.stringify({
    additionalContext: result.message,
    loop_detected: true,
    detector: result.detector,
    level: result.level,
    count: result.count
  });
  process.stderr.write(output + "\n");
  if (result.level === "critical") {
    process.exit(2);
  }
}
main();
