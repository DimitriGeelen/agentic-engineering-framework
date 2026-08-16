---
id: T-1106
name: "ULTRA-HIGH PRIORITY: fw task review URL defaults to :3000 — cross-project task-ID
  collision serves wrong content"
description: >
  URGENT inception. lib/review.sh:38-52 detects the Watchtower URL by reading PROJECT_ROOT/.context/working/watchtower.pid
  then ss for the port. If the pid file is missing OR the PID is dead, it FALLS BACK
  to default_port=3000 (line 51). On any host with multiple consumer projects, the
  first Watchtower to bind :3000 captures every other project's review URLs. Combined
  with task-ID collisions across projects (T-434 exists in BOTH /opt/025-WokrshopDesigner
  AND /opt/999-Agentic-Engineering-Framework as different tasks), this means: /opt/025
  user runs 'fw task review T-434', QR opens http://host:3000/inception/T-434, but
  :3000 is /opt/999's Watchtower, which serves ITS T-434 — wrong content, right URL,
  right task ID, completely silent failure. Live evidence today (2026-04-11): user
  ran fw task review T-434 in /opt/025-WokrshopDesigner, the URL took them to /opt/999's
  Watchtower which served a different T-434 (the inception about framework update/upgrade
  process), with the After-review-run text correctly pointing back to /opt/025. Investigate:
  (1) what was the port-detection mechanism BEFORE the current pid+ss approach? grep
  history for previous review.sh and earlier port-resolution code; check T-885 (configurable
  Watchtower port project setting) and any predecessor; (2) why the current pid+ss
  fallback collapses to 3000 silently — is there ANY cross-project safety check? (3)
  what would a STRUCTURAL fix look like: assign each project a unique deterministic
  port (e.g., hash of project name into 3000-3999 range), refuse to start Watchtower
  on a port that already serves another project, embed PROJECT_ROOT in Watchtower's
  identity endpoint and have fw task review verify the running Watchtower at the chosen
  URL belongs to PROJECT_ROOT before emitting the link; (4) the underlying task-ID
  collision is itself a bug — should task IDs be project-namespaced (e.g., 999/T-434,
  025/T-434) at least in URL form? (5) recommend GO with chokepoint+invariant test
  discipline per T-1105: chokepoint = single function that resolves Watchtower URL
  AND verifies project identity before emitting; invariant test = no fw task review
  can emit a URL whose Watchtower /identity returns a different PROJECT_ROOT. Severity:
  high - silent wrong-content serving across project boundaries violates the framework's
  project isolation guarantee. Origin: live incident 2026-04-11 during structural-fix
  discipline pass.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: [web/blueprints/inception.py, web/templates/inception_detail.html]
related_tasks: [T-885, T-1105, T-1100, T-1093]
created: 2026-04-11T13:30:22Z
last_update: '2026-08-16T22:24:22Z'
date_finished: 2026-04-11T20:10:54Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1106: ULTRA-HIGH PRIORITY: fw task review URL defaults to :3000 — cross-project task-ID collision serves wrong content

## Problem Statement

`lib/review.sh:38-52` resolves the Watchtower URL emitted by `fw task review T-XXX` like this:

```bash
local base_url="${WATCHTOWER_URL:-}"
if [ -z "$base_url" ]; then
    local wt_port="" wt_host="" wt_pid=""
    if [ -f "$PROJECT_ROOT/.context/working/watchtower.pid" ]; then
        wt_pid=$(cat "$PROJECT_ROOT/.context/working/watchtower.pid" 2>/dev/null)
        wt_port=$(ss -tlnp 2>/dev/null | grep "pid=$wt_pid" | grep -oP ':(\d+)\s' | tr -d ': ' | head -1)
    fi
    wt_host=$(hostname -I 2>/dev/null | awk '{print $1}')
    wt_host="${wt_host:-$(hostname 2>/dev/null)}"
    wt_host="${wt_host:-localhost}"
    local default_port
    default_port=$(fw_config "PORT" 3000 2>/dev/null || echo 3000)
    base_url="http://${wt_host}:${wt_port:-$default_port}"
fi
```

