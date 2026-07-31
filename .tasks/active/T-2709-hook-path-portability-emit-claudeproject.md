---
id: T-2709
name: "Hook path portability: emit CLAUDE_PROJECT_DIR placeholder from both generators"
description: >
  Hook path portability: emit CLAUDE_PROJECT_DIR placeholder from both generators

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-31T12:34:57Z
last_update: '2026-07-31T12:45:11Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-07-31T12:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-31T12:45:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2709: Hook path portability: emit CLAUDE_PROJECT_DIR placeholder from both generators

## Context

Build child of T-2704. Both hook generators baked the GENERATING host's absolute `fw`
path into `.claude/settings.json`, so every hook fails to resolve on any host with a
different checkout path — governance silently OFF, failing toward no-enforcement. Fixed
the generators (not the artifact) to emit `${CLAUDE_PROJECT_DIR}`, and unblinded the two
predicates that decide whether an existing consumer ever gets regenerated.

## Evidence

### A1 — heredoc survival, proven by generation not by reading

`lib/init.sh`'s SJSON heredoc is intentionally unquoted so `$fw_prefix` expands; heredoc
expansion is a single pass, so a single-quoted `${CLAUDE_PROJECT_DIR}` literal survives
verbatim. Proven by generating into a scratch dir and grepping the OUTPUT:

```
$ bash -c "source lib/init.sh && generate_claude_code_config $SC/fwrepo"
$ grep -cF '${CLAUDE_PROJECT_DIR}/bin/fw hook' $SC/fwrepo/.claude/settings.json
19
$ grep -cF "$SC" $SC/fwrepo/.claude/settings.json      # generating path leaked?
0
$ python3 -c "import json; json.load(open('.../settings.json'))"   # still valid JSON
parsed 4 events

# consumer-mode fixture (no root bin/fw)
$ grep -cF '${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook' $SC/consumer/.claude/settings.json
19
$ grep -cF "$SC" $SC/consumer/.claude/settings.json
0
```

Both branches emit the placeholder; the generating host's path appears nowhere.

### A2 — the shared predicate, and that it actually unblinds both call sites

`lib/hook_portability.py` is the single implementation. Both `bin/fw` doctor Check 6 and
`lib/upgrade.sh` step 5 shell out to it; neither reimplements the rule.

**Synthetic consumer fixture** carrying the old absolute form from a *different* host
(`/home/other-host/myproject/.agentic-framework/bin/fw hook …`, 25 commands):

```
$ python3 lib/hook_portability.py $C/.claude/settings.json | cut -d'|' -f1-3
25|25|0                       # new predicate: 25 of 25 non-portable

# the two OLD predicates, evaluated on the SAME fixture:
old stale + non_framework = 0   # => reason never fires => no regeneration
                                #    (T-2704 §5.1 "this is the trap", reproduced)

$ bin/fw upgrade $C --dry-run
[5/10] Claude Code hooks (.claude/settings.json)
  WOULD UPDATE  25 non-portable path(s) (host checkout baked in; expected ${CLAUDE_PROJECT_DIR})
```

Before: trigger blind (0). After: trigger fires with a named reason.

**Negative control** — same fixture, commands rewritten to the placeholder form:

```
$ python3 lib/hook_portability.py $C/.claude/settings.json | cut -d'|' -f1-3
25|0|0
$ bin/fw upgrade $C --dry-run
  OK  23/23 hooks present (all types matched)     # no spurious regeneration
```

**Doctor**, on this repo (still on the old form, regeneration held back):

```
$ bin/fw doctor
  WARN  Hook path portability: 25/25 hooks hardcode this host's checkout path (governance is OFF on any other host)
        Expected: ${CLAUDE_PROJECT_DIR}/bin/fw hook <name>  (absolute after expansion, host-portable)
        Run: fw upgrade (regenerates hooks from the fixed generator), then fw enforcement baseline
```

It previously printed `OK  Hook path validation: 25 hooks, all portable` over exactly
this state.

### A4 — LIVE-FIRE: the placeholder expands in a hook `command` and the hook fires

The report reached "yes, it expands" from documentation. Reading docs instead of testing
is what produced the original T-1364 false dichotomy, so this was run for real: two
scratch projects, a real `claude -p` invocation each, hook writes a marker file.

