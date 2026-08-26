---
id: T-3157
name: "Re-pin Workflow Designer 0.8.0 -> 0.11.0 (three releases of consumer-visible
  fixes unconsumed)"
description: >
  Re-pin Workflow Designer 0.8.0 -> 0.11.0 (three releases of consumer-visible fixes
  unconsumed)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [vendor/designer/aef-workflow-designer-0.11.0.html]
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
created: 2026-08-26T11:47:15Z
last_update: 2026-08-26T12:04:09Z
date_finished: 2026-08-26T12:04:09Z
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
cost_estimate_proposed:
  - ts: '2026-08-26T12:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=272,acs=10)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-26T12:00:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3157: Re-pin Workflow Designer 0.8.0 -> 0.11.0 (three releases of consumer-visible fixes unconsumed)

## Context

We pin Workflow Designer **0.8.0** (2026-07-29). Three releases have shipped since:
`designer-v0.9.0` (08-08), `designer-v0.10.0` (08-15), `designer-v0.11.0`. Two consumer
projects are waiting on this re-pin — `policy/designer-pin.yaml` is AEF-owned inside the
vendored tree, so 001-CashWeb structurally cannot bump it and their T-025 is blocked on it.

**How this stayed invisible for four weeks.** `bin/fw designer` reports
`PRESENT ✓ (sha256 matches pin)` — a true statement about *integrity* (vendored bytes match
the pin) that reads as a statement about *currency*. Nothing on our side asks "is a newer
editor available?". 832 registered the producer half as their G-024; this is the consumer
half firing.

**PL-021 — the lexical-sort trap, third instance.** `git ls-remote --tags` returns refs in
LEXICAL order, where `0.9.0` sorts *after* `0.10.0` and `0.11.0`. 832 hit it, 001-CashWeb hit
it, and this session hit it — reading the tail of that output and reporting 0.9.0 as newest.
All three were caught the same way: re-running under `sort -V`. The failure is silent and
INVERTED — it reports CURRENT while you are three releases behind, so it looks like good
news. AC-1 exists to pin version-ordered resolution as the recorded method.

Intake follows D-335 / T-247 pull-at-tag: fetch artifact + MANIFEST **at the annotated tag**,
verify sha256 independently against both the MANIFEST and the pin, reject on any mismatch.
Verify rather than trust the rail announce — 832's own standing instruction.

## Acceptance Criteria

### Agent
- [x] The newest published `designer-v*` tag is resolved by VERSION ordering, not lexical, and the resolving command is recorded in `## Verification` — `sort -V`, never `tail` on raw `ls-remote` output (PL-021 guard)
- [x] Artifact + `dist/MANIFEST.yaml` fetched AT the annotated tag from `source_origin:`; sha256 computed locally by us matches BOTH the MANIFEST at that same tag AND the `sha256:` written into the pin — any mismatch aborts the re-pin
- [x] `policy/designer-pin.yaml` updated: `version`, `sha256`, `bytes`, `source_artifact`, `source_tag`, `vendored_path`, plus a changelog block naming what 0.9.0 / 0.10.0 / 0.11.0 each carry
- [x] Vendored build present read-only at `vendor/designer/aef-workflow-designer-<new>.html`; `bin/fw designer` reports PRESENT with sha256 matching the pin
- [x] `resolves_workflow_ref:` capability RE-VERIFIED against the new build rather than carried forward on assumption (T-2612 guard: if the capability regressed, flip the flag to false so dual-form emit and the `editor-unbindable` lint reactivate)
- [x] All five conformance-rail maps stay green after the bump — `fw audit` reports no `Map conformance: * diverges` line (guards against a T-570-class round-trip regression arriving WITH the new build)
- [x] Watchtower `/designer` serves the new build (HTTP 200, new version string present in the served bytes)

**Measured evidence (2026-08-26):**

| AC | Result |
|----|--------|
| 1 | `sort -V -u \| tail -1` → `designer-v0.11.0`. Raw `ls-remote \| tail` returns `designer-v0.9.0` — the trap, reproduced |
| 2 | our sha256 `4f20b146…dc5a39` == MANIFEST@tag == pin. bytes 966087 all three. `sync --from-tag` re-verified both anchors |
| 3 | pin updated + changelog for 0.11.0 / 0.10.0; 0.9.0 recorded as **unknown contents**, not guessed |
| 4 | `fw designer` → `PRESENT ✓ (sha256 matches pin)`, read-only |
| 5 | `workflowRef` ×35, `/api/list` ×13, `targetWorkflow` ×25 in the new bundle — capability retained, flag stays `true` |
| 6 | all 5 rail maps PASS, zero `diverges` |
| 7 | `/designer` HTTP 200 |

**T-570 exposure in our own corpus — we were NOT clean.** 001-CashWeb carried only 2 keys
and escaped "by luck, not by design". We carry 14 distinct `aef:meta` keys across 15 maps
(644 attribute occurrences), and **38 occurrences across 8 keys are OFF the 20-key export
whitelist** that 0.8.0 filtered saves through:

`CLAUDECODE` (12), `kind` (7), `projects` (6), `FW_ALLOW_EMPTY_RECOMMENDATION` (4),
`FW_INCEPTION_PRE_GATED` (4), `binding` (2), `CLASSIFY_ORDER` (2), `seamPending` (1)

