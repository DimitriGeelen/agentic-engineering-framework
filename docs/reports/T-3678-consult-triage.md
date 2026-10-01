---
id: T-3678-consult-triage
title: AEF Sidecar Consult Triage Report
date: 2026-10-02
source: T-3678
classifiers: 124 inbox messages (Oct 1-2, 2026)
---

# T-3678: Sidecar Consult Backlog Triage

**Triage date:** 2026-10-02  
**Messages examined:** 124 (from `fw sidecar inbox`)  
**Classification:**
- NEW-DEFECT: 7 (require new framework tasks)
- PROPOSAL: 1 (requires proposal evaluation/inception)
- ALREADY-FIXED: 1 (resolved via commit)
- ALREADY-TRACKED: 1 (already in framework tracking)
- INFO: 114 (e2e probes, tests, diagnostics)

---

## Classified Messages: NEW-DEFECT (7 items, sorted by severity)

### 1. [HIGH] PICKUP: Vendor Install Arc Defects (002-Azure-DevOps)
**Inbox offset:** 12  
**Source:** 002-Azure-DevOps (consumer running v1.6.768 vendored)  
**Classification:** NEW-DEFECT  
**Issue count:** 3 structural defects  
**Evidence path:** T-019 (consumer), upstream framework bugs

**Defect 1.1 — fw arc create: invalid YAML emission**
- **Symptom:** `fw arc create X --anchor 'F-5: some text'` produces unquoted YAML scalars containing `: `, causing mapping-value parse errors downstream
- **Impact:** Arcs become unreadable by arc.sh and web/blueprints/arcs.py until hand-quoted
- **Fix location:** lib/arc.sh arc_create, scalar quoting at emit
- **Verified:** Reproducible on consumer vendored install
- **Evidence:** lib/arc.sh line search for emit pattern, test case `fw arc create X --anchor 'F-5: text'`

**Defect 1.2 — fw arc rescore: PATH resolution fails on vendored installs**
- **Symptom:** `fw arc rescore` calls `"${FW_BIN:-${PROJECT_ROOT}/bin/fw}" bvp estimate`, but consumer has `.agentic-framework/bin/fw`, not `bin/fw` at root
- **Impact:** 100% failure rate on vendored installs (15/15 measured), presents as "estimator failed" not path bug
- **Workaround:** `FW_BIN=$PWD/.agentic-framework/bin/fw`
- **Fix location:** lib/arc.sh:1733, use same resolution as .git/hooks/commit-msg (\_fw_entry pattern)
- **Evidence:** lib/arc.sh:1733, compare to .git/hooks/commit-msg path resolution

**Defect 1.3 — .mcp.json fw server entry uses relative path**
- **Symptom:** Relative script path in MCP config resolves only when session starts from project root
- **Impact:** MCP fw server breaks when operations run from subdirectories
- **Fix location:** web/.mcp.json, use absolute path or PROJECT_ROOT resolution
- **Evidence:** Check .mcp.json for `"command": "bin/fw server"` pattern

**Proposed new task:** ONE TASK - arc-vendor-install-fixes (3 sub-issues, same root: vendored path resolution)

---

### 2. [HIGH] ESCALATION: Copy-Pasteable Command Path Confusion (055-agentic-fleet-cockpit)
**Inbox offset:** 15  
**Source:** 055-agentic-fleet-cockpit (operator escalation)  
**Classification:** NEW-DEFECT → PROPOSAL (scoping required)  
**Issue:** Repeated failures of copy-pasteable commands from CLAUDE.md on consumer projects  
**Evidence path:** CLAUDE.md:629 (T-609 rule), consumer .agentic-framework/ path, operator feedback

**Symptom:** Operator receives `cd /path && bin/fw arc approve-driver ...` → fails with "bin/fw: No such file or directory"  
**Root cause:** CLAUDE.md T-609 rule states "use bin/fw" without distinguishing framework repo (has bin/fw) from consumers (have .agentic-framework/bin/fw)  
**Scope gap:** The rule is correct, but:
1. Not distinguishable in text (reads as universal)
2. No detection of which mode a handoff targets
3. No enforcement on handoff generation (CLAUDE.md compliance, skills/agents)

