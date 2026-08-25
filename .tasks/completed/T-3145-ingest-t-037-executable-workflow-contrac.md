---
id: T-3145
name: "Ingest T-037 executable workflow-contract runtime source packet (AEF side)"
description: >
  Ingest T-037 executable workflow-contract runtime source packet (AEF side)

status: work-completed
workflow_type: design
owner: agent
horizon: null
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
created: 2026-08-25T21:28:35Z
last_update: 2026-08-25T22:06:12Z
date_finished: 2026-08-25T22:06:12Z
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
  - ts: '2026-08-25T21:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:design); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-25T21:30:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3145: Ingest T-037 executable workflow-contract runtime source packet (AEF side)

## Context

AEF-side ingestion of the T-037 executable workflow-contract runtime source packet
dispatched from `0503-codex-cli-playground` (correlation `t037-aef-ingestion`,
receiver role `aef-agent`, human decision owner dimitri@geelenandcompany.com).

**Scope is bounded to ingestion and reflection.** Phases 0–2 of the shared
operating contract in
`/opt/0503-codex-cli-playground/docs/prompts/T-036-aef-workflow-designer-governed-execution-prompts.md`:
store and hash-verify both sources immutably, produce a bounded operating digest,
reflect against AEF's *actual* topology and governance rather than importing the
proposed arcs, and return an ingestion receipt.

**Explicitly out of scope** (contract §Phase 3 and the operator dispatch
checklist both forbid it at this stage): implementing any runtime, starting or
drafting an arc, confirming BVP scores, or bulk-creating the roadmap's candidate
tasks. Every disposition this task produces is a proposal to the operator.

Artifacts (all under `docs/research/executable-workflow/`):

| File | Role |
|---|---|
| `architecture-c9070637.md` | Immutable snapshot — architecture dossier |
| `roadmap-5be23719.md` | Immutable snapshot — delivery roadmap |
| `source-manifest.yaml` | Hash/provenance/read-back record + transport incident |
| `operating-digest.md` | Bounded navigation aid (never an authority) |
| `questions-and-dispositions.md` | Gap matrix, arc dispositions, open questions |
| `governance-cadence.md` | Phase 5 reconciliation loop, status board, stop conditions |

A transport defect found during ingestion is registered as **G-086** and homed to
the sending project.

## Acceptance Criteria

### Agent
- [x] Both source documents stored as immutable hash-addressed snapshots whose
      on-disk SHA-256 matches the expected hash declared in the T-036 source packet
- [x] `source-manifest.yaml` records source URL, source project, full expected and
      received hashes, receiver task, correlation, transport, and read-back result
      for both documents, and parses as valid YAML
- [x] `operating-digest.md` exists and explicitly declares itself a navigation aid
      subordinate to the hash-pinned sources
- [x] `questions-and-dispositions.md` carries an evidence-cited local
      current-state/gap matrix, a disposition for each of the 7 proposed arcs
      (accept / revise / merge / defer / reject), and an open-questions register
      with source-heading citations
- [x] `governance-cadence.md` carries the Phase 5 reconciliation triggers, a
      delta-only status board, stop conditions, and the blocking human decisions
- [x] The raw-URL transport defect is registered in the concerns register as G-086,
      preserving both wrapped (HTML-viewer) hashes and homed to the sending project
      per the gap-homing rule
- [x] Bounded-scope guard: no arc created for this initiative, no `bvp_scores:`
      self-confirmed on this task, no procedure/ratification registry or runtime
      code created

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

## Verification

# --- AC1: immutable snapshots match the declared source-packet hashes ---
test "$(sha256sum docs/research/executable-workflow/architecture-c9070637.md | cut -d" " -f1)" = c9070637b09493a24abc99982ae966a3b3ae8cd4a358a44fdceb59bdceb6ac2d
test "$(sha256sum docs/research/executable-workflow/roadmap-5be23719.md | cut -d" " -f1)" = 5be23719b976e37a6461b4b1f6f309985b5ba033ef0b801769edd2627fbae5b8
# --- AC2: manifest parses and asserts read-back for both documents ---
python3 -c 'import yaml; d=yaml.safe_load(open("docs/research/executable-workflow/source-manifest.yaml")); assert d["receiver_task"]=="T-3145" and len(d["documents"])==2 and all(x["hash_match"] and x["read_back_ok"] for x in d["documents"])'
# --- AC3: digest declares itself non-authoritative ---
grep -q "never an authority" docs/research/executable-workflow/operating-digest.md
# --- AC4: dispositions artifact present with all 7 arc rows ---
test -s docs/research/executable-workflow/questions-and-dispositions.md
test "$(grep -cE "^\| \*\*[0-6] " docs/research/executable-workflow/questions-and-dispositions.md)" = 7
# --- AC5: governance cadence artifact present with stop conditions ---
test -s docs/research/executable-workflow/governance-cadence.md
grep -q "Stop conditions" docs/research/executable-workflow/governance-cadence.md
# --- AC6: G-086 registered, homed to peer, both wrapped hashes preserved ---
python3 -c 'import yaml; c=yaml.safe_load(open(".context/project/concerns.yaml"))["concerns"]; g=[x for x in c if x["id"]=="G-086"]; assert len(g)==1 and g[0]["homed_to"]=="0503-codex-cli-playground"'
grep -q aeb5180a9424af0fa33a6a5647b20789294a6807b621b8cea4b7a5f6d84f3772 .context/project/concerns.yaml
grep -q 0988d8ac7a6af9009ea1caf1c33a66bb6e6404fd9cf29b2ebc896f558dca8784 .context/project/concerns.yaml
# --- AC7: bounded-scope guard (negative assertions) ---
! grep -rl executable-workflow-contract-runtime .context/arcs/ >/dev/null 2>&1
! grep -qE "^bvp_scores:" .tasks/active/T-3145-ingest-t-037-executable-workflow-contrac.md
! test -e .context/procedures

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

