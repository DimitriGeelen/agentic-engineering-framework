---
id: T-3045
name: "embed_host points at a dead sidecar — retire 11435, D-436's premise is gone"
description: >
  embed_host points at a dead sidecar — retire 11435, D-436's premise is gone

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw, tests/unit/t3045_embed_host_resolution.bats]
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
created: 2026-08-16T18:31:35Z
last_update: 2026-08-16T18:54:28Z
date_finished: 2026-08-16T18:54:28Z
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
  - ts: '2026-08-16T18:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T18:45:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=0
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3045: embed_host points at a dead sidecar — retire 11435, D-436's premise is gone

## Context

`.context/settings.yaml` pins `embed_host: http://127.0.0.1:11435` — an endpoint with no
listener. Every embedding call in the framework (`fw ask`, `fw recall`, search, reindex,
the T-1719 post-write hook) connects, fails, and silently fails over to `ollama_host`
(`http://192.168.10.107:11434`), which is the *same machine* reached by LAN IP instead of
loopback. The failover is T-3017 working as designed; the primary being permanently dead
is not.

D-436 (T-3008) deliberately kept `embed_host` on the T-3006 CPU sidecar because
`OLLAMA_MAX_LOADED_MODELS=1` lets a resident chat model starve the embed path. **That
premise no longer holds:** the host now runs `OLLAMA_MAX_LOADED_MODELS=2`, and
`nomic-embed-text-v2-moe` is resident on 11434 right now.

The sidecar died 2026-08-15 during the T-3014 bootstrap and nothing brought it back. It has
no systemd unit, no docker service, and no documented launch parameters — so nothing
*can* bring it back (OBS in `.context/inbox.yaml:3445`). The framework has been running on
its backup ever since, with transient stderr as the only signal
(`.context/inbox.yaml:3697`).

**`.context/settings.yaml` is gitignored.** The config edit therefore clears *this
install* and prevents nothing — a bad `embed_host` is invisible to code review, absent from
CI, and cannot be caught by any tracked test. That is not an argument against making the
edit; it is the reason A5 (doctor reachability check) and A6 (resolution test) are the
actual deliverable. The one-line config change is cleanup; the detection is the fix.

The fix is to stop pointing at it. `web/config.py:39` already documents the fallback
("When unset this is OLLAMA_HOST"), and `.context/settings.yaml:5` says so in its own
comment. T-3016's measurement removes the last reason to prefer the sidecar for queries:
**208 ms shared vs 210 ms sidecar — indistinguishable.**

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **A1** `embed_host` no longer names a dead endpoint: the key is removed from (or
  commented out in) `.context/settings.yaml`, so `Config.EMBED_HOST` resolves to
  `Config.OLLAMA_HOST` via the documented `or OLLAMA_HOST` fallback at `web/config.py:41-43`.
- [x] **A2** The resolved embed endpoint is reachable: `Config.EMBED_HOST` returns HTTP 200
  on `/api/tags` and reports the `nomic-embed-text-v2-moe` model present.
- [x] **A3** A live embed produces **zero failover warnings** — `embed_failover_state()`
  shows no new failover after an `index_one()` call, proving the primary now serves.
- [x] **A4** Query latency does not regress: a warm `embeddings.search()` completes inside
  the same 5 s budget the T-1719 A1 test asserts, measured after the change.
- [x] **A5** `fw doctor` gains an embed-endpoint reachability check so a dead primary is
  surfaced instead of being masked by failover (closes the detection half of
  `.context/inbox.yaml:3697` — the framework ran on its backup for a day with no surface
  reporting it).
- [x] **A6** Regression test pins the resolution rule: with `embed_host` unset,
  `Config.EMBED_HOST == Config.OLLAMA_HOST`; with it set, the explicit value wins. Guards
  against a future edit silently re-pinning a dead host.
- [x] **A7** D-436 is superseded, not silently contradicted (recorded as **D-451**): a decision entry records that
  the sidecar split is retired, cites `OLLAMA_MAX_LOADED_MODELS=2` and the 208/210 ms
  parity as the reason, and names what would bring it back (a return to `=1`).

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
# A1: settings.yaml no longer pins a live embed_host key
! grep -qE '^embed_host:[[:space:]]*\S' .context/settings.yaml
# A1/A2: resolved endpoint is reachable and serves the embed model
python3 -c "import sys; sys.path.insert(0,'web'); from config import Config; import urllib.request, json; d=json.load(urllib.request.urlopen(Config.EMBED_HOST.rstrip('/')+'/api/tags', timeout=10)); assert any('nomic-embed-text' in m['name'] for m in d['models']), d; print('EMBED_HOST ok:', Config.EMBED_HOST)"
# A6: resolution rule pinned by test
bats tests/unit/t3045_embed_host_resolution.bats
# A3/A4: live embed on the resolved host, no failover, inside budget
python3 -c "import sys; sys.path.insert(0,'web'); import embeddings as e, time; t=time.time(); r=e.index_one('.context/settings.yaml'); el=time.time()-t; st=e.embed_failover_state(); assert el < 5.0, ('budget', el); assert not st.get('active'), ('failover active', st); print('ok', r.get('indexed_chunks'), round(el,2))"
# A5: doctor surfaces embed endpoint reachability.
# Capture-then-grep, NOT `bin/fw doctor | grep -q`: grep -q exits on first match,
# SIGPIPEs doctor mid-write, and pipefail surfaces that as exit 141. The pipeline
# form fails precisely when the check SUCCEEDS early. Same shape as the cron
# verification in CLAUDE.md §Verification Gate.
out=$(bin/fw doctor 2>&1); echo "$out" | grep -qiE 'embed endpoint (reachable|not reachable|not configured)'
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
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

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

### 2026-08-16T18:31:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3045-embedhost-points-at-a-dead-sidecar--reti.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-52f9b4c9
- **Timestamp:** 2026-08-16T18:58:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-16T18:54:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
