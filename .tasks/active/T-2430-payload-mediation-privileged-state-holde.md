---
id: T-2430
name: "payload-mediation: privileged state-holder (A5 fix + proxy trust root)"
description: >
  Relocate trusted governance state (focus, active-task status, approval tokens, budget)
  out of agent-writable files behind a privileged setter the agent uid cannot write.
  Split verbs into propose (agent) / commit (privileged). Highest-leverage slice.
  Gated on T-2428 GO.

status: work-completed
arc_id: payload-mediation
workflow_type: build
owner: human
horizon: now
tags: []
components: [bin/fw, lib/govd_policy.py, tests/unit/test_govd_policy.py]
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
created: 2026-06-18T07:18:25Z
last_update: '2026-08-16T22:24:09Z'
date_finished: 2026-06-18T15:03:03Z
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
  - ts: '2026-08-16T22:24:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2430: payload-mediation: privileged state-holder (A5 fix + proxy trust root)

## Context

Design of record: `docs/reports/T-2428-payload-mediation-design.md` §4e (the
privileged state-holder as authority broker) + §4c (control plane). This is the
**keystone slice** — §4c names it the highest-leverage build piece, and the build
order is **T-2430 → T-2433** (the sandbox RO/RW fs partition is only clean once
trusted state is relocated out of agent scratch).

**What it is (§4e):** a small daemon `aef-govd` (uid `aef-gov`) in the trusted
zone outside the cage, alongside the proxy. It owns the authoritative governance
state; files become **read-only projections** of the holder's record — the
inversion principle: writing a file no longer *means* anything to governance, only
a holder-recorded event does. This dissolves the A5 hole at the root rather than
guarding each writable file.

**Authority broker, not a binary gate (§4e):** the holder implements the full tier
ladder (0/1/2/3) via a **sovereign-authored envelope** in RO substrate — a global
risk ceiling (BVP `blast_radius` / `voi_score` / `scope`) PLUS per-type overrides.
Per decision it resolves `overrides[type] ?? global`, checks params, and either
lets the agent commit (logged at the matching tier) or queues to the human. Tier-0
and directive-authorship are a hard floor no override can loosen.

**The invariant:** the agent commits *within* the envelope; the agent cannot
*change* the envelope. Generalizes the T-2367 bounded-autonomy ceiling to every
decision class — keeps the arc-012 autonomous loop alive while closing A5/D7.