**Recommendation:** GO — on a **draft Arc 0 only**, and only after the operator
rules on the two authority conflicts below. NO-GO on everything downstream of
Arc 0 until its exit gate is evidenced.

**Rationale:** The source packet is verified, internally coherent, and well
matched to AEF's actual substrate — two of its central claims (no-arbitrary-shell,
transport≠receipt) are independently corroborated by failures AEF already measured
and pinned in its own tests. Arc 0 is correctly scoped to AEF-owned surfaces per
arch §5.1, so the roadmap §7 question "does Arc 0 belong in AEF?" answers yes.
But three findings mean this cannot be a blanket GO: the roadmap's own first
verification fence (Component Fabric enriched and validated) **fails today** at
45.8% unclassified components; AEF has no service identity at all, making Arc 2 a
build rather than a proof; and two AEF governance patterns (`--force`/`FW_*`
bypasses, `--from-watchtower` direct mutation) directly contradict acceptance
scenarios 16 and 20. Those two are design decisions with permanent blast radius
and belong to the operator, not to an agent drafting an arc around them.

**Evidence:**
- Both snapshots re-verified this session: `c9070637…6ac2d`, `5be23719…ae5b8` — exact match, `read_back_ok: true`.
- `bin/fw fabric overview`: 27 subsystems / 1117 components / 5669 edges, but 512 components (45.8%) in `Unknown` → roadmap §6 fence 1 fails.
- No ratification/procedure registry exists locally (`.context/procedures` absent; no framework hit for `ratif|procedure_version` under `lib/`, `bin/fw`) → arch §2.1 is green-field, no conflict.
- `.context/dispatches.jsonl` (1817 rows) + `.context/dispatch-outcomes.jsonl` (2266 rows) are a reusable append-only substrate but have no signing, fold, retention or redaction → arch §14.5 stays open.
- CLAUDE.md §Enforcement Tiers (T-2742) + `tests/unit/tier0_scope_boundary.bats`: Tier 0 matches only the typed command string → AEF has already proven string-matching cannot bound execution, corroborating arch §6.2.1.
- Conflicts: `--force`/`FW_ALLOW_*`/`FW_SKIP_*` vs arch §13.16; `--from-watchtower` arc mutation vs arch §13.20.
- Transport defect confirmed and registered as G-086; `VERSION MISMATCH` correctly not declared.

## Decisions

### 2026-08-25 — Hash mismatch on both declared source URLs
- **Chose:** Establish the transport's raw-bytes behaviour before applying the contract's `VERSION MISMATCH` rule; read authoritative bytes from the peer working tree, and record the incident rather than refusing the packet.
- **Why:** Both URLs returned HTTP 200 with mismatching hashes, but `file(1)` reported "HTML document" and the payload began `<!DOCTYPE html>` with a csrf-token meta tag — the endpoint is a Watchtower HTML viewer, not raw bytes. The peer working-tree bytes matched both expected hashes exactly, proving a transport artifact, not a source revision. Declaring `VERSION MISMATCH` would have refused a byte-for-byte correct document.
- **Rejected:** (a) Declaring `VERSION MISMATCH` as literally instructed — would have been a false negative on a correct document. (b) Silently substituting the filesystem copy without recording the discrepancy — would have hidden a defect that breaks any receiver lacking filesystem reach to the peer.

### 2026-08-25 — Where to file the transport defect
- **Chose:** Register G-086 locally with `homed_to: 0503-codex-cli-playground`, and request the fix through the ingestion receipt on correlation `t037-aef-ingestion`.
- **Why:** Gap homing (T-1333) puts an entry where the fix lives; the fix is a publishing change in the sending project. But a purely remote entry would be invisible to future AEF receivers of this packet, so the entry is mirrored here as a receiver-side observation with the peer named as owner.
- **Rejected:** Editing the peer repository to fix it directly — prohibited by the arch §5.1 ownership boundary and by the contract's repository-boundary rule.

### 2026-08-25 — How much of the proposed roadmap to translate into AEF work
- **Chose:** Propose exactly one arc (Arc 0, revised), with dispositions recorded for the other six and no arc, task, or BVP confirmation created.
- **Why:** Roadmap §7 and the operator dispatch checklist both forbid bulk creation, and the write sets and acceptance criteria of Arcs 1–6 depend on evidence Arc 0 has not yet produced. Arc 0's own first fence currently fails, so committing downstream structure now would encode an assumption already known to be false.
- **Rejected:** Importing the full 7-arc chain as draft arcs — would create six arcs whose exit gates cannot be evidenced and would misrepresent agent reflection as operator authorisation.

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

### 2026-08-25T21:28:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3145-ingest-t-037-executable-workflow-contrac.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-67c0967c
- **Timestamp:** 2026-08-25T22:06:13Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 19
     - evidence: `! grep -rl executable-workflow-contract-runtime .context/arcs/ >/dev/null 2>&1`

### 2026-08-25T22:06:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
