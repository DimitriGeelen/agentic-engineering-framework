# T-1685 Phase 1 spike — fw audit as orchestrator consumer

**Inception task:** T-1685
**Author:** agent (autonomous Phase 1, requires human GO before any build)
**Created:** 2026-05-02
**Status:** spike-complete

## Question

Can `fw audit` be refactored to dispatch its slow analytical checks
through the orchestrator (`fw termlink dispatch --task-type audit`),
giving G-064 its first real autonomous consumer? At what scope?

## Why this exists

G-064: orchestrator substrate has zero production consumers. Audit
is the framework's largest inline batch process (3700 LOC, 25+ check
sections, runs every 30 minutes). T-1686 explores a different angle
(config UI).

## Current state survey

- `agents/audit/audit.sh` — 3689 lines. 25 sections delimited by
  `=== <NAME> ===` headers.
- Largest sections by LOC:
  | LOC | Section |
  | --- | --- |
  | 753 | DISCOVERY: TREND DETECTION |
  | 321 | OE-DAILY: DAILY CONTROL CHECKS |
  | 274 | STRUCTURE CHECKS |
  | 270 | DISCOVERY: OMISSION DETECTION |
  | 239 | TREND ANALYSIS |
  | 111 | GIT TRACEABILITY CHECKS |
  | 110 | LEARNING CAPTURE CHECKS |
  | 99 | ENFORCEMENT / CONCERNS |
  | 98 | EPISODIC MEMORY CHECKS |

- Auxiliary python scripts referenced by audit.sh: 0.05s each
  (`active-task-scan.py`, `completed-task-scan.py`,
  `orchestrator-mcp-scan.sh`).
- **Measured wall-clock for full `fw audit` run: 2 minutes 18
  seconds** (real 2m18s, user 1m6s, sys 2m7s).

## Where the time goes

The 2m18s is dominated by `sys` time (2m7s) — i.e. fork/exec overhead
for sub-shells, `git log` invocations, `grep` over the whole repo,
file stat operations across `.context/`, `.tasks/`, `.git/`. The
analytical content is almost entirely **deterministic, file-based,
structural** — `grep -c`, `awk`, YAML parsing, git log scanning, count
arithmetic.

There is **no LLM-amenable workload** in audit.sh. Every check has a
single correct answer derivable from `grep`/`awk`/`git`. None benefits
from "let a model think about this."

## Proposed scope

**There is no viable scope for option 3 as originally framed.**

If we still wanted an audit-as-consumer story, candidates would have
to be invented (e.g. "LLM summarises trend findings" instead of the
existing rule-based aggregator). That is gilding — adding a
non-deterministic LLM step to a deterministic pipeline that already
works in 2m18s, costs nothing, and is fully reproducible.

If audit speed is a real concern, the actual fix is parallel bash —
`xargs -P` over check sections, GNU parallel, or splitting audit.sh
into independent processes. None of that needs the orchestrator.

## Cost estimate

N/A — recommended action is **don't build**.

If we did build a force-fit consumer (e.g. dispatch a "summarise
trend findings" worker), estimated cost would be ~1-2 sessions of
work for negative value (slower audit + LLM cost per run + new
failure modes from network/API dependencies in a pipeline that today
has no external dependencies).

## Recommendation

**NO-GO.**

**Rationale:** The premise was "audit has slow analytical checks that
would benefit from typed routing." Investigation shows audit's
slowness is structural (fork/exec overhead, file I/O, git ops), not
analytical. There is no LLM-amenable workload to route. Forcing one
would inject non-determinism and external dependencies into a
deterministic pipeline that costs zero.

This NO-GO confirms what G-064 implicitly captured: the framework's
current workload is largely deterministic, and the orchestrator
doesn't have a natural autonomous consumer waiting in the existing
codebase. G-064 stays OPEN regardless of T-1685's outcome — fixing
it requires either creating new workload that benefits from
LLM-typed-routing, OR accepting the substrate is dormant.

T-1686 (sibling inception) explores a different angle (config UI).
That path doesn't autonomously close G-064 either, but it makes the
substrate more useful WHEN someone does invoke it — which is a
prerequisite for any future autonomous consumer ever being worth
building.

## Decisions captured

### 2026-05-02 — Why NO-GO instead of force-fit

- **Chose:** NO-GO on audit refactor.
- **Why:** Audit slowness is bash/git/IO; no LLM-amenable workload
  exists in current audit.sh content. Refactoring would not improve
  performance and would introduce LLM-cost + non-determinism into a
  deterministic pipeline.
- **Rejected:** Force-fitting a synthetic LLM consumer (e.g. "have
  haiku summarise trend findings") because it repeats the
  substrate-without-need pattern that G-064 just named.
