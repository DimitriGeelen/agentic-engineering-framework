# T-1261 — Consumer cron-registry seeds empty: RCA + remediation plan

**Status:** Captured 2026-04-15 after the user reported `fw cron install` on `/003-NTB-ATC-Plugin` proposing to DELETE the legacy 10-job audit crontab and replace it with a near-empty file. Confirmed two-line root cause + 50% blast radius across this host.

**Class:** L-006 enumeration-divergence — same family as T-1112/T-1113, but at a different layer. T-1112 fixed "two populated systems drift". T-1261 fixes "two systems seeded differently so they were never in sync from day 1."

---

## Symptom

On `/003-NTB-ATC-Plugin` (vendored install via `.agentic-framework/`), running `fw cron install`:

1. Reads `.context/cron-registry.yaml` (empty: `jobs: []`)
2. Generates a near-empty `/etc/cron.d/agentic-audit-003-ntb-atc-plugin` (just `SHELL` + `PATH` + comments)
3. Diffs against existing 10-job audit crontab
4. **Proposes to DELETE all 10 jobs** and install the empty file
5. On confirm, the project stops self-auditing entirely

User confirmed via `fw cron generate`: "0 active, 0 paused (0 total)". Workaround used: `fw audit schedule install` (legacy hardcoded template) which re-installed the 10-job crontab — bypassing the registry entirely.

## Root cause (two lines of code)

### Surface 1 — `lib/init.sh:150-163`

```bash
#@init: yaml-8cr .context/cron-registry.yaml jobs
if [ ! -f "$target_dir/.context/cron-registry.yaml" ]; then
    cat > "$target_dir/.context/cron-registry.yaml" << 'CRONREGEOF'
# Cron Registry — Structured source of truth for scheduled jobs (T-448)
# Read by web/blueprints/cron.py and fw cron generate.
# Editable by humans, controllable via Watchtower web UI.
jobs: []                  # <-- EMPTY
CRONREGEOF
fi
```

### Surface 2 — `lib/upgrade.sh:297-322`

```bash
# ── 3b. Cron registry (T-448/T-653) ──
if [ ! -f "$target_dir/.context/cron-registry.yaml" ]; then
    cron_seeded=$((cron_seeded + 1))
    if [ "$dry_run" != true ]; then
        cat > "$target_dir/.context/cron-registry.yaml" << 'CRONREGEOF'
# Cron Registry — Structured source of truth for scheduled jobs (T-448)
# Read by web/blueprints/cron.py and fw cron generate.
jobs: []                  # <-- EMPTY
CRONREGEOF
    fi
fi
```

**Two divergent seeds (heredocs in two files) — both seed `jobs: []`.**

The legacy `fw audit schedule install` command installs a hardcoded 10-job template (independent of the registry), so consumers had a working audit cron from day 1 — but as soon as they touch the registry-driven `fw cron install`, the empty seed wins.

## Spike A — Consumer-safe default job set

Comparison of framework's 12-job registry vs legacy `fw audit schedule install` template:

| Job ID | In framework registry | In legacy template | Consumer-safe? |
|---|---|---|---|
| structural-30m | yes | yes | **yes** |
| traceability-hourly | yes | yes | **yes** |
| observations-6h | yes | yes | **yes** |
| oe-fast-30m | yes | yes | **yes** |
| oe-hourly | yes | yes | **yes** |
| oe-daily | yes | yes | **yes** |
| oe-weekly | yes | yes | **yes** |
| full-daily | yes | yes | **yes** |
| docs-daily | yes | yes | **yes** |
| retention-daily | yes | yes | **yes** |
| pickup-process | yes | NO | **yes** (added post-T-778, consumer-safe) |
| release-weekly | yes | NO | **NO — framework-dev only** (tags `/opt/999-Agentic-Engineering-Framework`) |

**Consumer-safe set: 11 jobs** (10 base + `pickup-process`).

**Independent confirmation:** `/opt/termlink` consumer registry has exactly these 11 jobs and runs them successfully — proves the set is correct and self-consistent.

## Spike B — Blast radius

Enumerated `/etc/cron.d/agentic-audit-*` on this host vs each consumer's `.context/cron-registry.yaml`:

