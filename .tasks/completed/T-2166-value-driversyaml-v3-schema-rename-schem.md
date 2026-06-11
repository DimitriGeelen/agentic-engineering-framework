---
id: T-2166
name: "value-drivers.yaml v3 schema rename: schema_version→version, D1-D4 rationale→note,
  add rubric/guardrails/polarity, activate F-RECALL+F-ORCH free drivers"
description: >
  value-drivers.yaml v3 schema rename: schema_version→version, D1-D4 rationale→note,
  add rubric/guardrails/polarity, activate F-RECALL+F-ORCH free drivers

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc:value-prioritisation, value-drivers, bvp, schema]
components: [policy/value-drivers.yaml]
related_tasks: [T-2157, T-2165, T-1915, T-1921]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-01T17:43:03Z
last_update: '2026-06-11T22:24:10Z'
date_finished: 2026-06-01T17:50:10Z
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
  - ts: '2026-06-01T17:45:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-01T17:45:38Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 6
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2166: value-drivers.yaml v3 schema rename: schema_version→version, D1-D4 rationale→note, add rubric/guardrails/polarity, activate F-RECALL+F-ORCH free drivers

## Context

T-2157 inception (Decision: GO) + T-2165 continuation (evidence walk: Recommendation flipped DEFER → GO with refinements). Per `docs/reports/T-2157-value-drivers-v3-redesign.md`, v3 ships in ONE hard-rename slice — zero consumer-code changes needed because no reader checks `schema_version`, no reader reads `protected:` field value, only `web/blueprints/bvp.py:136` reads `rationale:` (free drivers only — they keep `rationale:` in v3). New fields (rubric/guardrails/polarity/retire_when) are pure additions ignored by all readers via `dict.get()` patterns.

This task lands the YAML edit only. The 5 follow-up slices (T-NEW-A..E) are operator-filed after.

## Acceptance Criteria

### Agent
- [x] `policy/value-drivers.yaml` `schema_version: 1` is replaced with `version: 3` (top-level field rename + bump).
- [x] Each of D1-D4 in `protected_drivers:` carries exactly: `id`, `name`, `weight`, `note:` (renamed from `rationale:`). Existing `weight:` values preserved (9/7/5/3). New `note:` text restates the existing `rationale:` content (CLAUDE.md directives unchanged in meaning). Per the verbatim proposal, `protected: true` is REMOVED from D1-D4 — protection now lives in list-membership semantics (`protected_drivers:` section name) and the lib/bvp.sh:837 ID-prefix pattern, both confirmed safe by the T-2165 walk. Rubric for D1-D4 stays in `policy/bvp-scoring-rubric.md` (T-1921) — D1-D4 do NOT carry `rubric:`/`guardrails:`/`polarity:` fields.
- [x] `free_drivers:` is no longer `[]` — it has **two active entries** F-RECALL (weight 6) and F-ORCH (weight 5) plus **one commented carve** F-AUTONOMY. Each active entry carries: `id`, `name`, `weight`, `rationale:`, `polarity: positive`, `rubric:` (mapping with keys 0..5), `guardrails:` (multi-line string), `retire_when:` (free-text string). F-AUTONOMY is fully commented out as a YAML carve (not parsed; preserves the proposal's "candidate not active" framing).
- [x] `auto_promote:` block unchanged: `enabled: false`, `bvp_norm_min: 0.85`, `cost_max: 1`, `max_concurrent: 1`. (Activation is §ACD-gated separately; this task touches schema only.)
- [x] File header docstring (lines 1-39) updated to mention v3 and the F-RECALL/F-ORCH free drivers; references to `schema_version` updated to `version`; reference to T-2157/T-2165 added under filing.
- [x] `python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); assert d['version']==3; assert len(d['protected_drivers'])==4; assert len(d['free_drivers'])==2; print('shape ok')"` — passes (single-line invariant check).
- [x] Smoke test: `bin/fw bvp` (rank command, no args) exits 0 and produces output — confirms no reader broke on the schema change.
- [x] No other source files touched: `git diff --name-only -- ':!.tasks' ':!.context'` shows only `policy/value-drivers.yaml`.

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

python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); assert d['version']==3, 'version not 3'; print('version ok')"
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); assert 'schema_version' not in d, 'schema_version still present'; print('rename ok')"
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); ids=[x['id'] for x in d['protected_drivers']]; assert ids==['D1','D2','D3','D4']; print('D1-D4 ok')"
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); fields=set(d['protected_drivers'][0].keys()); assert fields=={'id','name','weight','note'}, f'D1 fields wrong: {fields}'; print('D1 v3 fields ok')"
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); ids=[x['id'] for x in d['free_drivers']]; assert ids==['F-RECALL','F-ORCH'], 'free drivers not [F-RECALL, F-ORCH]'; print('free drivers ok')"
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); fr=d['free_drivers'][0]; assert {'rationale','rubric','guardrails','retire_when','polarity'}.issubset(fr.keys()); print('F-RECALL shape ok')"
out=$(bin/fw bvp 2>&1); echo "$out" | head -3

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

