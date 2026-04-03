# T-817: Three-Tier Config Resolution — Strawman/Steelman Analysis

**Task:** T-817
**Date:** 2026-04-03
**Type:** Inception research artifact (C-001)
**Question:** Should the Agentic Engineering Framework adopt a consistent 3-tier config resolution pattern (explicit arg > env var > default) across all scripts?

---

## Current State

The framework has **50+ shell scripts** with hardcoded configuration values. A partial, inconsistent pattern has already emerged organically:

| Setting | Current pattern | Where |
|---------|----------------|-------|
| `CONTEXT_WINDOW` | `${CONTEXT_WINDOW:-200000}` (env > default) | budget-gate.sh, checkpoint.sh |
| `FW_SAFE_MODE` | `${FW_SAFE_MODE:-0}` (env > default) | check-active-task.sh |
| `FW_PORT` | `${FW_PORT:-3000}` (env > default) | watchtower.sh |
| `FW_TEST_PORT` | `${FW_TEST_PORT:-9877}` (env > default) | onboarding-test.sh |
| `BASH_DEFAULT_TIMEOUT_MS` | `${BASH_DEFAULT_TIMEOUT_MS:-300000}` (env > default) | claude-fw |
| `DISPATCH_LIMIT` | `2` (hardcoded) | check-agent-dispatch.sh |
| `COOLDOWN_SECONDS` | `600` (hardcoded) | checkpoint.sh |
| `STATUS_MAX_AGE` | `90` (hardcoded) | budget-gate.sh |
| `RECHECK_INTERVAL` | `5` (hardcoded) | budget-gate.sh |
| `MAX_RESTARTS` | `5` (hardcoded) | claude-fw |
| `TOKEN_CHECK_INTERVAL` | `5` (hardcoded) | checkpoint.sh |
| `STALE_AGE` (approvals) | `7200` (hardcoded) | checkpoint.sh |
| `STALE_RESOLVED_AGE` | `604800` (hardcoded) | checkpoint.sh |
| Stale task threshold | `7` days (hardcoded) | metrics.sh |
| Stale observation threshold | `7` days (hardcoded) | audit.sh |
| Call fallback thresholds | `40/60/80` (hardcoded) | checkpoint.sh |

**Key observation:** The framework already uses the `${VAR:-default}` pattern for 5 settings. These were added ad-hoc when the need was immediate (T-596 CONTEXT_WINDOW, T-650 FW_SAFE_MODE). There is no discovery mechanism, no documentation, and no validation.

---

## Strawman: Arguments Against

### 1. Complexity for minimal gain

The framework has **one primary operator** (the human) and **one primary agent** (Claude Code). This is not Kubernetes with thousands of operators needing per-deployment knobs. The configuration surface that actually matters day-to-day is tiny:

- `CONTEXT_WINDOW` — already configurable, changed exactly once (200K discovery, T-596)
- `FW_PORT` — already configurable, used by exactly one consumer (Watchtower dev)
- Everything else — unchanged since introduction

Adding env var support to 15+ settings creates 15+ things to document, test, and reason about in debugging sessions. The marginal value of `FW_DISPATCH_LIMIT=5` vs editing line 29 of `check-agent-dispatch.sh` is near zero for a single-operator framework.

### 2. Configuration sprawl risk

Every env var is a knob. Knobs accumulate. Once the pattern exists, the temptation is to make *everything* configurable. The traceAI TraceConfig pattern shows this clearly — it has ~30 settings, most of which no one touches. Framework scripts will accumulate `fw_config "FW_SOMETHING" "default"` calls that no one reads, tests, or validates. The config surface grows monotonically; shrinking it requires deprecation cycles.

Worse: configuration sprawl creates a false sense of flexibility. An operator who sets `FW_STALE_TASK_DAYS=30` thinks they've customized their workflow. In reality, they've changed a metric threshold that affects one line of `fw metrics` output. The settings that actually change behavior (budget thresholds, dispatch limits) are the same 3-5 that are already configurable or trivially made so.

### 3. Hard-to-debug environment differences

Env vars are invisible state. When a framework behaves differently between two machines, the first question is "what's different?" With hardcoded values, the answer is always "the code." With env vars, you must now check:
- Shell profile (.bashrc, .zshrc)
- systemd service files
- Docker/LXC environment
- `.env` files (if adopted)
- Per-session exports

This is especially dangerous for this framework because it runs as Claude Code hooks. The hook execution environment may differ from the interactive shell. A setting that works in `FW_SAFE_MODE=1 fw doctor` may not work when the same variable is in `.bashrc` but the hook runs via a different path. The T-596 discovery — where Anthropic changed the context window without notice — was found precisely because the value was hardcoded and the *mismatch* was observable.

