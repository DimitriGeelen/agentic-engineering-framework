# T-1102: RCA — bin/fw Hardcoded in Framework Error Messages (G-033)

**Date:** 2026-04-11  
**Task:** T-1102 (inception)  
**Origin gap:** G-033  
**Related:** T-609, T-1093, ring20-dashboard transcript, /opt/termlink T-909 transcript

---

## Phase 1 — Audit

### Methodology

```
grep -rn 'bin/fw' lib/ agents/ web/ bin/ .tasks/templates/ tests/ docs/ \
  --include='*.sh' --include='*.py' --include='*.md'
```

Classified each match into 5 categories:
- **BUG** — user-facing emitted message, hardcodes `bin/fw` regardless of project mode
- **EDGE** — consumer context bug but lower severity (rare trigger condition)
- **TEMPLATE** — template/doc with wrong default (static, not runtime, but misleads)
- **OK-INTERNAL** — `$FRAMEWORK_ROOT/bin/fw` or internal call (always correct)
- **OK-DETECT** — string used as pattern for detection/allowlist (not emitted)
- **OK-COMMENT** — comment or documentation (not executed)

---

### BUG — User-facing messages, hardcoded `bin/fw`

| File | Line | Message emitted | Context |
|------|------|-----------------|---------|
| `lib/inception.sh` | 215 | `cd $PROJECT_ROOT && bin/fw task review $task_id` | Blocked when `fw inception decide` runs before review |
| `lib/review.sh` | 127 | `cd $PROJECT_ROOT && bin/fw inception decide $task_id go --rationale "..."` | Printed after `fw task review` for inception tasks |
| `agents/context/check-tier0.sh` | 377 | `./bin/fw tier0 approve` | Printed when a Tier 0 action is blocked |

**All three are actively user-visible error/instruction messages.** Both ring20-dashboard and T-909 incidents triggered `lib/inception.sh:215` or `lib/review.sh:127`. In consumer projects, `bin/fw` does not exist at PROJECT_ROOT — only `.agentic-framework/bin/fw` (pre-shim) or bare `fw` (post-shim).

Additional note on `check-tier0.sh:377`: uses `./bin/fw` (relative path with `./` prefix) rather than bare `bin/fw`, and lacks a `cd PROJECT_ROOT &&` prefix entirely. Two defects: wrong path for consumer projects, and missing `cd` context (T-609 compliance gap beyond scope of this inception).

---

### EDGE — Consumer context bug, rare trigger

| File | Lines | Issue |
|------|-------|-------|
| `lib/verify-acs.sh` | 159, 161, 163, 168 | Python inline: `check_command("bin/fw version")`, `check_command("bin/fw update --check")`, `check_command("bin/fw doctor")`, `check_command("bin/fw task verify...")` |

These execute subprocess calls in the current working directory (PROJECT_ROOT). In a consumer project, `bin/fw version` fails with "command not found" (no `bin/fw` in PROJECT_ROOT). However, these checks only fire when a Human AC's text contains `fw version`, `fw doctor`, etc. — in practice, those ACs appear only in framework self-hosted tasks. Low practical severity.

---

### TEMPLATE — Wrong default in TermLink template

| File | Lines | Issue |
|------|-------|-------|
| `.tasks/templates/path-c-deep-dive.md` | 62-64, 135 | TermLink commands use `bin/fw init --force`, `bin/fw doctor`, `grep -c 'bin/fw hook' .claude/settings.json` inside consumer project context via termlink |

Static template, not runtime. Users customizing this template for a consumer project would discover the issue when they run the TermLink commands. Low urgency but should be updated.

---

### OK — Internal calls, tests, patterns, docs

