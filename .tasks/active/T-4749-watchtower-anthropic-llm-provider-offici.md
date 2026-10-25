---
id: T-4749
name: "Watchtower Anthropic LLM provider (official SDK, streaming chat, model list)
  registered from the stored key"
description: >
  Operator request 2026-10-25, follow-on to T-4742: wire an Anthropic provider into
  web/llm/ next to Ollama and OpenRouter, using the key T-4742 stores (get_api_key('anthropic'),
  ANTHROPIC_API_KEY env override). Official anthropic Python SDK as an optional import;
  default model claude-opus-5-5; streaming; refusal handling.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [tests/web/test_t4749_anthropic_provider.py, 
      web/blueprints/settings.py, web/llm/anthropic_provider.py, 
      web/llm/manager.py]
related_tasks: []
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
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
created: 2026-10-24T22:14:45Z
last_update: '2026-10-25T12:00:30Z'
date_finished: 2026-10-25T11:53:40Z
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
  - ts: '2026-10-25T12:00:30Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 5
      tier: 2
      effort: 8
    rationale: blast_radius=5 (4-components-medium-blast); tier=2 
      (workflow:build); effort=8 (lines=365,acs=11)
    rubric_sha: e4a00f38e801
---

# T-4749: Watchtower Anthropic LLM provider (official SDK, streaming chat, model list) registered from the stored key

## Context

Operator request 2026-10-25, a follow-on to T-4742: wire an Anthropic provider into `web/llm/`, next to Ollama and OpenRouter, using the key T-4742 stores.

**Prior art, 1409-sprind** (sidecar 8a369c6f, `tools/externe_review.py` at their commit 4b32088af, T-2503). Theirs is a smaller, non-streaming send route, not a provider:
- Raw urllib POST to `/v1/messages` with `anthropic-version: 2023-06-01`, `max_tokens` 8192. No streaming, no thinking, no model list.
- The text blocks of the response are joined. An empty answer raises an error naming `stop_reason`; a `max_tokens` stop is logged as truncated, never silently as ok.
- The key comes from `ANTHROPIC_API_KEY`, then from the encrypted store (`get_api_key("anthropic")`). The log records which source was used, never the value.
- Tests monkeypatch `urlopen`, so no test touches the network.

What we reuse: the key order (already matched by T-4742), the never-silent truncation rule, and the no-network tests. What differs: the `LLMProvider` ABC needs streaming plus `list_models()`. Per the claude-api reference, that means the official `anthropic` SDK: `messages.stream`, `models.list`, default `claude-opus-5-5`, the server-side refusal fallback on by default, and `stop_reason == "refusal"` mapped to a `StreamChunk(type="error")`.

**Open before dispatch:** the SDK is not installed on this host. Make it an optional import (the provider reports unavailable without it, as OpenRouter does with `openai`) and add it to `web/requirements.txt`. Installing it is an operator runme.

## Acceptance Criteria

