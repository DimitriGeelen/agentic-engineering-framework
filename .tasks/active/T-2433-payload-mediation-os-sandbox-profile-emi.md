---
id: T-2433
name: "payload-mediation: OS sandbox profile emit/install (net-pin + RO substrate
  + uid)"
description: >
  fw sandbox emit-profile from known governance-substrate paths / sudo fw sandbox
  install (Lock-1 Part 1, root-only). netns egress-pin to proxy + RO substrate + uid
  demotion. Build-decision: systemd vs bwrap vs rootless podman. Gated on T-2428 GO.

status: started-work
arc_id: payload-mediation
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
created: 2026-06-18T07:18:44Z
last_update: 2026-09-20T08:22:53Z
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
  - ts: '2026-07-07T08:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=173,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-07T08:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-08T08:15:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2433: payload-mediation: OS sandbox profile emit/install (net-pin + RO substrate + uid)

## Context

Design of record: `docs/reports/T-2428-payload-mediation-design.md` §7a (sandbox
deep-dive, host-grounded). The cage = the S3+S4+S5 sandbox laid *above* the agent
(the agent runs as `root` today — uid demotion *is* the boundary).

**Mechanism (host-grounded 2026-06-18; OPEN tier fork):** the sandbox does
*active per-operation mediation* at a hardware boundary (hypervisor model), NOT a
static namespaces cage. `/dev/kvm` + AMD-V present. Three-tier choice (design doc
§7a): namespaces+seccomp (weakest, superseded) / **gVisor** (every syscall,
semantic) / **microVM** (I/O+net at virtio backends, native compute, strongest).
DECIDED 2026-06-18: microVM target (kata + Cloud-Hypervisor/Firecracker + custom virtio-fs/virtio-net backends as the effects-decider); gVisor fallback. Landlock + nftables remain a static floor inside the tier.
Linux-only acceptable (portability lives at the proxy). The VMM's virtio backends
are the effects-decider (twin of the proxy). NB: sandbox mediates EFFECTS only —
mechanism/choice governance is the proxy (§4b).

**Dependency: T-2430 (privileged state-holder) lands first** — the RO/RW fs
partition is only clean once trusted state (focus/approvals/bypass log) is
relocated out of agent scratch. Build order: T-2430 -> T-2433.

**Emit/install split (§4c):** `fw sandbox emit-profile` (agent-safe) /
`sudo fw sandbox install` (human/root only, Lock-1 Part 1). Gated on T-2428 GO.

## Acceptance Criteria

### Agent
<!-- Provisional at filing; T-2428 went GO. Slice 1 (2026-09-20) landed the tier-independent
     STATIC FLOOR (A3, A4, A5). A1, A2, A6 stay open — see Evolution for why each is
     blocked on a host-level or human-only action rather than on effort. -->
- [ ] microVM feasibility-validated: CC+TermLink+wrapper run inside a kata/microVM
      with substrate RO + egress-pin (no-GO spike, sibling of T-2429); gVisor fallback if it fails
      — BLOCKED: no VMM / kata / runsc on the host (`command -v` all absent, 2026-09-20);
      installing one is a host-level change → Human AC H2 below
- [ ] `fw sandbox emit-profile` generates the chosen tier's profile (VMM/virtio or
      runsc config) + Landlock static-floor ruleset + nftables egress ruleset from
      the framework's governance-substrate path list
      — PARTIAL: nftables ruleset + systemd static-floor unit + resolved manifest are
      emitted (`lib/govd_sandbox.py`); the tier profile is NOT emitted (nothing on the
      host can validate it — see Evolution) and Landlock is realised as systemd
      `ReadOnlyPaths=` rather than a separate ruleset (no Landlock applier on the host)
- [x] Profile marks RO (framework code, .claude+hooks, .git, policy/proxy config,
      trusted-state store) and RW (working tree, .tasks/, docs/, scratch .context/)
      — `policy/sandbox-profile.yaml` → `ReadWritePaths=<root>` with the substrate nested
      `ReadOnlyPaths=`; inner-RO-wins pinned live with `systemd-run` on this host
- [x] nftables ruleset permits egress only to the proxy address; default-deny
      — `policy/sandbox-profile.d/aef-agent-egress.nft`: uid-keyed OUTPUT chain, one accept
      (proxy), `counter log … drop`; `nft -c -f` passes without the user existing
- [x] emitted-but-not-installed drift surfaces in `fw doctor` + audit (reuse cron/MCP class)
      — two legs by sha256: stale (source edited, not re-emitted) and drift (emitted,
      deployed copy differs); `fw doctor` WARN/SKIP block + `audit.sh` block routed on
      `fw sandbox status` exit codes exactly like the MCP-manifest block
- [ ] Validation: CC + TermLink + wrapper run under `User=aef-agent` + RO substrate
      + egress-pin (T-1660 mid-session-userns failure does not recur at clean-uid-exec)
      — BLOCKED on install (human/root, Lock-1 Part 1): the user, the nft load and the
      unit activation are H1's steps; `fw sandbox install` refuses under the agent by design

