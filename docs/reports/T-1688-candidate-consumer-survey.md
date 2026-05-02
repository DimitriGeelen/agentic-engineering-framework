# T-1688 — G-064 candidate-consumer survey

**Date:** 2026-05-02
**Question:** Of every autonomous workload running in the framework today, which is the strongest candidate for retrofit through `fw termlink dispatch` (the orchestrator) to close G-064?

## Inception

G-064 names the §ACD substrate-vs-deliverable conflation in its cleanest form: the orchestrator-rethink arc shipped a tool that works when invoked, but nothing in the framework's autonomous workload invokes it. `route_cache.json` will go cold the moment verification work stops.

The prior session brainstormed three candidate consumer paths in `concerns.yaml`:

1. `fw audit` refactor (T-1685, NO-GO — bash/git/IO, no LLM-amenable workload)
2. Daily health-check cron (T-1684, captured horizon:later — weakest, smallest, synthetic prompts)
3. Opt-in `--via-orchestrator` flag (not yet a task — opt-in by definition is not autonomous)

This artifact broadens the search: enumerate **every** autonomous workload, classify each as retrofit candidate.

## Method

Read `.context/cron/agentic-audit.crontab` (the canonical install file). For each cron line, locate the entry point in `agents/`, `lib/`, or `tools/`. Classify on three axes:

- **Workload kind** — what the job actually does
- **LLM-amenable** — would an LLM add real value over the current implementation?
- **Retrofit difficulty** — what would be required to dispatch through the orchestrator?

Plus one extra signal: scan all autonomous code for `claude -p` / `fw termlink dispatch` / `termlink dispatch` invocations.

## Findings — autonomous workload inventory

| Cron | Cadence | Entry point | Workload kind | LLM-amenable? | Retrofit |
|---|---|---|---|---|---|
| `reviewer audit` | 04:37 daily | `lib/reviewer/audit.py` (Python regex static-scan) | Anti-pattern detection on completed tasks via 4 seed regex patterns | **Source says "Orchestrator routing (v3+)" — explicit deferred consumer.** Today: regex, no | Substantial — would need a v2.x classifier rewrite |
| `audit --section structure,compliance,quality,discovery` | every 30m | `agents/audit/audit.sh` | YAML/file structure counts, regex matches | No — counts and structural checks | N/A |
| `audit --section traceability,episodic,discovery-trends` | hourly | same | Git log scans, episodic file existence | No | N/A |
| `audit --section observations,gaps` | every 6h | same | Counts entries in observations.yaml / concerns.yaml | No | N/A |
| `audit --section oe-fast,oe-research` | :15/:45 | same + `active-task-scan.py` | Control-verification structural counts | No | N/A |
| `audit --section oe-hourly` | :30 | same | Git + cron health checks | No | N/A |
| `audit --section oe-daily` | 07:00 | same + `completed-task-scan.py` | Deep control verification, structural | No | N/A |
| `audit --section oe-weekly` | Mon 09:00 | same | Behavioral pattern aggregation | No | N/A |
| `audit` (full) | 08:00 | same | All sections | No | N/A |
| `docs --all` | 08:15 | (not inspected — `bin/fw docs`) | Doc generation from sources | Possibly (synthesis-shaped), but currently template-driven | Medium — would need a content-synthesis dispatch step |
| audit YAML retention cleanup | 09:00 | inline `python3 -c` | File deletes by mtime | No | N/A |
| `pickup process` | every minute | `lib/pickup.sh` | Cross-project handoff inbox processing | No | N/A |
| `release tag-and-release` | Mon 10:00 | release agent | Tag + push + changelog | No | N/A |
| `liveness-check.sh` | every minute | `agents/monitor/liveness-check.sh` | HTTP probe + log line | No | N/A |
| `liveness-check` (boot) | @reboot | same | Boot marker | No | N/A |
| `mirror sync --quiet` | every 15m | mirror agent | Pure `git push` | No | N/A |
| `escalation-scan-v0.py` | 05:23 | `tools/escalation-scan-v0.py` | Heuristic regex over completed tasks (H1–H3) | **Plausibly yes for nuance** — header comment notes "intentionally simple for the spike" | Medium — would need a v0.5 LLM-augmented variant |
| `watchtower-rss-sample.sh` | every 5m | `agents/monitor/watchtower-rss-sample.sh` | RSS metric snapshot | No | N/A |

