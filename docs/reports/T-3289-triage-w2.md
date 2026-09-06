# T-3289 — Observation triage, worker 2

Scope: OBS-272, OBS-273, OBS-296, OBS-297, OBS-299, OBS-300, OBS-301, OBS-302, OBS-303, OBS-304.
Each verified against current repo state (2026-09-06). Tally: **3 PROMOTE / 7 DISMISS / 0 DEFER.**

---

## OBS-272 — handover embeds global state by value (97.3% state dumps)

**Verdict: DISMISS — already fixed by T-3028.**

- T-3028 ("T-3025 GO: handover digest-plus-reference for the three dump sections") shipped exactly this fix: commit `471f054ab` "the three state dumps become count + command + top-N — 270,039 B to 17,643 B". Task is at `status: work-completed` in `.tasks/active/T-3028-*` (partial-complete, awaiting human AC).
- Live evidence: `.context/handovers/LATEST.md` is now 19,840 bytes (was 265,888 at capture); the Observation Inbox section reads "Showing 5 of 248 (urgent first, then newest). Full list: `bin/fw note triage`" — emitted by `agents/handover/handover.sh:1228`.
- The secondary half (empty learning-template sections) is already registered as G-018 in `.context/project/concerns.yaml:482` — the observation itself frames it as "G-018 with a measurement attached", so no separate task is warranted.

## OBS-273 — check-inception-schema gate catch-22 (validates disk, not the edit)

**Verdict: PROMOTE — defect confirmed live in current code, no fix since capture.**

- Proposed task: **"check-inception-schema must validate the proposed edit, not the on-disk file"** — `workflow_type: build`.
- One-line AC: an Edit/Write that adds the missing `target_blast_radius`/`voi_score` fields to an inception task that is invalid on disk passes the hook without any bypass.
- Evidence: `agents/context/check-inception-schema.py:137` still reads frontmatter from the on-disk path (`_read_frontmatter(fp)`) and never inspects `tool_input.content`/`new_string` — so the fixing edit is blocked exactly as OBS-273 describes. The only bypass remains env-only (`:149`, `FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1`), which the Write/Edit tool surface cannot carry, and the block message (`:174`) still recommends the env prefix. `git log` shows zero commits to either hook file since 2026-08-15.

## OBS-296 — TermLink hub split-brain + hub.secret absent

**Verdict: DISMISS — incident resolved same day; structural fix homed upstream (T-1333).**

- `/var/lib/termlink/hub.secret` exists on disk (`-rw------- root root`, dated 2026-08-16 20:37 — restored ~4.5h after capture), so the "any restart breaks fleet credentials" hazard is gone.
- Both cited PIDs (3093442, 3869961) no longer exist. A single hub (PID 1026708, `termlink hub start --tcp 0.0.0.0:9100`) owns `/var/lib/termlink` per `termlink hub status`. (A separate `dimitri` user hub exists but that is the sanctioned per-uid stopgap described in the T-3043 RCA §Interim workaround, not runtime-dir contention.)
- The structural fix ("hub start should detect a live hub via hub.pid and attach or fail loudly; silent takeover is what made §1.1 possible") is homed upstream as `docs/reports/T-3043-termlink-nonroot-rca.md:484` rec 5 and the upstream half was delivered to the TermLink agent 2026-08-18 (commit `1e51af07a`).

## OBS-297 — CORRECTION to OBS-295: fw-approve exists but doesn't resolve in reader's context

**Verdict: DISMISS — fold into OBS-295 (this entry is a correction, not an independent defect).**

- OBS-297's whole content is a reclassification of OBS-295's class ("names a command that does not exist" → "names a command that does not resolve in the reader's context") plus the fw-authority/REQ-xxx mismatch. OBS-295 remains pending at `.context/inbox.yaml:3703` and is the natural carrier for the promotable rail.
- The concrete gate lives in 150-skills-manager (its `bin/fw-approve`), not here: `grep -rn "fw-approve\|fw-authority" bin/ lib/ agents/ policy/` returns zero hits in this repo — there is no local fix surface. Per gap-homing (T-1333) the fix files there, and OBS-295's own text records "operator-directed fix dispatched to 150-skills-manager 2026-08-16".
- Integration note for the parent: when OBS-295 is triaged, carry OBS-297's sharpened predicate — the rail must assert the emitted remediation is absolute/project-qualified, because a binary-exists test passes on the emitting host and still ships the bug.

## OBS-299 — infisical credential gate names fw-authority, not on PATH; blocks ONEDEV_TOKEN

**Verdict: DISMISS — third instance of the OBS-295/297 class, homed in 150-skills-manager; the cited local blocker is resolved.**

- The emitting gate (`infisical_manager_get_secret` denial text) is 150-skills-manager code; this repo contains no reference to `fw-authority` (grep clean across bin/, lib/, agents/, policy/). Per T-1333 the register entry belongs where the fix lands; OBS-295 already carries the class and a fix was dispatched to the owning repo 2026-08-16.
- The concrete blocker OBS-299 named — rotated ONEDEV_TOKEN gating 16 unpushed commits — is gone: `origin/bleeding-edge` is current as of 2026-09-06 18:33 (+0200) with local HEAD only 8 ahead (normal mid-session), and the origin remote URL no longer embeds a plaintext token (`git remote -v` shows a bare https URL).
- Caveat the parent may want: this host cannot read /opt/150-skills-manager (project-boundary gate), so whether the dispatched fix covers the fw-authority/REQ-xxx variant specifically is unverified — cross-link it on OBS-295 rather than keeping a third pending copy of the same class.

