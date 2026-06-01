---
id: T-2154
name: "T-1761 build: hybrid auto-classify in orchestrator-mcp-scan.sh (Option 3, --apply
  opt-in)"
description: >
  Implements T-1761 GO decision (Option 3 hybrid from research artifact). Adds classify_by_convention(name)
  helper to agents/audit/orchestrator-mcp-scan.sh: termlink_agent_ and termlink_channel_
  namespace tools whose suffix matches a verb-list (post, send, broadcast, edit, react,
  pin, quote, redact, reply, star, typing_emit, ack, forward, poll_start, poll_end,
  poll_vote) classify to mutators_ungated; remaining termlink_agent_/termlink_channel_
  tools (analytics, status, snapshot, list, count, summary shapes) classify to readonly_exempt;
  tools outside these namespaces remain unknown (manual review). Default mode lists
  auto_classified suggestions in LATEST.yaml as advisory. New --apply flag rewrites
  baseline.yaml in-place (with .bak backup). Keeps blast radius bounded to the two
  namespaces with 7-batch zero-misclassification track record.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [orchestrator-rethink, orchestrator-mcp-scan, T-1761-build]
components: [agents/audit/orchestrator-mcp-scan.sh, tests/unit/test_orchestrator_mcp_classify.py]
related_tasks: [T-1761, T-1646, T-1755, T-1760, T-1867, T-2073, T-2150]
arc_id: orchestrator-rethink
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-01T08:23:36Z
last_update: 2026-06-01T08:37:20Z
date_finished: 2026-06-01T08:37:20Z
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
bvp_scores_proposed:
  - ts: '2026-06-01T08:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-01T08:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2154: T-1761 build: hybrid auto-classify in orchestrator-mcp-scan.sh (Option 3, --apply opt-in)

## Context

Implements T-1761 inception GO decision (recorded 2026-06-01 commit `ec47467a`). Build slice for **Option 3 (Hybrid)** from research artifact `docs/reports/T-1761-auto-classify-heuristic.md` §Implementation shapes line 89: convention auto-applies for `termlink_agent_*` + `termlink_channel_*` namespaces (7 batches × ~15 min ≈ 105 min toil, zero misclassifications across 196 tools); other namespaces continue manual classification (where ambiguity is higher).

The convention encoded by 7 historical batches (T-1755, T-1755 f/u, T-1760, T-1867, T-2073, T-2073 f/u, T-2150):
- Action-verb suffix → `mutators_ungated` (e.g. `termlink_agent_post`, `termlink_channel_broadcast`)
- Read-shape suffix → `readonly_exempt` (e.g. `termlink_agent_status`, `termlink_channel_recent`)

Verb whitelist (from baseline header annotations across all 7 batches): `post, send, broadcast, edit, react, pin, quote, redact, reply, star, typing_emit, ack, forward, poll_start, poll_end, poll_vote, reauth`.

## Acceptance Criteria