### 2026-06-01 — AC #2 corrected mid-build (D1-D4 don't carry rubric/guardrails/polarity)

- **What changed:** Initial AC #2 required D1-D4 to carry `rubric:`/`guardrails:`/`polarity:` fields (over-extrapolated from the task title's "per-driver" phrasing). When I read the verbatim proposed YAML in `docs/reports/T-2157-value-drivers-v3-redesign.md` lines 62-89, D1-D4 carry ONLY `id`/`name`/`weight`/`note` — those scoring fields live on free drivers (where the rubric guides human confirmation), while D1-D4's rubric stays canonical in `policy/bvp-scoring-rubric.md` (T-1921). Also: `protected: true` is REMOVED from D1-D4 in v3 (the consumer-walk T-2165 confirmed this is safe — protection lives in list-membership and ID-prefix patterns, not the field value).
- **Plan impact:** AC #2 corrected to match the proposal; AC #6 verification command tightened to exact-equality check `{'id','name','weight','note'}` on D1-D4 fields (was a subset-check that would have passed regardless).
- **Triggered:** None. The correction is bounded inside this task; the proposal verbatim is the source-of-truth and the artifact already documents the routing of rubric responsibilities (D1-D4 → .md, free drivers → inline YAML).

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

## Recommendation

**Recommendation:** GO

**Rationale:** v3 schema landed cleanly. Zero consumer code touched; all readers exercise cleanly against the new shape (smoke-tested `fw bvp`, `fw bvp --include-proposed`, `fw bvp T-2166` — all rc=0 with valid output). The T-2165 evidence walk's prediction held: this was a one-slice rename with no transition layer.

**Evidence:**
- `policy/value-drivers.yaml`: 79 → 203 lines (header docstring expanded, two free drivers + carve documented). Substantive deltas: `schema_version: 1` → `version: 3`; D1-D4 lose `protected: true` + `rationale:` → gain `note:`; `free_drivers:` gains F-RECALL (weight 6) + F-ORCH (weight 5) + commented F-AUTONOMY carve.
- All 8 ACs ticked; all 7 verification commands PASS.
- `git diff --name-only -- ':!.tasks' ':!.context'` → `policy/value-drivers.yaml` (single source file changed; scope fence held).
- The 5 follow-up slices (T-NEW-A..E) remain in the artifact's refinements table — operator's call on filing order.

## Updates

### 2026-06-01T17:43:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2166-value-driversyaml-v3-schema-rename-schem.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b0d91e5d
- **Timestamp:** 2026-06-02T15:01:28Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — Each of D1-D4 in `protected_drivers:` carries exactly: `id`, `name`, `weight`, `note:` (renamed from `rationale:`). Existing `weight:` values preserved (9/7/5/3). New `note:` text restates the existin
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/bvp.sh in: Each of D1-D4 in `protected_drivers:` carries exactly: `id`, `name`, `weight`, `note:` (renamed from `rationale:`). Existing `weight:` values preserve`
### 2026-06-01T17:50:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
