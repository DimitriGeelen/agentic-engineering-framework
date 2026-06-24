# T-2494 — RCA: host deployment is whack-a-mole

**Status:** inception / RCA
**Trigger:** Operator, mid-deploy: *"please lets RCA this and remediate structurally i feel like where playing whack a mole the whole time."* — then: *"what purpose does the cronjob deploy serve?"*
**Origin session:** going live with the `fw resolver loop` autonomous cron (T-2491/T-2493).

---

## Symptom

Making one feature (the autonomous dispatch loop) *live and executable on the host*
required discovering and clearing **nine separate, unanticipated blockers in sequence**,
each found reactively only when the previous one was cleared. It felt like — and
structurally was — whack-a-mole.

## The reframing question (operator): "what purpose does the cron deploy serve?"

The cron entry `resolver-loop-autonomous` runs `fw resolver loop --dispatch --max 1` every
30 min. Its **only** added purpose is **unattended, scheduled autonomy** — the orchestrator
selecting + dispatching one eligible task on a timer with *no human or agent present*.

Everything else already works **on-demand**: selection (`fw resolver pick`), dispatch
(`fw resolver loop --dispatch`), capture — all proven live this session. The cron adds the
single increment "runs itself continuously."

That increment is **simultaneously the highest-risk piece** (unattended workers mutating
the repo) **and the source of nearly all the whack-a-mole** (moles #5–#9 below are *only*
about getting the host-cron path live). So the operator's question is the key insight:
**we reached for the heaviest deployment vehicle (host cron across the full topology) for a
capability that doesn't yet need scheduling — and cron may be the wrong vehicle entirely.**

Recognizing this **collapses most of the whack-a-mole**: drop the cron deploy for now, run
the loop on-demand (already sufficient to use and prove autonomy), and treat *"what is the
right trigger mechanism for unattended autonomy"* as a first-class design question (IW-1).

## The moles (this session's "go live" arc)

| # | Mole | Plane / seam | Cron-path only? |
|---|------|--------------|-----------------|
| 1 | OneDev origin 502; push failed | external (recovered) | no (any land) |
| 2 | `fw integrate` refused on mis-classified `.context/working/*` churn | data-classification seam (T-2472 class) | no (any land) |
| 3 | Vendored `.agentic-framework/` diverged → `fw vendor self` | install-vendor plane | no (any land) |
| 4 | Active-task gate blocked post-completion read-only checks (focus null) | governance seam (T-2054 class) | no (every session) |
| 5 | Host install `/root/.agentic-framework` stale (OBS-087 exec-bit) | install plane staleness | **yes** |
| 6 | `/root/.agentic-framework` tracks GitHub mirror, behind OneDev → `fw mirror sync` | mirror-hop | **yes** |
| 7 | MAIN on divergent `t2417-fw-sessions`, 149 dirty → code-only go-live (T-2483) | MAIN-code plane | **yes** |
| 8 | Go-live syncs **code only**; cron registry entry is **`.context/` data** → not propagated | code-vs-data plane split | **yes** |
| 9 | `PROJECT_ROOT` ambiguity (worktree / MAIN / install) surfaced mid-deploy | topology under-specification | **yes** |