### Agent
- [x] Add `classify_by_convention(name)` helper to `agents/audit/orchestrator-mcp-scan.sh` (inline Python block where the YAML emit lives). Returns one of `{"mutators_ungated", "readonly_exempt", "unknown"}`. Returns `"unknown"` for any tool not matching `termlink_(agent|channel)_*` (blast radius bound).
- [x] Verb whitelist is a single source-of-truth Python set inside the script: `{post, send, broadcast, edit, react, pin, quote, redact, reply, star, typing_emit, ack, forward, poll_start, poll_end, poll_vote, reauth}`. Suffix-match (last underscore-delimited segment, OR known multi-word verbs like `poll_start`/`poll_end`/`poll_vote`/`typing_emit`).
- [x] Scan's `new_tools` set is partitioned into `auto_classified_mutators`, `auto_classified_readonly`, `still_unclassified` BEFORE the existing WARN-on-new-tools logic. Existing WARN only fires for `still_unclassified` (not for auto-classified). This is the value delivered: agents stop seeing "NEW: N unclassified" WARN for tools the convention already handles.
- [x] LATEST.yaml output gains `auto_classified: {mutators_ungated: [...], readonly_exempt: [...]}` field listing the convention-classified tools per run (advisory, even in default dry-run mode).
- [x] Add `--apply` flag handler. When `--apply` is passed AND the scan would otherwise WARN on auto-classifiable tools, rewrite `.context/audits/orchestrator-mcp-baseline.yaml` in-place (with `.bak` backup written first), appending auto-classified tools to the appropriate category and bumping `baseline_count`. Without `--apply`, no mutation.
- [x] Unit test `tests/unit/test_orchestrator_mcp_classify.py` covering: (a) `termlink_agent_post` → mutators_ungated; (b) `termlink_agent_status` → readonly_exempt; (c) `termlink_channel_broadcast` → mutators_ungated; (d) `termlink_channel_recent` → readonly_exempt; (e) `termlink_orchestrator_foo` → unknown (out-of-namespace); (f) `termlink_agent_poll_start` (multi-word verb) → mutators_ungated; (g) `termlink_agent_typing_emit` → mutators_ungated.
- [x] Existing `agents/audit/orchestrator-mcp-scan.sh` PASSes against current 251-tool baseline post-change (no regression — empty `new_tools` → empty `auto_classified` → same PASS).
- [x] Baseline file header (commented block) gains a 2026-06-01 entry pointing at T-2154: "convention auto-classification now applied at scan time; T-1761 verb whitelist canonical."

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

# T-2154 verification commands (P-011 / L-387 safe — direct grep on files OR
# tempfile-capture before grep; no streaming-cmd | grep -q pipelines).
grep -q "def classify_by_convention" agents/audit/orchestrator-mcp-scan.sh
grep -q "'broadcast'" agents/audit/orchestrator-mcp-scan.sh
grep -q "'poll_start'" agents/audit/orchestrator-mcp-scan.sh
grep -qE -- "--apply" agents/audit/orchestrator-mcp-scan.sh
grep -q "T-2154" .context/audits/orchestrator-mcp-baseline.yaml
test -f tests/unit/test_orchestrator_mcp_classify.py
python3 -m pytest tests/unit/test_orchestrator_mcp_classify.py -q --tb=short > /tmp/t2154-tests.log 2>&1 && grep -q "13 passed" /tmp/t2154-tests.log
bash agents/audit/orchestrator-mcp-scan.sh > /tmp/t2154-scan.log 2>&1 || true; grep -q "Tools: 251 (baseline 251)" /tmp/t2154-scan.log
python3 -c "import yaml; d=yaml.safe_load(open('.context/audits/orchestrator-LATEST.yaml')); assert 'auto_classified' in d['findings'], 'missing auto_classified'; assert d['findings']['auto_classified'] == {'mutators_ungated': [], 'readonly_exempt': []}, 'expected empty on clean state'; print('LATEST.yaml shape OK')"
bash -n agents/audit/orchestrator-mcp-scan.sh

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

### 2026-06-01 — multi-word verb handling

- **What changed:** The verb whitelist at filing time was assumed to be all single-word (post/send/edit/etc.). Build revealed four multi-word verbs (`poll_start`, `poll_end`, `poll_vote`, `typing_emit`) — baseline already classifies `termlink_agent_poll_start` etc. as mutators. A naïve "last-segment match" classifier would route `termlink_agent_poll_start` → "start" → not in whitelist → readonly (mis-classification). Fix: two-tier match — multi-word verbs match the FULL suffix or `_<verb>` boundary first; single-word verbs match the last underscore-segment second.
- **Plan impact:** Classifier needed two constant sets (`CONVENTION_MUTATOR_VERBS_MULTI`, `CONVENTION_MUTATOR_VERBS_SINGLE`) rather than one. Unit test (f) and (g) explicitly pin the multi-word cases — single set would have left them implicitly broken.
- **Triggered:** Nothing new — scope cut: T-1761 §Implementation shapes line 89 said "bounded blast radius". Resisted urge to extend convention to `termlink_fleet_*`/`termlink_hub_*`/`termlink_tofu_*` namespaces (T-2073 batch classified those manually). Out-of-namespace tools stay `unknown` until a separate follow-up decision.