| Category | Examples | Count |
|----------|----------|-------|
| `$FRAMEWORK_ROOT/bin/fw` qualified calls | `lib/upstream.sh:246`, `lib/setup.sh:454`, `lib/update.sh:358,447`, `agents/audit/audit.sh:32`, `agents/onboarding-test/*`, all `tests/integration/*.bats`, all `tests/e2e/*.sh` | ~60 |
| Detection patterns (bin/fw as string to match) | `agents/context/check-project-boundary.sh:111,121,154`, `agents/context/session-metrics.sh:155`, `agents/context/check-active-task.sh:62`, `agents/context/lib/safe-commands.sh:50` | 5 |
| lib/init.sh path detection logic | `lib/init.sh:401,580-583` — fw_prefix detection (see §Phase 2) | 4 |
| upgrade/update internal path operations | `lib/upgrade.sh:358-365,451-497`, `lib/update.sh:237-238` | ~12 |
| Self-references (bin/fw defining itself) | `bin/fw` lines 70, 268, 269, 277, 405, 793, 798, 799, 913 | ~9 |
| bin/fw-shim documentation | `bin/fw-shim` lines 4, 9, 10, 12, 21-28, 40, 45 | ~10 |
| lib/version.sh (version sync logic) | Lines 51, 76, 79, 107, 109, 123-126, etc. — framework internal version management | ~15 |
| Comment/docs | `lib/costs.sh:8,244`, `lib/preflight.sh:15`, `lib/version.sh` labels | ~5 |
| docs/ | walkthrough, plans, reports, prompts — all static docs referencing `bin/fw` as the framework's own CLI | ~30 |

Total OK instances: ~150.  
Total BUG instances: **3 active** + 1 edge + 1 template.

---

## Phase 2 — Helper Sketch

### Existing art: `lib/init.sh:579-583`

The detection pattern already exists:

```bash
# T-663/T-662: Detect framework-mode vs consumer-mode for fw path
# Framework repo uses bin/fw (project-relative), consumers use .agentic-framework/bin/fw (vendored)
local fw_prefix=".agentic-framework/bin/fw"
if [ -x "$dir/bin/fw" ] && [ -f "$dir/FRAMEWORK.md" ]; then
    fw_prefix="bin/fw"
fi
```

This is used in `lib/init.sh` to generate the correct path for `.claude/settings.json` hooks. The bug is that this pattern was **not extracted to a shared helper**, so `lib/inception.sh` and `lib/review.sh` reinvented the wheel — incorrectly, by hardcoding `bin/fw` without the conditional.

### Proposed helper: `_fw_cmd_for_user()`

**Location:** `lib/paths.sh` (already auto-sourced by all lib scripts via the lib/errors.sh → lib/paths.sh chain; PROJECT_ROOT and FRAMEWORK_ROOT are already set when it runs).

```bash
# _fw_cmd_for_user — Return the fw command form appropriate for the current project context.
#
# Outputs the correct form of the fw command for user-facing messages:
#   bin/fw                    — framework repo (PROJECT_ROOT has bin/fw + FRAMEWORK.md)
#   fw                        — consumer project, shim installed (bare fw routes correctly)
#   .agentic-framework/bin/fw — consumer project, no shim (vendored path)
#
# Usage:
#   local fw_cmd
#   fw_cmd="$(_fw_cmd_for_user)"
#   echo "Run: cd $PROJECT_ROOT && $fw_cmd task review $task_id"
#
# Origin: T-1102 (G-033 — bin/fw hardcoded in framework error messages)
_fw_cmd_for_user() {
    # Framework repo: has bin/fw + FRAMEWORK.md at PROJECT_ROOT
    if [ -x "${PROJECT_ROOT}/bin/fw" ] && [ -f "${PROJECT_ROOT}/FRAMEWORK.md" ]; then
        echo "bin/fw"
        return 0
    fi

    # Consumer project: check if the shim is installed
    # Shim contains the find_fw() function — distinguishes it from a legacy symlink
    local global_fw
    global_fw="$(command -v fw 2>/dev/null || true)"
    if [ -n "$global_fw" ] && grep -q "find_fw()" "$global_fw" 2>/dev/null; then
        # Shim installed — bare 'fw' will self-route to .agentic-framework/bin/fw
        echo "fw"
        return 0
    fi

    # Consumer project, no shim — use vendored path
    echo ".agentic-framework/bin/fw"
}
```

### Call sites after build

```bash
# lib/inception.sh:215 (BEFORE)
echo -e "  cd $PROJECT_ROOT && bin/fw task review $task_id" >&2

# lib/inception.sh:215 (AFTER)
local fw_cmd
fw_cmd="$(_fw_cmd_for_user)"
echo -e "  cd $PROJECT_ROOT && $fw_cmd task review $task_id" >&2
```

```bash
# lib/review.sh:127 (BEFORE)
echo "  cd $PROJECT_ROOT && bin/fw inception decide $task_id go --rationale \"your rationale\""

# lib/review.sh:127 (AFTER)
local fw_cmd
fw_cmd="$(_fw_cmd_for_user)"
echo "  cd $PROJECT_ROOT && $fw_cmd inception decide $task_id go --rationale \"your rationale\""
```

