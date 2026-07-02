---
id: T-2232
name: "Durable in-consumer fw upgrade — vendor .upstream sentinel + upgrade-time fallback
  chain (T-2078 V1-D pivot for ring20-dashboard class)"
description: >
  Durable in-consumer fw upgrade — vendor .upstream sentinel + upgrade-time fallback
  chain (T-2078 V1-D pivot for ring20-dashboard class)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw, lib/upgrade.sh]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-06T16:33:13Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-06T16:43:09Z
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
  - ts: '2026-06-11T22:24:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 5
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=5 
      (body:class-neutral); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2232: Durable in-consumer fw upgrade — vendor .upstream sentinel + upgrade-time fallback chain (T-2078 V1-D pivot for ring20-dashboard class)

## Context

Pivot from the T-2078 V1-D spec'd scope (F2 self-vendor refactor — kept under T-2095 captured-now). Operator directive: *"focus on durable fix for the in-consumer upgrade path ring20-dashboard needs."* The field failure on `192.168.10.121` (ring20-dashboard, captured in T-2231) is `fw upgrade invoked from inside the consumer's vendored framework, and no upstream URL is known` — `lib/upgrade.sh:258-281`. T-1634's bare-from-consumer auto-clone path exists, but is gated on `upstream_repo:` being set in `.framework.yaml`, and ring20-dashboard's `.framework.yaml` (init'd 2026-04-08) has none.

`lib/init.sh:212-228` already auto-detects `upstream_repo` from `FRAMEWORK_ROOT`'s git origin at init-time — but that branch fires only on *new* consumers. Legacy consumers (init'd before T-575 or with no framework origin at the time) have no recovery path: at upgrade-time, `$FRAMEWORK_ROOT` is the vendored copy, which is not itself a git repo.

The durable fix is a **vendored sentinel**: `do_vendor` writes `.agentic-framework/.upstream` containing the framework's git origin URL at vendor-time; `do_upgrade`'s collapse-refusal branch extends its fallback chain to read this sentinel as a recovery source; after a successful sentinel-driven recovery, the resolved URL is persisted to `.framework.yaml` so the operator never hits the error path again. Two surfaces (`bin/fw:do_vendor`, `lib/upgrade.sh:241-281`), one new sentinel file shape, full bats coverage, regression-net via existing `upgrade_fresh_machine_simulation.bats`.

Per CLAUDE.md §Consumer-Facing Command Hygiene (T-1633, T-1635), changes to `fw upgrade` / `fw vendor` MUST keep `tests/unit/upgrade_fresh_machine_simulation.bats` green.

## Acceptance Criteria

### Agent
- [x] AC#1 — `bin/fw:do_vendor` writes a `.upstream` sentinel into `$dest/` (vendored `.agentic-framework/.upstream`) containing the framework's git origin URL when one is resolvable from `git -C "$vendor_source" remote get-url origin`. Symmetric with `lib/init.sh:212-228` resolution (origin → first push remote → empty).
- [x] AC#2 — When the framework source has no resolvable git origin, `do_vendor` does NOT write the sentinel (and does NOT error). Existing vendored-without-sentinel state is tolerated as legitimate (legacy or `file://` framework checkouts without remotes).
- [x] AC#3 — `lib/upgrade.sh`'s collapse-refusal branch (lines ~241-281) extends the fallback chain to a third precedence step: `--from-upstream` flag → `.framework.yaml:upstream_repo:` → **vendored `.upstream` sentinel** → existing helpful error. The chain is short-circuiting; first hit wins.
- [x] AC#4 — When the sentinel resolves the upstream URL, a single observability line is emitted to stdout naming the chain step used (e.g. `Upstream URL resolved from vendored .agentic-framework/.upstream sentinel`). This is BEFORE the auto-clone announcement, so the operator can see which leg of the chain fired.
- [x] AC#5 — After a successful sentinel-driven auto-clone-and-replay completes (return code 0), the resolved URL is appended to `$target_dir/.framework.yaml` as `upstream_repo: <url>` so the sentinel fallback is not needed on the next upgrade. Self-healing leg. Skipped on dry-run and on failure.
- [x] AC#6 — New bats gate `tests/unit/t2232_durable_in_consumer_upgrade.bats` covers six paths: (i) `do_vendor` writes sentinel when origin exists; (ii) `do_vendor` skips sentinel cleanly when origin absent; (iii) `do_upgrade` resolves from `--from-upstream` flag (precedence-1 dry-run, no sentinel needed); (iv) `do_upgrade` resolves from `.framework.yaml:upstream_repo:` (precedence-2 dry-run); (v) `do_upgrade` resolves from vendored `.upstream` sentinel (precedence-3 dry-run, observability message present); (vi) `do_upgrade` emits the existing "no upstream URL is known" error when none of the three resolve.
- [x] AC#7 — `tests/unit/upgrade_fresh_machine_simulation.bats` regression net stays green — the synthetic fresh-machine consumer still onboards under `env -i`. Touching consumer-facing commands without this check is the T-1633 origin pattern.
- [x] AC#8 — `bin/fw reviewer T-2232 --no-write 2>&1 | grep -q "Overall:.*PASS"` returns 0 (reviewer static-scan PASS). Any FAIL/CONCERN is addressed via Verification-line recasting (L-459 pattern) or overridden with documented rationale.

