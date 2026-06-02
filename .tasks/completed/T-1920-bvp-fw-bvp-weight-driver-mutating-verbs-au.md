---
id: T-1920
name: "BVP T-NEW-5: fw bvp weight + fw bvp driver mutating verbs + weight history audit log (§ACD agent-gate)"
description: >
  Mutating CLI surface for BVP: change weights and add/remove free drivers. §ACD agent-gate (refuses under $CLAUDECODE=1, requires --rationale ≥30 chars). Reactive — weight changes re-rank live (D9). Add-one-drop-one rule (M1) enforced; protected D1-D4 cannot be removed.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bvp, build, slice-5, cli, acd-gate]
components: [012-ArcSystem.md, bin/fw, lib/arc.sh, lib/bvp.sh]
related_tasks: [T-1915, T-1916, T-1917, T-1919, T-1668, T-1671]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:36:43Z
date_finished: 2026-05-19T07:36:43Z
---

# T-1920: BVP T-NEW-5 — `fw bvp weight` + `fw bvp driver` mutating verbs

## Context

Mutating BVP CLI. The §ACD gate shape from `fw arc close` (lib/arc.sh:430-468, T-1671 closure-decision agent-gate) is reused here.

**Source:** Handoff §7 T-NEW-5; artefact §6 row 4; §7 M1 (add-one-drop-one), M6 (§ACD gate), M7 (CLI surface).

**Q1 default applied:** Weight-change is how campaigns are expressed (no separate campaign-scope mechanism).

**R6 mitigation lands here:** ≥30-char rationale prevents thin weight-history entries.

## Acceptance Criteria

