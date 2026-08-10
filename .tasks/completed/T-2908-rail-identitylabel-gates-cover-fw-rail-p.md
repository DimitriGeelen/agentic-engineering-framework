---
id: T-2908
name: "rail identity+label gates cover fw rail post only — the MCP producer surface
  is unguarded"
description: >
  rail identity+label gates cover fw rail post only — the MCP producer surface is
  unguarded

status: work-completed
workflow_type: build
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
created: 2026-08-10T18:51:00Z
last_update: 2026-08-10T20:22:07Z
date_finished: 2026-08-10T20:22:07Z
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
  - ts: '2026-08-10T19:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-10T19:00:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2908: rail identity+label gates cover fw rail post only — the MCP producer surface is unguarded

## Context

T-2904 shipped a gate refusing host-signed rail posts; T-2905 shipped an emitted
`from_project` label. Rail 513 reported the class closed. **It is closed on one
producer leg.** Both gates live in `do_rail post` in `bin/fw`. The
`mcp__termlink__termlink_channel_post` MCP tool is a second producer that reaches the
same topic with neither gate in scope — no identity check, no label attach.

Found by reading 832's rail 514 §4, where they declared the same asymmetry on their
side (their MCP posts carry `from_project` because a human types it into the metadata
map; their detector catches a miss only afterwards as UNATTRIBUTED). Going to check
whether ours was better is what surfaced that it is not. Not found by review — our own
L-399 / T-1890 discipline says a bypass contract must be honoured by every command
pattern the gate covers, and that discipline was cited in the same session that
shipped the one-leg gate.

### Measured, not inferred (2026-08-10)

Posted rail 515 through the MCP surface and read the envelope back:

| surface | `sender_id` | key | gated by T-2904/T-2905 |
|---------|-------------|-----|------------------------|
| `fw rail post` / shell `termlink channel post` | `d1993c2c3ec44c94` | substrate, shared with 832 | yes |
| `mcp__termlink__termlink_channel_post` | `0e7ee6cad65137fc` | **AEF project key** | **no** |
| 832's MCP surface (rail 514, for comparison) | `6a646ce8b1bc6560` | 832 project key | n/a |

**The split is by surface, and it inverts the gate.** MCP loads a project identity;
shell inherits the substrate's. So the surface with the *correct* identity is the
ungated one, and the gated one is the one that can only sign as the substrate. Rail
510 and 513 were sent host-signed via a logged Tier-2 bypass of our own gate — that
bypass was unnecessary. The right identity was available the whole time on a surface
nobody had measured.

**This also collapses part of T-2904's open question.** That task left "which
fingerprint do we adopt" with the operator, framing it as mint-a-new-key versus
find-a-file-behind-the-T-559-fence. Neither is needed to *have* a project identity:
`0e7ee6ca` exists, is loaded, and is already the key the DM topic name was built from
(`dm:0e7ee6ca…:6a646ce8…`). The remaining operator question is narrower — whether the
shell surface should be made to load it too.

Prediction discipline: the consequence above was posted to 832 in rail 515 **before**
the envelope was read, so it is on the record either way. It held.

### Full producer-surface enumeration (2026-08-10, this session)

The table above compared two surfaces. Grepping the repo for every call site that
reaches `termlink channel post` (not just `fw rail post`) finds more:

| # | surface | invocation shape | identity | gated by T-2904/T-2905 |
|---|---------|-------------------|----------|--------------------------|
| 1 | `fw rail post` | `bin/fw rail post ...` → `do_rail post` | project, if `RAIL_IDENTITY_FILE` configured; else substrate (`d1993c2c…`) | **yes** — identity guard + auto label |
| 2 | bare shell `termlink channel post` (typed directly in Bash, or any script that calls the binary without going through `do_rail`) | e.g. an agent runs `termlink channel post <topic> ...` instead of `fw rail post` | same binary, same env-precedence resolution as #1 — substrate by default | **no** — no PreToolUse hook inspects raw Bash for this pattern, no wrapper injects the label |
| 3 | in-repo scripts calling `termlink channel post` directly (`lib/templates/scripts/agent-respond.sh`, `agent-send.sh`, `chat-arc-broadcast.sh`, `listener-heartbeat.sh`, `lib/pickup-channel-bridge.sh`, `lib/publish-learning-to-bus.sh`, and their vendored `scripts/` mirrors) | invoked by cron / the doorbell path / the pickup pipeline, not by an interactive agent | same as #2 — these are just #2's call sites, pre-existing in our own code | **no** — filed separately as **T-2913** (Task Sizing Rules: this is a distinct producer class from the MCP tool the title names, six call sites is its own remediation, not a one-line fix folded into this task) |
| 4 | `mcp__termlink__termlink_channel_post` (MCP tool) | Claude Code calls the tool directly; termlink's MCP server (`termlink mcp serve`, wired in `.mcp.json`) signs and posts, no shell wrapper in between | measured `0e7ee6cad65137fc` (project key) at one point in time — see caveat below | **no**, until this task — **now label-gated** (identity intentionally NOT re-gated, see next section) |

Row 3 is the deliverable's biggest correction to the class as originally scoped: the
task title and AC text both frame this as "the MCP producer surface is unguarded" —
true, but MCP is not the *only* other surface. Six in-repo scripts we already own call
the same unwrapped binary. Filed as **T-2913** rather than fixed here, per Task Sizing
Rules ("one bug = one task") — six call sites across cron/doorbell/pickup code paths is
its own review, not a line item inside this task.

### Is the MCP surface gateable? Concretely: yes for the label, no for identity

**Label — YES, prevention, shipped.** `metadata.from_project` is a field in the MCP
tool's own JSON args (`tool_input.metadata`, confirmed against the tool's live
`inputSchema` via a local `tools/list` probe — `metadata` is
`additionalProperties: {type: string}`), exactly the same shape any other PreToolUse
hook in this repo already inspects (`check-tier0.sh` reads `tool_input.command`;
`check-arc-id.py` reads `tool_input.content`). A PreToolUse hook matching
`mcp__termlink__termlink_channel_post` can read that field and block the call before it
reaches termlink. Shipped as `agents/context/check-rail-mcp-label.sh`, wired via
`bin/fw hook-enable` (not a direct settings.json edit — that path is B-005-blocked, see
Decisions).

**Identity — NO, not safely.** Re-checked with the actual measurement to hand: a hook
subprocess that shells out to `termlink agent identity --resolve` (the same call
`rail_identity_guard` makes) reflects what a **freshly spawned** termlink process would
sign as *right now*, in the hook's own environment. It does **not** reflect what the
**already-running** MCP server process (started once, at Claude Code session init, by
`.mcp.json`) actually signed a given call with — that process's identity was resolved
once, before the hook ever fires, in an environment this hook does not control. Verified
this distinction is real, not theoretical: spawning `termlink mcp serve` fresh from this
session's own shell (inheriting this shell's env, no `TERMLINK_IDENTITY_FILE` set)
resolves to the substrate key `d1993c2c…` — the *opposite* of the `0e7ee6ca…` the prior
session measured through the live Claude-Code-launched MCP tool. Two processes, same
binary, same subcommand, different signing key, because *something* about how Claude
Code itself launches the MCP server differs from a bare subprocess spawn — and that
something lives inside termlink's MCP transport, which is outside this project's
boundary (T-559 blocks reading `/opt/termlink` source directly). Building a guard on a
signal I cannot independently reproduce would be a check that looks authoritative and
isn't — the exact false-confidence class this task exists to close (see L-572).
**Detection replaces prevention here**: the hook's block message and this file both
name the caveat in plain text, and `bin/fw rail identity` remains the tool to re-check
attribution by hand. No automated per-call identity assertion ships for this surface.

### L-399 parity check across every gated surface

| gated surface | bypass mechanism | tested? |
|---|---|---|
| `fw rail post` (identity, T-2904) | `FW_ALLOW_HOST_SIGNED_RAIL=1` (env var — the command is a literal shell invocation the agent controls) | `tests/unit/rail_identity_guard.bats` (pre-existing, re-run this session: 11/11 pass) |
| `mcp__termlink__termlink_channel_post` (label, this task) | `bin/fw rail allow-unlabeled-mcp` — a one-shot file token (`.context/working/.rail-mcp-label-bypass`), consumed on first use, TTL 300s (`FW_RAIL_MCP_BYPASS_TTL`) | `tests/unit/rail_mcp_label_guard.bats` (new, this session: 8/8 pass) |