```bash
# agents/context/check-tier0.sh:377 (BEFORE)
echo "    ./bin/fw tier0 approve" >&2

# agents/context/check-tier0.sh:377 (AFTER)
# Note: check-tier0.sh sources lib/paths.sh so PROJECT_ROOT and helper are available
local fw_cmd
fw_cmd="$(_fw_cmd_for_user)"
echo "    cd $PROJECT_ROOT && $fw_cmd tier0 approve" >&2
```

Note: the `check-tier0.sh` fix also adds the missing `cd $PROJECT_ROOT &&` prefix (T-609 compliance). That's a two-for-one fix at the same call site — acceptable to bundle.

---

## Phase 3 — T-609 Intent Review

**Task:** `T-609-codify-full-path-command-rule--agent-mus.md`

Key quotes:
> "When the agent gives humans commands to run, they must be single-line, copy-pasteable, with cd to PROJECT_ROOT and bin/fw not bare fw."

> "Origin: user ran `fw inception decide` from `/home/dimitri-mint-dev/` — got 'No framework project detected'. The global `fw` resolves to a different install."

**Finding:** T-609's intent is *copy-pasteable, unambiguous commands*. The concrete problem it solved was: bare `fw` pointing to the wrong install from the wrong directory. The rule was operationalized as "use `bin/fw`" — correct for the framework repo where T-609 was developed and applied. But T-609 did not distinguish self-host vs consumer-host contexts; the wording "bin/fw not bare fw" was written from a self-host-only vantage point.

**Assumption A-4 confirmed:** T-609 does not need to be repealed. Its intent (unambiguous, correct copy-paste) is right. The fix is context-aware path output. After the fix:
- Self-host users get `bin/fw` — same as before
- Consumer post-shim users get `fw` — correct because the shim resolves it  
- Consumer pre-shim users get `.agentic-framework/bin/fw` — previously broken, now fixed

---

## Phase 4 — Backwards Compat Audit

### Tests (`tests/`)

All 40+ integration and e2e test files use `$FRAMEWORK_ROOT/bin/fw` — explicitly qualified with `$FRAMEWORK_ROOT`. They do not invoke `_fw_cmd_for_user`. Zero test breakage from adding the helper.

Test behaviour after the fix:
- Tests run in framework repo context (FRAMEWORK_ROOT = PROJECT_ROOT)
- `_fw_cmd_for_user()` in that context → `bin/fw` (self-host branch)
- Output of `lib/inception.sh:215` changes from `bin/fw` to `bin/fw` — **identical**
- Tests asserting on inception/review message content would still pass

One test file of interest: `tests/integration/fw_inception.bats` — likely tests `fw inception decide` error output. If it asserts on `bin/fw` in the output, it would pass unchanged (self-host context → `bin/fw`). No risk of test breakage.

### Docs (`docs/`)

All `docs/` references to `bin/fw` are in static markdown — descriptive prose, plans, reports about the framework's own CLI path. None are runtime-generated. Zero impact.

### CLAUDE.md

Contains `bin/fw` extensively in examples under "Copy-Pasteable Commands" rule. These examples are for agents operating in the framework repo context. No change needed — the rule is about the *agent's behavior*, not the framework's emitted messages. After the fix, the agent will still emit `bin/fw` for CLAUDE.md-governed instructions when in self-host context.

### `.agentic-framework/` (vendored copy)

`lib/upgrade.sh` syncs `lib/inception.sh` and `lib/review.sh` to consumer vendored copies during `fw upgrade`. After the fix is applied to the framework repo:
1. The helper `_fw_cmd_for_user()` lands in `lib/paths.sh`
2. `fw upgrade <consumer>` copies the updated `lib/inception.sh`, `lib/review.sh`, and `lib/paths.sh` to the consumer's `.agentic-framework/lib/`
3. Consumer gets the fix automatically — no manual intervention

This is the standard propagation path. No special backwards compat concern.

### `.tasks/templates/path-c-deep-dive.md`

Contains `bin/fw` in TermLink commands meant for consumer project context. These are template placeholders — users fill in `{project}` and other variables. The fix for this template is out of scope for the build task (separate concern) but should be captured as a follow-on.

---

## Phase 5 — Recommendation

