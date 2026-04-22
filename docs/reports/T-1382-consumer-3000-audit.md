# T-1382 — Consumer `:3000` Hardcode Audit (post T-1376 B1-B5)

**Date:** 2026-04-22
**Task:** T-1382
**Related:** T-1376 (parent inception, GO), T-1378 (B1-B3 framework fixes), T-1379 (B4 CLAUDE.md), T-1380 (B5 accessors), T-1381 (framework doc alignment)

## Scope

After shipping `fw watchtower port`/`url` as the canonical accessor and fixing all framework-side hardcodes, sweep existing consumer projects for stale `:3000` hardcodes that T-1376 was supposed to prevent recurring.

## Consumer inventory

Checked `/opt/*` and `/003-NTB-ATC-Plugin` for `.framework.yaml` or `.agentic-framework/` markers. Found:

| Consumer | Framework mode | Active TermLink session |
|----------|---------------|-------------------------|
| `/003-NTB-ATC-Plugin` | Vendored (`.agentic-framework/`) | `tl-bubfbc3w` (ntb-dev-test) |
| `/opt/002-Claude-Partner-Network` | Shim (`.framework.yaml`) | none visible |

## Findings per consumer

### /003-NTB-ATC-Plugin

Hits (excluding third-party node_modules and truncation slice notation):

| File | Category | Propagates via |
|------|----------|----------------|
| `CLAUDE.md:51` | Instructive (documents :3039 override to avoid :3000 collision) | N/A — leave |
| `CLAUDE.md:140` | Stale template copy — pre-T-1378 B2 | Not auto — consumer edits CLAUDE.md manually; `lib/upgrade.sh` preserves project sections |
| `.claude/commands/resume.md:13,34` | Stale template copy — pre-T-1378 B1 | **Not auto** — `lib/upgrade.sh:694-709` skips if exists |
| `.agentic-framework/lib/init.sh:806,827` | Vendored snapshot, pre-T-1378 | Auto on next `fw upgrade` (vendored sync) |
| `.agentic-framework/lib/templates/claude-project.md:110` | Vendored snapshot, pre-T-1378 B2 | Auto on next `fw upgrade` (vendored sync) |
| `.agentic-framework/lib/verify-acs.sh:54` | Fallback pattern (legitimate) | N/A — defensive default |
| `.agentic-framework/agents/context/check-tier0.sh:343` | Fallback pattern (legitimate) | N/A — defensive default |
| `.agentic-framework/docs/walkthrough/*` | Vendored docs | Auto on next `fw upgrade` |
| `.agentic-framework/docs/reports/T-968-*.md` | Historical framework report | Don't rewrite history |
| `.agentic-framework/web/blueprints/*.py` | Slice notation `[:3000]` (string truncation) | False positive, ignore |
| `.agentic-framework/lib/ts/node_modules/@types/node/inspector.d.ts` | Third-party TypeScript defs | Ignore |
| `.tasks/active/T-045-azure-hosting-*.md` | Consumer task body (Dutch) | Consumer's own task content |

### /opt/002-Claude-Partner-Network

| File | Category | Propagates via |
|------|----------|----------------|
| `CLAUDE.md:110` | Stale template copy — pre-T-1378 B2 | Not auto — manual edit |
| `.claude/commands/resume.md:13,34` | Stale template copy — pre-T-1378 B1 | **Not auto** — `lib/upgrade.sh:694-709` skips if exists |

## Identified gap

**`lib/upgrade.sh:694-709` preserves existing `.claude/commands/resume.md` regardless of template changes.** The only path to pick up T-1378 B1's fix is `fw init --force`, which is destructive (overwrites project-specific customizations).

Implications:
- T-1376's "recurrence prevention" thesis only holds for **new** consumer inits
- Existing consumers remain on the broken instruction text indefinitely
- The fix is invisible — no gate warns when template drift exists

## Fix candidates

**Option A — patch `lib/upgrade.sh` to detect resume.md drift**

Compare the framework's current template output (what `init.sh` *would* write) against the consumer's existing file. If they differ, write a `.bak` and refresh. Preserves custom content via merge or fallback-to-force prompt. Similar pattern to how CLAUDE.md governance-section refresh works at line 130+.

Effort: ~1 session, build task. Low blast radius if gated on confirmed drift.

**Option B — send pickup proposals to each consumer TermLink agent**

Per CLAUDE.md feedback memory (no cross-repo edits), dispatch via `termlink remote inject` to `tl-bubfbc3w` and whichever session serves /opt/002-Claude-Partner-Network (none running as of 2026-04-22 20:55 UTC). Each agent patches its own `.claude/commands/resume.md` and `CLAUDE.md` line ~110/140 using the proven edits from T-1378/T-1381.

Effort: ~10 min dispatch, but requires the consumer agent to be running and authorized to accept incoming proposals.

**Option C — document-only; accept consumer drift until next full init**

Register gap; update consumer onboarding to mention `fw init --force` as an option after major template changes. No automation.

**Recommendation:** A. The gap is structural — any future template fix (not just T-1378's) faces the same silent-drift problem. One upgrade-side fix prevents an unknown number of future recurrences. B is tactical cleanup; combine with A for completeness.

## Learning candidate

L-238 captured the framework-side rule ("grep repo for legacy literal after shipping canonical accessor"). This audit extends it: **grepping only PROJECT_ROOT misses consumer projects, and consumer-owned files don't update on `fw upgrade`.** Proposed addition:

> "After fixing a template in `lib/init.sh` / `lib/templates/*`, verify `lib/upgrade.sh` propagates the fix to existing consumers. If it does not, either patch upgrade.sh or explicitly dispatch the fix to each consumer via TermLink."

## Follow-up tasks

- **T-1383 (inception or build):** Patch `lib/upgrade.sh` to detect `.claude/commands/resume.md` template drift and prompt refresh. Size: one session. Inception threshold not met (single file, single function) → build task with ~15 LoC change + bats regression.
- **T-1384 (build, optional):** Dispatch fix proposals via TermLink to /003-NTB-ATC-Plugin (`tl-bubfbc3w`) and start agent at /opt/002-Claude-Partner-Network to receive proposal.

No code changes proposed in this task — it is the audit artifact only.
