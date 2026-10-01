# T-3670 — Context pack for the core-module language review

**Task:** T-3670 (inception). **Date:** 2026-10-01. **Audience:** seven independent reviewers, four of whom have no repository access and see only this document.

**The question.** The framework's established, security-critical core is written mostly in bash, with Python inside it. Should it move to a typed, strict language, and if so how? The current lean is Go, using `mvdan.cc/sh` (the parser behind `shfmt`) to parse bash. We want an architectural assessment and rewrite advice.

**How to read this pack.** Every number here was measured by a command on 2026-10-01 against branch `bleeding-edge`. Each measurement says how it was taken. Where this pack summarises a document, it names the document. Statements we infer are labelled as inference. Section 8 lists the open questions we want answered.

**Host used for the measurements.** Linux 6.8, x86_64, a 12-core desktop CPU (24 threads), GNU bash 5.2.21, Python 3.12.3. The latency figures come from a fast machine. Slower laptops, macOS and WSL will be slower; none of those were measured.

---

## 1. What AEF is

The **Agentic Engineering Framework** (AEF) is a governance framework for AI coding agents working in a software repository. It is not an application library. It is a set of rules, file formats and **structural enforcement mechanisms**, meaning hooks that block a tool call, so that rules are enforced by the system rather than left to agent discipline. The main integration is Claude Code. `FRAMEWORK.md` is a provider-neutral guide for any CLI-capable agent, and `CLAUDE.md` adds the Claude Code specifics.

**Core principle:** *"Nothing gets done without a task."* An agent cannot write a file, or run a command that is not on a read-only allowlist, unless a task exists and is the current *focus*.

**Four constitutional directives, in priority order.** Every architectural decision must trace back to them.
1. **Antifragility.** The system gets stronger under stress, and failures are learning events. Each failure is recorded as a *learning* (`L-NNN`) or a *concern/gap* (`G-NNN`), and often becomes a new gate or test.
2. **Reliability.** Execution is predictable, observable and auditable. There are no silent failures.
3. **Usability.** The framework is a joy to use, extend and debug. Defaults are sensible and errors are actionable.
4. **Portability.** There is no lock-in to a provider, language or environment, and standards are preferred (MCP, LSP, OpenAPI).

**Authority model.**
```
Human     → SOVEREIGNTY → can override anything; is accountable
Framework → AUTHORITY   → enforces rules, checks gates, logs everything
Agent     → INITIATIVE  → can propose, request, suggest — never decides
```

**Main concepts.**
- **Tasks.** Markdown files with YAML frontmatter in `.tasks/active/` and `.tasks/completed/`. Each has a lifecycle (`captured → started-work ↔ issues → work-completed`), a workflow type (build, refactor, test, inception, …), `### Agent` and `### Human` acceptance criteria (ACs), and a `## Verification` block of shell commands that must all pass before the task can close.
- **Focus.** `.context/working/focus.yaml` names the current task. The write gate checks it.
- **Hooks.** Claude Code runs scripts before and after each tool call (PreToolUse and PostToolUse). Under Claude Code's protocol a PreToolUse hook that exits **2** blocks the tool call and its stderr is shown to the agent. Exit **0** allows the call. **Any other exit code is a "non-blocking error" and the tool call proceeds**, which is Claude Code's documented behaviour. A crashing hook therefore fails *open* unless it has been written to exit 2.
- **Gates.** These are predicates that refuse an action. Examples: the task/focus gate, the Tier 0 gate for destructive commands, the context-budget gate, and the close gates in `update-task.sh` (all ACs ticked, verification commands pass, an RCA exists for bug-fixes, and others).
- **Enforcement tiers.** Tier 0 covers consequential actions (force push, hard reset, `rm -rf`, `DROP TABLE`) and needs explicit human approval. Tier 1 is the default: it needs an active task. Tier 2 is a logged, single-use human authorisation. Tier 3 covers pre-approved read-only categories.
- **Context memory.** Working, project and episodic memory are YAML files under `.context/`. Handovers are written between sessions.
- **Reviewer and verdict ledger.** An independent reviewer agent can close certain Human ACs by recording a signed, append-only *verdict*. The ledger is validated against git history.
- **Watchtower.** A Flask web UI (`web/`) for review, approvals and dashboards.
- **`fw`.** A single CLI entry point (`bin/fw`, 10,901 lines of bash). It routes to "agents", which are scripts in `agents/<name>/`, and to libraries in `lib/`. Every hook is invoked as `bin/fw hook <name>`.

**Self-hosting.** The framework is developed under its own governance. In this repository, task ids run past T-3670, and there are 725 recorded learnings. The core gates have been hardened incrementally, mostly in reaction to incidents and external reviews.

---

## 2. Inventory (measured)

**How measured:** `find <dir> -type f -name '*.<ext>' | xargs cat | wc -l`. `__pycache__` and `node_modules` are excluded. Bash files without an extension were found by shebang (`#!…sh`) and exist only in `bin/`.

### 2.1 Lines and files per language

| Dir | Bash (.sh) | Bash (no ext.) | Python | JS | HTML (Jinja) | YAML |
|---|---|---|---|---|---|---|
| `bin/` | 4 files / 989 | 5 files / 12,283 | 0 | 0 | 0 | 0 |
| `lib/` | 105 / 32,842 | 0 | 107 / 36,217 | 2 / 2,995 | 0 | 3 / 426 |
| `agents/` | 115 / 39,087 | 0 | 31 / 14,072 | 0 | 0 | 0 |
| `web/` | 0 | 0 | 78 / 26,007 | 17 / 3,261 | 85 / 17,949 | 1 / 60 |
| **Total** | **229 files / 85,201 lines** | | **216 / 76,296** | **19 / 6,256** | **85 / 17,949** | **4 / 486** |

The extension-less bash files are `bin/fw` (10,901 lines), `bin/claude-fw` (980), `bin/fw-router` (260), `bin/claude-fw-router` (72) and `bin/fw-shim` (70).

**Bash files that are partly Python.** Many bash files embed Python as `python3 -c "…"` strings or `python3 - <<'EOF'` heredocs, so the language split above understates the mixing. For example:

| File | Lines | `python3 -c` sites | Python heredoc sites | Shell functions |
|---|---:|---:|---:|---:|
| `bin/fw` | 10,901 | 60 | 21 | 46 (plus about 103 top-level subcommand `case` arms) |
| `agents/context/check-tier0.sh` | 936 | 13 | 0 | 3 |
| `agents/context/check-active-task.sh` | 1,261 | 7 | 0 | 6 |
| `agents/context/budget-gate.sh` | 528 | 5 | 0 | 3 |
| `agents/context/checkpoint.sh` | 682 | 3 | 1 | 8 |
| `agents/task-create/update-task.sh` | 2,743 | 6 | 7 | 19 |
| `agents/git/lib/hooks.sh` | 1,579 | 2 | 0 | 10 |

(Counts come from `grep -c` on each pattern, so they are approximate.)

### 2.2 The 25 largest bash files

| # | Lines | File |
|---:|---:|---|
| 1 | 10,901 | `bin/fw` |
| 2 | 8,494 | `agents/audit/audit.sh` |
| 3 | 2,787 | `lib/upgrade.sh` |
| 4 | 2,743 | `agents/task-create/update-task.sh` |
| 5 | 2,424 | `lib/arc.sh` |
| 6 | 2,394 | `lib/bvp.sh` |
| 7 | 1,742 | `agents/termlink/termlink.sh` |
| 8 | 1,641 | `agents/handover/handover.sh` |
| 9 | 1,579 | `agents/git/lib/hooks.sh` |
| 10 | 1,488 | `agents/context/lib/safe-commands.sh` |
| 11 | 1,419 | `lib/init.sh` |
| 12 | 1,261 | `agents/context/check-active-task.sh` |
| 13 | 1,101 | `lib/inception.sh` |
| 14 | 1,032 | `lib/worktree.sh` |
| 15 | 980 | `bin/claude-fw` |
| 16 | 936 | `agents/context/check-tier0.sh` |
| 17 | 902 | `lib/pickup.sh` |
| 18 | 711 | `lib/review.sh` |
| 19 | 682 | `agents/context/checkpoint.sh` |
| 20 | 674 | `lib/continuous-mode.sh` |
| 21 | 656 | `lib/validate-init.sh` |
| 22 | 640 | `lib/branch-hygiene.sh` |
| 23 | 627 | `agents/task-create/create-task.sh` |
| 24 | 624 | `agents/context/check-project-boundary.sh` |
| 25 | 622 | `agents/metrics/api-usage.sh` |

### 2.3 Test suites (the behavioural contract)

**How measured:** test files are counted under `tests/`. Tests are counted by `^@test` lines (bats) and `def test_` lines (pytest).

| Suite | Files | Test cases |
|---|---:|---:|
| bats (`*.bats`) | 840 (718 of them in `tests/unit/`) | 7,049 |
| pytest (`test_*.py`) | 449 (251 of them in `tests/unit/`) | 4,351 |
| **Total** | **1,289** | **11,400** |

Many bats tests exercise the bash scripts as black boxes: they feed JSON to stdin and check the exit code and stderr. Tests written that way survive a change of implementation language unchanged.

---

## 3. The runtime model

### 3.1 Which hooks fire on which tool call

Taken from `.claude/settings.json`. Every hook command has the form `${CLAUDE_PROJECT_DIR}/bin/fw hook <name>`, which dispatches to `agents/context/<name>.sh`. The only exception is the Stop hook, which is called directly.

| Event | Matcher | Hook |
|---|---|---|
| PreToolUse | `Write\|Edit\|Bash` | `check-active-task` (task, focus and G-020 gates) |
| PreToolUse | `Write\|Edit\|Bash` | `check-project-boundary` |
| PreToolUse | `Write\|Edit\|Bash` | `budget-gate` |
| PreToolUse | `Bash` | `check-tier0` |
| PreToolUse | `Bash` | `check-paid-backend` |
| PreToolUse | `Write\|Edit` | `check-human-ac-tick`, `check-active-completed-dup`, `check-arc-id`, `check-heredoc-cmd-sub`, `check-inception-decisions`, `check-inception-schema`, `check-onboarding-gate`, `check-worktree-governance-write` (8 hooks) |
| PreToolUse | `Agent` | `check-agent-dispatch` |
| PreToolUse | `EnterPlanMode` | `block-plan-mode` |
| PreToolUse | `TodoWrite\|TaskCreate\|TaskUpdate\|TaskList\|TaskGet` | `block-task-tools` |
| PreToolUse | one MCP tool | `check-rail-mcp-label` |
| PostToolUse | (all tools) | `checkpoint post-tool`, `loop-detect`, `audit-task-tools` |
| PostToolUse | `Bash` | `error-watchdog` |
| PostToolUse | `Write` | `check-fabric-new-file` |
| PostToolUse | `Write\|Edit` | `commit-cadence`, `check-settings-edit` |
| PostToolUse | `Task\|TaskOutput` | `check-dispatch` |
| UserPromptSubmit | (all) | `sidecar-inbox` |
| Stop | (all) | `agents/context/stop-driver.sh` (timeout 10 s) |
| SessionStart / PreCompact | startup, resume, compact | `post-compact-resume`, `pre-compact` |

**Number of hook processes per tool call:**
- **Bash call:** 5 PreToolUse + 4 PostToolUse = **9**.
- **Write call:** 11 PreToolUse + 6 PostToolUse = **17**.
- **Edit call:** 11 PreToolUse + 5 PostToolUse = **16**.
- **Read call:** 0 PreToolUse + 3 PostToolUse = **3**.

### 3.2 Measured cold-start latency per hook

**Method:** a Python harness ran each hook 5 times with a synthetic PreToolUse/PostToolUse JSON payload on stdin. The payloads were: Bash `{"command":"ls"}`; Write to a path under `docs/reports/`; and Read for the post-hooks. Each payload had a unique `tool_use_id`. The harness recorded wall-clock time with `time.perf_counter` around `subprocess.run` and reports the median. Each hook was measured twice: as configured (`bin/fw hook <name>`) and directly (`bash agents/context/<name>.sh`). Every hook exited 0 (allow) on these inputs, so all timings are of the **allow path**. `budget-gate` was given a real 237 KB transcript copy. The harness ran on the host described at the top.

**Baselines:** `bash -c true` = **2 ms**; `python3 -c pass` = **68 ms**; `bin/fw version` = **123 ms**.