### Human
- [ ] [REVIEW] Install the static floor and run the deciding validation (design §7a)
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw sandbox spec` — read the install spec; it is the exact command list below
  2. `cd /opt/999-Agentic-Engineering-Framework && systemd-analyze verify policy/sandbox-profile.d/aef-agent.service && nft -c -f policy/sandbox-profile.d/aef-agent-egress.nft` — both must exit 0 before anything is deployed
  3. `sudo useradd --system --uid 1999 --shell /usr/sbin/nologin --home-dir /var/lib/aef-agent aef-agent`
  4. `cd /opt/999-Agentic-Engineering-Framework && sudo bin/fw sandbox install && bin/fw sandbox status`
  5. `sudo nft -f /etc/aef-sandbox/aef-agent-egress.nft && sudo install -m 0644 /etc/aef-sandbox/aef-agent.service /etc/systemd/system/aef-agent.service && sudo systemctl daemon-reload`
  6. Substitute the real launch line for `ExecStart=` if `claude-fw --termlink` is not on the unit's PATH, then `sudo systemctl start aef-agent.service && journalctl -u aef-agent.service -n 50`
  **Expected:** step 4 prints `OK  sandbox profile emitted and deployed copies match`; step 6 shows the harness starting as uid 1999 with the working tree writable and `bin/`, `lib/`, `.git/` refused on write; `journalctl -k | grep 'aef-sandbox drop'` shows any non-proxy egress being dropped. That is A6.
  **If not:** if the unit fails at start, `systemctl status aef-agent.service` names the offending directive — `ProtectSystem=strict` + `ReadWritePaths=` is the usual culprit when the working tree is a symlink or a separate mount; note it on this task and leave the profile deployed. If the harness needs a second egress (Watchtower on the LAN IP is the obvious one), add an `extra_allow` row to `policy/sandbox-profile.yaml`, re-run `bin/fw sandbox emit-profile`, and repeat step 4-5 — the drift rails will show you the stale/drift states in between.

- [ ] [REVIEW] Decide whether the agent may install a VMM on this host for the A1 feasibility spike
  **Steps:**
  1. Read design §7a "Mechanism decision" (`docs/reports/T-2428-payload-mediation-design.md`) — microVM target (kata + Cloud-Hypervisor/Firecracker), gVisor `runsc` fallback; the host has `/dev/kvm` + AMD-V and none of the tooling
  2. Either install one yourself (`kata-containers` + `cloud-hypervisor`, or `runsc`) and note which on this task, or record here that the agent may do so under its own task
  **Expected:** one line under `## Decisions` naming the tier tooling and who installs it. A1 and the tier half of A2 become executable only after that.
  **If not:** leave A1/A2 open — the static floor (A3-A5) stands on its own and the drift rails keep it honest; nothing regresses by waiting.
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

# Slice 1 — static floor (A3, A4, A5). Pins structure, never live host state (T-3326).
python3 -m pytest tests/unit/test_govd_sandbox.py -q
test -f policy/sandbox-profile.yaml && test -f policy/sandbox-profile.d/aef-agent.service && test -f policy/sandbox-profile.d/aef-agent-egress.nft
# committed artefacts are a fresh render of the committed source (stale class at close time)
out=$(bin/fw sandbox status 2>&1); echo "$out" | grep -q 'sandbox profile'
# the host checkers the install spec runs first — scoped, so a checker-less CI host passes
command -v systemd-analyze >/dev/null && systemd-analyze verify policy/sandbox-profile.d/aef-agent.service || true
command -v nft >/dev/null && [ "$(id -u)" = "0" ] && nft -c -f policy/sandbox-profile.d/aef-agent-egress.nft || true
# Lock-1 boundary at the verb: install refuses under the agent (exit 3) before touching anything
! CLAUDECODE=1 bin/fw sandbox install >/dev/null 2>&1
# drift rails are wired on both surfaces
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q 'sandbox profile'
grep -q 'sandbox profile: FAIL' agents/audit/audit.sh
bin/fw vendor self --check

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

### 2026-09-20 — the floor is landable, the tier is not (yet)
- **What changed:** At filing the six ACs read as one build. On the host today they are
  two: the tier-independent static floor (§7a "Profile content") needs only systemd 255
  + nftables, both present and both *checkable before install* (`systemd-analyze verify`,
  `nft -c -f`); the active tier (microVM / gVisor) needs a VMM or `runsc`, and
  `command -v kata-runtime cloud-hypervisor firecracker runsc` returns nothing. Emitting a
  kata/Cloud-Hypervisor profile now would be config with no check behind it — the
  reliable-but-ungated state — so it was not emitted.
- **Plan impact:** A2 splits along that line: its nftables half is landed, its
  Landlock half is realised as systemd `ReadOnlyPaths=` (no Landlock applier on the host;
  the RO invariant is the same, kernel-enforced via mount namespace instead of LSM), and
  its tier half waits on H2. A1 and A6 are host-level / human-only by design and became
  Human ACs H2 and H1.
