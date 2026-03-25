# T-614: Consumer Project Governance Bypass Investigation

## Executive Summary

All 7 consumer projects running the Agentic Engineering Framework are at v1.2.6 while
the framework is at v1.3.0. Each is missing 2 of 13 hooks and ~180 lines of CLAUDE.md
governance rules. The `fw upgrade` command exists but has a hook detection bug, `fw doctor`
has no consumer staleness check, and no upgrade audit trail exists. This is a systemic
fleet-wide governance decay — not a single-project issue.

**Trigger:** User reported TermLink consumer project agent repeatedly bypassing Tier 0
governance and working without tasks. Investigation expanded to all consumers.

**Classification:** Structural gap (G-023), not regression. The propagation mechanism
was never fully built — `fw upgrade` was built (T-169, T-494) but has defects that
prevent it from detecting missing hooks.

## Investigation Scope

### Projects Audited

| Project | Path | Version | Hooks | Init Date | Days Stale |
|---------|------|---------|-------|-----------|------------|
| Framework (baseline) | /opt/999-Agentic-Engineering-Framework | 1.3.0 | 13 | — | — |
| openclaw-evaluation | /opt/openclaw-evaluation | 1.2.6 | 11 | 2026-03-23 | 2 |
| 3021-Bilderkarte | /opt/3021-Bilderkarte-tool-llm | 1.2.6 | 11 | 2026-03-12 | 13 |
| termlink | /opt/termlink | 1.2.6 | 11 | 2026-03-08 | 17 |
| 050-email-archive | /opt/050-email-archive | 1.2.6 | 11 | 2026-03-18 | 7 |
| 150-skills-manager | /opt/150-skills-manager | 1.2.6 | 11 | 2026-03-23 | 2 |
| 001-sprechloop | /opt/001-sprechloop | 1.2.6 | 11 | 2026-02-17 | 36 |
| 995_2021-kosten | /opt/995_2021-kosten | 1.2.6 | 11 | 2026-03-16 | 9 |

### Missing Hooks (All Consumers)

| Hook | Matcher | Purpose | Added In |
|------|---------|---------|----------|
| check-project-boundary | Write\|Edit\|Bash | Block cross-project writes | T-559 |
| commit-cadence | Write\|Edit | Warn when too long without committing | T-591 |

### Missing CLAUDE.md Sections (All Consumers)

- Copy-Pasteable Commands (T-609)
- TermLink Integration (T-503) — entire section
- Key Primitives, Timeout Orphan Warning (T-577), Budget Rules, Phase Roadmap
- Remote Session Access (TermLink)
- Updated budget thresholds (consumers: 150K/75%, framework: 190K/95% of 200K)
- Autonomous Mode Boundaries — missing `--force` suggestion prohibition line

## Root Causes

### 1. fw upgrade Hook Detection Bug (CRITICAL)

**File:** `lib/upgrade.sh` line ~294

`upgrade.sh` detects hooks by COUNT only (expects 10), not by TYPE enumeration.
`init.sh` generates 13 hooks. The expected count is hardcoded and stale.

**Effect:** Even if someone runs `fw upgrade`, it sees "11 hooks >= 10 expected" and
reports hooks as fine. The 2 missing hooks are never detected.

**Fix:** Enumerate required hooks by name (from a canonical list), compare against
consumer's settings.json, report each missing hook individually.

### 2. fw doctor Has No Consumer Awareness (HIGH)

**File:** `bin/fw` (doctor section)

`fw doctor` validates framework health but has zero consumer-specific checks:
- No version drift detection (consumer vs framework)
- No hook completeness by type
- No CLAUDE.md governance hash comparison
- No upgrade timestamp tracking
- Version mismatch is WARN with no actionable suggestion

**Fix:** Add `fw doctor` consumer health section: version comparison, hook enumeration,
CLAUDE.md governance hash, last upgrade timestamp.

### 3. No Upgrade Audit Trail (HIGH)

**File:** `lib/upgrade.sh`

No record of WHEN `fw upgrade` was run, WHAT version it upgraded from, or WHERE.
`.framework.yaml` records current version but no history. Cannot answer "has this
consumer ever been upgraded?"

