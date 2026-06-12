---
task: T-2352
title: Audit findings → RCA + remediation tasks with severity-weighted BVP boost
status: in-progress
recommendation: GO
created: 2026-06-12
---

# T-2352 — Audit findings to RCA + remediation tasks

## 1. Trigger

Operator request (S-2026-0612, post-resume): *"after an audit has run, warns and fails should be turned into a rca and remediation tasks, and to ensure they don't pile up given a BVP score eg. for fail=1 (normalized) and for warn=0,75"*.

Follow-up reframe: *"this are audit finding not per se structural, that why task with RCA is needed"*. Sharpens the routing — audit finding ≠ structural gap; the RCA in the task body is what *discovers* the classification.

## 2. Symptom

Today the audit emit chain has three structural gaps:

1. **No task carrier.** `bin/fw audit` prints WARN/FAIL lines to stderr. No mechanism writes them into `.tasks/`. The framework's keystone *"nothing gets done without a task"* doesn't apply to its own audit output.
2. **Re-emit pile-up.** `full-daily` + `structural-30m` + `traceability-hourly` + `oe-*` crons all re-run audits. Same WARN/FAIL emits repeatedly. Operator must mentally dedupe.
3. **No drain pressure.** Even when findings are real, they compete with the rest of the backlog at default BVP weight. Critical-class findings (FAIL) sit at parity with low-value-low-cost captures.

## 3. Why the existing carriers don't fit

The operator's reframe (*"not per se structural"*) ruled out two of the three candidates I initially listed:

| Candidate | Killed because |
|-----------|----------------|
| ~~(a) Audit → OBS inbox → task~~ | OBS triage is "observation, eventually substantive" — audit FAIL is *already* substantive (a failed check). Triage hop wastes latency. |
| ~~(c) Audit → concerns register (G-XXX) → task~~ | Concerns register is for *known structural* gaps. An audit finding hasn't been classified yet — that's the RCA's job. Pre-classifying as structural prejudges the finding. |
| **(b) Audit → task directly with workflow_type=bugfix** | Reuses T-1550 RCA gate (already enforced). RCA classifies. If RCA concludes structural, body registers G-XXX as last step. No new infrastructure. |

## 4. Reused gates (free wiring)

| Gate | What it enforces | Already lives at |
|------|------------------|------------------|
| **T-1550 bug-class RCA gate** | bugfix-class tasks can't reach `work-completed` without a substantive `## RCA` section | `agents/task-create/update-task.sh` (check_rca_gate) |
| **G-019 post-fix root-cause escalation** | After fix: "Why did the framework allow this?" — RCA must answer | CLAUDE.md §Post-Fix Root Cause Escalation |
| **G-066 close gate** | Bugfix close requires either fix or `--skip-rca` (logged Tier-2) | Same as T-1550 |

Setting `workflow_type: bugfix` on the audit-emitted task gets all three for free.

## 5. Proposed flow (high-level)

```
bin/fw audit
   │
   ├── existing checks (no change) → stderr WARN/FAIL lines
   │
   └── post-emit hook (NEW)
       │
       ├── for each WARN/FAIL line:
       │     hash = sha1(normalized_finding_text)
       │     if .tasks/{active,completed}/T-*.md frontmatter audit_finding_hash == hash:
       │         skip (already filed)
       │     else:
       │         create T-XXXX with:
       │             workflow_type: bugfix
       │             tags: [audit-finding, severity:fail|warn, section:<section-name>]
       │             audit_finding_hash: <sha1>
       │             audit_severity: fail | warn
       │             horizon: now
       │             title: "Audit FAIL/WARN — <section>: <first 50 chars of finding>"
       │             body: ## Trigger (audit run + line)
       │                   ## Finding (verbatim)
       │                   ## RCA (TBD — structural? env? config? transient?)
       │                   ## Acceptance Criteria
       │                   ## Verification (re-run audit, finding absent)
       │
       └── batch-mode safety (IW-8):
           if N FAIL+WARN findings > threshold (default 5?):
              emit single digest task "Audit run produced N FAIL + M WARN"
              operator approves before fan-out
```

BVP weighting flows through new estimator handler:

```python
def score_audit_severity(task):
    sev = task.frontmatter.get("audit_severity")
    if sev == "fail": return 1.0   # normalized, top of 0-1
    if sev == "warn": return 0.75
    return 0.0
```

Composite cost shifts toward FAIL/WARN tasks → BVP rank surfaces them first → drain pressure.

## 6. 5-Whys (validating the route)

