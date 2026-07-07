---
id: T-2510
name: "Remediate audit FAILs and WARNs (cron drift, fabric drift, F-ORCH driver review)"
description: >
  Remediate audit FAILs and WARNs (cron drift, fabric drift, F-ORCH driver review)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-07T07:40:45Z
last_update: '2026-07-07T07:45:07Z'
date_finished:
---

# T-2510: Remediate audit FAILs and WARNs (cron drift, fabric drift, F-ORCH driver review)

> **ID note:** first drafted under T-2509 against a stale local master; on FF-reconcile,
> origin/master already held a completed T-2509 (Watchtower master-guard fix). Re-IDed to
> T-2510 to avoid the duplicate-id collision (T-100202 allocator-inflation class). Content
> unchanged.

## Context

Handover audit (S-2026-0707-0930) surfaced 2 FAILs (cron registry→generated→deployed drift)
and 4 WARNs (fabric: 1 orphaned card, 106/863 no-edges, 2 unregistered files; F-ORCH driver
retire_when appears met). This task remediates the mechanically-fixable items. Cron is
host-level — regenerate + install run from the MAIN checkout on master. F-ORCH retirement is a
sovereignty decision (D8) — surfaced to the operator, not auto-actioned.

## Acceptance Criteria

### Agent
- [x] Cron registry→generated drift cleared: `fw cron generate` run; audit no longer emits "Cron registry edited but not generated" (3 missing jobs now present, resolver-loop stays PAUSED)
- [x] Cron generated→deployed drift cleared: `fw cron install` run; generated crontab byte-identical to /etc/cron.d/agentic-audit-999-agentic-engineering-framework
- [x] Fabric orphaned card removed — `fw fabric drift` shows 0 orphaned (handover's 1 orphaned already cleared before this task ran)
- [x] Fabric unregistered source files registered — created cards for lib/branch-hygiene.sh + lib/hook_paths.py; `fw fabric drift` shows 0 unregistered
- [x] `fw fabric enrich` run (~29-32 edges, 14 cards). Audit no-edge count 101/865 (was 106/863) — advisory WARN NOT fully cleared: enrich is grep-based auto-inference; remaining edgeless cards are genuine leaves/configs/docs. Full clearance would need manual edge-authoring (low value for an advisory coverage metric). Documented, not silenced.
- [x] F-ORCH retire_when finding surfaced to operator as a sovereignty decision (NOT auto-retired) — recommendation recorded in ## Decisions (retire_when met: T-1643 completed + orchestrator live T-2484)
- [x] `fw audit --sections structure` re-run: **0 FAILs** (rc=1 warnings-only). Remaining WARNs: F-ORCH (sovereignty-surfaced) + fabric no-edges 101/865 (advisory, reduced from 106). Orphaned-card + unregistered-files WARNs both resolved.

## Verification

# generated == deployed (generated→deployed leg, was FAIL). `fw doctor`/`fw audit` exceed the
# 120s gate timeout on this host, so cron-sync (L-364) is verified by direct byte-comparison —
# same content the doctor "Cron registry in sync" check compares, but instant + deterministic.
diff -q .context/cron/agentic-audit.crontab /etc/cron.d/agentic-audit-999-agentic-engineering-framework
# registry→generated leg: the 3 previously-missing jobs are present in the generated crontab:
grep -q agentic-cron-resolver-loop.lock .context/cron/agentic-audit.crontab && grep -q agentic-cron-inception-retrofit-rec.lock .context/cron/agentic-audit.crontab && grep -q agentic-cron-bvp-cost-estimator-sweep.lock .context/cron/agentic-audit.crontab
# fabric drift fully clean (orphaned + unregistered both resolved); herestring avoids L-387 SIGPIPE:
out=$(bin/fw fabric drift 2>&1); grep -q "unregistered: 0, orphaned: 0" <<<"$out"

## RCA

**Symptom:** Handover audit (S-2026-0707-0930) reported 2 `[FAIL]`s — cron registry ahead of
generated crontab, and generated crontab differing from the deployed `/etc/cron.d/` copy — plus
4 `[WARN]`s (1 orphaned fabric card, 106/863 no-edge cards, 2 unregistered source files, F-ORCH
retire_when appears met).

**Root cause:** The cron chain (registry → generated → deployed) had drifted at both transitions.
Three registry jobs added on 2026-07-05 (resolver-loop-autonomous T-2491, inception-retrofit-rec
T-2208, bvp-cost-estimator-sweep) were committed to `cron-registry.yaml` but `fw cron generate`
was never run, so they never reached the generated crontab; and the last generate/install wasn't
re-deployed. The fabric WARNs were normal accretion — new lib files (branch-hygiene.sh, hook_paths.py)
landed without fabric cards, and one card outlived its file.

**Why structurally allowed:** The registry→generated→deployed drift IS gated (doctor WARN + audit
FAIL per T-1942/T-1943/T-1771), but those are *detection* rails, not *prevention* — a task that edits
the registry can still be closed without regenerating unless its own `## Verification` carries the
L-364 cron check. The three 2026-07-05 tasks landed their registry edits and the drift sat until the
daily audit surfaced it. This is the intended safety-net behaviour (detection at audit), not a new gap.

**Prevention:** Detection already exists (audit FAIL surfaced this within ~2 days, as designed). No
new gate needed. The remediation restores sync; the standing L-364 rule + daily audit cron catch the
next drift. Observation on the `lib.X` stderr leak (below) flagged as a separate cosmetic follow-up.

**Observation — `lib.X` stderr leak (cosmetic, non-fatal):** `fw cron generate` emits
`/usr/bin/python3: No module named lib.X` to stderr while returning rc=0 and producing a correct
crontab (all 25 jobs, correct active/paused split, generated==deployed verified). The string is
NOT a literal module in the code (`grep` finds only a comment at `bin/fw:3889`); `fw cron status`
and `fw version` do NOT emit it, so it is isolated to the `generate` path. Does not affect cron
correctness. Not chased to root here to avoid rabbit-holing the operator's remediation ask — flagged
for a separate follow-up.

## Decisions

### 2026-07-07 — F-ORCH retire is a sovereignty decision, surfaced not actioned

- **Chose:** Surface the F-ORCH retire_when finding to the operator; do NOT auto-retire.
- **Why:** Retiring a value driver mutates `policy/value-drivers.yaml` scoring policy — a D8
  sovereignty boundary (only the human retires drivers). The audit line is WARN-only and
  explicitly says "review whether to retire".
- **Evidence the condition is met:** F-ORCH `retire_when` = "orchestrator substrate (T-1643)
  lands in production." T-1643 is in `.tasks/completed/`; the orchestrator is live
  (`fw resolver run/pick` dispatches real workers, litellm :4000 + systemd — T-2484). The
  differentiating axis F-ORCH scored (orchestration leverage) is now baseline capability.
- **Operator options (numbered for reply):**
  1. **Retire F-ORCH** — comment it out / move to a candidates section in `policy/value-drivers.yaml`. (Recommended — the condition it was created to track is satisfied.)
  2. **Keep + re-scope** — rewrite `retire_when` if orchestration leverage is still a scoring axis worth keeping distinct from D1-D4.
  3. **Silence the advisory only** — `fw config set FW_RETIRE_WHEN_ADVISORY 0` (keeps the driver, stops the WARN). Not recommended — hides the signal.
- **Rejected:** Auto-editing value-drivers.yaml (sovereignty violation); `--force`-style silencing without operator sight.

## Updates

### 2026-07-07 — remediation executed + re-IDed T-2509→T-2510
- **Action:** cron generate+install (registry→generated→deployed resynced), fabric register+enrich (drift 0/0/0), F-ORCH surfaced. Re-IDed from T-2509 (collision with completed Watchtower task on origin).
