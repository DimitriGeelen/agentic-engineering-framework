# T-1258 — learnings.yaml truncation: RCA + fix

**Status:** RESOLVED 2026-04-15T20:05Z. Root cause: `tests/unit/context_learning.bats:60-73` destroys the real framework `.context/project/learnings.yaml` on every run via `PROJECT_ROOT=$FRAMEWORK_ROOT` + `rm -f`. Fixed in-session by aliasing `FRAMEWORK_ROOT=TEST_TEMP_DIR` instead. Same bug-class in `tests/unit/context_decision.bats:60-73` fixed in same commit.

> **Note:** Sections below marked **[SUPERSEDED]** reflect two earlier (incorrect) hypotheses. Kept for audit trail. The confirmed RCA is in the **"Confirmed Root Cause (2026-04-15T20:05Z)"** section further down.

---

## Confirmed Root Cause (2026-04-15T20:05Z)

**File:** `tests/unit/context_learning.bats:60-73`

```bash
@test "add learning: creates first entry with L-001 ID in framework project" {
    rm -f "$CONTEXT_DIR/project/learnings.yaml"
    # Set PROJECT_ROOT == FRAMEWORK_ROOT to get L- prefix (framework mode)
    export PROJECT_ROOT="$FRAMEWORK_ROOT"                    # ← redirects to real framework
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$CONTEXT_DIR/project"
    local learnings_file="$CONTEXT_DIR/project/learnings.yaml"
    rm -f "$learnings_file"                                  # ← DESTROYS real framework file
    run do_add_learning "First learning"                     # ← creates fresh L-001
    ...
}
```

The test redirects `PROJECT_ROOT` to the actual framework directory to exercise the `id_prefix=L` code path (`do_add_learning` uses `PL-` prefix when `PROJECT_ROOT != FRAMEWORK_ROOT`). In doing so it operates on the real `.context/project/learnings.yaml`. The `rm -f` destroys the file, then `do_add_learning "First learning"` creates a fresh one-entry file. Cleanup restores `PROJECT_ROOT` but NOT the destroyed content.

### Reproduction (definitive)

```
$ wc -l .context/project/learnings.yaml
1709 .context/project/learnings.yaml

$ bats tests/unit/context_learning.bats -f "creates first entry with L-001 ID in framework project"
ok 1 add learning: creates first entry with L-001 ID in framework project

$ wc -l .context/project/learnings.yaml
10 .context/project/learnings.yaml   ← DESTROYED (1709 → 10)

$ head -10 .context/project/learnings.yaml
# Project Learnings - Knowledge gained during development
# Added via: fw context add-learning "description" --task T-XXX
learnings:
- id: L-001
  learning: "First learning"
  source: unknown
  task: unknown
  date: 2026-04-15
  context: Added via context agent
  application: TBD
```

Post-state matches the **exact shape** observed in commit `41264a3a` (the T-1257 truncation commit): L-001 with `learning: "First learning"`, unsorted keys starting with `id`, today's date.

### Trigger in past sessions

Any invocation of the bats unit suite that includes `context_learning.bats`:
- `fw test unit`
- `fw test all`
- `bats tests/unit/`
- `bats tests/unit/context_learning.bats`

Four truncation commits in April 2026 (`5d90f655`, `96cd1080`, `4eb23e81`, `41264a3a`) all followed test runs during completion/handover workflows. The agent did not notice; the next `git commit -a` or `git add -A` swept the destruction into version control.

### Same bug-class: context_decision.bats

`tests/unit/context_decision.bats:60-73` has an identical pattern for `decisions.yaml` — would destroy the framework's decisions.yaml on every run. Fixed in the same commit as the learnings fix.

### Why prior hypotheses were wrong

**Hypothesis 1 (original):** agents using Write/Edit tool directly on learnings.yaml — disproven; grep showed no such pattern in recent sessions, and the Write-tool path would not produce the exact format observed.

**Hypothesis 2 (session S-2026-0415-1929):** truncation during `fw task update --status work-completed` (auto-capture decisions / generate-episodic / fabric-enrich) — disproven; strace of two probe completions (T-1264, T-1266) showed the flow opens learnings.yaml O_RDONLY only. No writer touches it during completion.

