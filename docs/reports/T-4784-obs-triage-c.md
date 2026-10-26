# T-4784 — observation triage C (OBS-457..OBS-604)

Range: pending observations OBS-457..OBS-604 in `.context/inbox.yaml`, read 2026-10-26: **127 pending**.
Every verdict was checked against today's code, git history and task state. None rests on age alone.

| Verdict | Count |
|---|---:|
| RESOLVED | 82 |
| DUPLICATE | 27 |
| STILL-VALID | 14 |
| UNCLEAR | 4 |

52 of the 127 are sidecar retry-ladder notices ("consult … unanswered after N attempts"). From rung 5 on, the ladder files a new `fw note` on **every** attempt, with no dedupe (`lib/sidecar/retry.py:449-453`, `lib/retry_ladder.py:61-79`, up to 16 attempts). That is why the same client_msg_id shows up two or three times.
- **September rows (35):** their client_msg_ids are no longer in `.context/sidecar/awaiting-ack.jsonl`, so the ladder stopped chasing them. Verdict: RESOLVED.
- **October rows (17):** still `HUB_ACCEPTED` at attempt 12-14. Almost all are addressed to exited dispatched workers (`w44xx`), so no reply can ever come. OBS-604 carries the class; the others are DUPLICATE of it.

## Non-sidecar observations

