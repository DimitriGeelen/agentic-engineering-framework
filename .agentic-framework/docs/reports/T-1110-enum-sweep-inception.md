# T-1110 — Framework Enum Sweep Inception

**Status:** Captured 2026-04-11. Research is largely pre-completed — this artifact exists to satisfy C-001 (research artifact first) and to record the dialogue trail from the same-session discovery to the go/no-go decision.

---

## Why this task exists

During T-1109's RCA (fw upgrade silently skips web/ sync), the main session named the class as **L-006 enumeration-divergence** — two or more code paths each maintaining their own hardcoded list of the same logical thing, drifting silently as items are added to one but not the other.

Within the same session, a 30-minute local scan by the main agent found **4 L-006 instances** (G-024, G-037, G-038, G-039). A TermLink worker (tl-vvfixptj, `t1109-l006-sweep`) then ran a systematic 20-minute scan and discovered **4 additional instances** plus an expansion to G-024 (NEW-007). Total: **8 L-006 instances** in a single session.

Pattern density this high does not fit the "one gap → one task" model. Either (a) 6 independent build tasks are opened to fix each gap one-by-one, multiplying coordination cost for the same chokepoint pattern; or (b) a single sweep-level task closes all 6 remaining Python/Jinja/bash gaps in one coherent structural pass using the chokepoint architecture already established by T-588 (`status-transitions.yaml`).

This inception decides between (a) and (b).

## Research inputs

**Primary source:** `docs/reports/T-1109-l006-sweep.md` (162 lines, worker output)

The worker scanned: `bin/`, `lib/`, `web/blueprints/`, `web/templates/`, `web/watchtower/`, `agents/context/`, `agents/audit/`, `agents/task-create/`, `.claude/settings.json`, `status-transitions.yaml`, `.context/cron-registry.yaml`. It produced:

- 7 new L-006 instance reports with file:line citations
- 1 expansion finding on G-024 (NEW-007: agent_dirs string missing 6 agents)
- 7 non-instances explicitly rejected with rationale
- LOC estimate: −115 removed, +80 added (net −35 LOC)
- Proposed chokepoint architecture: `status-transitions.yaml` extension + `fw_enums.py` Python helper + Flask context processor + Jinja loop for kanban CSS

**Secondary source:** `.context/project/learnings.yaml` — L-006 learning captured this session naming the bug class.

**Gap register:** `.context/project/concerns.yaml` — G-024 (escalated), G-037, G-038, G-039, G-040, G-041, G-042, G-043 all registered with evidence and proposed fixes.

## Dialogue log (C-001 extension)

### Segment 1 — Pattern discovery (main session)
- **Agent:** Completing T-1109 RCA. Root cause is enumeration divergence between do_upgrade step 4b and do_vendor includes.
- **Agent:** Capturing L-006 as a learning. Naming the class so future agents recognize it.
- **Agent:** Let me scan for other instances.
- **Agent:** Found G-037 (do_vendor vs do_update excludes). Different file pair, same pattern.
- **Agent:** Found G-038 (tasks.py hardcoded lists bypassing status-transitions.yaml). Python<->Bash boundary.
- **Agent:** Found G-039 (config registry triple-mirror). Python comment explicitly says "mirrors lib/config.sh" — self-documented drift risk.
- **Agent:** Density is surprisingly high. 4 instances in 30 minutes. Worth dispatching a TermLink worker for a systematic scan.

### Segment 2 — Worker dispatch (parent session + worker)
- **Parent:** Dispatched t1109-l006-sweep worker with 8-target scan scope. Write findings to docs/reports/T-1109-l006-sweep.md. No code edits, research only.
- **Worker:** Found 4 more instances: owner enum (no canonical), active-status (7+ sites including kanban CSS), fw hook list, fw subcommand case vs help prose.
- **Worker:** Expansion finding on G-024: lib/upgrade.sh:388 agent_dirs has a SECOND enumeration problem in the same file — missing 6 agents vs filesystem.
- **Worker:** Recommended sweep-style build task, cited LOC estimate, proposed chokepoint architecture.
- **Worker:** Explicitly rejected 7 non-instances (fabric.py, cron.py, risks.py, init.sh providers, create-task.sh) with rationale.

### Segment 3 — Inception decision framing
- **Agent:** 8 L-006 instances confirmed. 3 already drifting. Pattern density justifies a sweep-level task.
- **Agent:** Per T-1105 discipline, a recurring bug class (3+ instances) should be fixed via single chokepoint + invariant test, not incremental per-gap patches.
- **Agent:** Creating T-1110 as inception with GO recommendation so human can review the aggregate evidence in Watchtower rather than reading 8 separate gaps.
- **Agent:** Dependency: T-1110 blocked by T-1109 (consumer vendoring needs the new status-transitions.yaml + fw_enums.py to propagate).

## Options evaluated

### Option A — Incremental per-gap fixing
- Open 6 separate build tasks (one per remaining gap: G-038, G-039, G-040, G-041, G-042, G-043)
- Each task has its own chokepoint analysis, tests, review cycle
- **Pros:** smaller PRs, easier review, less coordination risk
- **Cons:** 6× coordination cost; same chokepoint pattern implemented 6 times with risk of inconsistency; no architectural invariant binding the fixes; future gaps reopen the same class

### Option B — Single sweep task (RECOMMENDED)
- T-1110 → T-1111a..g covering all 6 remaining gaps in one structural pass
- Shared chokepoint: `status-transitions.yaml` extension + `fw_enums.py` + Flask context processor
- **Pros:** net LOC reduction (−35 est); single invariant test (`tests/lint/no-hardcoded-enum-mirrors.bats`); architectural consistency; closes G-040/G-041/G-042/G-043 and retires Python side of G-038/G-039
- **Cons:** larger diff; kanban CSS reduction requires visual verification spike; dependency on T-1109 landing first

### Option C — Hybrid (urgent gaps only)
- Fix G-041 (kanban CSS) immediately because its fragility is user-visible
- Defer the rest until there's a structural reason (e.g., adding a new status type)
- **Pros:** addresses highest-severity finding first
- **Cons:** creates exactly the per-gap inconsistency Option B avoids; leaves 5 gaps open

**Recommendation: Option B.** Evidence in inception task Recommendation section.

## Constraints (duplicated from task file for quick reference)

- Blocked by T-1109 (consumer vendoring dependency)
- Backwards compatibility required on all existing task files, CLI, and API contracts
- Kanban CSS must produce pixel-identical visuals after migration
- YAML read must be cached (no per-request disk I/O)

## Next actions (conditional on human decision)

### If GO
1. Run spikes A/B/C (see inception task file)
2. Decide T-1110 GO via `fw inception decide T-1110 go --rationale "spikes passed"`
3. Create build tasks T-1111a..g
4. Land T-1109a..e first (blocker)
5. Implement T-1111a..g incrementally but within one branch

### If DEFER
- Keep T-1110 parked in horizon=later until T-1109 is decided
- Revisit after T-1109 lands

### If NO-GO
- Close T-1110 with rationale
- Leave G-038/G-039/G-040/G-041/G-042/G-043 as watching gaps for ad-hoc fixing
- Accept that future agents may rediscover instances and duplicate investigation

## Scope fence (for the research phase specifically)

**IN:** This document + the cited `docs/reports/T-1109-l006-sweep.md` as the research artifact pair; dialogue log; options analysis; decision framing.

**OUT:** Any actual code edits (those are T-1111a..g build tasks); spike execution (those happen after GO if spikes are chosen); cross-project migration (T-1109 handles that for the web/ sync).
