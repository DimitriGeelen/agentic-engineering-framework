---
id: T-2724
name: "fw init reports 19 broken hooks on a correct install — validator never expands CLAUDE_PROJECT_DIR"
description: >
  fw init reports 19 broken hooks on a correct install — validator never expands CLAUDE_PROJECT_DIR

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/validate-init.sh, tests/unit/validate_init_hook_path_expansion.bats]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-02T06:17:02Z
last_update: 2026-08-02T06:27:34Z
date_finished: 2026-08-02T06:27:34Z
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
---

# T-2724: fw init reports 19 broken hooks on a correct install — validator never expands CLAUDE_PROJECT_DIR

## Context

Found while working arc-015 (T-2723): every `fw init` ends with

```
  ✗ hookpaths-6vc  Hook script paths all resolve — 19 hook script(s) not found
  ✗ func-paths  Missing hook scripts: fw,fw,fw,fw,fw,fw,fw,fw,fw,fw,fw,fw,fw,fw,fw,fw,fw,fw,fw
  Validation: 2 error(s) out of 42 checks
Init completed with validation errors — check output above
```

on an install that is **completely correct**. Measured 2026-08-02, both in a normal shell
with `fw` on PATH and under a scrubbed `env -i`; reproduces identically, so it is not an
environment artefact.

`lib/validate-init.sh` has two checks (`hookpaths-6vc` at ~line 293, `func-paths` at
~line 366) that both do:

```python
parts = cmd.split()
script = next((p for p in parts if '=' not in p), '')
if script and not os.path.exists(script):
```

The command `fw init` itself writes into `.claude/settings.json` is
`${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook pre-compact`. The validator never
expands `${CLAUDE_PROJECT_DIR}`, so `os.path.exists()` is handed the literal string
`${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw`, which of course does not exist, and
`os.path.basename()` of it is `fw` — which is why the error names `fw` nineteen times
instead of naming a script.

Verified empirically: 19/19 hooks reported broken; expanding the variable makes the path
resolve (`os.path.exists(...) == True`); the target file is present and executable.

Two properties make this worse than a cosmetic mis-report:

1. **The validator's pass state is unreachable for the framework's own output.** `fw init`
   generates the `${CLAUDE_PROJECT_DIR}` form, and that form can never satisfy this check.
   In the vocabulary 832 and this project ratified on rail 378, this is a *capability*
   zero being mistaken for an occupancy zero — the check cannot pass, as opposed to
   merely not having passed yet.
2. **`fw init` still exits 0.** The text says "Init completed with validation errors" while
   the exit status says success, so nothing downstream can gate on it.

Blast radius is the entire first-run experience: this is among the first things a new user
ever sees from the framework, it is false, and it trains them to discount framework
validation output from minute one. Same class as F-10 and OBS-121/122/123 — a check
reporting confidently about the wrong object.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Both `lib/validate-init.sh` checks expand `${CLAUDE_PROJECT_DIR}` / `$CLAUDE_PROJECT_DIR`
      to the project directory being validated before testing existence — via
      `os.path.expandvars` after seeding `CLAUDE_PROJECT_DIR` from the new `VALIDATE_ROOT`
      env var, at both the `hookpaths-6vc` and `func-paths` sites
- [x] A fresh `fw init` into a temp dir reports `func-paths` and `hookpaths-6vc` as PASS and
      prints no "Init completed with validation errors" line — verified on a Makefile+main.c
      fixture: both lines now `✓`, and the `Validation: 2 error(s)` / `Init completed with
      validation errors` lines are absent entirely
- [x] Negative control: a settings.json containing a genuinely missing hook script is still
      reported broken, and names the actual script rather than `fw` — injected
      `no-such-script`; reported as `✗ func-paths  Missing hook scripts: no-such-script`
- [x] Negative control: an unexpandable/unknown variable in a hook command does not silently
      resolve to a passing path — `${TOTALLY_UNKNOWN_VAR}/some-script` still reported broken.
      `os.path.expandvars` leaves unknown variables untouched, so the path stays non-existent;
      this is the property that makes the fix safe rather than permissive
- [x] Regression test under `tests/unit/` covering both the false-negative (correct install
      passes) and the true-positive (missing script still caught) directions —
      `tests/unit/validate_init_hook_path_expansion.bats`, 6 tests
- [x] Suite runs clean via `bats tests/unit/validate_init_hook_path_expansion.bats`, with
      output quoted in Verification, **and shown to fail against the pre-fix validator** —
      reverting `lib/validate-init.sh` turns tests 1 and 2 red while the four controls stay
      green, which is the correct discrimination: the controls guard the true-positive
      direction, which was never the broken one

