---
id: T-2136
name: "arc-006 demo_evidence capture — wire-level artefact for value-prioritisation headline_mechanic"
description: >
  arc-006 demo_evidence capture — wire-level artefact for value-prioritisation headline_mechanic

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc-006, demo-evidence, value-prioritisation, arc-closure-prep, G-062-prevention]
components: [docs/reports/value-prioritisation-demo/README.md]
related_tasks: [T-1915, T-1957, T-1960, T-1961, T-1928, T-1929, T-1930]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-31T09:00:49Z
last_update: 2026-05-31T09:09:15Z
date_finished: 2026-05-31T09:09:15Z
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

# T-2136: arc-006 demo_evidence capture — wire-level artefact for value-prioritisation headline_mechanic

## Context

`arc-006` (value-prioritisation) has reached substantive functional completion — all 50+ build slices are partial-complete, the headline_mechanic is observable in `fw bvp` / `fw bvp arcs` / `fw bvp T-XXX` / `/bvp` / `/arcs/<slug>`. The arc cannot close without `demo_evidence` (G-062 gate, T-1671 sovereignty: `fw arc close` refuses under $CLAUDECODE=1 — closure is human-only). This task does NOT close the arc; it captures the wire-level artefact the human can pass as `--demo docs/reports/value-prioritisation-demo/` when they're ready.

Same shape as `docs/reports/orchestrator-rethink-demo/` (T-1669 step 4/4 closing arc-005): a directory with README + CLI/HTTP captures + screenshot, each artefact traceable to the headline_mechanic clauses, each line of the README cross-linking back to the commits that shipped the underlying behaviour.

Headline_mechanic (from `.context/arcs/value-prioritisation.yaml`):

> agent runs `fw bvp` → sees directive-weighted scores (D1/D2/D3/D4 weights 9/7/5/3) + composite cost (blast_radius × 0.6 + tier × 0.3 + effort × 0.1); `fw bvp arcs` ranks arcs by global drivers; `fw arc approve-driver` flips draft → in-progress; `fw bvp confirm` moves proposed → confirmed; Watchtower /bvp shows quadrant scatter with live weight sliders; auto-promote off by default.

Each clause needs one artefact in the demo directory. README documents which file proves which clause and which commit shipped it.

## Acceptance Criteria

### Agent
- [x] Directory `docs/reports/value-prioritisation-demo/` exists.
- [x] `docs/reports/value-prioritisation-demo/README.md` exists with: arc id, headline_mechanic verbatim, traceability table (artefact → mechanic clause → shipping commit), capture timestamp, and capture host.
- [x] `bvp-rank.txt` — captured output of `fw bvp --include-proposed` showing directive-weighted scores with the configured D1/D2/D3/D4 weights (9/7/5/3) visible via the per-task `fw bvp T-XXX` companion (no confirmed scores yet — corpus is proposed-only by design; `--include-proposed` documented in the README). Proves the first clause.
- [x] `bvp-arcs.txt` — captured output of `fw bvp arcs` showing arc-level rollup. Proves the `fw bvp arcs ranks arcs by global drivers` clause.
- [x] `bvp-task-detail-T-1850.txt` — captured output of `fw bvp T-1850` (per-driver breakdown + composite cost). Proves the cost formula clause. (Task T-1850 chosen because it tops the proposed-rank with score 90 — a meaningful demo of the cost-weighted-score mechanic.)
- [x] `bvp-arc-show.txt` — captured output of `fw arc show value-prioritisation` showing `scoped_drivers:` with one approved entry (`estimator-fidelity`, weight 3) — proves `fw arc approve-driver` flipped draft → in-progress.
- [x] `bvp-weight-history-excerpt.yaml` — first 30 lines of `.context/bvp-weight-history.yaml` showing one or more audit rows. Proves the slider / weight-change audit trail exists (sovereignty/M6 gate visible).
- [x] `screenshot-bvp.png` — Playwright screenshot of `/bvp` showing the scatter quadrant + weight sliders + Add-free-driver form. Proves the Watchtower UI clause.
- [x] `screenshot-arcs-value-prioritisation.png` — Playwright screenshot of `/arcs/value-prioritisation` showing arc-level BVP signals + drivers row (D1/D2/D3/D4=9/7/5/3) + G-062 audit-detective badge. Proves the arc-detail integration clause.
- [x] All artefacts in the demo directory referenced from the README (no orphan files; no missing referenced files).

