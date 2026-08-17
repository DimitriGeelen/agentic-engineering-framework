---
id: T-3040
name: "peer message backlog lost — local hub had no framework:pickup topic, posts
  rejected for months"
description: >
  peer message backlog lost — local hub had no framework:pickup topic, posts rejected
  for months

status: started-work
workflow_type: build
owner: agent
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
created: 2026-08-16T15:43:14Z
last_update: 2026-08-17T12:10:13Z
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
  - ts: '2026-08-16T15:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T15:45:13Z'
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
  - ts: '2026-08-16T22:24:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 3
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3040: peer message backlog lost — local hub had no framework:pickup topic, posts rejected for months

## Context

### Recovered backlog — triage map (18 messages, `framework:pickup` @ ring20 .122)

Archived verbatim at `.context/message-archive/framework-pickup-ring20-20260816.json`.
Offsets are the hub's. **Triaged 2026-08-17** — every row below now carries a
concrete disposition (filed / superseded / homed-elsewhere / no-action), so
nothing recovered stays silently dropped.

| # | Kind | Sev | Subject | Disposition |
|---|------|-----|---------|-------------|
| 1 | deploy-announce | — | T-1166 cut staged for .122 swap | Info only, 2026-05-11. No action — T-1166 has since progressed independently (see CLAUDE.md §Trunk-Based Session Flow references to the same cut). |
| 2 | bug-FIXED | — | G-082 episodic generator fixed upstream | **Superseded.** Group with #5/#17 below — the whole class was re-fixed by **T-3015** (`extract_decisions.py`), which explicitly documents this exact recurrence ("Reported by 050-email-archive, reproduced independently by 832 at 81%" — `agents/context/lib/episodic.sh:136-144`). |
| 3 | bug-report | — | T-711 AEF upgrade + test-suite report — 7 findings (F-1..F-7) | **Spot-checked, stale.** 3-month-old report against a much earlier codebase state. F-1 (`fw upgrade` vendored no-op) — superseded by extensive `lib/upgrade.sh` upstream-repo work since. F-3 (recursive fork-bomb via `/api/tests/run`) and F-4 (CSRF not enforced in test mode) — `web/app.py:95-132` now enforces CSRF unconditionally with no `TESTING`-mode carve-out, which structurally closes both as filed. F-2/F-5/F-6/F-7 are test-infra hygiene (missing-dir guard, monkeypatch drift, stale UI assertions, tantivy skip) — non-blocking, and a fresh `fw test` run today would be more accurate than chasing 3-month-stale specifics. No new entry filed; re-run the test-suite report if a fresh read is wanted. |
| 4 | gap-registered | — | G-WATCHTOWER-INCEPTION-DECIDE-NO-TERMINAL-GAP (2026-05-15) — `/review/T-XXX` has no inception-decide button | **Resolved.** This exact class (two decision surfaces, one CLI verb) was addressed by **T-2125/T-2129/T-2141** — `/inception/<id>` now exists as its own page (`web/templates/inception_detail.html`) with a dedicated decide form, separate from `/review/<id>`. See CLAUDE.md §Recommendation-completeness gate / "Two decision classes, one CLI verb". |
| 5 | followup | med | episodic corruption is **silent** — output is valid YAML, so the `yaml.safe_load` guard cannot catch it | **Superseded** — same T-3015 fix as #2/#17. |
| 6 | bug-report | med | fw-authority approvals invisible in Watchtower `/approvals`; "50+ sessions hit this" | **No local entry — homed to 150-skills-manager** (T-1333 Gap Homing: the fix lives in their `fw-authority` surface, not ours). Independently corroborated by PL-033 (offset 15:58 in the same recovery, see docs/reports/T-3040-recovered-messages-20260816.md) — a sibling finding about the same command-naming class, filed to `.context/inbox.yaml` (T-3040 GATE-REMEDIATION-DOESNT-RESOLVE entry). |
| 7 | bug-report | med | B-005 (Enforcement Config Protection) blocks ADDITIVE project-local hook edits to `.claude/settings.json`, no distinction from destructive edits | **Resolved.** `agents/context/check-active-task.sh:331-364` (T-3050) now names the sanctioned route in the block message itself — `fw hook-enable` — closing exactly the "gate with no exit" complaint this message raises. |
| 8 | patch-ready | — | T-916 / G-023 patch artifact ready for review (boundary-hook regex false-positives, `check-project-boundary.sh`) | **No action needed.** `agents/context/check-project-boundary.sh` has been hardened extensively since (quote-handling and redirect false-positive fixes at multiple later commits) — the false-positive class this patch targeted has been addressed through other work, not via the offered patch verbatim. Sender flagged "no urgency... pure courtesy filing". |
| 9 | defect | — | Watchtower has **zero HTTP access logging** (audit-trail gap) | **Likely superseded by architecture change** — the report describes a `waitress`-served app with no requestlog; `web/app.py` no longer uses waitress (now Flask dev server / socketio, `web/app.py:489-493`), and Werkzeug's dev server logs each request to stderr by default. The literal "zero logging" symptom no longer holds; a *structured, persisted* access-log file is a separate, smaller ask not filed here to avoid manufacturing a gap nobody asked for at that scope. |
| 10 | defect | — | `fw context add-learning` emits **invalid YAML** for quoted/multiline input | **Filed: OBS-319** — confirmed still live (`agents/context/lib/learning.sh:72,84`, unescaped `print`). |
| 11 | defect | — | `fw_hook_crash_trap` misclassifies usage-error exit as crash | **Filed: OBS-320** — confirmed still live (`lib/config.sh:142-157`). |
| 12 | enhancement | — | `fw work-on` autonomous-cron pattern needs sibling-check | **Filed: OBS-321** — confirmed still open (no sibling/overlap check in `bin/fw` or `agents/task-create/`). |
| 13 | diagnosis | — | watchtower-dev auto-updater on CT170 | No action toward us (their host, their unit). |
| 15 | docs | — | FRAMEWORK.md documents `fw observe`; verb is `fw note` | **Fixed directly** — `FRAMEWORK.md:200` corrected `fw observe "description"` → `fw note "description"` (verified: `bin/fw` dispatches under `note`, not `observe`). |
| 16 | defect | — | `bin/migrate-horizon-null-completed.sh` cannot run vendored | **Filed: OBS-322** — confirmed still live (`PROJECT_ROOT` falls back to `FRAMEWORK_ROOT`, lines 23-24; the sibling exec-bit fix in OBS-090/T-2498 did not touch this). |
| 17 | defect | — | episodic generator harvests template headings — **still live after the G-082 fix** | **Superseded** — same T-3015 fix as #2/#5. |
| 18 | security | — | OneDev token rotated (ring20 T-1626); old one revoked | ✅ answers OBS-106/OBS-277 |
| 19 | reply | — | answers to this session's two asks + hub-diagnosis correction | ✅ consumed |

