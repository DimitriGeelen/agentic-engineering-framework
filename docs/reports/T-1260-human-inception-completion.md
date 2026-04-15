# T-1260 — Human-owned inception tasks cannot complete: 5-layer RCA

**Status:** Captured 2026-04-14 from cross-session report. Investigated 2026-04-15. Five distinct failure surfaces identified across two existing tasks (T-002, T-006). Workaround validated.

---

## Symptoms

For inception tasks with `owner: human`, no available pathway completes them. T-002 has 3+ duplicated `## Decision` blocks from repeated Watchtower clicks; status stays `started-work`.

| Path tried | Result |
|-----------|--------|
| `fw inception decide T-002 go` (CLI, agent-run) | Tier 0 block (recommendation gate or T-1259 CLAUDECODE guard) |
| `fw tier0 approve` + retry | Retry hits Tier 0 again — hash drift |
| Watchtower `/inception/T-XXX` → click GO | Decision block written. Status does NOT transition. Error: "Task Update ... F" (truncated) |
| `fw task update T-XXX --status work-completed` (agent) | Sovereignty gate R-033 blocks |
| `fw task review T-XXX` | Dispatch script missing: `/tmp/tl-dispatch/fabric-purpose-fill/run.sh` |

Contrast: T-006 transitioned cleanly because the human ran `fw inception decide` directly from their own terminal (no agent identity, no Watchtower).

## Spike A — Sovereignty gate asymmetry (Watchtower vs CLI)

**Trace:**
1. Human clicks GO in Watchtower
2. POST `/inception/T-XXX/decide` (`web/blueprints/inception.py:393-437`)
3. Creates review marker `.context/working/.reviewed-T-XXX` (line 405-410) — bypasses T-973 review gate
4. Calls `run_fw_command(["inception", "decide", task_id, decision, "--rationale", rationale])` (line 411)
5. `web/subprocess_utils.py:51` passes `{**os.environ, ...}` — **inherits parent process env**
6. Subprocess runs `lib/inception.sh do_inception_decide`
7. **NEW (T-1259):** line 204 checks `${CLAUDECODE:-} = "1"` → blocks if true
8. After decide writes the Decision block, calls `update-task.sh --status work-completed --skip-sovereignty` (line 346) — R-033 IS bypassed
9. **But:** `--skip-sovereignty` does NOT bypass P-010 (AC gate) or P-011 (verification gate) per inception.sh:336 comment

**Findings:**

**Finding A1 (CRITICAL regression):** When Watchtower's Flask process is started inside a Claude Code session (`fw serve` from claude session), `CLAUDECODE=1` is inherited. Every Watchtower-driven `fw inception decide` call now hits the T-1259 guard and is blocked. **The T-1259 guard needs a Watchtower exemption.** Confirmed via `echo $CLAUDECODE` returning `1` in the current shell.

**Finding A2:** R-033 (sovereignty gate) is correctly bypassed in the work-completed transition via `--skip-sovereignty`. NOT the cause of the failure.

**Finding A3:** P-010 (AC gate) and P-011 (verification gate) are intentionally NOT bypassed (per T-1101/T-1142). If the inception task has unchecked Agent ACs, the work-completed transition fails. **For T-002 specifically, this is the likely cause** of "Status does NOT transition" — the decide writes the decision block, then update-task.sh blocks on AC gate.

**Fix sketch:**
- **A1:** Add Watchtower exemption to T-1259 guard. Either:
  - (a) `inception.py` adds `--from-watchtower` flag → inception.sh treats as bypass
  - (b) `inception.py` sets `WATCHTOWER_REQUEST=1` env var → inception.sh checks both
  - **Prefer (a)** — explicit flag, visible in process tree, no env-leak risk
- **A3:** Inception decide should auto-check Agent ACs that are clearly satisfied by the decide itself (no orphan ACs blocking completion). Or: the Watchtower flow should warn "Decision recorded, but X agent ACs unchecked — task remains active" instead of looking like a failure.

## Spike B — Dispatch script materialization (`/tmp/tl-dispatch/fabric-purpose-fill/run.sh`)

**Findings:**
- `/tmp/tl-dispatch/` is the worker directory created by `agents/termlink/termlink.sh` (line 30: `DISPATCH_DIR="/tmp/tl-dispatch"`). Workers are written by `fw termlink dispatch` and the bare `tl-dispatch.sh` (T-143).
- The name `fabric-purpose-fill` does **not appear anywhere** in the codebase except T-1260 itself. Search:
  ```
  grep -r "fabric-purpose-fill" /opt/999-Agentic-Engineering-Framework
  → only .tasks/active/T-1260-...md
  ```