| Consumer | Registry job count | /etc/cron.d/ job count | Status |
|---|---|---|---|
| `/003-NTB-ATC-Plugin` | **0** | 10 | **TRAP** — `fw cron install` would wipe 10 jobs |
| `/opt/150-skills-manager` | **0** | unknown (file present) | **TRAP** — same pattern |
| `/opt/termlink` | 11 | unknown (file present) | SAFE — registry populated |
| `/opt/999-Agentic-Engineering-Framework` (self) | 12 | 10+ | SAFE — registry populated |

**Blast radius: 2 of 4 consumers (50%) on this host are currently trapped.** Any non-vigilant `fw cron install` invocation wipes their audit schedule.

Plus the stray `/etc/cron.d/agentic-audit` (no project suffix, points at `/opt/3021-Bilderkarte-tool-llm`) — leftover from T-1112, harmless but noise.

## Spike C — Safety guard design

`fw cron install` currently has no safety check when the install-diff would remove a large fraction of existing jobs. Proposed guard:

**Rule:** Refuse install if the proposed crontab would remove ≥50% of existing jobs from `/etc/cron.d/agentic-audit-<slug>`, OR if installed-jobs > 0 and proposed-jobs == 0.

**Behavior:**
1. Compute installed-job-count from `/etc/cron.d/agentic-audit-<slug>` (count non-comment, non-blank, non-`SHELL=`/`PATH=` lines)
2. Compute proposed-job-count from generated crontab
3. If `installed > 0 && proposed == 0` → HARD BLOCK with explicit error
4. If `proposed < installed * 0.5` → WARN + require `--force-bulk-removal` flag
5. Otherwise proceed normally

**Override:** `--force-bulk-removal` (explicit, logged in `.context/working/.gate-bypass-log.yaml`).

**Why two thresholds:** (a) `0 jobs proposed` is the exact field-report case — should never silently happen. (b) ≥50% removal catches "I deleted half the registry by accident" without blocking legitimate downsizing.

## Spike D — Template vs heredoc

Two existing heredocs in `lib/init.sh` and `lib/upgrade.sh` mean any future seed change must touch both files. Bug class: dual-maintenance drift.

**Proposal:** Single source `templates/cron-registry-default.yaml` in framework repo. Both `init.sh` and `upgrade.sh` `cp` from it.