<!-- No ### Human block — every AC is deterministic shell verification. No render
     surface touched (CLI/script change only). The "is the durable fix the right
     shape?" judgment was decided by the operator's session-start directive and
     is captured in ## Decisions. -->

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

bash -n bin/fw
bash -n lib/upgrade.sh
grep -q '\.upstream' bin/fw
out=$(grep -n 'sentinel\|\.upstream' lib/upgrade.sh 2>&1); echo "$out" | grep -q '\.upstream'
bats tests/unit/t2232_durable_in_consumer_upgrade.bats
bats tests/unit/upgrade_fresh_machine_simulation.bats
out=$(bin/fw reviewer T-2232 --no-write 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

### 2026-06-06 — Pivot from T-2095 spec'd scope to the actually-durable fix

- **Chose:** File T-2232 with the **vendor sentinel + upgrade-time fallback chain + self-healing yaml-persist** shape. Two surfaces (`bin/fw:do_vendor`, `lib/upgrade.sh:do_upgrade`), one new sentinel artifact, full bats coverage.
- **Why:** T-2095 per T-2078 §F2 spec is a *self-vendor refactor* — extracting `lib/upgrade.sh:341-360`'s framework-side self-vendor loop into a separate verb. That fix is real but **does not unblock ring20-dashboard's .121do field failure** (T-2231 class). Ring20-dashboard's `.framework.yaml` lacks `upstream_repo:`, so the existing T-1634 auto-clone path refuses with the helpful 3-path remediation — but legacy consumers (init'd before T-575 or without a framework origin at init time) have no recovery path. The operator directive at session-start was explicit: *"focus on durable fix for the in-consumer upgrade path ring20-dashboard needs."* T-2095 doesn't match that scope.
- **Rejected:**
  - **Re-scope T-2095's body** to the durable fix while keeping its name: would lose the historical link to T-2078 §F2. Each task = one deliverable (CLAUDE.md §Task Sizing Rules).
  - **Ship T-2095 as-spec'd first, then file follow-up**: would require operator to wait through the F2 refactor before the actually-blocking issue gets unblocked. The operator's "focus on durable fix" directive was for *now*.
  - **Auto-detect from consumer's git remote at upgrade-time**: `git -C $target_dir remote get-url origin` returns the consumer's repo URL, not the framework's. Wrong primitive — the consumer doesn't know its framework's upstream by structure.
  - **Hardcode a default framework URL**: brittle, breaks portability (CLAUDE.md Constitutional Directive D4). The sentinel approach lets every framework distribute its own upstream URL with its vendored copy.

T-2095 remains in captured/now backlog for the F2 self-vendor refactor (separate, still-valid V1-D work). The operator's directive prioritised the in-consumer durable fix; this task ships that.