### 4. "Just edit the script" is simpler

This is a bash framework, not a compiled binary. Changing `DISPATCH_LIMIT=2` to `DISPATCH_LIMIT=5` is:
1. Open file
2. Change number
3. Commit

There is no build step, no deployment pipeline, no need to restart a service. The `.agentic-framework/` vendored copy means consumer projects already have a local copy they can edit. The edit is version-controlled, visible in git blame, and immediately effective.

Contrast with the env var path: set the variable somewhere, remember where you set it, hope the execution context inherits it, debug when it doesn't. The simplicity of bash editing is a feature, not a limitation.

### 5. Maintenance burden

Each configurable env var needs:
- Documentation in CLAUDE.md (already 800+ lines)
- Validation in `fw doctor`
- A test that verifies the env var is respected
- A migration path when the default changes

The framework already struggles with documentation freshness (the self-audit checks VERSION sync, hook presence, and directory structure, but not config documentation). Adding 15 env vars means 15 potential documentation-reality gaps that compound over time.

---

## Steelman: Arguments For

### 1. Operators need config without editing framework files

The `.agentic-framework/` vendored copy is meant to be **upgraded**. Running `fw upgrade` pulls the latest framework and overwrites the vendored directory. Any local edits to `check-agent-dispatch.sh` or `checkpoint.sh` are lost. This is by design — the vendored copy should match upstream.

Today, the only way to persistently change `DISPATCH_LIMIT` is to either:
- a) Fork the framework (breaks upgrade path)
- b) Post-upgrade patch script (fragile, untested)
- c) Never upgrade (defeats purpose of shared tooling)

Env vars solve this cleanly: set once in the project's environment, survives upgrades. The `${VAR:-default}` pattern already used by `CONTEXT_WINDOW` proves this works. The question is whether to standardize it, not whether it's viable.

### 2. Consumer projects have legitimately different needs

The framework is designed for shared tooling (`PROJECT_ROOT` vs `FRAMEWORK_ROOT`). A consumer project may need:
- Higher dispatch limits (project with 10 parallel test suites vs single-developer framework)
- Different budget thresholds (using a model with 1M context instead of 200K)
- Different stale-task windows (sprint-based vs continuous delivery)
- Different Watchtower ports (multiple projects on same host)

Two of these (`CONTEXT_WINDOW`, `FW_PORT`) were already needed and added ad-hoc. The T-596 `CONTEXT_WINDOW` change was specifically noted in CLAUDE.md as needing env var configurability because Anthropic can change it without notice. The same reasoning applies to any setting that depends on external factors.

### 3. Env vars are the native abstraction for bash

Bash configuration has exactly three standard mechanisms:
- Config files (INI, YAML, etc.) — requires parsing, adds dependencies
- Command-line flags — already the "explicit arg" tier
- Environment variables — zero-overhead, universally understood

For a bash framework, env vars are not an abstraction — they're the medium. Every script already uses `${VAR:-default}` syntax natively. There's no library to install, no parsing to write, no format to learn. The pattern is already in the codebase 5 times. Standardizing it is cheaper than any alternative.

### 4. CI/CD integration and containerized deployments

The Watchtower deployment (LXC 170) already uses systemd services. Adding configuration today means editing the systemd unit file to set `Environment=FW_PORT=5050`. This is standard, well-understood, and survives `fw upgrade`.

For Docker/LXC/CI environments:
```bash
# Docker
docker run -e FW_CONTEXT_WINDOW=1000000 -e FW_DISPATCH_LIMIT=5 watchtower

# CI
env:
  FW_STALE_TASK_DAYS: 14
  FW_CONTEXT_WINDOW: 200000

# systemd
Environment=FW_PORT=5050
Environment=FW_CONTEXT_WINDOW=200000
```

Without env vars, containerized deployments must either mount patched scripts or run post-start hooks to `sed` values. Both are fragile.

### 5. Evidence from the framework's own evolution

The five existing env vars were all added reactively, each time through the same cycle:
1. Value hardcoded
2. External factor changes (Anthropic, deployment host, test environment)
3. Need to override without editing source
4. Ad-hoc `${VAR:-default}` added, no documentation, no validation

This is the pattern of a missing abstraction. The framework kept discovering it needs configurability, but each time invented it from scratch. A standardized approach would have prevented T-596 from being a surprise (CONTEXT_WINDOW would have been documented and overridable from day one) and T-650 from needing a special escape hatch (FW_SAFE_MODE would have been a standard config knob).

---

## Implementation Sketch

### lib/config.sh — Central config helper