| id | verdict | evidence | proposed action |
|---|---|---|---|
| OBS-457 | DUPLICATE | Superseded by OBS-462 (its own text says so) | dismiss → OBS-462 |
| OBS-458 | RESOLVED | T-3430 6b6fe8a68: drift gains the under-populated class (`agents/fabric/lib/underpopulated.py`) | dismiss |
| OBS-459 | RESOLVED | T-3424 completed; `.mcp.json:27` TERMLINK_RUNTIME_DIR=/var/lib/termlink; T-4722 3417b7944 resolves the runtime dir from the hub | dismiss |
| OBS-460 | RESOLVED | Moot: `ls /tmp/termlink-0` today shows only invocation-audit.jsonl and sessions, so no topic store is left to drain. T-3424 AC records the 9 shadow messages, which were never drained | dismiss (note the loss) |
| OBS-461 | RESOLVED | T-3425 completed (24bed25fd) | dismiss |
| OBS-462 | STILL-VALID | `lib/bvp.sh:502-512` still prints "blast_radius unmeasured, so no quadrant"; no provisional high-cost default | build: "BVP: unmeasured cost defaults to provisional HIGH cost instead of no quadrant" |
| OBS-463 | RESOLVED | T-3427 + T-3428 completed (spec-driven scoring), T-3547 | dismiss |
| OBS-464 | RESOLVED | T-3430 (TODO purposes 792→32, unknown subsystems 564→3), T-3435 4c61a6d29 | dismiss |
| OBS-465 | RESOLVED | `.fabric/watch-patterns.yaml:39,92` watch `tools/*.py` and `tools/*.sh` (T-1759 e9fbe48f0); `.claude/hooks` does not exist in this repo | dismiss |
| OBS-466 | DUPLICATE | T-3700 (captured). Reproduced today: `hook-enable.sh --name no-such-hook-xyz` → "registered", rc=0 | dismiss → T-3700 |
| OBS-467 | RESOLVED | T-3545 completed (244af2745) | dismiss |
| OBS-468 | RESOLVED | T-3432 completed (386938a01) | dismiss |
| OBS-469 | STILL-VALID | `web/shared.py:2403` `linkify_tasks` links only `T-\d{3,}`; OBS/G/PL/arc ids are still bare text | build: "Watchtower: linkify OBS/G/PL/arc/component ids, not only T-ids" |
| OBS-470 | STILL-VALID | Operator's model-selection ruling for fabric card work is not recorded (grep sonnet in decisions/learnings: no match) | no build task: record as a decision (`fw context add-decision`) |
| OBS-473 | RESOLVED | `agents/audit/audit.sh:3733-3735`: libs-class FAIL remedy is now "Run: fw vendor self … --check" | dismiss |
| OBS-474 | RESOLVED | Ran `tests/unit/audit_stale_arc_warning.bats` today: 7/7 ok, 54s | dismiss |
| OBS-475 | RESOLVED | Ran `tests/unit/t2230_bvp_driver_init.bats` today: 15/15 ok (94e612aad T-3604, b6bda18f7 T-4483) | dismiss |
| OBS-476 | RESOLVED | T-3438 completed (8590c21c6) | dismiss |
| OBS-477 | STILL-VALID | `agents/dispatch/preamble.md` has no "commit only named paths, never -A" rule (grep: no hits). The rule exists only in parent-written prompts | build: "dispatch preamble: workers commit only their named paths (git commit -- <paths>), never -A" |
| OBS-479 | DUPLICATE | Same class as OBS-250 (pending, range A). Null focus admits only commits and safe-list commands (`check-active-task.sh:794-822`) | dismiss → OBS-250 |
| OBS-480 | RESOLVED | Correction of OBS-478, which was dismissed 2026-10-26; the commits are on origin | dismiss |
| OBS-483 | RESOLVED | Ran `tests/unit/handover_push_timeout.bats` today: 7/7 ok (bf6928ebb T-4385) | dismiss. T-3556 (captured) also looks obsolete |
| OBS-484 | STILL-VALID | `agents/task-create/create-task.sh:572` writes `name: "$NAME"` without escaping; `agents/observe/observe.sh` promote passes raw text as `--name` | build: "create-task YAML-escapes name: so fw note promote cannot write unparseable frontmatter" |
| OBS-486 | RESOLVED | D-626/T-3445 `fw task delegate`; T-3579 reviewer-verdict ledger closes criteria without a human tick | dismiss |
| OBS-487 | RESOLVED | Ran `tests/unit/fabric_watch_pattern_fitness.bats` today: 7/7 ok (T-3443) | dismiss |
| OBS-501 | RESOLVED | `lib/release.sh:610-635`: dev branch rides the same atomic push (T-3848) | dismiss |
| OBS-502 | UNCLEAR | `agents/termlink/termlink.sh:673-680` close_state reports closed, not pushed. `preamble.md:95-105` now forbids backgrounding, which was the cause | settle: decide whether workers own the push (current prompts leave it to the parent). If so, dismiss |
| OBS-503 | DUPLICATE | T-3449 (active, partial-complete) is this exact class | dismiss → T-3449 |
| OBS-504 | UNCLEAR | No unanchored owner rewrite found: `update-task.sh:2625,2839` are anchored `^owner:`, and T-3449's name has since been repaired | settle: reproduce `fw task create --name "x owner:human y"` in a scratch project |
| OBS-505 | STILL-VALID | `agents/context/check-project-boundary.sh` states no text-only scope boundary and pins none (no T-2742 parity note) | test: "pin and document check-project-boundary's text-only scope (Tier 0 T-2742 parity)" |
| OBS-506 | DUPLICATE | L-519 (`learnings.yaml:3996`); recorded by T-3450 07f984217 | dismiss → L-519 |
| OBS-507 | RESOLVED | Works as designed: a worktree-scoped FAIL does not refuse a push (`audit.sh:943-949`, T-3125/T-3126 5c2e78f25, 2026-08-24) | dismiss |
| OBS-508 | STILL-VALID | `fw arc show ewcr-arc0-contract-evidence` today: status in-progress; arc-019 never closed | operator action, no build task: arc close review at /arcs/ewcr-arc0-contract-evidence/close |
| OBS-509 | STILL-VALID | T-2770 still `captured`, with `**Decision**: DEFER` above a rationale that argues against DEFER | operator action: re-decide T-2770 (inception) |
| OBS-510 | UNCLEAR | `fw termlink status` now shows session liveness and close state (`termlink.sh:669-681`), but no gate stops a parent from editing a task while its worker is still alive | settle: decide whether a liveness check before resume is wanted. If not, dismiss |
| OBS-511 | RESOLVED | T-3454 completed (7db1f334d) | dismiss |
| OBS-512 | RESOLVED | `bin/fw:3906-3928` smoke rc/JSON handling (T-3452 e7e8ec72a) | dismiss |
| OBS-513 | RESOLVED | T-3454 completed (7db1f334d) | dismiss |
| OBS-525 | RESOLVED | Ran `fw bvp arcs` today: rc=0 in 21s | dismiss |
| OBS-526 | RESOLVED | T-3557 (GO 2026-09-30) replaced the delegation classes; T-3853 classifier reads producer text only | dismiss |
| OBS-529 | RESOLVED | T-3462 completed (5d2e07edc) | dismiss |
| OBS-530 | DUPLICATE | T-3682 (started-work): sidecar design-conformance audit, T-3396/T-3397 spec vs built | dismiss → T-3682 |
| OBS-532 | STILL-VALID | `agents/context/lib/decision.sh` `do_add_decision` has no inception or CLAUDECODE check | build: "fw context add-decision refuses inception-scope rulings under CLAUDECODE (parity with inception decide)" |
| OBS-533 | RESOLVED | T-3464 completed (designer 0.13.0; watchdog confirmed) | dismiss |
| OBS-534 | DUPLICATE | T-3473 (captured) cites OBS-534 | dismiss → T-3473 |
| OBS-535 | RESOLVED | T-3469 completed (60ea7f91f) | dismiss |
| OBS-536 | RESOLVED | T-3562 5aa2d20e6: "GO-scope audit stops calling a mention a build" | dismiss |
| OBS-537 | RESOLVED | T-3479 32f1ca21b: sidecar dual-reads the V9 address; `lib/project_identity.sh` calls aef_* | dismiss |
| OBS-538 | RESOLVED | `agents/context/lib/safe-commands.sh:2506-2557` admits the gate's remedy args incl. `--horizon` (T-3454) | dismiss |
| OBS-539 | RESOLVED | T-3495 completed (2e75b6502) | dismiss |
| OBS-540 | DUPLICATE | Parked as T-3500 (captured, later) | dismiss → T-3500 |
| OBS-542 | DUPLICATE | OBS-250 class. `update-task.sh:3212` still prints the fix-learned hint after the close nulls focus | dismiss → OBS-250 |
| OBS-543 | STILL-VALID | `check-active-task.sh:1136-1146` refuses everything, including the commit, when focus is `captured`; the T-3179/T-4182 exemptions do not cover it | build: "admit the commit that records a park (--horizon later demotes the focused task to captured)" |
| OBS-544 | STILL-VALID | `lib/watchtower-staleness.sh:152` scans only the `web/` tree | build: "fw watchtower current also compares the lib/ modules Watchtower imports" |
| OBS-545 | RESOLVED | T-3516 completed ("close OBS-545" in its name) | dismiss |
| OBS-546 | RESOLVED | T-3516 fbec7c3eb: import-allowlist rail | dismiss |
| OBS-547 | RESOLVED | `lib/arc.sh:850` `FW_REQUIRE_ARC_CLOSE_APPROVAL:-1` default-on; T-3510 + T-3511 prevention | dismiss |
| OBS-550 | RESOLVED | Ran `tests/unit/t3095_audit_branch_hygiene.bats` today: 12/12 ok | dismiss |
| OBS-551 | STILL-VALID | `agents/git/lib/parked-merge-guard.sh:36-46` documents the fast-forward gap as NOT GUARDED | build: "guard fast-forward merges of parked branches (reference-transaction hook)" |
| OBS-554 | RESOLVED | Ran `tests/unit/t3039_write_set_implicit.bats` today: 7/7 ok (5642d889f T-3604) | dismiss |
| OBS-555 | DUPLICATE | T-3518 (captured, sovereign): parks 010-termlink's T-3062 persistence answer | dismiss → T-3518 |
| OBS-556 | DUPLICATE | Corrected by OBS-557 | dismiss → OBS-557 |
| OBS-557 | RESOLVED | T-3529 3cae24259: dispatch-wait signal fixed | dismiss |
| OBS-558 | RESOLVED | `lib/arc.sh` set-scoped-weight is reviewer-gated now; the §ACD refusal is only the override path (comment block ~L1963-1985) | dismiss |
| OBS-559 | STILL-VALID | `lib/arc-driver-review.sh:124-127` still returns `False, "handler table unreadable (…)"`, a scorable FAIL rather than a tooling error | build: "arc driver reviewer reports estimator load errors as tooling errors, not driver-quality FAIL" |
| OBS-560 | RESOLVED | T-3528 completed (87db7ce60) | dismiss |
| OBS-564 | RESOLVED | Same test as OBS-550: 12/12 ok today | dismiss |
| OBS-565 | RESOLVED | T-3546 dba716379: P-011 reports the zero | dismiss |
| OBS-566 | RESOLVED | Prevention landed (T-3546). The 399 historical closes are an audit fact, not open work | dismiss |
| OBS-568 | DUPLICATE | T-3555 (captured, next): refusal ledger | dismiss → T-3555 |
| OBS-569 | RESOLVED | T-3550 beb0eea16: killed push resolved against the remote | dismiss |
| OBS-570 | RESOLVED | Same as OBS-483: 7/7 ok today | dismiss |
| OBS-573 | RESOLVED | `agents/context/checkpoint.sh:293-310` (T-4004): a push cut off by the 60s bound is retried detached with timeout 1800 | dismiss |
| OBS-574 | RESOLVED | `lib/sidecar/dm.py:178,232` own-key rails (T-4311, T-4531 10adf6152); T-3558 completed | dismiss |
| OBS-576 | RESOLVED | Ran `tests/unit/t3099_go_scope_structural.bats` today: 12/12 ok (T-3562) | dismiss |

