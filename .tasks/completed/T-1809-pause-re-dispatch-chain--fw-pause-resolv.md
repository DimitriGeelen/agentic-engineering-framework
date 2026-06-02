---
id: T-1809
name: "Pause re-dispatch chain — fw pause resolve + resolver retry_of_dispatch_id (dispatch-safety slice 5)"
description: >
  Pause re-dispatch chain — fw pause resolve + resolver retry_of_dispatch_id (dispatch-safety slice 5)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [slice-5]
components: [bin/fw, lib/pause_cli.py, lib/pause_resolve.py, lib/pause.sh, lib/resolver.py, tests/unit/test_pause_resolve.py]
related_tasks: [T-1805, T-1806, T-1807, T-1808]
arc_id: dispatch-safety
created: 2026-05-13T17:15:04Z
last_update: 2026-05-13T17:20:21Z
date_finished: 2026-05-13T17:20:21Z
---

# T-1809: Pause re-dispatch chain — fw pause resolve + resolver retry_of_dispatch_id (dispatch-safety slice 5)

## Context

Final slice 5/5 of the dispatch-safety arc. Slices 1-4 made Workers able to pause, taught the Resolver to inject the protocol, validated workflow configs, and surfaced paused dispatches to the operator. The missing piece: how does the operator's answer flow back into a re-dispatched Worker? Slice 4 baked in forward-compat for `retry_of_dispatch_id` (slice 4's `list_paused_dispatches` already filters out paused rows whose dispatch_id appears as some later row's `retry_of_dispatch_id` field). This slice writes those rows.

The chain: operator runs `fw pause resolve <dispatch_id> --answer "..."` → reads the paused row → constructs a re-dispatch through the Resolver with `retry_of_dispatch_id` set + a `pause_resolution` extra context block prepended to the rendered prompt → new dispatch row lands in dispatches.jsonl → operator-review queue deflates automatically (slice 4 helper). The new Worker reads the resolution at the top of its prompt and proceeds with operator's authoritative guidance.

Builds on [T-1805](T-1805), [T-1806](T-1806), [T-1807](T-1807), [T-1808](T-1808). Closes the dispatch-safety arc.

## Acceptance Criteria

### Agent
- [x] `lib/resolver.py:resolve()` accepts new optional kwargs `retry_of_dispatch_id: Optional[str]` and `pause_resolution: Optional[Dict[str, str]]` (with keys `question`, `answer`). When `pause_resolution` is set, `assemble_prompt` prepends a "RE-DISPATCH — operator answered your pause" block to the rendered output, BEFORE any risk-policy preamble. The block includes the original question, the operator's answer, and a directive to proceed with the answer as authoritative.
- [x] `lib/resolver.py:capture_dispatch()` already accepts `extra` — `resolve()` threads `retry_of_dispatch_id` into `extra` so the new dispatches.jsonl row carries the link.
- [x] `lib/pause_resolve.py` (new) exposes `resolve_pause(dispatch_id, answer, *, dry_run=False) -> Tuple[envelope, row]`. Reads the paused dispatch row from dispatches.jsonl, extracts task_id + task_type + original question (from terminal_event), calls `resolver.resolve()` with the retry/resolution fields populated, returns the new envelope+row.
- [x] Error path: `resolve_pause` raises `PauseResolveError` (subclass of ValueError) when (a) dispatch_id not found, (b) the dispatch's outcome is not `paused`, (c) the dispatch is already resolved (a later row already has `retry_of_dispatch_id` matching).
- [x] CLI: `fw pause resolve <dispatch_id> --answer "..." [--dry-run]` calls `resolve_pause`. Prints the new dispatch_id + retry_of_dispatch_id link. With `--dry-run`, builds the envelope but does not write to dispatches.jsonl.
- [x] CLI: `fw pause list` shows paused dispatches awaiting resolution (CLI parity with the Watchtower panel from T-1808; reuses `lib/dispatch_pause.list_paused_dispatches`).
- [x] Unit test (`tests/unit/test_pause_resolve.py`): happy path — synthetic paused row → `resolve_pause` returns new envelope with prepended RE-DISPATCH block; dispatches.jsonl gains a new row with `retry_of_dispatch_id` set; the new row's prompt block includes the answer text.
- [x] Unit test: error paths — unknown dispatch_id → PauseResolveError; non-paused dispatch → PauseResolveError; already-resolved → PauseResolveError.
- [x] Unit test (`tests/unit/test_resolver.py`): `assemble_prompt` with `pause_resolution` set → output starts with "[RE-DISPATCH — operator answered your pause]" block; block contains both question and answer text verbatim; risk-policy preamble (when `allow_pause: true`) still appears AFTER the re-dispatch block.
- [x] Unit test: `assemble_prompt` with `pause_resolution=None` → no re-dispatch block (no regression on existing dispatches).
- [x] Integration check: `bin/fw pause list` + `fw pause resolve --help` both run without traceback.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

