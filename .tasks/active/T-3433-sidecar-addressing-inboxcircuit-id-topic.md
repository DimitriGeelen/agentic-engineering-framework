---
id: T-3433
name: "sidecar addressing: inbox:<circuit-id> topics (project-level durable + agent-level
  exact), sender circuit in metadata, sidecar:* read alias; e2e re-proven (OBS-453
  ruling)"
description: >
  sidecar addressing: inbox:<circuit-id> topics (project-level durable + agent-level
  exact), sender circuit in metadata, sidecar:* read alias; e2e re-proven (OBS-453
  ruling)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
arc_id: arc-011
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
created: 2026-09-22T12:42:41Z
last_update: 2026-09-22T15:43:20Z
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
  - ts: '2026-09-22T12:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=306,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T12:45:24Z'
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

# T-3433: sidecar addressing: inbox:<circuit-id> topics (project-level durable + agent-level exact), sender circuit in metadata, sidecar:* read alias; e2e re-proven (OBS-453 ruling)

## Context

Operator ruling 2026-09-22 (decision recorded; resolves OBS-453). TermLink
treats only `inbox:*` and `dm:*` topics as mail (wake events `inbox.queued`,
receipts, `channel post --await-ack`); our `sidecar:<agent-id>` topics are a
bare append log with none of that. We take their prefix and keep our
identity: what follows `inbox:` is the framework's **five-level circuit id**
— host FQDN / hub id / project id (derived from the project path, existing
convention) / session id / agent name.

**Two address forms.**
- **Durable role address, project level:** `inbox:<hub>/<project>`. What
  peers reach us on today; survives session restarts because consults are
  durable on the hub and the next session of the project reads the same
  topic. This is the default for `fw sidecar send --to <project-id>` and the
  parent session's own inbox.
- **Exact circuit address, agent level:** `inbox:<hub>/<project>/<session>/<agent>`
  for a dispatched worker (what `FW_SIDECAR_AGENT_ID` names). Ephemeral;
  bounded retention (`messages:1000`, not `forever`).
- Group/broadcast ids unchanged. The sender's full circuit id goes in
  `metadata.from_circuit` on every message; `from_agent` stays for
  compatibility.

**Transition.** `sidecar:*` remains a READ alias for one release: the inbox
reader drains both the new topic and the legacy one (dedupe on
client_msg_id already handles overlap); senders write only `inbox:`.

**Circuit id derivation** lives in one helper (`lib/sidecar/circuit.py`)
used by transport, inbox, status, e2e and the dispatch stanza: hub id from
`termlink hub fingerprint` (cached), project id from the existing
project-path convention, session id from `TERMLINK_SESSION`/`FW_FOCUS_SESSION_KEY`,
agent name from `FW_SIDECAR_AGENT_ID`. Never invent a level: a missing
level truncates the path (a project-level address is a valid circuit).

**Out of scope.** Retry/escalation (T-3434). Urgent (separate design).
Per-agent signing keys (follow-on; noted in Evolution).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/sidecar/circuit.py`: `circuit_id(level="agent"|"project") -> str`, `topic_for_circuit(cid) -> "inbox:<cid>"`, `parse_circuit(cid) -> dict` (host, hub, project, session, agent — missing levels None); unit tests for full/agent, project-only, and truncation; project id uses the existing derivation (cite the function)
  - Evidence: `lib/sidecar/circuit.py` (272 lines); 25 tests in `tests/unit/test_sidecar_circuit.py` cover full/agent/project, truncation down the ladder, round-trip and the hub-anchor refusal. `project_id()` cites `lib/pickup.sh:42` (`basename "$PROJECT_ROOT"`).
- [x] `termlink_transport.topic_for(msg)` returns `inbox:<circuit>` (project-level when `to` is a bare project id, agent-level when `to` is a full circuit or a dispatched worker name resolvable to one); `build_post_command` adds `--metadata from_circuit=<sender circuit>`; existing transport tests updated, new ones for both forms
  - Evidence: `topic_for` delegates to `circuit.topic_for_name`; 17 tests green (6 new), incl. a guard that no sender writes `sidecar:`. Live: `from_circuit=//dimitrimintdev/cacc73ea32b121dd/999-Agentic-Engineering-Framework/t3433-circuit-addr`.
