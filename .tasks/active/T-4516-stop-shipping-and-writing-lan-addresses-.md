---
id: T-4516
name: "Stop shipping and writing LAN addresses (192.168.x.y) in framework files and
  in what fw writes into consumer repos"
description: >
  832 msg 0a8bbfa1: 832's operator ruled to scrub LAN addresses from tracked files
  because their GitHub mirror is public (their T-1239). AEF's vendored tree carries
  them in about 134 files (docs mostly, some lib/web/tools/policy, e.g. policy/designer-pin.yaml
  source_origin), and handovers and task updates written into consumer repos contain
  Watchtower URLs with LAN addresses. Inventory the shipped files, replace addresses
  with placeholders or resolved-at-runtime values, make generated Watchtower URLs
  in consumer-written files host-neutral (or opt-in), and add a lint that refuses
  new RFC1918 addresses in shipped paths. The same applies to AEF's own public mirror.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
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
created: 2026-10-20T20:40:28Z
last_update: 2026-10-20T20:54:50Z
date_finished:
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
  - ts: '2026-10-20T20:45:37Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=294,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-20T20:46:40Z'
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

# T-4516: Stop shipping and writing LAN addresses (192.168.x.y) in framework files and in what fw writes into consumer repos

## Context

Inventory and dispositions: `docs/reports/T-4516-lan-address-inventory.md` (134 files /
390 occurrences at HEAD 3b3fc30d5; 114 are records — docs/reports, docs/research — kept and
allowlisted by path). Lint: `tools/lan-address-lint.py` + `policy/lan-address-allowlist.yaml`;
enforced through the unit suite by `tests/unit/test_lan_address_lint.py::test_real_tree_is_clean`
(not wired into `agents/audit/audit.sh` here: another worker had uncommitted edits in it).
Step 3 (consumer-written Watchtower URLs) needs an operator decision — options under
`## Recommendation`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Inventory written: `docs/reports/T-4516-lan-address-inventory.md` lists every tracked file in shipped paths (lib, agents, bin, web, policy, tools, docs, templates, .tasks/templates) holding an RFC1918 address, grouped by kind, with a count per path
- [x] Shipped code/config/docs carry no RFC1918 address outside the allowlist (placeholders or runtime-resolved values); historical records (tasks, episodic, handovers, reports) untouched
- [x] Lint `tools/lan-address-lint.py` exits 1 on a new RFC1918 address in a shipped path, 0 on a clean tree, and honours an allowlist file (`policy/lan-address-allowlist.yaml`) where every entry carries a reason
- [x] Regression tests `tests/unit/test_lan_address_lint.py` cover: detection of 10/8, 172.16/12, 192.168/16; non-detection of public / out-of-range addresses (172.32.x, 192.169.x, version strings); allowlist suppression; scope limited to shipped paths
- [x] Consumer-written Watchtower URLs (step 3): either made host-neutral, or the options written into `## Recommendation` for an operator decision if it changes what links look like

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
- [ ] [REVIEW] The two rendered strings that lost their LAN address still read right and work
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` — open that URL plus `/settings/` (or look at `.context/visual/T-4516/settings@{1024,1440,1920}.png`)
  2. Under "Ollama Host", read the help line below the input
  3. Open the same URL plus `/static/ux-review/index.html` (or `.context/visual/T-4516/uxreview@*.png`); in the third line ("Overall: PASS · … · live page: /settings/appearance") click the `/settings/appearance` link
  **Expected:** step 2 shows "Full URL including protocol and port (e.g. http://ollama-host:11434)" on one line, nothing clipped, and the example reads as a placeholder, not a real host; step 3's link opens the Appearance settings page on whichever host you are browsing (it is now relative, so it follows the host instead of pointing at 192.168.10.107)
  **If not:** note the width/browser and what you saw on this task; the strings are `web/templates/settings.html:33` and `web/static/ux-review/index.html:12`

<!--
  Render-touching build tasks (web/templates, web/static, web/blueprints, web/shared.py,
  web/app.py …) add a section headed "Visual Verification" (level-2 heading) after
  Verification, with one checklist table — the check-visual-verification gate reads it
  at commit time (T-4213; T-4202 GO):

    | state | control | 1024 | 1440 | 1920 | note |
    |-------|---------|------|------|------|------|
    | toolbar | Load | ok | ok | ok | |

  Cells: ok / clipped / hidden / overlap / unreachable (non-ok needs a note). Each
  listed state needs screenshots at every UX_SHOT_WIDTHS width:
  fw ux shots <T-ID> <state>=<URL>. This comment is inert: the gate ignores it.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
# Build/refactor/decommission tasks with NO command here are refused. If nothing can be
# run, add the line `# verification: none — <why nothing can be run>`; it is serviced
# (queued for review: add a check / other evidence / accept). See docs/reports/T-4024-servicing-loop.md.
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
#
# Vendored-path hint (T-3236, T-4419): if you edited bin/fw, lib/, agents/, policy/,
# web/, tools/ or .tasks/templates/, run `bin/fw vendor self` and add
#     bin/fw vendor self --check --task T-XXXX
# (your own task id). It checks only the files your commits changed, so another
# worker's uncommitted edit does not block your close; that drift is listed as
# "in flight, not this task". The whole-tree `--check` stays for audit/pre-push.
python3 tools/lan-address-lint.py
python3 -m pytest tests/unit/test_lan_address_lint.py -q > /tmp/.t4516-py.out 2>&1 && grep -q passed /tmp/.t4516-py.out
test -s docs/reports/T-4516-lan-address-inventory.md && grep -q '^\*\*Total:\*\*' docs/reports/T-4516-lan-address-inventory.md
! grep -qE '192\.168\.[0-9]+\.[0-9]+:11434' bin/fw tools/t1700-ollama-harness.sh tools/t1703-probe-matrix.sh tools/t1704-hermes3-probe.sh tools/t1706-tool-loop-probe.sh
timeout 300 bats -f "ollama reachable check" tests/unit/test_doctor_litellm_ollama.bats > /tmp/.t4516-bats.out 2>&1 && ! grep -q "^not ok" /tmp/.t4516-bats.out
bin/fw vendor self --check --task T-4516
bin/fw watchtower current

