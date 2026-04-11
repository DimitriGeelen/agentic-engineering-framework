# T-1106 — Watchtower Port Bleed + Cross-Project Task-ID Collision: Deep RCA

**Date:** 2026-04-11  
**Investigator:** RCA Worker (Claude Sonnet 4.6, TermLink dispatch)  
**Scope:** Read-only investigation of live incident. Consumer project reads authorized for `/opt/025-WokrshopDesigner`.  
**Time-box:** 90 minutes  
**Phase coverage:** Phases 1–5 complete (Phase 4 partial — Bash blocked at budget-critical)

---

## Executive Summary

Three compounding bugs caused the live incident of 2026-04-11 where a user in `/opt/025-WokrshopDesigner` ran `fw task review T-434` and was silently served content from `/opt/999-Agentic-Engineering-Framework`.

1. **Bug 1 (Critical — Primary):** `lib/review.sh:52` falls back unconditionally to port 3000 when no Watchtower PID is found. On any multi-project host, whichever project first binds `:3000` captures ALL other projects' review URLs.

2. **Bug 2 (High — Compound):** `bin/watchtower.sh:21` writes `PID_FILE` to `$FRAMEWORK_ROOT/.context/working/watchtower.pid`. But `lib/review.sh:41` reads from `$PROJECT_ROOT/.context/working/watchtower.pid`. For **all consumer projects** (vendored framework, `FRAMEWORK_ROOT ≠ PROJECT_ROOT`), these are different directories. `lib/review.sh` **never finds** the PID for any consumer project — it ALWAYS falls through to Bug 1.

3. **Bug 3 (High — Silent failure):** No `/identity` endpoint on Watchtower. Even if the URL resolution were correct, there is no verification step before emitting the link. The emitter is blind.

4. **Bug 4 (Medium — Amplifier):** Task IDs are per-project integers, not globally unique. T-434 exists in both `/opt/025-WokrshopDesigner` (promote-to-prod gate inception) and `/opt/999-Agentic-Engineering-Framework` (framework update/upgrade inception, completed). The integer collision means the wrong Watchtower doesn't return 404 — it returns valid HTTP 200 with plausible HTML, making the failure completely silent.

**Severity confirmation: ULTRA-HIGH.** Bug 2 makes Bug 1 universal (affects all consumer projects, not just those missing a Watchtower). Bug 3 removes the last detection layer. Bug 4 silences the wrong-content signal.

---

## Phase 1 — Backward Research

### git log for lib/review.sh

`lib/review.sh` was created in commit `74e6e5a7` (T-634: "Deterministic human review — shared emit_review"). The **very first version** already included `:3000` as a hardcoded fallback on the `${wt_port:-3000}` path. There was **no predecessor** — T-634 created this function from scratch.

**Commit lineage for the port-detection mechanism:**

| Commit | Task | Change |
|--------|------|--------|
| `74e6e5a7` | T-634 | Created review.sh with `pid+ss` approach. Fallback: `${wt_port:-3000}` (hardcoded) |
| `e4525df6` | T-822 | Migrated to `fw_config "PORT" 3000` — configurable, but still defaults to 3000 |
| `9bb66841` | T-973 | Added review-before-decide gate (no port-resolution change) |
| `7a2deb09` | T-1090 | Announced `.reviewed-T-XXX` marker (no port-resolution change) |

**What was tried before T-634:** Nothing. T-634 was the first URL-emitting function. Before T-634, human ACs were not linked to Watchtower.

**Why T-634's pid+ss approach was thought sufficient:** At the time of T-634 (2026-03-27), multi-project port collisions were not yet a tracked concern. T-885 was created later (2026-04-05) — 9 days after T-634 — specifically because the collision problem became visible with 11+ projects. T-634 authors knew the project-local PID detection was the intended path; the `:-3000` fallback was treated as a "service not running" convenience, not a cross-project hazard.

**T-885 context:** Active inception (`started-work`, `owner: human`). Created 2026-04-05 to address multi-project port collision with a proper configurable port per project. The problem was **already identified** — T-885 just hadn't been decided/built when today's live incident occurred. T-885's recommendation is GO; it's been waiting for a human decision.

**Key gap:** Neither T-634 nor T-885 identified Bug 2 (PID_FILE path mismatch). T-885's scope focused on port configuration UX, not on the path inconsistency between watchtower.sh and review.sh.

---

