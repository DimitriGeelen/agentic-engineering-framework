---
id: T-2904
name: "outbound rail identity depends on the posting path — termlink channel post
  signs as the host key"
description: >
  Found by T-2903's verification, which asserted the sender of our own rail post.
  Rail 508 posted via 'termlink channel post' landed with sender_id=d1993c2c3ec44c94
  (the HOST key) rather than 0e7ee6cad65137fc (our project key). Offsets 3 and 5 on
  the same rail, posted via the doorbell /reply path, signed as 0e7ee6cad65137fc correctly.
  So our outbound producer identity varies by code path, and the CLI path is the wrong
  one. This matters beyond cosmetics: 832 is building T-406/T-414 identity gating
  on producer identity at this exact seam, and a peer cannot distinguish 'AEF posted
  this' from 'some co-resident agent on the AEF host posted this' when we sign as
  the host. Note the shape — rail offsets 1-2 record this same split being reported
  and declared fixed; either it regressed or the fix only ever covered the doorbell
  path. Also note termlink warned at post time: 'posting without from_project — co-resident
  agents may be indistinguishable'. That warning is the symptom surfacing and it was
  not acted on. Needs: determine whether --metadata from_project=<id> or running from
  a .framework.yaml-rooted cwd changes the signing key or only the metadata, and whether
  the CLI can sign as the project key at all.

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
created: 2026-08-09T16:03:36Z
last_update: '2026-08-09T16:15:06Z'
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
bvp_scores_proposed:
  - ts: '2026-08-09T16:05:12Z'
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
cost_estimate_proposed:
  - ts: '2026-08-09T16:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2904: outbound rail identity depends on the posting path — termlink channel post signs as the host key

## Context

Found by T-2903's verification command, which asserted the sender of our own rail
post and went red.

### Measured (AC-1)

| Path / flag | resulting `sender_id` |
|---|---|
| `termlink channel post`, bare | `d1993c2c3ec44c94` (host key) |
| `+ --metadata from_project=…` | `d1993c2c3ec44c94` — metadata only, does not affect signing |
| `+ --sender-id 0e7ee6cad65137fc` | **refused by hub**, see below |
| doorbell `/reply` path (offsets 3, 5) | `0e7ee6cad65137fc` (project key) — correct |

`termlink agent identity` reports the loaded identity as fingerprint
`d1993c2c3ec44c94`. The override is refused outright:

    JSON-RPC -32014: sender_id="0e7ee6cad65137fc" does not match identity
    fingerprint d1993c2c… derived from sender_pubkey_hex (T-1427)

### Never covered, not regressed (AC-3)

Rail offset 1 — our own message, months old — says verbatim *"hub rejects the
sender override (T-1427)"*. 832's identity fix at offsets 1-2 covered the
**doorbell** path. The CLI path was never in the patch. From outside, "regressed"
and "never covered" are indistinguishable, which is why AC-3 asked.

### The mitigation was stale (AC-2 divergence point)

`learnings.yaml:4257` records this exact failure caught live and prescribes
`--sender-id <established-fp>`. That remedy was hardened away by T-1427
afterwards, and nothing links the two — the entry still reads as authoritative,
specific and current. Superseded by a new learning under this task.

That learning is also one of the 572 rows T-2901 measured as carrying
`application: TBD`. The field meant to say *what do I do differently* was blank on
the entry that would have prevented this post.

### Boundary

Determining WHICH identity file the doorbell path loads requires reading
host-wide config, which T-559 blocks and which gap-homing puts in termlink's
register, not ours — `.context/inbox.yaml:764` already homes it there.

### CORRECTION — "structurally cannot" was wrong (AC-5)

The table above measured every flag on the `channel post` subcommand and
concluded the CLI could not sign as a project key. That conclusion was false, and
the probe was aimed at the wrong dimension: the signing key is selected by **env
precedence**, not by post flags —

    TERMLINK_IDENTITY_FILE > TERMLINK_AGENT_ID > TERMLINK_IDENTITY_DIR > shared host default

(termlink PL-236 / their T-2324; documented only under `termlink agent identity
--resolve --help`, which is why flag-probing never met it.)

Measured 2026-08-09, on a throwaway topic rather than 832's rail:

| probe | resulting `sender_id` |
|---|---|
| `TERMLINK_IDENTITY_FILE=<scratch>/probe.key` + `channel post` | `22b8cb92cc2606de` — the scratch key |

Topic `aef-t2904-idprobe` offset 0 on hub `192.168.10.107:9100` is the evidence;
left in place deliberately rather than cleaned up.

Two further findings:

- **`TERMLINK_IDENTITY_FILE` auto-creates the keypair** (chmod 600) when the path
  does not exist. So the tempting probe — `TERMLINK_AGENT_ID=<guess>` to discover
  the existing AEF agent key — would have **minted** keys under the shared host
  identity dir rather than read it. Not done, for that reason.
- The remaining unknown is only *where AEF's existing `0e7ee6ca` key file lives*,
  which is host config behind T-559 and homes to termlink per
  `.context/inbox.yaml:764`. That is a much smaller and more actionable statement
  than "structurally cannot".