Both hypotheses missed the bats test because:
- The test file contains `do_add_learning "First learning"` — matching the observed L-001 shape — but was not inspected until the third spike attempt
- Prior RCAs assumed the destruction happened in production code paths, not test code

### Fix

```bash
@test "add learning: creates first entry with L-001 ID in framework project" {
    local save_framework_root="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$TEST_TEMP_DIR"   # alias into bats temp
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$CONTEXT_DIR/project"
    local learnings_file="$CONTEXT_DIR/project/learnings.yaml"
    rm -f "$learnings_file"
    run do_add_learning "First learning"
    [ "$status" -eq 0 ]
    [[ "$output" == *"L-001"* ]]
    export FRAMEWORK_ROOT="$save_framework_root"
}
```

By aliasing `FRAMEWORK_ROOT` to `TEST_TEMP_DIR` instead of the reverse, the `id_prefix=L` branch is still taken (since `PROJECT_ROOT == FRAMEWORK_ROOT`), but all file operations land in the bats temp dir. Cleanup via `teardown() { rm -rf "$TEST_TEMP_DIR" }` correctly disposes of the test artifacts.

Same fix applied to `context_decision.bats`.

### Verification

- All 10 context_learning.bats tests pass
- All 11 context_decision.bats tests pass
- Framework `.context/project/learnings.yaml`: 1709 lines pre, 1709 lines post
- Framework `.context/project/decisions.yaml`: 24 lines pre, 24 lines post

### Follow-up (future inception — not this task)

The broader pattern `PROJECT_ROOT="$FRAMEWORK_ROOT"` in `setup()` exists in 6 other bats files:
- `tests/integration/fw_fabric.bats`
- `tests/unit/create_task.bats`
- `tests/integration/fw_harvest.bats`
- `tests/unit/update_task.bats`
- `tests/unit/verify_acs.bats`
- `tests/unit/lib_version.bats`

These overrides TASKS_DIR/other paths so are not directly destructive, but share the same design anti-pattern. A separate inception (not T-1258) should audit them for safety and propose a test_helper utility (e.g., `setup_fake_framework_root()`) that sets up a temp "framework" dir with seed files, preventing any test from pointing at the real framework.

---

## [SUPERSEDED] Hypothesis 1 — agent Write/Edit tool bypass

**Status:** Captured 2026-04-15. Fourth recurrence in 10 days. Most recent restoration (T-1257, commit `a0ed0fcd`) brought back 241 entries. Bug is NOT in `add-learning` — it's a different write path that the warning guard doesn't block.

---

## Symptom

`.context/project/learnings.yaml` has been truncated from ~1688 lines (240+ entries) down to 17-24 lines (1-2 entries) on at least four separate commits in April 2026:

| Commit | Date | Learnings after | Title |
|---|---|---|---|
| `5d90f655` | 2026-04-13 | 24 lines | "T-1239: Complete — web test regression fixed, learning captured" |
| `96cd1080` | 2026-04-14 | 17 lines | "T-1250: Fix commit-msg hook YAML shrinkage guard" |
| `4eb23e81` | 2026-04-14 | (pre-existing) | "T-012: Session handover" (inherited state) |
| `41264a3a` | 2026-04-15 | 17 lines | "T-1257: Context-aware fw path rule" |

Each was followed by a restoration commit (`7f62bcd4`, `97841b0b`, `a0ed0fcd`) manually rebuilding from git history.

## Investigation

### Ruled out: `add-learning` itself

`agents/context/lib/learning.sh do_add_learning()` uses awk to insert a new entry before the `# Candidate learnings` / `candidates:` marker, or at end-of-file if no marker (lines 68-94). It does `{ print }` on every line, preserving existing entries. awk output goes to `temp_file`, then `mv temp_file learnings_file`.

Tested: running `fw context add-learning "test"` on populated file adds one entry, preserves others.

**Verdict:** `add-learning` is NOT the truncation mechanism.

### Ruled out: `consolidate.py`

`agents/context/consolidate.py:apply_report()` DOES open learnings.yaml in write mode (line 351). But:
1. Uses `sort_keys=False` in `yaml.dump` → would preserve key order
2. Only runs when `fw consolidate apply` invoked with explicit report
3. Creates `.backup-TIMESTAMP` files when it runs (none present near truncation commits)