### Agent
- [x] `web/llm/anthropic_provider.py` implements `LLMProvider` with the official `anthropic` SDK, imported lazily as `openai` is in `openrouter_provider.py`. Without the SDK, `is_available()` is False with a clear reason and nothing else breaks
- [x] `chat_stream` streams through `client.messages.stream` (default model `claude-opus-5-5`, `max_tokens` 64000, `thinking: {type: "adaptive", display: "summarized"}`, `output_config.effort` left at the model default). Text deltas map to `StreamChunk("token")`, thinking deltas to `"thinking"`/`"thinking_done"`, the end to `"done"`. `stop_reason == "refusal"` or `"max_tokens"` yields a visible `"error"` chunk naming the reason, never a silent ok (1409's rule)
- [x] Server-side refusal fallback is on by default, per the claude-api skill (beta `server-side-fallback-2026-07-01` + `fallbacks: "default"`)
- [x] `list_models()` uses `client.models.list()` and returns `ModelInfo(id, display_name, "anthropic")`; on error it returns an empty list and logs the reason
- [x] `web/llm/manager.py` registers the provider when an Anthropic key resolves (`ANTHROPIC_API_KEY`, else `get_api_key("anthropic")`), and `/settings/save-key` hot-registers it on first save, as it does for OpenRouter. The key value is never logged
- [x] `anthropic` added to `web/requirements.txt`; the install itself is an operator runme, not run by the agent
- [x] Tests mock the SDK (a fake `anthropic` module in `sys.modules`) and cover: the stream mapping (text, thinking, done), refusal and max_tokens to an error chunk, models list, unavailable without SDK, and registration from env and from the store. No test touches the network
- [x] Watchtower restarted; `bin/fw watchtower current` passes; vendored copy in sync (`fw vendor self --check --task T-4749`)

### Human
- [ ] [REVIEW] A live chat through the Anthropic provider streams correctly in Watchtower
  **Steps:**
  1. Install the SDK and restart Watchtower: `bash /opt/999-Agentic-Engineering-Framework/.context/runme/anthropic-sdk/runme.sh`
  2. If no Anthropic key is stored yet, add it at http://192.168.10.107:3000/settings/ (Key Name: Anthropic)
  3. On the same page, choose Anthropic as the provider and save
  4. Open http://192.168.10.107:3000/search and ask a question in its Ask box
  **Expected:** The runme ends `RUNME EXIT 0` and prints an anthropic version. On http://192.168.10.107:3000/settings/ the Anthropic provider shows as available with models listed. On http://192.168.10.107:3000/search the answer streams in, a thinking summary may appear first, and nothing errors
  **If not:** Note the error text shown on either page. The provider reports why it is unavailable (no key, SDK missing, or the API error class and status), and `.context/runme/anthropic-sdk/run.log` shows the install
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

<!--
  Render-touching build tasks (web/templates, web/static, web/blueprints, web/shared.py,
  web/app.py …) add a section headed "Visual Verification" (level-2 heading) after
  Verification, with one checklist table — the check-visual-verification gate reads it
  at commit time (T-4213; T-4202 GO):

    | state | control | 1024 | 1440 | 1920 | note |
    |-------|---------|------|------|------|------|
    | toolbar | Load | ok | ok | ok | |

  Cells: ok / clipped / hidden / overlap / unreachable (non-ok needs a note). Each
  listed state needs screenshots at every UX_SHOT_WIDTHS width:
  fw ux shots <T-ID> <state>=<URL>. This comment is inert: the gate ignores it.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
# Build/refactor/decommission tasks with NO command here are refused. If nothing can be
# run, add the line `# verification: none — <why nothing can be run>`; it is serviced
# (queued for review: add a check / other evidence / accept). See docs/reports/T-4024-servicing-loop.md.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
#
# Vendored-path hint (T-3236, T-4419): if you edited bin/fw, lib/, agents/, policy/,
# web/, tools/ or .tasks/templates/, run `bin/fw vendor self` and add
#     bin/fw vendor self --check --task T-XXXX
# (your own task id). It checks only the files your commits changed, so another
# worker's uncommitted edit does not block your close; that drift is listed as
# "in flight, not this task". The whole-tree `--check` stays for audit/pre-push.
test -f web/llm/anthropic_provider.py
grep -q "^anthropic" web/requirements.txt
grep -q "AnthropicProvider" web/llm/manager.py && grep -q 'name == "anthropic"' web/blueprints/settings.py
python3 -m pytest tests/web/test_t4749_anthropic_provider.py tests/web/test_t4742_anthropic_key.py -q > /tmp/.t4749.out 2>&1 && grep -q passed /tmp/.t4749.out
bin/fw vendor self --check --task T-4749
bin/fw watchtower current

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

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

**Recommendation:** GO

**Rationale:** The provider is built on the official SDK, following the shapes documented in the claude-api reference: streaming, adaptive thinking shown as summaries, the server-side refusal fallback, and the model list. Refusals and truncations surface as visible errors, never as a silent ok. All tests mock the SDK, so nothing here has called the real API yet. Your live chat after the install is the first real call, and the one check left.

**Evidence:**
- Commit 2020655ee: `web/llm/anthropic_provider.py` (137 lines), registered in `web/llm/manager.py` and hot-registered on key save in `web/blueprints/settings.py`
- `tests/web/test_t4749_anthropic_provider.py`: the stream mapping, refusal and max_tokens to an error, the model list, unavailable without the SDK, and registration from the env and from the key store all pass, with no network
- Without the SDK (this host today), the provider reports "anthropic SDK not installed" and Watchtower is otherwise unaffected; `fw watchtower current` passes
- `web/requirements.txt` pins `anthropic>=1.0`. PyPI has up to 2.3.0, which the install will pick, so the live check also confirms the SDK major version

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-10-25 — stream surface: beta.messages.stream, not messages.stream
- **Chose:** `client.beta.messages.stream(..., betas=["server-side-fallback-2026-07-01"], fallbacks="default")`.
- **Why:** the claude-api skill documents `fallbacks` only on the beta messages surface (README § Refusal Fallbacks); AC 3 requires the fallback on by default, so AC 2's `messages.stream` is served by its beta counterpart. Same event types (`content_block_start/delta/stop`, `text_delta`, `thinking_delta`) and `get_final_message()`.
- **Rejected:** plain `messages.stream` without fallback (drops AC 3).

### 2026-10-25 — thinking summaries streamed regardless of the `thinking` flag
- **Chose:** always emit `thinking`/`thinking_done` chunks.
- **Why:** adaptive thinking cannot be disabled on claude-opus-5-5 (skill thinking table), and OpenRouter already streams reasoning whenever the model returns it.

### 2026-10-25 — requirements pin `anthropic>=1.0`
- **Chose:** `anthropic>=1.0` (PyPI today: 2.3.0 latest).
- **Why:** the skill's Python reference is the 1.x surface (no temperature/top_p/top_k; beta fallbacks). It names no exact release that introduced `fallbacks="default"`, so the floor is the documented major; the operator installs latest. Not installed by the agent.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-24T22:14:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4749-watchtower-anthropic-llm-provider-offici.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d05361c5
- **Timestamp:** 2026-10-25T11:53:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Human)** — [REVIEW] A live chat through the Anthropic provider streams correctly in Watchtower
  - **human-ac-mechanical-signal** (partial, heuristic) — `matched='EXIT 0' in Expected: The runme ends `RUNME EXIT 0` and prints an anthropic version. On http://192.168.10.107:3000/settings/ the Anthropic provider shows as avail`
- **AC#3 (Human)** — [REVIEWER] Block message names both bypass mechanisms
  - **reviewer-prose-mismatch** (partial, heuristic) — `matched='reads' in: Verdict: PASS; no findings on `block-message-completeness``

### 2026-10-25T11:53:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
