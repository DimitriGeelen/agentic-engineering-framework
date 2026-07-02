---
id: T-1893
name: "arc-005 closure demo evidence capture (G-062 wire artefact)"
description: >
  arc-005 closure demo evidence capture (G-062 wire artefact)

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [docs/reports/arc-005-headline-mechanic-demo.md]
related_tasks: [T-1846, T-1848, T-1849, T-1854, T-1855, T-1856, T-1857]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T07:14:50Z
last_update: '2026-06-11T22:24:02Z'
date_finished: 2026-05-18T07:22:01Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1893: arc-005 closure demo evidence capture (G-062 wire artefact)

## Context

arc-005 (arc-grooming) has all 27 constituent tasks `work-completed` but `demo_evidence: null`. Per G-062, `fw arc close` requires `--demo <path|url|none>` — a wire-level artefact showing the `headline_mechanic` firing, not just substrate. Additionally `fw arc close` is refused under `$CLAUDECODE=1` (T-1671): closure decision belongs to the human via `fw task review`. This task constructs the wire-evidence file so the human can close the arc.

The headline mechanic has 5 prongs:
1. `fw arc create` allocates sequential `arc-NNN` IDs
2. Saving a task with `arc_id:` that doesn't resolve is blocked (Tier-1 hook)
3. `fw audit` reports tag→arc_id parity + 30-day stale-arc warnings
4. `fw arc abandon` flips state without deleting YAML
5. `012-ArcSystem.md` exists at repo root + indexed by `FRAMEWORK.md`

## Acceptance Criteria

### Agent
- [x] `docs/reports/arc-005-headline-mechanic-demo.md` exists and demonstrates all 5 prongs end-to-end with captured shell output
- [x] Prong 1 (sequential allocation): existing arc YAMLs in `.context/arcs/` show `arc-001..arc-005` monotonically — wire evidence is the IDs themselves
- [x] Prong 2 (Tier-1 hook block): demo includes a hook-stdin replay showing exit 2 + `arc_id does not resolve` message
- [x] Prong 3 (audit parity + stale): demo includes excerpt from today's `.context/audits/2026-05-18.yaml` showing arc-related PASS checks
- [x] Prong 4 (abandon): demo cites the bats test pinning the behaviour (agent cannot exercise live under `$CLAUDECODE=1` per T-1671) + `fw arc abandon --help` output showing `--reason` required
- [x] Prong 5 (012-ArcSystem.md): `ls -la 012-ArcSystem.md` + `grep -c "012-ArcSystem" FRAMEWORK.md` outputs included
- [x] All commands in `## Verification` pass
- [x] [REVIEWER] Demo file structure is wire-evidence-suitable: 5 `## Prong N` sections, each with at least one fenced code block (≥3 lines) showing executable command + captured output; the headline_mechanic text from the arc YAML is quoted verbatim in the demo's opening; substrate-only phrasing (`"all tasks completed"`, `"substrate in place"`) is absent. Re-classified from Human [REVIEW] by T-1894 — these structural claims are deterministic and verifiable; only the closure-decision remains Human.
- [x] **Closure-mechanics conformance (T-1897 split):** [REVIEWER] Once the human runs `fw arc close arc-grooming --demo docs/reports/arc-005-headline-mechanic-demo.md --decision "..."`, the arc YAML transitions to `status: closed` and an audit row is appended to `.context/audits/arc-close.jsonl`. Mechanics are deterministic — Verification grep below pins it on closure. Pre-closure: this AC is satisfied by the existence of the closure verb wiring (`bin/fw arc close --help` returns valid usage) since the actual closure is human-gated under `$CLAUDECODE=1` (T-1671). Verification uses `bin/fw arc` (top-level help) since subcommands don't honour `--help`.

### Human
- [ ] [REVIEW] **The actual closure decision:** does the wire-evidence in `docs/reports/arc-005-headline-mechanic-demo.md` + the lifecycle of arc-grooming's 30+ substrate tasks justify closing the arc as `status: closed` (with a positive `--decision "..."`), abandoning it (`fw arc abandon` with reservation), or leaving it open (further work outstanding)?
  **Steps:**
  1. Read `docs/reports/arc-005-headline-mechanic-demo.md` (5 prongs, ~235 lines)
  2. Review the partial-completes overhang in `fw review-queue` (or Watchtower `/approvals`)
  3. Decide: are the headline-mechanic prongs adequately demonstrated *for closure purposes*, or is there a residual scope you want to carry as a follow-up arc?
  4. Run `fw arc close arc-grooming --demo docs/reports/arc-005-headline-mechanic-demo.md --decision "<your decision string>"` OR `fw arc abandon arc-grooming --reason "..."` OR neither (leave open)
  **Expected:** A deliberate strategic call documented in the `--decision` / `--reason` / inaction-rationale, not a rubber-stamp run-the-command-because-the-AC-says-to.
  **If not:** Document reservations in `--justification "..."` to keep the arc open for further work.
  <!-- T-1897 split (2026-05-18): the previous AC blended (a) procedural mechanics
       (tick boxes, run command, verify status:closed + audit row appended) with
       (b) the strategic close-the-arc decision. The conformance half moved to
       Agent [REVIEWER] above; this residual [REVIEW] captures only the genuine
       judgment: should this arc actually close? — which only the human can
       answer (and is structurally gated under $CLAUDECODE=1 per T-1671). -->


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