**Run 1 — placeholder as a bare script path:**

```
.claude/settings.json:
  "command": "${CLAUDE_PROJECT_DIR}/hooks/marker.sh"    (PreToolUse, matcher Bash)

$ cd /tmp/.../livefire && claude -p "Run the bash command: echo hello-livefire" \
      --permission-mode acceptEdits --allowedTools Bash
Output: `hello-livefire`

$ cat HOOK_FIRED.txt
FIRED at 2026-07-31T14:46:15+02:00
argv0=/tmp/tmp.tCpDBNSxja/livefire/hooks/marker.sh
CLAUDE_PROJECT_DIR=/tmp/tmp.tCpDBNSxja/livefire
```

**Run 2 — the EXACT framework command shape, with trailing args:**

```
.claude/settings.json:
  "command": "${CLAUDE_PROJECT_DIR}/bin/fw hook check-active-task"

$ cd /tmp/.../lf2 && claude -p "Run the bash command: echo shape-test" \
      --permission-mode acceptEdits --allowedTools Bash
Output: `shape-test`

$ cat HOOK_FIRED.txt
FIRED
argv0=/tmp/tmp.swsfU7JsHj/lf2/bin/fw
args=hook check-active-task
```

**Result: FIRED, both runs.** `argv0` is the fully-expanded absolute path — so expansion
happens in the `command` string itself (not merely `CLAUDE_PROJECT_DIR` being exported to
the process), the trailing `hook <name>` args survive intact, and the resolved path is
absolute at exec time. T-1364/T-1504's CWD-drift constraint is satisfied. The approach is
empirically confirmed, not inferred.

### Guard state change — `tests/lint/hook-paths-portable.bats`

T-2704 proved this guard RED against the current state. Watched flip:

```
### BEFORE — live .claude/settings.json (old absolute form; regeneration held back)
not ok 1 hook paths: every framework hook command uses ${CLAUDE_PROJECT_DIR}, ...
# FAIL: 25 of 25 framework hook command(s) hardcode an absolute path.
ok 2 hook paths: settings.json declares a plausible number of framework hooks
ok 3 hook paths: project-local --script registrations are not flagged (no false positive)

### AFTER — settings.json produced by the FIXED generator (scratch dir)
ok 1  ok 2  ok 3        # framework-mode: 3/3
                        # consumer-mode: 3/3
```

Stronger than T-2704's check: that used a hand-substituted fixture; this is the actual
generator's output. Test 2 passes in both directions, so the GREEN is not vacuous.

`tests/unit/hook_absolute_paths.bats` (rewritten): **5/5 ok**, including a new negative
control (test 5) that asserts the rewritten predicate still REJECTS a bare-relative
command — the T-1364 regression shape the file exists to guard.

## A2 completion — three doctor validators rejected the correct form (found at A4)

Executing A4 surfaced that A1+A2 as delivered were **half a contract**. The generator
learned the placeholder; three validators had not, and all three FAILed on the
now-correct config. Doctor emitted contradictory remedies in one run — one line saying
regenerate to *portable* paths, the next saying regenerate to *absolute* form.

| Site | Defect | Fix |
|------|--------|-----|
| `bin/fw:1133` static validator | the placeholder path matches `.endswith('/bin/fw')`, so it took the vendored branch and was joined onto PROJECT_ROOT, producing a path that cannot exist → `25/25 broken` | expand placeholder before splitting |
| `lib/doctor-hook-exercise.py` | probe runs `/bin/sh -c cmd` from `/tmp` with inherited env; placeholder expands to empty → every command becomes `/bin/fw` → `21/21 failed` | pass `CLAUDE_PROJECT_DIR` in the probe env, derived from the settings file's own location (**not** `os.getcwd()` — CWD-independence is this probe's whole purpose, T-1626) |
| `bin/fw:1714` hook-config check | literal placeholder is neither absolute nor resolvable → `fw binary not found` ×25 | expand before the isabs/join test |

Verified after fix: `OK 25 hooks, all portable` / `OK 21 hook(s) resolve from foreign CWD`
/ `OK Hook configuration valid`.