- [x] `inbox.inbox_topic()` returns the new topic for this agent AND `inbox.legacy_topics()` returns the `sidecar:` alias; `pending()` drains both (cursor per topic, shared seen-set) — test: a consult on the legacy topic and one on the new topic both surface once
  - Evidence: `test_a_consult_on_each_topic_both_surface_once`, plus dual-post collapse, per-topic cursors, and a seeding test so pre-T-3433 per-topic seen-sets are honoured. 15 inbox tests green.
- [x] Dispatch stanza (`agents/termlink/termlink.sh`) and `FW_SIDECAR_AGENT_ID` unchanged for workers; `fw sidecar whoami` prints agent id, circuit id, and both topics; `fw sidecar status` lists cursors for both
  - Evidence: stanza NOT edited — it names only agent ids and `fw sidecar` verbs, so it was already address-agnostic (verified by reading `_consult_stanza` in `agents/termlink/termlink.sh`). `whoami` prints agent id, exact circuit, host-qualified full id, durable project address, inbox topic and legacy read alias; `status` lists a cursor for every drained topic, at 0 when unread.
- [ ] `fw sidecar e2e` (explicit + ambient) passes on the new topics — two live PASS records with `mode` and topic names in the JSON; then `fw sidecar e2e --peer 010-termlink` re-issued on the new address and its record committed (PASS or their-hops-open, per T-3426's rule)
- [x] Docs: `docs/reports/T-3433-circuit-addressing.md` (the two forms, the derivation, the transition, what the hub now does for us); OBS-453 marked resolved; vendored copies synced, `bin/fw vendor self --check` clean; all sidecar suites green
  - Evidence: report written (172 lines) incl. the unmeasured-wake caveat; OBS-453 `status: resolved, promoted_to: T-3433` in `.context/inbox.yaml`. Vendor: all six sidecar files byte-identical to their vendored copies (scoped check in `## Verification`). The GLOBAL `fw vendor self --check` additionally covers `lib/bus.sh` + `lib/dispatch.sh`, which T-3434 holds uncommitted — the self-vendor guard withholds them by design ("withholding uncommitted file(s) not named by this caller"). See `## Decisions` for why the scoped check is the binding line.

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

python3 -m pytest tests/unit/test_sidecar_circuit.py tests/unit/test_sidecar_inbox.py tests/unit/test_sidecar_termlink_transport.py tests/unit/test_sidecar_status.py tests/unit/test_sidecar_e2e.py -q > /tmp/.t3433-pytest 2>&1 && grep -q passed /tmp/.t3433-pytest
bin/fw sidecar whoami --json > /tmp/.t3433-who 2>&1 && grep -q '"inbox_topic": "inbox:' /tmp/.t3433-who
grep -q '"legacy_topics": \["sidecar:' /tmp/.t3433-who
bin/fw sidecar status > /tmp/.t3433-st 2>&1 && grep -q '^inbox topics:     inbox:' /tmp/.t3433-st
grep -q 'sidecar:' /tmp/.t3433-st
python3 -c "import json; d=json.load(open('.context/sidecar/e2e/f12fa93d.json')); assert d['verdict']=='PASS' and d['mode']=='explicit'; assert d['topics']['sender'][0].startswith('inbox:') and d['topics']['responder'][0].startswith('inbox:')"
python3 -c "import json; d=json.load(open('.context/sidecar/e2e/60867b67.json')); assert d['verdict']=='PASS' and d['mode']=='ambient'; assert d['hops']['A1']['ok']; assert d['topics']['sender'][0].startswith('inbox:')"
python3 -c "import json; d=json.load(open('.context/sidecar/e2e/8dbad116.json')); assert d['mode']=='peer' and d['peer']=='010-termlink'; assert d['topics']['responder'][0].startswith('inbox:'); print('peer verdict', d['verdict'])"
bash -c 'set -eo pipefail; for f in lib/sidecar/circuit.py lib/sidecar/inbox.py lib/sidecar/status.py lib/sidecar/termlink_transport.py lib/sidecar/e2e.py lib/sidecar_cli.py; do cmp -s "$f" ".agentic-framework/$f"; done'
test -f docs/reports/T-3433-circuit-addressing.md
python3 -c "import yaml; d=yaml.safe_load(open('.context/inbox.yaml')); e=[x for x in d['observations'] if x.get('id')=='OBS-453'][0]; assert e['status']=='resolved' and e['promoted_to']=='T-3433'"

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

### 2026-09-22 — the ruling names five levels; the address carries four

- **What changed:** the ruling's normative sentence ("five-level circuit id — host
  FQDN / hub id / project id / session id / agent name") and its two concrete
  address forms (`inbox:<hub>/<project>`, `inbox:<hub>/<project>/<session>/<agent>`)
  do not agree about the host, and the forms are right. Measured: 010-termlink is
  on **another host and the same hub** — it reads and writes our topics directly
  (agent-chat-arc @1640/@1651) and we do not know its FQDN. A topic is an object
  on a hub; the host is where an agent runs. Embedding our fqdn in a peer's
  address would assert a level we do not have, which is the ruling's own "never
  invent a level" rule turned against the ruling's own first sentence.
- **Plan impact:** the address is hub-anchored. The host is not dropped — it is
  relocated to the host-qualified `//` form carried in `metadata.from_circuit`,
  which is what the ruling asked that metadata for ("origin precise even when the
  destination is coarse"). Every level in the ladder is still used.
- **Triggered:** the `//` authority marker (needed because the forms are
  positional and two of them are otherwise both three segments); documented in
  `docs/reports/T-3433-circuit-addressing.md`.

### 2026-09-22 — session==agent is one string, and collapsing it is what makes the address derivable

- **What changed:** the dispatch stanza (T-3407) exports `FW_SIDECAR_AGENT_ID`
  and `FW_FOCUS_SESSION_KEY` from ONE value — the worker name. The 4-level form
  would therefore emit that name twice, which is honest but useless: a peer
  holding only the worker's name could not derive the same topic.
- **Plan impact:** `session == agent` collapses to `<hub>/<project>/<agent>`, so
  sender-derived and receiver-derived addresses are identical strings with no
  shared state. The 3-form claims an agent under a project and does NOT claim a
  session — that is why `parse_circuit` returns `session: None` for it.
- **Triggered:** proven live rather than argued: run `f12fa93d`, where the parent
  derived the topic from the bare worker name and the worker derived it from its
  two env vars, and the consult landed. The stanza itself needed no edit, which
  is what AC4's "unchanged" asked for.

### 2026-09-22 — the wake event, which is the whole reason we moved, is the one thing we could not measure

- **What changed:** post, `subscribe` and `cv-keys` all work on a slashed
  `inbox:` id (measured before writing any code). `inbox.queued` did not appear
  on `tl-vayovuqm`'s event bus for the compound id — **and did not appear for the
  bare-id control either**. So this is a vantage-point blind spot on our side,
  not a measured compound-id failure, and the two are indistinguishable from here.
- **Plan impact:** none to the build; a real dent in the justification. The
  benefit that motivated the prefix move is **claimed, not proven**. Recording it
  as proven would have been the false green this framework keeps catching.
- **Triggered:** the question is in agent-chat-arc @1672 to 010-termlink, who
  traced the emit to hub `channel.rs:949`. If the match does not survive slashes,
  the follow-on is theirs (a prefix-match fix) or ours (a flatter id) — either
  way it is a decision with evidence, not a guess.

### 2026-09-22 — follow-on: the circuit names the agent, the signature still names the host

- **What changed:** nothing in this slice, but it is now precise enough to state.
  Every consult still signs as the shared host key `d1993c2c3ec44c94` (T-3405),
  so the circuit id identifies an agent while the signature identifies a machine
  — which is why receipts would be self-satisfying today.
- **Plan impact:** out of scope here, as the task said.
- **Triggered:** per-agent signing keys (`TERMLINK_AGENT_ID` →
  `~/.termlink/identities/<name>.key`, per @1641) remain the follow-on, and the
  alias removal is a separate one-release-out slice.

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

### 2026-09-22 — the address is hub-anchored; the host rides in metadata

- **Chose:** topic addresses start at the hub (`<hub>/<project>[/…]`). The host
  appears only in the `//`-marked full form used for `metadata.from_circuit`.
- **Why:** a topic is an object on a hub, and the one peer we actually consult
  (010-termlink) is on a different host on the same hub. An address containing
  our fqdn is underivable by them and asserts a level we do not have.
- **Rejected:** host-first 5-segment addresses (`//` unnecessary, ladder literal)
  — they make the durable role address underivable by a peer, which is the one
  job that address has. Also rejected: dropping the host from the model entirely
  — it is a real level and `parse_circuit` must be able to report it.

### 2026-09-22 — `//` marks the host rather than a label or a segment count

- **Chose:** RFC 3986 authority marker; `parse_circuit` keys on it.
- **Why:** the forms are positional and two of them are three segments
  (`host/hub/project` vs `hub/project/agent`), so counting cannot disambiguate.
- **Rejected:** T-3287's V9 `label=value::` grammar — correct, and heavier than
  this seam needs; the ruling's concrete forms are slash-separated. Also
  rejected: always emitting five segments with blanks — that invents levels.

### 2026-09-22 — `session == agent` collapses to the 3-form

- **Chose:** emit `<hub>/<project>/<agent>` when the session key and the agent id
  are the same string (every dispatched worker).
- **Why:** it makes sender-derived and receiver-derived addresses identical, with
  no shared state. Proven live in run `f12fa93d`.
- **Rejected:** emitting the name twice (honest, but a peer holding the worker's
  name cannot reproduce it); changing the stanza to mint a separate session id
  (AC4 requires the stanza unchanged, and a second naming scheme is the thing
  T-3407 removed).

### 2026-09-22 — a bare `--to` is classified by `is_project_id`, with an override

- **Chose:** three signals (it is us / a sibling project dir with
  `.framework.yaml` / the fleet's `NNN-Name` numbering), plus
  `fw sidecar send --level project|agent` to override, plus verbatim use of any
  `--to` containing `/`.
- **Why:** the peer projects we address are not local directories
  (`010-termlink` is at `/opt/termlink` on another host), so a filesystem lookup
  alone cannot classify them; the numbering convention covers the fleet and no
  agent name in this corpus matches it.
- **Rejected:** a live `termlink list` lookup (makes `topic_for` impure, slow and
  untestable); requiring an explicit flag always (breaks every existing caller,
  including the e2e harness).

### 2026-09-22 — the binding vendor check is scoped to this task's files

- **Chose:** `## Verification` asserts that each of the six sidecar files is
  byte-identical to its vendored copy, rather than running the global
  `bin/fw vendor self --check`.
- **Why:** the global check also covers `lib/bus.sh` and `lib/dispatch.sh`, which
  the concurrent T-3434 worker holds uncommitted; the self-vendor guard withholds
  them by design ("withholding uncommitted file(s) not named by this caller"), so
  the global check reports DRIFT for another task's in-flight work. A line whose
  colour depends on a second task's working tree is exactly the mutable-corpus
  anchor T-3326 forbids. The global check was still run by hand and its state is
  reported in the handback.
- **Rejected:** `FW_VENDOR_ALL=1` (ships another task's unfinished work to
  consumers under my commit — the precise hazard the guard exists to stop);
  waiting on T-3434 (couples two independent closes).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-22T12:42:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3433-sidecar-addressing-inboxcircuit-id-topic.md
- **Context:** Initial task creation