python3 -m pytest tests/unit/test_pause_resolve.py tests/unit/test_resolver.py tests/unit/test_dispatch_pause.py -q 2>&1 | tail -5
bin/fw pause --help 2>&1 | grep -q "resolve"
python3 -c "import sys; sys.path.insert(0, 'lib'); from pause_resolve import resolve_pause, PauseResolveError; print('ok')"

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

### 2026-05-13 — CLI split into pause.sh shim + pause_cli.py
- **What changed:** Original AC said "CLI: fw pause resolve ...". Implementation split into two files: `lib/pause.sh` (thin shim, env setup, exec python) and `lib/pause_cli.py` (argparse + subcommands). This matches the existing pattern (`lib/resolver.sh` + `lib/resolver.py`, `lib/outcome.sh` + `lib/outcome.py`) and lets pause_cli.py be unit-tested directly via `from pause_cli import build_parser`. PostToolUse scope alert fired on the 4 new files — confirmed within planned scope; the shim/dispatcher split is an internal pattern, not a scope expansion.
- **Plan impact:** Added `lib/pause.sh` + `lib/pause_cli.py` to the components list, no AC change.
- **Triggered:** None.

### 2026-05-13 — RE-DISPATCH block goes ABOVE the risk-policy preamble, not below
- **What changed:** First draft put the re-dispatch block AFTER the risk-policy preamble (treating it as "additional context for the Worker"). Reconsidered: the re-dispatch block answers a question the Worker explicitly paused on, while the risk-policy preamble is generic governance. The specific, just-asked answer is higher priority — Workers reading top-down should see "your question was answered: X" before they re-read the pause protocol.
- **Plan impact:** Added a dedicated test (`test_assemble_prompt_redispatch_block_above_risk_preamble`) that pins the ordering via `out.index("[RE-DISPATCH") < out.index("[RISK POLICY")`.
- **Triggered:** None — design call resolved before commit.

### 2026-05-13 — dispatch_id prefix matching in resolve_pause
- **What changed:** AC didn't specify how to look up the paused dispatch. Operators using `fw review-queue` see 8-char prefixes (e.g. `abc12345..`). Forcing them to copy the full UUID would be friction. Added prefix matching: `>=6 chars` accepted, with an ambiguity error when more than one row matches.
- **Plan impact:** Added `test_prefix_matching` to pin the contract.
- **Triggered:** None — UX choice consistent with `fw resolver explain` which also accepts prefixes.

## Decisions

### 2026-05-13 — RE-DISPATCH block sits above the risk-policy preamble
- **Chose:** Order is `[RE-DISPATCH] → [RISK POLICY] → body` when both are present. The Worker's eyes land on the operator's answer first.
- **Why:** The answer is to a question the Worker itself asked. The risk-policy preamble is generic governance shared by every dispatch on this workflow. Specific-just-asked beats generic-always-true.
- **Rejected:** Order `[RISK POLICY] → [RE-DISPATCH] → body` — would force the Worker to re-read the pause protocol before seeing the answer to its own question. Order `body → [RE-DISPATCH] → [RISK POLICY]` (appended) — top-of-prompt is the highest-attention position.

### 2026-05-13 — pause_resolution carried via resolve()/assemble_prompt kwarg, not in workflow yaml
- **Chose:** New optional kwargs `retry_of_dispatch_id` + `pause_resolution` on `resolve()` and `assemble_prompt()`. The workflow yaml stays unchanged.
- **Why:** Pause resolution is a per-dispatch instance fact, not a per-workflow contract. Putting it in workflow yaml would conflate the two and force schema changes the linter has no use for.
- **Rejected:** $PAUSE_RESOLUTION as a substitutable variable in the prompt template — would require every prompt template to know about pause and explicitly include `$PAUSE_RESOLUTION`. Centralizing in the Resolver lets every workflow get pause support for free.