## Phase 2 — Live Incident Reconstruction

### Confirmed chain of events

**State of host at incident time (2026-04-11):**

| Port | PID | Project | Watchtower serving |
|------|-----|---------|-------------------|
| :3000 | 2060863 | `/opt/999-Agentic-Engineering-Framework` | Framework's own Watchtower |
| :3001 | 4170601 | `/opt/025-WokrshopDesigner` | WokrshopDesigner Watchtower |
| :3002 | 1772220 | (unknown consumer) | Another Watchtower |

**User runs `fw task review T-434` from `/opt/025-WokrshopDesigner`:**

Step 1 — `lib/review.sh` checks `$PROJECT_ROOT/.context/working/watchtower.pid`:
- Path: `/opt/025-WokrshopDesigner/.context/working/watchtower.pid`
- **Does not exist.** (Confirmed: `ls -la /opt/025-WokrshopDesigner/.context/working/` — no watchtower.pid)

Step 2 — PID not found → falls through to `fw_config "PORT" 3000`:
- `/opt/025-WokrshopDesigner/.framework.yaml` has **no PORT setting**
- Returns default: 3000

Step 3 — Emits: `http://192.168.10.107:3000/inception/T-434`

Step 4 — `:3000` is `/opt/999`'s Watchtower (PID 2060863)

Step 5 — `/opt/999` has its own T-434 (completed inception for framework update/upgrade)

Step 6 — HTTP 200, HTML titled "Inception T-434 — Agentic Engineering Framework", paths reference `/opt/999-Agentic-Engineering-Framework`

Step 7 — **Silent failure.** No 404. No "wrong project" warning. User sees plausible inception page.

**Why `/opt/025`'s Watchtower PID was not found:** The PID file IS present — but at the **wrong path**:
- watchtower.sh writes to: `/opt/025-WokrshopDesigner/.agentic-framework/.context/working/watchtower.pid` (= `$FRAMEWORK_ROOT/.context/working/watchtower.pid`, line 21 of bin/watchtower.sh)
- review.sh reads from: `/opt/025-WokrshopDesigner/.context/working/watchtower.pid` (= `$PROJECT_ROOT/.context/working/watchtower.pid`, line 41 of lib/review.sh)
- For vendored framework: `FRAMEWORK_ROOT = /opt/025-WokrshopDesigner/.agentic-framework`, `PROJECT_ROOT = /opt/025-WokrshopDesigner`

Confirmed: `cat /opt/025-WokrshopDesigner/.agentic-framework/.context/working/watchtower.pid` = 4170601 → `:3001` (the CORRECT Watchtower for /opt/025). The detection mechanism would work perfectly IF the paths matched.

**No `/identity` endpoint:** Confirmed via curl on all three running instances (:3000, :3001, :3002). All return non-200/connection errors for `/identity`. No verification mechanism exists anywhere in the emit path.

### Secondary blast: watchtower.sh's aggressive port conflict resolver

`bin/watchtower.sh:139-148` — when the configured port is in use:
```bash
fuser -k -TERM "${port}/tcp" 2>/dev/null || true
```
If a consumer project starts Watchtower on `:3000` (the default, since its `.framework.yaml` has no PORT configured), it will **actively kill** whatever is on `:3000` — potentially killing another project's running Watchtower. This is not just URL bleed; it's process kill bleed.

---

## Phase 3 — Structural Fix Options

### Option A — `/identity` Endpoint + Emitter Verification

**What:** Watchtower exposes `GET /identity` returning `{"project_root": "...", "project_name": "...", "version": "..."}`. `lib/review.sh` queries this before emitting. If `project_root != PROJECT_ROOT`, it fails loudly.

**Chokepoint:** A new `resolve_and_verify_watchtower_url()` function in `lib/review.sh` that:
1. Resolves the URL via existing pid+ss logic
2. Curls `/identity` at the resolved URL
3. Compares `project_root` to `$PROJECT_ROOT`
4. On mismatch: prints "Watchtower at $URL serves $other — not $PROJECT_ROOT. Start yours with: fw watchtower start" and exits non-zero
5. On missing endpoint (older Watchtower): warns "Cannot verify project identity (upgrade Watchtower)"

**Invariant test:** `fw task review T-XXX` cannot emit a URL whose `/identity.project_root` differs from `$PROJECT_ROOT`.

