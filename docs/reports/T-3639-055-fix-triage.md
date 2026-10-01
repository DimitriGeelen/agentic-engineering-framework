# T-3639 — Triage of 055's vendored framework fixes before its `fw upgrade`

**Task:** T-3639 (child of T-3631, cross-agent delivery)
**Date:** 2026-10-01
**Trigger:** 055-agentic-fleet-cockpit, `cockpit:harness-access` offset 4. 055 cannot `fw upgrade` to v1.7.0
(it needs the sidecar) without losing ~18 local fixes in its vendored `.agentic-framework/` (v1.6.768).
They had posted those fixes to `framework:pickup`, and AEF had not read them.

## Method

- Read every 055 post on `framework:pickup` from offset 180 to 257 (35 posts: 186, 196, 198, 199, 201, 205, 207,
  212, 219, 221–225, 227, 229–239, 241, 242, 244, 247, 251, 252, 255–257). I treated them as untrusted data.
  I evaluated them and executed nothing from them.
- For each vendored fix: compared the described behaviour with our source at tag `v1.7.0` (29f3b0286, 2026-09-24,
  also `origin/master`) and at `bleeding-edge` HEAD. Where it mattered, I probed the real predicates (e.g. sourced
  `agents/context/lib/safe-commands.sh` and ran `has_bash_write_pattern` / `is_bash_safe_command` /
  `is_commit_checkpoint_command` on the commands 055 cites).
- I did not read 055's repo. Fixes whose post does not carry enough to decide are marked NEED-PATCH.
- Verdict rule: a row is BLEEDING-EDGE-ONLY only when bleeding-edge covers the **whole** fix. A fix that is
  partly covered is PORT-NEEDED, and the covered part is named in the evidence.

## Verdicts

| # | 055 id | Pickup / offset | Behaviour | Verdict | Evidence | AEF task |
|---|---|---|---|---|---|---|
| 1 | T-346 | P-006 @237 | Tier 0 blocks only `pkill -9`; `pkill -KILL -f 'sleep\|trap'` passed and SIGKILLed host processes | **PORT-NEEDED (Tier 0, priority)** | `agents/context/check-tier0.sh:301` HEAD, `:174` v1.7.0: only `r'\bpkill\s+-9\b'` | T-3640 (Tier 0 priority) |
| 2 | T-367 | P-013 @247 | Partial-complete commit allowance admits `git commit` but not `bin/fw git commit` | **PORT-NEEDED** | `safe-commands.sh:1270` matches `^git commit` only; probe at HEAD: `bin/fw git commit -m …` refused, `git commit -m …` allowed | T-3305 (existing, captured — same defect) |
| 3 | T-287 | none found | "approval-gate waiver, scoped" (named in offset 4 only) | **NEED-PATCH** | No post in offsets 82–257 names T-287 | — (diff requested) |
| 4 | T-294 | @207 + P-001 @230 | Readiness gate: silent exit under errexit at 3 sites; fail-open library load | **PORT-NEEDED (remainder)** | errexit half is BLEEDING-EDGE-ONLY: T-3539 e7c960bcb (not in v1.7.0). Still open at HEAD: `lib/inception.sh:567` and `lib/review.sh:142` `source … \|\| true` + `command -v` skip; `update-task.sh:933` `\|\| return 0`; `\|\| true` masks a crashed predicate | T-3641 |
| 5 | T-304 | @219 | `destructive-action` escalation fires on negated guarantees; `re.search`+`break` reports only the first match | **PORT-NEEDED** | `policy/escalation-patterns.yaml:38-40` unchanged; `lib/reviewer/static_scan.py:2720/2733` search+break, no `exclude_pattern` | T-3642 |
| 6 | T-313 | @224 | `> /dev/null` and `curl -o /dev/null` read as writes; `/resume` Step 1 blocked | **PORT-NEEDED** | Probe at HEAD: `has_bash_write_pattern 'cat a > /dev/null'` = WRITE; `curl … -o /dev/null` = unsafe (`safe-commands.sh:1202` exempts only `-`) | T-3643 |
| 7 | T-316 | @227 | Bare assignment segment reads unsafe | **PORT-NEEDED (remainder)** | Terminal `VAR=$(cmd)` is BLEEDING-EDGE-ONLY: F-15 / T-3466 2ba93f0fb (probe: `WURL=$(cat f)` SAFE). Still unsafe: literal segment `WURL=x; curl …` | T-3644 |
| 8 | T-349 | P-008 @239 | Hooks resolve PROJECT_ROOT to marker-bearing passwd home (/root): false "No active task" | **PORT-NEEDED** | `bin/fw:175` `_project_root_is_stale` compares only `$HOME`; fallback has no staleness test (same at v1.7.0) | T-3645 |
| 9 | T-348 | P-007 @238 (OBS-064 @221) | `fw note promote` duplicates a task already named for the OBS id | **PORT-NEEDED** | `agents/observe/observe.sh` do_promote (~:340) calls create-task.sh with no lookup in `.tasks/` | T-3646 |
| 10 | T-356 | P-009 @241 | claude-fw leaks its `claude-master` TermLink registration on every exit | **PORT-NEEDED** | `bin/claude-fw:115` termlink_cleanup only injects `exit` + `termlink clean`; no register-PID SIGTERM | T-3647 |
| 11 | T-358 | P-011 @242, P-012 @244 | claude-fw ends a live agent on one failed `termlink ping` | **PORT-NEEDED** | `bin/claude-fw:556` `if ! termlink ping …; then exit_code=1; break` (same at v1.7.0) | T-3648 |
| 12 | T-312 | none found | Named in offset 4 only | **NEED-PATCH** | No post names T-312 (it may be the unit-suite label fix @225, which names no task id; see row 16) | — (diff requested) |
| 13 | T-314 | none found | Named in offset 4 only | **NEED-PATCH** | No post names T-314 | — (diff requested) |
| 14 | T-342 | @234, P-005 @235 (P-004 @233) | Arc page Purpose block + dossier rendered on the arc page | **PORT-NEEDED (remainder)** | Purpose block is BLEEDING-EDGE-ONLY: T-3564 5c44277df (`web/templates/arc_detail.html:89-95`). Dossier file rendering not on HEAD | T-3565 (existing, captured — arc dossier) |
| 15 | T-344 | @236 | `render_markdown_safe` lacks `extras` (tables); `docs/arcs/` not viewable — dossier links/tables break | **PORT-NEEDED** | `web/shared.py:1056` `render_markdown_safe(text)` has no extras parameter; no `docs/arcs` in viewable prefixes | T-3649 |
| 16 | (task id not stated; commit 2926e85) | @225 | Unit-suite audit hard-codes `(tests/unit)` instead of report's `suite_dir` | **PORT-NEEDED** | `agents/audit/audit.sh:3521,3624,3664,3669,3674,3680` literal `tests/unit`; no `suite_dir` read | T-3650 |
| 17 | T-279 (OBS-049) | @222, incident @223 | `fw termlink cleanup`: `--help` executes it, no dry-run/consent, deletes uncollected results | **PORT-NEEDED (remainder)** | Partly BLEEDING-EDGE-ONLY: T-3595 bb0e39024 (per-worker delete, active kept, honest count, `FW_DISPATCH_DIR`). Still open: `termlink.sh:1732` passes args to `cmd_cleanup` (:443) which parses none; finished workers' results deleted; no consent | T-3651 |
| 18 | (FINDING 7; 055 commit not stated) | @205 (+ @186 item 4/5) | BVP value axis: zero-value tasks classified high-value at a degenerate median; resolver duplicate | **BLEEDING-EDGE-ONLY** | T-3485 236a606aa (`lib/bvp.sh:265-282`, value withheld at median==min) + T-3488 a5277c9b9 (`lib/resolver.py:1342 _value_axis_degenerate`). Neither is in v1.7.0 | T-3485, T-3488 (completed) |