Plus a code-wide scan: only `agents/termlink/termlink.sh` and `lib/config.sh` reference termlink dispatch, neither autonomously. `agents/dispatch/preamble.md` is documentation telling agents they CAN dispatch; nothing in the framework's autonomous workload DOES.

## Classification result

**18 autonomous workloads, 0 currently LLM-amenable, 2 plausible-with-rework.**

The two plausible candidates and their honest cost:

- **`fw reviewer audit`** — the source code itself flags "Orchestrator routing (v3+)" as a deferred capability. Retrofit means rewriting the v1.0 static-scan classifier as a classifier+LLM pipeline (where the regex narrows candidates and the LLM nuances verdicts). This is a genuine v2.x line of work, not a 1-day retrofit. Would close G-064 daily on real workload (every completed task → reviewer scan → orchestrator dispatch → verdict back). Cost estimate: ~3 sessions of build, plus the prerequisite of v2.x roadmap commitment.
- **`tools/escalation-scan-v0.py`** — comment "intentionally simple for the spike" + name "v0" both signal a planned successor. Retrofit means a v0.5 that LLM-augments the H1–H3 heuristics (e.g. "is this RCA section substantive or template-shaped?" — a judgment call regex can't make). Cost estimate: ~1 session for v0.5, plus the question of whether this work is on anyone's roadmap.

The other 16 are not retrofit candidates. They're structural/git/file/HTTP/regex work where an LLM adds nothing over the current implementation, only cost and non-determinism.

## Recommendation

**The retrofit path does not naturally close G-064.** Both plausible retrofits (reviewer v2.x, escalation-scan v0.5) are real future work but not "ship it this week" — they need their own scope and roadmap commitment, and pretending otherwise is exactly the substrate-vs-deliverable error this gap was filed against.

The honest options:

1. **Accept G-064 as long-term** — orchestrator substrate stays opt-in; agents can use `fw termlink dispatch`; route_cache learns sparsely from manual usage; no autonomous consumer planned. Document this explicitly in the arc (it shipped a developer-facing tool, not a behaviour-change deliverable). Mitigation: not closure.
2. **Promote T-1684 (cron health-check)** — synthetic prompts, but it IS autonomous workload and keeps `last_used` fresh. Mitigates the "cache goes cold" symptom without addressing the root question of whether the substrate has real users. Smallest concrete path. Captured in T-1684 with explicit "NOT to be promoted/started without human GO" gate.
3. **Schedule reviewer v2.x as the real closure** — accept that closing G-064 is a multi-session investment that ties into reviewer roadmap. Add T-1688 (this) as the upstream survey, file a child task for the reviewer v2.x scope discussion.
4. **Schedule escalation-scan v0.5 as the real closure** — smaller scope than reviewer v2.x, more concrete (the v0 comment names its successor). File a child task for v0.5 design.

**Recommendation: 1 + 4 in parallel.**
Accept G-064 as long-term reality (1) — be honest in the arc that orchestrator is a developer-facing tool right now. Then schedule escalation-scan v0.5 (4) as the planned upgrade that turns G-064 from "watching" to "mitigating": it's small enough to ship, has internal source-code precedent (the v0 comment), and produces real LLM-augmented work that exercises the substrate every day. Reviewer v2.x (3) is a longer arc that should be its own roadmap conversation — out of scope for this survey.

T-1684 (option 2) stays captured as the "if 4 stalls" fallback.

## Evidence

- Cron survey: `.context/cron/agentic-audit.crontab` (18 entries enumerated above)
- Code scan: `grep -rln "claude -p\|fw termlink dispatch\|termlink dispatch" agents/ lib/ tools/` returns 4 files, none autonomous
- Reviewer source: `lib/reviewer/static_scan.py` lines 18–19 explicitly defer "Orchestrator routing (v3+)"
- Escalation source: `tools/escalation-scan-v0.py` line 1 names itself "v0 spike", lines 6–10 say "intentionally simple"
- Route cache state: 5 keys, all `last_used` from today's verification work — confirms the cold-cache concern in G-064

## Decision

Proposed: **GO on option 1 + 4** — file a child inception for `escalation-scan-v0.5` scoping, and update concerns.yaml G-064 description to reflect that retrofit search is exhausted (reviewer v2.x is its own roadmap).

Decision authority: human, via Watchtower `/inception/T-1688`.