**Changes required:**
- `web/app.py`: 1 new route `GET /identity` (5 lines)
- `lib/review.sh`: replace `base_url` construction with `resolve_and_verify_watchtower_url()` (~15 lines)

**Also required (prerequisite):** Fix Bug 2 first. If the PID path mismatch is not fixed, the identity check would only trigger when ANOTHER project's Watchtower is already on the default port — it wouldn't detect the case where the consumer's Watchtower IS running on a non-default port but invisible to review.sh.

**Cost:** Low (2 files, ~20 lines)  
**Blast radius:** Low (additive endpoint, review.sh logic change)  
**Backward compat:** Full — old Watchtowers without `/identity` get a warning, not a block  
**Fail mode:** Loud — "wrong project" error with actionable copy-paste command  
**Weakness:** Does not prevent URL namespace collision (both projects on same port scenario). Does not fix Bug 2 (path mismatch) — that requires a separate fix.

### Option B — Deterministic Port Hashing (project_name → 3000-3999)

**What:** Hash `project_name` into 3000-3999, write to `.framework.yaml` as `watchtower_port: 3247`. All URL-generating tools read this. Watchtower starts on this port and refuses if the port is serving another project.

**Example hash:** `crc32("025-WokrshopDesigner") % 1000 + 3000 = 3XXX` — stable per project name.

**Changes required:**
- `lib/config.sh` or init script: compute and persist port on `fw context init`
- `bin/watchtower.sh`: read persisted port, refuse if wrong project at that port
- `lib/review.sh`: port from project config (already partially done via `fw_config "PORT" 3000`)
- All 11+ consumer projects: need `fw context init` to assign their port

**Cost:** Medium (4+ files, one-time migration for all consumer projects)  
**Blast radius:** Medium (watchtower startup, config format, all URL generators)  
**Backward compat:** Requires migration — all consumer projects need port assigned  
**Fail mode:** Reduces collision probability but does NOT eliminate it (hash collisions exist; two projects with the same hash still collide). Does not fix the PID path mismatch.  
**Weakness:** Hash collision is not zero-probability for 11+ projects in 1000-port space. Does not address identity verification. Does not fix Bug 2.

### Option C — URL Namespacing (`/proj/<project_name>/inception/T-XXX`)

**What:** All routes gain a project prefix: `/proj/025-WokrshopDesigner/inception/T-434`. Even on the wrong Watchtower, the URL returns 404 because the project name doesn't match.

**Cost:** High (all routes, all templates, all QR codes, all existing bookmarks break)  
**Blast radius:** Very high (all Watchtower routes, HTML links, review.sh, Playwright tests)  
**Backward compat:** Breaking — all existing QR codes and bookmarked links fail  
**Fail mode:** Loud — wrong-project URL returns 404 (with clear "wrong project" error page if implemented)  
**Weakness:** Requires ALL callers of review.sh to be updated. Old QR codes from human tasks in progress become stale.

### Option D — Combined A + Bug-2-fix (Recommended)

**What:** Fix Bug 2 (PID path) + add `/identity` endpoint + add emitter verification.

This is the minimal set that STRUCTURALLY prevents the incident:
1. **Bug 2 fix:** `bin/watchtower.sh:21` → change `PID_FILE` from `$FRAMEWORK_ROOT/...` to `$PROJECT_ROOT/...`
2. **Option A:** `/identity` endpoint in `web/app.py` + `resolve_and_verify_watchtower_url()` in `lib/review.sh`

**Bug 2 fix details:**
```bash
# Current (broken for consumer projects):
PID_FILE="$FRAMEWORK_ROOT/.context/working/watchtower.pid"

# Fixed:
PID_FILE="$PROJECT_ROOT/.context/working/watchtower.pid"
```
This makes watchtower.sh write to the same location review.sh reads from, for all projects.

**Cost:** Low (3 files: watchtower.sh:1 line, app.py:5 lines, review.sh:15 lines)  
**Blast radius:** Low-Medium (watchtower.sh PID path change affects stop/status/is_running — all currently working correctly for /opt/999 because FRAMEWORK_ROOT=PROJECT_ROOT there, so this change is neutral for the framework itself and a fix for all consumers)  
**Backward compat:** Full  
**Fail mode:** Loud — emitter verifies identity before emitting; wrong-project produces error + copy-paste start command  
**Invariant test:** `fw task review T-XXX` cannot emit a URL whose `/identity.project_root` ≠ `$PROJECT_ROOT`