`learnings.yaml` L-569 carried the false universal and has been marked in place
(not merely superseded — the correction must be reachable *from* the claim);
L-570 records the measurement and the methodological shape.

### What this task ships (AC-5)

The mechanism, not the fingerprint. `lib/rail-identity.sh` resolves a
project-scoped signing identity and refuses when the resolved key is the shared
host key; `fw rail post` is the guarded route. **Which** fingerprint the project
adopts — re-use `0e7ee6ca` (continuity with 832) or mint a project-owned key
(D-377 total isolation, but a new producer identity 832 has never seen) — is a
cross-project blast-radius call and belongs to the operator, not to me.


## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Measured, not assumed: post via `termlink channel post` with and without
      `--metadata from_project=…` and from a `.framework.yaml`-rooted cwd, and
      record the resulting `sender_id` for each — establishing whether either
      changes the SIGNING KEY or only annotates the envelope
- [x] The doorbell `/reply` path (which signs correctly at offsets 3 and 5) is
      compared against the CLI path, and the divergence point is named — one of
      them supplies a project key the other does not
- [x] Determined whether the fix declared at rail offsets 1-2 regressed or only
      ever covered the doorbell path; those two are indistinguishable from the
      outside and the answer changes what needs doing
- [x] 832 is told, because they are gating on producer identity at this seam and
      a host-signed message reads to them as a valid non-AEF producer
- [x] Either the CLI path signs as the project key, or — if it structurally
      cannot — the framework's rail-posting surface stops using the bare CLI
      path, so a mis-signed post is not reachable by the default route
      → **first branch, and the premise "structurally cannot" was false.**
      `lib/rail-identity.sh` + `fw rail post` sign with the project key when
      `RAIL_IDENTITY_FILE` is set, and refuse (exit 2) when the post would carry
      the host key. Proven live, not inferred: a guarded post landed on topic
      `aef-t2904-idprobe` as sender `22b8cb92cc2606de` from a session whose host
      identity is `d1993c2c3ec44c94`. Host-default detection is by comparison
      against the bare fingerprint, not a hard-coded literal, so it holds on any
      host. 7 bats legs; the two load-bearing ones mutation-checked red.

### Human

- [ ] [REVIEW] Decide WHICH fingerprint this project signs rail posts with

  This is the one part of T-2904 I deliberately did not decide. The mechanism is
  built and proven; the choice is a cross-project coordination call, because 832
  has known us as `0e7ee6cad65137fc` for hundreds of rail offsets and a new
  producer identity is something they must be told about, not something they
  should discover.

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw rail identity`
     (expect `state: host` until a choice is made)
  2. Pick one:
     - **Mint a project-owned key** — aligns with D-377 (nothing of the project
       in `$HOME`), removes all dependence on host config, but is a NEW
       fingerprint 832 has never seen:
       `cd /opt/999-Agentic-Engineering-Framework && bin/fw config set RAIL_IDENTITY_FILE .context/rail-identity.key`
     - **Re-use the existing `0e7ee6ca` key** — preserves continuity with 832,
       but the key file lives under host config, which T-559 fences and which
       `.context/inbox.yaml:764` already homes to termlink:
       `cd /opt/999-Agentic-Engineering-Framework && bin/fw config set RAIL_IDENTITY_FILE /path/to/that/key`
     - **Neither yet** — leave host-signed; `fw rail post` will keep refusing,
       and hand-typed `termlink channel post` keeps working as today.
  3. If you minted a new key, tell 832 the new fingerprint before the next rail
     post, so their producer-identity gating (their T-406/T-414) does not read it
     as an unknown third party.

  **Expected:** `bin/fw rail identity` reports `state: project` with a
  fingerprint that is not `d1993c2c3ec44c94`.

  **If not:** the path may be relative to a different root — pass an absolute
  path, and re-check with `bin/fw config get RAIL_IDENTITY_FILE`.

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-09T16:03:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2904-outbound-rail-identity-depends-on-the-po.md
- **Context:** Initial task creation

### 2026-08-09T16:05:11Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

bats tests/unit/rail_identity_guard.bats
# the guard refuses a host-signed post with the documented exit code, not just a message
echo body | env -u FW_RAIL_IDENTITY_FILE bin/fw rail post --hub 127.0.0.1:9 sink-topic > /tmp/.t2904 2>&1; [ $? -eq 2 ] && grep -q "BLOCKED" /tmp/.t2904
# a project-owned key resolves to a fingerprint that is NOT the host default
K=$(mktemp -d)/k.key; H=$(env -u FW_RAIL_IDENTITY_FILE bin/fw rail identity | awk '/fingerprint:/{print $2}'); P=$(FW_RAIL_IDENTITY_FILE=$K bin/fw rail identity | awk '/fingerprint:/{print $2}'); [ -n "$H" ] && [ -n "$P" ] && [ "$H" != "$P" ]
# the corrected learning is reachable FROM the wrong claim, not merely filed near it
grep -q "PARTLY WRONG — CORRECTED SAME DAY BY L-570" .context/project/learnings.yaml
