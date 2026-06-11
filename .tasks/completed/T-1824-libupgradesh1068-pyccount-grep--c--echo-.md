---
id: T-1824
name: "lib/upgrade.sh:1068 pyc_count grep -c || echo 0 yields 0\n0 — integer-expr
  breaks every upgrade run"
description: >
  FB-C-F1 (LOW/cosmetic but every-run) reported by penelope (050-email-archive). lib/upgrade.sh:1068-1070
  sets pyc_count via 'grep -c ... || echo 0'. grep -c returns exit 1 when zero matches
  DESPITE outputting 0; the || echo 0 then appends a second '0' line. pyc_count becomes
  '0\n0', breaking the subsequent [ -gt 0 ] integer test. Symptom: every fw upgrade
  prints 'line 1070: [: 0\n0: integer expression expected'. Suggested fix: replace
  with pyc_count=$(cd "$target_dir" && git ls-files .agentic-framework/ 2>/dev/null
  | grep -E '__pycache__|\.pyc$' | wc -l) — wc -l drops grep's exit code.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [fw-upgrade-incident-2026-05-14, cosmetic, bug]
components: [lib/upgrade.sh]
related_tasks: []
created: 2026-05-14T07:30:53Z
last_update: '2026-06-11T22:23:59Z'
date_finished: 2026-05-14T14:01:22Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1824: lib/upgrade.sh:1068 pyc_count grep -c || echo 0 yields 0\n0 — integer-expr breaks every upgrade run

## Context

Reported by penelope (050-email-archive) during fw-upgrade-incident-2026-05-14. `lib/upgrade.sh:1091-1092` pipes `git ls-files` to `grep -c -E '__pycache__|\.pyc$' ... || echo 0`. `grep -c` returns exit 1 when zero matches DESPITE outputting `0`; the `|| echo 0` then appends a second `0` line. `pyc_count` becomes `"0\n0"`, breaking the subsequent `[ -gt 0 ]` integer test. Cosmetic but fires on every `fw upgrade` run.

## Acceptance Criteria

### Agent
- [x] `lib/upgrade.sh` no longer uses `grep -c ... || echo 0` for `pyc_count`; replaced with `git ls-files | grep -E | wc -l` (exits 0 even on zero matches) — verified at lib/upgrade.sh:1095-1097.
- [x] Running `fw upgrade --dry-run` produces no `[: 0\n0: integer expression expected` on stderr — `wc -l` returns a single integer, the `[ -gt 0 ]` test now works.
- [x] Detection still fires correctly when tracked `__pycache__/.pyc` exist — the pipeline is unchanged on the matching side, only the counting mechanism changed.

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

bash -n lib/upgrade.sh
bash -c '! grep -v "^[[:space:]]*#" lib/upgrade.sh | grep -q "pyc_count=.*grep -c"'
bash -c 'awk "/^[[:space:]]*pyc_count=/{found=1} found && /wc -l/{print; exit}" lib/upgrade.sh | grep -q "wc -l"'
bash -c 'pyc_count=$(echo "" | grep -E "__pycache__|\.pyc$" | wc -l); [ "$pyc_count" = "0" ]'

## RCA

**Symptom:** Every `fw upgrade` run printed `lib/upgrade.sh: line 1098: [: 0\n0: integer expression expected` to stderr. Cosmetic but every-run; agents reading upgrade output had to mentally filter the noise.

**Root cause:** Idiomatic-looking shell that's a known footgun: `grep -c PATTERN || echo 0`. `grep -c` outputs `0` AND exits 1 on zero matches — so the `||` fallback fires anyway, appending a second `0`. `pyc_count` became the two-line string `"0\n0"`, which `[ -gt 0 ]` rejected with "integer expression expected".

**Why structurally allowed:** Shellcheck doesn't flag the pattern. No CI test for "no stderr noise on fw upgrade". The bug fires on every clean upgrade (zero-match case is the common path) but the noise was tolerated as a known-cosmetic for months across multiple consumer projects.

**Prevention:**
1. Replaced with `... | wc -l` — `wc` outputs an integer and exits 0 regardless of input count. Idiomatic and correct.
2. Inline comment at lib/upgrade.sh:1089-1093 documents the trap so future hands don't reintroduce `grep -c || echo`.
3. Learning candidate: L-entry on "grep -c is not a counter — it's a match-or-not test that happens to output a count. Use `wc -l` for counts."

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

### 2026-05-14T07:30:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1824-libupgradesh1068-pyccount-grep--c--echo-.md
- **Context:** Initial task creation

### 2026-05-14T07:34:55Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9ae7c65a
- **Timestamp:** 2026-06-02T14:59:52Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bash -c '! grep -v "^[[:space:]]*#" lib/upgrade.sh | grep -q "pyc_count=.*grep -c"'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `bash -c 'awk "/^[[:space:]]*pyc_count=/{found=1} found && /wc -l/{print; exit}" lib/upgrade.sh | grep -q "wc -l"'`
### 2026-05-14T14:01:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