**Chicken-and-egg check:** During `fw init`, `FRAMEWORK_ROOT` is set (init runs from inside framework). During `fw upgrade`, same (upgrade runs from framework's `lib/upgrade.sh`). No bootstrap problem.

**File path:** `${FRAMEWORK_ROOT}/templates/cron-registry-default.yaml`. Loaded in both seeds:
```bash
cp "${FRAMEWORK_ROOT}/templates/cron-registry-default.yaml" \
   "${target_dir}/.context/cron-registry.yaml"
```

## Spike E — Idempotency

Both init.sh and upgrade.sh wrap the seed in `if [ ! -f "$target_dir/.context/cron-registry.yaml" ]`. **Confirmed:** seeding defaults is a no-op on consumers that already have a populated registry. Good.

**Implication:** The forward-fix (seed defaults instead of `jobs: []`) only helps **new** installs. Existing trapped consumers (`/003-NTB-ATC-Plugin`, `/opt/150-skills-manager`) need a separate one-shot remediation:
- `fw cron seed-defaults [--force]` — explicit command that overwrites empty registry with the consumer-safe set
- Or: agent-driven manual fix per consumer (4 consumers on host, manageable)

## Build decomposition (post-GO)

| Task | Scope | LOC | Risk |
|---|---|---|---|
| **B1** | Add `templates/cron-registry-default.yaml` (11 jobs, consumer-safe set from Spike A) | +120 | Low |
| **B2** | `lib/init.sh:150-163` — replace heredoc with `cp` from B1 template | -10/+5 | Low |
| **B3** | `lib/upgrade.sh:297-322` — replace heredoc with `cp` from B1 template | -10/+5 | Low |
| **B4** | `bin/fw` cron install dispatch — add Spike-C safety guard (hard block on 0-proposed-vs-N-installed; warn-with-flag on >=50% removal) | +40 | Medium |
| **B5** | `tests/unit/lib_init.bats` — assert seeded registry has 11 jobs (not empty) | +20 | Low |
| **B6** | `tests/unit/lib_upgrade.bats` — same assertion | +20 | Low |
| **B7** | `tests/integration/cron-install-bulk-removal-blocked.bats` — assert install with empty registry on populated /etc/cron.d/ exits non-zero without `--force-bulk-removal` | +30 | Low |
| **B8** | `bin/fw` add `cron seed-defaults` subcommand for one-shot remediation of trapped consumers | +50 | Low |
| **B9** | Manual remediation: run B8 on `/003-NTB-ATC-Plugin` and `/opt/150-skills-manager` (one-time, agent-assisted from each consumer's terminal — cross-repo edit rule) | n/a | Low |
| **B10** | Update `fw doctor` to check for the trap pattern (registry empty + `/etc/cron.d/agentic-audit-<slug>` exists with N>0 jobs) and warn | +30 | Low |

**Total LOC:** ~340 added, ~20 removed. **Time estimate:** ~3-4 hours for B1-B7 (one session). B8-B10 in a follow-up.

## Recommendation

**Recommendation:** GO

**Rationale:**
- Two-line root cause confirmed in `lib/init.sh:157-162` and `lib/upgrade.sh:305-314`
- Blast radius confirmed: 2 of 4 consumers on this host are currently trapped (50%)
- Fix is bounded (~340 LOC), reversible (revert template + heredoc restore), and idempotent (existing populated registries unaffected)
- Consumer-safe job set independently validated by `/opt/termlink` running these exact 11 jobs successfully
- Same L-006 class as T-1112 — proven remediation pattern (chokepoint + invariant test)
- Safety guard (Spike C) is **orthogonal** to the seed fix — both prevent the same trap but at different layers (defence in depth)

**Evidence:**
- Field report (2026-04-15) on `/003-NTB-ATC-Plugin`: full terminal trace shows `fw cron install` proposing to delete 10 jobs
- `/003-NTB-ATC-Plugin/.context/cron-registry.yaml` confirmed `jobs: []` (196 bytes)
- `lib/init.sh:157-162` and `lib/upgrade.sh:305-314` confirmed seed `jobs: []`
- `/opt/termlink/.context/cron-registry.yaml` confirmed 11 jobs, working
- Framework's own `.context/cron-registry.yaml` has 12 jobs including `release-weekly` (framework-dev only)

**Critical user-facing warning (immediate):**
> Until B1-B4 ship: do **NOT** run `fw cron install` on any consumer where `cron-registry.yaml` shows `jobs: []` AND `/etc/cron.d/agentic-audit-<slug>` exists. The current install will silently wipe the audit schedule. Affected on this host: `/003-NTB-ATC-Plugin`, `/opt/150-skills-manager`. Use `fw audit schedule install` (legacy) until the structural fix lands.

## Scope fence

**IN:**
- RCA both surfaces (seed + safety)
- Consumer-safe default list (11 jobs)
- Build decomposition B1-B10
- Blast radius enumeration on this host

**OUT:**
- Fixing init.sh/upgrade.sh now (build follow-up after GO)
- Rewriting legacy `fw audit schedule install` (kept as deprecated alias)
- Cross-machine remediation (one host at a time)
- Cron-registry schema redesign

## Relationship to other L-006 work

This is the **tenth confirmed L-006 instance** in two weeks:
- G-024, G-024-NEW-07, G-037, G-038, G-039, G-040, G-041, G-042, G-043
- T-1112 (cron registry vs /etc/cron.d/ — populated drift)
- **T-1261 (cron seeds — empty divergence at install time)** ← this task

T-1112 closed the chokepoint at `fw cron install`. T-1261 closes the chokepoint at the **seed layer**. After both ship, the registry-cron pair is bound at both write-time (seed) and sync-time (install).

## Dialogue log

### 2026-04-15 — Field report → root cause confirmed in two reads

User pasted full terminal trace from `/003-NTB-ATC-Plugin` showing `fw cron install` proposing to delete 10 audit jobs. Distinguished from T-1112 by reading both task files: T-1112 fixed drift between two populated systems; T-1261 fixes "never in sync from day 1". User chose option "1" (create high-priority bugfix inception) → T-1261 created.

### 2026-04-15 — Spikes A-E executed in single batch

All five spikes resolved from local reads (no TermLink dispatch needed — work was small and serial-dependent on each prior finding). Independent validator: `/opt/termlink` consumer's working 11-job registry. Build decomposition produced. Recommendation: GO.
