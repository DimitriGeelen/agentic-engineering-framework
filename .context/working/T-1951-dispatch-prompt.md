# T-1951 build dispatch — reviewer TermLink-dispatch worker (G-066 prong 3, final)

You are a TermLink-dispatched build worker. Parent orchestrates from `/opt/999-Agentic-Engineering-Framework`. Framework governance applies. Commit incrementally. Write to repo files directly (NOT /tmp/). Report completion via fw bus.

## Task
T-1951. Run `bin/fw work-on T-1951` FIRST. Read `.tasks/active/T-1951-*.md` for full ACs.

## Goal
Add `bin/fw reviewer T-XXX --dispatch` mode that spawns a TermLink session running the inline reviewer in isolation. Zero parent context cost. Same verdict shape as inline. Closes G-066 prong 3 (final of 3 — T-1984 + T-1985 already shipped).

## Substrate (DO NOT reimplement — already in place)
- `lib/termlink_worker.py` (T-1797) — `TermLinkWorker(name, prompt, ...)` class wrapping `fw termlink dispatch` for `claude -p` workers. Read it first to understand the contract.
- `lib/reviewer/static_scan.py` v1.5 — inline reviewer with auto-tick (T-1985 shipped slices 1-6). `python3 -m lib.reviewer.static_scan T-XXX` is the entrypoint.
- `bin/fw bus post --task T-XXX --agent <name> --summary "..." --result "..."` — result ledger with size gating.
- `bin/fw` reviewer routing: see lines ~2945-3010. Current dispatch: `exec python3 -m lib.reviewer.static_scan "$@"` for single-task scans.

## Architecture (the path of least resistance)

```
fw reviewer T-XXX --dispatch
        │
        ▼
bin/fw (detects --dispatch in args)
        │
        ▼
lib/reviewer/dispatch_cli.py (NEW)
        │
        ▼  (uses lib.termlink_worker.TermLinkWorker)
TermLink session: claude -p "bin/fw reviewer T-XXX && bin/fw bus post --task T-XXX --agent reviewer-dispatched --summary '<verdict-line>' --result @verdict.txt"
        │
        ▼  (writes to fw bus)
Parent reads via `bin/fw bus manifest T-XXX`
```

The worker (inside the dispatched session) runs the EXISTING inline reviewer — no recursive --dispatch.

## Deliverables (one commit per slice; tick each AC as work lands)

1. **`lib/reviewer/dispatch_cli.py`** — New module. CLI entry: `python3 -m lib.reviewer.dispatch_cli T-XXX [--timeout N] [--json]`. Imports `lib.termlink_worker.TermLinkWorker`. Build the prompt that runs inline reviewer + posts to fw bus. Spawn worker. Wait. Read result.jsonl. Surface success/failure. Refuse if `--dispatch` is detected inside the worker (env var sentinel `FW_REVIEWER_IN_DISPATCH=1` set by the prompt; module aborts if seen).

2. **`bin/fw` reviewer subcommand** — Add `--dispatch` detection. If present in args, route to `python3 -m lib.reviewer.dispatch_cli` instead of `static_scan`. Without `--dispatch`, behavior unchanged. **CRITICAL: After editing bin/fw, the very NEXT tool call MUST be `bash -n bin/fw` to catch heredoc-lockup class (3× prior incidents per CLAUDE.md memory).**

3. **Concurrency safety** — Worker session names must include task_id + short random suffix (`reviewer-T-XXX-<6char>`). fw bus channel is per-task already — no collision. Verify `.context/audits/reviewer/` writes are per-task-file (timestamped) — no shared file under parallel writes.

4. **Tests** — `tests/unit/test_reviewer_dispatch.py` with ≥5 tests:
   - (a) `--dispatch` spawns and returns without blocking parent (mock TermLinkWorker)
   - (b) parent reads verdict from fw bus after worker completes
   - (c) recursive --dispatch refused (FW_REVIEWER_IN_DISPATCH=1 → aborts cleanly)
   - (d) 3 parallel dispatches produce 3 distinct verdicts (mocked workers, fw bus has 3 envelopes)
   - (e) --dispatch against non-existent task surfaces clean error (worker reports error to fw bus, parent doesn't crash)

5. **No-regression** — Run `bin/fw reviewer T-XXX` (no --dispatch) on T-1985 — must still PASS, verdict block unchanged. Run existing `tests/unit/test_reviewer_*.py` — all green. Run `bin/fw audit` — no new FAIL classes.

6. **Docs + dogfood** — CLAUDE.md §Reviewer section: add subsection `Reviewer dispatch mode (--dispatch, T-1951)`. One paragraph on when to use (heavy parallel review, isolated context, parent budget-pressured) vs inline (single quick check). End-to-end dogfood: run `bin/fw reviewer T-1951 --dispatch` AFTER your final commit. Wait for completion. Verify `bin/fw bus manifest T-1951` shows reviewer-dispatched envelope with verdict.

## Governance reminders (do not skip)
- Framework rule: nothing without active task. `bin/fw work-on T-1951` first.
- Progressive AC ticking (T-1831 C-4): tick `[ ]→[x]` IMMEDIATELY when each slice's work lands. NOT after-the-fact.
- Each slice = its own commit. `bin/fw git commit -m "T-1951: <slice>"`.
- **`bash -n bin/fw`** immediately after EVERY bin/fw edit (3× prior lockup incidents).
- Pipefail/SIGPIPE (L-387): never `cmd | grep -q` in Verification — use `out=$(cmd 2>&1); echo "$out" | grep -q "X"`.
- Path isolation: never edit outside framework repo.
- Do NOT use --force / --no-verify. Do NOT use banned tools (TaskCreate/EnterPlanMode).
- AC design rule (T-1950): Agent ACs are pre-decision deliverables only. No "decision recorded" or "if-GO X" Agent ACs.
- Sovereignty invariant from T-1443: Human ACs are NEVER ticked. T-1985 auto-tick respects this — your `--dispatch` mode also runs the same inline reviewer, so this holds automatically.

## Reporting
- After EACH slice commit, post a one-line update to fw bus:
  `bin/fw bus post --task T-1951 --agent t1951-worker --summary "slice <N> landed: <one-liner>"`
- On completion (all 7 slices), set status:
  `FW_SWITCH_FOCUS=1 bin/fw task update T-1951 --status work-completed`
- If gate refuses, that's the gate DOING ITS JOB — investigate. Real refusal = bug.
- If blocker after 3 hypotheses: STOP and post:
  `bin/fw bus post --task T-1951 --agent t1951-worker --summary "BLOCKED: <what>" --result "<details>"`

## Success
- T-1951 task body: all 7 Agent ACs ticked + Recommendation block GO + Evidence
- 6-7 commits prefixed `T-1951:`
- `bin/fw reviewer T-1951 --dispatch` works end-to-end (dogfood)
- `bin/fw bus manifest T-1951` shows reviewer-dispatched verdict envelope
- Existing reviewer tests + audit still green
- `bash -n bin/fw` returns 0 after every bin/fw edit

Begin.
