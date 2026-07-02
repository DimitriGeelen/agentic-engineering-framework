---
id: T-2092
name: "V1-a fw upgrade: docker-based live-upgrade simulation gate (T-2078 GO, closes
  F3)"
description: >
  Release-blocking V1 slice from T-2078 GO. Closes F3: the fresh-machine simulation
  gate currently exercises only the dry-run path; the live mutation path (the actual
  upgrade) is untested. Add a docker-based bats variant that runs the live upgrade
  end-to-end in <=5min. Spec: docs/reports/T-2078-fw-upgrade-reliability-review.md
  F3.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [C-004, bin/fw, lib/upgrade.sh]
related_tasks: [T-2078, T-1633]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T11:58:17Z
last_update: '2026-06-11T22:24:07Z'
date_finished: 2026-06-01T00:01:34Z
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
bvp_scores_proposed:
  - ts: '2026-05-29T12:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-30T12:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 5
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=5 (body:class-neutral); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-01T00:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 5
      F1: 1
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 (body:default-change);
      D4=5 (body:class-neutral); F1=1 (body/tag hits for 'F1': 1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 5
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=5 (body:class-neutral); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-29T12:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-30T12:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2092: V1-a fw upgrade: docker-based live-upgrade simulation gate (T-2078 GO, closes F3)

## Context

T-2078 GO Recommendation V1-a (release-blocking). Spec: `docs/reports/T-2078-fw-upgrade-reliability-review.md` F3 — the existing fresh-machine simulation `tests/unit/upgrade_fresh_machine_simulation.bats` exercises only the dry-run path; the live mutation path (actual fw upgrade against a vendored consumer) is untested. T-1633 elevated this to *"the load-bearing piece"*. Build a docker-based bats variant that runs the live upgrade end-to-end in ≤5 min.

Scope refinement and per-AC implementation detail land progressively as the build starts. This filing commit lands T-2092..T-2095 as the V1 backlog; substantive build work follows in its own commits.

## Acceptance Criteria

### Agent
- [x] `tests/integration/upgrade_live_simulation.bats` exists and contains a bats test that (a) builds a minimal docker container with the vendored consumer skeleton, (b) runs `fw upgrade` against it without `--dry-run`, (c) asserts post-upgrade `.agentic-framework/VERSION` advanced (was pre-corrupted to 0.0.1, becomes upstream's current 1.6.79) and `bin/fw` was rewritten (T-2092-LIVE-SIM-MARKER pre-injected, absent after upgrade)
- [x] Test runs in ≤5 min wall-clock on the framework dev host (~19 s measured; timing emitted as `elapsed=Ns budget=300s rc=N` line in test output; budget tunable via `T2092_TIME_BUDGET_SECS` env var)
- [x] Test is wired into `fw test integration` — bats path `tests/integration/upgrade_live_simulation.bats` is automatically picked up by `bin/fw test integration` (no additional wiring needed; the integration runner globs `tests/integration/*.bats`)
- [x] Failure modes documented: (a) docker binary missing → `skip "docker not available"`, (b) docker daemon unreachable → `skip "docker daemon unreachable"`, (c) apt repos unreachable inside container → sentinel exit 64 → `skip "apt repos unreachable inside container — offline environment"`, (d) live upgrade verification fails → FAIL with full container log preserved via `cat "$out_log"` before `false`
- [x] Closes F3 in `docs/reports/T-2078-fw-upgrade-reliability-review.md` — F3 heading now reads `**Status: shipped (T-2092)**` with the dated note appended; verified by grep `grep -q "Status: shipped (T-2092)" docs/reports/T-2078-fw-upgrade-reliability-review.md`

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

# T-2092 verification: assert all 5 ACs land.
# Each line runs in a SEPARATE shell (P-011) — no variable persists across lines.
# Use single-line capture+grep idioms (memory: feedback-l387-systemic-threshold-crossed).
test -f tests/integration/upgrade_live_simulation.bats
grep -Fq "T-2092 (T-2078 V1-a, closes F3)" tests/integration/upgrade_live_simulation.bats
grep -q "Status: shipped (T-2092)" docs/reports/T-2078-fw-upgrade-reliability-review.md
# Fix landed in lib/upgrade.sh (pyc_count pipefail regression caught by the gate)
grep -q "T-2092: trailing .|| true. is critical" lib/upgrade.sh
# Both bats tests pass (single-line capture+grep, no SIGPIPE risk on small bats output)
bats tests/integration/upgrade_live_simulation.bats > /tmp/t2092-bats.log 2>&1 && grep -q "ok 1 T-2092" /tmp/t2092-bats.log
bats tests/integration/upgrade_live_simulation.bats > /tmp/t2092-bats.log 2>&1 && grep -q "ok 2 T-2092" /tmp/t2092-bats.log

## RCA

Not strictly required (T-2092 is a build/gate task, not bug-class by title). But
the gate caught a real regression under it, captured here for traceability:

**Symptom:** Inside the docker container, `fw upgrade` printed all 10 steps as
OK / UPDATED / CREATED then silently exited 1 — no error line, no "Upgrade
Complete" summary. From outside, looked like a partial-completion class.

**Root cause:** `lib/upgrade.sh:1318` pyc_count pipeline:
```bash
pyc_count=$(cd "$target_dir" && git ls-files .agentic-framework/ 2>/dev/null \
    | grep -E '__pycache__|\.pyc$' | wc -l)
```
Under `set -euo pipefail` (bin/fw:12), when no `.pyc` files are tracked
(clean consumer), `grep -E` exits 1 → pipefail propagates → set -e kills
`do_upgrade` BEFORE the summary block. The framework dev tree happens to
have tracked `.pyc` files in `.agentic-framework/` so grep matches and
this never fires locally.

**Why structurally allowed:** T-1824 fixed the output shape (use `wc -l`
instead of `grep -c ... || echo 0`) but the pipeline exit was still
pipefail-unsafe. No pre-T-2092 test exercised the clean-consumer path; the
existing fresh-machine simulation only runs `--dry-run` so the post-step-10
code path never executed.

**Prevention:** `tests/integration/upgrade_live_simulation.bats` IS the
regression net for this class — it asserts the full live upgrade reaches
"Upgrade Complete". Fix: trailing `|| true` on the pyc_count pipeline.
Future pipefail regressions in any step's invisible-cleanup blocks will
trip the gate on first run.

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

### 2026-06-01 — gate caught a regression on first run

- **What changed:** Pre-build assumption: ship the gate, hope it passes on
  a clean consumer. Build reality: the gate's first run surfaced a
  pipefail regression in `lib/upgrade.sh:1318` that has been latent for
  months (T-1824 was 2026-04-XX). The framework's own dev tree masked the
  bug because it carries tracked `.pyc` files; every clean consumer in the
  field would have hit silent exit-1 with no diagnostic.
- **Plan impact:** Scope expanded by one line (`|| true` on the pyc_count
  pipeline). Kept under T-2092 rather than spinning a sibling task — the
  gate IS the regression net for this exact class, and the fix is
  one-character surgical. The "one bug = one task" rule is about
  compounding multiple independent bugs into a single ticket, not about
  splitting a fix from the test that caught it.
- **Triggered:** F3 status in T-2078 review marked "shipped (T-2092)"
  with note about the surfaced regression.

### 2026-06-01 — bats-with-set-e: capture exit code via `|| rc=$?`

- **What changed:** First test run used `local docker_rc=$?` after the
  failing `docker run` line. Bats runs each test under set -e; the failing
  command kills the test BEFORE `docker_rc=$?` runs. Saw confusing "rc 128"
  with no log.
- **Plan impact:** Pattern updated in this bats file (and worth promoting
  as a learning): when capturing exit codes of commands that may fail under
  bats' default set -e, use `... || rc=$?` not `...; rc=$?`. The trailing
  `|| rc=$?` keeps the test in the success path so the failure-handling
  branch below can run.
- **Triggered:** This Evolution note. Candidate learning entry post-close.

### 2026-06-01 — `--shared` bare clones leak host filesystem paths

- **What changed:** First-pass bare clone used `git clone --bare --shared`
  (matching the existing fresh-machine sim). Inside the container, the
  shared bare repo's alternates pointed at `/opt/999-Agentic-Engineering-Framework/.git/objects`
  which doesn't exist → `fatal: not our ref`. Slim-slice can use `--shared`
  because it runs in-process on the host; docker variant cannot.
- **Plan impact:** Drop `--shared`. Full standalone bare clone is ~150 MB
  but takes <1 s on local disk — acceptable trade-off for container
  reachability.
- **Triggered:** Documented inline in `make_upstream_bare()`.

## Decisions

### 2026-06-01 — fix the pyc_count regression under T-2092 vs file a sibling task

- **Chose:** Fix in the same commit as the gate.
- **Why:** The fix is one character (`|| true`); the gate IS the regression
  net for this class; and "one bug = one task" is about compounding multiple
  independent bugs into a single ticket, not about splitting a fix from the
  test that caught it. The bug and the regression net are the same
  conceptual unit.
- **Rejected:** File T-2154 as the bug fix and T-2092 as the gate. Adds
  pure ceremony cost and creates the awkward race where T-2092's test
  fails until T-2154 ships.

### 2026-06-01 — debian:trixie-slim vs custom Dockerfile

- **Chose:** Use the pre-pulled `debian:trixie-slim` image directly via
  `docker run` with apt-install inline.
- **Why:** Image is ~30 MB, apt-installs git/rsync/python3/python3-yaml/
  ca-certificates in ~13 s on warm cache. No custom Dockerfile build step
  needed. The container script lives in the bats fixture as a heredoc,
  mounted in at `/seed/run-upgrade.sh`.
- **Rejected:** Custom Dockerfile under `tests/integration/docker/`. Adds
  a separate file the bats setup must lifecycle, and locks in an image
  build step that costs ~30 s on cold cache for marginal benefit.

## Recommendation

**Recommendation:** GO

**Rationale:** Gate landed and green. F3 closed. Surfaced a real pipefail
regression in lib/upgrade.sh on first run — exactly the class T-2078 said
was untested — and fixed it in the same slice. Test runs ~19 s well under
the 5-min budget; skips cleanly on hosts without docker / offline; all
five Agent ACs deterministic.

**Evidence:**
- `tests/integration/upgrade_live_simulation.bats` lands two passing tests
  (`bats tests/integration/upgrade_live_simulation.bats` → 2/2 ok)
- Regression fix: `lib/upgrade.sh:1318` carries `|| true` + T-2092 comment
  block explaining the pipefail mechanics
- F3 status in `docs/reports/T-2078-fw-upgrade-reliability-review.md`
  reads "Status: shipped (T-2092)" with dated note
- Commit `da623102` ships the gate + fix together
- Class-level traceability: this is V1-a from T-2078 GO; V1-b (F2 self-vendor
  scope leak), V1-c (F4/F5 exit-code consistency), V1-d (F8 composite cost),
  V1-e (F10 audit verdict) remain as follow-on slices

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-29T11:58:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2092-v1-a-fw-upgrade-docker-based-live-upgrad.md
- **Context:** Initial task creation

### 2026-05-29T12:00:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-05-29T12:10:20Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-31T23:32:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ebcaa518
- **Timestamp:** 2026-06-02T15:01:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-06-01T00:01:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
