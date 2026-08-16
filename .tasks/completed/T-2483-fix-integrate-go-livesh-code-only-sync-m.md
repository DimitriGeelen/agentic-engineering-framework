---
id: T-2483
name: "fix integrate-go-live.sh: code-only sync model, not merge (OBS-086 live failure)"
description: >
  The T-2482 merge-based go-live script failed in live --apply: committing MAIN transients
  then merging origin/master conflicts on every data file (18, not the 1 dry-run predicted)
  and races MAIN's concurrent git writers (index.lock crash, left MAIN half-merged).
  Recovered safely; went live via the correct pattern instead: git checkout origin/master
  -- lib agents bin && commit (code-only, data untouched). Rewrite the script around
  that model: code-only checkout, dry-run default, optional vendored refresh, no merge,
  no commit-then-merge. RCA the false-confidence dry-run.

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-06-24T12:09:20Z
last_update: '2026-08-16T22:25:07Z'
date_finished: 2026-06-24T12:12:51Z
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
  - ts: '2026-08-16T22:25:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2483: fix integrate-go-live.sh: code-only sync model, not merge (OBS-086 live failure)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `bin/integrate-go-live.sh` rewritten to the code-only model: `git checkout <remote-ref> -- <code dirs>` then a single `T-XXX` commit of only those staged code files. NO checkpoint-commit, NO `git merge`, NO conflict whitelist — it never touches `.context/` data, so it cannot conflict on accumulators or race a busy checkout's data writers. — Verification asserts `git merge` absent + `git checkout … -- $CODE_DIRS` present.
- [x] Dry-run by default (`--apply` to execute); `--repo`, `--remote-ref`, `--task`, `--code-dirs`, `-h` flags; already-in-sync (no staged delta after checkout) is a clean no-op; refuses if the working tree has staged code changes it didn't create. — dry-run vs MAIN reported "already in sync / already live".
- [x] RCA section explains the false-confidence dry-run (merge-tree vs pre-checkpoint HEAD) and why merge-of-divergent-busy-checkouts is the wrong model for zone-3 go-live. — see ## RCA.
- [x] `bash -n` clean; a live `--dry-run` against MAIN shows the code-dir sync plan with ZERO mutations (MAIN `git status` md5 identical before/after). — bash -n OK; dry-run ran, MAIN status md5 identical before/after.

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

test -x bin/integrate-go-live.sh
bash -n bin/integrate-go-live.sh
bin/integrate-go-live.sh -h | grep -q "code-only"
grep -q "git checkout .* -- \$CODE_DIRS" bin/integrate-go-live.sh
code=$(grep -v '^[[:space:]]*#' bin/integrate-go-live.sh); ! echo "$code" | grep -q "git merge"

## RCA

**Symptom:** The v1 go-live script (T-2482) passed its dry-run ("1 conflict, all
regenerable") but on live `--apply` produced 18 data-file conflicts and crashed
half-merged on a `.git/index.lock` race, leaving MAIN in a broken merge state.

**Root cause:** Two compounding design errors. (1) Wrong model — the script
committed MAIN's dirty transients as a checkpoint, then `git merge origin/master`.
Once both sides have a commit touching the same data file, git conflicts on it;
since every `.context/*` transient is touched on both sides, every one conflicted.
The take-theirs whitelist also covered accumulators (feedback-stream,
gate-bypass-log) that need UNION, not theirs. (2) Concurrency — MAIN is a busy
checkout (watchtower/cron write `.context/` constantly), so a multi-step git
mutation races for `index.lock`.

**Why structurally allowed:** the dry-run gave false confidence — it predicted via
`git merge-tree origin/master HEAD`, i.e. against *pre-checkpoint* HEAD, but the
real merge runs *after* the checkpoint commit moves HEAD. The verification path
diverged from the execution path (same class as a mock that doesn't match the real
CLI). No test exercised `--apply` against a dirty busy checkout.

**Prevention:** abandon the merge model entirely. Going live = code only:
`git checkout <ref> -- lib agents bin && git commit` — never touches `.context/`
data, so it cannot conflict on accumulators and cannot race data writers (one quick
index op). The new script's Verification asserts `git merge` is ABSENT from it. The
correct pattern is recorded in OBS-086; proven live (MAIN went live at b2cdff6fe,
30 `.context/` files preserved untouched). Learning: a go-live dry-run must predict
against the *same* HEAD the apply path will use, or it lies.

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

### 2026-06-24T12:09:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2483-fix-integrate-go-livesh-code-only-sync-m.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5e04ccd2
- **Timestamp:** 2026-06-24T12:12:52Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 34
     - evidence: `bin/integrate-go-live.sh -h | grep -q "code-only"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 36
     - evidence: `code=$(grep -v '^[[:space:]]*#' bin/integrate-go-live.sh); ! echo "$code" | grep -q "git merge"`

### 2026-06-24T12:12:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