**Why this matters more than the three lines of code.** A false FAIL here is not cosmetic:
it tells the operator to "fix" a correct configuration back into non-portable absolute
paths — the exact defect T-2704 exists to remove. The gate would have actively reverted
its own fix. This is L-399 (producer/consumer parity) for the third time in one task, and
the lesson sharpens it: "wire the predicate into both call sites" was scoped to the two
sites the RCA happened to name, while three *other* consumers of hook-command strings
existed and were never enumerated. The author-time question is not "did I update both
call sites" but **"who else parses this string"**.

## Held-back supervised step

Two ACs under A4 are deliberately NOT executed. This repo's `.claude/settings.json` is
the live enforcement surface of the running session; regenerating it mid-flight would
disable the governance meant to be catching this work's own mistakes. Everything that
makes the step safe is done; the step itself is the operator's.

**A defect found while preparing it — do not run a naive regenerate.**
`generate_claude_code_config` emits **19** hooks; this repo's settings.json has **25**.
The 6 extra were added later via `fw hook-enable` and are NOT in the generator template:

| Event | Matcher | Hook |
|-------|---------|------|
| PreToolUse | `Write\|Edit` | `check-active-completed-dup` |
| PreToolUse | `Write\|Edit` | `check-arc-id` |
| PreToolUse | `Write\|Edit` | `check-heredoc-cmd-sub` |
| PreToolUse | `Write\|Edit` | `check-inception-decisions` |
| PreToolUse | `Write\|Edit` | `check-inception-schema` |
| PostToolUse | `Write\|Edit` | `check-settings-edit` |

`( force=true; generate_claude_code_config )` — the path both `fw upgrade` and any
"regenerate" verb take — would silently DROP all six. That is a pre-existing hazard in
the upgrade path (it predates this task and is orthogonal to portability), but it becomes
*reachable* here because A2 makes the regenerate trigger fire where it previously never
did. **It warrants its own task** (one bug = one task); it is not fixed here.

**Exact command sequence for the supervised step**, ordered, re-adding the six:

```
cd /opt/999-Agentic-Engineering-Framework && \
cp .claude/settings.json /tmp/settings.pre-T2709.json && \
bash -c 'source lib/init.sh && force=true generate_claude_code_config "$PWD"' && \
bin/fw hook-enable --name check-active-completed-dup --event PreToolUse --matcher 'Write|Edit' && \
bin/fw hook-enable --name check-arc-id             --event PreToolUse --matcher 'Write|Edit' && \
bin/fw hook-enable --name check-heredoc-cmd-sub    --event PreToolUse --matcher 'Write|Edit' && \
bin/fw hook-enable --name check-inception-decisions --event PreToolUse --matcher 'Write|Edit' && \
bin/fw hook-enable --name check-inception-schema   --event PreToolUse --matcher 'Write|Edit' && \
bin/fw hook-enable --name check-settings-edit      --event PostToolUse --matcher 'Write|Edit'
```

Then verify BEFORE trusting the session, in this order:

```
cd /opt/999-Agentic-Engineering-Framework && \
python3 lib/hook_portability.py .claude/settings.json | cut -d'|' -f1-3 && \
bats tests/lint/hook-paths-portable.bats && bats tests/unit/hook_absolute_paths.bats
```

Expected: `25|0|0`, then 3/3 and 5/5 green. If the count is not 25, a hook was dropped —
restore `/tmp/settings.pre-T2709.json` and stop.