**Fix:** Add `last_upgrade` timestamp to `.framework.yaml`. Add upgrade history
to `.context/audits/upgrades.yaml`.

### 4. Bash Tool Not Task-Gated (MEDIUM)

**File:** `.claude/settings.json`, `agents/context/check-active-task.sh`

`check-active-task` only matches `Write|Edit`. Bash is ungated for task existence.
An agent can create/modify files via `echo > file`, run `git commit`, or batch-create
tasks without any task gate firing.

**Documented:** Learning from T-549 acknowledges this gap but labels it TBD.

**Bootstrap problem:** `fw context init` and `fw task create` need Bash before any
task exists. Gating all Bash breaks session startup.

**Fix:** Allowlist approach — gate Bash on task existence EXCEPT for known bootstrap
commands (fw context init, fw task create, git status, read-only operations).

### 5. fw update Doesn't Suggest fw upgrade (LOW)

**File:** `lib/update.sh`

After `fw update` completes (framework self-update), it does not suggest running
`fw upgrade` for known consumer projects. User must manually discover the need.

**Fix:** After successful update, scan for `.framework.yaml` files in /opt/ and
suggest `fw upgrade <path>` for each stale consumer.

## Specific Project Findings

### TermLink (/opt/termlink)

- **Trigger for investigation:** User reported governance bypass
- **CLAUDE.md:** 821 lines (180 behind framework). Has G-020 Pickup Message Handling.
- **Focus:** null (no task focused). Session 3 days stale.
- **Bypass log:** 3 entries, all human-authorized, all clean.
- **Hook divergence:** Vendored `check-active-task.sh` has T-560 session stamp code
  that the framework version lacks (consumer is AHEAD on this specific script).
- **Assessment:** Hooks are structurally sound. Agent misbehavior likely due to stale
  CLAUDE.md missing behavioral rules added since v1.2.6.

### 050-email-archive (/opt/050-email-archive)

- **Audit grade:** A- (55 PASS, 6 WARN, 0 FAIL)
- **CLAUDE.md:** 607 lines (394 behind — mostly project-specific content is shorter)
- **Git traceability:** 70% (below 80% target)
- **Bypass log:** 1 entry, human-authorized.
- **Assessment:** Healthier than TermLink overall. Same version drift vulnerability.

## Remediation Plan

### Tier 1 — Fix the tooling (blocks fleet upgrade)

| Task | Description | Dependency |
|------|-------------|------------|
| T-615 | Fix hook count bug in upgrade.sh — enumerate by type | None |
| T-616 | Add consumer staleness check to fw doctor | None |
| T-617 | Upgrade audit trail in .framework.yaml | None |

### Tier 2 — Apply the fix (requires Tier 1)

| Task | Description | Dependency |
|------|-------------|------------|
| T-618 | Fleet-wide consumer upgrade — all 7 projects | T-615 |

### Tier 3 — Structural prevention

| Task | Description | Dependency |
|------|-------------|------------|
| T-619 | Inception: Bash task gate with bootstrap allowlist | None |

## Go/No-Go Assessment

**GO criteria met:**
- Clear root causes identified (5)
- Remediation is bounded (3 build tasks + 1 fleet operation + 1 inception)
- Each task fits in one session
- No architectural redesign needed — extends existing `fw upgrade` and `fw doctor`
- Evidence base: 7 consumer projects audited, 4 structural gaps documented

**Risk:** Low. Changes to `upgrade.sh` and `bin/fw` are additive (new checks),
not destructive (no existing behavior removed).

**Recommendation:** GO — fix T-615 first (unblocks fleet upgrade), then T-616/T-617
in parallel, then T-618 to apply fixes across all consumers.

## Learnings Captured

- L-118: fw upgrade hook detection uses count not type — fleet-wide impact
- L-119: Consumer project governance decays silently — no detection mechanism

## Gap Registered

- G-023: Consumer project governance decays silently — no detection, no propagation,
  no audit trail. Severity: urgent. Status: watching. Remediation: T-615 through T-619.
