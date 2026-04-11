---
id: T-1106
name: "ULTRA-HIGH PRIORITY: fw task review URL defaults to :3000 — cross-project task-ID collision serves wrong content"
description: >
  URGENT inception. lib/review.sh:38-52 detects the Watchtower URL by reading PROJECT_ROOT/.context/working/watchtower.pid then ss for the port. If the pid file is missing OR the PID is dead, it FALLS BACK to default_port=3000 (line 51). On any host with multiple consumer projects, the first Watchtower to bind :3000 captures every other project's review URLs. Combined with task-ID collisions across projects (T-434 exists in BOTH /opt/025-WokrshopDesigner AND /opt/999-Agentic-Engineering-Framework as different tasks), this means: /opt/025 user runs 'fw task review T-434', QR opens http://host:3000/inception/T-434, but :3000 is /opt/999's Watchtower, which serves ITS T-434 — wrong content, right URL, right task ID, completely silent failure. Live evidence today (2026-04-11): user ran fw task review T-434 in /opt/025-WokrshopDesigner, the URL took them to /opt/999's Watchtower which served a different T-434 (the inception about framework update/upgrade process), with the After-review-run text correctly pointing back to /opt/025. Investigate: (1) what was the port-detection mechanism BEFORE the current pid+ss approach? grep history for previous review.sh and earlier port-resolution code; check T-885 (configurable Watchtower port project setting) and any predecessor; (2) why the current pid+ss fallback collapses to 3000 silently — is there ANY cross-project safety check? (3) what would a STRUCTURAL fix look like: assign each project a unique deterministic port (e.g., hash of project name into 3000-3999 range), refuse to start Watchtower on a port that already serves another project, embed PROJECT_ROOT in Watchtower's identity endpoint and have fw task review verify the running Watchtower at the chosen URL belongs to PROJECT_ROOT before emitting the link; (4) the underlying task-ID collision is itself a bug — should task IDs be project-namespaced (e.g., 999/T-434, 025/T-434) at least in URL form? (5) recommend GO with chokepoint+invariant test discipline per T-1105: chokepoint = single function that resolves Watchtower URL AND verifies project identity before emitting; invariant test = no fw task review can emit a URL whose Watchtower /identity returns a different PROJECT_ROOT. Severity: high - silent wrong-content serving across project boundaries violates the framework's project isolation guarantee. Origin: live incident 2026-04-11 during structural-fix discipline pass.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-885, T-1105, T-1100, T-1093]
created: 2026-04-11T13:30:22Z
last_update: 2026-04-11T13:30:22Z
date_finished: null
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
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
