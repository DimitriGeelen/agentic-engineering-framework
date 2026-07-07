# T-1376 — Port parameter visibility — why agents keep defaulting to :3000 after T-1154

> **Inception research artifact** (backfilled by T-2515 from the `T-1376` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1376-port-parameter-visibility--why-agents-ke.md`. **Decision recorded: GO.**

## Problem Statement

Agents repeatedly default to `:3000` when referring to Watchtower, despite 5 completed tasks intended to eliminate this. User observation (2026-04-22): "we get mistakes, mistakes, mistakes over and over again — defaulting to port 3000, or worse, killing the existing session."

**Infrastructure is already in place:**
- `FW_PORT` env var (CLAUDE.md:508 Config table)
- `fw config set PORT 4444` per-project (T-885, T-903)
- `.context/working/watchtower.{pid,port,url}` triple as source-of-truth (T-1287)
- `bin/watchtower.sh` announces port at startup lines 210-217 ("Local: / LAN: / PID: / Log:")
- `_watchtower_url` helper function

**Real surviving hardcoded sites (audit via grep `:3000` in bin/ lib/ agents/):**
1. `lib/init.sh:811,832` — **/resume skill hardcodes `curl http://localhost:3000/`** — instructs every agent's session-start to poke :3000 specifically, even if Watchtower runs elsewhere
2. `lib/templates/claude-project.md:110` — **consumer CLAUDE.md template hardcodes :3000** in the verification example shown to every new consumer project
3. `agents/monitor/liveness-check.sh:52` — **liveness cron hardcodes localhost:3000**, ignores FW_PORT
4. `lib/verify-acs.sh:54,56,75` — fallbacks to 3000 if `_watchtower_url` fails (arguably correct)
5. `agents/audit/audit.sh:2830-2831` — fallback 3000 (correct pattern)
6. `agents/context/check-tier0.sh:343` — fallback 3000 (correct pattern)

Sites 1-3 are **instructions and templates shown to agents**. Every /resume, every new consumer, every liveness check reinforces "use 3000". Sites 4-6 are fallbacks used only when the source-of-truth fails — structurally correct.

**Additional ask from user:**
- Hoist port documentation from CLAUDE.md line 508 (mid-file Config table) to **top of CLAUDE.md**, so agents encounter it before any `:3000` anti-pattern.

## Assumptions

- A1: Fixing /resume + consumer CLAUDE.md template + liveness check will eliminate most recurring mistakes (TESTABLE — audit episodic memory for :3000 defaults post-fix)
- A2: A top-of-CLAUDE.md section on "which port is Watchtower on right now" will change agent behavior (TESTABLE — check if subsequent sessions probe triple file first)
- A3: A `fw watchtower port` subcommand (prints current port from triple) would further reduce re-derivation (UNVALIDATED — not yet built)
- A4: The 3 `fallback 3000` sites in lib/verify-acs.sh, audit.sh, check-tier0.sh are structurally correct (use `_watchtower_url` first, fallback only on failure) — no change needed

## Exploration Plan

- FS1 (audit, done in this inception): grep `:3000` across bin/ lib/ agents/ — 3 instruction/template sites identified.
- FS2 (fix, scoped): replace 3 hardcoded sites with `$(fw_config "PORT" 3000)` inline OR read from `.context/working/watchtower.port`.
- FS3 (doc, scoped): hoist port section to top of CLAUDE.md, pointing at triple file + `fw doctor` as single-source-of-truth.
- FS4 (subcommand, optional): add `fw watchtower port` that prints the current port (reads triple file, falls back to config, announces "Watchtower not running" if neither).

## Technical Constraints

- Template file (`lib/templates/claude-project.md`) is distributed to consumer projects via `fw init` — changes propagate only on new inits or `fw upgrade`.
- `/resume` skill text in `lib/init.sh` is part of the session-start workflow — safe to change (read dynamically each session).
- `agents/monitor/liveness-check.sh` runs from cron — may need to source `lib/config.sh` to access `fw_config`.

## Scope Fence

**IN:** FS1 audit (done), FS2 surgical replacement of 3 hardcoded sites, FS3 CLAUDE.md top-of-file port section, decision on FS4 (subcommand).

**OUT:** Rewriting T-1284 discovery logic (separate task). Per-project service port registry (T-885 shipped). Auto-restart on port collision.

## Go/No-Go Criteria

**GO if:**
- 3 hardcoded sites confirmed as anti-pattern (they are)
- Fix is scoped + reversible (it is — surgical grep/replace per site)
- Top-of-CLAUDE.md doc is cheap and high-leverage

**NO-GO if:**
- Fixing template file propagation is too disruptive (unlikely — `fw upgrade` handles it)
- Root cause is not sites 1-3 but deeper (would need post-fix recurrence data)

## Recommendation

**Recommendation:** GO — minimum fix is tractable.

**Rationale:** Infrastructure is done (T-885, T-903, T-1154, T-1287, T-1284). Recurrence is caused by **3 concrete agent-facing instruction sites** that hardcode :3000: the /resume skill, the consumer CLAUDE.md template, and the liveness cron. Each is a 1-3 line surgical fix. Adding a top-of-CLAUDE.md "Which port is Watchtower on" block closes the documentation loop. Optional: `fw watchtower port` subcommand as a public single-source-of-truth.

**Evidence:**
- Audit of bin/ lib/ agents/ surfaced 6 hits for `:3000` — 3 anti-pattern (instruction/template), 3 fallback (correct pattern)
- T-1287 triple file is authoritative
- `bin/watchtower.sh` already announces port on start
- User reported recurrence TODAY despite prior work — gap is in instructions/templates, not infrastructure

**Proposed build plan (if GO):**
- **B1** (≤1 session): Patch `lib/init.sh` /resume skill to read `.context/working/watchtower.url` instead of hardcoding :3000.
- **B2** (≤1 session): Patch `lib/templates/claude-project.md` to reference the triple file + `fw doctor` instead of :3000 URL.
- **B3** (≤1 session): Patch `agents/monitor/liveness-check.sh` to source `lib/config.sh` and use `fw_config PORT`.
- **B4** (≤1 session): Add "Watchtower Port" block near top of CLAUDE.md (before Task System section), pointing at triple file + `fw doctor`.
- **B5** (optional, ≤1 session): `fw watchtower port` subcommand.

**Prioritisation:** B1 highest leverage (every /resume triggers it). B3 highest frequency (cron). B2 highest blast-radius (propagates to new consumers).

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — minimum fix is tractable.

Rationale: Infrastructure is done (T-885, T-903, T-1154, T-1287, T-1284). Recurrence is caused by 3 concrete agent-facing instruction sites that hardcode :3000: the /resume skill, the consumer CLAUDE.md template, and the liveness cron. Each is a 1-3 line surgical fix. Adding a top-of-CLAUDE.md "Which port is Watchtower on" block closes the documentation loop. Optional: `fw watchtower port` subcommand as a public single-source-of-truth.

Evidence:
- Audit of bin/ lib/ agents/ surfaced 6 hits for `:3000` — 3 anti-pattern (instruction/template), 3 fallback (correct pattern)
- T-1287 triple file is authoritative
- `bin/watchtower.sh` already announces port on start
- User reported recurrence TODAY despite prior work — gap is in instructions/templates, not infrastructure

Proposed build plan (if GO):
- B1 (≤1 session): Patch `lib/init.sh` /resume skill to read `.context/working/watchtower.url` instead of hardcoding :3000.
- B2 (≤1 session): Patch `lib/templates/claude-project.md` to reference the triple file + `fw doctor` instead of :3000 URL.
- B3 (≤1 session): Patch `agents/monitor/liveness-check.sh` to source `lib/config.sh` and use `fw_config PORT`.
- B4 (≤1 session): Add "Watchtower Port" block near top of CLAUDE.md (before Task System section), pointing at triple file + `fw doctor`.
- B5 (optional, ≤1 session): `fw watchtower port` subcommand.

Prioritisation: B1 highest leverage (every /resume triggers it). B3 highest frequency (cron). B2 highest blast-radius (propagates to new consumers).

**Date**: 2026-04-22T18:29:44Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5ab96e8c
- **Timestamp:** 2026-06-02T14:57:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