- Conclusion: this is a **stale reference from a one-off worker** that ran in a previous session, was cleaned up, and something kept a path reference (likely a watchdog, status check, or attached terminal trying to re-run).
- This is class L-006 again (worker registry vs filesystem disagreement), but at low impact: the failure surface is `fw task review` → "Dispatch script missing" — recoverable by re-running with a fresh worker name.

**Fix sketch:**
- `fw task review` should not depend on a specific named worker. If it does (for some background fabric task), the missing-script error should fail-soft with a clear "this is recoverable, run X" message.
- `fw termlink cleanup` should also clean stale references in any caller's metadata, not just `/tmp/tl-dispatch/`.

## Spike C — Template completeness

Audited `.tasks/templates/inception.md` — has `## Decision`, `## Recommendation`, `## Updates` sections. **Current template is complete.**

Older inception tasks created before these sections were added may be missing them. T-002 and T-006 (the cited failure cases) may be from this older era. Spot check confirmed T-1261 (just created) has all three. Migration script needed for older tasks: scan `.tasks/active/` for inception tasks missing `## Recommendation` or `## Decision`, append empty stubs.

**Fix sketch:** One-shot `fw inception backfill-sections` command that adds missing sections to existing inception tasks (idempotent — only adds if heading absent).

## Spike D — Recommendation gate ordering

Confirmed flow in `lib/inception.sh do_inception_decide`:
1. CLAUDECODE guard (line 204) — NEW T-1259
2. Find task file (line 219)
3. Workflow-type check (line 228)
4. Placeholder audit (line 237)
5. Review marker check (line 245) — T-973
6. **## Recommendation gate** (line 256-277)
7. Write decision block (line 285)
8. Append Updates entry (line 325)
9. Transition started-work then work-completed (line 343-346)
10. Cleanup review marker (line 350)

**Order is correct.** The Recommendation gate fires BEFORE writing the decision. If Watchtower clicks GO without a Recommendation present, decide refuses cleanly without leaving a half-written state.

The T-002 case (3+ duplicate Decision blocks) suggests the gate was **passing** repeatedly — Recommendation was present — but the work-completed transition failed each time, leaving the Decision block written but the lifecycle stuck. Then the human clicked again, decide ran again, wrote ANOTHER Decision block. Each click compounds.

**Fix sketch:** Decision block writer (line 295-318 in inception.sh) should be **idempotent** — if a `## Decision` block with the same decision already exists, skip the write (or replace, not append). Currently it appends because the section heading is the only marker.

## Spike E — Tier 0 hash drift

Read `agents/context/check-tier0.sh:167`:
```bash
COMMAND_HASH=$(echo -n "$COMMAND" | sha256sum | awk '{print $1}')
```

The hash is on the **exact command string** read from Claude Code's tool input. Two invocations of "the same" command produce different hashes if:
1. Whitespace differences (extra space, tab vs space, trailing newline)
2. Quote escaping differences (`"foo"` vs `'foo'` vs `\"foo\"`)
3. Variable expansion happening at one call but not the other (e.g., `$HOME` vs `/root`)
4. Different argument order or extra flags appended
5. **Most likely:** tool-call serialization re-renders the command differently on retry

**Reproduction:** Run `bin/fw inception decide T-002 go --rationale "test"` once → block, write hash H1. Run literal same string → hash H1 matches → approval consumed. But if the agent re-renders with `--rationale 'test'` (single quotes), hash changes → mismatch → fresh block.

**Fix sketch:** Normalize the command string before hashing:
- Collapse whitespace (`re.sub(r'\s+', ' ', cmd).strip()`)
- Convert all single-quoted strings to double-quoted equivalents
- Sort flag arguments alphabetically (or normalize position)

Trade-off: stricter normalization risks **collision** (two genuinely-different commands hashing the same). Conservative approach: only collapse whitespace; document quote-sensitivity.

## Spike F — Workaround validation

T-006 transitioned cleanly via direct human terminal:
```
$ bin/fw inception decide T-006 go --rationale "..."
```
This works because:
1. Human's terminal has no `CLAUDECODE` env var → T-1259 guard does not fire
2. No Watchtower involvement → no Flask subprocess inheritance
3. Direct bash invocation → exact command string preserved → Tier 0 hash stable
4. Human IS the human → R-033 logic doesn't even apply (sovereignty gate is about agent attempts to complete human-owned tasks)

**Workaround documented.** Until the structural fixes ship, the human-only path is:
```bash
cd /path/to/project && [bin/fw OR .agentic-framework/bin/fw] inception decide T-XXX go --rationale "..."
```