## Sidecar retry-ladder notices

| id | verdict | evidence | proposed action |
|---|---|---|---|
| OBS-488..OBS-500 (13) | RESOLVED | client_msg_ids (0c3b30af, 6ad47880, d6336d2f, 0d7cf3a7, 7faa72e5, 8ef41fcf, c91c5585, f05b4a16, a8717ecc, b557900e, e6316141, a2318830, 92601532) are absent from `awaiting-ack.jsonl` today | dismiss |
| OBS-514..OBS-524 (11) | RESOLVED | Attempt-12 repeats of the rows above, plus 7b0c01ef; none is in the ack ledger today | dismiss |
| OBS-527, OBS-528, OBS-531 | RESOLVED | Attempt-12 repeats (e6316141, a2318830, 92601532); not in ledger | dismiss |
| OBS-541, OBS-548, OBS-549, OBS-552, OBS-553 | RESOLVED | d2360e35, 34830410, 4ea91975, c929ec8f: not in ledger | dismiss |
| OBS-561, OBS-562, OBS-563 | RESOLVED | Attempt-12 repeats of 34830410, 4ea91975, c929ec8f; not in ledger | dismiss |
| OBS-588..OBS-592 (5) | DUPLICATE | Attempt-11 rows for b6613b3d, d7ecf1ff, de779709, c247c1e8, dc094f4a; repeated at attempt 12 by OBS-600..OBS-604 | dismiss → OBS-604 |
| OBS-593, OBS-595..OBS-603 (10) | DUPLICATE | Ledger rows HUB_ACCEPTED at attempt 12, addressed to exited dispatched workers (w4485, w4491, w4488, w4499, w4439v3*, w4526, w4531). Nobody is left to answer them | dismiss → OBS-604 |
| OBS-594 | UNCLEAR | 8c26b390 to ring20-dashboard (a real peer), conversation aef-release-v1.8.4, attempt 14, still open in the ledger | settle: check whether ring20-dashboard answered on another rail; if not, follow up by hand |
| OBS-604 | STILL-VALID | `lib/sidecar/retry.py:449-453` files one note per attempt from rung 5 (up to 6 per message, `lib/retry_ladder.py:61-79`) and keeps chasing exited dispatched workers | build: "sidecar ladder: one operator note per message, not per attempt; close rows addressed to exited dispatched workers" |
