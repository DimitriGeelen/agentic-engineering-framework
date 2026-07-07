# T-2416 — fw sessions — portable per-project session picker (option 1 + provider adapter

> **Inception research artifact** (backfilled by T-2515 from the `T-2416` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-2416-fw-sessions--portable-per-project-sessio.md`. **Decision recorded: GO.**

## Problem Statement

CC's `claude agents` picker shows sessions as a global flat list (Needs input / Working / Completed) with no project grouping. With ~18 active sessions across ~10 projects on this host, the operator cannot quickly answer "which sessions belong to project X" without scanning every row's cwd attribute. T-2414 demonstrated that we cannot restructure CC's native picker (the `-n` flag bypasses it entirely; CC owns the TUI). A side-channel view that we render ourselves, grouped by project, would close the gap without touching CC.

## Assumptions

- A1: `claude agents --json` is a stable contract from CC (verified — it returns the canonical fields name/cwd/state/sessionId/startedAt).
- A2: Other coding-agent CLIs (Cursor, Aider, Codex, Cline) will have equivalent JSON or programmatic session-listing — if not now, then on a similar trajectory (worth adapter-layering even before a second provider exists).
- A3: Operator's primary mental model for "project" = basename of cwd from the host's filesystem. Sessions outside a known repo (cwd in `$HOME` or `/tmp`) are not zero — they are real sessions and need a sensible bucket, not silent drop.

## Open Questions

- **IW-1: Interactive (pick a session to attach to) or static print-out?**
  confidence: 1
  disposition: deferred
  rationale: leaning static for v1 (no input handling, no terminal-mode complexity, can pipe/grep/redirect). Interactive attach is a follow-up after we see how the static form is actually used. Defer to dialogue.

- **IW-2: Sort order within each project — alphabetical, most-recent-activity, or by state (Needs input first)?**
  confidence: 1
  disposition: deferred
  rationale: state-first then by recency seems most useful (matches CC's flat picker ordering), but I'd rather operator decides than assume. Defer to dialogue.

- **IW-3: Age format — relative (`2d`, `1h`) like CC does, or absolute ISO timestamp?**
  confidence: 2
  disposition: deferred
  rationale: relative matches the screenshot operator referenced and stays compact. Absolute is more precise but verbose. Defer to dialogue.

- **IW-4: Sessions with cwd outside any repo (`/home/user`, `/tmp`, system paths) — single `(no project)` bucket, three (HOME / TMP / SYSTEM), or hide them?**
  confidence: 1
  disposition: deferred
  rationale: hiding loses data; three buckets adds noise; one bucket called something like `(loose)` or `(no project)` is the middle. Defer to dialogue.

- **IW-5: Canonical schema — what fields does the adapter MUST emit, and what's optional?**
  confidence: 2
  disposition: deferred
  rationale: MUST: `provider, project (cwd basename or "(loose)"), name, state, age_seconds, session_id`. OPTIONAL: `cwd, description, detail`. The renderer formats from the canonical fields; adapters can omit optional fields. Pin in the inception decision before build.

- **IW-6: Provider autodetect strategy — `command -v claude` only, or also probe `~/.claude/` directory existence, or rely on `FW_AGENT_PROVIDER` env explicitly?**
  confidence: 1
  disposition: deferred
  rationale: I'd default to `command -v` chain (claude → cursor → aider → cline → ...) with explicit `FW_AGENT_PROVIDER` override. If nothing detected, exit with clear "no adapter for current host" + how to add one. Defer to dialogue.

## Exploration Plan

1. **Dialogue with operator** on the 6 Open Questions (IW-1 through IW-6). Output: each disposed `answered` or `dissolved`.
2. **Canonical schema lock** (IW-5 answer becomes the inception's load-bearing contract). Write it to the Decisions section verbatim.
3. **CC adapter spike** — 30-line `agents/sessions/claude-code/list.sh` that calls `claude agents --json | jq` and emits the canonical schema as JSON-Lines. Verify it parses on the live host's session set. **Do this in a scratch dir, do NOT touch agents/ yet.**
4. **Renderer spike** — Python or bash script that consumes the canonical JSONL and renders the grouped tree (matching the screenshot mock from the playback). One sample output captured against this host.
5. **Live verify before GO close** — operator looks at the sample output, confirms shape matches expectation. T-2414 lesson: bats green ≠ surface preserved; the only proof is operator eyeballs on real output.

## Technical Constraints

- **Portability (Constitutional Directive 4):** no CC-specific code outside `agents/sessions/claude-code/`. `bin/fw sessions` and the renderer stay agent-neutral.
- **No CC UI hacks:** we do not modify, replace, or bypass `claude agents`. The view sits alongside.
- **Read-only:** `fw sessions` does not mutate any state.json, no `claude agents kill`, no session control. Picker is informational.
- **No terminal hijack:** v1 is print-to-stdout (no curses, no `--alternate-screen`). If interactive later, that's a separate follow-up.
- **Adapter contract is the boundary:** if no adapter exists for the detected provider, exit code 2 with a clear message + path to add one. Never silently empty.

## Scope Fence

**IN scope:**
- New verb `fw sessions` (read-only, prints grouped tree)
- Generic renderer reading canonical schema
- Claude Code adapter (`agents/sessions/claude-code/list.sh` or `.py`)
- Provider autodetect + `FW_AGENT_PROVIDER` override
- Canonical schema documented in `agents/sessions/SCHEMA.md`
- bats unit test for adapter (stub `claude` binary)
- bats integration test for renderer (canned JSONL → expected text)
- Live operator verify before close

**OUT of scope (future / separate task):**
- Interactive attach / pick (IW-1 deferred to follow-up)
- Cursor / Aider / Codex / Cline adapters (write contract; do not implement)
- Wiring into `bin/claude-fw` as a launch preamble (the original option #2 — separate task once #1 ships)
- Watchtower web page rendering the same view
- Session control verbs (`fw sessions kill`, `fw sessions attach`)

## Go/No-Go Criteria

**GO if:**
- Canonical schema locked (IW-5 disposed answered)
- All 6 Open Questions disposed (answered or dissolved)
- CC adapter spike emits canonical JSONL parseable by a generic renderer
- Renderer sample output matches operator's expected shape (live verify on this host's session set)
- Portability constraint honoured: zero CC-specific code outside `agents/sessions/claude-code/`

**NO-GO if:**
- `claude agents --json` schema turns out unstable / changes per CC version (would need an adapter version pin we don't want to maintain)
- Canonical schema cannot represent a real session class (e.g. sub-agents inside a parent session)
- Operator's expected shape after seeing the spike output no longer matches the playback (means alignment was wrong; restart from Problem Statement)
- Building the verb pulls in CC-specific knowledge into framework core (lib/, agents/context/, etc.) — portability violation, no clean adapter boundary exists

## Recommendation

**Recommendation:** GO

**Rationale:**

Operator wants a per-project grouped view of CC sessions (Needs input / Working / Completed nested under each project). T-2414 proved we can't restructure CC's native picker. Alignment confirmed on a portable shape: generic 'fw sessions' verb + agent-provider adapter layer under agents/sessions/<provider>/, CC adapter reads 'claude agents --json' and maps to canonical schema. Ship #1 (verb + CC adapter) first. Inception scope: design the canonical schema, dispose the 4 open questions (interactive vs static, sort order, age format, home/tmp bucketing), produce build plan.

**Evidence:**

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale:

Operator wants a per-project grouped view of CC sessions (Needs input / Working / Completed nested under each project). T-2414 proved we can't restructure CC's native picker. Alignment confirmed on a portable shape: generic 'fw sessions' verb + agent-provider adapter layer under agents/sessions/<provider>/, CC adapter reads 'claude agents --json' and maps to canonical schema. Ship #1 (verb + CC adapter) first. Inception scope: design the canonical schema, dispose the 4 open questions (interactive vs static, sort order, age format, home/tmp bucketing), produce build plan.

Evidence:

**Date**: 2026-06-16T08:51:26Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8995357a
- **Timestamp:** 2026-06-16T08:51:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-16T08:51:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
