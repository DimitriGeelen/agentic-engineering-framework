# T-1104 RCA: CLAUDE.md / fw help / Code Drift — Structural Enforcement of Doc Parity

**Task:** T-1104 (META-Inception, G-035)
**Date:** 2026-04-11
**Scope:** Read-only investigation. No CLAUDE.md, bin/fw, or lib/ files modified.
**Time-boxed:** 90 minutes

---

## Executive Summary

The same class of failure hit three times on 2026-04-11, then hit THIS session with 4 identical
worker failures in parallel. Root cause: CLAUDE.md Quick Reference drifts from actual CLI surface
when code changes have no documentation AC. The drift is invisible to manual authors and survives
explicit doc-update passes because the stale form is not machine-checked.

**Census:** 1 required-flag drift across 2 surfaces (critical), 30+ missing commands.
**Drift window for the --task incident:** 14 days. Survived 2 explicit doc-update passes.
**Recommendation:** GO — fw doctor doc-drift scan + canonical-form comments in CLI functions.

---

## Phase 1 — Drift Census

### 1.1 Flag-Level Drift (Critical — causes invocation failures)

**`fw termlink dispatch` in CLAUDE.md Quick Reference (line ~1039):**
```
fw termlink dispatch --name N --prompt P [--project DIR] [--model M]
```

**Actual `cmd_dispatch()` parser in `agents/termlink/termlink.sh`:**
```bash
--task) task="$2"; shift 2 ;;     # REQUIRED — validated at line ~400
--name) name="$2"; shift 2 ;;
--prompt) prompt="$2"; shift 2 ;;
--prompt-file) prompt_file="$2"; shift 2 ;;
--project) project_dir="$2"; shift 2 ;;
--timeout) timeout="$2"; shift 2 ;;
--model) model="$2"; shift 2 ;;
```

**Enforcement (termlink.sh ~line 405):**
```bash
[ -z "$task" ] && die "Missing --task — TermLink workers require a task reference for governance (T-652, T-630)"
```

**`fw termlink help` (cmd_help in termlink.sh):**
```
dispatch  --name N --prompt P  Spawn claude -p worker in real terminal
                               [--project DIR] [--model M] [--timeout S]
```
`--task` is **also missing from the in-binary help** — two surfaces wrong, not one.

**Drift type:** Missing required flag  
**Severity:** CRITICAL — agent invocation fails immediately, error is clear but the agent shouldn't hit it  
**Drift age:** 14 days (T-652: 2026-03-28 → today: 2026-04-11)  
**Surfaces affected:** CLAUDE.md Quick Reference + `fw termlink help`

### 1.2 Missing Commands (Agents Cannot Discover These)

Commands in `fw help` output NOT present in CLAUDE.md Quick Reference:

| Command | fw help description | In QR? | Gap |
|---------|---------------------|--------|-----|
| `fw upgrade [dir]` | Sync framework improvements to consumer project | NO | G-025 |
| `fw vendor` | Copy framework into project .agentic-framework/ | NO | G-031 |
| `fw onboarding` | Onboarding gate (status\|skip\|reset) | NO | G-025 related |
| `fw consolidate` | Memory consolidation (scan, apply, report) | NO | — |
| `fw mcp` | MCP server process management (reap orphans) | NO | — |
| `fw fix-learned T-XXX "text"` | Capture bugfix learning (G-016 shortcut) | NO | — |
| `fw note [text]` | Lightweight observation capture | NO | — |
| `fw scan` | Run watchtower scan | NO | — |
| `fw serve [--port N]` | Start web UI (default port 3000) | NO | — |
| `fw upstream` | Report issues to framework upstream | NO | — |
| `fw deploy` | Ring20 deployment (scaffold, status, routes, ports) | NO | — |
| `fw update` | Update framework (vendored or global) to latest | NO | — |
| `fw hook <name>` | Run a framework hook (used by settings.json) | NO | — |
| `fw build` | Compile TypeScript sources | NO | — |
| `fw self-audit` | Standalone integrity check (Layers 1-4) | NO | — |
| `fw self-test [phase]` | Run E2E self-test | NO | — |
| `fw validate-init` | Verify fw init output is correct | NO | — |
| `fw test-onboarding` | End-to-end onboarding flow test | NO | — |
| `fw approvals` | Approval queue (pending, status, expire) | partial* | — |
| `fw decisions` | Show all decisions | NO | — |
| `fw timeline` | Show session timeline | NO | — |
| `fw learnings` | Show learnings with context | NO | — |
| `fw patterns` | Show failure/success patterns | NO | — |
| `fw practices` | Show graduated principles | NO | — |
| `fw search` / `fw search --semantic` / `fw search --hybrid` | Search across artifacts | NO | — |
| `fw recall <query>` | Query project memory | NO | — |
| `fw plugin-audit` | Audit plugins for task-system awareness | NO | — |
| `fw traceability baseline` | Set traceability baseline | NO | — |
| `fw handover --checkpoint` | Mid-session checkpoint (P-009) | NO | — |
| `fw version bump/check/sync` | Version management subcommands | NO | — |

