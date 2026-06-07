---
id: T-2236
name: "fix consumer-recover TermLink leg"
description: >
  fix consumer-recover TermLink leg

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-07T12:50:27Z
last_update: 2026-06-07T16:37:43Z
date_finished: 2026-06-07T16:37:43Z
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
  - ts: '2026-06-07T13:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-07T13:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 4
      F-RECALL: 0
      F-ORCH: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=4 (body:cross-machine); F-RECALL=0 
      (no-signal); F-ORCH=1 (body:hand-wired-dispatch)
    rubric_sha: e4a00f38e801
---

# T-2236: fix consumer-recover TermLink leg

## Context

Field-test gap discovered during ring20-management consumer survey 2026-06-07: the wrapper's TermLink leg in `lib/consumer-recover.sh` calls `termlink remote exec "$host" -- "$@"` but the real CLI shape is `termlink remote exec <HUB> <SESSION> <COMMAND>` (3 positional args, not 1 + "--"). Same shape mismatch in `_cr_pick_transport`'s auto-detect (`termlink remote list` without HUB arg). SSH leg works correctly; TermLink leg only worked in the bats test because the mock didn't enforce the real CLI shape.

Field impact: ring20-management at 192.168.10.122 has 4 legacy consumers (proxmox-ring20-management v1.5.604, termlink v1.5.307, ring20-dashboard vdev, /root v1.4.520 — all NO-SENTINEL pre-T-2232). SSH from this dev host to ring20-management is not configured for non-interactive auth (verified — Permission denied publickey,password). TermLink IS the working cross-machine transport (just used it for the survey). Wrapper currently can't recover them via either leg.

## Acceptance Criteria

### Agent
- [x] `_cr_pick_transport` calls `termlink remote list <hub>` correctly (with HUB positional arg) when probing for the host
- [x] `_cr_remote_exec` for transport=termlink takes a session arg and emits `termlink remote exec <hub> <session> <cmd>` (real CLI shape, 3 positional args)
- [x] `_cr_remote_script` for transport=termlink uses the base64 inject path with the correct hub+session positional args
- [x] New `--session SESSION_ID` flag — required when `--via termlink` forces TermLink AND auto-discovery yields no ready session; otherwise auto-discovers a ready session (first STATE=ready row from `termlink remote list HUB`)
- [x] Wrapper degrades gracefully when TermLink not installed (`command -v termlink` guards the auto-pick branch; falls through to SSH)
- [x] bats tests at `tests/unit/test_consumer_recover.bats` updated to reflect the new CLI shape; mocks enforce the 3-positional-arg form for `exec` and 1-positional-arg for `list` so future regressions fail tests; 16/16 PASS
- [x] Local dispatcher smoke test: `bin/fw consumer-recover ring20-management /tmp/proxmox-test --via termlink --upstream <URL> --json` PASSED — printed recipe, JSON envelope `transport=termlink outcome=dry-run exit_code=0`, auto-discovered session on real hub
- [x] `fw reviewer T-2236` returns Overall PASS

### Human
<!-- All ACs above are deterministic. No Human AC needed; reviewer + bats provide coverage. -->
<!-- Render-surface gate (T-1766): does NOT apply — pure shell library, no web/templates change. -->

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

# Build verification:
bash -n lib/consumer-recover.sh
# T-2236: real termlink CLI shape — `remote exec <HUB> <SESSION> <CMD>` (3 positional)
# and `remote list <HUB>` (1 positional). In our code the HUB arg name is $host.
grep -q 'termlink remote exec "\$host" "\$session"' lib/consumer-recover.sh
grep -q 'termlink remote list "\$host"' lib/consumer-recover.sh
# Test suite (mocked transport with strict CLI-shape enforcement):
bats tests/unit/test_consumer_recover.bats
# Dispatcher smoke (--via termlink path, dry-run, no actual network):
out=$(FW_CONSUMER_RECOVER_NO_PROBE=1 bin/fw consumer-recover testhost.invalid /tmp/foo --via termlink --session test-sess --upstream https://test/repo.git 2>&1); echo "$out" | grep -q "Transport:     termlink"
# Reviewer static-scan:
out=$(bin/fw reviewer T-2236 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

## RCA

**Symptom:** wrapper's TermLink leg would error at runtime against any real consumer host — `termlink remote exec <host> -- <cmd>` fails because real CLI requires `<HUB> <SESSION> <COMMAND>` (3 positional args).

**Root cause:** I wrote the wrapper's TermLink leg from memory of the older `termlink exec`/`termlink interact` API rather than checking the actual `termlink remote exec --help` shape. Same memory-error in `_cr_pick_transport` calling `termlink remote list` without the HUB arg.

**Why structurally allowed:** the bats tests mocked `termlink` with a script that recorded calls but didn't enforce the real CLI shape (no arg-count check, no positional-name check). T-2235 reviewer PASS because all bats passed against a mock that accepted any args.

**Prevention:**
1. Tighten the bats mock to assert the real `termlink remote exec <HUB> <SESSION> <COMMAND>` arg shape — future shape drift fails the test
2. Add a `bin/fw consumer-recover ... --via termlink --session SESSION` dispatcher smoke test that exercises the real-CLI-shape path (mock-free) for the dry-run case
3. Capture the lesson: "shell wrappers around third-party CLIs MUST be tested against the real CLI's --help output, not against memory of the API" — added as L-NNNN learning

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

### 2026-06-07T12:50:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2236-fix-consumer-recover-termlink-leg.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5e8f2e6e
- **Timestamp:** 2026-06-07T16:37:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-07T16:37:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
