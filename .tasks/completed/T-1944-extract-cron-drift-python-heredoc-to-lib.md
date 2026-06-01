---
id: T-1944
name: "extract cron drift python heredoc to lib helper L-408 prevention"
description: >
  extract cron drift python heredoc to lib helper L-408 prevention

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: [arc:value-prioritisation, future-prevention, L-408, L-332, refactor]
components: [C-004, bin/fw, lib/cron_dry_run.py]
related_tasks: [T-1942, T-1943, T-1629]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T05:51:39Z
last_update: 2026-05-20T06:03:09Z
date_finished: 2026-05-20T06:03:09Z
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
  - ts: '2026-05-20T06:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1944: extract cron drift python heredoc to lib helper L-408 prevention

## Context

T-1942/T-1943 added cron registry → generated drift detection at both
`fw doctor` (WARN) and `fw audit` (FAIL) surfaces. Both call sites use
the identical `$(python3 - <<'PY' ... PY)` inline-heredoc pattern —
the exact shape L-332 (2026-05-01, T-1629) explicitly banned and L-408
(2026-05-19, T-1942) re-captured after 3rd-incident lockup.

Symptoms today:
- Every `bin/fw` invocation emits `bin/fw: line 1713: warning: command
  substitution: 1 unterminated here-document` to stderr (cosmetic).
- Same Python logic duplicated across `bin/fw:1713-1750` and
  `agents/audit/audit.sh:1028-1065`. Any future edit to the generation
  algorithm needs two-place updates; drift between them is invisible.
- The pattern is the one that bit the agent twice in T-1942 (lost
  closing `)` while trying to "fix" the cosmetic warning).

Fix per L-332: extract Python to `lib/cron_dry_run.py`; invoke from
both bash sites as `python3 "$FRAMEWORK_ROOT/lib/cron_dry_run.py" ...`.
Bash side becomes parse-safe; cosmetic warning disappears; single
source of truth for the generation algorithm.

## Acceptance Criteria

### Agent
- [x] `lib/cron_dry_run.py` exists, executable, takes 3 positional args (project_root, registry_file, fw_path), emits the same crontab text the heredocs emitted (byte-identical for the in-repo state).
- [x] `bin/fw` no longer contains an inline `python3 - ... <<'PY' ... PY` block; the doctor cron check invokes `lib/cron_dry_run.py` and `bash -n bin/fw` produces no warnings.
- [x] `agents/audit/audit.sh` no longer contains an inline `python3 - ... <<'PY' ... PY` block; the audit cron check invokes `lib/cron_dry_run.py` and `bash -n agents/audit/audit.sh` produces no warnings.
- [x] `bats tests/unit/test_cron_registry_generated_drift.bats` — all 3 T-1942 tests still pass after the refactor.
- [x] `bats tests/unit/test_audit_cron_registry_generated_drift.bats` — all 3 T-1943 tests still pass after the refactor.
- [x] `bats tests/unit/test_audit_cron_drift.bats` — all 5 T-1771 tests still pass.
- [x] `bin/fw doctor` runs without the cosmetic "unterminated here-document" warning on the first line.
- [x] `lib/cron_dry_run.py` registered in `.fabric/components/`.

### Human

(none — pure structural refactor; byte-equivalence + green bats are deterministic checks.)

<!-- (template kept below as reference; intentionally left empty above)
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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

bash -n bin/fw
bash -n agents/audit/audit.sh
bats tests/unit/test_cron_registry_generated_drift.bats
bats tests/unit/test_audit_cron_registry_generated_drift.bats
bats tests/unit/test_audit_cron_drift.bats
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"
test -x lib/cron_dry_run.py

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

### 2026-05-20 — L-332 was already the canonical rule; L-408 was a duplicate trigger

- **What changed:** Surfacing the related-knowledge sidebar on `fw work-on` revealed L-332 (2026-05-01, T-1629) — the pre-existing rule banning `$(cmd <<EOF ... EOF)` in hot-path bash dispatchers, with prescriptive guidance ("any Python helper >10 lines goes in lib/*.py"). The L-408 entry written last segment (T-1942) was the 3rd-incident reinforcement of the same class, not a new class. The arc-006 work that introduced the heredocs (T-1942/T-1943) bypassed L-332 because the related-knowledge surface wasn't consulted at the start of that task.
- **Plan impact:** Refactor is mechanical (extract → invoke), but the meta-finding is that the prevention rule existed and was missed. Suggests future-prevention work: surface L-rules whose `application:` field is "TBD" more aggressively at task-create time, or attach class-tagged learnings to hook block-messages (e.g. the bin/fw boundary check could echo "L-332" when it sees an inline `$(... <<EOF ...)` in a Write/Edit diff).
- **Triggered:** No new sub-task — this Evolution entry plus a learnings.yaml update to cross-link L-408 → L-332 ("3rd-incident reinforcement, same class") is the prevention. Larger "auto-surface learnings on task-create" idea logged here but not filed; would need its own inception.

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

**Recommendation:** GO (work-completed)

**Rationale:** Pure structural refactor with byte-equivalent output. Eliminates the cosmetic warning that polluted every `bin/fw` invocation, removes ~40 lines of duplicated Python between `bin/fw` and `agents/audit/audit.sh`, and routes both surfaces through a single source of truth (`lib/cron_dry_run.py`). Closes the L-332/L-408 prevention loop the framework had explicitly written but the agent had still violated 3× in 2026-05. All three bats suites (T-1942 / T-1943 / T-1771) remain green; doctor and audit functional behaviour is unchanged.

**Evidence:**
- bin/fw / audit.sh parse clean (`bash -n` no warnings); previously: `bin/fw: line 1713: warning: command substitution: 1 unterminated here-document` on every invocation
- T-1942 bats 3/3 PASS, T-1943 bats 3/3 PASS, T-1771 bats 5/5 PASS (no regression)
- `bin/fw doctor` first line is the banner, not the cosmetic warning (drift gate green: in-sync line present, edited-but-not-generated absent)
- `lib/cron_dry_run.py` byte-identical to on-disk `agentic-audit.crontab` in the framework repo
- Commit `0e0d7d56`; fabric card created (`.fabric/components/lib-cron_dry_run.yaml`)

## Decisions

### 2026-05-20 — Extract to lib/*.py (not lib/*.sh or inline `python3 -c`)
- **Chose:** New file `lib/cron_dry_run.py` with `#!/usr/bin/env python3` shebang
- **Why:** L-332's explicit prescription. Matches the established convention (`lib/doctor-hook-exercise.py`, `lib/ollama_loop.py`, `lib/outcome.py`, ...). Inline `python3 -c "..."` would not fit ~30 lines without escaping headaches; a `.sh` shim would just push the heredoc problem one level down.
- **Rejected:** (a) Single-line `python3 -c` — too long, escape-prone. (b) Bash-native generation — would re-implement the registry parser. (c) Wrap inline heredoc in a function — doesn't fix the parse-error self-lockout class.

### 2026-05-20 — Cross-link L-408 to L-332 in learnings.yaml
- **Chose:** Append a one-line cross-reference to L-408's body noting it is the 3rd-incident reinforcement of L-332, not a new class.
- **Why:** Honest provenance — the prevention rule existed; the issue was rule discoverability at task-create time. Future-prevention candidates depend on framing this as a meta-class (rule not consulted) rather than a fresh learning.

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

### 2026-05-20T05:51:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1944-extract-cron-drift-python-heredoc-to-lib.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-79fdd2ee
- **Timestamp:** 2026-05-20T06:07:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-20T06:03:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
