# T-1833 — T-1736 spike harvest read session JSONLs outside PROJECT_ROOT — path-isolation

> **Inception research artifact** (backfilled by T-2515 from the `T-1833` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1833-t-1736-spike-harvest-read-session-jsonls.md`. **Decision recorded: GO.**

## Problem Statement

The T-1736 spike (prompt-triage classifier accuracy bench, 2026-05-05) shipped a harvest
tool — `scripts/spikes/T-1736-harvest.py:116` — that **defaults to reading
`~/.claude/projects/*/*.jsonl`** (Path.home() / ".claude" / "projects") and writing the
content into `.context/spikes/T-1736-prompts.jsonl` inside PROJECT_ROOT. This is a
direct path-isolation violation per `feedback_path_isolation_strict`: even read-only
inspection of paths outside PROJECT_ROOT is forbidden. The leaked Azure AD OAuth client
secret (T-1834) was the *consequence* of the read; the read itself was the violation.

**Why now:** Layer 3 RCA of fw-upgrade-incident-2026-05-14 cluster. T-1834 purged the
secret-bearing artefact from git history. T-1828 (mirror) is healed. But the harvest
**tooling remains in the tree** (`scripts/spikes/T-1736-{harvest,sample,metrics,runharness}.py`)
and a derived artefact **`.context/spikes/T-1736-sampled.jsonl`** still carries 50
sampled entries from 16+ outside-PROJECT_ROOT source files. The violation class is live.

## Assumptions

- **A1:** No other spike under `scripts/spikes/` reads outside PROJECT_ROOT by default
  *(test: grep `Path.home`/`/.claude/`/`projects/-` in scripts/spikes/ — only T-1736
  family matches; validated this session)*.
- **A2:** `T-1736-sampled.jsonl` (50 entries, 16 outside-PROJECT_ROOT sources) is the
  only surviving in-repo derivative of the harvest *(test: `grep -rln "projects/-"
  .context/spikes/` returns only T-1736-sampled.jsonl; validated this session)*.
- **A3:** A PreToolUse boundary-hook extension can structurally block scripts opening
  files under `~/.claude/projects/` regardless of caller (the boundary hook today
  blocks `cd` to outside paths — see G-065 — and is being extended for argument-level
  detection under T-1702/T-1707).
- **A4:** The originating T-1736 tasks (1736, 1740, 1741, 1742) have already shipped;
  the harvest scripts are not on any active critical path *(test: nothing in `.tasks/active/`
  depends on T-1736-harvest.py)*.

## Exploration Plan

This inception is **research-done** — the source code (`scripts/spikes/T-1736-harvest.py:116`)
is the smoking-gun evidence. No additional spike is needed before decision; the
prevention is bounded and the fix path is mechanical.

## Technical Constraints

- Boundary hook today is `cd`-only (G-065). Argument-level extension is the responsibility
  of T-1702 (Stream 1) and T-1707 (Stream 2: fw doctor scope tagging) — both `started-work`.
- Removing `scripts/spikes/T-1736-*.py` does NOT require a history rewrite (they are not
  sensitive themselves; only their output was). They can be deleted by ordinary commit.
- `T-1736-sampled.jsonl` removal: same — ordinary `git rm`. Contents are derivative of
  the already-purged corpus; a subset of harvested text may still contain low-probability
  secret material (50/3114 = 1.6% sample rate). Scrub for safety, not for residual leak.

## Scope Fence

**IN scope:**
- Recommendation on disposition of the 4 T-1736 spike scripts and the surviving sampled.jsonl
- Recommendation on structural prevention (boundary-hook extension vs separate lint)
- Audit decision: enumerate any other spike tooling reading outside PROJECT_ROOT

**OUT of scope:**
- The T-1834 secret rotation (user declined; not part of this inception)
- Implementing the boundary-hook argument-level extension (already owned by T-1702/T-1707)
- Re-running classifier benches (T-1740/T-1741/T-1742 are independent; their results live
  alongside T-1736-results.jsonl which contains no outside-PROJECT_ROOT data)

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Recommendation

**Recommendation:** GO — three-prong remediation, all bounded and reversible

**Rationale:** The violation class (script default-reading outside PROJECT_ROOT) is
structural, the evidence is concrete (one source-line, one surviving artefact, one harvest
tree to delete). Doing nothing leaves the harvest tool armed for re-use by future
agents who may not know the path-isolation rule. The fix is mechanical and Level-C:
delete the offender, scrub the survivor, and add a structural gate so the class can't
recur. No new infrastructure required — the boundary-hook extension (T-1702/T-1707) is
already in flight for an adjacent concern (G-065) and can absorb this scope.

**Three prongs (each becomes one build task on GO):**

1. **Prong A — Scrub:** `git rm .context/spikes/T-1736-sampled.jsonl` +
   `git rm scripts/spikes/T-1736-{harvest,sample}.py`. Keep `T-1736-runharness.py`
   and `T-1736-metrics.py` if they don't read outside PROJECT_ROOT (verified: they
   don't; they consume only the in-repo `*-results.jsonl`). One-commit Level-C fix.

2. **Prong B — Gate (structural prevention):** extend the boundary hook (T-1702 sibling
   slice) to refuse Read/Bash/Write tool calls whose **argument** resolves to a path
   under `$HOME/.claude/projects/` or matches `**/projects/-*/*.jsonl`. This catches
   the read-half of the violation that today only `cd`-blocks. Pair with a one-line
   addition to `agents/context/check-active-task.sh` boundary-check stanza. Test:
   bats fixture that simulates a script trying to open `~/.claude/projects/foo.jsonl`
   → blocked with the standard boundary message + named policy reference (L-378).

3. **Prong C — Audit:** add a `fw audit` check that greps `scripts/spikes/**` and
   `tools/**` for the pattern `Path.home\(\)|\.claude|projects/-` and WARNs on any
   match without a `# PATH-ISOLATION-OK:` comment exemption. Failed scan ratchets a
   gap entry (G-065 sibling) so the next regression surfaces in the 15-min audit cron.

**Evidence:**

- **Source:** `scripts/spikes/T-1736-harvest.py:116` — `default=str(Path.home() / ".claude" / "projects")`
- **Output path:** `scripts/spikes/T-1736-harvest.py:121` — writes into `.context/spikes/T-1736-prompts.jsonl` (already purged by T-1834)
- **Sample tool:** `scripts/spikes/T-1736-sample.py:17` — reads the harvest output, writes `.context/spikes/T-1736-sampled.jsonl`
- **Surviving derivative:** `.context/spikes/T-1736-sampled.jsonl` — 50 entries, 16 unique outside-PROJECT_ROOT source paths (audited this session; counts only)
- **Already-shipped purge:** T-1834 (commit `53293e76`) — proves the history-rewrite path works for this class
- **Already-planned gate:** T-1702 (Stream 1 — boundary-hook argument extension) and T-1707 (fw doctor scope tagging) — both `started-work`; can absorb Prong B scope without a new arc
- **Gap entry:** G-065 already names the gap ("Boundary hook is read-blind"); this inception scopes one consumer of the fix
- **L-378:** already captured ("agent must never quote secret values verbatim in chat") — Prong A scrub honors this by never reading sampled.jsonl content

**Go/No-Go evaluation:**
- ✓ Root cause identified with bounded fix path (3 prongs, each ≤1 session)
- ✓ Fix is scoped, testable, and reversible (each prong is its own git commit)
- ✗ NOT a fundamental redesign (boundary hook already exists, just being extended)
- ✗ Fix cost does NOT exceed benefit (1 session vs ongoing leak risk + 10-day-undetected class)

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — three-prong remediation, all bounded and reversible

Rationale: The violation class (script default-reading outside PROJECT_ROOT) is
structural, the evidence is concrete (one source-line, one surviving artefact, one harvest
tree to delete). Doing nothing leaves the harvest tool armed for re-use by future
agents who may not know the path-isolation rule. The fix is mechanical and Level-C:
delete the offender, scrub the survivor, and add a structural gate so the class can't
recur. No new infrastructure required — the boundary-hook extension (T-1702/T-1707) is
already in flight for an adjacent concern (G-065) and can absorb this scope.

Three prongs (each becomes one build task on GO):

1. Prong A — Scrub: `git rm .context/spikes/T-1736-sampled.jsonl` +
   `git rm scripts/spikes/T-1736-{harvest,sample}.py`. Keep `T-1736-runharness.py`
   and `T-1736-metrics.py` if they don't read outside PROJECT_ROOT (verified: they
   don't; they consume only the in-repo `-results.jsonl`). One-commit Level-C fix.

2. Prong B — Gate (structural prevention): extend the boundary hook (T-1702 sibling
   slice) to refuse Read/Bash/Write tool calls whose argument resolves to a path
   under `$HOME/.claude/projects/` or matches `/projects/-/.jsonl`. This catches
   the read-half of the violation that today only `cd`-blocks. Pair with a one-line
   addition to `agents/context/check-active-task.sh` boundary-check stanza. Test:
   bats fixture that simulates a script trying to open `~/.claude/projects/foo.jsonl`
   → blocked with the standard boundary message + named policy reference (L-378).

3. Prong C — Audit: add a `fw audit` check that greps `scripts/spikes/` and
   `tools/` for the pattern `Path.home\(\)|\.claude|projects/-` and WARNs on any
   match without a `# PATH-ISOLATION-OK:` comment exemption. Failed scan ratchets a
   gap entry (G-065 sibling) so the next regression surfaces in the 15-min audit cron.

Evidence:

- Source: `scripts/spikes/T-1736-harvest.py:116` — `default=str(Path.home() / ".claude" / "projects")`
- Output path: `scripts/spikes/T-1736-harvest.py:121` — writes into `.context/spikes/T-1736-prompts.jsonl` (already purged by T-1834)
- Sample tool: `scripts/spikes/T-1736-sample.py:17` — reads the harvest output, writes `.context/spikes/T-1736-sampled.jsonl`
- Surviving derivative: `.context/spikes/T-1736-sampled.jsonl` — 50 entries, 16 unique outside-PROJECT_ROOT source paths (audited this session; counts only)
- Already-shipped purge: T-1834 (commit `53293e76`) — proves the history-rewrite path works for this class
- Already-planned gate: T-1702 (Stream 1 — boundary-hook argument extension) and T-1707 (fw doctor scope tagging) — both `started-work`; can absorb Prong B scope without a new arc
- Gap entry: G-065 already names the gap ("Boundary hook is read-blind"); this inception scopes one consumer of the fix
- L-378: already captured ("agent must never quote secret values verbatim in chat") — Prong A scrub honors this by never reading sampled.jsonl content

Go/No-Go evaluation:
- ✓ Root cause identified with bounded fix path (3 prongs, each ≤1 session)
- ✓ Fix is scoped, testable, and reversible (each prong is its own git commit)
- ✗ NOT a fundamental redesign (boundary hook already exists, just being extended)
- ✗ Fix cost does NOT exceed benefit (1 session vs ongoing leak risk + 10-day-undetected class)

**Date**: 2026-05-17T07:00:23Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-954d53b7
- **Timestamp:** 2026-06-02T14:59:55Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Problem statement validated (source-line evidence at scripts/spikes/T-1736-harvest.py:116)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=scripts/spikes/T-1736-harvest.py in: Problem statement validated (source-line evidence at scripts/spikes/T-1736-harvest.py:116)`
### 2026-05-17T07:00:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