Only then, and only once the above is green:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw enforcement baseline
```

The "Enforcement baseline CHANGED" FAIL between regeneration and this command is
expected (L-398), not a new defect.

**Also outstanding, not committed by this worker:** `bin/fw` and `bin/hook-enable.sh` were
edited, so the self-vendor gate will block a commit until `bin/fw vendor self` runs.

## Known-unrelated pre-existing failure

`tests/unit/test_hook_paths.py::ReanchorProjectRoot::test_noop_when_cwd_outside_any_project`
fails. Confirmed pre-existing and unrelated: it fails identically with this task's
`lib/hook_paths.py` edit stashed (that edit is docstring-only). Not fixed here — out of
scope, and one bug = one task. The other 7 tests in that file pass, as do
`t2465_reanchor_from_cwd.bats` (10/10), `lib_paths.bats` (11/11),
`t2289_paths_env_leak.bats` (5/5) and `upgrade_relative_hook_path_detection.bats` (8/8) —
so T-2465/T-2468 reanchoring is unaffected by the placeholder form, as report §8 predicted.

## Acceptance Criteria

Build child of T-2704 (GO recorded, `dc49f8c84`). Report:
`docs/reports/T-2704-hook-path-portability.md` §9. All four slices required — A1
without A2 ships a fix nothing ever invokes.

### Agent

**A1 — both generators emit the placeholder**
- [x] `lib/init.sh:617-620` (`generate_claude_code_config`) and
      `bin/hook-enable.sh:116-119` emit a SINGLE-QUOTED literal
      `'${CLAUDE_PROJECT_DIR}/bin/fw'` (framework) or
      `'${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw'` (consumer), so the
      generating shell does not expand it
- [x] Framework-vs-consumer detection logic is UNCHANGED — it still inspects the real
      filesystem (`$dir/bin/fw` + `$dir/FRAMEWORK.md`); only the emitted STRING changes
- [x] `lib/init.sh`'s heredoc quoting (SJSON) verified not to re-expand the
      placeholder early — the report names this the single most likely way to get the
      patch wrong. Prove by generating into a scratch dir and grepping the output for
      a literal `${CLAUDE_PROJECT_DIR}`, not by reading the heredoc
- [x] `bash -n` on every edited shell file (L-408: never edit `bin/fw` heredoc /
      command-substitution constructs without it)

**A2 — unblind the predicates so the fix reaches consumers**
- [x] ONE shared predicate ("hook command contains a literal absolute filesystem path
      instead of the `${CLAUDE_PROJECT_DIR}` placeholder") wired into BOTH
      `bin/fw:1160` (doctor stale-path check) and `lib/upgrade.sh:1329` (upgrade
      regenerate trigger) — not two copies (L-399 producer/consumer parity)
- [x] `fw doctor` no longer prints "all portable" when it is not — `bin/fw:1177-1178`
      claims portability only when the predicate confirms it
- [x] `fw upgrade` regenerate/stale computation FIRES on a consumer still carrying the
      old absolute form. Proven against a synthetic consumer fixture carrying that
      form, not asserted from reading the code

**A3 — correct the documentation and the false load-bearing premises**
- [x] `docs/claude-code-settings.md:108` corrected: describes the actual mechanism
      (placeholder) and records the T-496/T-498 → T-1364/T-1504 → T-2704 history so the
      next reader does not hit the same doc-vs-artifact mismatch
- [x] `lib/paths.sh:82-89` and `lib/hook_paths.py:3-13` comments rewritten — their
      premise "every framework hook is wired by MAIN's absolute path" becomes FALSE
      under A1 (in a worktree session the placeholder resolves to the worktree root)
- [x] T-2465/T-2468 tests re-run under the placeholder form; reanchoring
      (`fw_reanchor_from_cwd` / `reanchor_project_root`) still degrades to a correct
      no-op when already correctly anchored (report §8)

**A4 — empirical confirmation, then regenerate**
- [x] LIVE-FIRE: a hook registered with the `${CLAUDE_PROJECT_DIR}` form is confirmed
      to actually fire when invoked by Claude Code. The report reached this conclusion
      from documentation, not observation — the whole point of this AC is that reading
      docs is what produced the original error. Evidence pasted into this task
- [x] This repo's `.claude/settings.json` REGENERATED from the fixed generator
      (`fw git install-hooks --force` or equivalent). Not hand-edited — a hand-edit
      proves nothing about the generator's default
      **EXECUTED under supervision 2026-07-31 18:4xZ**, using the exact sequence in
      `## Held-back supervised step` (backup → regenerate → re-add the 6 non-template
      hooks). Evidence:
      - `lib/hook_portability.py` verdict went `25|25|0` → **`25|0|0`**: all 25 hooks
        preserved (no drop), zero hardcoded absolute paths.
      - `tests/lint/hook-paths-portable.bats` flipped **RED → GREEN** (3/3); it had
        failed all day with "25 of 25 framework hook command(s) hardcode an absolute
        path". `tests/unit/hook_absolute_paths.bats` 5/5 under the rewritten assertion.
      - Hooks proven to FIRE, not merely to be well-formed: counter deltas across a
        subsequent tool call — `check-active-task` 186→187, `check-tier0` 131→132,
        `budget-gate` 120→121. A resolvable-looking command that is silently skipped
        would show no delta; this is the live-verify rail, not config inspection.
      - Backup retained at `/tmp/settings.pre-T2709.json` (5435 bytes) for this session.
