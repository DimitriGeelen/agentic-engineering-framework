---
id: T-1746
name: "T-1745 fix: silent-failure on inception-decide form (RC1 regex + RC2 comment-strip
  + RC3 warning-render + integration test)"
description: >
  T-1745 fix: silent-failure on inception-decide form (RC1 regex + RC2 comment-strip
  + RC3 warning-render + integration test)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/inception_recommendation.sh, lib/task-audit.sh, 
      web/blueprints/inception.py, web/templates/inception_detail.html]
related_tasks: []
created: 2026-05-05T13:25:47Z
last_update: '2026-06-11T22:23:57Z'
date_finished: 2026-05-05T13:57:05Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1746: T-1745 fix: silent-failure on inception-decide form (RC1 regex + RC2 comment-strip + RC3 warning-render + integration test)

## Context

T-1745 GO authorized this build. Three compounding bugs let T-1744 inception-decide silently no-op
4× across 2h. Full RCA: `docs/reports/T-1745-rca-watchtower-decision-silent-failure.md`.

## Acceptance Criteria

### Agent
- [x] **A1 — RC1 fix:** `lib/task-audit.sh::audit_inception_recommendation` accepts `**Recommendation:** **GO**` (inner emphasis on verdict). Sibling `lib/inception_recommendation.sh::has_real_recommendation` updated identically so audit detector and decide-gate align.
- [x] **A2 — RC2 fix:** `web/blueprints/inception.py::_decision_recorded_in_task` strips HTML comments before scanning the `## Decision` body and requires a non-commented canonical decision marker (e.g., `**Decision**:` followed by the verdict). Placeholder template comments no longer cause `primary_landed=True`.
- [x] **A3 — RC3 fix:** `web/templates/inception_detail.html` renders a yellow `?warning=` banner mirroring the existing `?error=` block. User sees a banner whenever the decision flow returns warning OR error.
- [x] **A4 — Integration test:** `tests/web/test_inception_decide_e2e.py` (extended) exercises all three layers end-to-end. Four new `test_t1746_*` cases cover bold-verdict POST, false-positive comment placeholder, GO/NO-GO substring collision, and warning banner render.
- [x] **A5 — Regression pin:** A pre-fix variant of the fixture (template still containing `<!-- ... go|no-go ... -->` placeholder, no `## Decision` content) returns `primary_landed=False` when calling `_decision_recorded_in_task` — the false-positive path is closed.
- [x] **A6 — G-068 concern:** `concerns.yaml` gains G-068 entry naming the meta-pattern (G-067 was already taken — embeddings strategy). G-068 names the human-control-surface silent-failure pattern.
- [x] **A7 — Smoke test on real bug:** After fixes deployed and Watchtower :3002 restarted, human re-clicked GO at http://192.168.10.107:3002/inception/T-1744 — decision landed (`**Decision**: GO` in body, task moved to `.tasks/completed/`). `_decision_recorded_in_task('T-1744', 'go')` returns True against the real on-disk body. Latent format-mismatch caught and fixed: regex now accepts both `**Decision**:` and `**Decision:**` variants.

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

