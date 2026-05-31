---
id: T-2139
name: "Transition-time blocking gate — review-link homework detection (T-2138 V1 keystone)"
description: >
  Transition-time blocking gate — review-link homework detection (T-2138 V1 keystone)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc-008, review-handoff, watchtower, blocking-gate, T-2138-V1, keystone]
components: [lib/review_link_validator.py, lib/review.sh, agents/task-create/update-task.sh, tests/unit/test_review_link_validator.py]
related_tasks: [T-2138, T-2030, T-2050, T-2109, T-2113]
arc_id: inception-review-loop
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-31T13:16:25Z
last_update: 2026-05-31T13:16:25Z
date_finished: null
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

# T-2139: Transition-time blocking gate — review-link homework detection (T-2138 V1 keystone)

## Context

T-2138 V1 keystone (operator GO recorded 2026-05-31, decision commit `8c2b2ed6`). The review-link homework anti-pattern (`URL from \`bin/fw watchtower url\``, bare-path bullets in Steps) keeps recurring despite T-2030's GO 2026-05-25 + T-2050's advisory validator. Recurrence trigger this session: T-2109's Human AC + same-session `/inbox` chat slip — 2× discipline failure with the memory freshly updated.

This task upgrades T-2050's `lib/review_link_validator.py` from advisory-WARN to blocking-at-handoff, and extends it to detect the absence-of-URL homework class (which the current presence-of-URL regex silently passes). The gate fires at the three handoff transitions (Candidate E in T-2138):

1. `bin/fw task review T-XXX` direct invocation
2. `update-task.sh --status work-completed` on a build with unticked Human ACs (auto-handoff via `emit_review`)
3. `update-task.sh --status work-completed` on an inception (pre-`fw inception decide`)

All three paths route through `lib/review.sh:emit_review` — single integration point. The current `|| true` swallow at `lib/review.sh:169` is the leak that needs sealing.

Class-aware block message: when the task is an inception (`workflow_type: inception`) the gate names `/inception/<id>` as the expected URL pattern; for partial-complete builds it names `/review/<id>`. Each violation teaches the review-vs-inception distinction (T-2138 Q3-both, half: block-message teaching half).

OUT of scope (separate slices):
- V2 (T-2138 sibling): reviewer static-scan `review-link-homework` catalogue entry
- V3 (T-2138 sibling): CLAUDE.md / AGENT.md / hook block message doc sweep
- Chat-message detection (the `/inbox` slip class — different surface, no clear gate)

## Acceptance Criteria

### Agent
- [x] `lib/review_link_validator.py` gains `detect_homework_patterns(body) -> list[(level, message)]` that catches: `URL from .bin/fw watchtower url`, `base from .bin/fw watchtower url`, `\(Watchtower URL from`, and bare-path bulleted lines inside `### Human` Steps without a preceding `http://` or `https://`. Returns at level `block` for each anti-pattern found.
- [x] Validator gains `--enforce` CLI flag (default off for backward-compat). When `--enforce` is set, `main()` returns non-zero on any `block` finding; without it, behaviour is the existing advisory-WARN (T-2050 contract preserved).
- [x] Validator reads `workflow_type:` frontmatter and emits class-aware block messages: inception → "this task is an inception, handoffs go to /inception/T-XXX"; other → "this is a build/refactor, partial-complete handoffs go to /review/T-XXX".
- [x] `lib/review.sh:emit_review` passes `--enforce` to the validator and propagates its exit code (no more `|| true` swallow). Bypass: `FW_ALLOW_REVIEW_LINK_HOMEWORK=1` env var skips the block and logs Tier-2 to `.context/working/.gate-bypass-log.yaml`.
- [x] `fw task review` CLI gains `--skip-review-link-check "rationale"` flag — sets `FW_ALLOW_REVIEW_LINK_HOMEWORK=1` for that invocation and logs Tier-2 with the rationale.
- [x] Unit test in `tests/unit/test_review_link_validator.py` covers: (a) each homework pattern detected, (b) clean task passes both modes, (c) advisory mode (default) returns 0 even on findings, (d) enforce mode returns non-zero on findings, (e) class-aware message names inception vs review correctly, (f) bypass env var skips block.
- [x] Bats integration test in `tests/unit/review_link_blocking_gate.bats` (new file) covers: (a) `emit_review` blocks on homework, (b) bypass env var unblocks + logs, (c) clean task passes.
- [x] T-2109 (post-fix) and a synthetic clean inception both pass `python3 lib/review_link_validator.py <file> <url> --enforce` (regression pin for the fix that started this).