```bash
#!/bin/bash
# lib/config.sh — 3-tier configuration resolution
# Pattern: explicit arg > env var > hardcoded default
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/config.sh"
#   CONTEXT_WINDOW=$(fw_config "CONTEXT_WINDOW" 200000)
#   DISPATCH_LIMIT=$(fw_config "DISPATCH_LIMIT" 2)

[[ -n "${_FW_CONFIG_LOADED:-}" ]] && return 0
_FW_CONFIG_LOADED=1

# fw_config KEY DEFAULT [EXPLICIT_VALUE]
# Returns: EXPLICIT_VALUE if non-empty, else FW_KEY env var, else DEFAULT
fw_config() {
    local key="$1"
    local default="$2"
    local explicit="${3:-}"

    # Tier 1: Explicit argument wins
    if [ -n "$explicit" ]; then
        echo "$explicit"
        return
    fi

    # Tier 2: Environment variable (FW_ prefix)
    local env_var="FW_${key}"
    local env_val="${!env_var:-}"
    if [ -n "$env_val" ]; then
        echo "$env_val"
        return
    fi

    # Tier 3: Default
    echo "$default"
}

# fw_config_int — Same as fw_config but validates integer
fw_config_int() {
    local val
    val=$(fw_config "$@")
    if ! [[ "$val" =~ ^[0-9]+$ ]]; then
        echo "ERROR: FW_$1 must be integer, got '$val'" >&2
        echo "$2"  # Fall back to default
        return
    fi
    echo "$val"
}
```

### Migration: budget-gate.sh

Before:
```bash
CONTEXT_WINDOW=${CONTEXT_WINDOW:-200000}
RECHECK_INTERVAL=5
STATUS_MAX_AGE=90
```

After:
```bash
source "$FRAMEWORK_ROOT/lib/config.sh"
CONTEXT_WINDOW=$(fw_config_int "CONTEXT_WINDOW" 200000)
RECHECK_INTERVAL=$(fw_config_int "BUDGET_RECHECK_INTERVAL" 5)
STATUS_MAX_AGE=$(fw_config_int "BUDGET_STATUS_MAX_AGE" 90)
```

### Migration: checkpoint.sh

Before:
```bash
CONTEXT_WINDOW=${CONTEXT_WINDOW:-200000}
TOKEN_CHECK_INTERVAL=5
CALL_WARN=40
CALL_URGENT=60
CALL_CRITICAL=80
COOLDOWN_SECONDS=600
```

After:
```bash
source "$FRAMEWORK_ROOT/lib/config.sh"
CONTEXT_WINDOW=$(fw_config_int "CONTEXT_WINDOW" 200000)
TOKEN_CHECK_INTERVAL=$(fw_config_int "TOKEN_CHECK_INTERVAL" 5)
CALL_WARN=$(fw_config_int "CALL_WARN" 40)
CALL_URGENT=$(fw_config_int "CALL_URGENT" 60)
CALL_CRITICAL=$(fw_config_int "CALL_CRITICAL" 80)
COOLDOWN_SECONDS=$(fw_config_int "HANDOVER_COOLDOWN" 600)
```

### Migration: check-agent-dispatch.sh

Before:
```bash
DISPATCH_LIMIT=2
```

After:
```bash
source "$FRAMEWORK_ROOT/lib/config.sh"
DISPATCH_LIMIT=$(fw_config_int "DISPATCH_LIMIT" 2)
```

### Migration: handover.sh

The handover script doesn't have obvious configurable values — its behavior is structural. No migration needed. The `COOLDOWN_SECONDS` that affects handover behavior is in checkpoint.sh.

### Top 15 Configurable Settings

| Env Var | Default | Script | What it controls |
|---------|---------|--------|-----------------|
| `FW_CONTEXT_WINDOW` | `200000` | budget-gate, checkpoint | Context window size for budget enforcement |
| `FW_PORT` | `3000` | watchtower.sh | Watchtower web UI port |
| `FW_DISPATCH_LIMIT` | `2` | check-agent-dispatch | Agent tool dispatches before TermLink gate |
| `FW_BUDGET_RECHECK_INTERVAL` | `5` | budget-gate | Re-read transcript every N tool calls |
| `FW_BUDGET_STATUS_MAX_AGE` | `90` | budget-gate | Max seconds before cached status is stale |
| `FW_TOKEN_CHECK_INTERVAL` | `5` | checkpoint | Check tokens every N tool calls |
| `FW_HANDOVER_COOLDOWN` | `600` | checkpoint | Seconds between auto-handover triggers |
| `FW_STALE_TASK_DAYS` | `7` | metrics.sh | Days before task is flagged stale |
| `FW_STALE_OBS_DAYS` | `7` | audit.sh | Days before observation is flagged stale |
| `FW_STALE_APPROVAL_AGE` | `7200` | checkpoint | Seconds before pending approval is cleaned |
| `FW_MAX_RESTARTS` | `5` | claude-fw | Max consecutive auto-restarts |
| `FW_RESTART_SIGNAL_TTL` | `300` | claude-fw | Seconds before restart signal is stale |
| `FW_SAFE_MODE` | `0` | check-active-task | Bypass task gate (already exists) |
| `FW_BASH_TIMEOUT` | `300000` | claude-fw | Default Bash tool timeout (ms) |
| `FW_CALL_WARN` / `URGENT` / `CRITICAL` | `40/60/80` | checkpoint | Fallback tool-call thresholds |

