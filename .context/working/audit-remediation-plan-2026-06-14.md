# Audit Remediation Plan — 2026-06-14

Source: `bin/fw audit` (full, exit 2) run in worktree `arc012-continuous-run-s4s5`.
Captured at budget-critical (303K) — `fw task create` was blocked by budget-gate, so
the full RCA + remediation specs are persisted here for the next session to materialize
via `fw task create` (or the operator to triage). One shell task (CTL-030, ~T-2383) may
already exist from `fw task create` run just before the block.

Triage key: **[TASK]** = create a remediation task · **[OPERATOR]** = sovereignty/human-gated, surface only · **[ENV]** = worktree/host environmental, not a real defect.

---

## [TASK] R1 — CTL-030 FAIL + missing episodics (completion hygiene)  [HV, agent-actionable]

**Findings:**
- `[FAIL] CTL-030: T-2364 in completed/ but stored horizon='now' (expected null/absent)`
- `[FAIL] CTL-030: T-2365 in completed/ but stored horizon='now'`
- `[WARN] Completed task T-2364 / T-2365 / T-2351 has no episodic summary`

**RCA:**
- **Symptom:** two completed arc-012 S2/S3 tasks store `horizon: now`; render (T-2160) derives 'past' from `_location` and expects the stored field null/absent → CTL-030 FAIL. Three completed tasks also lack episodic summaries.
- **Root cause:** `agents/task-create/update-task.sh` has the started-work→`horizon: now` invariant (T-1068, line 1508) but **no inverse**: it never clears/normalizes `horizon` when a task moves to `completed/`. T-2364/T-2365 were completed carrying `horizon: now`. The missing episodics indicate their completion ran through a path (or manual move via the OBS-072/T-2370 fix) that skipped episodic generation.
- **Why structurally allowed:** CTL-030 (T-2160) was added to *detect* the drift but no completion-time normalization *prevents* it; episodic-gen is best-effort and silently skips on certain completion paths.
- **Prevention (distinct from fix):** add horizon-normalization to `update-task.sh` on `--status work-completed` (strip/null `horizon` when moving to completed/), so CTL-030 can't recur. Verify other completed tasks aren't similarly affected (CTL-030 only flagged 2 — confirm scope).

**Remediation ACs:**
- [ ] `.tasks/completed/T-2364*.md` and `T-2365*.md` have `horizon` nulled/removed; `fw audit` no longer emits CTL-030 for them
- [ ] Episodics generated for T-2364, T-2365, T-2351 (`agents/context/context.sh generate-episodic T-XXX`)
- [ ] `update-task.sh` normalizes (strips) `horizon` on `--status work-completed` (prevention), with a unit/bats guard
- [ ] RCA section filled; `fw audit` CTL-030 count for these = 0

---

## [TASK] R2 — orchestrator scan scripts lost executable bit  [LV, quick fix]

**Findings:**
- `[WARN] Orchestrator scan: agents/audit/orchestrator-mcp-scan.sh not executable`
- (sibling) `[WARN] CTL-011: pre-push hook missing or not executable` — partly worktree-env, but check the committed script perms too

**RCA:**
- **Symptom:** `agents/audit/orchestrator-mcp-scan.sh` is `-rw-rw-r--` (no +x) → audit WARN; the orchestrator scan step can't run.
- **Root cause:** the file's executable bit was lost (likely a `git add` / vendor / checkout that didn't preserve mode, or it was created without +x). Git tracks the mode; the committed blob is non-executable.
- **Prevention:** `chmod +x` + commit so the tracked mode is `100755`; consider an audit/doctor check that all `agents/**/*.sh` invoked as scripts are executable.

**Remediation ACs:**
- [ ] `agents/audit/orchestrator-mcp-scan.sh` is `100755` (committed mode), audit WARN clears
- [ ] Sweep `agents/**/*.sh` for other non-executable scripts that are invoked directly; fix any found
- [ ] RCA filled

---

## [TASK] R3 — RCA: CTL-012-MISSING-DECIDE + D10 (inceptions flipped without decide ceremony)  [investigation]

**Findings:**
- `[WARN] CTL-012-MISSING-DECIDE: Inception T-1902 / T-2000 / T-1915 / T-1905 flipped without decide ceremony`
- `[WARN] D10: Decision-without-dialogue — T-1902 T-1846 T-1915 T-1905`
- `[WARN] CTL-012: Completed task T-678 / T-436 has unchecked AC` (related data-hygiene)