The env-var mechanism from T-2904 could not be reused here: an MCP tool call is a
direct function invocation from the model, not a shell command line the agent's own
env-prefix could wrap, so `FW_ALLOW_X=1 <call>` has no surface to attach to. This is
the same shape L-399 already names for external tools like `git commit` — a file-token
mirrors that class more than it invents a new one. Both mechanisms are pinned by tests
that exercise hook-block → bypass-armed → hook-allow → log-entry-written end to end, not
just the hook in isolation (T-1890's actual lesson: the bug lives at the join).

### RED → GREEN evidence (AC5)

`tests/unit/rail_mcp_label_guard.bats` was written and run **before**
`check-rail-mcp-label.sh` existed. All 8 cases failed genuinely (exit 127, "command not
found" — the hook script did not exist, not a designed skip):
```
not ok 1 rail-mcp-label: ignores tools other than the MCP channel_post surface
not ok 2 rail-mcp-label: BLOCKED (exit 2) when metadata carries no from_project
... (8/8 not ok)
```
After implementing the hook, the CLI subcommand, and wiring the matcher via
`fw hook-enable`, the same file: 8/8 pass. `rail_identity_guard.bats` (the T-2904 suite)
re-run after these changes: 11/11 pass, no regression from the shared `_rail_log_bypass`
signature change (gate name is now a parameter, defaulting to the original caller's
value, so T-2904's call site needed no edit).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every producer surface that can post to a rail topic from this project is
      enumerated — `fw rail post`, bare `termlink channel post`, the
      `mcp__termlink__termlink_channel_post` MCP tool, and anything in the repo
      that shells out to any of them — with each marked gated or ungated. The
      enumeration is the deliverable: T-2904/T-2905 shipped believing there was
      one producer, and 513 reported the class closed on that belief
- [x] The signing identity of each surface is MEASURED, one post per surface with
      the observed `sender_id` recorded — not inferred from the tool's docs. The
      prior round's wrong conclusion came from reasoning about a surface instead
      of posting from it
- [x] Whether the MCP surface CAN be gated is answered concretely. It is provided
      by termlink, not by us, and a PreToolUse hook is the only interposition
      point we own. If prevention is not reachable, say so plainly and state what
      detection replaces it — "detection, not prevention" recorded as such rather
      than described as a fix (832's own §4 is the standard to match here)
- [x] L-399 parity is re-checked across every gated surface: the documented bypass
      mechanism actually works on each one, or the block message names the
      surfaces it cannot reach. A contract honoured on one leg is the T-1890
      failure, and this task exists because that happened again
- [x] If a guard ships, it goes RED against the pre-fix state — an ungated post
      demonstrably reaching the topic — not merely green afterwards

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

bats tests/unit/rail_mcp_label_guard.bats > /tmp/.t2908-mcp.out 2>&1; grep -q "^1\.\.8$" /tmp/.t2908-mcp.out && ! grep -q "^not ok" /tmp/.t2908-mcp.out
bats tests/unit/rail_identity_guard.bats > /tmp/.t2908-id.out 2>&1; grep -q "^1\.\.11$" /tmp/.t2908-id.out && ! grep -q "^not ok" /tmp/.t2908-id.out
python3 -c "import json; json.load(open('.claude/settings.json'))"
# fw doctor's own "Enforcement baseline intact" check inlined directly (L-398) —
# `fw doctor` itself also walks every sibling consumer project on this host and
# is consistently 120s+ under concurrent load; this reproduces its exact
# baseline-hash comparison (bin/fw:2247-2253) without that unrelated cost.
stored=$(tr -d '[:space:]' < .context/project/enforcement-baseline.sha256); current=$(python3 -c "import json,hashlib; d=json.load(open('.claude/settings.json')); print(hashlib.sha256(json.dumps(d.get('hooks',{}),sort_keys=True).encode()).hexdigest())"); [ "$stored" = "$current" ]

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
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-08-10 — Bypass mechanism for the MCP label gate
- **Chose:** a one-shot file token (`bin/fw rail allow-unlabeled-mcp` writes
  `.context/working/.rail-mcp-label-bypass`; the hook consumes/deletes it on first use,
  TTL `FW_RAIL_MCP_BYPASS_TTL` default 300s).
- **Why:** T-2904's `FW_ALLOW_HOST_SIGNED_RAIL=1 fw rail post ...` env-var-prefix pattern
  only works because the gated action is a literal shell command line the agent's own
  env override wraps. An MCP tool call has no such surface — it's a direct function
  invocation from the model, and the hook subprocess Claude Code spawns for it doesn't
  inherit env set by a prior, unrelated Bash tool call. L-399 already names this split
  for external tools (git commit needs the env-var form because flags aren't honoured);
  this is the same shape one layer further — no command line at all to attach anything
  to, so the mechanism has to be a persisted signal instead.
- **Rejected:** reusing `FW_ALLOW_HOST_SIGNED_RAIL` verbatim (wrong semantics — that
  name is about identity, this bypass is about the label) and building
  Tier-0-style Watchtower approval plumbing (real overkill for a same-session,
  same-agent, single-field bypass; the file token is the minimum viable honoured
  contract, not the maximum robust one).

### 2026-08-10 — Identity is detection-only on the MCP surface, not prevention
- **Chose:** ship a label gate (prevention) but not an identity gate (prevention) for
  `mcp__termlink__termlink_channel_post`. The identity caveat is documented in the hook's
  block message, this task file, and `lib/rail-identity.sh`'s help text instead.
- **Why:** the only way to check "would this call be host-signed" from a hook is to
  shell out to `termlink agent identity --resolve` from the hook's own process — which
  answers what a *fresh* process would sign as, not what the *already-running* MCP
  server (started once, at session init, by `.mcp.json`) actually signs calls with.
  Measured this session: a fresh subprocess spawn of `termlink mcp serve` from this
  session's own shell resolved to the substrate key, the opposite of what the prior
  session measured through the real, Claude-Code-launched MCP tool. Two spawns of the
  same binary, different keys — so the two are not interchangeable, and a hook built on
  the fresh-spawn signal would be checking the wrong process. Building the gate anyway
  would be exactly the failure this task exists to prevent: a check that looks
  authoritative and isn't (L-572).
- **Rejected:** reusing `rail_identity_guard()` in the MCP hook (checks the wrong
  process, as above); trying to read termlink's MCP-server source to explain the split
  (blocked by the T-559 project-boundary gate — `/opt/termlink` is another project).

### 2026-08-10 — Six in-repo script call sites filed as T-2913, not fixed here
- **Chose:** enumerate the six scripts calling `termlink channel post` directly
  (`agent-respond.sh`, `agent-send.sh`, `chat-arc-broadcast.sh`,
  `listener-heartbeat.sh`, `pickup-channel-bridge.sh`, `publish-learning-to-bus.sh`)
  as a fourth producer-surface row, but file their remediation as a separate task
  (T-2913) rather than route all six through `do_rail post` inside this task.
- **Why:** Task Sizing Rules — "one bug = one task". This task's title and ACs are
  scoped to the MCP tool surface; the six scripts are a distinct discovery (found while
  enumerating, not while fixing MCP) touching cron / doorbell / pickup-pipeline code
  paths that each need their own verification that routing through `do_rail` doesn't
  change call-site behaviour (e.g. `--ensure-topic`, `--payload-from-file`, ack/retry
  flags `do_rail post` doesn't yet pass through cleanly).
- **Rejected:** silently leaving them unenumerated (would repeat this exact task's root
  cause — "list every surface... do not reason about a surface you have not exercised",
  L-572); folding the fix into this task (oversized, mixes two unrelated blast radii).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-10T18:51:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2908-rail-identitylabel-gates-cover-fw-rail-p.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b817b798
- **Timestamp:** 2026-08-10T20:22:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-10T20:22:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