**Three layered failures:**

1. **Pid file is project-local** — only checks `$PROJECT_ROOT/.context/working/watchtower.pid`. If THIS project doesn't have a Watchtower running (no pid file or stale pid), falls through to default.
2. **Default is unconditional `3000`** — every project on the same host that doesn't have its own Watchtower running emits URLs pointing at `:3000`. Whichever project is first to bind `:3000` captures every other project's review URLs.
3. **No cross-project safety check** — the emitter never asks the Watchtower at the chosen URL "are you serving PROJECT_ROOT?" before printing the link. The user clicks, gets HTTP 200 with HTML, and trusts it.

**Combined with task-ID collision:** Task IDs are integers scoped per-project, NOT globally unique. `T-434` exists in `/opt/025-WokrshopDesigner` (a "promote-to-prod gate" inception) AND in `/opt/999-Agentic-Engineering-Framework` (an "inception framework update/upgrade process" task — completed). When the consumer's URL points at the wrong Watchtower, that Watchtower happily serves ITS T-434 because the integer ID matches. The user sees a page titled "Inception T-434" with completely different content, never realizing the URL went to the wrong project.

**Live incident (2026-04-11, this session):**
- User in `/opt/025-WokrshopDesigner` ran `fw task review T-434`
- Output included QR code → `http://192.168.10.107:3000/inception/T-434`
- Output also included `After review, run: cd /opt/025-WokrshopDesigner && bin/fw inception decide T-434 ...` (correctly references the consumer)
- :3000 on this host is the framework's own Watchtower (PID 2060863, cwd `/opt/999-Agentic-Engineering-Framework`)
- Curl confirmed: `http://localhost:3000/inception/T-434` returns HTML titled "Inception T-434 — Agentic Engineering Framework", references `/opt/999-Agentic-Engineering-Framework` paths
- The user saw the QR + the consumer path + the URL — and rightly read the inconsistency as a project-isolation breach. Severity is high: silent wrong-content serving across project boundaries violates the framework's isolation guarantee.

**For whom:** Every consumer project on a multi-project host. Every human or agent who clicks a `fw task review` URL. Every approval flow that depends on the human seeing the right content under the right URL.

**Why now:** Live incident today during the structural-fix discipline pass. Without a fix, **every approval recorded via Watchtower on a multi-project host is potentially against the wrong task**. This compounds with G-032 (`fw inception decide` silently force-completes — already registered), creating a path where you "approve" a task you never actually saw.

**Severity: ULTRA-HIGH.** Project isolation breach + silent wrong-content serving + already-broken decide flow = approvals against tasks the human never reviewed.

## Assumptions

A-1: The pid+ss approach was added to fix an earlier "no port detection at all" bug. Reading the history will reveal what was tried before and why the current approach was thought sufficient. (Testable by `git log -p lib/review.sh` and checking the commit that introduced the current logic + any predecessor port-resolution code.)

A-2: T-885 ("configurable Watchtower port — project setting") was captured because someone hit this exact issue and shelved it. (Testable by reading T-885 task file and any episodic.)

A-3: The fix is structural, not tactical: defaulting to `3000` is the wrong thing to do at all. The right behavior is "if the project has no Watchtower running, fail loudly with a copy-pasteable start command — never emit a URL that might lie." (Testable by sketching the alternative and running it against the live incident scenario.)

A-4: Each consumer project should have a deterministic unique port (e.g., hash project_name into 3000-3999), OR the URL should embed PROJECT_ROOT and the Watchtower's `/identity` endpoint should return its served root for verification before link emission. (Testable by sketching both approaches and comparing.)

A-5: The underlying task-ID collision is a separate bug class — task IDs are not globally unique. URL form should be `host:port/inception/T-XXX?project=<name>` or `host:port/<project>/inception/T-XXX` so even a wrong-port URL fails fast. (Testable by sketching the URL change and impact on existing routes.)

A-6: The chokepoint+test discipline (T-1105) applies here: chokepoint = single function that resolves Watchtower URL AND verifies the running Watchtower at that URL serves PROJECT_ROOT before emitting; invariant test = `fw task review` cannot emit a URL whose `/identity` endpoint returns a different project root.