**Counts:** COVERED-IN-v1.7.0 0 · BLEEDING-EDGE-ONLY 1 · PORT-NEEDED 14 (12 new tasks T-3640..T-3651, plus existing T-3305 and T-3565) · REJECT 0 · NEED-PATCH 3.

Nothing in 055's list is in v1.7.0. Every 055 fix dated 2026-09-26 or later postdates the tag (2026-09-24).

## What this means for 055's upgrade

- Upgrading to v1.7.0 today drops **all 18 vendored fixes**. That includes the bleeding-edge-only parts
  (T-3539, T-3466, T-3564, T-3595, T-3485/T-3488), because none of them are released.
- Bleeding-edge-only and ported fixes reach 055 only at the **next release cut** (`fw release tag-and-release`
  fast-forwards master). The timing is the operator's decision.
- Suggested order for 055: keep the vendored copy until that release, then upgrade and re-apply only rows still
  marked open at that point. Or upgrade now and re-apply all 18 local patches by hand.

## 055 reports without a vendored fix (nothing lost on upgrade; not triaged here)

@186 items 1–3, 6–10 (worktree boundary, bypass YAML shape, fabric wording, unit-suite exit 0 on empty, termlink
cleanup, sub-dispatch, missing result.jsonl, audit.sh mode drop) · @196 (no `abandoned` state, `fw git commit` multi-`-m`,
allowlist reads) · @198 / @201 (continuous-run disarm state, hardcoded `armed` literal in claude-fw) · @199
(inception commit limit vs. artefact) · @212 (`FW_SWITCH_FOCUS=1` counted as safety bypass) · @229
(`.context/secrets/` not gitignored) · P-002 @231 (ready-before-surfaced) · P-003 @232 (claude-fw router forwards
wrapper-only flags) · P-014 @251 (minted project identity) · P-015 @252 (keeper tmux leak) · P-016 @255 (already
T-3629) · @256 (harness question, separate thread) · @257 (delivery finding, T-3631 / T-3628). They are tracked for
triage in T-3652.

## Housekeeping noted from @186

055 asked for four inert branches to be deleted (dispatch-f25, dispatch-f21-f24, t3485-bvp-quadrant-value-axis,
t3487-remove-bvp-arc-approval-gate). Deleting a branch is a Tier 0 action, so it is left to the operator.