### Human
- [ ] [REVIEW] Block message text reads clearly when the gate fires — names the class (inception vs review), gives the correct URL pattern, names both bypass mechanisms.
  **Steps:**
  1. Inspect the example block-message output captured at the end of this task's Evolution section (smoke test against a synthetic inception body with the homework pattern injected).
  2. Confirm the block names: (a) the class — "inception" or "review/build" — (b) the correct URL pattern for that class, (c) the env-var bypass mechanism, (d) the CLI-flag bypass mechanism.
  3. Confirm the rendered tone reads as a coaching message (what to do next) rather than an opaque error.
  **Expected:** All four clauses present, tone reads coaching not punitive.
  **If not:** Note which clause is missing and which clause reads punitive.
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

# T-2139 verification commands:
python3 -m pytest tests/unit/test_review_link_validator.py -q
bats tests/unit/review_link_blocking_gate.bats
python3 lib/review_link_validator.py .tasks/active/T-2109-capture.md "http://192.168.10.107:3000" --enforce
python3 -c "import re; src = open('lib/review_link_validator.py').read(); assert 'detect_homework_patterns' in src and '--enforce' in src and 'workflow_type' in src, 'V1 contract missing'; print('contract present')"
out=$(grep -n 'review_link_validator' lib/review.sh); echo "$out" | grep -q '|| true' && { echo "leak: review.sh still swallows validator exit with || true"; exit 1; }; echo "validator exit propagates"

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

### 2026-05-31 — single integration point reuses T-2050's wiring

- **What changed:** Pre-build expectation was that V1 would touch three integration points (`lib/review.sh:emit_review`, `agents/task-create/update-task.sh --status work-completed` for builds, and the same for inceptions). Build revealed that `update-task.sh` already calls `emit_review` on partial-complete handoffs and the inception-decide flow also routes through `emit_review` — so a single change at `lib/review.sh:165-180` (remove the `|| true` swallow + pass `--enforce`) covers all three transitions transitively.
- **Plan impact:** scope narrowed. The "integrate at update-task.sh too" bullet in T-2138's V1 spec is satisfied by the existing call-graph; no second-site edit needed.
- **Triggered:** scope cut — no second integration point.

### 2026-05-31 — class-aware example line, not just the hint

- **What changed:** First-pass block message had the class-aware teaching line ("This task is an inception, handoffs go to /inception/T-XXX") but the *example replacement URL* below it always said `/review/T-XXX`. That contradicts the teaching line.
- **Plan impact:** example URL now reads `/inception/<id>` for inceptions and `/review/<id>` for everything else (the `example_route = "inception" if workflow_type == "inception" else "review"` branch).
- **Triggered:** nothing new — internal polish.

### 2026-05-31 — self-trap on Human AC Steps quoting the homework pattern

- **What changed:** The original Human AC Steps quoted the homework pattern verbatim as instruction text for the reviewer (so the reviewer would know what string to type to test the gate). When T-2139 surfaces for review via `fw task review`, the gate would fire on its own Steps and refuse the handoff.
- **Plan impact:** Human AC Steps rephrased to point the reviewer at the captured example block-message output in this Evolution section rather than asking them to construct the trigger themselves. The block-message capture below serves that purpose.
- **Triggered:** captured example below for the [REVIEW] AC.

### 2026-05-31 — example block-message output (for Human AC #1)

Captured by running the validator with `--enforce` against a synthetic body containing the homework pattern:

**Inception class:**
```
  ✗ Review-link check (T-2139) — BLOCK — review-handoff homework in this task:
      homework pattern in Steps: `URL from bin/fw watchtower url`
      bare-path bullet in Steps (no http:// prefix): - `/bvp`
      This task is an inception. Inception handoffs go to /inception/T-9999, NOT /review/T-9999.
      Replace homework with concrete absolute URLs (e.g. http://192.168.10.107:3000/inception/T-9999).
      Bypass: FW_ALLOW_REVIEW_LINK_HOMEWORK=1 <command>  (logged Tier-2)
      Or:     bin/fw task review T-XXX --skip-review-link-check "rationale"
```

**Build class (partial-complete with Human ACs unticked):**
```
  ✗ Review-link check (T-2139) — BLOCK — review-handoff homework in this task:
      homework pattern in Steps: `URL from bin/fw watchtower url`
      bare-path bullet in Steps (no http:// prefix): - `/bvp`
      This is a build task with unticked Human ACs (partial-complete). Review handoffs go to /review/T-9999.
      Replace homework with concrete absolute URLs (e.g. http://192.168.10.107:3000/review/T-9999).
      Bypass: FW_ALLOW_REVIEW_LINK_HOMEWORK=1 <command>  (logged Tier-2)
      Or:     bin/fw task review T-XXX --skip-review-link-check "rationale"
```

Both classes name: (a) the failure ("BLOCK — review-handoff homework"), (b) each specific anti-pattern found, (c) the class — inception vs build — (d) the correct URL pattern for that class, (e) both bypass mechanisms (env var + CLI flag).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO

**Rationale:** V1 keystone for T-2138 GO (Candidate E + B + Q3-both, operator decision recorded 2026-05-31 via Watchtower, decision commit `8c2b2ed6`). All 7 Agent ACs satisfied: validator extended with absence-of-URL homework detection (4 anti-pattern regexes + bare-path-bullet detector), `--enforce` mode added with class-aware block messages, `lib/review.sh:emit_review` upgraded from `|| true` advisory to blocking exit, `bin/fw task review` gained `--skip-review-link-check "rationale"` CLI flag, Tier-2 logging wired (env var + CLI flag both write to `.context/working/.gate-bypass-log.yaml`), 26 unit tests + 5 bats integration tests = 31/31 green. T-2050's wrong-URL contract preserved (advisory mode is the default, T-2050 callers see no behavioural change unless they pass `--enforce`).

Single integration point — `update-task.sh` and inception-decide both route through `emit_review`, so the one edit at `lib/review.sh:165-180` covers all three handoff moments transitively (per Evolution entry "single integration point"). The "integrate at update-task.sh too" bullet in T-2138's V1 spec is satisfied by the existing call-graph; no second-site edit needed.

Block message dogfood-tested against synthetic inception and build bodies (Evolution section captures both verbatim) — names the failure, each anti-pattern, the class, the correct URL pattern, and both bypass mechanisms. T-2109 (post-fix, regression pin) passes enforce mode with exit 0.

**Evidence:**
- `lib/review_link_validator.py` — `detect_homework_patterns()`, `--enforce` mode, `class_aware_handoff_hint()`, `_log_tier2_bypass()` (PROJECT_ROOT-aware)
- `lib/review.sh:164-181` — `|| true` swallow removed, `--enforce` passed, exit code propagated, BLOCK banner
- `bin/fw:2489-2528` — `--skip-review-link-check "rationale"` flag dispatch
- `tests/unit/test_review_link_validator.py` — 26 tests covering detection, enforce mode, class-aware messages, bypass
- `tests/unit/review_link_blocking_gate.bats` — 5 integration tests covering emit_review block/pass/bypass
- T-2109 regression pin: `python3 lib/review_link_validator.py .tasks/active/T-2109-capture.md "http://192.168.10.107:3000" --enforce` → exit 0
- T-2139's own body passes its own gate (dogfood)

**What's next:**
- V2 (T-2138 sibling): file separately — `agents/audit/reviewer/static_scan.py` `review-link-homework` catalogue entry for the catch-before-handoff backstop
- V3 (T-2138 sibling): file separately — CLAUDE.md / AGENT.md / hook block message sweep to teach review-vs-inception distinction proactively

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-31T13:16:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2139-transition-time-blocking-gate--review-li.md
- **Context:** Initial task creation