**Three-in-one (why it's the keystone):** A5 fix + the proxy's dynamic-state trust
root + the sandbox fs-boundary enabler. Structural home for D7 (dispatch
self-approve), D1/D3 (directive authorship), and bypass-log integrity. Keep the
daemon SMALL — it is the TCB; every line is attack surface.

## Acceptance Criteria

### Agent
<!-- Firmed up at GO (T-2428)→build. Built = agent-verifiable now; install-time
     ENFORCEMENT (uid demotion, RO bind-mounts, chattr +a) is Lock-1 Part 1 → ### Human. -->
- [x] Decision evaluator (`lib/govd_envelope.py`): effective rule `{**global, **overrides[type]}`;
      within → agent commit Tier-3; breach → queued Tier-2; Tier-0/directive are hard floors
      no override can loosen (`tests/unit/test_govd_envelope.py`, 17 passed)
- [x] Worked-example proof: `inception_go` blast_radius 1 → agent commits; blast_radius 7
      (e.g. T-2428) → queued to human (unit test + `govd.sh evaluate` CLI)
- [x] Propose channel = unix socket (`lib/govd_holder.py --serve`); agent submits proposals,
      cannot commit directly; `op=commit` requires the sovereign principal via SO_PEERCRED
      (live socket round-trip + unit test)
- [x] Authority envelope (global ceiling + per-type overrides) authored as RO substrate
      (`policy/authority-envelope.yaml`), loaded by the holder; load fails closed → human
- [x] State setter built (`StateStore`): the holder owns authoritative state — the inversion
      principle, on-disk files become RO projections of the holder's record
- [x] Audit log append-only (`AppendOnlyAudit`): every decision recorded; the agent path
      cannot rewrite prior entries (app-level proven; `chattr +a` is install-time)
- [x] `agents/govd/govd.sh emit-install` EMITS the systemd unit + root setup and runs
      nothing — the Lock-1 Part 1 boundary holds

### Human
- [ ] [REVIEW] Lock-1 Part 1 — as root, deploy the holder under a dedicated non-agent service
      account with the envelope + state on RO bind-mounts and `chattr +a` on the audit, so writes
      from the unprivileged account are refused by the kernel. Security-critical: read
      `lib/govd_holder.py` + the emitted unit before installing.
      **Steps:** 1. `cd <repo> && bash agents/govd/govd.sh emit-install --out /tmp/govd`
      2. read the emitted spec + `lib/govd_holder.py` 3. run the emitted `sudo` setup.
      **Expected:** you observe `systemctl status aef-govd` active, and a test write to the envelope
      from the unprivileged account is refused (Permission denied).
      **If not:** note which mount/account step failed.
- [ ] [REVIEW] Relocate real framework trusted state (focus.yaml, approvals, bypass log) behind
      the holder's setter so the on-disk files become RO projections. Integration follow-on —
      the setter mechanism is built; wiring the existing state is the human-gated step.
      **Steps:** review the StateStore API, decide the migration order, wire one state (focus) first.
      **Expected:** focus changes flow through `op=propose` and the file mirrors the holder record.
      **If not:** keep the legacy path until the holder is installed.

<!-- template examples retained below -->
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

PYTHONPATH=. python3 -m pytest tests/unit/test_govd_envelope.py -q
out=$(bash agents/govd/govd.sh evaluate '{"type":"inception_go","blast_radius":7,"voi_score":0.9}'); echo "$out" | grep -q '"commit": "human"'
out=$(bash agents/govd/govd.sh evaluate '{"type":"inception_go","blast_radius":1,"voi_score":0.85}'); echo "$out" | grep -q '"commit": "agent"'
out=$(bash agents/govd/govd.sh emit-install); echo "$out" | grep -q "systemctl daemon-reload"

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

**Symptom:** An agent operating under a broad directive ("proceed as you see fit") can edit its own governance substrate — `.claude/settings.json`, hooks, the authority envelope, the proxy policy — and thereby self-authorize actions beyond its tier. There is no runtime authority that sits above the agent and that the agent cannot itself reach and rewrite (the A5 class).

**Root cause:** Governance state lives in files writable by the agent's own uid, and "authority" is enforced by PreToolUse hooks that run at the same privilege as the agent. The boundary "Initiative ≠ Authority" was a *convention* (text in CLAUDE.md), not a *structural* boundary — whoever can write the files can rewrite the rules. There was no privileged holder owning the trust root.

**Why structurally allowed:** File-based governance is mutable by anyone with write access; the framework's enforcement layer (hooks, task gate) executes in the agent's own process tree with the agent's permissions. Nothing in the substrate distinguished "the agent proposing" from "the sovereign deciding" at the OS level — both were the same uid writing the same files.

**Prevention:** The privileged state-holder (`aef-govd`, `lib/govd_holder.py`) owns the authority envelope and trusted state under a *non-agent uid*. The agent can only `propose`; a `commit` requires `peer_uid == sovereign_uid`, checked via SO_PEERCRED at the socket — unforgeable from the agent's uid. Governance files become read-only projections to the agent (Lock-1 Part 1: RO bind-mount + `chattr +a` audit). The envelope's hard-floor types (`tier0_approve`, `directive_author`) are denials no per-type override can loosen. The boundary moves from convention to OS-enforced structure. (Full enforcement requires the human/root Lock-1 Part 1 deploy — the two `[REVIEW]` ACs.)

## Evolution

### 2026-06-18 — T-2430 first reviewable cut (autonomous build, arc-013)
- **What changed:** the holder splits cleanly into (a) agent-verifiable LOGIC — the
  envelope evaluator, append-only audit, state setter, unix-socket propose/commit with
  SO_PEERCRED principal check — and (b) install-time ENFORCEMENT (non-agent uid, RO
  bind-mounts, `chattr +a`) which is Lock-1 Part 1. Built and tested (a); emitted (b).
- **Plan impact:** the original ACs conflated the two; firmed up to ticked Agent ACs
  (logic) + Human ACs (Lock-1 install + real-state relocation). Decision evaluator made a
  pure module so it is unit-testable without root or sockets.
- **Triggered:** envelope authored at `policy/authority-envelope.yaml`; `fw holder` route
  not added (kept off bin/fw for this cut — runnable via `agents/govd/govd.sh`); fabric
  registration of the new files deferred to the slice close.


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

### 2026-06-18T07:18:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2430-payload-mediation-privileged-state-holde.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3bf0527c
- **Timestamp:** 2026-06-18T15:03:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - mock-only-integration @ AC vs Verification cross-check
### 2026-06-18T15:01:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Recommendation

**Recommendation:** GO

**Rationale:** The agent-buildable portion of the authority-broker holder is complete and verified. All 7 Agent ACs are met with reviewer PASS; the two remaining `[REVIEW]` ACs are deliberately human/root-gated (Lock-1 Part 1 deploy + relocating live framework trusted state behind the holder) — they cannot and must not be executed by the agent. This is a "first reviewable cut" of TCB code: the mechanism is real and tested, not yet production-hardened. GO means: the code is ready for your security review and, when you choose, the root deploy.

**Evidence:**
- `lib/govd_envelope.py` — pure envelope evaluator: `resolve_rule` (per-type override merge), `evaluate` (within→agent Tier-3 / breach→human Tier-2), hard-floor types (`tier0_approve`, `directive_author`) no override can loosen.
- `lib/govd_holder.py` — `aef-govd` daemon: `AppendOnlyAudit` (JSONL), `StateStore` (atomic `os.replace`), `Holder` (propose/commit/query; commit requires `peer_uid == sovereign_uid` via SO_PEERCRED).
- `policy/authority-envelope.yaml` — sovereign envelope (global ceiling + per-type overrides).
- Tests: `tests/unit/test_govd_envelope.py` — 18 pass, incl. live AF_UNIX socket round-trip (`test_holder_socket_roundtrip_real_unix_socket`).
- Reviewer: PASS (OV-b2003abc, network-boundary mock-only-integration override, TTL 90).
- Commit: `9e132c737`.
- Human-gated remainder (the two `[REVIEW]` ACs): deploy holder under non-agent uid + RO substrate + `chattr +a` audit (`fw ... emit-install` prints the spec); relocate `focus.yaml`/approvals/bypass-log behind the holder.

### 2026-06-18T15:03:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
