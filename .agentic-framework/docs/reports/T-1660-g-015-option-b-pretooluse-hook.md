# T-1660 — G-015 Option B: PreToolUse hook to redirect /tmp/fw-agent-*.md writes through `fw bus post`

**Workflow type:** inception
**Status at filing:** captured (horizon: later)
**Companion to:** T-1645 (G-015 Option A — bus protocol convention shipped)
**Recommendation (this artifact):** DEFER, with explicit promotion criteria

## 1. Problem statement

G-015 in `concerns.yaml` was originally registered as the gap that allowed
T-073-class context explosions: nine sub-agents each returning ~15KB of
inline content blew the parent's context window. The mitigation pattern
adopted across the framework — and pinned in `agents/dispatch/preamble.md`
— is:

> Sub-agents write to `/tmp/fw-agent-{name}.md` and return ≤5 lines (path +
> one-line summary). Parent reads from disk on demand.

T-1645 narrowed G-015 from "open" to "partially mitigated" via that
convention, but explicitly noted: a convention is not a gate. A new
sub-agent prompt that forgets the rule, an updated preamble that drifts,
or a third-party plugin dispatching with raw `Write` tool — any of these
can land a >5KB inline payload in the parent's transcript with zero
structural pushback.

The question for this inception: is it worth shipping Option B (a
structural gate) now, or wait for evidence that Option A's coverage has
holes worth plugging?

## 2. Three feasibility paths

### Path (a) — FUSE overlay on `/tmp/`

A FUSE filesystem mounted at `/tmp/` would intercept every `open(2)` for a
`/tmp/fw-agent-*.md` path and:

1. Forward the write to a real file under `/tmp/.real-fw-agent/`
2. Asynchronously call `fw bus post --task $CURRENT_TASK --blob <path>`
3. Optionally rewrite the path returned to the agent so the agent's
   summary references a `bus://` URL instead of `/tmp/...`

**Pros:** language-agnostic, catches Bash-side `cat > /tmp/fw-agent-*` as
well as `Write`-tool dispatches.

**Cons:**
- Requires root or `user_allow_other` to mount; breaks portability
  (CLAUDE.md §Portability — "no provider/language/environment lock-in").
- FUSE adds a daemon — another single-point-of-failure on every dispatch.
- Cross-platform: macOS FUSE landscape (osxfuse / macFUSE) is unstable
  vs. Linux; the framework supports both.
- Effort: ≥3 days for production-grade impl (filesystem coverage,
  failure modes, daemon supervision).

**Verdict:** rejected. Cost is ~10× Path (c) for the same effective
coverage on the actual observed risk surface (Claude Code Write tool).

### Path (b) — Linux user namespace + bind-mount

Per-session unshare into a user namespace, bind-mount a tmpfs over
`/tmp/` that's writable only via a wrapper script. Wrapper script
intercepts writes matching `fw-agent-*.md`, calls `fw bus post`,
returns success.

**Pros:** no FUSE daemon; isolation per-session.

**Cons:**
- Linux-only (macOS dev boxes are out — see Portability directive).
- `unshare(CLONE_NEWUSER)` interacts badly with Claude Code's session
  setup (prior incidents on container-isolated workflows).
- Effort: ~2 days, plus the cross-platform fallback path which collapses
  back to Option (c) anyway.

**Verdict:** rejected. Effectively Option (c) on Linux + a complex
fallback on macOS.

### Path (c) — Claude Code PreToolUse hook

`.claude/settings.json` `PreToolUse` matcher on `Write` tool, calling a
shell hook that:

1. Reads the JSON payload from stdin (Claude Code hook protocol).
2. Extracts `file_path` (Write) or the command string (Bash).
3. If matches `/tmp/fw-agent-*\.md$` (or the Bash equivalent
   `> /tmp/fw-agent-*` / `tee /tmp/fw-agent-*`):
   - exit 2 with a stderr message: "Direct writes to /tmp/fw-agent-*.md
     are blocked. Use `fw bus post --task T-XXX --blob <path>` instead.
     See agents/dispatch/preamble.md."
4. Otherwise exit 0.

**Pros:**
- Single shell script, ~30 lines. Mirrors existing PreToolUse hooks
  (`check-active-task.sh`, `budget-gate.sh`, `block-task-tools.sh`,
  `check-tier0.sh`).