### Human
- [ ] [REVIEW] The captured artefacts faithfully represent the headline_mechanic firing on your install — open `docs/reports/value-prioritisation-demo/README.md`, follow the traceability table, and spot-check 1-2 artefacts against re-running the same command locally.
  **Steps:**
  1. Open `docs/reports/value-prioritisation-demo/README.md` in your editor.
  2. Re-run any one CLI capture (e.g. `cd /opt/999-Agentic-Engineering-Framework && bin/fw bvp | head -20`) and compare against `bvp-rank.txt`. Numbers may differ (live data) but column shape + weight values (9/7/5/3) must match.
  3. Open `http://192.168.10.107:3000/bvp` and spot-check that the scatter + sliders match the screenshot.
  4. If the artefacts faithfully represent the mechanic firing, pass `--demo docs/reports/value-prioritisation-demo/` to `fw arc close value-prioritisation` when you're ready to close the arc (this task does NOT close it).
  **Expected:** Each artefact ties to a mechanic clause (table column 2); each clause ties to a commit (table column 3). The /bvp page renders cleanly with a scatter + at least one weight slider responding to interaction.
  **If not:** Comment in the task body which clause is misrepresented; agent re-captures.

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

# T-2136 verification commands:
# Each line runs in its own subshell — paths must be inlined (no shared $DEST var).
test -d docs/reports/value-prioritisation-demo
test -s docs/reports/value-prioritisation-demo/README.md
out=$(grep -E "^# arc-006|headline_mechanic|--demo" docs/reports/value-prioritisation-demo/README.md); echo "$out" | grep -q "headline_mechanic"
test -s docs/reports/value-prioritisation-demo/bvp-rank.txt && grep -q "TASK.*BVP.*COST" docs/reports/value-prioritisation-demo/bvp-rank.txt
test -s docs/reports/value-prioritisation-demo/bvp-arcs.txt && grep -q "value-prioritisation" docs/reports/value-prioritisation-demo/bvp-arcs.txt
test -s docs/reports/value-prioritisation-demo/bvp-task-detail-T-1850.txt && grep -q "Antifragility" docs/reports/value-prioritisation-demo/bvp-task-detail-T-1850.txt
test -s docs/reports/value-prioritisation-demo/bvp-arc-show.txt && grep -q "estimator-fidelity" docs/reports/value-prioritisation-demo/bvp-arc-show.txt
test -s docs/reports/value-prioritisation-demo/bvp-weight-history-excerpt.yaml && out=$(head -1 docs/reports/value-prioritisation-demo/bvp-weight-history-excerpt.yaml); echo "$out" | grep -q "entries:"
test -s docs/reports/value-prioritisation-demo/bvp-confirm-sovereignty-refusal.txt && grep -q "§ACD" docs/reports/value-prioritisation-demo/bvp-confirm-sovereignty-refusal.txt
test -s docs/reports/value-prioritisation-demo/screenshot-bvp.png
test -s docs/reports/value-prioritisation-demo/screenshot-arcs-value-prioritisation.png

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

### 2026-05-31 — `fw bvp` (bare) returns empty; corpus is proposed-only