- [x] `fw enforcement baseline` refreshed afterwards (L-398; the "Enforcement baseline
      CHANGED" FAIL is expected here, not a new defect)
      **EXECUTED** immediately after the regeneration above, once both bats suites were
      green. `Enforcement baseline saved — Hash: f5036fad671cd769...` written to
      `.context/project/enforcement-baseline.sha256`.

**Rewritten test (A1, but called out separately because deleting it is the wrong move)**
- [x] `tests/unit/hook_absolute_paths.bats` REWRITTEN, not deleted. It currently
      asserts every command `startswith('/')` AND that the portable form is absent —
      so a correct fix turns it red. New assertion: placeholder-or-absolute-after-
      expansion, never bare relative. It still guards the real T-1364/T-1504 CWD-drift
      regression it was written for

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

bats tests/lint/hook-paths-portable.bats
bats tests/unit/hook_absolute_paths.bats
bash -n lib/init.sh
bash -n bin/hook-enable.sh
bash -n bin/fw
bash -n lib/upgrade.sh
bash -n lib/paths.sh
python3 -c "import ast,sys; ast.parse(open('lib/hook_paths.py').read())"
grep -q 'CLAUDE_PROJECT_DIR' .claude/settings.json
out=$(grep -cE '"command": "/' .claude/settings.json || true); test "$out" = "0"
out=$(bin/fw doctor 2>&1); echo "$out" | grep -qv "Hook path validation.*broken"

# T-2709 build-worker state, 2026-07-31 — block run as written, NOT weakened.
# 8 of 11 PASS. The 3 that FAIL are exactly the ones that read this repo's
# .claude/settings.json, whose regeneration is the deliberately held-back
# supervised step (see ## Held-back supervised step):
#     bats tests/lint/hook-paths-portable.bats          FAIL  (25/25 still absolute)
#     grep -q 'CLAUDE_PROJECT_DIR' .claude/settings.json FAIL
#     grep -cE '"command": "/' ... = 0                   FAIL
# All three flip GREEN on the fixed generator's output — proven in ## Evidence
# against a scratch dir. They are left failing here on purpose: passing them
# requires mutating the live enforcement surface of the running session.
# Do NOT weaken these lines; run the supervised step instead.

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

### 2026-07-31 — where the shared A2 predicate lives

- **Chose:** a new python module `lib/hook_portability.py`, shelled out to from both
  `bin/fw` doctor Check 6 and `lib/upgrade.sh` step 5.
- **Why:** both call sites are bash wrapping inline python heredocs, and both already
  carried their own copy of the *older* predicate — which is exactly why both were blind
  to the current defect. A module both sites consume makes divergence impossible rather
  than merely discouraged (L-399: a contract shipped on one side only is how this class
  recurs). It is also directly unit-testable, unlike an inline heredoc.
- **Rejected:** a bash function in `lib/` (the call sites parse JSON, so it would be a
  python heredoc inside a bash function — the same duplication one layer down);
  extending each site's existing inline python (two copies by construction).

### 2026-07-31 — what the rewritten `hook_absolute_paths.bats` asserts

- **Chose:** placeholder-OR-literal-absolute, never bare-relative — so the live (still
  absolute) settings.json and the regenerated (placeholder) one both pass, while the
  T-1364 regression shape still fails. Generator-output tests additionally assert the
  placeholder form specifically, and a new test 5 is a negative control on a
  bare-relative fixture.
- **Why:** the original assertion (`startswith('/')`) measured a *proxy* — "is it
  absolute in the file?" — for the real invariant, "does it resolve independently of
  CWD at exec time?". The proxy diverged from the invariant the moment a third form
  existed. Asserting the invariant directly means the test does not need rewriting again
  the next time the form changes. Splitting it this way also keeps the suite green
  through the held-back regeneration rather than red in the interim.
- **Rejected:** deleting the file (throws away a real 680-silent-failure regression
  guard); asserting placeholder-only (would be red until the supervised step runs, and
  would wrongly fail any legitimately-absolute project-local registration).

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-31T12:34:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2709-hook-path-portability-emit-claudeproject.md
- **Context:** Initial task creation
