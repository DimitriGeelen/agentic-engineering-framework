---
id: T-3374
name: "Fix OBS-423 fail-open: safe-commands env-prefix stripper accepts PATH/LD_PRELOAD/BASH_ENV
  without denylist"
description: >
  Fix OBS-423 fail-open: safe-commands env-prefix stripper accepts PATH/LD_PRELOAD/BASH_ENV
  without denylist

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/lib/safe-commands.sh, tests/unit/t3374_env_prefix_denylist.bats]
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
created: 2026-09-16T17:40:03Z
last_update: 2026-09-16T17:52:18Z
date_finished: 2026-09-16T17:52:18Z
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
  - ts: '2026-09-16T17:42:27Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=328,acs=10)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-16T17:45:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3374: Fix OBS-423 fail-open: safe-commands env-prefix stripper accepts PATH/LD_PRELOAD/BASH_ENV without denylist

## Context

Fixes **OBS-423** (filed under T-3373). The T-1908 env-prefix stripper in
`agents/context/lib/safe-commands.sh` removes **any** `NAME=VALUE` prefix before
the classifier reads the base command:

```bash
while [[ "$cmd" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+(.*)$ ]]; do
    cmd="${BASH_REMATCH[1]}"
done
```

It has no exclusion for variables that determine *what the base name resolves to*.
Measured before this task: `PATH=/tmp cat x`, `LD_PRELOAD=/tmp/e.so cat x`,
`BASH_ENV=/tmp/e.sh cat x` and `IFS=x cat y` all classify **SAFE**.

The gate decides SAFE from the base command *after* stripping, while the prefix it
discarded is precisely what controls the meaning of that base. This direction is
fail-**open** — the opposite of OBS-422, which over-blocks.

### Two loops, not one

`grep -c` the regex: it appears **twice**. The second copy lives *inside* the T-3096
transparent-wrapper loop (`safe-commands.sh:294`), which re-enters assignment
stripping after unwrapping `env`/`timeout`/`flock`. **Fixing only the first leaves
`env PATH=/tmp cat x` open** — and `env` is exactly the wrapper an agent reaches for
when setting an env var. Both must carry the denylist or the fix is cosmetic.

### Approach: name denylist, not name allowlist

A **name allowlist** (e.g. `FW_*` only) would be strictly safer. It is **not** taken
here because `tests/unit/safe_commands_env_prefix.bats` pins
`FOO=1 BAR=2 fw work-on T-X` as SAFE — a documented T-1908/L-399 contract. Changing
that test to fit the fix would be weakening a pinned contract to make my own change
pass, which is exactly what must not happen. The denylist preserves every pinned
contract and closes the measured hole.

**Residual risk, stated plainly:** a denylist is incomplete by construction. It
cannot cover a variable nobody has thought of. This is a genuine reduction, not a
proof of safety. The allowlist alternative is recorded as a Sovereign question
(§Sovereign) rather than decided here.

### Failure direction

Every failure mode of this change is toward BLOCKING — a denied prefix leaves `cmd`
untouched, so the base stays `PATH=/tmp`, which matches no case arm and gates. This
matches the idiom the file already states for the T-3096 wrapper loop. The change
**cannot** admit anything that was previously refused.

## Acceptance Criteria

### Agent
- [x] Denylist applied to **BOTH** assignment-stripping loops (the primary T-1908
      loop and the copy nested in the T-3096 wrapper loop) — verified by the
      `env`-wrapped case, not by reading the diff
      — *the duplication was REMOVED rather than the denylist pasted twice: one
      shared `_fw_strip_env_prefixes`, called from both sites. `grep BASH_REMATCH`
      now shows the strip regex exactly once (test 19 pins this)*
- [x] All four OBS-423 measured forms classify UNSAFE:
      `PATH=/tmp cat x`, `LD_PRELOAD=… cat x`, `BASH_ENV=… cat x`, `IFS=x cat y`
      — *tests 1-4; and end-to-end at the real hook, exit 2*
- [x] The wrapper-nested path `env PATH=/tmp cat x` classifies UNSAFE
      (this is the AC that distinguishes a real fix from a one-loop fix)
      — *test 5, plus `timeout 5 PATH=…` test 6; hook exit 2*
- [x] T-1908 / L-399 contract preserved — `FW_SWITCH_FOCUS=1 fw work-on T-X`,
      `FW_DEBUG=1 fw doctor`, `FOO=1 BAR=2 fw work-on T-X` all still SAFE
      — *tests 11-15; `safe_commands_env_prefix.bats` 10/10 green*
