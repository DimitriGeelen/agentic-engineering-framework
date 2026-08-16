---
id: T-1861
name: "fix gate-bypass log writer — unescaped single quotes in REASON corrupt YAML
  (audit can't parse log)"
description: >
  fix gate-bypass log writer — unescaped single quotes in REASON corrupt YAML (audit
  can't parse log)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bug, fix, yaml-quoting, audit-data-integrity, hook]
components: [agents/task-create/update-task.sh, 
      agents/context/check-active-task.sh, agents/context/check-human-ac-tick.py]
related_tasks: [T-1142, T-165]
created: 2026-05-15T18:32:24Z
last_update: '2026-08-16T22:24:46Z'
date_finished: 2026-05-15T20:37:05+02:00
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1861: fix gate-bypass log writer — unescaped single quotes in REASON corrupt YAML (audit can't parse log)

## Context

Three writers append YAML entries to `.context/working/.gate-bypass-log.yaml`:
- `agents/task-create/update-task.sh:32-42` (`log_gate_bypass()`) — writes `reason: '$REASON'` with no quote escaping
- `agents/context/check-active-task.sh:274-283` — writes focus-drift override entries
- `agents/context/check-human-ac-tick.py:77-96` (`log_bypass()`) — writes human-AC-tick override entries

All three use single-quoted YAML scalars without doubling embedded single quotes — the YAML spec's required escape for `'` inside `'…'`. The result: any bypass `reason` text containing a single quote (e.g., commit-message excerpts with apostrophes, code snippets with `'…'` strings) produces malformed YAML that breaks `yaml.safe_load`.

Concrete corruption surfaced on 2026-05-15: `.gate-bypass-log.yaml:390` — `reason: 'Verification bats reliably passes interactive (6/6) — gate flake under concurrent bg load (multiple stuck task-update processes). Implementation verified live: bin/fw doctor reports 'OK Hook exercise from /tmp: 14 hook(s) resolve from foreign CWD'.'` — the inner `'OK Hook…'` breaks the outer single-quoted scalar; the parser errors at `expected <block end>, but found '<scalar>'`. 53 bypasses in the last 7 days; the audit-warn counter currently does crude line counting because the file no longer parses.

This is functionally a quiet defect — audits "work" with crude line counts, but the moment any consumer (Watchtower, scripts, future audit checks) tries to actually parse the log, it fails. Same defect class as T-165 (Watchtower task-link YAML quoting bugs).

## Acceptance Criteria

### Agent
- [x] **A1** `agents/task-create/update-task.sh:log_gate_bypass()` escapes embedded single quotes by doubling (`'` → `''`) in all five fields (timestamp, task, flag, caller, reason). reason is the highest-risk field; others may not need it in practice but uniform escaping is the right structural fix.
- [x] **A2** `agents/context/check-active-task.sh:274-283` applies the same escaping to all written fields (the `tr -d "'"` on `command` should be replaced with proper escaping for consistency; or kept and documented as a separate sanitization layer).
- [x] **A3** `agents/context/check-human-ac-tick.py:log_bypass()` uses proper YAML serialization — either `yaml.safe_dump([entry])[2:]` (strips the leading `- ` since we append items not a list) or manual escaping that matches A1's approach.
- [x] **A4** Existing corrupted entries in `.context/working/.gate-bypass-log.yaml` are repaired in-place (single-quote-doubling applied to the malformed `reason:` values). After repair, `python3 -c "import yaml; yaml.safe_load(open('.context/working/.gate-bypass-log.yaml'))"` parses without error.
- [x] **A5** Bats unit test pins the writer: passing a reason with embedded single quotes through `log_gate_bypass` produces a log entry that round-trips through `yaml.safe_load` cleanly.
- [x] **A6** RCA section filled (symptom / root cause / why structurally allowed / prevention).

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

bats tests/unit/audit_gate_bypass_log.bats
python3 -c "import yaml; d = yaml.safe_load(open('.context/working/.gate-bypass-log.yaml')); assert isinstance(d, list) and len(d) > 0; print(f'Live log parses: {len(d)} entries')"
grep -q "_esc_reason=\"\${REASON//" agents/task-create/update-task.sh
grep -q "_q(file_path)" agents/context/check-human-ac-tick.py

## RCA

**Symptom:** `python3 -c "import yaml; yaml.safe_load(open('.context/working/.gate-bypass-log.yaml'))"` failed with `ParserError: expected <block end>, but found '<scalar>'` at line 386/390. The audit's "53 bypasses in last 7 days" WARN is generated via crude line counting precisely because the file no longer parses. Pinned to entries where `reason:` or `caller:` contained embedded single quotes (apostrophes, code snippets like `'Forward-only — backfill against history is OUT of scope'`).

**Root cause:** Three writers emit YAML entries with single-quoted scalar fields but do not double embedded `'` per the YAML single-quoted-scalar escape rule. Files:
- `agents/task-create/update-task.sh:32-42` — emits all 5 fields raw via bash interpolation
- `agents/context/check-active-task.sh:274-283` — emits 6 fields raw (with `tr -d "'"` on `command` field only)
- `agents/context/check-human-ac-tick.py:77-96` — emits 6 fields raw via f-string interpolation

**Why structurally allowed:** YAML single-quoted scalars have a well-known but easy-to-miss escape rule (`''` for `'`). All three writers reach for the natural single-quoted shape because it preserves whitespace and avoids backslash gymnastics — but none route through a real YAML serializer. The defect surfaces only when user-supplied text (reason, caller annotation, file path) happens to contain `'`. Most bypass calls have no quotes in their reason text; the silent corruption rate is bounded by how often agents include apostrophes or quoted snippets. Audit's crude line-counter never noticed because it never tried to parse.

T-165 (Watchtower task-link YAML quoting bugs) is the precedent — exact same defect class in a different writer.

**Prevention:**
1. All three writers now escape `'` → `''` in every user-controlled scalar field (uniform shape, regardless of which field happens to carry quotes today).
2. `tests/unit/audit_gate_bypass_log.bats` test #4 pins `log_gate_bypass` with a quote-containing REASON — the log must round-trip through `yaml.safe_load`. Any future writer regression that drops the escaping fails CI.
3. Existing 165 entries in the live log re-escaped via one-shot python script (`reason` + `caller` lines normalized).

**Class-wide opportunity:** Other framework writers (concerns.yaml, learnings.yaml, decisions.yaml, episodic YAMLs, frontmatter writers) likely have the same defect class. Out of scope here — would be one task per writer per "one bug = one task" rule. T-1861 closes the gate-bypass-log instance; broader audit is a separate follow-up if desired.

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T18:32:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1861-fix-gate-bypass-log-writer--unescaped-si.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f7b42980
- **Timestamp:** 2026-06-02T15:00:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