# T-1893 verification — assert demo file exists + each prong section is present.
test -f docs/reports/arc-005-headline-mechanic-demo.md
test "$(grep -c '^## Prong [1-5]' docs/reports/arc-005-headline-mechanic-demo.md)" -eq 5
# Spot-check that key wire artefacts referenced in the demo actually exist.
test -f 012-ArcSystem.md
test "$(grep -c '012-ArcSystem' FRAMEWORK.md)" -ge 3
test -f tests/unit/arc_abandon.bats
# Confirm at least one arc YAML carries a valid `id: arc-` line (Prong 1 invariant).
# Use `-h` + wc to aggregate across files (grep -c reports per-file).
test "$(grep -h '^id: arc-' .context/arcs/*.yaml | wc -l)" -ge 1
# Re-run Prong 2 hook replay. Note:
#  - Hook's path-filter regex `/\.tasks/(active|completed)/T-\d+` requires the
#    leading `/` before `.tasks/` (an absolute path). Relative paths bypass
#    the regex and the hook short-circuits exit 0. So we synthesize an
#    absolute path via $PROJECT_ROOT (gate exports it).
#  - Hook is expected to exit 2; gate runs each line under `set -eo pipefail`,
#    so swallow via `|| true` and assert on the block-message text instead.
out=$(python3 -c "import json,os; print(json.dumps({'tool_name':'Write','tool_input':{'file_path': os.environ['PROJECT_ROOT']+'/.tasks/active/T-9999-verify.md','content':'---\nid: T-9999\narc_id: arc-nonexistent-verify\n---\n'}}))" | CLAUDECODE=1 bash agents/context/check-arc-id.sh 2>&1 || true); echo "$out" | grep -q "ARC_ID DOES NOT RESOLVE"
# T-1894 re-class: demo file is wire-evidence-suitable (5 prongs, each with code block,
# headline_mechanic quoted, no substrate-only phrases).
test "$(grep -c '^## Prong [1-5]' docs/reports/arc-005-headline-mechanic-demo.md)" -eq 5
for n in 1 2 3 4 5; do test "$(awk -v n="$n" '/^## Prong / { in_p=($0 ~ "Prong "n) } in_p && /^```/ { f++ } END { print f+0 }' docs/reports/arc-005-headline-mechanic-demo.md)" -ge 2 || { echo "FAIL: Prong $n missing fenced block"; exit 1; }; done
grep -q "agent runs" docs/reports/arc-005-headline-mechanic-demo.md
! grep -qE "substrate is in place|all tasks completed are sufficient" docs/reports/arc-005-headline-mechanic-demo.md
# T-1897 split: closure-mechanics verb wired (pre-closure check — actual closure is human-gated under $CLAUDECODE=1 per T-1671).
# fw arc subcommands don't honour --help; top-level `fw arc` emits the help block which documents `close <id> --demo <path|url|none>`.
bin/fw arc 2>&1 | grep -q "close.*--demo"
# T-1897 re-class: reviewer confirms the human-ac-mechanical-signal pattern stays silent (split residue is genuine strategic-decision).
test "$(bin/fw reviewer T-1893 2>&1 | grep -c 'human-ac-mechanical-signal')" -eq 0

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

### 2026-05-18 — Prong 2 hook payload shape

- **What changed:** First hook-replay attempt for Prong 2 returned exit 0 because the JSON payload only carried `file_path` — `check-arc-id.py` reads `tool_input.content` (Write) or `old_string`/`new_string` (Edit) to compute the would-be new content. Without `content:`, `extract_arc_id()` got an empty string and short-circuited "no arc_id → allow."
- **Plan impact:** The plain `(file_path,)` JSON shape — fine for many other hooks — is insufficient for arc-id validation. Documented the full Write-shape payload in the demo so future operators don't reproduce the false-pass.
- **Triggered:** No new sub-task — captured here for future Prong 2 reproductions and as a hint that hook-replay tests must mirror Claude Code's actual `tool_input` shape, not a minimised version.