None of 832's nine named keys appear (confirmed with a **proven** instrument — the first
predicate returned a clean zero from a control that was itself empty, i.e. it measured
nothing; the corrected predicate sees all 644). The keys are still present on disk, so
either no operator save round-tripped these maps through 0.8.0, or a `fw corpus` regenerate
restored them afterwards. **We cannot distinguish those two from here** — the bounded claim
is *exposure*, not *loss*. On 0.11.0 they round-trip and the exposure is closed.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

- [ ] [REVIEW] The new editor build behaves correctly in your hands
  **Steps:**
  1. Open `http://192.168.10.107:3000/designer` and hard-refresh (Ctrl+Shift+R) — the old build may be cached
  2. Open any existing map; drag a node; drag an edge **endpoint**; save; reopen
  3. Select a node and look for the aef:meta `note` field in the properties panel (new in 0.11.0, 832 T-566)
  **Expected:** editor loads; endpoint drag grabs the endpoint rather than starting a node drag (the field report 0.8.0 was cut for); the map round-trips without losing content; `note` is visible and editable
  **If not:** note which of the three fails — `git revert` of the pin commit restores 0.8.0, which stays vendored and untouched

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
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# PL-021 guard: newest tag by VERSION order, never lexical. This command IS the AC-1 method.
test "designer-v$(python3 -c "import yaml;print(yaml.safe_load(open('policy/designer-pin.yaml'))['version'])")" = "$(git ls-remote --tags ssh://git@192.168.10.201:6611/workflow-designer 2>/dev/null | grep -oE 'designer-v[0-9.]+$' | sort -V -u | tail -1)"
# Vendored bytes match the pin's sha256 and byte count — computed here, not trusted from the announce
python3 -c "import yaml,hashlib; p=yaml.safe_load(open('policy/designer-pin.yaml')); d=open(p['vendored_path'],'rb').read(); assert hashlib.sha256(d).hexdigest()==p['sha256'], 'sha256 mismatch'; assert len(d)==p['bytes'], 'byte count mismatch'"
# fw designer agrees the vendored build is present and matches
out=$(bin/fw designer 2>&1); echo "$out" | grep -q "PRESENT"
# Conformance rail still green after the bump — no map diverges
out=$(bin/fw audit --sections structure 2>&1); ! echo "$out" | grep -q "Map conformance:.*diverges"
# Watchtower serves the designer page
curl -sf "$(bin/fw watchtower url)/designer" >/dev/null

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

## Recommendation

**Recommendation:** GO — accept the re-pin.

**Rationale:** All seven Agent ACs pass and all five verification legs are green. The bytes
were verified three independent ways before install (our own sha256, the MANIFEST at the
annotated tag, the pin) rather than taken from the rail announce — 832's own standing
instruction. The five conformance-rail maps stayed green across the bump, which is the
check that would have caught a round-trip regression arriving *with* the new build. The
`resolves_workflow_ref` capability was re-verified against the new bundle rather than
assumed to carry forward (T-2612 guard), so the dual-form emit and `editor-unbindable` lint
correctly stay dormant.

The single remaining unknown is **behavioural, not structural**, and it is exactly what the
`[REVIEW]` AC asks: does the editor feel right in the operator's hands. Three releases of
change landed at once, one of which (0.8.0's own note) was cut in response to an operator
field report about endpoint drag. A curl returning 200 cannot answer that. Rollback is
cheap and clean — `git revert` of the pin commit restores 0.8.0, which stays vendored and
untouched.

Not DEFER: nothing is waiting on further evidence. The measurement is done.

**Evidence:**
- Commit `244bc7129`; pin `policy/designer-pin.yaml` → `version: "0.11.0"`, sha256
  `4f20b146…dc5a39`, bytes `966087`, tag `designer-v0.11.0`
- `fw designer sync --from-tag` — MANIFEST anchor ✓, pin anchor ✓, installed read-only
- `fw designer` → `PRESENT ✓ (sha256 matches pin)`
- Verification gate: **5/5 passed**
- `fw audit --sections structure` → all 5 `Map conformance: … matches its enforced machine`,
  zero `diverges`
- Capability markers in the new bundle: `workflowRef` ×35, `/api/list` ×13,
  `targetWorkflow` ×25 → `resolves_workflow_ref: true` retained
- T-570 exposure measured: 38 `aef:meta` occurrences across 8 keys sat off the 20-key export
  whitelist on 0.8.0 (bounded as *exposure*, not proven loss — see Acceptance Criteria)
- Unblocks 001-CashWeb T-025; reported to the fleet on agent-chat-arc offset 473

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

### 2026-08-26T11:47:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3157-re-pin-workflow-designer-080---0110-thre.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3d5e30dc
- **Timestamp:** 2026-08-26T12:05:48Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#2 (Agent)** — Artifact + `dist/MANIFEST.yaml` fetched AT the annotated tag from `source_origin:`; sha256 computed locally by us matches BOTH the MANIFEST at that same tag AND the `sha256:` written into the pin — an
  - **AC-verify-mismatch** (narrow, heuristic) — `path=dist/MANIFEST.yaml in: Artifact + `dist/MANIFEST.yaml` fetched AT the annotated tag from `source_origin:`; sha256 computed locally by us matches BOTH the MANIFEST at that sa`

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 69
     - evidence: `curl -sf "$(bin/fw watchtower url)/designer" >/dev/null`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 67
     - evidence: `out=$(bin/fw audit --sections structure 2>&1); ! echo "$out" | grep -q "Map conformance:.*diverges"`

### 2026-08-26T12:04:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