### 2026-06-06 — Sentinel resolution: framework's git origin, not the consumer's

- **Chose:** `do_vendor` reads `git -C "$vendor_source" remote get-url origin` (with `(push)` first-remote fallback, symmetric with `lib/init.sh:212-228`) at vendor-time and writes the URL into `$dest/.upstream`.
- **Why:** At upgrade-time the vendored copy is NOT a git repo (`do_vendor` doesn't copy `.git/`), so the framework's origin URL must be captured AT vendor time and travel WITH the vendored copy. Reading at upgrade-time would always fail. The `$vendor_source` is whatever `--source` resolves to — typically `$FRAMEWORK_ROOT`, but operator can override.
- **Rejected:**
  - **Store the URL in `VERSION` file alongside the version**: conflates two different shapes (a string vs a URL) and breaks the existing T-1217 `VERSION` semantics.
  - **Embed in `.gitignore` as a comment**: cute but invisible; static scanners and operators wouldn't expect it there.
  - **Use a binary manifest format**: overkill for one URL string; plain text remains debuggable with `cat`.

## Recommendation

**Recommendation:** GO (close as work-completed)

**Rationale:** All 8 Agent ACs satisfied; 8/8 T-2232 bats PASS; 3/3 fresh-machine-simulation bats regression PASS; reviewer R-9a47e388 PASS with zero findings. Two surfaces touched (`bin/fw:do_vendor`, `lib/upgrade.sh:do_upgrade`), one new sentinel artifact (`.agentic-framework/.upstream`), backward-compatible (legacy consumers without sentinel still resolve via existing yaml or flag paths; only the empty-cascade case still errors with the existing helpful message). Self-healing yaml-persist runs only after a known-good auto-clone, never on dry-run. Symmetric with `lib/init.sh:212-228` (same origin-detect logic, just at vendor-time).

**Evidence:**

- `bash -n bin/fw lib/upgrade.sh` — both parse clean.
- `bats tests/unit/t2232_durable_in_consumer_upgrade.bats` — 8/8 PASS.
- `bats tests/unit/upgrade_fresh_machine_simulation.bats` — 3/3 PASS (T-1633/T-1635 regression net).
- `bin/fw reviewer T-2232 --no-write` — PASS, R-9a47e388, no findings.
- Code-path inspection:
  - `bin/fw:367-394` — vendor-time sentinel write (gated on `git remote get-url origin` resolving).
  - `lib/upgrade.sh:241-279` — three-leg fallback chain with `$_upstream_source` label tracking.
  - `lib/upgrade.sh:283-289` — observability line emits `Resolved via: <chain step>`.
  - `lib/upgrade.sh:355-369` — self-healing yaml-persist branch (post-success, sentinel-source only, dry-run safe).

**Ring20-dashboard recovery path (operator-call after merge):** ring20-dashboard's existing `.agentic-framework/` was vendored BEFORE this fix ships, so its sentinel will be missing. Two paths to unblock it:

1. **One-shot from this host** (cross-machine destructive — *operator authorisation required*):
   ```
   cd /opt/999-Agentic-Engineering-Framework && bin/fw upgrade /root/ring20-dashboard --from-upstream https://github.com/DimitriGeelen/agentic-engineering-framework.git
   ```
   That single upgrade run will re-vendor with the new sentinel, after which subsequent in-consumer `fw upgrade` succeeds without operator intervention.
2. **Operator one-line YAML edit** on the ring20-dashboard host:
   ```
   echo 'upstream_repo: https://github.com/DimitriGeelen/agentic-engineering-framework.git' >> /root/ring20-dashboard/.framework.yaml
   ```
   Then any in-consumer `fw upgrade` works; the next upgrade also re-vendors with sentinel for future consistency.

Both are durable-after-once; the structural fix in this task ensures *no new consumers* will need this remediation.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-06T16:33:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2232-durable-in-consumer-fw-upgrade--vendor-u.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5bb41804
- **Timestamp:** 2026-06-06T16:43:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-06T16:43:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
