---
id: T-2632
name: "designer 0.7.0 adoption — re-pin + annotation-seam overlay e2e"
description: >
  designer 0.7.0 adoption — re-pin + annotation-seam overlay e2e

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-27T19:16:15Z
last_update: 2026-07-27T19:29:24Z
date_finished: 2026-07-27T19:29:24Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
---

# T-2632: designer 0.7.0 adoption — re-pin + annotation-seam overlay e2e

## Context

832 cut designer 0.7.0 (rail 222, tag `designer-v0.7.0`, sha256 `472d6a5d…be04`,
889411 B): T-259 eventDef preservation fix + T-258 annotation seam v0 (the T-250
GO contract) + MANIFEST `capabilities: {annotation_seam: 1}`. Adoption per
pull-at-tag (T-247/D-335): update pin from announce → `fw designer sync
--from-tag` (sha must match announce AND MANIFEST at tag) → serve → e2e →
verdict on rail.

NEW this round: first release where the overlay seam can fire end-to-end. Their
announced intake is `{uid, badge<=48, tone:info|ok|warn|err, title<=200}` —
field names differ from our Slice A payload (`severity`, `text`). Reconcile
against their protocol doc AT THE TAG before adapting anything.

## Acceptance Criteria

### Agent
- [x] Pin updated from the 222 announce (version/sha/bytes/artifact/tag/
      vendored_path); `fw designer sync --from-tag` fetched at designer-v0.7.0,
      independent sha256 matched BOTH announce and MANIFEST-at-tag
      (472d6a5d…be04, 889411 B), installed read-only
- [x] Markers verified in vendored bytes: aefEmitReady=2, aefApplyAnnotations=2,
      aef-annotation=13, eventDefKind=3 — all exactly per 222; MANIFEST at tag
      carries `capabilities: {annotation_seam: 1}`
- [x] Served byte-identical: /designer/app sha == vendored sha; editor loads
      aef-task-lifecycle latest (35 data-ids), console 0 errors
- [x] Field reconciliation done from protocol doc §Annotation seam at the tag:
      shipped intake is `{type, annotations:[{uid,badge,tone,title}]}` — NOT the
      rail-197 draft `nodes/severity/text`; our payload would have been silently
      ignored as malformed. tools/corpus_overlay.py now emits the shipped shape
      (severity ladder maps info→info/warn→warn/alert→err; text→title; 48/200
      clamps); tests updated (13 overlay tests + full tests/web 136 green);
      wrapper forward stays verbatim (only its status line reads .annotations)
- [x] Overlay e2e LIVE (browser, Playwright): wrapper status "aef:annotate
      forwarded … (5 badges)"; 5 badge pills in editor DOM with correct tones
      (tone-info ×2, tone-warn ×2, tone-err ×1), tooltips carry stuck-counts and
      focus marker; console 0 errors. First end-to-end firing of the T-2620 seam.
- [x] eventDef preservation verified on our intake through the editor's REAL
      save path: 3-eventDef fixture (draft-trigger-handling v1 content) opened
      and saved in 0.7.0 — all 3 survive on their hosts (timer@startEvent,
      message@intermediateThrowEvent, message@intermediateCatchEvent), canonical
      form kind+binding="" as announced at 218. (Save-target mishap during the
      check polluted draft-trigger-handling with a v4; deleted via /api/delete,
      draft restored to latest=3 — see Evolution.)

### Human
- [ ] [REVIEW] Live overlay v0 reads right (first end-to-end render)
  **Steps:**
  1. Open http://192.168.10.107:3001/designer/overlay?id=aef-task-lifecycle
  2. Badges should appear on lifecycle nodes (bucket counts) and the status line should show "aef:annotate forwarded"
  3. Judge: badge placement/tone legible? overlay adds signal without cluttering the diagram?
  **Expected:** live task-state badges on the map, diagram stays readable
  **If not:** note what reads wrong — badge text/thresholds are ours (tools/corpus_overlay.py), placement/styling is 832's; we route feedback accordingly

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
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

