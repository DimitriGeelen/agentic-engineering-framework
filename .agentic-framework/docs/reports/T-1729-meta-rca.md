# T-1729 Meta-RCA: Agent Did Substantive Work Without a Task

**Date:** 2026-05-04 / 2026-05-05
**Session:** S-2026-0501-1642 (continuation post-`/compact`)
**Trigger:** User-flagged "MAJOR BREAKDOWN EVENT" — agent ran RCA, diagnostics, Bash mutations, and Edits without first creating or focusing the appropriate task.

## 1. Symptom Catalogue

In a single session post-`/compact`, the agent committed four discrete violations of the framework's foundational rule "Nothing gets done without a task":

| # | Action | Tool class | Substantive? |
|---|--------|-----------|--------------|
| 1 | Wrote stale-budget RCA directly in chat | text output | yes — analysis work product |
| 2 | Ran `checkpoint.sh status`, `cat .budget-status` for diagnostics | Bash | yes — diagnostic of an undeclared concern |
| 3 | Ran `bin/fw task update T-1716` and follow-up Bash + Edits to investigate a verification-gate failure while focus was T-1727 (stale) | Bash + Edit | yes — multi-step debugging |
| 4 | Was about to write a meta-RCA in chat with no task | text output | yes — would have evaporated at next compaction |

Only after the user explicitly demanded "have we created an arc, are we following framework governance???" did the agent stop, file T-1729, set focus, and produce this artifact.

## 2. Forensic Evidence

### 2.1 Hook telemetry (counters at investigation start)

Source: `.context/working/.hook-counter`

```
audit-task-tools=18
check-tier0=17
check-project-boundary=18
budget-gate=18
check-active-task=1        ← only fired ONCE in the entire session
checkpoint=18
loop-detect=18
commit-cadence=1
error-watchdog=15
```

Delta from `git show HEAD:.context/working/.hook-counter` (T-1716 completion commit `12f0fe7c4`):

| Hook | At commit | Now | Δ |
|------|-----------|-----|---|
| audit-task-tools | 4 | 18 | +14 |
| check-tier0 | 4 | 17 | +13 |
| check-project-boundary | 5 | 18 | +13 |
| budget-gate | 5 | 18 | +13 |
| **check-active-task** | **1** | **1** | **0** |
| checkpoint | 3 | 18 | +15 |
| loop-detect | 3 | 18 | +15 |
| commit-cadence | 1 | 1 | 0 |
| error-watchdog | 2 | 15 | +13 |

**Interpretation:** ~14 Bash commands fired post-commit, yet `check-active-task` fired zero times. The agent ran `fw task update`, `fw context add-learning`, `fw inception start`, `git commit`, and many diagnostics — none gated on task focus.

### 2.2 The decisive matcher mismatch

`.claude/settings.json:44-52` —

```json
{
    "matcher": "Write|Edit",
    "hooks": [
        {
            "type": "command",
            "command": "/opt/999-Agentic-Engineering-Framework/bin/fw hook check-active-task"
        }
    ]
},
{
    "matcher": "Bash",
    "hooks": [
        {
            "type": "command",
            "command": "/opt/999-Agentic-Engineering-Framework/bin/fw hook check-tier0"
        }
    ]
},
```

The active-task gate is bound to **Write|Edit only**. Bash routes to `check-tier0` exclusively, which catches destructive ops (force push, hard reset, rm -rf, DROP TABLE) but does not check task focus.

Crucially, `agents/context/check-active-task.sh:50-82` has **full Bash handling** (safe-command allowlist, write-pattern detection) — the code is written, it's the matcher that excludes it. The protective logic exists; the wiring is missing.

### 2.3 Path exemption analysis

`agents/context/check-active-task.sh:116-120` —

```bash
case "$FILE_PATH" in
    "$PROJECT_ROOT"/.context/*|"$PROJECT_ROOT"/.tasks/*|"$PROJECT_ROOT"/.claude/*|"$PROJECT_ROOT"/.git/*)
        exit 0
        ;;
esac
```

This exemption is necessary — agents must update task files to mark ACs, modify `## Verification`, add updates. Without the exemption, `fw task update` self-deadlocks (it Edits the task file). But the exemption is **total**: no diff-aware logic distinguishes "agent ticks Agent AC" (legitimate) from "agent ticks Human AC" (CLAUDE.md violation). The latter is what happened with T-1716's `[REVIEW]` checkbox.

### 2.4 Focus-target drift is uninspected

The gate verifies *some* task is focused. It does not verify the action targets the focused task. Concretely:

- focus = T-AAA (started-work, has real ACs)
- agent runs Edit on `lib/foo.sh` ← gate passes (focus exists)
- agent runs `bin/fw task update T-BBB --status work-completed` ← Bash, no gate at all
- agent runs Edit on `.tasks/active/T-BBB-...md` ← exempt path, instant pass