### Evidence Summary

| Evidence | Detail |
|----------|--------|
| Confirmed BUG count | 3 user-facing emitted messages |
| Incident count | 2 same-day incidents (ring20-dashboard, /opt/termlink T-909), both hit lib/inception.sh:215 or lib/review.sh:127 |
| Fix pattern already exists | `lib/init.sh:579-583` — identical detection logic, just not extracted to a helper |
| Helper complexity | ~15 lines, 3 branches, no new dependencies |
| Impact on tests | Zero — tests run in self-host context, helper returns same value |
| Impact on docs | Zero |
| Propagation path | Standard (`fw upgrade` syncs lib/ to vendored copies) |
| T-609 intent | Preserved and extended — commands remain copy-pasteable, now also context-correct |
| Risk | Low — additive change; self-host path unchanged; consumer path fixed; no test modifications needed |

### Go/No-Go Criteria

**GO if:**
- A helper function can correctly detect context (self-host vs consumer vs shim) without false positives — **YES**, detection logic proven in `lib/init.sh:579-583`
- The fix covers all 3 confirmed BUG call sites — **YES**: inception.sh, review.sh, check-tier0.sh
- Backward compat preserved for existing tests and docs — **YES**: self-host context returns identical `bin/fw`
- T-609 intent preserved — **YES**: commands remain single-line, copy-pasteable, unambiguous

**NO-GO if:**
- Shim detection is unreliable, causing false "fw" output in pre-shim consumer projects — **MITIGATED**: the helper falls through to `.agentic-framework/bin/fw` if shim is not detected; worst case a pre-shim user gets `fw` instead of `.agentic-framework/bin/fw`, which fails, but they also had the shim available to install
- Multiple unrelated callers emit different messages that can't share one helper — **FALSE**: all 3 bug sites use the same pattern (`cd $PROJECT_ROOT && <fw_cmd> ...`)

### Recommendation

**Recommendation:** GO

**Rationale:** Two same-day incidents from two independent consumer projects confirm the bug class is real and recurring. The fix is mechanical: extract `_fw_cmd_for_user()` from the already-existing detection pattern in `lib/init.sh:579-583` into `lib/paths.sh`, then replace the 3 hardcoded `bin/fw` strings in emitted messages. Risk is minimal — self-host context is unchanged, consumer context gains correct path. Shim-aware 3rd branch adds robustness at low cost. T-609's intent is preserved and the helper makes it enforceable at the right level of abstraction.

**Evidence:**
- `lib/inception.sh:215` — active user-facing BUG, emits `bin/fw` unconditionally
- `lib/review.sh:127` — active user-facing BUG, emits `bin/fw` unconditionally
- `agents/context/check-tier0.sh:377` — active user-facing BUG, emits `./bin/fw` unconditionally (also missing `cd PROJECT_ROOT &&`)
- Detection pattern reuse from `lib/init.sh:579-583` confirms helper is the right abstraction
- All 40+ test files use `$FRAMEWORK_ROOT/bin/fw` (qualified) — zero breakage risk
- `fw upgrade` will propagate fix to vendored consumer copies automatically

**Out-of-scope for build task (separate follow-ons):**
- `lib/verify-acs.sh:159-168` — Python inline `check_command("bin/fw ...")` edge case (low priority, rare trigger)
- `.tasks/templates/path-c-deep-dive.md:62-64` — template bug (static, not runtime)
- T-609 CLAUDE.md rule wording clarification (may want to update "bin/fw not bare fw" to "context-appropriate fw path")

---

## Assumptions Validation

| ID | Assumption | Result |
|----|-----------|--------|
| A-1 | Every `bin/fw` emitted message has the same root cause, fixable with one helper | **CONFIRMED** — all 3 BUG sites use the same `cd $PROJECT_ROOT && bin/fw` pattern |
| A-2 | Single helper in lib/paths.sh can detect context | **CONFIRMED** — pattern already proven in lib/init.sh:579-583 |
| A-3 | Shim makes bare `fw` work for consumer post-shim; pre-shim needs `.agentic-framework/bin/fw` | **CONFIRMED** — bin/fw-shim walks up from CWD and routes to vendored .agentic-framework/bin/fw |
| A-4 | T-609 doesn't need repeal — fix is context-aware output | **CONFIRMED** — T-609's intent is "unambiguous copy-pasteable"; the fix serves that intent |
