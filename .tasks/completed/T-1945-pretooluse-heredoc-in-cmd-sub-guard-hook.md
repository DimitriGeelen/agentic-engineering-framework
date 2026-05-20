---
id: T-1945
name: "PreToolUse heredoc-in-cmd-sub guard hook for bin/fw — L-332/L-408 surface at
  edit moment"
description: >
  PreToolUse heredoc-in-cmd-sub guard hook for bin/fw — L-332/L-408 surface at edit
  moment

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [arc:value-prioritisation, future-prevention, L-332, L-408, hooks]
components: [agents/context/check-heredoc-cmd-sub.sh, C-009, lib/heredoc_guard.py, tests/unit/test_heredoc_cmd_sub_guard.bats]
related_tasks: [T-1944, T-1942, T-1943, T-1629]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T06:10:35Z
last_update: 2026-05-20T06:22:04Z
date_finished: 2026-05-20T06:22:04Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-05-20T06:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1945: PreToolUse heredoc-in-cmd-sub guard hook for bin/fw — L-332/L-408 surface at edit moment

## Context

L-332 (T-1629, 2026-05-01) explicitly banned `$(cmd <<EOF ... EOF)` in
hot-path bash dispatchers (bin/fw, agent hook shims). L-408 (T-1942,
2026-05-19) is the 3rd-incident reinforcement of the same class.
T-1944 (2026-05-20) closed the cron-drift case by extracting both
inline heredocs to `lib/cron_dry_run.py`.

Despite the rule existing for 19 days, T-1942 introduced the very
pattern L-332 banned because the related-knowledge surface
(`fw work-on` sidebar) was visible only at task-create time. Once
the agent was deep in editing bin/fw, the rule was out of mind.
The cosmetic warning emitted by bash was the only signal — and that
signal turned out to be misleading (trying to "fix" it lost the
closing `)` and self-locked the agent twice).

**The gap:** Prevention surface at TASK-CREATE is insufficient.
The rule needs to fire at EDIT-TIME — the moment the agent is
about to add a `python3 - <<TAG` block inside `$(...)` to bin/fw.

**Approach:** PreToolUse hook on `Write|Edit` matching `bin/fw`
file_path. Reads JSON stdin, extracts proposed `content` (Write) or
`new_string` (Edit), greps for `\$\(.*python3.*<<` or
`\$\([^)]*<<['"]?[A-Z_]+`. If pattern found, emit a one-line stderr
warning naming L-332/L-408 with the canonical extraction pattern.

**Severity decision (see Decisions):** WARN-only (exit 0), NOT block.
Reason: not every heredoc-in-cmd-sub is dangerous (the multi-line-
clean `<<PYEOF\n...\nPYEOF\n)` shape at bin/fw:1911 has been stable
for weeks). Blocking would also create a chicken-and-egg if the
agent legitimately needs to MODIFY an existing heredoc to fix
something. WARN gets attention without obstructing legitimate work.

Out of scope:
- Extracting the OTHER bin/fw heredoc at line 1911 (T-1735
  worker-kinds parity) — file as sibling task if WARN catches it.
- Hook for audit.sh or other hot-path scripts beyond bin/fw —
  bin/fw is the canonical lockout-class file; expand later if needed.

## Acceptance Criteria

### Agent
- [x] `agents/context/check-heredoc-cmd-sub.sh` exists, executable, reads PreToolUse JSON from stdin (final path; `agents/context/` is the convention for `fw hook` dispatch).
- [x] Hook detects `python3 - <<TAG` or `$(... <<['"]?[A-Z_]+)` in the proposed Edit `new_string` / Write `content` when `tool_input.file_path` ends in `bin/fw`. Detection delegated to `lib/heredoc_guard.py` (forced extraction per L-332 — see Evolution).
- [x] When pattern detected: stderr emits a multi-line warning referencing L-332 and L-408 + the canonical extract-to-`lib/*.py` rule. Hook exits 0 (advisory, non-blocking).
- [x] When pattern absent: hook exits 0 silently (no spurious output).
- [x] Hook is wired into `.claude/settings.json` under `PreToolUse` matcher `Write|Edit` via `bin/fw hook-enable` (settings.json is human-protected; hook-enable is the canonical wire-in path).
- [x] `bin/fw enforcement baseline` refreshed after settings.json change (L-398). Hash: `ae2e99f41a709dd5...`
- [x] Bats unit test `tests/unit/test_heredoc_cmd_sub_guard.bats`: **7** cases — (a) bin/fw + heredoc → warns; (b) bin/fw + no heredoc → silent; (c) non-bin/fw + heredoc → silent; (d) Write tool with heredoc in content → warns; (e) Bash tool → silent; (f) non-python3 heredoc → warns; (g) malformed JSON → fail-open silent.
- [x] `bin/fw doctor` and `bash -n bin/fw` remain clean (no parse warnings); cosmetic warning eliminated post-T-1944.

### Human

(none — hook behaviour is deterministic, bats-verifiable.)

<!-- (template retained below for reference)
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

bash -n agents/context/check-heredoc-cmd-sub.sh
bats tests/unit/test_heredoc_cmd_sub_guard.bats
python3 -c "import json; cfg=json.load(open('.claude/settings.json')); hooks=cfg.get('hooks',{}).get('PreToolUse',[]); assert any('check-heredoc-cmd-sub' in str(h) for h in hooks), 'hook not wired in settings.json'"
bash -n bin/fw
out=$(bin/fw doctor 2>&1); echo "$out" | head -1 | grep -q "Framework Health Check"

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

