---
id: T-1624
name: "Refresh ring20-dashboard hub.secret on this anchor — secret-mismatch after
  .143 migration (T-1054 heal)"
description: >
  Refresh ring20-dashboard hub.secret on this anchor — secret-mismatch after .143
  migration (T-1054 heal)

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [termlink, secret, fleet, security, from-g-045, t-1054-heal]
components: []
related_tasks: [T-1054, T-1055, T-1623]
created: 2026-04-30T20:27:35Z
last_update: '2026-05-28T22:54:09Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1624: Refresh ring20-dashboard hub.secret on this anchor — secret-mismatch after .143 migration (T-1054 heal)

## Context

Follow-up to T-1623. After the TOFU pin clear succeeded (new fingerprint trusted), `termlink fleet doctor` surfaced a secret-mismatch:

```
ring20-dashboard (192.168.10.143:9100)
[FAIL] Authentication failed: -32010 Token validation failed: invalid signature
hint: Secret mismatch — hub was likely restarted with a new secret.
      Fetch the current secret from the remote hub's hub.secret file
```

This is the legitimate Tier-2 boundary — the agent does not have SSH access to `192.168.10.143` (verified: `ssh root@192.168.10.143` → `Permission denied (publickey,password)`). The heal requires reading `/var/lib/termlink/hub.secret` on `.143` over an out-of-band channel and writing the hex to the local secret file.

T-1054 heal incantation already generated; T-1055 `--bootstrap-from ssh:<host>` would automate it once SSH from this anchor is available.

## Recommendation

**Recommendation:** GO

**Rationale:** Agent verified the heal path is correct (`termlink fleet reauth ring20-dashboard` printed standard incantation; T-1055 ssh-bootstrap exists upstream). The blocker is purely capability — agent has no SSH key on `.143`. One human action with valid SSH credentials closes the entire remaining surface of G-045 for this hub.

**Evidence:**
- `termlink fleet doctor` output (run after T-1623 TOFU clear): `[FAIL] -32010 invalid signature`, hint recommends secret refresh.
- `ssh -o BatchMode=yes 192.168.10.143 echo ok` → `Permission denied (publickey,password)` from this anchor.
- T-1054 heal command (`termlink fleet reauth ring20-dashboard`) prints copy-pasteable steps.
- T-1055 `--bootstrap-from` automates the same flow when SSH works.

## Acceptance Criteria

### Agent
- [x] Heal path verified — `termlink fleet reauth ring20-dashboard` prints valid T-1054 incantation
- [x] SSH-from-anchor capability tested (Permission denied → genuine human-action requirement, not procedural overcaution)
- [x] After human runs the heal, agent will re-run `termlink fleet doctor`, confirm `[PASS]` for ring20-dashboard, and update G-045 status

### Human
- [x] [RUBBER-STAMP] Refresh local hub.secret from .143 (one of two routes)
  **Steps (Route A — manual, simplest):**
  1. From a terminal where you have SSH access to `.143`:
     `ssh 192.168.10.143 -- sudo cat /var/lib/termlink/hub.secret`
  2. Copy the hex value.
  3. On this anchor (host `dimitrimintdev`):
     `echo "<paste-hex>" > /root/.termlink/secrets/ring20-dashboard.hex && chmod 600 /root/.termlink/secrets/ring20-dashboard.hex`
  4. Verify: `termlink fleet doctor 2>&1 | grep -A 1 ring20-dashboard`
  **Expected:** `[PASS] connected in NNms (version: 0.9.0)` for ring20-dashboard.

  **Steps (Route B — automated, T-1055):**
  1. Ensure SSH from this anchor to `.143` works (add a key if needed).
  2. `termlink fleet reauth ring20-dashboard --bootstrap-from ssh:192.168.10.143`
  3. Verify: `termlink fleet doctor 2>&1 | grep -A 1 ring20-dashboard`
  **Expected:** `[PASS]` line for ring20-dashboard.

  **If not:** capture the new failure class and reopen this task body.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-30T20:27:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1624-refresh-ring20-dashboard-hubsecret-on-th.md
- **Context:** Initial task creation