### Ruled out: audit/scanner/harvest

Comprehensive grep of all `.py` and `.sh` files. Every other reference to `learnings.yaml` is READ-ONLY (grep, yaml.safe_load). Only two writers exist: add-learning (append via awk) and consolidate.py (full rewrite with sort_keys=False).

### Key observation — 41264a3a truncation shape

Post-truncation L-001 has field order: `id, learning, source, task, date, context, application` with `date: 2026-04-14` (today) and `learning: "First learning"` (the default string from `lib/init.sh:294`).

Post-truncation L-002: new entry for T-1257, same 7-field order from add-learning's awk template (learning.sh:71-77).

**This tells us:**
- L-001 was REGENERATED (the `date` field is now today, not the original 2026-04-13)
- L-002 was added via add-learning (normal format)
- The 239 intermediate entries are GONE

The shape is NOT consistent with `consolidate.py` (which would keep sort_keys=False + keep all non-merged entries). It IS consistent with a **wholesale file rewrite** from scratch — as if a tool wrote out a fresh `learnings:` structure with just L-001, then add-learning appended L-002.

### Root cause — agent Write tool on learnings.yaml

**Hypothesis:** Agents (post-compact, or missing context) use the Write/Edit tool directly on `.context/project/learnings.yaml` to capture learnings, bypassing `fw context add-learning`. Without the full prior entries in context, the write overwrites the file with only what the agent currently has — typically 1-2 entries. Then add-learning may be invoked afterwards, appending one more entry on the truncated base.

**Evidence for this hypothesis:**
1. **Timing:** Truncations occur on task-completion commits — exactly when agents capture learnings at end-of-task
2. **Schema:** L-001 is regenerated to match the init.sh default ("First learning", date=today), suggesting a FRESH file creation (not incremental edit)
3. **Frequency:** 4 times in 10 days, always during agent-driven commits
4. **Recurrence after fix:** T-1250 "fixed" the shrinkage guard's `grep -c` arithmetic bug — but only made the WARN message accurate. The guard is still WARN-only (`.git/hooks/commit-msg:152`: *"Advisory only (WARN, not BLOCK) — legitimate cleanup is rare but possible"*)
5. **No code path truncates:** Comprehensive grep confirms no production shell/Python code rewrites the file with a subset of entries

**Why the existing shrinkage guard doesn't prevent this:**

`.git/hooks/commit-msg:151-172` detects >50% shrinkage and prints a WARNING, then `exit 0`. The commit proceeds. The agent sees the warning but the commit already staged the bad content; rewinding would lose the agent's other work. Net effect: advisory-only noise.

### Why agents prefer Write tool over `fw context add-learning`

Inferred from the pattern:
1. **Post-compact context loss:** After compaction, the agent doesn't remember the 240 existing entries. `add-learning` preserves them (via awk passthrough), but the agent THINKS it's starting fresh and uses Write with just the new learning.
2. **Bulk capture temptation:** When capturing multiple learnings at once, agents sometimes write the full file with their subset rather than running add-learning N times.
3. **No PreToolUse block:** Nothing structurally prevents the Write tool on learnings.yaml. All existing guards are post-commit (warn) or test-time (not hit on write).

## Structural fix

The guard must be STRUCTURAL, not advisory. Four complementary layers:

### Layer 1 (primary) — PreToolUse hook blocks Write/Edit on `.context/project/*.yaml`

New hook `.claude/hooks/block-yaml-write.sh` (or extend `check-active-task.sh`):

```bash
# If tool is Write or Edit, and target matches .context/project/{learnings,patterns,practices,decisions,gaps}.yaml
# → BLOCK with exit 2, message: "Use 'fw context add-learning' (or equivalent) instead"
```

**Why this is the right layer:** Truncation happens at WRITE TIME, not at commit. Blocking at write prevents bad staging in the first place. Agents get immediate feedback with the correct alternative. This mirrors the T-1115/T-1117 pattern (block TodoWrite et al.) — proven to work.

### Layer 2 (defence in depth) — Upgrade commit-msg shrinkage guard from WARN to BLOCK