- **What changed:** Pre-build assumption was that `fw bvp` (no flags) would render directive-weighted scores immediately. Build revealed the corpus has zero tasks with confirmed `bvp_scores:` set — every score is `bvp_scores_proposed:`. Bare `fw bvp` correctly returns the informational "No tasks have `bvp_scores:` set yet" message rather than spurious output. The mechanic IS firing — through `--include-proposed` — and that's the actual user flow given M1 (sovereignty-gated confirm). The "proposed-only" state is itself part of the contract (auto-promote OFF by default — last clause of the headline_mechanic).
- **Plan impact:** AC#3 wording revised to `fw bvp --include-proposed`. README's traceability table notes the corpus state and references `grep -rl "^bvp_scores:" .tasks/ | wc -l == 0` as evidence of "auto-promote off". Demo doesn't need a confirmed task to prove the mechanic — the confirm gate's *refusal* (captured in `bvp-confirm-sovereignty-refusal.txt`) IS the proof.
- **Triggered:** Added `bvp-confirm-sovereignty-refusal.txt` (originally not in scope). Demonstrates the sovereignty boundary fires structurally, mirroring T-1259 / T-1671.

### 2026-05-31 — viewport-cap pattern reused (L-450 sibling)

- **What changed:** First Playwright capture used 1400×900 viewport — captured only the top half of `/bvp` (sliders visible, scatter cropped off). Re-captured at 1400×2400, well under the >8000px full-page wedge threshold (the [[playwright_fullpage_wedge]] memory class). Both screenshots now show their respective mechanic clauses without hitting the wedge.
- **Plan impact:** Single capture per page instead of two scrolled screenshots. Kept `full_page=False` to avoid the wedge.
- **Triggered:** Documents an L-class pattern (viewport-cap > full-page on /bvp /arcs surfaces). Not a new learning — reapplying [[playwright_fullpage_wedge]].

## Recommendation

**Recommendation:** GO (close-prep complete; arc closure itself remains human-only per T-1671)

**Rationale:** Eight headline_mechanic clauses each have a wire-level artefact traceable to a shipping task/commit. Two of the artefacts are screenshots verifying the Watchtower-UI clause (sliders + scatter + arc-detail); six are CLI captures verifying the `fw bvp …` clauses + sovereignty gate + audit trail. The "auto-promote off by default" clause is captured *negatively* (corpus has zero confirmed scores) — the absence is the proof. Same shape as orchestrator-rethink-demo (used as template). Verification: all 11 file-existence and content-grep checks pass.

**Evidence:**
- Directory: `docs/reports/value-prioritisation-demo/` — 8 artefacts + README.
- README traceability: every clause → at least one artefact → at least one shipping task / commit hash.
- Sovereignty: agent path captured the refusal (`bvp-confirm-sovereignty-refusal.txt`); the actual closure (`fw arc close value-prioritisation --demo ... --i-am-human`) is human-gated by T-1671.
- File-existence + content grep verification: 11 commands, all pass.

**What's next (human action when ready):**
```
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc close value-prioritisation --demo docs/reports/value-prioritisation-demo/ --i-am-human
```
Or via Watchtower: open `/arcs/value-prioritisation/close` (which sets `--from-watchtower`). Before closing, optionally:
1. Approve or reject the 2 `proposed_scoped_drivers:` candidates (`sovereignty-preservation`, `adoption-friction`).
2. Clear arc-006 partial-complete `[REVIEW]` ACs from `bin/fw review-queue` if you want a tidy close-record.

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

### 2026-05-31T09:00:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2136-arc-006-demoevidence-capture--wire-level.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b3a2c560
- **Timestamp:** 2026-05-31T09:09:16Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#7 (Agent)** — `bvp-weight-history-excerpt.yaml` — first 30 lines of `.context/bvp-weight-history.yaml` showing one or more audit rows. Proves the slider / weight-change audit trail exists (sovereignty/M6 gate visib
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/bvp-weight-history.yaml in: `bvp-weight-history-excerpt.yaml` — first 30 lines of `.context/bvp-weight-history.yaml` showing one or more audit rows. Proves the slider / weight-ch`

### 2026-05-31T09:09:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