### fw doctor validation

```bash
# In fw doctor:
echo "Configuration:"
source "$FRAMEWORK_ROOT/lib/config.sh"

# Show any FW_* overrides
env | grep "^FW_" | sort | while read -r line; do
    echo "  OVERRIDE: $line"
done

# Validate known settings
CONTEXT_WINDOW=$(fw_config_int "CONTEXT_WINDOW" 200000)
if [ "$CONTEXT_WINDOW" -lt 50000 ]; then
    warn "FW_CONTEXT_WINDOW=$CONTEXT_WINDOW is very low — budget gate will fire early"
elif [ "$CONTEXT_WINDOW" -gt 2000000 ]; then
    warn "FW_CONTEXT_WINDOW=$CONTEXT_WINDOW exceeds known model limits"
fi

DISPATCH_LIMIT=$(fw_config_int "DISPATCH_LIMIT" 2)
if [ "$DISPATCH_LIMIT" -gt 10 ]; then
    warn "FW_DISPATCH_LIMIT=$DISPATCH_LIMIT — very high, risk of context explosion"
fi
```

### CLAUDE.md documentation

Add a new section after the existing `## Context Budget Management`:

```markdown
## Configuration

Framework settings follow a 3-tier resolution: explicit CLI flag > `FW_*` env var > default.

| Setting | Env Var | Default | Purpose |
|---------|---------|---------|---------|
| Context window | `FW_CONTEXT_WINDOW` | `200000` | Token budget enforcement |
| Dispatch limit | `FW_DISPATCH_LIMIT` | `2` | Agent tool cap before TermLink gate |
| Watchtower port | `FW_PORT` | `3000` | Web UI listen port |
| Safe mode | `FW_SAFE_MODE` | `0` | Bypass task gate |
| ... | ... | ... | ... |

Check active overrides: `env | grep FW_`
Validate: `fw doctor` shows warnings for out-of-range values.
```

---

## Recommendation

**GO — with a narrow scope.**

### Rationale

1. **The pattern already exists.** Five settings already use `${VAR:-default}`. The question is not "should we allow env var configuration?" — that decision was made in T-596. The question is "should we standardize the pattern so it's discoverable and validated?"

2. **The cost is near-zero.** `lib/config.sh` is ~30 lines. Migration per-script is replacing `VAR=default` with `VAR=$(fw_config_int "VAR" default)`. No behavioral change, no breaking change, no new dependency.

3. **The scope should be narrow.** Apply to the top 10 settings listed above — the ones that have either been needed before or plausibly will be needed in consumer projects. Do not apply to every constant in every script. The strawman's "configuration sprawl" argument is valid and should be actively resisted.

4. **Validation prevents the debugging risk.** The strawman's "invisible state" argument is countered by `fw doctor` surfacing all overrides and `fw_config_int` rejecting non-integer values. Without standardization, the existing ad-hoc env vars have no validation — `CONTEXT_WINDOW=banana` silently breaks budget-gate.sh today.

### Scope guardrails

- Only add `fw_config` for settings that have been needed externally OR are plausibly different across consumer projects
- Max 15 settings in v1. New settings require a "why is this configurable?" justification
- All env vars documented in one CLAUDE.md table
- `fw doctor` warns on all overrides and validates ranges
- Never make structural constants configurable (task file format, directory names, hook mechanics)

### Watchtower config page (user-suggested addition)

A `/config` page in Watchtower would provide visibility into all framework settings:
- Table: setting name, current value, source (env var / default), description
- Warning indicators for out-of-range values (reuse `fw doctor` validation logic)
- Read-only — env vars are set outside the web UI, but seeing all settings in one place aids debugging
- Implementation: new blueprint `web/blueprints/config.py`, one template, reads `env | grep FW_` and maps against the known settings table

This is a natural complement to `fw doctor` output — `fw doctor` is CLI, `/config` is web.

### Not recommended

- A `.fw-config.yaml` file — bash `${VAR:-default}` is already the native mechanism; adding YAML parsing is overengineering
- A `fw config set/get` CLI — env vars are simpler and more portable
- Making everything configurable — the strawman's sprawl argument holds for marginal settings

---

## Dialogue Log

*(Research artifact created before inception dialogue; no human dialogue recorded yet.)*
