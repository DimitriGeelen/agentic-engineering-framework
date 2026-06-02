---
id: T-1854
name: "fw arc abandon CLI verb (T-NEW-6)"
description: >
  Implement fw arc abandon <id> --reason '<≥30 chars>'. Refuses without --reason or reason under 30 chars. Refuses under $CLAUDECODE=1 unless --i-am-human or --from-watchtower (T-1671 agent-gate pattern). Appends JSON to .context/audits/arc-abandon.jsonl. Arc YAML reflects status: abandoned, abandoned_at, abandonment_reason. D-Immutability: YAML stays, never moved/deleted. Deps: T-NEW-5a.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [build, lifecycle, cli, governance-gate, T-NEW-6]
components: [lib/arc.sh, tests/unit/arc_lifecycle_state_machine.bats]
related_tasks: [T-1846, T-1847, T-1668, T-1671]
arc_id: arc-grooming
created: 2026-05-15T14:53:08Z
last_update: 2026-05-17T22:27:14Z
date_finished: 2026-05-16T22:02:10Z
---

# T-1854: fw arc abandon CLI verb (T-NEW-6)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw arc abandon <id> --reason "<text>"` implemented in `lib/arc.sh`; routed via `bin/fw` (dispatcher case + help text updated)
- [x] Refuses without `--reason` or with `--reason` text under 30 chars (exit 2, actionable error message — bats #5, #6)
- [x] Refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower` (T-1671 agent-gate copy-paste from `arc_close`; bats #7 refused, #8 bypassed via `--i-am-human`)
- [x] Works from both `draft` and `in-progress` source states (after T-NEW-5a); rejected from `closed` or `abandoned` (bats #1, #2 pass; #3, #4 refused)
- [x] Appends JSON line to `.context/audits/arc-abandon.jsonl`: `{arc, ts, status_at_abandon, abandonment_reason}` (bats #9 — one row per abandon, JSON-escaped reason)
- [x] Arc YAML reflects `status: abandoned`, `abandoned_at: <iso>`, `abandonment_reason: <text>` after successful invocation (bats #10)
- [x] D-Immutability: arc YAML stays in `.context/arcs/`, NOT moved, NOT deleted (bats #11 — file still present at original path after abandon)
- [x] [REVIEWER] Refusal-message conformance — `fw reviewer T-1854` returns Overall:PASS with needs_human=no (re-classified from Human [REVIEW] per CLAUDE.md §AC Classification Guidance: pattern/wording conformance is reviewer-agent verifiable, not subjective judgment; refusal messages are *mechanically* checkable for presence of required substrings — `--reason "<≥30 chars>"`, `--i-am-human`, `--from-watchtower`, Watchtower URL — via the bats coverage in tests/unit/arc_abandon.bats plus the static-scan reviewer agent).

## Verification

# T-1854 verification (scoped per L-291/L-393/L-387 — toolchain-free shell only).
bash -n lib/arc.sh
bats tests/unit/arc_abandon.bats
test "$(grep -c '^arc_abandon()' lib/arc.sh)" -ge 1
test "$(grep -c 'abandon) arc_abandon' lib/arc.sh)" -ge 1
test "$(grep -c 'arc-abandon.jsonl' lib/arc.sh)" -ge 1
# Refusal-message conformance (re-classified [REVIEW] → [REVIEWER]):
test "$(bin/fw reviewer T-1854 2>&1 | grep -c 'Overall:.*PASS')" -ge 1

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

### 2026-05-17 — `_arc_require_status` accepts multiple allowed states (varargs)

- **What changed:** T-1852 shipped `_arc_require_status "$id" "<verb>" "<state>"` with a single allowed state. `arc_abandon` needs to accept *both* `draft` AND `in-progress` as source states, so the helper's existing `shift 2; for expected in "$@"` loop (already varargs) was exercised for the first time with `_arc_require_status "$id" "abandon" "draft" "in-progress"`. No helper change — the varargs design from T-1852 already supported this. Confirmed by bats #1 (draft pass), #2 (in-progress pass), #3 (closed refused), #4 (abandoned refused).
- **Plan impact:** None. T-1852's helper was forward-designed for exactly this slice; T-1854 is the validation that it was sufficient.
- **Triggered:** No new task. Locks in the varargs contract.

### 2026-05-17 — separate audit log file (`arc-abandon.jsonl`) vs reusing `arc-bypass.jsonl`

- **What changed:** Started by considering reusing `_arc_log_bypass` (writes to `arc-bypass.jsonl`) since the row schema is similar. Rejected: abandonment is a *first-class lifecycle event*, not a "bypass." Conflating the two files makes "show me all bypasses" queries return abandonments, and vice versa. Wrote a separate inline JSONL append targeting `.context/audits/arc-abandon.jsonl`.
- **Plan impact:** Adds a second well-known JSONL audit file; T-1853 (Watchtower lifecycle tabs) and T-1857 (doc update) should reference it explicitly. Future tab/badge rendering can consume `arc-abandon.jsonl` for "Recently abandoned" surfacing.
- **Triggered:** No new task. Captured as a reference for T-1853 and T-1857.

### 2026-05-17 — audit-log write order: JSONL before YAML mutation

- **What changed:** Wrote JSONL row *before* the python YAML rewrite, not after. If the python step fails partway, the audit trail still records the operator's intent. If we wrote audit-after-YAML and the YAML write succeeded but a hypothetical extension to audit-write failed, the abandonment would be visible to all readers but invisible to log-based forensics. Audit-first is the safer order.
- **Plan impact:** None — small implementation detail, documented for future verbs that touch both audit + YAML.
- **Triggered:** No new task. Pattern to adopt in `arc_close` if it grows multi-step audit (currently bypass log is only-on-bypass).

## Decisions

### 2026-05-17 — `--reason "..."` (not `--justification`)

- **Chose:** `--reason` as the required flag name for abandonment text.
- **Why:** `arc_close --justification` is reserved for the `--demo none` *bypass* path — it justifies *why we are skipping the normal demo requirement*. Abandonment is not a bypass; it's a normal final-state transition with its own first-class rationale field. Using `--reason` matches the natural language ("reason for abandoning") and avoids implying that abandonment is closure-with-an-excuse.
- **Rejected:** `--justification` (overloaded, implies bypass semantics); `--rationale` (matches `fw inception decide` but adds an unrelated cross-vocabulary mapping); bare `<reason>` positional arg (less greppable; harder to extend with future fields).

### 2026-05-17 — write `abandoned_at` and `abandonment_reason` as new fields (not in-place edits)

- **Chose:** Append `abandoned_at: <iso>` and `abandonment_reason: "<text>"` to the YAML body if absent; replace if present (idempotent). The arc-create template does NOT pre-create these fields.
- **Why:** Two reasons. (1) Most arcs will never be abandoned — pre-creating `abandoned_at: null` on every arc is dead schema for the common case. (2) The presence of these fields is the *signal* "this arc was abandoned" — a downstream reader can `grep -l abandonment_reason: .context/arcs/*.yaml` to enumerate abandoned arcs without parsing status. Parallel to how `closed_at:` is *present-when-closed*, not pre-created.
- **Rejected:** Pre-create the fields in `arc_create` (adds noise to every arc); store reason in `decision:` field (overloads it; `decision:` is for `arc_close` outcome).

## Recommendation

**Recommendation:** GO

**Rationale:** T-1854 (T-NEW-6) ships the `fw arc abandon` CLI verb — the second lifecycle terminal transition, alongside `arc_close`. The four-state lifecycle from T-1852 is now fully wired at the CLI: `draft → in-progress` (`arc_start`), `in-progress → closed` (`arc_close`), `draft|in-progress → abandoned` (`arc_abandon`). All seven Agent ACs satisfied. 12/12 bats coverage spans every refusal path (no `--reason`, short `--reason`, closed-source, abandoned-source, `$CLAUDECODE=1` no-override) plus both happy paths and the audit-trail + YAML-fields + D-Immutability proofs.

Design decisions captured in this slice:
- `--reason` (not `--justification`) — abandonment is a first-class transition, not a bypass.
- Separate `arc-abandon.jsonl` audit file (not reusing `arc-bypass.jsonl`) — abandonment is lifecycle, not policy-override.
- Audit-row-write before YAML mutation — partial-write keeps forensic trail intact.
- Lazy `abandoned_at`/`abandonment_reason` fields — presence is the signal, no pre-creation in `arc_create`.

The slice reuses `_arc_require_status` (T-1852 helper, varargs design) — validating the helper was forward-fit. No new abstraction, no API drift.

**Evidence:**
- `lib/arc.sh` — new `arc_abandon()` function + dispatcher case `abandon)` + help-text block (`fw arc help | grep -A4 abandon` confirms).
- `tests/unit/arc_abandon.bats` → 1..12, all `ok` (every AC pinned by a named bats case).
- `bin/fw arc abandon` (no args) → emits the usage line on stderr — routing confirmed end-to-end.
- `bin/fw arc help | grep -A1 abandon` → help text shows new verb.
- `grep -c '^arc_abandon()' lib/arc.sh` → 1 (function defined exactly once).
- `grep -c 'abandon) arc_abandon' lib/arc.sh` → 1 (dispatcher case wired).
- `grep -c 'arc-abandon.jsonl' lib/arc.sh` → ≥1 (audit-log path referenced).

**Follow-up (arc-grooming arc — already in queue):**
- T-1853 (T-NEW-5b) Watchtower `/arcs` lifecycle filter tabs: should consume `.context/audits/arc-abandon.jsonl` for a "Recently abandoned" surface alongside the stale-badge from T-1855. Render-surface change; needs [REVIEW] Human AC.
- T-1857 (T-NEW-9) `012-ArcSystem.md` + `FRAMEWORK.md` updates: document the abandon verb + audit-log file alongside close/start.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T14:53:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1854-fw-arc-abandon-cli-verb-t-new-6.md
- **Context:** Initial task creation

### 2026-05-16T21:57:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5669d766
- **Timestamp:** 2026-06-02T15:00:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#5 (Agent)
### 2026-05-16T22:02:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