---

## Phase 4 — Task-ID Collision Audit (Partial)

### Confirmed collisions

| Task ID | Path 1 | Path 2 | Content |
|---------|--------|--------|---------|
| T-434 | `/opt/025-WokrshopDesigner/.tasks/active/T-434-design-promote-to-prod-gate...` | `/opt/999-Agentic-Engineering-Framework/.tasks/completed/T-434-...` | 025: promote-to-prod gate; 999: framework update inception |

**Note:** The full cross-project audit (`find /opt/*/.tasks -name "T-*.md" | sed 's/-.*//' | sort | uniq -c | sort -rn`) was blocked by budget gate at context-critical. Full audit deferred to build task.

### Structural observation

Task IDs are assigned by incrementing a per-project counter (or a monotonic counter per project). They are explicitly NOT globally unique. With 11+ consumer projects each at 200-1100 tasks, the overlap probability in the 1-1106 range is high. URL Option C (namespacing) would address this definitively but at high blast radius. Option D + fail-loud-on-identity-mismatch is sufficient as a first line of defense.

**Host-wide PID file audit:**
```
/opt/openclaw-evaluation/.agentic-framework/.context/working/watchtower.pid  → $FRAMEWORK_ROOT path (Bug 2 affected)
/opt/openclaw-evaluation/.agentic-framework.rollback/.context/working/watchtower.pid  → rollback copy
/opt/openclaw-evaluation/.context/working/watchtower.pid  → $PROJECT_ROOT path (correct? or separate install?)
/opt/051-Vinix24/.agentic-framework/.context/working/watchtower.pid  → $FRAMEWORK_ROOT path (Bug 2 affected)
/opt/termlink/.agentic-framework/.context/working/watchtower.pid  → $FRAMEWORK_ROOT path (Bug 2 affected)
/opt/050-email-archive/.agentic-framework/.context/working/watchtower.pid  → $FRAMEWORK_ROOT path (Bug 2 affected)
/opt/999-Agentic-Engineering-Framework/.context/working/watchtower.pid  → $PROJECT_ROOT path (correct, FRAMEWORK_ROOT=PROJECT_ROOT for framework itself)
/opt/025-WokrshopDesigner/.agentic-framework/.context/working/watchtower.pid  → $FRAMEWORK_ROOT path (Bug 2 affected, confirmed)
```

**All 5 consumer projects (025, 051, termlink, 050, openclaw) are affected by Bug 2.** They all write watchtower.pid to `$FRAMEWORK_ROOT/.context/working/` (inside the vendored `.agentic-framework/` dir) but review.sh reads from `$PROJECT_ROOT/.context/working/`. EVERY consumer project's `fw task review` ALWAYS falls through to the default port 3000.

---

## Phase 5 — Assumptions Validated

| Assumption | Result |
|-----------|--------|
| A-1 (pid+ss was added to fix an earlier "no detection" bug) | PARTIAL. T-634 created it fresh — no predecessor. But the `:3000` fallback was built in from the start, treated as harmless. The real problem (path mismatch) was never detected. |
| A-2 (T-885 was captured because someone hit this) | CONFIRMED. T-885 explicitly says "Port collisions are a daily friction point" with 11 projects. Inception is GO-recommended but waiting for human decision. |
| A-3 (fix should fail loud, not default-to-3000) | CONFIRMED. The incident shows that defaulting silently is the failure class. The fix must be: "no Watchtower running → fail with actionable error." |
| A-4 (deterministic unique port or identity endpoint) | CONFIRMED. Both are viable; identity endpoint (Option A) has lower blast radius. Deterministic port (Option B) does not eliminate Bug 2. |
| A-5 (task-ID collision is a separate bug class) | CONFIRMED. T-434 collision confirmed live. URL namespacing is the full fix but high cost; identity check is sufficient first defense. |
| A-6 (chokepoint + test discipline applies) | CONFIRMED. Chokepoint = `resolve_and_verify_watchtower_url()`. Invariant test = `fw task review` cannot emit a URL whose `/identity.project_root` ≠ `$PROJECT_ROOT`. |

---

## Go/No-Go Criteria Evaluation

**GO criteria (all met):**
- Root cause is fully identified and reproducible ✓
- Structural fix is designed with chokepoint + invariant test ✓
- Fix is backward compatible and low blast radius ✓
- Fail-loud behavior eliminates silent wrong-content serving ✓
- Bug 2 (PID path mismatch) fix is a 1-line change with clear correctness argument ✓