### Human
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
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# Regression suite green (6/6). This suite was verified to go RED on tests 1-2 against
# the pre-fix validator, so it discriminates rather than describing current behaviour.
out=$(bats tests/unit/validate_init_hook_path_expansion.bats 2>&1); echo "$out" | grep -q "^ok 6" && ! echo "$out" | grep -q "^not ok"
# A real `fw init` into a scratch dir must report BOTH hook checks passing. This is the
# end-to-end producer→consumer path the unit suite cannot cover on its own — the whole
# defect lived at that seam, so the gate has to cross it too.
T=$(mktemp -d); touch "$T/Makefile" "$T/main.c"; out=$(bin/fw init "$T" 2>&1); rc=$?; clean=$(printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g'); rm -rf "$T"; [ $rc -eq 0 ] && echo "$clean" | grep -q "✓ func-paths" && echo "$clean" | grep -q "✓ hookpaths-6vc" && ! echo "$clean" | grep -q "Init completed with validation errors"
# The shape-detection guard (T-2723) must be unaffected: still exactly 6 red / 6 green.
# validate-init changes alter fw init's output, and that suite parses fw init's output.
out=$(bats tests/unit/init_project_shape_detection.bats 2>&1 || true); f=$(printf '%s\n' "$out" | grep -c "^not ok" || true); p=$(printf '%s\n' "$out" | grep -c "^ok" || true); echo "shape suite: failing=$f passing=$p"; [ "$f" = "6" ] && [ "$p" = "6" ]

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

**Symptom:** Every `fw init` — on a completely correct install — ended with
`✗ hookpaths-6vc … 19 hook script(s) not found`, `✗ func-paths  Missing hook scripts:
fw,fw,fw,…` (nineteen times), `Validation: 2 error(s) out of 42 checks`, and
`Init completed with validation errors — check output above`. Exit status was 0 regardless.

**Root cause:** `lib/validate-init.sh` extracted the hook script from the command string and
passed it straight to `os.path.exists()` without expanding shell variables. `fw init` writes
hook commands as `${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook <event>`, so the
validator tested the literal string `${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw`, which
can never exist. `os.path.basename()` of that literal is `fw`, which is why the message named
`fw` nineteen times instead of naming a script — the error had lost the identity of its own
subject.

**Why structurally allowed:** three compounding reasons, and the third is the interesting one.

1. **The producer and the consumer were never tested together.** `fw init` (producer of the
   settings.json) and `validate-init.sh` (consumer) each behaved correctly in isolation. This
   is the L-399 / T-1890 producer-consumer join class the framework has already codified —
   the bug lives at the seam, and neither side's unit tests can see it.

2. **The check's failure was self-cancelling as a signal.** It fired on *every* init, so it
   carried no information. A check that fails 100% of the time is indistinguishable from
   decoration and gets read as background noise — the exact mechanism by which a real failure
   would later have been ignored.

3. **The passing state was unreachable, not merely unreached.** In the occupancy/capability
   vocabulary ratified with 832 on rail 378: this was a *capability zero* — no input the
   framework itself generates could ever satisfy the check — while presenting exactly like an
   *occupancy zero* (a check that simply hasn't passed yet). Nothing distinguishes the two
   from outside, which is why "it always says that" survives as an explanation. The framework
   has no surface that asks "can this check pass at all?"

**Prevention:** distinct from the fix in all three directions above.

- `tests/unit/validate_init_hook_path_expansion.bats` pins both directions — a correct
  `${CLAUDE_PROJECT_DIR}` install must validate clean, and a genuinely missing script must
  still be caught *and named accurately*. Verified to fail against the pre-fix validator, so
  it is a real guard rather than a description of current behaviour.
- The unknown-variable control (`${TOTALLY_UNKNOWN_VAR}`) pins the safe direction of the fix:
  `expandvars` leaves unrecognised variables untouched, so a future "strip anything
  variable-shaped" rewrite turns that test red instead of silently passing everything.
- Not covered by this task and deliberately not folded into it: reason 3 is a *class*, not an
  incident. A check whose green state is unreachable reads as a persistent-but-tolerated
  failure forever. Filed separately rather than absorbed here, on the same principle 832 and
  this project applied to OBS-119/OBS-120 — folding is how the second finding disappears into
  the first.

## Evolution

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

### 2026-08-02T06:17:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2724-fw-init-reports-19-broken-hooks-on-a-cor.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3d2efe30
- **Timestamp:** 2026-08-02T06:28:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 38
     - evidence: `T=$(mktemp -d); touch "$T/Makefile" "$T/main.c"; out=$(bin/fw init "$T" 2>&1); rc=$?; clean=$(printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g'); rm -rf "$T"; [ $rc -eq 0 ] && echo "$clean" | grep -q "`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`

### 2026-08-02T06:27:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
