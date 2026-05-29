---
id: T-2106
name: "/timeline warm-load 8.3s exceeds T-2105 5s cap — T-1954 cache pattern needed"
description: >
  Discovered by T-2105 all-routes load-time guard. /timeline warm-cache load measured
  at 8279ms — exceeds the 5000ms global cap. Apply T-1954/T-2102 mtime-keyed cache
  pattern in web/blueprints/timeline.py (or wherever the timeline aggregator lives).
  Currently held under 10000ms KNOWN_SLOW elevated cap in test_all_routes_load_time.py
  — fix closes that exemption.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc-007, perf, test-infra, T-1954-cluster, watchtower]
components: []
related_tasks: [T-2105, T-1954, T-2102]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T22:59:54Z
last_update: 2026-05-29T23:07:35Z
date_finished:
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
  - ts: '2026-05-29T23:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-29T23:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2106: /timeline warm-load 8.3s exceeds T-2105 5s cap — T-1954 cache pattern needed

## Context

Discovered by T-2105 all-routes load-time guard: /timeline warm-cache load = 8279ms (exceeds the 5000ms global cap; currently held under a 10000ms KNOWN_SLOW elevated cap with T-2106 as the tracking task). Profile shows `_build_sessions()` walks 580+ handover files calling `read_text()` + `parse_frontmatter` per request whenever `_session_cache` 30s TTL expires. Same shape T-1954/T-2102 fixed elsewhere with `_FM_CACHE: dict[str, tuple[mtime_ns, parsed]]`. After fix /timeline should be under the global 5000ms cap and the KNOWN_SLOW entry in `tests/playwright/test_all_routes_load_time.py` is removed.

## Acceptance Criteria

### Agent
- [x] `_FM_CACHE` (mtime-keyed per-file frontmatter+body cache) added to `web/blueprints/timeline.py:18-50`, mirroring the T-1954 / T-2102 cache shape (see Decisions) — `dict[str, tuple[int_mtime_ns, tuple[dict, str]]]` + `_get_frontmatter_cached(path)` helper.
- [x] `_build_sessions()` routes its read+parse through `_get_frontmatter_cached(path)` — survives `_SESSION_CACHE_TTL` expiry on unchanged handover files (1064 active handovers).
- [x] `/timeline` warm-cache HTTP load < 5000ms — measured 590-715ms post-restart (curl on live Watchtower), down from 8279ms baseline (T-2105 measurement).
- [x] `KNOWN_SLOW` dict in `tests/playwright/test_all_routes_load_time.py` no longer contains `/timeline`; Playwright `test_route_load_time_bounded[/timeline]` PASSES at global 5000ms cap.
- [x] No semantic change — `_build_sessions()` returns same shape (1064 sessions, narrative populated, keys identical). Cold-process startup: 5225ms (one-time cost, no behavior change). Warm: 70ms (74× speedup vs prior re-parse).

### Human
- [ ] [REVIEW] `/timeline` still reads correctly with the cache active — sessions render in newest-first order, narratives populate, emergency-handover collapse still works.
  **Steps:**
  1. Open <http://192.168.10.107:3000/timeline> in your browser.
  2. Scan the first ~10 sessions — confirm timestamps are newest-first; each carries narrative text + tasks_touched chips; "N emergency handovers collapsed" rows still appear where expected.
  3. Make a no-op change to a handover file (`touch .context/handovers/S-*.md` on any one file), reload `/timeline`, verify the page still loads (cache invalidates on mtime per individual file).
  **Expected:** Page loads in <1s warm, content matches what was visible before the cache landed.
  **If not:** Note which session looks wrong or which field is missing.

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

# Cache helper landed in the right shape.
grep -q "_FM_CACHE" web/blueprints/timeline.py
grep -q "_get_frontmatter_cached" web/blueprints/timeline.py
# /timeline warm load under global cap (curl probe, generous; 590ms steady state).
curl -s -o /dev/null -w '%{time_total}' "$(bin/fw watchtower url)/timeline" > /tmp/.t2106.tm 2>&1
# Single hit to fill cache, then re-measure.
curl -s -o /dev/null -w '%{time_total}' "$(bin/fw watchtower url)/timeline" > /tmp/.t2106.tm 2>&1
awk '{ if ($1+0 < 5.0) exit 0; else exit 1 }' /tmp/.t2106.tm
# KNOWN_SLOW exemption removed.
out=$(cat tests/playwright/test_all_routes_load_time.py); echo "$out" | grep -q "T-2106 (/timeline) CLOSED"
echo "$out" | grep -q "\"/timeline\":" && exit 1 || true

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

**Symptom:** `/timeline` warm-cache HTTP load = 8.3s (T-2105 baseline; would have failed the global 5000ms cap of test_all_routes_load_time.py).

