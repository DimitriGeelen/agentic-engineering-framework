---
id: T-2109
name: "Promote per-file mtime cache pattern to web/shared.py — 5th consumer crossed"
description: >
  Promoted from OBS-039. Five blueprints/helpers now carry the same
  `dict[str, tuple[int_mtime_ns, parsed_value]]` per-file cache shape:
  T-1954 (bvp.py:_FM_CACHE), T-2102 (approvals.py:_BODY_CACHE),
  T-2106 (timeline.py:_FM_CACHE), T-2107 (search_utils.py:_TAG_FM_CACHE),
  T-2108 (cockpit.py:_HUMAN_VERIFY_CACHE). Drift risk on each ad-hoc
  re-implementation is real (T-2107 already shifted shape slightly to carry
  a body string alongside frontmatter; T-2108 stores a dict entry not a
  parsed tuple). Promote a single helper to web/shared.py so the next
  consumer doesn't re-implement.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [arc-007, perf, refactor, T-1954-cluster, watchtower]
components: [web/shared.py, web/blueprints/bvp.py, web/blueprints/approvals.py, web/blueprints/timeline.py, web/search_utils.py, web/blueprints/cockpit.py]
related_tasks: [T-1954, T-2102, T-2106, T-2107, T-2108]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-30T07:20:51Z
last_update: 2026-05-30T07:20:51Z
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

# T-2109: Promote per-file mtime cache pattern to web/shared.py

## Context

Five separate consumer sites now carry the same per-file mtime cache shape, each re-implemented:
- `web/blueprints/bvp.py:_FM_CACHE` (T-1954) — frontmatter dict
- `web/blueprints/approvals.py:_BODY_CACHE` (T-2102) — body string
- `web/blueprints/timeline.py:_FM_CACHE` (T-2106) — (frontmatter, body) tuple
- `web/search_utils.py:_TAG_FM_CACHE` (T-2107) — tag list
- `web/blueprints/cockpit.py:_HUMAN_VERIFY_CACHE` (T-2108) — verify-entry dict

The shape is consistent: `dict[str, tuple[int_mtime_ns, parsed_value_of_type_T]]` with `stat().st_mtime_ns` invalidation. Differences are purely in the parsed-value type and parse function. A `mtime_cached_get(path, parse_fn, cache_dict)` helper in `web/shared.py` would let new consumers reach for the pattern instead of re-implementing. Migration is mechanical: each site's local cache+helper becomes a call to the shared helper with its own per-consumer cache dict (or a shared module-level cache keyed by parse_fn identity).

Why ship this now rather than tolerate drift: T-2107 already shifted shape (stored a `(fm_dict, body_str)` tuple instead of plain fm_dict). T-2108 stores a dict entry. Each variation looks reasonable in isolation but the next consumer has to read 5 sites to know what the canonical shape is. Promotion = one source of truth + tests.

## Acceptance Criteria

### Agent
- [ ] Add `mtime_cached_get(path, parse_fn, cache)` (or equivalent shape) to `web/shared.py` with docstring referencing T-1954/T-2102/T-2106/T-2107/T-2108 as the consumer sites.
- [ ] Add unit test in `tests/unit/test_shared_mtime_cache.py` covering: (a) cold call → parse runs, (b) warm call same mtime → parse does NOT run, (c) file touched → parse re-runs, (d) OSError on missing file → fallback returned.
- [ ] Migrate `web/blueprints/bvp.py:_FM_CACHE` to the shared helper — `/bvp` warm-load unchanged (curl-timing).
- [ ] Migrate `web/blueprints/approvals.py:_BODY_CACHE` to the shared helper — `/approvals` warm-load unchanged.
- [ ] Migrate `web/blueprints/timeline.py:_FM_CACHE` to the shared helper — `/timeline` warm-load unchanged.
- [ ] Migrate `web/search_utils.py:_TAG_FM_CACHE` to the shared helper — `/search` warm-load unchanged.
- [ ] Migrate `web/blueprints/cockpit.py:_HUMAN_VERIFY_CACHE` to the shared helper — `/` warm-load unchanged.
- [ ] All 47 routes in `tests/playwright/test_all_routes_load_time.py` still PASS (no regression in load-time guard).

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

### 2026-05-30T07:20:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2109-capture.md
- **Context:** Initial task creation