Note the project-aware fw path per T-1257. Single line, copy-pasteable.

## Build decomposition (post-GO)

| Task | Scope | LOC | Risk | Priority |
|---|---|---|---|---|
| **B1** | `web/blueprints/inception.py:411` — pass `--from-watchtower` flag to `fw inception decide` | +5 | Low | P0 (regression) |
| **B2** | `lib/inception.sh:184-194` — parse `--from-watchtower` flag, exempt from CLAUDECODE guard at line 204 | +10 | Low | P0 |
| **B3** | `tests/unit/lib_inception.bats` — assert: CLAUDECODE=1 + --from-watchtower → passes guard | +15 | Low | P0 |
| **B4** | `lib/inception.sh:295-318` — make Decision block writer idempotent (replace existing block, don't append) | +20 | Medium | P1 (T-002 cleanup) |
| **B5** | `lib/inception.sh:343-346` — when work-completed transition fails (e.g., AC gate), surface clear error to caller (not "Task Update ... F" truncation). Watchtower should display the underlying P-010 message. | +15 | Medium | P1 |
| **B6** | `agents/context/check-tier0.sh:167` — normalize command before hashing (collapse whitespace, document caveats) | +10 | Medium | P2 (hash drift fix) |
| **B7** | `bin/fw` add `inception backfill-sections` command — scan inception tasks, append missing `## Decision`/`## Recommendation`/`## Updates` sections | +50 | Low | P2 |
| **B8** | `fw task review` failure path for missing dispatch worker — fail-soft with recovery instructions, not opaque "Dispatch script missing" | +20 | Low | P3 |
| **B9** | One-shot cleanup of T-002 — remove duplicate Decision blocks, keep latest, run work-completed via human terminal (workaround) | n/a | Low | P0 |

**Total LOC:** ~145 added. **Time estimate:** ~2-3 hours for B1-B5 (P0+P1, the regression + clean-up); B6-B9 in follow-up.

## Recommendation

**Recommendation:** GO

**Rationale:** Five distinct failure surfaces identified, each with a bounded, testable fix. Most critical (B1-B3) is a regression from my own T-1259 commit — the CLAUDECODE guard does not exempt Watchtower-originated calls, breaking the canonical human-decision surface. P0 fixes restore the broken path within ~30 LOC; P1 fixes prevent recurrence of stuck-state compounding (T-002's 3+ duplicate Decision blocks). The workaround (human's own terminal) is validated and can unblock urgent inceptions immediately.

**Evidence:**
- `web/subprocess_utils.py:51` confirmed: `env={**os.environ, ...}` inherits CLAUDECODE
- `echo $CLAUDECODE` in current session returns `1` — every subprocess inherits this
- `lib/inception.sh:204` blocks on CLAUDECODE=1 unless `--i-am-human`
- `web/blueprints/inception.py:411` does not pass any human-identity flag
- `lib/inception.sh:336` confirms `--skip-sovereignty` does NOT bypass AC/verification gates
- `lib/inception.sh:295-318` Decision block writer is non-idempotent (appends a new block on every call)
- `agents/context/check-tier0.sh:167` hash is on raw command — whitespace/quote sensitive
- `.tasks/templates/inception.md` confirmed has all three required sections
- `grep -r fabric-purpose-fill` finds zero non-task references — stale worker reference, not a code issue

**Critical interim warning:**
> Until B1-B2 ship: Watchtower's GO/NO-GO buttons are likely **broken** for any session where Watchtower was started inside a Claude Code shell. Use the human's own terminal:
> ```bash
> cd /path/to/project && [bin/fw|.agentic-framework/bin/fw] inception decide T-XXX go --rationale "..."
> ```

## Scope fence

**IN:**
- RCA all 5+ failure surfaces
- Workaround validation
- Build decomposition with priority tags

**OUT:**
- Watchtower auth/identity overhaul (flask-login adoption — separate inception)
- Tier 0 redesign (R-033 in scope per T-1260; broader Tier 0 out)
- Rewriting inception workflow end-to-end

## Dialogue log

### 2026-04-15 — Spikes executed in single read-batch

All 6 spikes resolved from local file reads (no TermLink dispatch). Critical finding emerged in Spike A: the T-1259 guard committed earlier this week (commit 4589bc60) regresses Watchtower decide because Flask inherits `CLAUDECODE=1` from its parent shell. This was not anticipated when T-1259 landed — the guard correctly blocks agent-direct invocation but didn't model the Watchtower-as-human-surface case. Build task B1+B2 fix it explicitly via a `--from-watchtower` flag (option (a) from Spike A fix-sketch — preferred over env var because it's visible in process tree and avoids env-leak risk).