*`fw approvals` has no QR row; only `fw tier0 approve/status` appears in QR.

**Total missing: ~30 commands / subcommand variants**

### 1.3 Phantom Commands (in CLAUDE.md but absent or changed in code)

Checked all QR rows against `fw help` and key implementation files. **No phantom commands found.**
All documented commands exist. The drift is one-directional: code/features advance, docs lag.

This confirms Assumption A-1 from T-1104.

### 1.4 Summary Statistics

| Category | Count | Severity |
|----------|-------|---------|
| Required-flag drift (in QR, wrong signature) | 1 flag / 2 surfaces | CRITICAL |
| Whole-command missing from QR | ~30 commands | HIGH (unknown unknowns) |
| Phantom commands (in QR, not in code) | 0 | — |
| In-binary help also wrong (fw termlink help) | 1 case | CRITICAL |

---

## Phase 2 — T-652 / T-630 History: Was There a Doc-Update Step?

### Timeline

| Date | Event |
|------|-------|
| 2026-03-26 | T-630 (inception): Universal task gate — close bypass paths. GO decision. |
| 2026-03-27 | T-630 GO decision recorded. Build tasks (T-650, T-651, T-652) spawned. |
| 2026-03-28 | T-652: `--task` made mandatory in `cmd_dispatch()`. Committed as `280d2888`. |
| 2026-04-08 | T-1063: `--project` flag added. termlink.sh help updated. CLAUDE.md updated in separate commit. |
| 2026-04-08 | T-1065: `--model` flag added. termlink.sh updated. CLAUDE.md updated in separate commit. |
| 2026-04-11 | THIS session: 4 workers dispatched without `--task`. All fail identically. |

### T-652 Commit Analysis

**Commit `280d2888` — files changed:**
```
.agentic-framework/agents/termlink/termlink.sh
.context/episodic/T-651.yaml
.tasks/active/T-651-*.md
.tasks/active/T-652-*.md
agents/termlink/termlink.sh
```

**CLAUDE.md: NOT IN COMMIT.**

**T-652 Acceptance Criteria (verbatim):**
1. `cmd_dispatch()` validates `--task` is provided ✓
2. Missing `--task` produces clear error message ✓
3. Vendored copy synced to `.agentic-framework/agents/termlink/` ✓
4. `bash -n` passes on modified script ✓

**Zero ACs for documentation.** No "CLAUDE.md Quick Reference updated" AC. No "fw termlink help updated" AC.

### Root Cause: Mental Model Mismatch

T-630 was framed as "close bypass paths." T-652 inherited that framing: "make --task mandatory."
The author's mental model was **enforcement change**, not **CLI surface change**.

When you add an enforcement constraint, you think: "Is the code right? Is the error message clear?
Is it vendored?" You do NOT think: "Does the agent manual say what flags are required?"

Documentation is invisible from an enforcement framing. It would be visible from a **CLI surface
change** framing, which is what T-1063 and T-1065 used ("Add --project flag", "Add --model flag").

**The same-session evidence confirms this:** T-1063 and T-1065 both remembered to update CLAUDE.md
because they were framed as "adding a feature." T-652 forgot because it was framed as "adding a guard."

### The Drift Survived Two Explicit Doc-Update Passes

T-1063 (`29dc556b`) explicitly updated the termlink.sh dispatch help text to add `--project`.
T-1065 (`86059542`) explicitly added `--model` to termlink.sh and CLAUDE.md.

In BOTH cases, the authors looked at the `dispatch` help text / Quick Reference row and manually
typed the signature — and both times omitted `--task`. Not because they forgot T-652 existed, but
because the canonical form in front of them (`--name N --prompt P [--project DIR]`) didn't show
`--task`, so they never thought to add it.

This is the key finding: **the drift self-perpetuates once it enters the canonical form.**
Authors copy the existing form and append their new flag. The stale form propagates forward.