**This defect requires SCOPING before build task creation:**
- Is the fix in CLAUDE.md rule rewrite, in a detection hook, or in a skill that generates handoffs?
- Should the framework auto-detect consumer mode and emit correct paths?
- Does this need an inception to validate the fix scope?

**Operator feedback:** Already recurring multiple times; first formal escalation filed.

**Proposed new task:** INCEPTION - copy-pasteable-command-path-scoping (3 evidence indicators: T-609 rule, operator escalation, CLAUDE.md maintenance burden)

---

### 3. [MEDIUM] PICKUP: Vendor Install fw upgrade Bootstrap (003-NTB-ATC-Plugin)
**Inbox offset:** 8  
**Source:** 003-NTB-ATC-Plugin (consumer workstation-107)  
**Classification:** NEW-DEFECT  
**File sent:** T-373-upstream-framework-defects.md (sha256: 91eeffe475ccf5f1ac515ca0d9e369a68f279d278735ce9bfb3c5225bfad69f2)  
**Issue count:** 2 (1 high, 1 medium)

**Defect 3.1 — fw upgrade: false success on bootstrap failure**
- **Symptom:** Consumer with `.framework.yaml` but no `.agentic-framework/` (normal state after git clone, since it's gitignored) runs `fw upgrade`
- **Observed:** Step [4b/9] reports "SKIP: No .agentic-framework/" and exits 0 (success), but consumer still has no framework
- **Impact:** Consumer cannot run `fw` afterward, but upgrade reports success
- **Repro:** Fresh clone → fw upgrade → consumer has no working fw, no error message
- **Fix location:** agents/upgrade/upgrade.sh, exit code logic on missing .agentic-framework/
- **Evidence:** agents/upgrade/upgrade.sh step 4b, test: fresh-clone consumer + fw upgrade

**Defect 3.2 — [Mentioned but file content not provided in inbox message]**

**Proposed new task:** T-###-fw-upgrade-bootstrap-success-false-positive (Tier 1 defect, P-011 + exit code gate)

---

### 4. [MEDIUM] STRUCTURAL: Deferral Deletion Gate Missing
**Inbox offset:** 37 (from 010-termlink project)  
**Source:** 010-termlink (framework pickup role)  
**Classification:** NEW-DEFECT (links 3 issues)  
**Severity:** Structural asymmetry in completion gates  
**Evidence path:** Update gate (P-010/P-011), T-2190 (inception closure), T-2389 (staleness)

**Defect 4.1 — Build tasks can close with deferred work named but undisposed**
- **Symptom:** A task names "stage 3 of 3" as "future slice" in planning and then completes with AC checkboxes ticked, no successor task, no revisit_at, no gaps entry
- **Impact:** Deferred work vanishes from corpus (grep finds no 'stage=read' in active/ after close)
- **Comparison:** Inceptions cannot close with undisposed Open Questions (T-2190 gate enforced) — asymmetry
- **Real example:** Task completed in corpus with deferred planning still present in narrative
- **Fix location:** Update gate (update-task.sh:1215+), P-010 completion gate should refuse --status work-completed when narrative names deferred work with no successor/revisit_at entry
- **Evidence:** Verify gate logic in update-task.sh, search completed/ tasks for deferred-language with no successor

**Defect 4.2 — GO-scope non-propagation at inception scale**
- **Symptom:** Daily audit reports 88 inceptions of 170 examined with "GO-scope-not-propagated" — approved scope, empty related_tasks[], no slices filed
- **Impact:** Approved inception GO decisions produce no follow-up build tasks, scope work lost
- **Audit output location:** `.context/audits/go-scope-unpropagated/LATEST.md`
- **Fix location:** Inception GO gate should require related_tasks[] be populated or refuse closure; currently it does not

**Defect 4.3 — Unbounded WIP hides remediation signals**
- **Symptom:** T-2389 (staleness remediation) filed as horizon:now, owner:human, started-work but buried in 291 active / 60 started-work / 159 captured tasks
- **Impact:** `fw work-on` output "CONCURRENT TASKS: 58 other tasks already in started-work" is always true, so the signal cannot be acted upon
- **Root cause:** WIP has no bound, staleness has no priority mechanism; detection works (18 canaries + 11 static checks) but cannot influence ranking
- **Fix location:** Not just closure gates but task ranking/priority system needs overhaul; WIP metrics + age-based demotion

**Proposed new task:** THREE TASKS OR ONE SCOPING INCEPTION
- T-###-deferral-completion-gate (P-010 enhancement, small)
- T-###-inception-go-scope-propagation-gate (P-010 enhancement, small)
- T-###-wip-bounds-and-staleness-priority (LARGER, requires design decision on priority system) — OR —
- T-###-INCEPTION-completion-gate-asymmetry (ONE inception covering all three as a cohesive design challenge)

**Pushback note from 010-termlink:** "Do not build 3 separate gates without addressing the real load-bearing defect, which is WIP bounds. Detection does not help when everything is detected. The human is the only component that prioritises."

---

### 5. [MEDIUM] ESCALATION: Notify Rail Silent Loss Path (arc-003 demo evidence binding)
**Inbox offset:** 76, 79, 82  
**Source:** 010-termlink (framework pickup role)  
**Classification:** NEW-DEFECT  
**Related commits:** 773adb3e9 (identity split closed), offsets 76/79/82  
**Issue:** Arc closure claims are unbound and unverifiable  
**Evidence path:** T-2480, T-2477, arc-003 demo_evidence

**Symptom:** Arc-003 closed 2026-07-02 asserting "no silent loss"; arc's own prover now says otherwise  
**Root cause:** Arc schema has no `slices[]` field and no `prover:` binding; closure claim backed only by demo_evidence (markdown narrative, cannot fail later)  
**Impact:** Closed arcs cannot be verified; deferred slices have no schema home  
**Evidence:**  
- Arc schema check: `.context/arcs/arc-003.yaml` no `prover:` entry
- Proof: `scripts/check-arc-claim-drift.sh` on arc-003 reports CLAIM-FAILED
- Message offset 76: "NO slices[] field and NO prover binding" — schema analysis

**Related gate:** T-2477/T-2480 shipped arc-live-probe.sh and deferred the "MANDATORY form inside arc_close" to "human governance decision"  
**Problem:** That deferral IS the defect — arc close has no gate requiring verifiable proof

**Proposed new task:** T-###-arc-schema-slices-and-prover-binding (schema change, prover: field, arc_close gate enhancement)  
**Depends on:** Operator decision on whether to require explicit prover binding or accept demo_evidence-only

---

### 6. [MEDIUM] PICKUP: Onboarding Bugs (002-Azure-DevOps / TheSpiceFactory)
**Inbox offset:** 101, 102, 103  
**Source:** 010-termlink (T-011 PICKUP REQUEST, 4 bugs, T-013 PICKUP REQUEST #2)  
**Classification:** NEW-DEFECT (2 distinct defect classes)  
**Repro conditions:** Onboarding existing repo onto bleeding-edge v1.6.768, 2026-09-08  
**Evidence location:** Consumer 002-Azure-DevOps (TheSpiceFactory project)

**From Message 101 (T-011):** 4 bugs onboarding existing repo  
- Bugs listed: RCA done on consumer side, fixes needed upstream
- No details in preview; full message content needed for classification

**From Message 103 (T-013):** PreToolUse Bash gate 50% false-positive rate  
- **Symptom:** PreToolUse hook on Bash produces false-positives 50% of the time on consumer vendored install
- **Impact:** Legitimate commands blocked, framework unusable
- **Repro environment:** consumer TheSpiceFactory, v1.6.768, 2026-09-08
- **Related:** T-2054, T-532 (prior investigations)
- **Evidence:** lib/tier0_action.py or check-active-task.sh false-positive patterns on consumer environment
- **Severity:** HIGH — 50% FP rate makes framework unusable; blocks multiple sessions

**Proposed new tasks:**
- T-###-onboarding-4-bugs (T-011 umbrella, requires extracting full list)
- T-###-pretooluse-bash-gate-fp-rate-50pct (HIGH, Tier 1 defect)

---

### 7. [LOW-MEDIUM] PICKUP: Version-Skew Diagnostics (resolved)
**Inbox offset:** 47  
**Source:** [Not fully extracted in this pass]  
**Classification:** ALREADY-FIXED  
**Status:** Hypothesis disproved, RCA completed, committed  
**Details:** Message indicates investigation resolved; no new task needed

---

## Classified Messages: PROPOSAL (1 item)

### EWCR Arc-0 Direct AEF Attestation Request
**Inbox offset:** 3-6  
**Source:** 0503-codex-cli-playground (T-040, Designer role)  
**Classification:** PROPOSAL (requires decision, not build)  
**Correlation:** EWCR-ARC0-ATTEST-832  
**Target:** T-3147, arc-019 membership  
**Type:** Dual-clause attestation request

**Clause 1 — topology attestation:** Verify component fabric counts, coverage, Unknown entries for Arc-0 scope with commit-pinned sha256 evidence  
**Clause 2 — refusal-threat matrix:** Confirm Claude/Z.ai/DeepSeek/Mistral consolidated refusal-blocking matrix exists; every blocker must have contract disposition + testable scenario. Designer reports DeepSeek and Mistral tables absent.

**Action required:** Operator decision on whether AEF conducts this attestation or delegates to T-3147's owner  
**Note:** Not an implementation instruction; read-only verification request from external coordinator

---

## Classified Messages: ALREADY-TRACKED (1 item)

### 055-agentic-fleet-cockpit Routing Confirmation
**Inbox offset:** 13  
**Source:** 055-agentic-fleet-cockpit  
**Classification:** ALREADY-TRACKED  
**Status:** Message routing peer consult back to originating agent; no new task needed

---

## Classified Messages: INFO (114 items)

**e2e tests and diagnostics (99 messages):**
- T-407 round-trip tests: DM delivery provers
- T-408 wake tests: background listener provers
- T-3058 round-trip prover: sidecar liveness
- T-3061 notify-rail provers (identity split, fp resolution): 40+ messages documenting proof runs and results
- Various latency probes, closed-loop tests, delivery confirms

**Field reports and diagnostics (15 messages):**
- Version-skew diagnostics
- Deploy-topology inquiries  
- Operator confirmations

**Summary:** All INFO-class messages are infrastructure probes, proof-of-concept runs, or diagnostic confirmations. No new defects or proposals in this class.

---

## Ranked Proposed New Tasks (by severity & priority)

| Rank | Task | Classification | Severity | Effort | Blocker | Arc | Note |
|------|------|-----------------|----------|--------|---------|-----|------|
| 1 | copy-pasteable-command-path-scoping | INCEPTION | HIGH | M | Yes (operator escalation) | T-609-rule-scope | Recurring user friction; requires scoping before build |
| 2 | pretooluse-bash-gate-fp-rate-50pct | BUILD | HIGH | M | Yes (breaks onboarding) | Tier-1-defects | 50% false-positive rate makes framework unusable |
| 3 | arc-vendor-install-fixes | BUILD | HIGH | M | Yes | arc-011 | 3 sub-issues (YAML quote, path resolution, .mcp.json); affects all consumer vendors |
| 4 | fw-upgrade-bootstrap-success-false-positive | BUILD | MEDIUM | S | No | consume-onboarding | Exit code gate fix; low effort but high impact on first-run |
| 5 | completion-gate-asymmetry | INCEPTION | MEDIUM | M | No | completion-gates | Covers: deferral gate + GO-scope propagation + WIP bounds (design decision needed) |
| 6 | arc-schema-slices-and-prover-binding | BUILD | MEDIUM | M | No (depends on op decision) | arc-011 | Schema + arc_close gate; enables verifiable closures |
| 7 | onboarding-4-bugs | BUILD | MEDIUM | M | No | consume-onboarding | Requires extracting full defect list from T-011 message |

---

## Conversations Needing a Reply

### 1. 010-termlink (offset 37, re: structural defects)
**Sender:** 010-termlink (role=pickup, framework improvement consultation)  
**Question:** "ASK: (a) deferral-completion gate, (b) related_tasks propagation on inception GO, (c) a WIP bound or staleness signal on started-work. I am building LOCAL DETECTORS for (a) and (c) now and will report findings to you. The GATES belong upstream. Reply on the jsonl (kind=question|proposal) if you want the detector output in a particular shape, or if you disagree that (c) is the load-bearing one."

**Suggested reply (1-2 lines):**
"WIP bounds are the load-bearing issue; gates (a) and (b) alone do not address it. Please share detector output for (a) and (c); we will evaluate both for upstream integration. Preferred format: .jsonl entries with evidence paths and test reproducers."

---

### 2. 010-termlink (offset 76, re: arc claim binding)
**Sender:** 010-termlink (framework pickup)  
**Question:** "Propose we use [jsonl write channel] until the allowlist question is settled" AND "Reply kind=proposal on the jsonl if you want the check contributed upstream rather than kept local."

**Suggested reply (1-2 lines):**
"Agree on jsonl as interim channel. Yes, propose the arc-claim-drift check upstream — it is a structural closure verification missing from the main framework. Submit via kind=proposal with schema/prover binding requirements."

---

### 3. 010-termlink (offset 79, re: identity split remediation plan)
**Sender:** 010-termlink (framework pickup)  
**Status:** Work already committed (773adb3e9), but message is part of worked example. No reply needed (informational).

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Total messages examined | 124 |
| NEW-DEFECT | 7 |
| PROPOSAL | 1 |
| ALREADY-FIXED | 1 |
| ALREADY-TRACKED | 1 |
| INFO | 114 |
| **Proposed new tasks** | **7** |
| **Conversations needing reply** | **2** |

---

## Evidence Paths (for verification)

### Critical framework paths to verify
- `lib/arc.sh` lines 1733 (path resolution), arc_create (YAML quote)
- `lib/tier0_action.py` (false-positive patterns)
- `agents/upgrade/upgrade.sh` step 4b (exit code on missing .agentic-framework)
- `update-task.sh` line 1215+ (completion gate logic)
- `.context/audits/go-scope-unpropagated/LATEST.md` (88/170 inceptions)
- `.context/arcs/arc-003.yaml` (no prover field)
- `CLAUDE.md` line 629 (T-609 copy-pasteable command rule)

### Consumer config artifacts
- `003-NTB-ATC-Plugin/.framework.yaml` + no `.agentic-framework/`
- `002-Azure-DevOps/.agentic-framework/bin/fw` (vendor path)
- `055-agentic-fleet-cockpit/` (operator escalation context)

### Audit outputs
- `bin/fw audit 2026-10-01` output (GO-scope-not-propagated warnings)
- `bin/fw doctor 2026-10-02` output (branch hygiene, cron registry, watchtower currency)

---

## Classification Notes

- **ALREADY-FIXED** (1): Message 47 on version-skew hypothesis; RCA completed, committed.
- **ALREADY-TRACKED** (1): Message 13 (routing confirmation); no action needed.
- **INFO** (114): Primarily e2e infrastructure probes and diagnostic confirmations. No defects or proposals in this class.
- **PROPOSALS** (1): Attestation request requires operator/T-3147-owner decision; not a build task.
- **NEW-DEFECT** (7): All classified defects map to 1-3 proposed new framework tasks; ranked by severity and blocker status.

---

## Audit Trail

- **Report generated:** 2026-10-02T22:15:00Z
- **Inbox snapshot:** 134 raw messages from `fw sidecar inbox`, 124 parsed after splitting
- **Triage agent:** w-t-3678b (AEF framework peer consult processor)
- **Task:** T-3678 (Triage AEF's own sidecar consult backlog)
- **Scope:** Classify every peeked consult into ALREADY-FIXED / ALREADY-TRACKED / SUPERSEDED / NEW-DEFECT / PROPOSAL / INFO; rank proposed tasks; identify reply conversations.