`.git/hooks/commit-msg:152-172` and `agents/git/lib/hooks.sh` (authoritative template) — change `exit 0` to `exit 1` when >50% shrinkage detected, unless commit message contains `[learnings-cleanup]` override marker.

Rationale: Layer 1 prevents Write-tool misuse. Layer 2 catches any OTHER path we haven't discovered yet (direct edits, external scripts, manual YAML fixes). The override marker allows legitimate cleanup after consolidation.

### Layer 3 (detection) — Invariant test in CI

`tests/invariant/learnings-yaml-min-entries.bats`:
```bash
@test "learnings.yaml has at least 200 entries (T-1258 regression guard)" {
    count=$(grep -c "^- id: " .context/project/learnings.yaml)
    [ "$count" -ge 200 ] || fail "learnings.yaml has only $count entries — possible truncation (T-1258)"
}
```

Threshold: current count minus buffer. Runs on every `fw test invariant`. Same pattern as other invariant tests.

### Layer 4 (usability) — Make add-learning more attractive

- Add `--batch` mode accepting YAML fragment for multi-learning capture
- Document in CLAUDE.md §"Context Integration" that Write/Edit on `.context/project/*.yaml` is FORBIDDEN — use the CLI

## Build decomposition (post-GO)

| Task | Scope | LOC | Risk | Priority |
|---|---|---|---|---|
| **B1** | `.claude/hooks/block-yaml-write.sh` — PreToolUse hook blocking Write/Edit on `.context/project/{learnings,patterns,practices,decisions,gaps}.yaml` with clear redirect message | +60 | Low | P0 |
| **B2** | Register hook in `.claude/settings.json` PreToolUse matcher | +5 | Low | P0 |
| **B3** | `.git/hooks/commit-msg:152-172` + `agents/git/lib/hooks.sh` — change `exit 0` to `exit 1` on >50% shrinkage with `[learnings-cleanup]` override marker | +10 | Medium | P1 |
| **B4** | `tests/invariant/learnings-yaml-min-entries.bats` — invariant guard | +15 | Low | P1 |
| **B5** | CLAUDE.md §"Context Integration" — document Write/Edit ban on `.context/project/*.yaml` | +15 | Low | P2 |
| **B6** | `agents/context/lib/learning.sh` — add `--batch` flag accepting YAML fragment | +40 | Medium | P3 (usability) |
| **B7** | `tests/unit/block_yaml_write.bats` — unit test for B1 hook | +25 | Low | P1 |

**Total LOC:** ~170 added. **Time estimate:** ~2 hours for B1-B5 (P0+P1+P2).

## Recommendation

**Recommendation:** GO — see task file `## Recommendation` section for full evidence.

## Scope fence

**IN:** RCA root cause identification, four-layer structural fix, build decomposition, interim workaround.
**OUT:** Actual fix (post-GO builds), auto-recovery mechanism, migration of other YAML files.

## Dialogue log

### 2026-04-15 — RCA executed via direct investigation

TermLink dispatch was attempted first (`fw termlink dispatch --task T-1258 --name t1258-rca`) but the `claude -p` worker exited 0 with empty result.md. Note: `fw context focus T-1258` surfaced **FP-011** in the output — "fw termlink dispatch silently fails inside Claude Code — CLAUDECODE env var b..." — a known failure pattern from T-576. The worker's `run.sh` DOES include `unset CLAUDECODE` but the issue still recurs. Separate from T-1258 but worth flagging as a TermLink dispatch regression.

Fell back to direct investigation. Four commits traced, mechanism ruled out across add-learning/consolidate/audit/scanner/harvest. Root cause: agents using Write tool directly on the file. Fix is a PreToolUse hook — the same structural pattern as T-1115/T-1117 (block TodoWrite et al.) — proven to work for structural enforcement.

### 2026-04-15 — Task converted from build to inception

T-1258 was originally created as `workflow_type: build` with placeholder ACs. G-020 (Scope-Aware Task Gate) correctly blocked writing to the research artifact. Converted to `workflow_type: inception` via `fw task update T-1258 --type inception` — this is an RCA, not a build. ACs then filled with real criteria reflecting the research deliverables.