- **Triggered:** nothing new filed — the split lives inside this task; T-2434 (the demo)
  stays gated on H1 landing.

### 2026-09-20 — two things the design assumed that had to be pinned, not assumed
- **What changed:** (1) systemd's nesting rule: the design partitions "working tree RW,
  substrate inside it RO" and nothing in the doc says which wins when an RO entry sits
  inside an RW tree. Pinned live with a transient `systemd-run` unit under
  `ProtectSystem=strict`: the inner RO entry wins. (2) nftables resolves user names at
  parse time, so a `meta skuid "aef-agent"` rule fails `nft -c` until the user exists —
  which inverts the emit-before-install order. The profile therefore carries a fixed
  numeric uid (1999) that the install spec's `useradd --uid` matches.
- **Plan impact:** both are now test-pinned (`test_unit_render_carries_the_partition`,
  `test_emitted_nft_passes_syntax_check`) and documented in the source file's comments.
- **Triggered:** none.

### 2026-09-20 — the floor blocks two things the harness uses today
- **What changed:** With egress pinned to the proxy, the agent uid cannot reach
  Watchtower on the LAN IP (verification lines curl it) nor the TermLink hub over IP.
  The design says "one route out" and that the active tier is where further destinations
  get mediated; the floor deliberately does not pre-admit them.
- **Plan impact:** none to the build — `extra_allow` rows in the source are the
  sovereign-editable escape, and the stale/drift rails make a forgotten re-emit visible.
  Named in H1's *If not* so the operator meets it with the answer in hand.
- **Triggered:** none filed; it is an operator ruling at install time, not a build gap.

## Decisions

### 2026-09-20 — floor before tier
- **Chose:** Land the tier-independent static floor (systemd unit + nftables + manifest)
  now; leave the microVM/gVisor tier un-emitted until a VMM exists on the host.
- **Why:** Every emitted artefact has a host checker that runs *before* install; the tier
  config would have none. The design already separates "floor inside whichever tier" from
  the tier itself, so the split does not re-open the (operator-confirmed) microVM decision.
- **Rejected:** emitting a kata/Cloud-Hypervisor profile blind (ungated config);
  installing a VMM on the host under this task (host-level change with cross-project
  blast radius — Sovereign, raised as H2).

### 2026-09-20 — RO invariant via systemd, not a separate Landlock ruleset
- **Chose:** Realise the RO substrate with `ProtectSystem=strict` + nested
  `ReadOnlyPaths=` rather than emitting a Landlock ruleset.
- **Why:** No Landlock applier exists on the host, so a ruleset file would be unverifiable
  and unapplied; systemd's mount-namespace RO is kernel-enforced, verifiable with
  `systemd-analyze verify`, and was pinned live. Landlock can be added *inside* the unit
  later if a launcher that applies it lands.
- **Rejected:** writing a Python Landlock launcher in this slice (new privileged
  component, out of the AC's scope; the floor would grow a TCB the design did not ask for).

### 2026-09-20 — install deploys files only
- **Chose:** `fw sandbox install` copies the three artefacts to `/etc/aef-sandbox` and
  stops; `useradd`, `nft -f` and `systemctl` stay explicit lines in the printed spec.
- **Why:** Same shape as `fw policy install` (T-2432); the activation steps are the
  ones with host-wide effect and the human should run them one at a time, reading each.
- **Rejected:** a one-shot `install --activate` (hides the three host-mutating steps
  behind one verb — exactly the opacity Lock-1 exists to remove).

## Recommendation

**Recommendation:** GO — deploy the static floor (H1); decide the tier tooling separately (H2).

**Rationale:** Slice 1 lands the tier-independent floor with every artefact checked on this
host before install (`systemd-analyze verify` rc=0, `nft -c` rc=0, 18/18 unit tests, doctor
+ audit drift rails, vendor in sync, install refusal pinned at the verb). Nothing regresses
by installing it: it constrains a uid that does not yet exist. The remaining ACs are not
effort-blocked — A1 needs a VMM on the host, A6 needs the install that is human-only by
design. Both are yours; the task file carries the exact command list.

**Evidence:**
- `lib/govd_sandbox.py` (emit/status/spec/install), `policy/sandbox-profile.yaml` (source),
  `policy/sandbox-profile.d/` (three emitted artefacts), `bin/fw sandbox`, doctor + audit blocks
- `python3 -m pytest tests/unit/test_govd_sandbox.py -q` → 18 passed
- `bin/fw sandbox status` → `SKIP … emitted but not installed`, exit 0; `CLAUDECODE=1 bin/fw sandbox install` → exit 3
- Nesting semantics + numeric-uid parse pinned live on this host, 2026-09-20 (see Evolution)

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-18T07:18:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2433-payload-mediation-os-sandbox-profile-emi.md
- **Context:** Initial task creation

### 2026-09-20T08:22:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