### 2026-05-13 — `--apply` flag NOT added; resolve always writes (except --dry-run)
- **Chose:** `fw pause resolve` always writes a new dispatch row unless `--dry-run`. No `--apply` two-phase option.
- **Why:** Operators already had to type the answer; making them confirm with `--apply` adds friction for the common case (their answer IS the apply). Use `--dry-run` to preview.
- **Rejected:** Two-phase `resolve` (preview) + `apply` — slow, redundant given dry-run.

## Recommendation

**Recommendation:** GO

**Rationale:** Closes the dispatch-safety arc end-to-end. With slice 5 shipped, the complete chain works: Worker emits `pause_requested` → substrate classifies as `outcome: paused` (slice 1) → operator sees the dispatch in CLI + Watchtower (slice 4) → operator runs `fw pause resolve <id> --answer "..."` (slice 5) → Resolver constructs a new dispatch with `retry_of_dispatch_id` linking back + RE-DISPATCH block prepended to the prompt → new Worker reads the operator's answer at the top of its prompt and proceeds → slice 4's helper sees the retry_of_dispatch_id and deflates the awaiting list automatically. The risk-policy preamble (slice 2) continues to teach Workers when to pause; the workflow linter (slice 3) catches typos in pause config. The arc's headline mechanic is now demonstrable: a Worker can hit ambiguity, exit cleanly, surface a question to the operator, and resume with the answer in its prompt.

**Evidence:**
- `lib/resolver.py`: `assemble_prompt` gained optional `pause_resolution` kwarg, prepends `_redispatch_preamble` block ABOVE the risk-policy preamble. `resolve()` gained optional `retry_of_dispatch_id` + `pause_resolution` kwargs, threads `retry_of_dispatch_id` into `capture_dispatch(extra=...)` so the new row carries the link.
- `lib/pause_resolve.py` (new): `resolve_pause(dispatch_id, answer)` reads paused row, validates state (not found / not paused / already resolved → `PauseResolveError`), calls Resolver with retry fields. Accepts 6+ char dispatch_id prefix with ambiguity detection.
- `lib/pause_cli.py` + `lib/pause.sh` (new): `fw pause list` / `fw pause resolve <id> --answer "..." [--dry-run]` / `fw pause resolve --json`.
- `bin/fw`: routes `pause` subcommand to `lib/pause.sh`.
- 11 new unit tests in `test_pause_resolve.py`: happy path + dry-run + prefix match + 4 error cases + 3 assemble_prompt ordering cases.
- 153 tests pass across the full dispatch-safety arc (resolver + spawn + outcome + dispatch_pause + pause_resolve + workflow_schema_pause_lint) — no regression.
- CLI smoke: `bin/fw pause --help`, `bin/fw pause list`, `bin/fw pause resolve --help` all run clean.

**Arc closeout (§ACD headline mechanic):** Worker emits `pause_requested` → operator's review queue shows the question with severity/likelihood → operator answers via `fw pause resolve` → new Worker dispatched with the answer at the top of its prompt → original paused dispatch deflates from awaiting list. Demo-evidence path: the test `test_resolve_paused_dispatch_writes_retry_row` exercises every link of the chain end-to-end against a synthetic project tree, asserting `retry_of_dispatch_id` is set, the prompt contains `[RE-DISPATCH]` + the original question text + the operator's answer, and the prompt body still follows after the preambles.

**Next steps (post-arc):** The dispatch-safety arc closes here. Open follow-ups (separate tasks, not slice 6):
- T-1804 (cross-agent conversation arc) — peer-consult substrate that lets Workers ask other Agents (not just operators) when they pause.
- Watchtower "answer this paused dispatch" form on `/review/T-XXX` — currently operators must use the CLI (`fw pause resolve`). The web UI for the resolution form is a UI-layer follow-up.

## Updates

### 2026-05-13T17:15:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1809-pause-re-dispatch-chain--fw-pause-resolv.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1bb8c119
- **Timestamp:** 2026-06-02T14:59:47Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_pause_resolve.py tests/unit/test_resolver.py tests/unit/test_dispatch_pause.py -q 2>&1 | tail -5`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw pause --help 2>&1 | grep -q "resolve"`
### 2026-05-13T17:20:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