## OBS-300 — spawn.py stamp_outcome erases concurrently-appended dispatch rows

**Verdict: DISMISS — already fixed by T-3042.**

- T-3042 ("update_outcome_row erases concurrently-app…") is in `.tasks/completed/`. Both sides of the race now hold the ledger's sidecar lock: `lib/spawn.py:247` wraps the whole read→replace window in `keylock.guarding(DISPATCHES_LOG)`, and the appender at `lib/resolver.py:761` takes the same lock.
- The docstring at `lib/spawn.py:229-238` documents the exact race OBS-300 reported ("CRASH-atomic is not CONCURRENCY-safe… Locking one side would have left the race exactly where it was"), and lock expiry raises loudly rather than silently dropping the outcome (`:242-246`).

## OBS-301 — "atomic write (L-493)" comment sweep is a false-safety surface

**Verdict: PROMOTE — the comments were never amended; the misleading grep surface is still live.**

- Proposed task: **"Amend L-493 atomic-write comments to state crash-atomic ≠ concurrency-safe"** — `workflow_type: refactor`.
- One-line AC: every comment matching `atomic write (L-493` also states the concurrency caveat (crash-atomic; NOT concurrency-safe — use lib/keylock for shared read-modify-write), and a grep for the unqualified form returns zero sites.
- Evidence: 15 occurrences of the unqualified comment remain across 8 files (`lib/assumption.sh` ×2, `lib/pending.sh` ×2, `lib/promote.sh`, `lib/arc.sh` ×3, `agents/audit/orchestrator-mcp-scan.sh` ×2, `agents/context/lib/focus.sh`, `agents/context/consolidate.py`, `agents/context/check-tier0.sh` ×3); `grep -rn "crash-atomic"` over lib/, agents/, bin/, web/ finds the amendment only in `lib/spawn.py` (T-3042's own docstring). The one live-bug site was fixed (OBS-300/T-3042) but the triage-misleading comment class it named is untouched.

## OBS-302 — TermLink renders failed hub RPC as legitimate empty result

**Verdict: DISMISS — homed upstream per T-1333; delivered, confirmed, and tracked upstream as their T-2791.**

- `docs/reports/T-3043-termlink-nonroot-rca.md:376-393`: "Registered as OBS-302; homed upstream per T-1333… Mechanism, supplied upstream 2026-08-18 (their T-2791)… Fix in progress upstream under T-2791." The upstream agent confirmed the mechanism from source (`discovery.rs:81-87`, `is_dir()` false on EACCES) — commit `63e291b3b`.
- Nothing in this repo can fix it (Rust client code in the TermLink repo); the local record (RCA report + inbox entry) already did its job of routing the fix.

## OBS-303 — TermLink client queues posts it never attempts ("queued" = success on permanent auth failure)

**Verdict: PROMOTE — root cause is upstream, but unlike OBS-302 there is no evidence of upstream delivery, and the local mitigation was never built.**

- Proposed task: **"Doctor rail for silent TermLink outbound-queue silt (+ hand OBS-303 upstream)"** — `workflow_type: build`.
- One-line AC: `fw doctor` emits a WARN when `termlink channel queue-status` reports pending outbound rows with `attempts=0` older than a threshold (the OBS-303 signature: queued messages that can never flush).
- Evidence: `grep -rn "OBS-303"` across docs/, .tasks/, .context/episodic/ returns zero hits outside the inbox — it was never promoted or referenced again. The T-3043 upstream handoff (commit `1e51af07a`) itemises three findings (two-auth-model root, OBS-325 socket mode, OBS-302) and does not include the queue-as-success defect. No queue-status/outbound check exists in `bin/fw`, doctor, or `agents/audit/audit.sh` (grep clean). The failure mode — sender sees success, recipient sees nothing, 14 real messages lost — is exactly the false-green class the framework rails against, and it remains undetectable today.

## OBS-304 — full fw audit >10 min, no partial output, unusable as P-011 command

**Verdict: DISMISS — superseded by its own correction chain (OBS-306, OBS-310); the real root travels as OBS-308.**

- OBS-306 (`.context/inbox.yaml`, tags: correction) opens "CORRECTION TO OBS-305 AND OBS-304 — THE AUDIT IS NOT SLOW, IT IS BLOCKED": the measured runs had ~2 CPU-seconds in 5 minutes (lock wait, not compute), and it explicitly directs "'optimise audit runtime' is the wrong lead and should not be pursued on this evidence."
- OBS-310 completes the correction: the lock holder was a working audit that exited normally after ~160s, and following the gate's own wait-then-push advice cleared the block. So the ">10 minutes and produces no verdict" premise does not describe audit runtime.
- The genuinely fixable defect underneath (audit.sh's EXIT trap unlinks the flock'd lock file; orphaned watchdog sleep) is OBS-308, which names itself "the root under OBS-304/305/306/307" and stands on its own. Keeping OBS-304 pending alongside its corrections invites re-deriving the wrong fix. Note the cron-verdict cache OBS-304 asked for already exists (`.context/audits/cron/LATEST-CRON.yaml`, since T-184/2026-02-19), and `--section` scoping already provides the "quick profile".
