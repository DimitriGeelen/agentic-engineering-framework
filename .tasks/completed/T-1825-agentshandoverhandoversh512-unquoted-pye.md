---
id: T-1825
name: "agents/handover/handover.sh:512 unquoted PYEOF heredoc triggers SC2284 lint
  false-positive"
description: >
  FB-C-F2 (LOW/lint-only) reported by penelope (050-email-archive). agents/handover/handover.sh
  line 512 opens 'python3 << PYEOF' (unquoted delimiter); shellcheck attempts to lint
  the Python content as bash and reports SC2284 false-positive on '==' operator at
  line 632 (inside the Python block). Suggested fix: quote heredoc delimiter at line
  512 → python3 << 'PYEOF'. Audit lines 776 and 802 for same issue. Line 688 (<< 'PCEOF')
  is already correct.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [fw-upgrade-incident-2026-05-14, lint, bug]
components: [agents/handover/handover.sh]
related_tasks: []
created: 2026-05-14T07:30:58Z
last_update: '2026-08-16T22:24:45Z'
date_finished: 2026-05-14T14:01:57Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1825: agents/handover/handover.sh:512 unquoted PYEOF heredoc triggers SC2284 lint false-positive

## Context

Reported by penelope (050-email-archive) during fw-upgrade-incident-2026-05-14. `agents/handover/handover.sh` has three unquoted `<< PYEOF` heredocs (lines 512, 776, 802). Shellcheck lints the Python body as bash and emits SC2284 false-positive errors. Penelope suggested simply quoting the delimiter — but each heredoc interpolates shell variables, so naive quoting would break behavior. The correct fix is to mirror the existing `PCEOF` pattern at line 688: pass shell vars through env, then quote the delimiter. SC2284 disappears (shellcheck stops linting quoted heredoc bodies as bash).

## Acceptance Criteria

### Agent
- [x] The `<< PYEOF` heredoc at line 512 is changed to `<< 'PYEOF'` with shell vars passed via env (TASKS_DIR_PY, WT_URL_PY, PROJECT_ROOT_PY) — mirroring the PCEOF pattern at line 688. Note: lines 776 and 802 (later PYEOFs) emit no SC2284 findings; refactor scope was limited to the one heredoc shellcheck flagged.
- [x] `shellcheck agents/handover/handover.sh` reports zero SC2284 findings — only unrelated diagnostics on lines 7, 910, 933 remain (none are SC2284).
- [x] Handover generation still produces a valid handover — auto-handover S-2026-0514-1546 (commit f3d8f9854) ran end-to-end after this fix landed in commit dd438d877.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bash -n agents/handover/handover.sh
bash -c "! shellcheck agents/handover/handover.sh 2>&1 | grep -q SC2284"
grep -q "python3 << 'PYEOF'" agents/handover/handover.sh

## RCA

**Symptom:** `shellcheck agents/handover/handover.sh` reported SC2284 on line ~632 — `==` operator not recognized. Lint-only, non-functional, but noisy in `fw test lint` output for any consumer.

**Root cause:** The heredoc at line 512 opened `python3 << PYEOF` (unquoted delimiter). Shellcheck treats unquoted-delimiter heredocs as bash content that's interpolated by the shell and lints the body as bash. The Python comparison operator `==` looked to shellcheck like a malformed bash assignment (SC2284).

**Why structurally allowed:**
1. The unquoted delimiter was load-bearing because shell vars (`$TASKS_DIR`, `$WT_URL`, `$PROJECT_ROOT`) were interpolated directly into the Python body. Naive quoting would break behavior.
2. The PCEOF pattern at line 688 (env-var + quoted delimiter) already existed in the same file as the correct fix — but it had never been promoted to PYEOFs because the SC2284 false-positive was tolerated as "harmless noise."

**Prevention:**
1. Adopted the PCEOF pattern at the line-512 PYEOF: env-var pass-through (`TASKS_DIR_PY="$TASKS_DIR" ... python3 << 'PYEOF'`) + quoted delimiter. Shellcheck now skips the body.
2. Convention now in place: any new shell-to-Python heredoc in this codebase should use the env-var + quoted-delimiter pattern (line 688 / new line 512 both demonstrate it).
3. Learning candidate: L-entry on "heredoc delimiter quoting controls shellcheck linting scope — unquoted = lint-as-bash, quoted = skip body. Pass vars via env when you need both quoted body and shell-side values."

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

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-14T07:30:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1825-agentshandoverhandoversh512-unquoted-pye.md
- **Context:** Initial task creation

### 2026-05-14T07:36:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f7de059d
- **Timestamp:** 2026-06-02T14:59:52Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bash -c "! shellcheck agents/handover/handover.sh 2>&1 | grep -q SC2284"`
### 2026-05-14T14:01:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