| Event | Matcher | Hook | Median via `bin/fw hook` (ms) | Median direct (ms) | Range via fw (ms) |
|---|---|---|---:|---:|---|
| Pre | Write\|Edit\|Bash | check-active-task | 394 | 283 | 372–417 |
| Pre | Write\|Edit\|Bash | check-project-boundary | 270 | 165 | 263–295 |
| Pre | Write\|Edit\|Bash | budget-gate | 264 | 155 | 254–569 |
| Pre | Bash | check-tier0 | 417 | 310 | 413–433 |
| Pre | Bash | check-paid-backend | 327 | 232 | 325–337 |
| Pre | Write\|Edit | check-human-ac-tick | 183 | 78 | 178–199 |
| Pre | Write\|Edit | check-active-completed-dup | 198 | 79 | 179–208 |
| Pre | Write\|Edit | check-arc-id | 193 | 80 | 178–218 |
| Pre | Write\|Edit | check-heredoc-cmd-sub | 189 | 85 | 184–192 |
| Pre | Write\|Edit | check-inception-decisions | 203 | 102 | 196–205 |
| Pre | Write\|Edit | check-inception-schema | 177 | 76 | 175–187 |
| Pre | Write\|Edit | check-onboarding-gate | 181 | 78 | 178–188 |
| Pre | Write\|Edit | check-worktree-governance-write | 210 | 110 | 209–215 |
| Post | (all) | checkpoint post-tool | 239 | 136 | 238–312 |
| Post | (all) | loop-detect | 143 | 44 | 141–148 |
| Post | (all) | audit-task-tools | 178 | 79 | 174–180 |
| Post | Bash | error-watchdog | 179 | 75 | 176–193 |
| Post | Write\|Edit | commit-cadence | 185 | 76 | 176–199 |
| Post | Write\|Edit | check-settings-edit | 183 | 76 | 180–198 |

Not timed: `check-fabric-new-file`, `check-agent-dispatch`, `sidecar-inbox`, `stop-driver`, and the session and compaction hooks.

**Observations (these are arithmetic on the table, not new measurements):**
- **The `bin/fw` dispatcher adds about 100–105 ms to every hook.** That is the "via fw" median minus the "direct" median. Bash parses and sources the 10,901-line `bin/fw` before it reaches the `hook)` case arm. This cost is roughly the same as `bin/fw version` (123 ms).
- **The heaviest gates take 250–420 ms each.** These are the Tier 0 classifier, the task gate, the budget gate and the paid-backend guard. Most of that time is the bash startup plus one or more `python3` interpreter launches; one launch costs about 68 ms here.
- **Summed hook CPU time per tool call** is about **2.4 s for a Bash call** (Pre 1,672 ms + Post 739 ms) and about **3.4 s for a Write call** (Pre 2,462 ms + Post at least 928 ms, excluding one untimed hook). Claude Code's hook documentation says matching hooks for one event run in parallel. If so, the **wall-clock** time added per call is roughly the slowest Pre hook plus the slowest Post hook, about 0.4 + 0.25 s, on this machine. The CPU cost is still paid on every call. We did not measure wall-clock time inside a live Claude Code session.
- **For comparison (inference, not measured here):** a statically linked Go binary typically starts in single-digit milliseconds. The budget-gate header says its target is "<100 ms per invocation". Through `bin/fw`, it measures 264 ms.

### 3.3 Failure semantics today (relevant to "fail closed")

These facts were read from the code. They matter for any rewrite that must fail closed.
- **Missing hook script → allow.** In `bin/fw hook`, if `agents/context/<name>.sh` does not exist, the dispatcher logs `missing-hook` and **exits 0** (T-1360). This was a deliberate choice: blocking would hard-lock every Bash, Write and Edit call. It is a fail-open path.
- **Hook crash → allow, with a banner.** `fw_hook_crash_trap` (`lib/config.sh:172`) installs an EXIT trap. When a hook exits with any code other than 0 or 2, the trap prints "HOOK CRASHED … This is a hook malfunction, NOT a policy block" and appends to `.context/working/.hook-crashes.log`. The trap does not change the exit code. Under Claude Code semantics a non-0, non-2 exit is non-blocking, so **a crashing gate allows the tool call**.
- **Parse error in `bin/fw` → blocks everything.** Every hook routes through `bin/fw`. A syntax error there makes every PreToolUse hook fail. Learnings L-332 and L-408 record this as "self-locking": the agent cannot run the Edit or Bash call that would fix the file. This failure mode is closed, but not by design.
- **Inline-Python breakage → gate silently allows.** Learning L-528 records that a backtick inside a double-quoted `python3 -c "…"` block made the Python a SyntaxError, so "the gate fails open while still exiting 0."
- **Budget gate with no transcript → allow.** This is documented as an intentional fail-open: "If no transcript available, fails open (PostToolUse fallback handles it)."
- **Tier 0 lock timeout → block.** The exact-text approval path fails closed. If it cannot take the lock within 10 s, it consumes nothing and blocks.

### 3.4 How consumers get the framework