- Cross-platform — runs anywhere Claude Code runs.
- Zero runtime daemon, no privilege requirement.
- Failure mode is a clean refusal with a redirect, identical to the
  pattern agents already encounter from `block-task-tools.sh`.

**Cons:**
- Catches Claude Code's `Write` and `Bash` tools only — does not catch
  TermLink-spawned `claude -p` workers writing to `/tmp/fw-agent-*` from
  within their own child processes (those run outside the parent's hook
  scope). Mitigation: TermLink workers should write to `docs/reports/`
  per T-818, not `/tmp/`, so this gap is already addressed by a
  different rule.
- A determined sub-agent could shell-escape the match (`bash -c 'echo
  ... > "/tmp/fw-agent-${name}.md"'`). Mitigation: scan the rendered
  command string with the same regex, not just `argv[0]`.
- Adds a hook to the chain — every Write call costs ~5ms. Bench: at
  current dispatch volume (handful per session) that's <1s/session
  total, well under the existing PreToolUse budget.

**Verdict:** by far the cheapest. Effort: half a day to write, test, and
ship. Coverage matches the actual observed risk surface (T-073 was a
Claude Code parent dispatching sub-agents — exactly what this hook
guards).

## 3. Trade-off matrix

| Dimension                 | (a) FUSE | (b) Namespace | (c) PreToolUse hook |
|---------------------------|----------|---------------|---------------------|
| Effort to ship            | ~3 days  | ~2 days       | ~0.5 days           |
| Cross-platform            | partial  | Linux only    | yes                 |
| Catches `Write` tool      | yes      | yes           | yes                 |
| Catches `Bash` heredoc    | yes      | yes           | yes (regex)         |
| Catches TermLink workers  | yes      | yes           | no (different fix)  |
| Adds runtime daemon       | yes      | no            | no                  |
| Portability cost (D-IV)   | high     | high          | none                |
| Failure-mode legibility   | medium   | medium        | high (clean refusal)|

Given the framework's directive precedence (Antifragility > Reliability
> Usability > Portability), Path (c) wins on all four directives that
matter to G-015's observed risk surface.

## 4. Why DEFER, not GO

T-1645 (Option A) is in production. Three observations gate the
go/no-go:

1. **Observed loss incidents since T-1645 shipped (2026-05-01):** zero.
   The bus-protocol convention has held in every dispatch logged in
   `.context/audits/`.
2. **Open coverage gap:** unknown but bounded. The convention is in the
   preamble, the preamble is loaded into every dispatch, and reviews
   have not caught a sub-agent ignoring it.
3. **Cost of a Level-D structural fix vs. Level-B convention drift:**
   the half-day to ship Option B is real engineering time. Spending it
   pre-incident on a guard with zero observed bypass would violate
   "Don't add error handling, fallbacks, or validation for scenarios
   that can't happen" (CLAUDE.md, Doing Tasks §3).

## 5. Promotion criteria (when to revisit)

Revisit this DEFER and promote to GO if **either** triggers:

1. **One observed bypass incident.** Any sub-agent or third-party plugin
   write to `/tmp/fw-agent-*.md` that escapes the bus protocol and
   results in a lost result, context spike, or post-compaction silent
   data loss. One incident is enough — G-019 says don't wait for
   recurrence.
2. **Coverage gap measured ≥10%.** A spot-check of dispatch results
   (`fw bus manifest <task-id>`) finding ≥10% of dispatched sub-agents
   wrote inline content >2KB without going through the bus.

If neither fires, T-1660 stays parked. The G-015 entry in
`concerns.yaml` retains `mitigation_level: partial` until Option B
ships — that's the antifragile signal that prevents this from drifting
to "closed" without structural backing.

## 6. Decision

**Recommendation:** DEFER

This artifact records the analysis. The decision verb itself
(`fw inception decide T-1660 defer --rationale "..." --i-am-human`)
belongs to the human under §Closure-Decision-Discipline (T-1259/T-1671).

## Dialogue log

This artifact was extracted post-hoc from the task's existing
Recommendation block + dispatch protocol context (`agents/dispatch/preamble.md`,
`.context/project/concerns.yaml` G-015 entry, T-1645 episodic). No
human/agent dialogue happened during the inception itself — the
analysis was implicit in T-1645's mitigation framing. Filing this
artifact satisfies C-001 and unblocks the deferred decision. Future
re-watching of G-015 (per promotion criteria above) will append
incident evidence under a new dialogue-log entry.