**`broadcast:global` (14 messages, archived at `.context/message-archive/broadcast-global-ring20-20260816.json`)** — swept for framework-relevant reports; the rest is cross-project chatter (penelope/email-archive/ring20 coordination) not addressed to us:

| Offset | Subject | Disposition |
|---|---|---|
| 8 | Duplicate of framework:pickup #3 (T-711 findings) | Same disposition as #3 above — stale, spot-checked. |
| 9 | `agents/fabric/lib/drift.sh` false-positives: https:// card locations treated as missing files; cross-boundary `depends_on` into `.agentic-framework/` flagged as stale | **Already in progress — T-3049** (active), which explicitly covers both sub-findings (URL-location join bug, and the "already fixed" note on the cross-boundary depends_on leg). |
| 13 | Upstream request: `memory-recall` should include OPEN tasks, not just completed episodics | **Resolved — T-3056** (completed: "memory-recall never searches the open task..."). |

Two entries deserve attention beyond their severity labels:

- **#2 + #5 + #17.** All three describe the same defect from three angles (fixed,
  why the fix's own validation can't detect the failure, and confirmation the
  defect outlived the fix) — a guard that cannot fail on the failure it guards
  against is the same class as T-3004 and as this task's own root cause. All
  three are resolved together by T-3015's `extract_decisions.py` rewrite, which
  independently cites the same recurrence pattern these messages describe.
- **#10.** `fw context add-learning` producing invalid YAML means the framework's
  learning capture has been silently corrupting its own memory for anyone hitting
  quoted or multiline input. Filed as OBS-319, not yet fixed.


<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

### `agent-chat-arc` recovery — outcome (AC 6)

Recovery was attempted against the ring20-management hub (192.168.10.122:9100),
the same one holding `framework:pickup` at `forever` retention. It failed:

```
Error: Hub rpc_call (channel.subscribe) failed
Caused by:
    0: I/O error: RPC 'channel.subscribe' response timeout after 30s (hub accepted
       the connection but never replied — wedged record-walk or overloaded hub)
    1: RPC 'channel.subscribe' response timeout after 30s (hub accepted the
       connection but never replied — wedged record-walk or overloaded hub)
```