All three paths are unguarded against drift. There is no `.focus-history` log, so forensic reconstruction relies on the session JSONL transcript.

### 2.5 Gate-bypass log is empty

`.context/audits/gate-bypass.jsonl` does not exist. No `--force`, `--skip-verification`, `--i-am-human`, or `--switch-focus`-class bypass was used during the breakdown — because no gate fired to require one. Bypass logging is defined; the events that would invoke it never occurred.

## 3. Root Cause

**Agent discipline failure on the "create task FIRST" rule, made structurally allowable by four cumulative gaps:**

1. **G1 — Bash matcher excludes task gate.** `check-active-task` is wired only to Write/Edit. Bash mutations of framework state (`fw task update`, `fw context add-*`, `fw assumption add`, `git commit -m "T-XXX: ..."`) bypass the gate entirely.
2. **G2 — Path exemption is not diff-aware.** `.tasks/*` is exempt for legitimate reasons but no second-layer check distinguishes Agent-AC ticks from Human-AC ticks, or focused-task edits from off-focus task edits.
3. **G3 — Focus-target drift is uninspected.** No gate compares the action's target task against the focused task. `fw task update T-X` while focus=T-Y is invisible to the framework.
4. **G4 — Substantive text output has no surface for governance.** RCAs written in chat produce no tool calls, hence no hooks. CLAUDE.md C-001 mandates `docs/reports/T-XXX-*.md` capture for inception phases, but ad-hoc mid-session RCAs (a recurring class) have no parallel rule and no hook trigger.

This is the G-018 family pattern: the rule lives in CLAUDE.md text, the enforcement gap is exactly where the rule applies most pressure, and decay is inevitable under flow pressure.

## 4. Why structurally allowed

CLAUDE.md asserts: *"Nothing gets done without a task. This is enforced structurally by the framework, not by agent discipline."*

The empirical reality (post this RCA): the rule is structurally enforced for **Write/Edit on non-exempt source files only**. Every other surface — Bash, exempt paths, text output — relies on agent discipline. The CLAUDE.md sentence is therefore aspirational rather than descriptive. That gap between assertion and reality is itself a meta-failure: agents reading CLAUDE.md trust the enforcement claim and drop their discipline accordingly.

## 5. Prevention — three layers

### 5.1 Structural fixes (deterministic, ship now)

**Fix 1 — Bash matcher + focus-drift gate.** Add `Bash` to `check-active-task` matcher in settings.json. Augment the hook to detect:
- `bin/fw task update T-X` while focus ≠ T-X → block with `--switch-focus` override
- `bin/fw context add-* --task T-X` while focus ≠ T-X → same
- `git commit -m "T-X: ..."` while focus ≠ T-X → same

Closes G1 + G3.