test "$(sha256sum vendor/designer/aef-workflow-designer-0.7.0.html | cut -d' ' -f1)" = "472d6a5d333ccb3c5e0d9cc5cfbb6bb9cff366c997d0362a77c3ec1856b8be04"
# T-2763: was `= "472d6a5d…"` (the 0.7.0 sha). That asserted "the live server currently
# serves 0.7.0" — true the instant this task shipped, false from the next re-pin onward.
# G-015 shape: a gate pinned to an always-moving global. It went red at 0.8.0 and would
# have refused this task at close for a reason unrelated to what it shipped.
# What this task actually produced is asserted durably on the line above, still green.
# This line now asserts the invariant that survives re-pinning: the server serves the
# build the pin names. Baseline read from the pin, never re-derived from the server.
served=$(curl -sf "$(bin/fw watchtower url)/designer/app" | sha256sum | cut -d' ' -f1); pinned=$(python3 -c "import yaml;print(yaml.safe_load(open('policy/designer-pin.yaml'))['sha256'])"); [ -n "$pinned" ] && [ "$served" = "$pinned" ]
test "$(grep -c aefApplyAnnotations vendor/designer/aef-workflow-designer-0.7.0.html)" = "2"
python3 -m pytest tests/unit/test_corpus_overlay.py tests/web/test_api_overlay.py tests/web/test_designer_overlay.py -q
# T-2764: classified (a) WRONG — superseded shape, repairable. The `annotations`/`tone`
# adaptation this line asserted was T-2632's own deliverable, and T-2635 deliberately
# REVERTED it: 832 confirmed the `nodes/severity/text` shape canonical at rail 230, and
# T-2635 retired the alias from the emitter (it stays accepted on intake until 0.8.0).
# So this asserted a deliverable that was removed on purpose, with the peer's agreement —
# not a regression. Evidence: T-2635 Context ("T-2629's stored Verification greps
# ['annotations'] → back to ['nodes']") — it repaired the sibling's line and missed this
# one, the very task that introduced the assertion. Until now the corpus held a straight
# contradiction: T-2635 asserts `! grep -q '"annotations"'` on the same endpoint.
# Repaired shape-agnostically: the canonical shape is T-2635's deliverable to assert, not
# this task's. What T-2632 durably shipped is the seam serving renderable annotations, so
# that is what this asserts — and it survives the 0.8.0 alias retirement either way.
curl -sf "$(bin/fw watchtower url)/api/overlay?id=aef-task-lifecycle" -o /tmp/.t2632-overlay.json && python3 -c "import json;d=json.load(open('/tmp/.t2632-overlay.json'));items=d.get('nodes') or d.get('annotations') or [];assert d.get('type')=='aef:annotate',d.get('type');assert items,'no renderable entries';assert all(('uid' in i and 'badge' in i) for i in items)"
# T-2763: was `= "3"`. Second G-015 in this same block — `latest` is a revision counter
# that only ever moves (now 6). "The draft's current revision is 3" was true the day this
# shipped and false at the next save. What T-2632 durably established is that the revision
# it created exists and was not rolled back, so assert the floor, not the moment.
test "$(python3 -c "import json; print(json.load(open('.context/designer/projects/draft-trigger-handling/meta.json'))['latest'])")" -ge 3

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

## Recommendation

- **Recommendation:** GO
- **Rationale:** 0.7.0 adopted per pull-at-tag with every gate green, and the
  T-2620 overlay seam fired end-to-end for the first time — live task-state
  badges on the lifecycle map, driven by the real /api/overlay projection
  through the ratified postMessage contract. The one contract surprise (shipped
  intake shape ≠ rail-197 draft field names) was caught by reading the protocol
  doc at the tag and fixed in the single projection place before anything
  shipped mismatched. Your call is the [REVIEW]: does the live overlay read
  well enough to stand as v0?
- **Evidence:**
  - sha256 exact vs announce + MANIFEST-at-tag; served byte-identical
  - markers 2/2/13/3 exact; capabilities.annotation_seam=1
  - Browser e2e: 5 badges, correct tones, tooltips, focus marker, 0 console
    errors; wrapper status "aef:annotate forwarded (5 badges)"
  - eventDef fix verified on our intake: 3/3 survive real open→save
  - tests/web + overlay unit: 136 passed

## Evolution

### 2026-07-27 — shipped intake ≠ draft contract; save-dialog target trap
- **What changed:** (1) 832's shipped annotation intake key is `annotations`
  with `{uid,badge,tone,title}` — the rail-197 draft shape (`nodes`,
  `severity`, `text`) we built Slice A against would have been silently
  ignored (malformed payloads are dropped by design). Caught by reading the
  protocol doc at the tag BEFORE e2e; fixed in tools/corpus_overlay.py only —
  the wrapper's verbatim-forward design meant zero wrapper logic changes.
  (2) The editor's "Save to project" dialog binds its target from the map's
  workflowMeta id, not the ?load source — saving a scratch COPY of a map whose
  workflowMeta id still names the original wrote v4 onto the real
  draft-trigger-handling project (synthetically editing the dialog's id input
  didn't rebind; unclear if a real keystroke would — flagged to 832 as an
  observation, not a defect claim). Deleted v4, draft restored to latest=3.
- **Plan impact:** payload contract questions now have a canonical answer
  source: the protocol doc AT THE TAG, not rail announcements (which compress).
  Scratch-map round-trip tests must rewrite workflowMeta id before loading.
- **Triggered:** nothing filed — both learnings recorded here + memory; rail
  message to 832 carries the verdict + the save-dialog observation.

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

### 2026-07-27T19:16:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2632-designer-070-adoption--re-pin--annotatio.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-778b75f1
- **Timestamp:** 2026-07-27T19:29:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_corpus_overlay.py tests/web/test_api_overlay.py tests/web/test_designer_overlay.py -q`

### 2026-07-27T19:29:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