Without a machine check, the drift is **stable under human review** — it looks correct to any
human reading it because they're reading the drift as the reference.

---

## Phase 3 — Mechanism Options

### (a) Test: Assert CLAUDE.md Table Contains Every `fw help` Command

**What it does:** Extract command names from `fw help` output. Grep for each in CLAUDE.md. Fail if missing.

**Implementation:** ~30 lines of bash. Run as `fw test unit` or in bats.

**Cost:** Low (one day to write + maintain).

**Blast radius:** Local (test failure, not blocking).

**False positive rate:** Low for command existence. **Cannot catch flag-level drift** (fw help doesn't show flag signatures).

**What it catches:** All 30 missing commands. Would NOT catch T-652 (`fw termlink dispatch` exists in QR, just wrong signature).

**Verdict:** Partially solves the problem. Addresses the 30 missing commands but not the critical flag drift.

---

### (b) Auto-Generate CLAUDE.md Quick Reference from bin/fw Introspection

**What it does:** Parse bin/fw case statements and argument parsers to extract command/flag signatures.
Regenerate the Quick Reference table on every fw change.

**Implementation:** Complex. bash has no type system — `--task` is required at runtime, not in the
parser declaration. You cannot extract "required" vs "optional" from a bash case-statement parser.
The format `--name N --prompt P [--project DIR] [--model M]` requires human annotation of which
flags are optional. Auto-gen can produce the list of flags but not the required/optional annotation.

**Cost:** High (3+ days + ongoing maintenance of parser annotations).

**Blast radius:** Medium (rewrites the Quick Reference table; human edits overwritten on next run).

**False positive rate:** N/A (would be source of truth, errors are by definition).

**What it catches:** Everything, IF annotations are maintained. If `--task` has no `required=true`
annotation, auto-gen still produces a wrong form.

**Verdict:** Addresses the structural gap but introduces a new annotation-drift problem.
Trades one maintenance burden for another. Not recommended for this problem class.

---

### (c) `fw doctor` Doc-Drift Check

**What it does:** `fw doctor` already runs every session. Add a check that:
1. Runs `fw help` and extracts command names
2. Greps CLAUDE.md for each command
3. Emits WARN for missing commands

**Cost:** Low (0.5 day — add ~40 lines to bin/fw doctor block).

**Blast radius:** Zero (read-only warning).

**False positive rate:** Medium — some commands intentionally absent from QR (internal/setup
commands like `fw hook`, `fw build`). Needs an exclude list.

**What it catches:** Missing commands. NOT flag-level drift (same limitation as (a)).

**Verdict:** Best fit for the 30-missing-commands class. Should be paired with (f).

---

### (d) CI Step — Regenerate Docs on Every fw-Touching Commit

**Context:** This framework has no CI pipeline. Commits go directly to master. This mechanism
assumes a CI environment that doesn't exist.

**Cost:** High (requires CI setup + doc generation toolchain).

**Verdict:** Out of scope for current infrastructure. Not recommended.

---

### (e) Pre-Commit Hook — Flag `bin/fw` or `agents/*.sh` Changes Without CLAUDE.md Update

**What it does:** If the commit touches `agents/termlink/termlink.sh` or `bin/fw` or `lib/*.sh`,
check whether CLAUDE.md is also in the commit. Warn or block if not.

**Cost:** Low (0.5 day — 10 lines added to commit-msg or pre-commit hook).

**Blast radius:** Low-medium (blocks commits, adds friction).

**False positive rate:** HIGH. Most code changes don't affect CLI surface:
- Bug fixes (T-972, T-843, T-792, T-798, T-795): all CODE_ONLY, correct
- Shellcheck fixes (T-795, T-798): CODE_ONLY, correct
- Config migrations (T-822): BOTH, correct
- T-652: CODE_ONLY, WRONG

Sampling the termlink.sh commit history: 10 commits, 2 BOTH (correct), 6 CODE_ONLY
(correct — bug fixes), 1 CODE_ONLY (MISSING — T-652), 1 CODE_ONLY (PARTIAL — T-1063,
where CLAUDE.md was updated but in a separate commit).

**False positive rate: ~60-70%** (most code changes correctly don't update CLAUDE.md).
A hook blocking these would create constant friction and would be disabled quickly.

**Verdict:** Too noisy. NOT recommended as the primary mechanism.

---

### (f) NEW: Canonical-Form Comments + fw doctor Scan (Proposed)

**What it does:** Add a machine-readable comment to each CLI-surface function:
```bash
# CANONICAL FORM: fw termlink dispatch --task T-XXX --name N --prompt P [--project DIR] [--model M] [--timeout S]
cmd_dispatch() {
```

`fw doctor` greps these markers and verifies they appear verbatim (or close enough) in CLAUDE.md.

**Cost:** Low (0.5 day: add ~10 canonical-form comments to existing CLI functions + 40 lines in doctor).

**Blast radius:** Very low (read-only warning in doctor).

**False positive rate:** Very low. The canonical form is a single authoritative string; CLAUDE.md
must contain it exactly. No ambiguity.

**What it catches:** Flag-level drift (the T-652 class). If T-652 had a canonical-form comment,
`fw doctor` would have flagged the mismatch on the next session.

**Verdict:** Directly addresses the T-652 class. Should be paired with (c).

---

### Combined Mechanism Matrix

| Mechanism | Command-missing | Flag-drift | Cost | FP Rate |
|-----------|----------------|------------|------|---------|
| (a) Test fw help vs QR | YES | NO | Low | Low |
| (b) Auto-generate | YES | Partial | High | Low |
| (c) fw doctor scan | YES | NO | Low | Medium |
| (d) CI regenerate | YES | Partial | High | Low |
| (e) Pre-commit hook | Indirect | Indirect | Low | HIGH |
| **(f) Canonical-form + doctor** | **YES (c)** | **YES (f)** | **Low** | **Low** |

---

## Phase 4 — Memory Propagation

### The Problem

1. Agent reads CLAUDE.md at session start → caches the form
2. CLAUDE.md has wrong form → agent caches wrong form
3. Agent uses wrong form → 4 parallel failures (THIS session)
4. **Fix CLAUDE.md → next session reads correct form** — this is sufficient for forward correction

There is no way to invalidate existing session caches (they expire with the session). The auto-memory
in `MEMORY.md` contains TermLink key commands but references the `termlink` binary primitives, not
`fw termlink dispatch`. No stale form in MEMORY.md was found.

### Memory Strategy Options

**(i) Accept stale memory + framework error catches it (status quo)**
- The error message is clear: "Missing --task — TermLink workers require a task reference for governance (T-652, T-630)"
- The agent reads the error but has already dispatched 4 workers in parallel — the damage is done
- Works eventually but wastes tool calls and context

**(ii) Auto-write "command surface changelog" memory entry on each fw version bump**
- On `fw version bump`, auto-generate a MEMORY.md entry with recent CLI surface changes
- Cost: medium; maintenance burden is low since version bumps are explicit
- Problem: MEMORY.md is per-user, lives in `~/.claude/projects/`, not in the repo — it cannot be
  updated by framework code during a commit

**(iii) Restructure: make CLAUDE.md Quick Reference the ONLY place agents look (source of truth)**
- This is the current design: CLAUDE.md IS the source of truth for agents
- The fix is: ensure CLAUDE.md is accurate (via mechanism (c)+(f)), then trust it
- Agents re-read CLAUDE.md at every session start (it's injected as system context)
- No separate memory layer needed if CLAUDE.md is correct

**Recommended memory strategy: (iii) — trust CLAUDE.md as source of truth, enforce parity mechanically.**

The agent memory (MEMORY.md) should NOT duplicate command signatures. If it does (as it did for
some entries), those become a second surface that can drift independently. The correct approach is
to reference CLAUDE.md, not copy from it.

One additional note: the `agents/dispatch/preamble.md` file instructs TermLink workers to write
output to the repo, not `/tmp`. This preamble is also a surface that could drift from actual
dispatch behavior. Adding a canonical-form comment to `preamble.md` as well would extend coverage.

---

## Phase 5 — Recommendation

### GO: Mechanism (c) + (f) — fw doctor Command-Gap Scan + Canonical-Form Comments

**Why this combination:**
- (c) catches the 30 missing commands (the "unknown unknown" class — agents can't use what they don't know exists)
- (f) catches flag-level drift (the T-652 class — the specific failure that hit THIS session)
- Together they cover both categories of drift
- Combined cost: ~1 day. No CI, no generator, no auto-rewrite.
- Blast radius: zero (warnings, not blocks)
- False positive rate: low (excluded internal commands; exact-string canonical forms)

**Why NOT (b) auto-generate:**
- Bash parsers are not declaratively typed — cannot distinguish required from optional flags
- Would produce the same stale form if `--task` has no annotation
- Trades one maintenance burden for another

**Why NOT (e) pre-commit hook:**
- 60-70% false positive rate on code changes that correctly don't update docs
- Would be disabled within a week from friction

**Why NOT (a) test alone:**
- Covers missing commands but not flag-level drift
- The T-652 class (the one that hit THIS session) would still be undetected

### Specific Implementation Targets

**For (f) Canonical-form comments — minimal viable set:**
1. `agents/termlink/termlink.sh: cmd_dispatch()` — add:
   ```bash
   # CANONICAL FORM: fw termlink dispatch --task T-XXX --name N --prompt P [--project DIR] [--model M] [--timeout S]
   ```
2. `agents/termlink/termlink.sh: cmd_help()` — the help text itself needs `--task T-XXX` added
3. `bin/fw` termlink entry in `show_help()` — currently shows just `check|spawn|exec|status|cleanup|dispatch`, which is adequate (subcommands, not flags)

**For (c) fw doctor — command-gap check:**
- Extract command list from `fw help` (machine-readable flag or parse the output)
- Check each against CLAUDE.md Quick Reference table
- Exclude list for intentionally-absent internal commands: `hook`, `build`, `self-audit`, `validate-init`, `test-onboarding`

**For CLAUDE.md update (downstream build task):**
- Fix the Quick Reference row: `fw termlink dispatch --task T-XXX --name N --prompt P [--project DIR] [--model M]`
- Add `--prompt-file FILE` as an optional variant (it's in the parser but not documented anywhere)
- Add the 30 missing commands (or a subset of the agent-relevant ones: `fw upgrade`, `fw vendor`, `fw onboarding`)

### Go/No-Go Criteria

**GO if:**
- The two mechanism sketches above are buildable within a single session (they are — both are ~40-line additions)
- The fw doctor warning surfaces before the first dispatch call each session (it does — doctor runs at session start)
- The canonical-form pattern covers at least the TermLink dispatch and any other multi-flag CLI surfaces

**NO-GO if:**
- The mechanism produces >20% false positives in doctor output (would create warning fatigue)
- Maintenance burden of canonical-form comments exceeds benefit (it doesn't — they're updated at the same time as the code)

**Recommendation: GO**

---

## Assumptions Tested Against Evidence

| # | Assumption | Test | Result |
|---|------------|------|--------|
| A-1 | Drift is one-directional: code moves forward, docs lag | Checked all QR rows vs code | CONFIRMED — 0 phantom commands, 30+ missing, 1 flag drift |
| A-2 | Single mechanism can catch all drift | Census shows two classes need two mechanisms | PARTIALLY TRUE — (c)+(f) covers both classes |
| A-3 | Auto-gen from bash parsers is feasible | Reviewed parser structure | PARTIALLY TRUE — command names yes, required/optional distinction no |
| A-4 | fw doctor is the right venue | Doctor runs every session, pre-tool-use | CONFIRMED |
| A-5 | Pre-commit hook is too noisy | Sampled 10 termlink.sh commits: 7 correct CODE_ONLY | CONFIRMED — 60-70% FP rate |
| A-6 | Agent memory cannot be structurally enforced | Memory is per-user, out of band | CONFIRMED — fix CLAUDE.md, trust it as source of truth |

---

## Evidence Appendix

**The same-day triplet (all same class, all same day):**
1. G-025 — `fw upgrade` is canonical onboarding but not in CLAUDE.md
2. G-031 evidence #4 — `fw vendor` at `bin/fw:118` ("Copy framework into project for full isolation") not in CLAUDE.md
3. THIS session — 4 TermLink workers dispatched without `--task`, all fail identically with clear error

**T-652 commit `280d2888` diff summary:**
- Files changed: `agents/termlink/termlink.sh`, `.agentic-framework/agents/termlink/termlink.sh`, 3 task files
- CLAUDE.md: NOT TOUCHED
- Enforcement message added to code: "Missing --task — TermLink workers require a task reference for governance (T-652, T-630)"
- But the in-binary `cmd_help()` was NOT updated — both CLAUDE.md and `fw termlink help` wrong

**Drift survived two explicit doc-update passes:**
- T-1063 (2026-04-08): explicitly updated `fw termlink dispatch` signature in both termlink.sh help AND CLAUDE.md — still omitted `--task`
- T-1065 (2026-04-08): explicitly updated `fw termlink dispatch` in both termlink.sh AND CLAUDE.md — still omitted `--task`
- Mechanism: authors copy the existing canonical form and append their new flag. The stale form self-perpetuates.

**Drift window:** 2026-03-28 (T-652 commit) → 2026-04-11 (THIS session) = 14 days.
