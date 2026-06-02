# T-1984 build dispatch — inception GO-scope traceability (G-066 structural prevention)

You are a TermLink-dispatched build worker. Parent session orchestrates from this framework repo. Standing autonomous directive: framework governance applies, commit incrementally, write to repo files directly (NOT /tmp/), report completion via fw bus.

## Task
T-1984. Run `bin/fw work-on T-1984` FIRST. Read `.tasks/active/T-1984-*.md` for full ACs.

## Spec
T-1983 (completed) GO'd the design: `.tasks/completed/T-1983-go-scope-traceability--inception-decisio.md`. Its Decisions block specifies the full design — schema, gate site, override mechanism, migration. Read this BEFORE coding.

## Template
T-1849 `arc_id:` hook is the analogue. Clone its shape:
- `agents/context/check-arc-id.py` → `agents/context/check-inception-decisions.py`
- `agents/context/check-arc-id.sh` → `agents/context/check-inception-decisions.sh` (shim that runs the .py)

## Deliverables (one commit per slice; tick the corresponding AC checkbox after each commit)
1. **Parser** — `lib/inception_decisions.py`: parses `inception_decisions:` frontmatter; validates 5 `ships_in:` shapes (file path / module.function / path::test / T-XXX / deferred:T-XXX); returns structured findings; tests at `tests/unit/test_inception_decisions_parser.py` (pytest).
2. **PreToolUse hook** — `agents/context/check-inception-decisions.py` modeled on `check-arc-id.py`. Blocks Write|Edit on `.tasks/{active,completed}/T-*.md` when `inception_decisions:` is non-empty AND parser reports errors (malformed shape / duplicate id / unresolvable referent). Override env var: `FW_ALLOW_INCEPTION_DECISIONS_DRIFT=1` (Tier-2 log). Tests: `tests/unit/check_inception_decisions_hook.bats`.
3. **Hook wire** — edit `.claude/settings.json` to register `bin/fw hook check-inception-decisions` on PreToolUse Write|Edit|MultiEdit. Edit `bin/fw` to route `hook check-inception-decisions` → `agents/context/check-inception-decisions.py`. **CRITICAL:** run `bash -n bin/fw` IMMEDIATELY after any bin/fw edit (L-408). After settings.json edit, run `bin/fw enforcement baseline` (L-398, T-1886).
4. **Close gate** — edit `agents/task-create/update-task.sh`: on `--status work-completed` for `workflow_type: inception`, parse `inception_decisions:` and refuse transition if any `ships_in:` is unreachable. Bypass: `--skip-inception-scope-trace "rationale"` flag + `FW_SKIP_INCEPTION_SCOPE_TRACE=1` env var (L-399 parity — both required). Block message: one paragraph, names failing decision id, lists both bypass mechanisms with one-line "when to pick which" guidance. Bats: `tests/unit/update_task_inception_scope_gate.bats` covering grandfathering / refusal classes / both overrides / build-child unlocks_inception_decision rejection.
5. **CLAUDE.md** — add one paragraph in §Task System (after the `arc_id` paragraph) titled "Inception GO-scope traceability" with schema example + override flag + env-var.
6. **Verify** — `tests/unit/upgrade_fresh_machine_simulation.bats` MUST still pass (T-1633). Run it before final commit.

## Governance reminders (do not skip)
- Framework rule: nothing without active task. `bin/fw work-on T-1984` first.
- Progressive AC ticking (T-1831 C-4): tick `[ ]→[x]` IMMEDIATELY when each slice's work lands. Not after-the-fact.
- Each slice = its own commit. `bin/fw git commit -m "T-1984: <slice>"`.
- Pipefail/SIGPIPE (L-387): never use `cmd | grep -q` in Verification or shell — use `out=$(cmd 2>&1); [[ "$out" == *X* ]]`.
- Bin/fw edits: `bash -n bin/fw` next tool call. ALWAYS.
- Do NOT use --force / --no-verify. Do NOT use the banned TaskCreate/EnterPlanMode tools.
- Path isolation: never edit outside the framework repo.
- AC design rule: Agent ACs are pre-decision deliverables only. Never make "decision recorded" or "if-GO X" an Agent AC — that's the gate trap fixed in T-1950.

## Reporting
- Commit incrementally. After EACH slice commit, post a one-line update to fw bus:
  `bin/fw bus post --task T-1984 --agent t1984-worker --summary "<slice-N landed: <one-liner>>"`
- On completion (all 6 slices), set status:
  `FW_SWITCH_FOCUS=1 bin/fw task update T-1984 --status work-completed`
- If gate refuses, that's the gate DOING ITS JOB on its own dogfood — investigate. Real refusal = bug in slice 4.
- If you hit a blocker you cannot resolve in 3 hypotheses (CLAUDE.md §Hypothesis-Driven Debugging), STOP and post:
  `bin/fw bus post --task T-1984 --agent t1984-worker --summary "BLOCKED: <what>" --result "<details>"`

## Success
- T-1984 task body: all 7 Agent ACs ticked
- 6 commits prefixed `T-1984:`
- `bin/fw audit` PASS (or only the pre-existing fabric edge-coverage WARN)
- Fresh-machine bats simulation still passes

Begin.
