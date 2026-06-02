---
id: T-1838
name: "fw doctor asymmetric version-skew detection — distinguish consumer-behind from consumer-ahead-of-framework (T-1828 surfaces)"
description: >
  fw doctor warns 'v$cversion → v$FW_VERSION, Run: fw upgrade $consumer_dir' whenever consumer pinned version != framework version. When the framework's VERSION counter has been rolled back (T-1828 scenario), consumers are AHEAD of framework (e.g. termlink at 1.6.260, framework at 1.6.170). The doctor's remediation suggests running fw upgrade — which would overwrite consumer's higher pinned version with the framework's lower one (silent downgrade). Fix: bin/fw:1498 should distinguish consumer-behind from consumer-ahead via semver-style comparison. For consumer-ahead, emit a different warning class explaining the framework is behind and pointing at T-1828 for context; DO NOT advise fw upgrade. Surfaces as consumer-fw-upgrade-flow issue (the user's standing directive).

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [consumer-fleet, fw-doctor]
components: [bin/fw, tests/unit/test_doctor_consumer_version_ahead.bats]
related_tasks: [T-1828, T-1542, T-1834]
arc_id: project-shape-resilience
created: 2026-05-14T21:33:14Z
last_update: 2026-05-14T21:51:02Z
date_finished: 2026-05-14T21:51:02Z
---

# T-1838: fw doctor asymmetric version-skew detection — distinguish consumer-behind from consumer-ahead-of-framework (T-1828 surfaces)

## Context

`bin/fw:1498` flags `version_ok=false` whenever consumer's pinned version differs from `FW_VERSION` — direction-blind. The doctor warning text `v$cversion → v$FW_VERSION, Run: fw upgrade $consumer_dir` reads correctly when consumer < framework but is destructive guidance when consumer > framework: `fw upgrade` would overwrite the consumer's higher pinned version with the framework's lower value (silent downgrade).

The consumer-ahead case is real today as a Layer 3 surface of T-1828: framework's `VERSION` counter rolled back from 1.6.260 to 1.6.170 (tag-counter reset), so all consumers that had been upgraded against the rolled-back portion of history now appear "ahead" (995_2021-kosten / openclaw-evaluation / 3021-Bilderkarte-tool-llm at 1.6.252, termlink at 1.6.260). `fw doctor` on this anchor currently invites the operator to downgrade four real consumers.

Fix scope: introduce `version_relation` (match | behind | ahead) via `sort -V` comparison; route the "ahead" branch to a different warning class that names T-1828 and explicitly tells the operator NOT to run `fw upgrade` until the framework catches up.

## Acceptance Criteria

### Agent
- [x] `bin/fw` consumer fleet block (lines ~1494-1551) computes `version_relation` (match/behind/ahead) via `sort -V` comparison of `$cversion` and `$FW_VERSION`
- [x] Consumer-behind branch preserves existing behaviour: WARN with `v$cversion → v$FW_VERSION` reasons + `Run: fw upgrade $consumer_dir`
- [x] Consumer-ahead branch emits a distinct WARN reading `v$cversion is AHEAD of framework v$FW_VERSION` and the remediation line tells the operator NOT to run `fw upgrade` (would downgrade) and references T-1828
- [x] Hooks-missing check still surfaces independently of the version axis (a consumer-ahead with missing hooks must still report the missing hooks; the warning must not advise upgrade)
- [x] Bats regression test `tests/unit/test_doctor_consumer_version_ahead.bats` covers (a) consumer-behind keeps "fw upgrade" suggestion, (b) consumer-ahead suppresses "fw upgrade" suggestion and mentions T-1828, (c) match case stays OK — 9/9 pass
- [x] `bash -n bin/fw` parses clean post-edit

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

bash -n bin/fw
test -f tests/unit/test_doctor_consumer_version_ahead.bats
# Capture bats output first to avoid SIGPIPE from `grep -q` short-circuit under pipefail
bats tests/unit/test_doctor_consumer_version_ahead.bats > /tmp/t1838-bats.out 2>&1 && grep -qE "^ok 3 |^ok 4 " /tmp/t1838-bats.out
grep -q "version_relation" bin/fw
grep -q "AHEAD of framework\|is AHEAD" bin/fw

## RCA

**Symptom:** `fw doctor` on the framework anchor reports 4 consumers as "WARN ... Run: fw upgrade $consumer_dir" — but those consumers are at higher pinned versions (1.6.252 / 1.6.260) than the framework's current VERSION (1.6.170). Running the suggested command would silently downgrade them.

**Root cause:** `bin/fw:1498` performs direction-blind inequality check (`"$cversion" != "$FW_VERSION"`) and the warning emitter (1539-1548) issues a single remediation template ("Run: fw upgrade $consumer_dir") for the whole `version_ok=false` branch. The code was written when consumer-behind was the only physically reachable case; it predated T-1603's monotonicity-hook scenario where the framework's VERSION can be rolled back.

**Why structurally allowed:** No test pinned consumer-ahead semantics. The fresh-machine simulation `upgrade_fresh_machine_simulation.bats` covers consumer-from-clean-init (consumer behind / unpinned) but not the consumer-ahead path. The doctor warning text is templated, not asserted against any fixture. The version-comparison helper (none — direct string `!=`) doesn't carry direction.

**Prevention:** New bats fixture `test_doctor_consumer_version_ahead.bats` pins the three-case matrix (match / behind / ahead). The ahead case asserts (a) WARN fires, (b) "fw upgrade $consumer_dir" remediation does NOT appear, (c) T-1828 is named. This locks the asymmetric remediation and catches the next regression (e.g. accidental return to symmetric template).

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

### 2026-05-14 — scope of the surface widened from 4 → 12 consumers

- **What changed:** Filing referenced the 3 consumers visible in the prior session's doctor snippet (995_2021-kosten, openclaw-evaluation, termlink) plus 3021-Bilderkarte-tool-llm. Running `fw doctor` against this anchor today shows the ahead-of-framework state hits 12 consumers (001-sprechloop, 002-Claude-Partner-Network, 025-WokrshopDesigner, 050-email-archive, 051-Vinix24, 052-KCP, 053-ntfy, 150-skills-manager, 3021-Bilderkarte-tool-llm, 995_2021-kosten, openclaw-evaluation, termlink). The T-1828 VERSION rollback is fleet-wide, not localized.
- **Plan impact:** Fix scope unchanged (still local to `bin/fw:1497-1565`), but the blast radius of the pre-fix bug was 3× what the filing description implied. Reinforces the "ahead branch must be loud" call — silently downgrading 12 consumers across a fleet is a worse outcome than this task originally framed.
- **Triggered:** No new sub-task; the fleet-scope observation is captured here and in the Update entry for future debugging if a similar VERSION rollback recurs.

### 2026-05-14 — bats | grep -q under pipefail = SIGPIPE-141

- **What changed:** Initial `## Verification` command `bats … | grep -qE "^ok 3|^ok 4"` failed with exit 141 (SIGPIPE) even when the pattern matched — because `grep -q` exits on first match and closes stdin while `bats` is still writing, and the framework gate runs verification under `set -eo pipefail` which propagates the SIGPIPE as a failure.
- **Plan impact:** None for the source fix; only the verification step was affected. But this is a generally-applicable pattern: anywhere a long-output producer is piped to `grep -q`, the verification gate will SIGPIPE-141 if the producer hasn't finished by the time grep matches.
- **Triggered:** Verification command rewritten to capture bats output to `/tmp/t1838-bats.out` first, then `grep -q` on the file. A future learning entry (L-XXX) could codify "never pipe to `grep -q` in `## Verification` under pipefail" — flagging here for the next time this surfaces.

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

### 2026-05-14T21:33:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1838-fw-doctor-asymmetric-version-skew-detect.md
- **Context:** Initial task creation

### 2026-05-14 — fix shipped + bats coverage + live verification
- **Action:** Edited `bin/fw:1497-1513` to compute `version_relation` via `sort -V`; edited the warning emitter at lines ~1538-1565 to route consumer-ahead to a distinct WARN/remediation pair (no `fw upgrade` advice; explicit downgrade warning; T-1828 cross-reference). Added `tests/unit/test_doctor_consumer_version_ahead.bats` (9 tests).
- **Output:** `bin/fw` (+19 LOC), `tests/unit/test_doctor_consumer_version_ahead.bats` (new, 9/9 pass)
- **Context:** 12 consumers on this anchor previously received "Run: fw upgrade ..." advice that would have silently downgraded them (1.6.252/1.6.260 → 1.6.170). Live `fw doctor` after the fix prints the asymmetric warning + "DO NOT run fw upgrade" for all 12 plus T-1828 cross-reference.

## Recommendation

**Recommendation:** GO

**Rationale:** Direction-blind version check at `bin/fw:1498` was telling operators across 12 real consumer projects to run a command that would silently downgrade their pinned framework version. Fix is local (~20 LOC), reversible, and bats-pinned. The new ahead branch names T-1828 inline so the next operator who hits this state on a different anchor lands on the explanation rather than blindly running the broken suggestion. Behind branch is byte-identical for the user-facing text — no regression risk for the only previously-tested case.

**Evidence:**
- `bin/fw:1497-1513`: `version_relation` computed via `sort -V` (ahead / behind / match)
- `bin/fw:1546-1565`: ahead branch emits "is AHEAD of framework", "DO NOT run `fw upgrade ...`", and "see T-1828"; behind branch keeps the original "Run: fw upgrade $consumer_dir" advice
- `tests/unit/test_doctor_consumer_version_ahead.bats`: 9/9 pass (source pins + behavioural sort -V check on real-world inputs 1.6.260 vs 1.6.170)
- Live verification: `bin/fw doctor` against this anchor now prints the asymmetric warning for all 12 ahead-of-framework consumers (transcript captured in Update entry above)
- No source files outside `bin/fw` touched; no behavioural change for consumer-behind or version-match cases

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b3a6634a
- **Timestamp:** 2026-06-02T14:59:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-14T21:51:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