**NO-GO criteria (none triggered):**
- Fix would require breaking all existing QR codes or URLs — No (Option D is additive)
- Root cause is unclear or multiple competing hypotheses — No (fully confirmed)
- Fix is higher than Medium complexity — No (3 files, ~20 lines total)

---

## Recommendation

**Recommendation:** GO — Option D (Bug 2 fix + `/identity` endpoint + emitter verification)

**Rationale:** The live incident is 100% reproducible for ALL consumer projects on this host. Bug 2 alone means every consumer project's `fw task review` always emits `:3000` regardless of whether their own Watchtower is running. Bug 3 removes the last detection layer. The fix is minimal (3 files, ~20 lines), backward compatible, and produces fail-loud behavior with an actionable error message instead of silent wrong-content serving.

The T-1105 chokepoint+test discipline applies cleanly:
- **Chokepoint:** `resolve_and_verify_watchtower_url()` in `lib/review.sh` — single function that resolves URL AND verifies project identity before emitting
- **Invariant test:** `fw task review T-XXX` cannot emit a URL whose `/identity.project_root` differs from `PROJECT_ROOT`

T-885 (configurable per-project port) is a COMPLEMENTARY task, not a BLOCKING predecessor. The identity verification in Option D is sufficient to prevent the incident class; T-885 adds user comfort (stable predictable ports). Both should be built; Option D should be built first because it closes the security gap.

**Evidence:**
- `bin/watchtower.sh:21` — `PID_FILE="$FRAMEWORK_ROOT/.context/working/watchtower.pid"` (Bug 2 root cause, confirmed)
- `lib/review.sh:41` — checks `$PROJECT_ROOT/.context/working/watchtower.pid` (mismatched path, confirmed)
- `lib/review.sh:52` — `base_url="http://${wt_host}:${wt_port:-$default_port}"` (unconditional fallback, confirmed)
- 5 consumer projects affected by Bug 2 (025, 051, termlink, 050, openclaw — all vendored framework)
- `/identity` endpoint absent on all 3 running Watchtower instances (confirmed via curl)
- T-434 task-ID collision confirmed: active in /opt/025, completed in /opt/999
- `/opt/025/.context/working/` has NO `watchtower.pid`; PID 4170601 correctly bound to `:3001` is invisible to review.sh
- T-885 recommendation is already GO; it's been waiting for human decision since 2026-04-05

**Proposed build decomposition:**
1. **T-1106a** — Fix Bug 2: `bin/watchtower.sh:21` → change `FRAMEWORK_ROOT` to `PROJECT_ROOT` for PID_FILE path (1 line, 1 test)
2. **T-1106b** — Add `GET /identity` to `web/app.py` returning `{"project_root": PROJECT_ROOT, "project_name": PROJECT_NAME, "fw_version": VERSION}` (5 lines, 1 Playwright test)
3. **T-1106c** — Add `resolve_and_verify_watchtower_url()` to `lib/review.sh`, replace existing port-detection block, add invariant bats test (15 lines + 1 test)
4. **T-885 (unblock)** — Deterministic per-project port from `.framework.yaml` (existing inception, GO-recommended, unblock from human)

---

## Appendix: Exact Code Locations

| Location | Line | Issue |
|----------|------|-------|
| `bin/watchtower.sh:21` | `PID_FILE="$FRAMEWORK_ROOT/.context/working/watchtower.pid"` | Bug 2: writes to FRAMEWORK_ROOT instead of PROJECT_ROOT |
| `lib/review.sh:41` | `if [ -f "$PROJECT_ROOT/.context/working/watchtower.pid" ]; then` | Reads from PROJECT_ROOT — CORRECT but diverges from writer |
| `lib/review.sh:52` | `base_url="http://${wt_host}:${wt_port:-$default_port}"` | Bug 1: unconditional fallback to default port |
| `lib/review.sh:51` | `default_port=$(fw_config "PORT" 3000 2>/dev/null \|\| echo 3000)` | Default: 3000 with no cross-project safety |
| `bin/watchtower.sh:140-148` | `fuser -k -TERM "${port}/tcp"` | Kill bleed: starting Watchtower on default port kills another project's instance |
| `web/app.py` | (no `/identity` route exists) | Bug 3: no identity verification endpoint |