| # | Why | Evidence |
|---|-----|----------|
| 1 | Why do audit findings pile up? | No structural carrier into task system → cron re-emits → silent duplication. Daily `full-daily` cron re-runs same audit at 02:00 UTC; nothing dedupes. |
| 2 | Why no carrier? | Audit was authored before the task-system-as-keystone rule landed; emit-to-stderr was the v0 contract. |
| 3 | Why hasn't it been retrofitted? | Concerns register (G-XXX) absorbed the structural subset; OBS inbox absorbed the observation subset; the gap (findings that aren't yet classified) had no obvious home. |
| 4 | Why is the gap actually a class? | Because RCA classifies — it's the work, not a routing decision. Trying to pre-route to G- or OBS pre-judges what RCA exists to determine. The right shape is a bugfix task whose RCA *outputs* G-XXX iff structural. |
| 5 | Why now? | Operator surfaced after a /resume showed multiple existing-cron audit channels but no task representation. The drain-pressure question (*"don't pile up given BVP score"*) makes the cost of inaction explicit. |

**Root cause:** mismatched routing assumption — every existing carrier presupposes classification, but audit findings are *upstream* of classification. The fix is a workflow_type=bugfix task that carries the finding *into* the RCA gate.

## 7. Candidate plan — single-arc, 3-slice

After GO, file this arc + slices:

| Slice | Scope | Cost |
|-------|-------|------|
| **S1** | `audit.sh` post-emit hook — parses WARN/FAIL lines + writes tasks via `bin/fw task create`; dedupe by `audit_finding_hash`; --dry-run flag | M — single file, real shell, must handle 0/1/many findings |
| **S2** | BVP estimator handler `score_audit_severity` + frontmatter field `audit_severity` + policy entry (or convention — TBD whether this needs a new free driver or reuses existing) | S — estimator + 1 yaml entry |
| **S3** | Volume safety: digest-mode trigger (>N findings → single approval task) — calibrated against real audit runs once S1 lands | S — gated on S1 dry-run data |

Optional / out of scope for v1:
- Cross-project audit-finding routing (TermLink consumer audits → framework task system) — different blast radius
- Auto-close when finding stops emitting — IW-6 answered NO; rely on RCA-gate close
- Watchtower triage surface for fan-out (`/audit-findings` batch-approve page) — file as follow-on if IW-8 calibration shows operator pain

## 8. Recommendation

**GO** — three structural gaps with cited file/cron evidence, candidate path reuses two existing gates (T-1550 + G-019 + G-066) at zero new RCA infrastructure cost, BVP severity mechanics are arithmetic. IW-8 (volume safety, 50-finding fan-out on a bad day) is the only genuine evidence gap — answerable by first dry-run on a real audit run, NOT a structural unknown. DEFER would be a hedge per T-2144.

After GO:
- File arc `audit-findings-as-tasks` (or fold into existing `governance-self-audit` arc if it fits)
- File T-2352a (S1 — emit hook + dedupe), T-2352b (S2 — BVP severity handler), T-2352c (S3 — digest mode if calibration requires)

## 9. Dialogue Log

### 2026-06-12 — Trigger

**Operator:** "i want to incept the following: after and audit has run, warns and fails should be turned into a rca and remediation tasks, and to ensure they dont pile up given a BVP score eg. for fail=1 (normalized) and for warn=0,75"

**Agent (proposal):** Outlined inception scope, 7 IWs, three candidate routes (a/b/c through OBS, direct, or concerns register).

**Operator (sharpening):** "also not sure how audit and housekeeping work together in this"

**Agent (research):** Surveyed existing housekeeping carriers (concerns register, OBS inbox, BVP auto-promote, escalation drift, full-daily audit cron). Surfaced the routing options each implies.

**Operator (reframe — the critical move):** "IV this are audit finding not per se structural, that why task with RCA is needed"

**Agent (sharpening):** Killed candidates (a) and (c). Audit finding ≠ structural gap; RCA is what classifies. Refined candidate (b): direct audit → bugfix task → T-1550 RCA gate does the work. 8 IWs updated.

**Operator (decision-point):** "yes" — file the inception.

### Why this reframe matters

The operator's reframe in two sentences killed 50% of the candidate matrix. Pattern: when a candidate set assumes pre-classification, ask "what does RCA exist to determine?" If the answer is "exactly the classification you're using to route", the routing is begging the question. Same shape as why `[REVIEWER]` doesn't cover prose quality (L-409) — the gate-axis and the work-axis are different things.

## 10. Out-of-scope (explicit)

- **Audit detection logic** — existing checks unchanged
- **Cross-project audit findings** — consumer-side audits via TermLink; different blast radius
- **OBS inbox restructure** — OBS keeps its observation-triage role for `fw note` deposits
- **Concerns register restructure** — G-XXX stays as the post-RCA structural carrier
- **Replacing existing `full-daily` cron** — that cron keeps running; this inception layers on top