- [x] **Control leg**: the new test file fails against the UNFIXED implementation.
      Demonstrated by running the new tests against the pre-fix source, not asserted
      — ***13 of 19 fail against pre-fix; the 6 that pass are exactly the 5 CONTROL
      tests plus the GIT_DIR boundary test — all of which SHOULD pass in both
      states.*** Reproduce: `git show HEAD~1:agents/context/lib/safe-commands.sh >
      /tmp/old.sh && FW_SAFE_COMMANDS_SRC=/tmp/old.sh bats
      tests/unit/t3374_env_prefix_denylist.bats`
- [x] All five existing `safe_commands` bats suites green with **zero skips**
      (a skipped bats test reports `ok` — T-3217)
      — *48 + 21 + 10 + 31 + 12 = 122 tests, 0 failed, 0 skipped*
- [x] No existing test deleted, weakened, or modified — asserted by
      `git diff` over `tests/` showing only additions of new files
      — *`git status --short` over all five pinned suites returns empty*
- [x] Residual risk (denylist incompleteness) and the allowlist alternative recorded
      as a Sovereign question rather than silently decided — *§Sovereign Questions*

### Additional evidence gathered (beyond the ACs)

End-to-end at the real hook, in a scratch project with **no active task** (the only
state in which the allowlist is consulted at all — with a task active, every command
passes regardless, so an in-session probe proves nothing):

| command | hook exit |
|---|---|
| `fw doctor` | 0 — allowed *(control: not blocking everything)* |
| `cat README.md` | 0 — allowed *(control)* |
| `PATH=/tmp cat x` | **2 — BLOCKED** |
| `LD_PRELOAD=/tmp/e.so cat x` | **2 — BLOCKED** |
| `env PATH=/tmp cat x` | **2 — BLOCKED** *(second entry point)* |
| `FW_SWITCH_FOCUS=1 fw work-on T-1` | 0 — allowed *(L-399 contract intact)* |

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
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
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
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# Library still parses (a syntax error here disables the Tier-1 gate entirely).
bash -n agents/context/lib/safe-commands.sh

# New suite green AND fully run — the skip clause is not optional (T-3217).
timeout 300 bats tests/unit/t3374_env_prefix_denylist.bats > /tmp/.t3374.out 2>&1 && ! grep -q "^not ok" /tmp/.t3374.out
test "$(grep -c '# skip' /tmp/.t3374.out)" -eq 0

# The four measured OBS-423 forms are refused, and the T-1908 contract survives.
# Assertions last, single sub-shell so every clause counts (T-3203 safe shape B).
bash -c 'set -eo pipefail; source agents/context/lib/safe-commands.sh; ! is_bash_safe_command "PATH=/tmp cat x"; ! is_bash_safe_command "LD_PRELOAD=/tmp/e.so cat x"; ! is_bash_safe_command "BASH_ENV=/tmp/e.sh cat x"; ! is_bash_safe_command "IFS=x cat y"'
bash -c 'set -eo pipefail; source agents/context/lib/safe-commands.sh; ! is_bash_safe_command "env PATH=/tmp cat x"; is_bash_safe_command "FW_SWITCH_FOCUS=1 fw work-on T-1"; is_bash_safe_command "FOO=1 BAR=2 fw work-on T-1"; is_bash_safe_command "GIT_DIR=foo git status"'

# ONE strip implementation. Two copies of a security predicate is two chances to
# fix only one — which is the shape of the bug this task fixed.
test "$(grep -c '_fw_strip_env_prefixes "\$cmd"' agents/context/lib/safe-commands.sh)" -eq 2

# The five pre-existing suites still green and fully run (no skips).
timeout 600 bats tests/unit/safe_commands_env_prefix.bats tests/unit/safe_commands_chain.bats tests/unit/context_safe_commands.bats tests/unit/t3096_safe_commands_wrappers.bats tests/unit/test_safe_commands_git_commit.bats > /tmp/.t3374r.out 2>&1 && ! grep -q "^not ok" /tmp/.t3374r.out
test "$(grep -c '# skip' /tmp/.t3374r.out)" -eq 0

# None of those five pinned suites was modified to make this change pass.
test -z "$(git status --porcelain tests/unit/safe_commands_env_prefix.bats tests/unit/safe_commands_chain.bats tests/unit/context_safe_commands.bats tests/unit/t3096_safe_commands_wrappers.bats tests/unit/test_safe_commands_git_commit.bats)"

# Vendored path (agents/) — sync must be clean BEFORE close, not after (OBS-250).
#
# SCOPED DELIBERATELY, and this is not a softened check. The global
# `bin/fw vendor self --check` exits 1 right now, but the drift is entirely an
# uncommitted `bin/fw` belonging to ANOTHER task, which `fw vendor self`
# correctly WITHHELD ("vendoring it would ship another task's unfinished work to
# consumers under your commit"). Satisfying the global form would require either
# committing someone else's work-in-progress or FW_VENDOR_ALL=1 — which is the
# exact outcome the withhold exists to prevent. Anchoring a close on it is the
# mutable-corpus anti-pattern this template warns about (T-3326): red for reasons
# unrelated to the code under test.
#
# So assert what THIS task owns — the file it changed is byte-identical in the
# vendored tree. Filed as OBS-424. Re-derive the global state with
# `bin/fw vendor self --check` when the foreign bin/fw edit is resolved.
diff -q agents/context/lib/safe-commands.sh .agentic-framework/agents/context/lib/safe-commands.sh