### 2026-05-20 — Hook itself violated L-332 during build (own dogfood)

- **What changed:** Initial hook draft used `read -r TOOL FP PAYLOAD <<< "$(echo "$INPUT" | python3 - <<'PY' ... PY)"` to parse stdin. Smoke-test FAILED silently — the python3 inside `$()` consumed the heredoc as its stdin (`<<'PY' ... PY`), starving the `echo "$INPUT" |` pipe of a reader. `json.load(sys.stdin)` got the Python source code instead of the JSON, raised an exception, and the fallback returned `UNKNOWN UNKNOWN ""` for everything. Bash `bash -n` passed cleanly — the failure was at runtime, in stdin routing semantics.
- **Plan impact:** Forced extraction of the detection logic to `lib/heredoc_guard.py` (the exact L-332 prescription the hook exists to enforce). This made the build slice "hook script + helper + bats + fabric cards" instead of just "hook script + bats". The post-tool-use SCOPE ALERT correctly flagged 4 new files, but they are all in service of the same single AC set — not pickup-message scope creep.
- **Triggered:** Recursive self-validation: the moment of writing the L-332 guard caught me writing an L-332 violation. Meta-prevention working. No new sub-task — the helper extraction folded into this build.

### 2026-05-20 — bin/fw still has one heredoc at line 1911 (T-1735 worker-kinds parity)

- **What changed:** Discovered a second `python3 - <<PYEOF ... PYEOF` block in bin/fw (`do_doctor`, worker-kinds parity check) that this hook will warn on next time someone edits it. The block is currently stable (no parse warning at runtime, multi-line-clean shape), but technically still an L-332 violation.
- **Plan impact:** Intentionally NOT extracted in this task (scope kept tight to T-1945's AC set). The hook's warning is the trigger — if/when someone next edits that block, the WARN fires and they extract then.
- **Triggered:** No sibling filed proactively (would dilute the gate's signal). The hook itself is the proactive instrument now.

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

**Recommendation:** GO (work-completed)

**Rationale:** Structural prevention for the L-332/L-408 lockout class shipped end-to-end at the edit moment (not just task-create time). Hook delegates detection to `lib/heredoc_guard.py` — the same canonical pattern T-1944 just established for the cron-drift case. 7 bats cases pinning behaviour. Settings.json wired via `fw hook-enable` (canonical path); enforcement baseline refreshed. Advisory-only (exit 0) by design — does not obstruct legitimate edits to an already-existing heredoc; surfaces the rule at the moment of decision so the agent does not need to remember.

**Evidence:**
- `bats tests/unit/test_heredoc_cmd_sub_guard.bats` — 7/7 PASS
- `bash -n agents/context/check-heredoc-cmd-sub.sh` — clean
- `bash -n bin/fw` — clean (no parse warnings)
- `bin/fw doctor` first line is the banner (no cosmetic noise)
- Hook registered in `.claude/settings.json` PreToolUse → Write|Edit chain via `fw hook-enable`
- Enforcement baseline refreshed: hash `ae2e99f41a709dd5...`
- Fabric cards created for hook + helper + bats
- Live smoke (positive/negative/out-of-scope) all behave correctly

## Decisions

### 2026-05-20 — WARN-only, not BLOCK
- **Chose:** Advisory warning to stderr; exit 0 always.
- **Why:** Not every heredoc-in-cmd-sub is the dangerous shape — the stable multi-line-clean `<<PYEOF\n...\nPYEOF\n)` form at bin/fw:1911 has been fine for weeks. Blocking would also create chicken-and-egg if someone legitimately needs to MODIFY an existing heredoc to fix something (e.g., the T-1944 extraction itself touched the heredoc on its way out). WARN surfaces the rule without obstructing.
- **Rejected:** (a) BLOCK with `FW_ALLOW_HEREDOC_IN_BIN_FW=1` override — too friction-heavy for a rule that's about *consideration* rather than *prohibition*. (b) BLOCK only when heredoc body >10 lines — adds parsing complexity without clear benefit (the WARN already references the 10-line L-332 threshold in its text).

### 2026-05-20 — Detection helper in `lib/heredoc_guard.py`
- **Chose:** Extract detection logic to a python file; bash side stays parse-safe.
- **Why:** Own dogfood — discovered during build that the initial inline `python3 - <<'PY' ... PY` shape inside `$()` consumed the heredoc as stdin instead of the pipe. The bug only surfaced at runtime (bash -n was clean). Fixing it meant applying L-332 to the L-332 guard itself. The recursive self-validation is the strongest possible proof the rule has teeth.
- **Rejected:** (a) Inline `python3 -c "..."` — too long, escape-prone (~30 lines). (b) Embedded `awk`/`grep` only — would miss multi-line patterns and lose JSON parsing.

### 2026-05-20 — Hook lives in `agents/context/`, not a new `agents/hooks/`
- **Chose:** Drop the file at `agents/context/check-heredoc-cmd-sub.sh`.
- **Why:** That's where the existing check-* hooks live (check-active-task, check-arc-id, check-human-ac-tick, ...) and `fw hook` dispatch auto-discovers everything matching `agents/context/*.sh`. A new directory would need bin/fw plumbing changes for zero benefit.
- **Rejected:** `agents/hooks/` — would split the existing hook set across two paths and require dispatch changes.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-20T06:10:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1945-pretooluse-heredoc-in-cmd-sub-guard-hook.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-a0130dbf
- **Timestamp:** 2026-05-20T06:24:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-20T06:22:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
