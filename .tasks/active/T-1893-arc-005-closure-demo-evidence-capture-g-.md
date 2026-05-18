---
id: T-1893
name: "arc-005 closure demo evidence capture (G-062 wire artefact)"
description: >
  arc-005 closure demo evidence capture (G-062 wire artefact)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc-closure-prep, demo-evidence, G-062, headline-mechanic]
components: [docs/reports/arc-005-headline-mechanic-demo.md]
related_tasks: [T-1846, T-1848, T-1849, T-1854, T-1855, T-1856, T-1857]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T07:14:50Z
last_update: 2026-05-18T07:14:50Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
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

### Human
- [ ] [REVIEW] The demo file is suitable as `--demo` argument for `fw arc close arc-grooming`
  **Steps:**
  1. Open `docs/reports/arc-005-headline-mechanic-demo.md`
  2. Confirm each of the 5 prongs has an executable command + its real captured output (not narrative-only)
  3. Confirm the demo addresses the arc's `headline_mechanic` text rather than substrate descriptions
  **Expected:** File reads as wire-level evidence — a sceptical reviewer can re-execute the captured commands and observe the same outputs
  **If not:** Note which prong needs rework; agent will iterate
- [ ] [REVIEW] Decide whether to `fw arc close arc-grooming --demo docs/reports/arc-005-headline-mechanic-demo.md` after Watchtower review of all 6 partial-complete constituents (T-1851, T-1852, T-1853, T-1857, T-1890, T-1891)
  **Steps:**
  1. Visit `fw review-queue` URL
  2. Tick remaining [REVIEW] Human ACs on the 6 partials
  3. Run `fw arc close arc-grooming --demo docs/reports/arc-005-headline-mechanic-demo.md --decision "..."`
  **Expected:** Arc transitions to `status: closed`, audit log row appended to `.context/audits/arc-close.jsonl`
  **If not:** Use `--justification "..."` to record reservations; arc stays open

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
# Re-run the Prong 2 hook replay and confirm exit 2 still fires.
TMPF=".tasks/active/T-9999-verify.md"; trap 'rm -f "$TMPF"' EXIT
JSON_PAYLOAD=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":"---\nid: T-9999\narc_id: arc-nonexistent-verify\n---\n"}}))' "$(pwd)/$TMPF")
hook_out=$(echo "$JSON_PAYLOAD" | CLAUDECODE=1 PROJECT_ROOT="$(pwd)" bash agents/context/check-arc-id.sh 2>&1); hook_exit=$?; [ "$hook_exit" -eq 2 ]
echo "$hook_out" | grep -q "ARC_ID DOES NOT RESOLVE"

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