## Exploration Plan

**Phase 1 — Backward research (per user directive).**
- `git log -p lib/review.sh` — find the commit that introduced the current pid+ss approach. Read the predecessor logic. What was tried before?
- Read T-885 in full. Any predecessor inception (T-880s..) that touched port handling.
- `git log --all --oneline -- 'lib/review.sh' 'web/app.py' '*watchtower*port*'` — every commit that touched port resolution.
- Document what was tried, what failed, and why each iteration was thought sufficient.

**Phase 2 — Live incident reconstruction.**
- Reproduce: from `/opt/025-WokrshopDesigner`, run `fw task review T-434`, capture exact output. Note which port the URL contains. Note whether `/opt/025/.context/working/watchtower.pid` exists; if so, whether the PID is alive; if so, what port it's bound to.
- Hit the URL with curl, confirm wrong-project content is served.
- Hit `http://localhost:3000/identity` (if it exists) or `/` and see whether the response identifies its served project root. (T-1106 may need Watchtower to GROW an identity endpoint as part of the fix.)

**Phase 3 — Structural fix design.**
- **Option A — Identity verification:** Watchtower exposes `/identity` returning JSON `{project_root, project_name, version}`. `fw task review` queries the URL it's about to emit, refuses to emit if `project_root != PROJECT_ROOT`, prints "Watchtower at $URL serves $other_project, not $this. Start your own with: fw watchtower start --port <unused>".
- **Option B — Deterministic port allocation:** hash project_name into 3000-3999, write to `.framework.yaml` as `port: 3247`. Each project has a stable unique port. fw watchtower start binds it; refuse if taken by another project.
- **Option C — URL namespacing:** task URLs become `/proj/<project_name>/inception/T-XXX`. Even a wrong-port URL fails fast (404) because the project name in the path doesn't match the served project.
- **Option D — Combined:** A + C (identity verification + namespaced URLs) for defense in depth.
- For each: cost, blast radius, backwards-compat with existing URLs/QRs, false-positive rate.

**Phase 4 — Task-ID collision audit.**
- Are task IDs globally unique across consumer projects, or per-project? Survey: `find /opt/*/.tasks /opt/*/.tasks/completed -name "T-*.md" -printf '%f\n' | sed 's/-.*//' | sort | uniq -c | sort -rn` — count ID collisions across all consumer projects on this host.
- If collisions are common, URL namespacing is mandatory. If rare, identity verification alone may be sufficient.

**Phase 5 — Recommendation.** GO Option X with chokepoint+test pair per T-1105. Cite the live incident, the audit numbers, and the backwards-research findings.

## Scope Fence

**IN scope:** RCA (backward research, live reconstruction), structural fix design, recommendation. May read framework source, git history, consumer projects (for audit). May write findings to `docs/reports/T-1106-watchtower-port-bleed-rca.md`.

**OUT of scope:** Implementing any fix (build comes from descendants after GO). Modifying lib/review.sh, web/app.py, or any consumer project. Creating the /identity endpoint. URL route changes. The actual port allocation algorithm.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Bug 2 (PID path mismatch: `bin/watchtower.sh:21` uses `$FRAMEWORK_ROOT`, `lib/review.sh:41` uses `$PROJECT_ROOT`) is verified by direct code reading (CONFIRMED — file:line cited in RCA report)
- A single chokepoint can serve all four bugs with proven architecture (CONFIRMED — `resolve_and_verify_watchtower_url()` in lib/review.sh + `/identity` endpoint in web/app.py + PID path unification)
- Invariant tests can assert no code bypasses the chokepoint (CONFIRMED — no-rogue-url-construction, review-url-identity-check, pid-path-consistency, no-default-port-fallback sketched in docs/reports/T-1106-watchtower-port-bleed-rca.md)
- The fix is fully contained within `lib/review.sh`, `bin/watchtower.sh`, and `web/app.py` (CONFIRMED — no cross-project impact, no schema changes, no migration needed)
- Zero-downtime migration path exists (CONFIRMED — chokepoint is additive; old callers work until migrated)