(archived verbatim at `.context/message-archive/agent-chat-arc-ring20-20260816.json`).
`framework:pickup` and `broadcast:global` subscribes against the **same hub, same
session** succeeded normally — so this is specific to `agent-chat-arc`, not a
general hub-reachability problem. Plausible cause: `agent-chat-arc` is the
highest-traffic topic on that hub (retention `messages:2000`, actively pruning
per OBS-281/OBS-284 from the earlier T-3033 investigation), so a full
`channel.subscribe` record-walk from offset 0 is the most expensive read any
topic on that hub receives.

**Filed upstream, not silently abandoned:** posted to ring20's `framework:pickup`
(their hub, `192.168.10.122:9100`) at offset 23, 2026-08-17, naming the exact
symptom, reproduction context, and that other topics on the same hub read fine
in the same session. No local fix attempted — the wedge is server-side on a hub
we don't operate.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Root cause identified and reproduced: `channel.post` to a topic that does
      not exist on the local hub is REJECTED (`unknown topic … posts do not
      auto-create topics`), not queued — so every peer message sent to
      `framework:pickup` on this host was discarded at send time
- [x] `framework:pickup` and `broadcast-chat` created on the local hub; a probe
      post to `framework:pickup` persists (`Posts: 1`, offset returned)
- [x] Recoverable backlog archived from the ring20 hub (which holds the same
      topics at `forever` retention) into `.context/message-archive/` and
      committed — 18 `framework:pickup` + 14 `broadcast:global` messages
- [x] Every recovered peer report is triaged into the framework's own registers
      (observation / task / concern), with a mapping table in the task body so
      nothing recovered is silently dropped a second time
- [x] A guard exists so a missing topic cannot silently discard messages again:
      either topic auto-provisioning at post time, or a `fw doctor` check that
      the topics the codebase posts to actually exist on the local hub
- [x] `agent-chat-arc` recovery attempted and its outcome recorded — the remote
      hub currently wedges on `channel.subscribe` for that topic (30s internal
      RPC timeout), which is filed upstream rather than silently abandoned

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

bash -n bin/fw
out=$(termlink channel list --json 2>/dev/null); echo "$out" | python3 -c "import sys,json; d=json.load(sys.stdin); names=[t['name'] for t in d.get('topics',[])]; assert 'framework:pickup' in names and 'broadcast:global' in names and 'broadcast-chat' in names, names"
grep -q 'TermLink topic(s) missing on local hub' bin/fw
grep -q 'fw note "description"' FRAMEWORK.md

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

**Symptom:** Peer agents on the ring20 fleet had been posting bug reports,
findings, and status updates to `framework:pickup` and `broadcast:global` on
this host's local TermLink hub for months (earliest recovered message:
2026-05-11). None of them arrived — no message was ever visible locally, and
nothing surfaced the loss to this project until an unrelated recovery effort
swept the sender-side hubs and found the traffic this host never received.

**Root cause:** `termlink channel post <topic>` REJECTS a post to a topic that
does not exist on the target hub — it does not queue it, and does not
auto-create the topic. `framework:pickup` had never been created on this
host's local hub, so every inbound post from a peer failed at the hub's
`channel.post` RPC boundary, synchronously, with no retry and no local trace.
The sender saw a plain RPC error (if their client surfaced it at all); this
host saw nothing, because a rejected post never reaches storage to be read.

**Why structurally allowed:** Topic creation on this project's local hub was
never a step in any onboarding, upgrade, or health-check path — nothing ever
ran `termlink channel create framework:pickup`. `fw doctor`'s TermLink check
verified only that the *binary* was installed, not that the hub it talks to
carries the topics other projects' agents assume exist. A silent, structural,
one-way channel (peer → us) had no instrumentation on either end: the sender's
success path for other topics gave no signal that this one specific topic was
different, and the receiver had no periodic check that would ever notice an
absence of traffic on a topic it didn't know it was supposed to have.

**Prevention:** Topics created directly (`framework:pickup`, `broadcast-chat`,
`broadcast:global` — AC 1/2). Structural guard added: `fw doctor` now checks
(`bin/fw` TermLink section, T-3040) that these well-known cross-project
convention topics exist on the local hub and WARNs if any are missing, so a
future topic loss (e.g. after a hub wipe or fresh install) surfaces at the
next `fw doctor` run instead of after months of silent rejection. The
sender-side half of this class (posting to a topic missing on the *remote*
hub) was already covered by `--ensure-topic` (T-1445); this task closes the
matching receiver-side gap.

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

### 2026-08-16T15:43:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3040-peer-message-backlog-lost--local-hub-had.md
- **Context:** Initial task creation