**Root cause:** `_build_sessions()` walked every handover file under `.context/handovers/` (1064 files), calling `read_text()` + `parse_frontmatter()` per session per request. The blueprint-local `_session_cache` had a 30s TTL but flushed the entire list — every TTL expiry forced a full 1064-file re-walk (~4.6s steady state, 5.2s cold).

**Why structurally allowed:** T-1954 introduced the per-file `_FM_CACHE` pattern in `web/blueprints/bvp.py`. T-2102 extended the pattern to `web/blueprints/approvals.py` (as `_BODY_CACHE`). Neither was promoted to a shared helper — when timeline.py was the next slow-aggregation surface, the developer had to (a) know the pattern exists, (b) port it manually. Until T-2105 landed there was no automated detector — slow pages were caught by humans noticing 8s loads. The 30s TTL gave a false sense of "cached" — it caches the result, but cache misses pay the full re-walk.

**Prevention:** T-2105 (per-route load-time guard) catches the next instance the moment it lands — already PASSes /timeline at the global 5000ms cap post-fix. A more durable prevention would promote `_FM_CACHE` + `_get_frontmatter_cached(path)` to `web/shared.py` as a shared helper so the fourth consumer doesn't re-implement it — filed as deferred sibling thought, not under "one bug = one task". For now, the pattern is documented in this RCA + the T-2105 RCA + the file-level comments.

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

### 2026-05-30 — pattern reuse, no surprises

- **What changed:** Profile confirmed T-2105's hypothesis: `_build_sessions()` is the hot path. 1064 files × ~4ms parse_frontmatter = 4.6s steady state. Cache miss every 30s.
- **Plan impact:** None — the exact T-1954 / T-2102 cache shape applied cleanly. `_FM_CACHE` keyed on `(path, mtime_ns)` returning `(fm, body)` so the "Where We Are" regex on the body keeps working. Replaced `f.read_text() + parse_frontmatter(content)` with `_get_frontmatter_cached(f)` and the `## Where We Are` regex's input `content` with `body`.
- **Triggered:** Sibling thought (deferred, not filed): promote `_FM_CACHE` + `_get_frontmatter_cached(path)` to `web/shared.py` so the fourth consumer (next slow-aggregation page after `/search` T-2107 and `/` T-2108) doesn't re-implement it. Not under "one bug = one task" rule — first promote-to-shared comes after a 3rd consumer needs it; we now have 3 (`bvp.py:_FM_CACHE`, `approvals.py:_BODY_CACHE`, `timeline.py:_FM_CACHE`). One observation in T-2106 RCA → file as OBS-NNN at session end.

## Recommendation

**Recommendation:** GO

**Rationale:** Mechanical perf fix, proven cache shape (third application of T-1954). 12× warm-load speedup on `/timeline` (590ms vs 8279ms). No semantic change — `_build_sessions()` returns identical session list shape (1064 entries, narrative + token-usage fields populated, emergency-collapse logic untouched). Reviewer PASS, no findings. Verification 7/7 commands pass on live Watchtower. Only the visual sanity check remains for you — confirming the sessions look right in the browser.

**Evidence:**
- `web/blueprints/timeline.py:18-50` — `_FM_CACHE` + `_get_frontmatter_cached` helper
- `web/blueprints/timeline.py:120-126` — `_build_sessions()` routed through cache
- `tests/playwright/test_all_routes_load_time.py` — `/timeline` removed from `KNOWN_SLOW`; closure comment present
- Live curl: `curl -sf -w '%{time_total}' http://192.168.10.107:3000/timeline` returns 0.59-0.71s warm
- Playwright `test_route_load_time_bounded[/timeline]` PASSES at global 5000ms cap (was failing at 5000, passed at 10000 KNOWN_SLOW pre-fix)
- Profile: cold 5225ms (one-time), warm 70ms (74× over previous re-parse loop)

## Decisions

### 2026-05-30 — cache the read+parse together, not just the parse

- **Chose:** `_get_frontmatter_cached(path)` returns `(fm, body)` tuple — both products of `parse_frontmatter()` in one cached pair.
- **Why:** the callsite in `_build_sessions` needs both: `fm` for the session fields and `body` for the "Where We Are" regex. Returning just `fm` would force a re-read on every call to re-extract body. Returning the pair keeps the cache lookup O(1) per file.
- **Rejected:**
  - Cache only `fm` (T-1954 shape) and re-read for body — would still pay ~4ms read per file × 1064 = 4.3s. Defeats the purpose.
  - Cache the full pre-rendered session dict (T-2102 "_BODY_CACHE for parsed sections" shape) — over-fitting; the dict construction in `_build_sessions` is cheap once you have `(fm, body)`. Keeps the cache simple and reusable.

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

### 2026-05-29T22:59:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2106-timeline-warm-load-83s-exceeds-t-2105-5s.md
- **Context:** Initial task creation

### 2026-05-29T23:07:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e41afa3c
- **Timestamp:** 2026-05-29T23:14:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