- **Install.** `install.sh` checks for **bash ≥ 4.4** (so macOS's system bash 3.2 is rejected and Homebrew bash is needed), git ≥ 2.20 and Python ≥ 3.8. Node is optional. It clones the framework and puts `fw` on PATH.
- **Vendoring.** `fw init <project>` / `fw vendor` call `do_vendor()` (in `bin/fw`). This **copies** `bin/`, `lib/`, `agents/`, `web/`, `docs/`, `.tasks/templates/`, `policy/`, `FRAMEWORK.md` and related files into the consumer's **`.agentic-framework/`** directory, using one `rsync` per include. It also writes a `.upstream` sentinel that records where it came from. The consumer is then self-contained. This repository vendors itself too: its `.agentic-framework/` is **35 MB, 2,660 files, VERSION 1.7.695**.
- **Upgrade.** `fw upgrade [<project>]` (`lib/upgrade.sh`, 2,787 lines) syncs the vendored copy through the same `do_vendor()`. It also refreshes the consumer's `.claude/settings.json` hooks and the version pin in `.framework.yaml`, and merges governance sections, templates and seeds while preserving project content.
- **Consumer hooks** are registered as `${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook <name>`, so a consumer runs its **vendored** copy. It does not use a global install.
- **Shim.** `bin/fw-shim`, copied to `~/.local/bin/fw`, walks up from the current directory. If it finds `bin/fw` next to `FRAMEWORK.md` it uses that (this is the framework repo). Otherwise, if it finds `.agentic-framework/bin/fw`, it uses that (a consumer). It then `exec`s the result.
- **Release train.** Development happens on branch `bleeding-edge`. `master` is the consumer install surface and only fast-forwards at a release (`fw release tag-and-release`). Consumers upgrade from the last release, not from tip.
- **Windows** is supported through WSL only. In the P-01 field test, native Git Bash was blocked (§7).

**Implication for a compiled core (inference).** Today a consumer receives only text files. A compiled binary would need one of three routes: ship per OS and architecture inside `.agentic-framework/`, be fetched or built at `fw upgrade`, or be compiled on the host. This is open question IW-4.

---

## 4. The candidate "established core" modules

**How measured.**
- **Lines:** `wc -l`.
- **Test files and tests:** the number of test files under `tests/` whose text mentions the module's path or name, and the tests inside them. This is an **upper bound**, because a file that mentions a module does not necessarily test it. The exception is Tier 0, where the files are listed by name.
- **Dependents:** taken from `bin/fw fabric deps <path>`, the project's hand-maintained component graph. Its edges are noisy and some directions look inverted, so treat the counts as indicative of coupling, not exact.

### 4.1 Tier 0 classifier and pre-push guard

| File | Lang | Lines | Role |
|---|---|---:|---|
| `agents/context/check-tier0.sh` | bash, with 13 `python3 -c` blocks | 936 | PreToolUse gate on Bash. It does keyword pre-filtering in bash, then detailed detection with Python regexes inside a bash string. It handles self-approval detection, approval lookup, consumption and logging. |
| `lib/tier0_action.py` | Python (36 defs/classes) | 885 | Maps a command to **actions** (`force-push {remote, ref}`, `branch-delete`, `hard-reset {repo, branch, target}`, `recursive-delete {path}`) through a small explicit grammar. It also holds the approval store (flock-locked JSON), single-use consumption, the TTL, and the `prepush` subcommand. |
| `agents/git/lib/hooks.sh` | bash | 1,579 | Generates and installs git hooks (commit-msg, post-commit, pre-push). The generated pre-push hook reads git's ref-update lines and calls `tier0_action.py prepush` to refuse a non-fast-forward update or a ref deletion unless a matching approval exists. If the module is missing it refuses. |

**What the gate does (from CLAUDE.md and the module docstrings).** It reads only `tool_input.command`, the literal text of the Bash call. It never opens a file that the command refers to, so `bash x.sh`, `make` and `python3 y.py` are not inspected. Any command that contains the word `tier0` (after removing quotes and backslashes and decoding ANSI-C quoting) is treated as Tier 0, unless it is a plainly spelled read-only `fw tier0 status|list|help`. This blocks self-approval. Commands that map to the grammar get action-keyed approvals. Every other *detected* destructive command needs approval of its exact text, hashed over the raw bytes. Duplicate hook fires are deduplicated by `tool_use_id`. A push approval is only *admitted* by the text gate; git's pre-push hook *consumes* it, with a 60 s admission TTL.

**Tests.** These are named files (`tests/*/*tier0*`, `*3593*`, `*3594*`): 16 files, 228 test cases. The largest are:
- `t3593_tier0_action_approvals.bats` (43)
- `check_tier0.bats` (34)
- `t3594_prepush_forced_update_guard.bats` (23)
- `test_tier0_origin.py` (18)
- `t3593_round4_prefix_cdpath_dedup.bats` (15)
- `t3593_round5_grammar.bats` (15)
- `t3593_round7_no_normalisation.bats` (12)

The round-7 reviewer ran the five core suites in a fixture: **166 tests, all passing**. The T-3670 task calls this "~170".

**Dependents (fabric).** `check-tier0.sh`: 4 dependencies, 17 dependents (audit, self-audit, doctor hook exercise, approvals UI, tests). `hooks.sh`: 12 dependencies (secret-scan, master-guard, large-file-scan, `bin/fw`, …), 33 dependents. `tier0_action.py` has no fabric card edges ("may need card enrichment"); by grep it is used by `check-tier0.sh`, `hooks.sh` and `bin/fw`.

**Observed while building this pack.** A read-only `grep` whose pattern contained the word `tier0` was blocked as Tier 0 SELF-APPROVAL. This is the documented, accepted cost of the word rule ("a read-only command that names the bare word … is blocked; … name the file instead").

### 4.2 `check-active-task.sh` (task, focus and G-020 gates)

| File | Lang | Lines |
|---|---|---:|
| `agents/context/check-active-task.sh` | bash, with 7 `python3 -c` blocks | 1,261 |
| `agents/context/lib/safe-commands.sh` (Bash allowlist classifier) | bash | 1,488 |
| sources `lib/paths.sh`, `lib/config.sh`, `lib/section-extract.sh` | bash | — |

**Role.** This is a PreToolUse gate on Write, Edit and Bash. For Write and Edit it checks the file path. Some paths are exempt: `.context/`, `.tasks/`, `.claude/`. For Bash it classifies the command against a safe-command allowlist; read-only commands pass without a task. Otherwise it requires that focus names an active task. It also runs:
- **G-020**, the build-readiness gate, which refuses work on a task whose ACs are placeholders;
- **the T-1730 focus-drift gate**, which refuses a commit or update against a task other than the focused one unless an explicit `--switch-focus` or `FW_SWITCH_FOCUS=1` is given;
- **session-scoped focus** (T-3038).

`FW_SAFE_MODE=1`, set on the Claude process environment, bypasses this gate only.

**Known gap.** **G-077 (high).** The allowlist admits `python3 -c` behind a *textual* deny-list of write indicators. Seven ordinary Python write idioms (for example `pathlib.write_text`) match none of it, so writes reach disk with no task and no audit trail. Learning L-554 adds that a safe-list must be reviewed "as a product of entries": `curl … | python3 -c <write>`.

**Tests.** 64 files mention it, with 701 test cases (upper bound).

**Dependents (fabric).** 5 dependencies, 37 dependents. The dependents include `check-human-ac-tick`, `check-onboarding-gate`, the hook-parity tests, and about 20 specific regression suites (`focus_drift_gate`, `t3038_session_scoped_focus`, `t2988_grouped_command_classification`, …).

### 4.3 `budget-gate.sh` and `checkpoint.sh`

| File | Lang | Lines | Role |
|---|---|---:|---|
| `agents/context/budget-gate.sh` | bash, with 5 `python3 -c` blocks | 528 | PreToolUse on Write, Edit and Bash. It reads token usage from the session JSONL transcript (the slow path, every 5th call) or from the cached `.budget-status` (the fast path, fresh if under 90 s). At the critical level, 95% of the configured context window, it **blocks** everything except wrap-up actions (git commit, handover, task update, reads, writes to `.context/`, `.tasks/` and `.claude/`). It classifies commands through `lib/cmd_classify.py`. |
| `agents/context/checkpoint.sh` | bash, with 3 `python3 -c` blocks and 1 heredoc | 682 | PostToolUse on all tools. It is the fallback: it warns at 75% and 85%, and triggers an automatic handover and a restart signal at critical. |
| `lib/context_tokens.py` | Python | — | Shared token reader. |

**Tests.** budget-gate: 23 files and 214 tests. checkpoint: 25 files and 290 tests (both upper bounds).

**Dependents (fabric).** budget-gate has 6 dependencies and 15 dependents, including lint tests such as `no-backticks-in-inline-python`, which exists because of L-528, L-627 and L-684. checkpoint has 5 dependencies (including `handover.sh`) and 11 dependents.

### 4.4 `lib/verdict_ledger.py` and `lib/reviewer/`

| File | Lang | Lines |
|---|---|---:|
| `lib/verdict_ledger.py` | Python | 3,333 |
| `lib/review_policy.py` (required review "rung" per impact) | Python | 421 |
| `lib/reviewer/static_scan.py` (anti-pattern static scanner) | Python | 3,194 |
| `lib/reviewer/judge_cli.py` | Python | 946 |
| `lib/reviewer/audit.py`, `recommendation_claims.py`, `reverify.py`, `drift.py`, `overrides.py`, `classifier.py`, `*_cli.py` | Python | 2,138 combined |

**Role.** An independent reviewer's verdict (green, amber, red or escalate) is appended to `.context/reviews/verdicts.jsonl`. `update-task.sh --status work-completed` reads the ledger, and a valid green verdict ticks the matching Human AC. A row counts only with verified provenance:
- an HMAC-signed review-dispatch registry entry;
- a reviewer who is not a producer of the task, where producers are derived from git commits;
- an introducing commit that exists and was not made by a producer.

The ledger is **append-only as verified against git history**: any modified, deleted or duplicated row makes the whole ledger refuse. Every close attempt revalidates earlier ticks. The required review strength ("rung" 1, 3 or 5) is computed from task impact and the components the task touched.

**Stated limit (T-3581).** Every agent runs as the same OS user as the signing key, so a coherently fabricated chain cannot be told apart from a genuine one. The design is fail-closed against accidents and unsophisticated forgery. It is not forgery-resistant.

**Tests.** 17 files mention `verdict_ledger` (466 tests). The largest is `test_t3579_verdict_ledger.py`, with 64. 40 files mention the reviewer package (626 tests). Both are upper bounds.

**Dependents.** `verdict_ledger.py` has no fabric card edges; by grep it is used by `update-task.sh`, `bin/fw`, `agents/audit/audit.sh`, `lib/upgrade.sh`, `agents/termlink/termlink.sh`, `lib/review_policy.py` and `lib/reviewer/judge_cli.py`. `static_scan.py` has 6 dependencies and 13 dependents (`update-task`, `audit`, `fw`, `drift_cli`, …).

**Note.** This module is already Python. For it, the question is strict typing and packaging, not leaving bash.

### 4.5 The `update-task.sh` close gates

| File | Lang | Lines |
|---|---|---:|
| `agents/task-create/update-task.sh` | bash, with 6 `python3 -c` blocks and 7 Python heredocs | 2,743 |

**Role.** It handles every task status transition. The `--status work-completed` path runs these gate functions, among others:
- `check_human_sovereignty`
- `check_acceptance_criteria` (P-010)
- `check_recommendation_for_review`
- `check_rca_for_bugfix`
- `check_render_surface_human_ac` (P-013)
- `check_inception_decision`
- `check_inception_scope_trace`
- `check_evolution_log`
- `check_disposition_gate`
- `check_task_pair_acd`
- `check_verification_port_literals`
- `check_verification_unjudged_test_runs`

It also runs the **P-011 verification gate**, which executes each line of `## Verification` as a shell command, and the verdict-ledger apply step.

There are 11 `--skip-*` bypass flags. Each requires `--reason`. The criterion and ownership flags are refused when `CLAUDECODE=1` (that is, when an agent runs them) unless `--i-am-human` is passed.

On success it moves the file to `completed/`, generates episodic memory and clears focus.

It sources 9 bash libraries and calls 5 Python modules, among them `verdict_ledger.py`, `human_review_state.py`, `inception_decisions.py` and `task_pair_acd.py`.

**Tests.** 100 files mention it (960 tests, upper bound).

**Dependents (fabric).** 21 dependencies and 53 dependents. This is the most coupled module after `bin/fw`.

### 4.6 `bin/fw` (the dispatcher)

| File | Lang | Lines |
|---|---|---:|
| `bin/fw` | bash, with 60 `python3 -c` blocks and 21 Python heredocs | 10,901 |

**Role.**
- It resolves `FRAMEWORK_ROOT` and `PROJECT_ROOT` and loads configuration from four tiers: CLI flag, then `FW_*` environment variable, then `.framework.yaml`, then the default.
- It routes about 103 top-level subcommands and the `hook <name>` path.
- It contains a number of implementations inline, for example `do_vendor`, the cron generator and doctor helpers.

**Tests.** 444 test files mention `bin/fw` (3,844 tests), which is most of the suite.

**Dependents (fabric).** 371 edges. Every hook, and most agents, call it.

**Startup cost.** About 100–123 ms before any work happens (§3.2).

---

## 5. Failure catalogue: bash and shell-class defects

**Source:** `.context/project/learnings.yaml` (725 entries) and `.context/project/concerns.yaml` (116 entries).

**How counted:** a keyword regex over the learning text, so the counts are **approximate** and some categories overlap.

| Category | Learnings matched by keyword |
|---|---:|
| pipefail / SIGPIPE / exit 141 | 27 |
| errors swallowed (`2>/dev/null`, `\|\| true`) | 25 |
| `set -e` / errexit / `set -euo pipefail` | 17 |
| heredoc (any) | 14 |
| quoting / word-splitting | 14 |
| shellcheck findings | 12 |
| backticks | 8 |
| subshell / pipe scope | 7 |
| inline `python3 -c` | 7 |
| trap / EXIT | 9 |
| dead negation | 4 |
| grep and sed portability | 4 |

**Data-quality note.** 24 learning ids occur more than once in the file; examples are L-006, L-014 and L-022. Below, each entry is identified by its id plus its task.

### 5.1 Selected entries (one line each, quoted or closely paraphrased)

**Heredoc and command substitution**
1. **L-332 (T-1629).** "Never use heredoc-in-command-substitution (`$(cmd <<EOF … EOF)`) in … hot-path hook dispatchers (bin/fw …)". The parse interaction is fragile across bash versions, and a parse error in bin/fw "is unrecoverable from inside Claude Code because every PreToolUse hook routes through bin/fw".
2. **L-408 (T-1942).** "NEVER edit bin/fw heredoc/command-substitution constructs without bash -n verification BEFORE the next tool call". A wrong closing `)` creates "a self-locking failure mode".
3. **L-294 (T-1530).** An unquoted heredoc (`<<EOF`) "command-substitutes `$(.*?)` inside Python regex strings, silently mangling the regex."
4. **L-370 (T-1816).** "Bare shell-heredoc interpolation silently produces broken YAML when values contain ':', '#', or newlines."
5. **G-073 (concern, low).** `cat > "$file" << HEREDOC` fails silently at the redirect when the directory is missing. A function "printed its unconditional success banner and exited 0 while every hook write had failed."

**Backticks and quotes inside `python3 -c "…"`**

6. **L-528 (T-2707).** "Backticks inside a double-quoted python3 -c "..." block are command substitution performed by bash before python starts … In a PreToolUse hook that means the gate fails open while still exiting 0."
7. **L-627 (T-3086).** A backtick-quoted `fw … approve` inside a double-quoted registry string in `lib/config.sh` "made every source of config.sh exec fw, a self-replicating fork bomb that OOM-crashed the host 4x in 22h."
8. **L-684 (T-3594).** "A backtick or `$(` inside check-tier0.sh's double-quoted python3 -c block is bash command substitution, even in a Python comment: a comment naming a git push executed a real push from the hook's cwd."
9. **L-440 (T-2068).** A literal `"` inside a `python3 -c "…"` comment "terminates [the string] … and shifts argv at runtime; bash -n does NOT catch [it] because syntax is parse-time valid."

**`set -e`, pipefail and SIGPIPE**

10. **L-236 (T-1374).** "set -euo pipefail silently aborts via command-substitution assignments … the abort happens BEFORE any subsequent 'silent failure detector' can fire."
11. **L-022 (T-1362).** `grep PATTERN file | sed …` "aborts the enclosing function when grep has no match (grep exits 1, pipefail propagates, set -e catches)."
12. **L-302 (T-1545).** Regular assignments (unlike `local var=…`) propagate pipeline failures. A filter chain that removes all input "aborts the calling function silently."
13. **L-304 (T-1557).** Foundation utilities (`yaml.sh:get_yaml_field`, `config.sh:_fw_config_file_val`) must guard pipelines: "The pipefail trap (L-302) is contagious."
14. **L-240 / L-305 / L-387 / L-613 (T-1385, T-1558, T-1862, T-3039).** In the verification gate, `cmd | grep -q X` exits **141** (SIGPIPE) "when grep finds the match", so "it fails precisely when the check SUCCEEDS early". This was recorded four separate times.
15. **L-299 (T-1541).** In GNU grep BRE, `` \` `` is a start-of-buffer assertion, so `grep -v '^\`\`\`'` "matches every line and strips all input". Under pipefail this then aborts before the diagnostic.
16. **L-006 (T-1250).** `grep -c` exits 1 on zero matches. Using `|| echo 0` "appends extra '0' producing multi-line vars that break arithmetic."
17. **G-089 (concern, medium).** The cron generator rewrites every job to `<cmd> 2>&1 | logger …`. "logger always succeeds", so every job's exit status is masked.

**Negation and dead assertions**

18. **L-636 (T-3138).** "Bash exempts from errexit any command whose return value is inverted with '!'. A non-final `! cmd` inside a bats test therefore CANNOT fail it." 106 such sites were swept.
19. **L-651 (T-3191).** The dead-negation linter was wired into no gate, and the class "was reintroduced two days later … only mutation testing caught it."
20. **L-655 (T-3250).** A `{ …; fail=$((fail+1)); } | tee` block runs in a subshell, "so counters never reach the parent and [the] exit … returns 0 on every run regardless of failures."
21. **L-656 (T-3250).** Four test-harness false greens of one shape, including "`grep -c | grep -qx 0` under pipefail returned FAIL for EVERY input".

**Arithmetic, globbing and portability**

22. **L-395 (T-1687).** `$((…))` treats `'008'` and `'009'` as invalid octal ("value too great for base"), so `10#` is needed. This was latent in `lib/arc.sh` and "would fire at arc-008."
23. **L-014 (T-1320).** Without `shopt -s globstar`, "`**` silently collapses to `*`," which diverged from Python's `glob(recursive=True)`.
24. **L-592 (T-2951).** **ugrep** used in place of `grep` "applies ignore PATTERNS with no knowledge of git's index", so tracked but pattern-matched files were invisible to the agent.
25. **L-125 / L-048 (T-348, T-1158).** `lib/compat.sh` exists for GNU/BSD differences (`_sed_i`, `_date_to_epoch` with a GNU→BSD→python3 fallback).
26. **CRLF (T-3665, P-01 Windows field test).** "a CRLF checkout silently disables the secret scan" on native Windows.
27. **CDPATH (Tier 0 rounds 4 and 7).** A bare relative `cd` is unsafe to key on while `CDPATH` is set. Round 7 found that the hook reads `CDPATH` from *its own* environment, not from the Bash tool's shell (§6).

**Processes, locks and state**

28. **L-367 (T-1687).** A `( sleep T && kill $$ ) &` watchdog "leak[s] EVERY inherited file descriptor", including a flock fd, which blocked later `fw audit` runs for 600 s.
29. **L-280 (T-1478).** "flock + trap-rm of lockfile defeats sequential mutual exclusion."
30. **L-672 (T-3371).** A `mapfile → edit → rewrite` counter in `lib/hook-telemetry.sh` lost "17 of 1600 (98.9% loss)" increments under concurrency. This happens on every hook fire.

**Text matching standing in for parsing**

31. **G-077 (high), with L-554.** A textual deny-list in front of `python3 -c` on the Bash allowlist lets writes through with no task (§4.2).
32. **L-600 (T-2991).** P-011 `eval`s each verification line. A multi-line `python3 -c` block had its Python body run as bash: "`import yaml,sys` is a valid bash line that runs ImageMagick's screenshot tool, writing multi-MB PostScript into the repo root."
33. **L-284 (T-1500).** Tier 0 hashed the raw command, so whitespace re-flow voided approvals. Whitespace was then normalised. Round 6 (§6) later found that the normalisation collapsed distinct quoted paths into one key.

**The pattern (inference, from the entries above).** Most of these defects are silent. A gate allows, a check passes or a counter under-reports, with exit 0 and no error. Many come from bash *evaluating text that was meant as data*: Python in a double-quoted string, regexes in a heredoc, verification lines passed to `eval`. Most of the rest come from bash exit-status semantics: errexit exemptions, pipefail and SIGPIPE, subshell scope. The usual remedy has been one more lint, one more test and one more learning per instance.

---

## 6. Tier 0 review history (rounds 3–7)

**Source:** `docs/reports/T-3593-round{3..7}-*.md`. These were independent external reviews of the Tier 0 gate (T-3593: action-keyed approvals and the text classifier; T-3594: the git pre-push guard). Each round reviewed the fixes for the previous round. Reviewers in rounds 3–6 had a read-only filesystem, so their bats runs could not start ("`/tmp` is not writable"), and their findings come from code reading and read-only classifier probes.

**Round 3 (Codex). T-3593 RED, T-3594 AMBER.**
- A multi-setting `GIT_CONFIG_PARAMETERS="'core.hooksPath=/dev/null' 'a.b=c'"` prefix let `git push -f` map to an ordinary force-push approval while hiding the hook bypass.
- A five-second text-based replay window was not "single use."
- Tag deletions (`:v1`, `--delete v1`) were keyed as `v1`, while pre-push expected `refs/tags/v1`, so the stranded approval could authorise deleting a *branch* `v1`.
- `git -P push -f` escaped text detection.

**Round 4 (Codex). T-3593 RED, T-3594 AMBER.**
- HIGH: environment taint disappeared behind wrappers. `command export GIT_CONFIG_GLOBAL=…`, a quoted `'export'` and `command source envfile` before `git -C <abs> push -f` still produced a force-push action.
- HIGH: an escaped-space path (`git -C /tmp/a\ b push -f …`, also with `reset --hard` and `commit -n`) returned SAFE, because the regex did not see the argument boundary.
- MEDIUM: the legacy deduplication path continued after `flock -w 10` failed.
- MEDIUM: deduplication guarantees needed qualification. A replayed valid `tool_use_id` was accepted after the grant expired. A test named "cannot run twice" never executed a reset.

**Round 5 (Codex). RED.** By this round the classifier had been rewritten as an explicit grammar, and the reviewer confirmed that quotes, variables, globs, wrappers, here-strings, process substitution and newlines all came out unmapped.
- HIGH: `git branch -D victim`, `-D +victim` and `-D refs/heads/victim` produced the same key. Push-style normalisation was applied to local branch names, so an approval for `victim` could delete a different branch.
- MEDIUM: `env -u CLAUDECODE bin/fw $'tier\x30' approve` returned SAFE. This is ANSI-C quoting decoded to `tier0`, a typed self-approval.

**Round 6 (Codex). RED.**
- Round-5 probes closed.
- HIGH: `HEAD:refs/tags/x` and `HEAD:refs/heads/refs/tags/x` shared a force-push key, and so did the matching deletions. Stripping `refs/heads/` made branch `refs/tags/x` indistinguishable from tag `x`, and pre-push repeated the same normalisation.
- HIGH: the fallback exact-text hash collapsed whitespace inside quotes, so `rm -rf ./ "a  b"` and `rm -rf ./ "a b"` shared an approval.
- MEDIUM: `$'tier\0junk'0` and `$'tier\x00junk'0` returned SAFE. Bash truncates an ANSI-C string at NUL and then concatenates the trailing `0` into `tier0`; the detector kept the NUL and the characters after it.

**Round 7 (Codex). RED.**
- Round-6 findings closed.
- HIGH: `action_key()` serialised targets as `force-push|ref=…|remote=…`, so ref `refs/heads/x|remote=y` with remote `z`, and ref `refs/heads/x` with remote `y|remote=z`, collided. Git accepts those characters in a ref name. Same for `branch-delete`. Suggested fix: canonical JSON keys.
- HIGH: `env -u CLAUDECODE bin/fw ti\⏎er0 approve` (a backslash-newline line continuation) passed the allow fast path.
- LOW: `rm -rf lib` and `rm -rf ./lib` got different keys, which over-blocks.

**Round 7 (Claude). RED.** It ran all 166 tests in a fixture, and all passed. About 55 collision probes found no new text-level collision.
- HIGH: brace expansion. `bin/fw tier{0..0} approve`, `t{i..i}er0`, `{tier,}0` and `tie{r,}0` pass the gate. With `CLAUDECODE=1` unset, the approval is recorded as `approved_by: human`.
- HIGH: line continuation, `tier\⏎0 approve`, confirmed end to end.
- MEDIUM: the glob forms `tier[0]`, `tier?` and `ti*0` are SAFE. They work when a file named `tier0` exists, and brace expansion can create one.
- MEDIUM (not tested live): a `curl -X POST …/api/approvals/decide` against the local Watchtower writes an approval with no human check, and the CSRF token can be read with a GET.
- LOW: the push key holds the remote *name*, not its URL, so a `git remote set-url` inside the window would retarget it.
- LOW: `CDPATH` is read from the hook's environment, not from the Bash tool's shell.
- MEDIUM, over-block: an unmapped force push needed **3 approvals** (exact text, then the pre-push action, then exact text again).
- Deployment: this repository's own `.git/hooks/pre-push` still lacked the T-3594 guard until `install-hooks` was re-run.

**The pattern.** Over five rounds the hand-written text classifier kept missing **shell expansions**: environment-changing builtins behind wrappers, escaped spaces, ANSI-C quoting, ANSI-C with NUL truncation, line continuation, brace expansion and globs. It also kept introducing **normalisation collisions**: tag versus branch namespaces, local branch prefixes, collapsed whitespace and delimiter injection in serialised keys. Each fix closed the specific probe and the next round found a sibling. Round 5 replaced the denylist with an allow-grammar ("unmapped is the fail-safe direction"). That stopped the *mapping* holes but not the *detection* holes. Detection still has to answer "does this text, once bash expands it, contain the word `tier0`?", and that question needs bash's own expansion rules. The T-3670 hypothesis is that a real bash AST (`mvdan.cc/sh`, which models brace expansion, ANSI-C quoting, line continuation and word parts) closes the detection class, and that typed, structured keys close the serialisation class. Open question IW-3 asks whether that is true.

---

## 7. Constraints for any rewrite

1. **The four directives, in priority order** (§1). Any change must show it improves Antifragility and Reliability without regressing Usability or Portability.
2. **Portability.**
   - No runtime, provider or OS lock-in.
   - Supported targets are **Linux, macOS and Windows through WSL**.
   - Native Windows Git Bash is currently unsupported. In the P-01 field test (`docs/reports/T-3659-p01-zero-to-running.md`, one Windows 10 machine, 57 findings), the documented native install took 15 min 51 s and was blocked: Watchtower could not start (an `fcntl` crash). The WSL route worked after about 10 manual fixes. A one-command PowerShell installer reached a ready project in 127 s with 0 fixes.
   - The current prerequisites are bash ≥ 4.4 (macOS needs Homebrew bash), git ≥ 2.20 and Python ≥ 3.8.
   - P-01 proposes an installer kit under `install/` in the framework repo, versioned with releases.
   - The framework must also work in CI and headless hosts, and inside git worktrees.
3. **Consumers vendor the framework.** Each consumer runs its own copy in `.agentic-framework/`, refreshed by `fw upgrade`, and its hooks call `.agentic-framework/bin/fw hook <name>`. Today that copy is plain text. Any compiled artefact must reach consumers through this path, or through an equivalent one that keeps the per-project version pin, and old consumers must keep working.
4. **Hooks must fail CLOSED.** A gate that cannot decide must block; it must not allow. Today several paths fail open (§3.3): a missing hook script, a crashing hook (because of Claude Code's exit-code semantics), broken inline Python, and the budget gate with no transcript. Some of these were deliberate, to avoid self-locking the session. A rewrite needs an answer to *fail closed without making the agent unable to repair the gate*. For example, failing closed except for an explicit, narrow repair path.
5. **The existing bats and pytest suites are the behavioural contract.** That is 11,400 test cases. The core modules alone account for about 228 Tier 0 tests (166 in the five core suites), up to 701 that touch the task gate, and up to 960 that touch `update-task.sh`. Most drive hooks as black boxes through stdin JSON, exit codes and stderr, so they can run against a new implementation unchanged. Learnings L-631, L-636 and L-651 warn that some tests are inert; mutation testing found tests that assert nothing.
6. **The operator approves Tier 0 and sovereignty actions.** The human approves Tier 0 actions (`fw tier0 approve`), inception go/no-go decisions, human-owned task closure and arc closure. Agents are structurally refused under `CLAUDECODE=1`. A rewrite must not create any path by which an agent can record a human approval.
   - **Stated residual:** all agents run as the same OS user with write access to the repo, so file-level forgery is out of scope. The gates are "fail-closed against accidents and unsophisticated self-approval, not forgery-resistant."
7. **Scope boundary of Tier 0.** The gate sees only the typed command string (T-2742). Scripts are governed at write time (Tier 1), not at run time. A rewrite is not expected to inspect arbitrary scripts.
8. **Latency budget.** At least 9 hooks run on every Bash call and 16–17 on every Write or Edit (§3.1). Startup cost multiplies across calls.
9. **Migration discipline (proposed, IW-5).** One module at a time. Old and new paths run side by side with a parity check. The bats suites are the contract. No big-bang rewrite. Development goes to `bleeding-edge`, and consumers get it only at a release.

---

## 8. Open questions (copied from T-3670)

- **IW-1: Which language for the established core: Go, Rust, or strict Python?**
  - Go: mvdan.cc/sh (shfmt's parser), a single static binary, fast hook cold-start.
  - Rust: matches TermLink, the strongest guarantees, but a less mature bash parser.
  - Strict Python (mypy --strict): the lowest migration cost, but slow hook startup, and only bashlex as a parser.
  - Lean: Go.
- **IW-2: What counts as "established core"?** Proposed set: the Tier 0 classifier and pre-push guard, check-active-task (task/focus/G-020 gates), budget-gate, verdict ledger, and the update-task close gates. The criteria: security-critical, stable spec, a large existing test suite, fires on every tool call.
- **IW-3: Does the pilot (the Tier 0 classifier on a real bash AST) close the self-approval and normalisation class as claimed?** Measure it against the existing ~170 Tier 0 tests plus every review probe from rounds 3-7, and compare latency.
- **IW-4: Distribution and consumers.** How does a compiled binary ship? Built per OS/arch at release, vendored into `.agentic-framework/`, or built on `fw upgrade`? What happens on hosts where it is missing (fail closed to the current bash path)? What does it mean for the P-01 installer and Windows/WSL?
- **IW-5: Migration discipline.** One module at a time, the old and new paths run side by side with a parity check, the existing bats suites as the contract, and no big-bang rewrite.

**What we ask of each reviewer:**
1. An assessment of whether to move the core at all.
2. A language recommendation with reasons.
3. The module scope and migration order.
4. A distribution design for vendored consumers on Linux, macOS and WSL.
5. How to make hooks fail closed without self-locking.
6. The risks you see that this pack does not mention.

Please mark which of your claims rest on this pack and which on outside knowledge.