**RCA (to complete in task):**
- **Symptom:** 4–5 historical inception tasks reached a terminal/flipped state without a recorded `fw inception decide` ceremony; 2 completed tasks have unchecked ACs.
- **Hypothesis:** either (a) detector FP — these predate the decide-gate (T-1259/T-1260) or were decided via a path the detector doesn't recognize, or (b) real governance gap — inceptions can flip workflow_type / status without the ceremony. Investigation needed: inspect each task's history; determine FP vs real.
- **Prevention:** if real, close the flip path; if FP, scope the detector to post-gate tasks or recognize the alternate decide records.

**Remediation ACs:**
- [ ] Each of T-1902/T-2000/T-1915/T-1905/T-1846 classified FP-or-real with evidence
- [ ] T-678/T-436 unchecked ACs resolved or documented as grandfathered
- [ ] If real gap: detector/gate fix filed; if FP: detector scoped. RCA filled.

---

## [TASK] R4 — Assess inception research-artifact backlog (C-001)  [assessment, likely grandfather]

**Findings:** 20+ `[WARN] Inception task T-XXXX has no research artifact in docs/reports/` (T-1617, T-2000, T-2159, T-1981, T-1444, T-1621, T-1710, T-1831, T-1958, T-1376, T-1833, T-1616, T-1372, T-1506, T-1732, T-1626, T-1959, T-1507, T-1829, T-2252, T-1713, T-2203, T-2121 …)

**RCA / assessment:**
- **Symptom:** many historical inceptions lack `docs/reports/T-XXX-*.md` artifacts (C-001 expects research persistence).
- **Root cause:** C-001 was advisory before enforcement; these inceptions predate the artifact-at-creation discipline. This is a historical backlog, not active drift.
- **Decision needed:** grandfather (scope the C-001 check to inceptions created after a cutoff date) vs. backfill (large effort, low value for closed/old inceptions). Recommend **grandfather** — backfilling artifacts for long-completed inceptions has near-zero forward value.

**Remediation ACs:**
- [ ] Decide grandfather-vs-backfill (recommend grandfather with cutoff)
- [ ] If grandfather: C-001 check scoped to created-after-cutoff; WARN count drops to only genuinely-recent offenders
- [ ] RCA/decision filled

---

## [OPERATOR] surface-only (sovereignty / human-gated — NOT agent tasks)

- `[FAIL] D2: Human review queue — 130+ tasks waiting >30d` → operator must review (Human ACs). Use `/approvals` / `fw review-queue`.
- `[WARN] Arc 'arc-005/010/012/001/009/003/011/004/006/007': ≥80–100% complete but in-progress` → Sovereign close via Watchtower `/arcs/<slug>/close` (§ACD-gated; agent cannot close — G-062/T-1671). **arc-012 is 11/11 (1.0000)** — ready for your close once the live-fire demo is captured.
- `[WARN] CTL-029: 20+ tasks all-Agent-ACs-ticked but started-work` → mostly owner:human or need Human ACs; agent-owned ones (e.g. T-801/802/803 costs tasks) could be closed with care.
- `[WARN] D13: Inception limbo — T-2062..T-2066 (Human ACs pending)` → operator.

## [ENV] worktree/host environmental (NOT real defects — do not task)

- `[FAIL] Cron drift (registry→generated, generated→installed)` — worktree slug `agentic-audit-arc012-continuous-run-s4s5`; generating/installing cron for a winding-down worktree is wrong.
- `[WARN] Uncommitted changes present` — transient session state.
- `[WARN] No commit-msg hook / CTL-011 pre-push hook / CTL-020 no cron audit in last hour` — worktree hooks not installed (`fw git install-hooks` if this worktree were long-lived).
- `[WARN] Gate-bypass log: 147 bypasses/7d` — dominated by this session's logged `FW_SWITCH_FOCUS=1` focus-switches (governance-clean, informational).
- `[WARN] Fabric 103/832 cards no edges` — maintenance (`fw fabric enrich`).
- `[WARN] D3 commit velocity drop today` / `[WARN] free driver F-ORCH retire_when` / `[WARN] workflow stale (cheap-research, default, …)` — informational/known.

---

## Next-session entry point
Run `fw task create` for R1–R4 (specs above are task-ready), then execute R1 (clears a FAIL) and R2 (quick) first. R3/R4 are investigation/assessment. The rest is operator-gated or environmental as triaged.