**5 of 9 moles (#5–#9) exist *only because we chose the host-cron deploy path*.** They are
not intrinsic to the feature.

## The deployment topology (implicit today)

A feature must traverse a **7-transition chain across 6 locations and 3 planes** to be
live-and-executable on a host cron:

```
 PLANE: code ───────────────►  PLANE: vendored install ──►  PLANE: data/schedule
 worktree ──(integrate)──► OneDev origin/master ──(mirror sync)──► GitHub mirror
        │                                                              │
        │                                                  (git pull) ▼
        │                                            /root/.agentic-framework  (host fw: shim + cron binary)
        │                                                              │
        └──(integrate-go-live, code-only)──► /opt/999 MAIN (t2417)     │
                                                  │                    │
                                   registry entry │ (DATA — manual)    │
                                                  ▼                    │
                                   .context/cron-registry.yaml         │
                                                  │ (cron generate)    │
                                                  ▼                    │
                                        generated crontab ──(cron install)──► host crontab
                                                                       │
                                                            (runtime) ▼
                                              cron runs: /root/.agentic-framework/bin/fw
                                                         with PROJECT_ROOT=<?>
                                                                       │
                                                            EXECUTABLE? ◄── L-365 seam
```

Every arrow is a transition with its own tool, its own staleness, its own drift class.
**No artifact declares this graph; no command drives or verifies it end-to-end.**

## 5-Whys → structural root

1. **Why whack-a-mole?** Each deploy hop surfaced an unanticipated blocker.
2. **Why unanticipated?** The full chain (land → mirror → host-install → MAIN-code →
   registry → crontab → executable) is driven by hand; nothing models it as a plan.
3. **Why by hand?** The hops exist only as *independent* tools — `fw integrate`,
   `fw mirror sync`, `integrate-go-live.sh`, `fw vendor self`, `fw cron generate|install` —
   with no composition over them.
4. **Why no composition?** Each tool solved its *own local transition*. No component owns
   the end-to-end "feature is live **and executable**" path. The **seams between tools are
   unmodeled** — `L-365 "deployed ≠ executable"` is a named symptom of exactly one seam.
5. **Why are the seams unmodeled?** The deployment **topology** (6 locations × 3 planes ×
   7 transitions) is **implicit tribal knowledge**, never declared as a checkable graph.

**Root cause:** rich, correct tooling for *each* transition; **no declared deployment
topology and no end-to-end orchestrator/verifier over it.** "Go live" is re-derived by hand
every time, so undeclared seams surface one at a time as moles. **Secondary root:** the
*default reflex* is to deploy via the maximal vehicle (host cron) even when a lighter
trigger would serve — amplifying the topology cost (the operator's question caught this).

## Why this generalizes (not just this session)

Same root → a long tail of sibling incidents, each an unmodeled deploy seam: **L-364/L-365**
(deployed ≠ executable), the **cron registry→generated→deployed** triple-drift chain,
**OBS-080** (worktree root resolution), **OBS-085/086/087** (go-live timestamp/merge/exec-
bit), **T-2472** (churn mis-classification), the vendored-lib divergence class (T-2455).
They keep being whacked individually because the topology connecting them is invisible.

This is the **same antifragility class** the framework already solved *locally* for cron
(three transitions, three doctor/audit drift checks). The fix is to lift that pattern to
**deploy scale.**

## Structural remediation candidates

- **D (IW-1) — Trigger-mechanism review** *(do first)*: decide whether unattended autonomy
  rides a host **cron** at all, vs a **systemd service** (co-located, like litellm), the
  **already-running watchtower/orchestrator process**, or an **event-driven** trigger (on
  task create/status-change). The right trigger may **eliminate moles #5–#9 permanently**.
- **C (IW-2) — Declared topology manifest** (`policy/deploy-topology.yaml`): declare
  locations, planes, transitions, and the tool + staleness-check for each. Makes tribal
  knowledge explicit + machine-readable. *Foundational — A and B read it.*
- **A (IW-2) — `fw deploy status <commit>` ("deploy doctor")**: for a given commit, report
  live-status across every node — on origin? mirror? `/root/.agentic-framework`? MAIN code?
  MAIN registry? host crontab? **executable** (dry-run the deployed command)? One command
  answers *"what's left to make this live."* *Observability before automation.*
- **B (IW-3) — `fw release` / `fw deploy run` orchestrator**: composes land → mirror →
  go-live → vendor → cron-install with per-transition verification + a final **executable**
  check; dry-run first; resumable.

**Sequencing (recommended):** D → C → A → B. Answer "what triggers autonomy" first (it may
delete half the topology), then declare the graph, make it observable (deploy-doctor), then
drive it (orchestrator). Mirrors the framework's "observability before self-improvement"
discipline (orchestrator `status` shipped before `improve`).

## Recommendation

**GO** — lead with **D** (trigger-mechanism review) because the operator's question exposes
that the cron deploy may be premature/wrong-vehicle; then **C + A** (declare + deploy-doctor)
so the next go-live is never blind; **B** (orchestrator) as a fast follow. Evidence base: a
walked 9-mole arc with a clean 5-Whys to a single root + a secondary "maximal-vehicle
reflex" root; the fix is a proven framework pattern (local cron-chain drift checks) lifted
to deploy scale; A alone removes the whack-a-mole on the next go-live, and D may remove most
of it structurally.

## Current deploy state (for resumability — loop go-live is PAUSED here)

- origin/master (OneDev): **327714e3f** ✓; GitHub mirror: **327714e3f** ✓
- `/root/.agentic-framework`: **327714e3f** ✓ (`resolver loop` verified working)
- `/opt/999` MAIN (t2417-fw-sessions): code synced to master via `integrate-go-live`
  (`resolver loop` verified working); `.context/` data untouched
- **Not done (deliberately):** resolver-loop cron entry not in MAIN's registry; host
  crontab not installed. The loop runs **on-demand** anywhere (`fw resolver loop
  --dispatch`); it is simply not *scheduled*. Resuming the cron = exactly moles #8/#9 —
  which is why we stopped to fix the root (and question the cron) instead.

## Dialogue Log

- **Operator (mid-deploy):** *"please lets RCA this and remediate structurally i feel like
  where playing whack a mole the whole time."* → Course correction: stop clearing deploy
  blockers one-by-one; find + fix the structural root. Outcome: this RCA + inception T-2494.
- **Operator (follow-up):** *"what purpose does the cronjob deploy serve?"* → Reframe: the
  cron's only added value is *scheduled unattended* autonomy; the loop already runs
  on-demand. Exposed (a) the cron deploy may be premature, (b) cron may be the wrong
  vehicle, (c) moles #5–#9 are *cron-path-only*. Drove remediation candidate **D**
  (trigger-mechanism review) to the front of the sequence.
- **Operator:** *"proceed as suggested."* → Drop the cron deploy (host crontab confirmed
  clean, registry re-paused); execute **D** (below).

---

## D — Trigger-mechanism review (IW-1) — RESOLVED

**Question:** what should trigger unattended autonomous dispatch (`fw resolver loop
--dispatch`)?

| Option | Persistence | PROJECT_ROOT | Deploy cost | Observability | Moles eliminated |
|--------|-------------|--------------|-------------|---------------|------------------|
| **Host cron** (attempted) | crontab (host) | ambiguous (templated) | 7-transition chain | syslog only | none — *causes* #5–#9 |
| **systemd timer** (off canonical MAIN) | native (`enable`) | pinned by `WorkingDirectory=` | 1 declarative file in `deploy/` | `systemctl status` / `journalctl` | **#7, #8, #9; #5/#6 sidestepped** |
| Watchtower process scheduler | tied to web proc | Watchtower's project | code, but couples autonomy to web app | Watchtower UI | #7,#8 — but couples concerns |
| Event-driven (hook on task change) | needs a daemon anyway | n/a | hook + daemon | — | doesn't solve "unattended" alone |

**Decision: systemd timer, co-located with the litellm lane.** Rationale:

1. **The loop's runtime dependency is already systemd** — `deploy/litellm-proxy.service`
   (T-2490). Autonomy should ride the same lane as the runtime it needs, not a parallel
   cron topology.
2. **Run it entirely off the canonical MAIN checkout.** `ExecStart=/opt/999.../bin/fw` +
   `WorkingDirectory=/opt/999...` means the loop uses MAIN's own `fw` and MAIN as
   `PROJECT_ROOT` — **no `/root/.agentic-framework` dependency at all** (moles #5/#6 become
   irrelevant to the loop), **no crontab** (mole #7 gone), **no `.context` registry entry**
   (mole #8 gone — the unit is a code-plane file in `deploy/`), **PROJECT_ROOT pinned** in
   the unit (mole #9 gone). The *only* remaining requirement is "MAIN's code is current",
   which `integrate-go-live` already handles and is now done.
3. **Native observability + persistence** — `systemctl status resolver-loop.timer`,
   `journalctl -u resolver-loop.service`, survives reboot via `enable`. The cron path had
   neither cleanly.

### Proposed units (design — ship on GO, operator installs)

`deploy/resolver-loop.service` (oneshot, fired by the timer):
```ini
[Unit]
Description=AEF autonomous dispatch loop (one tick)
After=network-online.target litellm-proxy.service
Wants=litellm-proxy.service

[Service]
Type=oneshot
WorkingDirectory=/opt/999-Agentic-Engineering-Framework
# fw + PROJECT_ROOT both = the canonical MAIN checkout; no host-vendored-install dep
ExecStart=/opt/999-Agentic-Engineering-Framework/bin/fw resolver loop --dispatch --max 1 --cooldown-min 30
```

`deploy/resolver-loop.timer`:
```ini
[Unit]
Description=AEF autonomous dispatch loop — every 30 min

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min
Persistent=true

[Install]
WantedBy=timers.target
```

Install (operator, one block — the consequential "go autonomous" act stays human):
```
sudo cp deploy/resolver-loop.service deploy/resolver-loop.timer /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now resolver-loop.timer
```

**This is the mole-free path to scheduled autonomy.** The strategic remainder of this
inception (declared topology `policy/deploy-topology.yaml` + `fw deploy status` deploy-
doctor, IW-2/IW-3) stands as the generalized fix so the *next* feature's go-live is never
blind — but it is no longer on the critical path for *this* feature.