**NO-GO if:**
- The `/identity` endpoint introduces auth complexity that outweighs the bleed prevention value (not observed — endpoint is a read-only GET returning `$PROJECT_ROOT`)
- The chokepoint refactor breaks existing fw task review in edge cases more common than the bleed (not observed — the bleed is already user-visible across multiple sessions)

**DEFER if:**
- T-885 (per-project configurable port) lands first and makes port collisions rare enough that the primary bleed vector disappears (would reduce urgency but not invalidate the fix — URL identity verification remains valuable)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO — Option D (Bug 2 fix + `/identity` endpoint + emitter verification)

**Rationale:** Three compounding bugs confirmed. Bug 2 (`bin/watchtower.sh:21` uses `$FRAMEWORK_ROOT` for PID_FILE, `lib/review.sh:41` reads `$PROJECT_ROOT`) means ALL 5 consumer projects ALWAYS fall through to default port 3000 — Bug 1. No `/identity` endpoint (Bug 3) removes last detection layer. Fix: 3 files, ~20 lines, backward compatible, fail-loud.

**Evidence:**
- `bin/watchtower.sh:21` — PID_FILE uses FRAMEWORK_ROOT, not PROJECT_ROOT (root of Bug 2)
- `lib/review.sh:52` — unconditional fallback to :3000 (Bug 1)
- 5 of 5 consumer projects write PID to `.agentic-framework/.context/working/` — review.sh reads from `.context/working/` — paths never match
- `/identity` absent on all 3 running Watchtower instances (curl confirmed)
- T-434 collision live: active in /opt/025 (promote-to-prod), completed in /opt/999 (fw upgrade)
- Full RCA: `docs/reports/T-1106-watchtower-port-bleed-rca.md`
- Build decomposition: T-1106a (watchtower.sh 1-line fix), T-1106b (/identity endpoint), T-1106c (emitter verification + invariant test), then T-885 (unblock port registry)

## Structural Upgrade (added 2026-04-11 — chokepoint+test discipline pass per T-1105)

The worker's Option D (Bug 2 fix + `/identity` endpoint + emitter verification) is already chokepoint-shaped. This section makes the chokepoint explicit, adds the invariant tests, and extends the design to cover the task-ID collision blast radius the worker deferred (Bug 4).

**Chokepoint 1 — URL resolution (single function):**
- Add `resolve_and_verify_watchtower_url()` in `lib/review.sh`. Every `fw task review` URL emission MUST go through this function. It:
  1. Reads `$PROJECT_ROOT/.context/working/watchtower.pid` (same path as before — Bug 2 fix makes the writer match)
  2. If missing/stale → fails loud with "No Watchtower running for this project. Start with: cd $PROJECT_ROOT && bin/fw watchtower start" — NEVER defaults to :3000
  3. If present → resolves port via ss, curls `/identity`, asserts `project_root == $PROJECT_ROOT`
  4. On mismatch → fails loud with the served project_root and copy-paste start command
  5. Returns the verified URL only if all checks pass
- `lib/review.sh:38-52` is replaced wholesale. No other function in `lib/` or `agents/` is permitted to construct a Watchtower URL — enforced by invariant test below.

**Chokepoint 2 — PID file path (single convention):**
- `bin/watchtower.sh:21` → `PID_FILE="$PROJECT_ROOT/.context/working/watchtower.pid"` (was `$FRAMEWORK_ROOT/...`)
- Add compatibility read: if `$PROJECT_ROOT/.context/working/watchtower.pid` missing, check `$FRAMEWORK_ROOT/.context/working/watchtower.pid` with a loud migration warning, then move it. One-shot migration for existing consumer installs.
- All five consumer projects (025, 051, termlink, 050, openclaw) get the migration on their next `fw watchtower start`.

**Chokepoint 3 — Identity endpoint (single source of truth):**
- Add `GET /identity` in `web/app.py` returning `{"project_root": str(PROJECT_ROOT), "project_name": ..., "fw_version": ..., "started_at": ...}`.
- Reads from the same `PROJECT_ROOT` env var the Flask app was launched with — no duplication. If the env var is absent, `/identity` returns 503 with an explicit "Watchtower started without PROJECT_ROOT" error, preventing a silent "serves whatever cwd" fallback.