### 2026-05-18 — Closure boundary: substrate vs deliverable

- **What changed:** Confirmed that "all 27 constituent tasks work-completed" is necessary but not sufficient for arc closure. G-062 requires wire-evidence of the user-observable mechanic firing; the demo file (this task's deliverable) is that artefact. The arc YAML's `demo_evidence: null` was the structural reminder that closure was incomplete despite a clean task table.
- **Plan impact:** Closure flow is now: (1) collect partial-complete review queue, (2) human-tick remaining `[REVIEW]` ACs, (3) human runs `fw arc close arc-grooming --demo docs/reports/arc-005-headline-mechanic-demo.md` from Watchtower. Three distinct human actions, not one.
- **Triggered:** This task (T-1893) ships the wire-evidence artefact. No further sub-tasks under T-1893 itself.

## Recommendation

**2026-05-18 T-1894 re-class note:** A mechanical sub-claim of this task's Human  AC has been split into a new Agent AC (with verification command in ). Only the genuine taste/judgment claim remains Human. See T-1894 for the classification audit and CLAUDE.md §AC Classification Guidance for the rule.

**Recommendation:** GO — surface to human for arc-005 closure

**Rationale:** All 5 headline-mechanic prongs are demonstrated end-to-end in `docs/reports/arc-005-headline-mechanic-demo.md` with captured shell output (not narrative-only descriptions). The arc's user-observable deliverable — "every task has one canonical arc_id resolving to an immutable arc, lifecycle has draft/in-progress/closed/abandoned tabs in Watchtower, 012-ArcSystem.md exists at repo root and FRAMEWORK.md indexes it" — fires structurally:
- Allocation: arc-001..arc-005 monotonic in `.context/arcs/`
- Tier-1 enforcement: live hook replay → exit 2 with actionable block-message
- Audit reporting: 3 PASS checks in today's audit YAML
- Lifecycle verbs: `fw arc abandon` documented + bats-pinned; `fw arc close` reachable via Watchtower
- Docs: 012-ArcSystem.md (16.6KB) + 3 FRAMEWORK.md cross-references

The arc itself remains for the human to close per T-1671 (agent-gate on `fw arc close`).

**Evidence:**
- `docs/reports/arc-005-headline-mechanic-demo.md` — full wire-evidence file (5 prongs, captured shell output)
- All 7 Agent ACs ticked (this task)
- `## Verification` block passes cleanly
- 27 constituent arc-grooming tasks are all `work-completed`
- 6 of those have unresolved `[REVIEW]` Human ACs (T-1851, T-1852, T-1853, T-1857, T-1890, T-1891) — handed to human via `/approvals`

**Closure path for the human:**
1. Tick remaining `[REVIEW]` Human ACs on the 6 partial-completes in Watchtower `/approvals`
2. Review this task (T-1893) for demo-file acceptability
3. From Watchtower: `fw arc close arc-grooming --demo docs/reports/arc-005-headline-mechanic-demo.md --decision "<rationale>"` (or the Watchtower-side button, when wired)

**Why no broader scope:** The natural next step ("auto-generate demo evidence at closure time") is a separate feature — and it would still need a human to confirm the captured commands actually demonstrate the headline mechanic, not just generate plausible noise. Not filing follow-up tasks; arc-005 closure is the immediate user-visible deliverable.

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

### 2026-05-18T07:14:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1893-arc-005-closure-demo-evidence-capture-g-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-68379ebd
- **Timestamp:** 2026-06-02T15:00:19Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Per-AC findings:**

- **AC#4 (Agent)** — Prong 3 (audit parity + stale): demo includes excerpt from today's `.context/audits/2026-05-18.yaml` showing arc-related PASS checks
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/2026-05-18.yaml in: Prong 3 (audit parity + stale): demo includes excerpt from today's `.context/audits/2026-05-18.yaml` showing arc-related PASS checks`
- **AC#9 (Agent)** — **Closure-mechanics conformance (T-1897 split):** [REVIEWER] Once the human runs `fw arc close arc-grooming --demo docs/reports/arc-005-headline-mechanic-demo.md --decision "..."`, the arc YAML transi
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/arc-close.jsonl in: **Closure-mechanics conformance (T-1897 split):** [REVIEWER] Once the human runs `fw arc close arc-grooming --demo docs/reports/arc-005-headline-mecha`

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `test -f tests/unit/arc_abandon.bats`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 52
     - evidence: `bin/fw arc 2>&1 | grep -q "close.*--demo"`
### 2026-05-18T07:22:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