### 2026-06-01 — apply-mode baseline header round-trip

- **What changed:** `yaml.safe_dump` does not preserve comment blocks. The baseline file's header is ~50 lines of provenance comments across 7 batches — losing that on first `--apply` would be a real regression. Fix: read the original file, split off the leading comment-only block, prepend it back after `yaml.safe_dump` emits the body. Also append a fresh T-2154 stamp at the end of the header block so the apply event is itself audit-trail.
- **Plan impact:** None to ACs — the AC said "rewrite baseline.yaml in-place (with .bak backup)" without specifying comment preservation. Doing it the lossy way would have been technically AC-conformant but semantically wrong. Logged here as the kind of small implementation choice that's invisible in the AC but matters at the actual touched file.
- **Triggered:** Nothing — no follow-up needed. The header-split approach is generic and lives inside the apply block; no library extraction warranted.

## Recommendation

**Recommendation:** GO

**Rationale:** All 8 Agent ACs satisfied with structural evidence. Pure additive build slice — classifier returns `unknown` for any tool outside the two proven-safe namespaces (bounded blast radius per T-1761 §Implementation shapes), and `--apply` is opt-in. Default-mode scan on current 251-tool baseline returns same exit/output as pre-T-2154 (no regression, verified by 251→251 round-trip). End-to-end `--apply` smoke test on synthetic state (1 tool removed from baseline) correctly re-classified, wrote .bak backup, bumped baseline_count 250→251, preserved header comment block. 13/13 unit tests pass — pins the two-tier verb-match against canonical and edge cases (multi-word verbs, out-of-namespace, empty suffix).

Closes T-1761 GO scope. Future batches of new `termlink_agent_*`/`termlink_channel_*` tools surface as `AUTO-CLASSIFIABLE` advisory; operator passes `--apply` to ratchet them into baseline without manual YAML editing. Eliminates the ~15-min × N-batches toil that motivated T-1761.

**Evidence:**
- Classifier: `agents/audit/orchestrator-mcp-scan.sh:96+` — `classify_by_convention(name)` with two-tier verb match (multi-word longest-match first, single-word last-segment second). 17 verbs total across both sets.
- Unit tests: `tests/unit/test_orchestrator_mcp_classify.py` — 13/13 passed, covers canonical cases + multi-word verbs + out-of-namespace + empty-suffix edge.
- Scan-no-regression: `bash agents/audit/orchestrator-mcp-scan.sh` returns "Tools: 251 (baseline 251)" with only pre-existing TAG-FORMAT-DRIFT WARN; auto_classified={mutators_ungated:[], readonly_exempt:[]} on clean state.
- `--apply` smoke (removed `termlink_agent_post` from baseline → re-applied): "APPLIED: +1 mutator(s), +0 readonly via convention (baseline 250 → 251, backup: ...orchestrator-mcp-baseline.yaml.bak)". Header comments preserved, T-2154 stamp appended.
- Baseline header: `.context/audits/orchestrator-mcp-baseline.yaml` — gained 7-line T-2154 provenance block above `baseline_count:` line.

**What's next:** Convention extension to `termlink_fleet_*`/`termlink_hub_*`/`termlink_tofu_*` namespaces is a separate decision (T-2073 manually classified some; track record is shorter). If those batches resurface with the same verb-convention shape, propose a sibling task widening `CONVENTION_NAMESPACES`. For now, bounded.

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

### 2026-06-01T08:23:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2154-t-1761-build-hybrid-auto-classify-in-orc.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-44068943
- **Timestamp:** 2026-06-01T08:37:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **external-publish** (high) — External publish or release
     - matched: `broadcast`

### 2026-06-01T08:37:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