## Visual Verification

Shots (2026-10-21, live Watchtower restarted at 02:0x so it serves current `web/`, `bin/fw watchtower current` → current): `bin/fw ux shots T-4516 "settings=http://192.168.10.107:3000/settings/" "uxreview=http://192.168.10.107:3000/static/ux-review/index.html"`. Measured with Playwright at each width: document scrollWidth equals viewport width (1024/1440/1920) on both pages; `#ollama-host-help` scrollWidth = clientWidth (918/1168/1418 px), one line, visible; the ux-review `/settings/appearance` link is visible (x 589-749 at 1024) and the route answers 200. `web/blueprints/tasks.py` changed a code comment only, so it has no rendered state.

| state | control | 1024 | 1440 | 1920 | note |
|-------|---------|------|------|------|------|
| settings | Ollama Host help text | ok | ok | ok | reads "e.g. http://ollama-host:11434"; the input above it shows this host's saved setting (runtime value, not shipped) |
| settings | rest of LLM Engine card | ok | ok | ok | unchanged by this task |
| uxreview | "live page: /settings/appearance" link | ok | ok | ok | now relative; resolves against the host being browsed |
| uxreview | header + preset cards | ok | ok | ok | unchanged by this task |

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

**Symptom:** the vendored tree and the public mirror carry the operator's LAN addresses
(134 shipped files at HEAD 3b3fc30d5); consumer handovers carry LAN Watchtower URLs.
832 flagged it after scrubbing their own (msg 0a8bbfa1, their T-1239).

**Root cause:** host-specific values were written as literals where a runtime value or a
placeholder belonged. Live code: `bin/fw` doctor Ollama probe hard-coded the GPU host
(pre-fix bin/fw:4058-4065), as did the four `tools/t17xx` probes; examples and help text
(lib/pending.sh:50, lib/templates/scripts/agent-conversation-*.sh, lib/templates/skills/*,
web/templates/settings.html:33, web/static/ux-review/index.html:12, policy/anti-patterns.yaml:540,
docs/deployment-runbook.md) copied real addresses instead of placeholders. Generated:
`agents/handover/handover.sh:383,1012,1338` writes `$WT_URL/review/T-X`, and `WT_URL`
resolves to the LAN Watchtower URL (handover.sh:43).

**Why structurally allowed:** nothing scanned shipped paths for private addresses. Every
existing URL rule (T-1376 port-3000 gate, `lib/verification-port.sh`) targets the *port*,
inside task Verification blocks only; an address in code, docs or policy was invisible.

**Prevention:** `tools/lan-address-lint.py` (RFC1918 matcher, shipped-path scope,
reasoned allowlist) and `tests/unit/test_lan_address_lint.py::test_real_tree_is_clean`,
which turns the unit suite — and hence the unit-suite audit (T-3621) — red on any new
address. Records are exempt by explicit allowlist entry, not by silent scope.

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

**Recommendation:** GO — steps 1, 2, 4 shipped; step 3 needs your choice (recommend option B).
**Rationale:** Shipped code/config/docs are clean and a lint keeps them clean. Step 3 changes
what handover links look like, so it is held for a decision. Two items stay open: the
consumer-written URLs (below) and `policy/designer-pin.yaml` `source_origin` (allowlisted
because `fw designer sync --from-tag` pulls from it; move it to a DNS name or local config
if you want it out of the mirror).
**Evidence:**
- `python3 tools/lan-address-lint.py` → clean; with an empty allowlist the only hits are docs/reports, docs/research, designer-pin
- `tests/unit/test_lan_address_lint.py` 17 passed; `test_doctor_litellm_ollama.bats` 6/6 ok (incl. full `fw doctor`)
- Render surfaces (`/settings/` help text, ux-review `/settings/appearance` link): screenshots `.context/visual/T-4516/{settings,uxreview}@{1024,1440,1920}.png`, no horizontal overflow at any width (Playwright), link answers 200 — see `## Visual Verification`; the [REVIEW] Human AC asks you to confirm they read right

**Step 3 options — Watchtower URLs that `agents/handover/handover.sh` (lines 383, 1012, 1338) writes into `.context/handovers/*.md`:**
1. **A — relative links** (`[T-X](/review/T-X)`). Host-neutral and zero config; links stop being clickable in a terminal, GitHub or an editor (they only resolve inside Watchtower's own file viewer).
2. **B — public-base opt-in (recommended).** New config key (e.g. `WATCHTOWER_PUBLIC_URL`, `fw config set`); when set, handovers use it (a DNS name such as the Traefik FQDN); when unset, handovers write the plain bold ID plus one line "open with `fw task review T-X`". Chat output (`fw task review`, which is not written to a file) keeps the live LAN URL, so your clickable links in chat are unchanged.
3. **C — keep absolute, scrub at commit.** Handovers keep LAN URLs locally; a pre-commit filter rewrites them to relative. Least visible change, but the file on disk and the committed file differ, which is a new class of surprise.
4. **D — status quo + allowlist `.context/handovers`.** Accept the leak in consumer repos; document it. Not recommended: it is the leak 832 reported.

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

### 2026-10-20T20:40:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4516-stop-shipping-and-writing-lan-addresses-.md
- **Context:** Initial task creation

### 2026-10-20T20:54:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