**Invariant tests:**
- `tests/lint/no-rogue-url-construction.bats` — greps `lib/` `agents/` `bin/` for any string matching `http://.*:(3000|3001|\${.*port.*})` outside `lib/review.sh:resolve_and_verify_watchtower_url()`. Allowlist: the chokepoint itself, `bin/watchtower.sh` start banner, `docs/`.
- `tests/integration/review-url-identity-check.bats` — starts Watchtower on :3099, runs `fw task review T-XXX`, asserts the emitted URL's `/identity.project_root` equals `$PROJECT_ROOT`. Runs as a sub-test with a second Watchtower on :3098 serving a fake project — asserts that `fw task review` from the first project NEVER emits a URL resolving to the second.
- `tests/integration/pid-path-consistency.bats` — for each consumer project layout (vendored + shim), starts Watchtower and asserts `lib/review.sh` can find the PID by reading `$PROJECT_ROOT/.context/working/watchtower.pid`.
- `tests/lint/no-default-port-fallback.bats` — asserts no file in `lib/` contains `:-3000` or `:-$default_port` in a URL-constructing context.

**Addressing Bug 4 (task-ID collision) — deferred but scoped:**
- Full URL namespacing (Option C — `/proj/<name>/inception/T-XXX`) is out of scope for T-1106 build. Option D's identity check makes namespacing unnecessary as a security fix — the verification catches the wrong-Watchtower case before the URL is emitted. Namespacing would only help if the URL leaks to a second client (e.g., QR scanned on another device while the original Watchtower is restarted on a different project).
- Open a separate inception `T-1107` (to be captured) to track "globally unique task IDs OR URL namespacing" as a defense-in-depth follow-up to T-1106 and T-885.

**Memory propagation:**
- After Bug 2 is fixed, all five affected consumer projects need `fw watchtower restart` once to migrate the PID file. Document this in the build task's migration steps. Add a `fw doctor` check that detects the mismatched path and prints the one-line remediation.

**Why this is more reliable than the worker's plan alone:**
- The worker identified the chokepoint but the build decomposition (T-1106a/b/c) left the invariant tests implicit. This section makes them explicit and enforceable in CI.
- The rogue-URL-construction lint catches future regressions where someone adds a new `http://...:3000` anywhere in the tree, not just in the current bug site.
- The integration test with two Watchtowers is the only way to prove the cross-project check works end-to-end — unit tests can't exercise the actual network port collision.
- The Bug 2 migration shim prevents a silent "upgrade ate the PID file" class on consumer projects.

**Build decomposition (revised):**
1. **T-1106a** — Bug 2 fix: `bin/watchtower.sh:21` + migration shim (1 file, ~10 lines)
2. **T-1106b** — `/identity` endpoint + Playwright test (1 file, ~10 lines + test)
3. **T-1106c** — `resolve_and_verify_watchtower_url()` chokepoint in `lib/review.sh` (1 file, ~30 lines)
4. **T-1106d** — Invariant tests (`no-rogue-url-construction.bats`, `review-url-identity-check.bats`, `pid-path-consistency.bats`, `no-default-port-fallback.bats`) — 4 files, ~100 lines total
5. **T-1106e** — `fw doctor` checks for PID path drift + Watchtower identity mismatch — existing doctor hooks, ~20 lines
6. **T-1107** (new inception, captured) — Task-ID collision: globally unique IDs or URL namespacing (defense-in-depth)
7. **T-885 (unblock)** — Deterministic per-project port (already GO-recommended, awaiting human decision)

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO — Option D (Bug 2 fix + `/identity` endpoint + emitter verification)

Rationale: Three compounding bugs confirmed. Bug 2 (`bin/watchtower.sh:21` uses `$FRAMEWORK_ROOT` for PID_FILE, `lib/review.sh:41` reads `$PROJECT_ROOT`) means ALL 5 consumer projects ALWAYS fall through to default port 3000 — Bug 1. No `/identity` endpoint (Bug 3) removes last detection layer. Fix: 3 files, ~20 lines, backward compatible, fail-loud.