# A1 — validator regex accepts inner emphasis on verdict (both call sites)
bash -c 'source lib/task-audit.sh; tmp=$(mktemp); printf "## Recommendation\n\n**Recommendation:** **GO** — fix it\n" > "$tmp"; audit_inception_recommendation "$tmp"; rc=$?; rm -f "$tmp"; exit $rc'
bash -c 'source lib/inception_recommendation.sh; tmp=$(mktemp); printf "## Recommendation\n\n**Recommendation:** **GO** — fix it\n" > "$tmp"; has_real_recommendation "$tmp"; rc=$?; rm -f "$tmp"; exit $rc'
# A1 — validator still rejects empty/comment-only Recommendation
bash -c 'source lib/task-audit.sh; tmp=$(mktemp); printf "## Recommendation\n\n<!-- placeholder -->\n" > "$tmp"; ! audit_inception_recommendation "$tmp"; rc=$?; rm -f "$tmp"; exit $rc'
# A2 + A4 + A5 — RC2 fix (false-positive closed, both marker formats accepted, GO/NO-GO substring collision absent) all covered by the t1746 regression tests
python3 -m pytest tests/web/test_inception_decide_e2e.py -k "t1746" -q 2>&1 | tail -3 | grep -qE "[0-9]+ passed"
# A3 — warning banner rendered in template
grep -q "request.args.get('warning')" web/templates/inception_detail.html
# A4 — full inception-decide test suite still passes (no regression)
python3 -m pytest tests/web/test_inception_decide_e2e.py tests/web/test_inception_decide_hardening.py -q 2>&1 | tail -3 | grep -qE "[0-9]+ passed"
# A6 — G-068 registered (G-067 was taken)
grep -q "G-068" .context/project/concerns.yaml
# A7 — real-bug smoke test: T-1744 GO landed and is detectable post-decide
test -f .tasks/completed/T-1744-spike-d-off-ramp-pick-a-different-g-064-.md

## RCA

**Symptom:** POST `/inception/T-1744/decide` returned 200 OK; decision never persisted; no UI feedback. Human submitted GO 4× across 2h. Recorded zero times.

**Root cause:** Three independent bugs aligned to produce silent failure (full diagnostic in `docs/reports/T-1745-rca-watchtower-decision-silent-failure.md`):
- RC1 (`lib/task-audit.sh:154`) — validator regex requires `[A-Za-z]` after `**Recommendation:**`, rejects bold-emphasized verdicts.
- RC2 (`web/blueprints/inception.py:578`) — `_decision_recorded_in_task` matches placeholder comment text, false-positives `primary_landed=True`.
- RC3 (`web/templates/inception_detail.html:384`) — only renders `?error=`, ignores `?warning=`.

**Why structurally allowed:** Three drift channels: (a) validator was hardened over time for various edge cases (T-1497, T-1510, T-1528) but never for inner emphasis on the verdict; (b) `primary_landed` check was a recent refinement (T-1470) that traded false-negatives for false-positives without comment-stripping; (c) warning route (T-1470) and error route (T-1454) were added in different sessions — only error route got the matching template support. Three different `## Recommendation` parsers live in three files and disagreed silently. No cross-cutting integration test exercised all three layers together.

**Prevention:**
- Validator regex normalised across both call sites (M1).
- `_decision_recorded_in_task` now strips comments and requires canonical marker (M2).
- Template renders both `?error=` and `?warning=` (M3).
- Integration test M4 pins all three layers; future edits to any one layer must keep the test green.
- Concern G-067 registers the meta-pattern (no liveness check on decision-form persistence) so future blind-spot detection has a name and an owner.

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

### 2026-05-05T13:25:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1746-t-1745-fix-silent-failure-on-inception-d.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-69f1a241
- **Timestamp:** 2026-06-02T14:59:28Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 3

**Per-AC findings:**

- **AC#2 (Agent)** — **A2 — RC2 fix:** `web/blueprints/inception.py::_decision_recorded_in_task` strips HTML comments before scanning the `## Decision` body and requires a non-commented canonical decision marker (e.g., `*
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/inception.py in: **A2 — RC2 fix:** `web/blueprints/inception.py::_decision_recorded_in_task` strips HTML comments before scanning the `## Decision` body and requires a`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 16
     - evidence: `python3 -m pytest tests/web/test_inception_decide_e2e.py -k "t1746" -q 2>&1 | tail -3 | grep -qE "[0-9]+ passed"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 20
     - evidence: `python3 -m pytest tests/web/test_inception_decide_e2e.py tests/web/test_inception_decide_hardening.py -q 2>&1 | tail -3 | grep -qE "[0-9]+ passed"`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`
### 2026-05-05T13:57:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