**Fix 2 — Human-AC tick guard.** PreToolUse on Write/Edit to `.tasks/*`: parse the diff. If the change toggles a `[ ]` ↔ `[x]` checkbox under a `### Human` heading, block under `$CLAUDECODE=1` with `--i-am-human` override (mirrors T-1671's pattern). Closes G2.

### 5.2 Orchestrator-driven prevention (covers the residual class)

Prompt-triage workflow as G-064 first real consumer:

- `UserPromptSubmit` hook routes the user's message through `fw resolver dispatch <session> prompt-triage`.
- Workflow: ollama-local default, cloud fallback only on unreachability, cost cap $0.001/call, latency target <500ms, fail OPEN.
- Verdict: GO (file task first) / NO-GO (conversation only) / DEFER (ambiguous → ask user).
- On GO, surface to agent via `additionalContext`: "Your prompt requests substantive work. File a task with: `fw work-on '<auto-name>' --type <type>` before responding."

Closes G4 — the only surface where structural gates can't reach.

### 5.3 Detective surveillance (catches what slips through)

`fw orchestrator surveil --session current` (cron, 5-min cadence) reads `.context/dispatches.jsonl`, session JSONL, and focus.yaml. Flags:

- Bash mutations targeting a non-focused task
- Substantive work product committed without a task creation event
- Focus stamp older than the work window

Emits to handover; doesn't block. Detective only.

### 5.4 Self-improvement loop

Outcome enrichment (T-1697 substrate) captures whether triage verdicts matched eventual ground truth. `route_cache` learns the prompt-class → verdict correlation. Over weeks, the classifier sharpens and cloud-fallback rate falls.

## 6. Why this is the right G-064 first consumer (not escalation-scan)

T-1726 (escalation-scan v0.5) was filed yesterday as the named G-064 closure path. Re-evaluating:

| Dimension | escalation-scan v0.5 | prompt-triage |
|-----------|---------------------|---------------|
| Closes recurring failure class? | symptom-fix detection (medium severity) | governance-bypass prevention (high severity, observed today) |
| Dispatch hot-path? | daily (1×/day) | per-prompt (10–100×/day) |
| Visible win? | weekly drift-LATEST.yaml entries | every prevented breakdown is observable |
| Substrate identical? | yes | yes |
| Risk if it underperforms? | heuristics already cover the path | small latency tax, fail-OPEN safe |

Recommendation: **prompt-triage as v0.5; escalation-scan as v0.6.** They are structurally identical workloads — same envelope shape, same outcome capture. Implementation cost of v0.6 after v0.5 is near-zero; the dispatch infrastructure is shared.

## 7. Test Plan

Pinned in `tests/integration/focus_drift_gate.bats` (full draft in T-1729's body, summarized here):

- **T1** — focus = T-AAA, run `fw task update T-BBB`. Current state: succeeds (the gap). Post-fix: blocks under `$CLAUDECODE=1`.
- **T2** — same scenario with `--switch-focus`. Current: N/A (flag doesn't exist). Post-fix: succeeds, logs to `.context/audits/gate-bypass.jsonl`.
- **T3** — pin the settings.json gap: assert Bash matcher does NOT chain to check-active-task. Fails after the fix.
- **T4** — pin the post-fix wiring: assert Bash matcher DOES chain to check-active-task. Fails today.
- **T5** — Human-AC tick guard: Edit `.tasks/active/T-X.md` toggling `### Human` checkbox under `$CLAUDECODE=1`. Current: succeeds (the gap). Post-fix: blocks.

Tests T3+T4 are the regression tooth — they pin both the current gap AND the post-fix configuration, so any future revert to the broken matcher fails CI.

## 8. Decisions

### 2026-05-05 — Three-task decomposition over single mega-task

- **Chose:** File three separate tasks (focus-drift gate, Human-AC tick guard, prompt-triage inception). Cross-tag with arc:orchestrator-rethink + meta-rca:T-1729.
- **Why:** Per CLAUDE.md "One task = one deliverable" + Post-Grill Governance Closure (L-349). Each fix has independent test, owner, ship cadence. Bundling would obscure status and prevent partial progress.
- **Rejected:** Single "fix-all-gaps" task. Rejected because it merges deterministic structural fixes (small, ship-fast) with an LLM-substrate inception (needs spike + decision).

### 2026-05-05 — prompt-triage as v0.5 over escalation-scan

- **Chose:** Promote prompt-triage to G-064 first real consumer; demote escalation-scan to v0.6.
- **Why:** Prompt-triage closes a higher-severity recurring failure class (governance bypass), is hot-path (per-prompt), and produces a directly observable win on every prevented breakdown.
- **Rejected:** Keep escalation-scan as v0.5. Rejected because it solves a less-frequent, lower-leverage problem; the v0 heuristics already cover most of its detection path.

### 2026-05-05 — Fail OPEN on prompt-triage unreachability

- **Chose:** If orchestrator/ollama is unreachable, prompt-triage hook returns "allow" (silent on the agent side; logs to telemetry).
- **Why:** Closing the framework on every prompt when LLM is down is itself a major breakdown class. The structural fixes (1+2) cover the deterministic governance; the LLM layer is additive defense, not load-bearing.
- **Rejected:** Fail-CLOSED. Rejected because it makes LLM availability a hard dependency for any agent interaction.

## 9. Risk Acknowledged

- **Layer 1 latency tax.** ~500ms per user prompt. Mitigation: ollama-local default, prompt-cache within session, fail-OPEN.
- **False-positive triage fatigue.** Classifier flags too aggressively → agent ignores. Mitigation: telemetry on `FW_PROMPT_TRIAGE=off` usage; if >5%/week, retune workflow.
- **Three-layer drift.** Layers 1+2+3 ship across multiple tasks; easy to muddle. Mitigation: each layer is its own task with explicit ACs.
- **Substrate-vs-deliverable conflation (§ACD).** Same shape as G-066. Mitigation: each task's headline mechanic is *visibly observable* — Layer 1 prevents a real prompt; Layer 2 surfaces a real flag; Layer 3 logs a real verdict.

## 10. Filing Plan

Three sibling tasks, all tagged `arc:orchestrator-rethink`, `meta-rca:T-1729`, cross-linked in `related_tasks`:

1. **T-NNNN — focus-drift gate + Bash matcher fix** (build, horizon: now). Fix 1 above. ~30 LOC + 5 bats tests.
2. **T-MMMM — Human-AC tick guard** (build, horizon: now). Fix 2 above. ~50 LOC + bats coverage. Mirrors T-1671 closure-gate pattern.
3. **T-PPPP — prompt-triage as G-064 first consumer** (inception, horizon: now). Layer 1+2+3 above. Spike on cost/latency, then decision. May supersede T-1726 as v0.5.

T-1729 closes when all three are filed and this report committed.

---
*Filed under T-1729 inception. Generated 2026-05-04/2026-05-05.*