Evidence:
- `bin/watchtower.sh:21` — PID_FILE uses FRAMEWORK_ROOT, not PROJECT_ROOT (root of Bug 2)
- `lib/review.sh:52` — unconditional fallback to :3000 (Bug 1)
- 5 of 5 consumer projects write PID to `.agentic-framework/.context/working/` — review.sh reads from `.context/working/` — paths never match
- `/identity` absent on all 3 running Watchtower instances (curl confirmed)
- T-434 collision live: active in /opt/025 (promote-to-prod), completed in /opt/999 (fw upgrade)
- Full RCA: `docs/reports/T-1106-watchtower-port-bleed-rca.md`
- Build decomposition: T-1106a (watchtower.sh 1-line fix), T-1106b (/identity endpoint), T-1106c (emitter verification + invariant test), then T-885 (unblock port registry)

**Date**: 2026-04-11T20:10:54Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — Option D (Bug 2 fix + `/identity` endpoint + emitter verification)

Rationale: Three compounding bugs confirmed. Bug 2 (`bin/watchtower.sh:21` uses `$FRAMEWORK_ROOT` for PID_FILE, `lib/review.sh:41` reads `$PROJECT_ROOT`) means ALL 5 consumer projects ALWAYS fall through to default port 3000 — Bug 1. No `/identity` endpoint (Bug 3) removes last detection layer. Fix: 3 files, ~20 lines, backward compatible, fail-loud.

Evidence:
- `bin/watchtower.sh:21` — PID_FILE uses FRAMEWORK_ROOT, not PROJECT_ROOT (root of Bug 2)
- `lib/review.sh:52` — unconditional fallback to :3000 (Bug 1)
- 5 of 5 consumer projects write PID to `.agentic-framework/.context/working/` — review.sh reads from `.context/working/` — paths never match
- `/identity` absent on all 3 running Watchtower instances (curl confirmed)
- T-434 collision live: active in /opt/025 (promote-to-prod), completed in /opt/999 (fw upgrade)
- Full RCA: `docs/reports/T-1106-watchtower-port-bleed-rca.md`
- Build decomposition: T-1106a (watchtower.sh 1-line fix), T-1106b (/identity endpoint), T-1106c (emitter verification + invariant test), then T-885 (unblock port registry)

**Date**: 2026-04-11T20:10:54Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-11T14:30:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Ingesting T-1106 RCA + applying structural upgrade + fixing port squatter

### 2026-04-11T20:10:54Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — Option D (Bug 2 fix + `/identity` endpoint + emitter verification)

Rationale: Three compounding bugs confirmed. Bug 2 (`bin/watchtower.sh:21` uses `$FRAMEWORK_ROOT` for PID_FILE, `lib/review.sh:41` reads `$PROJECT_ROOT`) means ALL 5 consumer projects ALWAYS fall through to default port 3000 — Bug 1. No `/identity` endpoint (Bug 3) removes last detection layer. Fix: 3 files, ~20 lines, backward compatible, fail-loud.

Evidence:
- `bin/watchtower.sh:21` — PID_FILE uses FRAMEWORK_ROOT, not PROJECT_ROOT (root of Bug 2)
- `lib/review.sh:52` — unconditional fallback to :3000 (Bug 1)
- 5 of 5 consumer projects write PID to `.agentic-framework/.context/working/` — review.sh reads from `.context/working/` — paths never match
- `/identity` absent on all 3 running Watchtower instances (curl confirmed)
- T-434 collision live: active in /opt/025 (promote-to-prod), completed in /opt/999 (fw upgrade)
- Full RCA: `docs/reports/T-1106-watchtower-port-bleed-rca.md`
- Build decomposition: T-1106a (watchtower.sh 1-line fix), T-1106b (/identity endpoint), T-1106c (emitter verification + invariant test), then T-885 (unblock port registry)

### 2026-04-11T20:10:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:16Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ab2986c9
- **Timestamp:** 2026-06-02T14:55:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