## Sovereign Questions

Raised, **not** decided. Each changes the shape of the gate and is a scope call.

**S1 — Denylist or name allowlist?** This fix uses a *denylist* of
resolution-affecting variable names. A *name allowlist* (strip only `FW_*`, refuse
everything else) is strictly safer: it cannot be outflanked by a variable nobody
thought of, which a denylist can, by construction. It was not taken because
`tests/unit/safe_commands_env_prefix.bats` pins `FOO=1 BAR=2 fw work-on T-X` as
SAFE — a documented T-1908/L-399 contract — and rewriting that test so my own
change could pass is precisely the move that must not be made silently. Switching
to an allowlist means deliberately retiring that contract. **That is your call, not
mine.** The denylist is a genuine reduction of exposure, not a proof of safety, and
this task does not claim otherwise.

**S2 — Should the affix class get a standing rail rather than a sixth patch?**
This is the sixth recorded instance of "a positional token reader meets a prefix
nobody taught it about" (T-1908, T-2834, T-2988, T-3096, T-3344, now T-3374).
Five were false-BLOCKs; this one was the first false-ALLOW. The pattern is not
slowing down. A property-based or fuzz rail over `is_bash_safe_command` — assert
that no affix can turn a known-unsafe line safe — would catch the seventh before
it ships. That is a new piece of test infrastructure and a scope decision.

**S3 — Does a Tier-1 fail-open warrant a retro-audit of the bypass log?** The hole
existed since T-1908. Whether anything actually traversed it is answerable from
`.context/working/.gate-bypass-log.yaml` and session transcripts, but that is an
audit of past agent behaviour, which is a governance action with its own weight.
Not started. No evidence of exploitation was sought or found; the absence of a
search is not evidence of absence.

## RCA

**Symptom:** `is_bash_safe_command` returned SAFE for `PATH=/tmp cat x`,
`LD_PRELOAD=… cat x`, `BASH_ENV=… cat x` and `IFS=x cat y`. With no active task,
the Tier-1 gate admitted these on the read-only fast path.

**Root cause:** the T-1908 stripper removed the prefix *before* the classifier read
the base command, and the classifier's entire verdict is computed from that base.
For this family of variables the discarded prefix is what decides what the base
name resolves to — so the gate answered a question about a token whose meaning it
had already thrown away. Not "the denylist was incomplete": `grep` for these names
returned **no matches at all**. The category was never represented.

**Why structurally allowed:** the stripper was introduced (T-1908) to fix a
*usability* defect — the L-399 `FW_SWITCH_FOCUS=1` bypass being blocked by its own
gate. It was scoped to "make the base command readable", and every subsequent
instance of the affix class (T-2834 whitespace, T-2988 grouping, T-3096 wrappers,
T-3344 redirects) was likewise motivated by a false BLOCK. Five consecutive fixes
pushed in the permissive direction, each correct in isolation. Nothing in that
sequence ever asked whether an affix could also make a verdict *wrong in the other
direction* — so the safety question was never put, and its absence looked like a
settled answer. The T-3096 comment even states "every failure direction here is
toward BLOCKING", which was true of that loop and taken as true of the function.

**Why it stayed invisible:** a fail-open in a classifier produces no symptom.
A false BLOCK generates an immediate complaint from the agent it stops (which is
precisely how the other five were found); a false ALLOW generates silence. The
detection asymmetry, not the code, is why this one was sixth.

**Prevention** (distinct from the fix):
1. `tests/unit/t3374_env_prefix_denylist.bats` — 19 tests, demonstrated to fail
   13-of-19 against the pre-fix source, so it pins the behaviour rather than
   describing it.
2. Test 19 asserts the strip regex appears **exactly once** in the library. The
   duplicated copy inside the wrapper loop is what made `env PATH=…` a second,
   separate bypass; the structural assertion stops a future edit re-introducing a
   second copy that only one fix reaches.
3. Predicate-level tests (`_fw_env_prefix_is_denied`) with an explicit
   `declare -F` existence check, so a missing implementation fails loudly instead
   of reading as "allowed" — a vacuous-pass this task's own control leg caught.

## RCA notes (template guidance retained below)

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

### 2026-09-16T17:40:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3374-fix-obs-423-fail-open-safe-commands-env-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-71408866
- **Timestamp:** 2026-09-16T17:52:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-16T17:52:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