### Agent
- [x] `fw bvp weight --set Dn=N --rationale "..."` writes append-only entry to `.context/bvp-weight-history.yaml` with timestamp, who, from-weight, to-weight, rationale (proven by smoke test: D4 3→4→3, two history entries with correct schema)
- [x] `fw bvp weight` refuses (exit ≠0, actionable error) without `--rationale` flag — V1 PASS, error names R6 mitigation
- [x] `fw bvp weight` refuses rationale text under 30 characters — V2 PASS, error cites char count
- [x] `fw bvp weight` refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower` (§ACD) — V3 PASS, error names both overrides
- [x] `fw bvp driver --add "name" --weight N` appends to `free_drivers:` in policy/value-drivers.yaml (proven by smoke test: F1-F5 added then F6 with --drop)
- [x] `fw bvp driver --add` refuses (with actionable error) when total drivers (4 protected + free) >= 9 unless `--drop <id>` is provided (M1) — proven by `total drivers = 9 (cap = 9). Add-one-drop-one (M1)` refusal
- [x] `fw bvp driver --remove D1` refuses (protected); same for D2/D3/D4 — V4 PASS, error cites Four Constitutional Directives
- [x] Weight change is reactive: subsequent `fw bvp` reflects new weights immediately (D9) — by design, BVP computed live from policy each invocation (T-1919 architecture, no cached scores)

## Verification

# L-387: capture-first pattern (avoids SIGPIPE-141 under pipefail).
out=$(bin/fw bvp weight --set D2=8 2>&1 || true); echo "$out" | grep -qi "rationale"
out=$(bin/fw bvp weight --set D2=8 --rationale "too short" 2>&1 || true); echo "$out" | grep -qi "30"
out=$(CLAUDECODE=1 bin/fw bvp weight --set D2=8 --rationale "test reason long enough to be valid for gate" 2>&1 || true); echo "$out" | grep -qiE "i-am-human|from-watchtower"
out=$(bin/fw bvp driver --remove D1 2>&1 || true); echo "$out" | grep -qi "protected"

## Evolution

### 2026-05-19 — Form-validation before §ACD authority gate
- **What changed:** Original implementation followed the arc_close pattern (§ACD first, form validation second). That order meant the Verification block could never prove the rationale/30-char gates from agent session — the §ACD refusal fires first. Reordered to validate `--rationale` presence + length BEFORE the §ACD check.
- **Plan impact:** Semantically right anyway: "your form is bad" precedes "you don't have authority". For protected-driver removal, the protected check also fires before §ACD so the error message stays specific. Documented as a sub-pattern under §ACD usage.
- **Triggered:** None — just an in-task ordering fix.

### 2026-05-19 — Comment preservation via ruamel.yaml
- **What changed:** PyYAML rewrites strip comments. ruamel.yaml available on this system; used it for mutating writes. Fallback to PyYAML if ruamel absent (function-preserving, comment-losing). Note: ruamel may rewrap long strings — that's cosmetic, structure preserved.
- **Plan impact:** Policy file comments (M1/M5 documentation, consumer-slice index, semantics tie-back to artefact) survive every weight/driver edit.
- **Triggered:** None.

### 2026-05-19 — Smoke-test history purge before ship
- **What changed:** End-to-end smoke (D4 3→4→3, F1-F6 add/drop/remove cycle) generated 13 history entries before the file was meant to ship. Reset `.context/bvp-weight-history.yaml` to `entries: []` with a header comment documenting the schema; the smoke-test entries are intentional test exhaust, not audit data.
- **Plan impact:** Future build slices that smoke-test mutating fw commands should similarly clean up their test exhaust before ship. Possibly worth a small testing convention: use a TMP_HISTORY env var to redirect during smoke.
- **Triggered:** Consideration — could file a tiny follow-up to add `BVP_HISTORY_PATH` override for tests. Not yet filed; the manual purge here is fine for one slice.

### 2026-05-19 — Driver id allocation pattern (F1, F2, ...)
- **What changed:** Free drivers allocated as F1, F2, ... by scanning existing ids and picking the lowest unused integer. Not in the AC but obvious omission once implementation started.
- **Plan impact:** Documented in code; users can't pick custom ids. Could surface as `--id` flag later if needed. Current convention is correct for first-pass usage.
- **Triggered:** None.

## Recommendation

**Recommendation:** GO

**Rationale:** Mutating CLI ships with all gates working. 8/8 Agent ACs satisfied, 4/4 Verification commands pass. End-to-end smoke proves form-validation, §ACD gate, M1 add-one-drop-one cap, protected-D1-D4 refusal, history append, and reactive weight change. Comment preservation via ruamel.yaml — multiple weight cycles leave the policy file's M1/M5 comments intact.

**Evidence:**
- Verification block runs all 4 gates inside this Claude Code session (CLAUDECODE=1) and they all match expected refusal patterns
- Smoke test: D4 weight 3→4→3 with rationale, two history entries with full schema (verb, driver, section, from_weight, to_weight, rationale, who, agent_session, ts)
- M1 smoke: added F1-F5 (cap=9), refused F6 without --drop, accepted F6 with --drop F1 (displacement), cleaned up all test drivers
- `.context/bvp-weight-history.yaml` shipped clean (`entries: []`) with schema header comment
- `lib/bvp.sh` now 588 lines: 4 read verbs + 3 mutating verbs + §ACD gate + history append, all in one engine

## Decisions

## Updates

### 2026-05-19T07:30:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-688f7019
- **Timestamp:** 2026-06-02T15:00:28Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `fw bvp weight --set Dn=N --rationale "..."` writes append-only entry to `.context/bvp-weight-history.yaml` with timestamp, who, from-weight, to-weight, rationale (proven by smoke test: D4 3→4→3, two 
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/bvp-weight-history.yaml in: `fw bvp weight --set Dn=N --rationale "..."` writes append-only entry to `.context/bvp-weight-history.yaml` with timestamp, who, from-weight, to-weigh`
- **AC#5 (Agent)** — `fw bvp driver --add "name" --weight N` appends to `free_drivers:` in policy/value-drivers.yaml (proven by smoke test: F1-F5 added then F6 with --drop)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=policy/value-drivers.yaml in: `fw bvp driver --add "name" --weight N` appends to `free_drivers:` in policy/value-drivers.yaml (proven by smoke test: F1-F5 added then F6 with --drop`
### 2026-05-19T07:36:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
