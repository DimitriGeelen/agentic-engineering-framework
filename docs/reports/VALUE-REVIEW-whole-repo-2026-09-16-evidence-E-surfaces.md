# VALUE-REVIEW whole repo — Evidence E: surfaces (web/, tests/, docs/, Designer, TermLink)

- **Task:** T-3370 (GATHERER-E)
- **Date:** 2026-09-16
- **Scope:** `web/`, `tests/`, `docs/`, Workflow Designer corpus (`.context/designer/projects/`), TermLink integration points
- **Out of scope:** `bin/`, `lib/`, `agents/`, `policy/` (another gatherer has these). They were only read to answer Q5 and Q6.
- **Method:** Only static reads and greps. The one exception is Q1: the Flask `url_map` was listed by importing `web.app` in Python, without starting a server. No `fw` verbs were run. The TermLink binary calls are listed at the end.
- **Usage data:** The repo has **no per-route, per-page, per-doc or per-workflow usage data**. "Unreferenced" below means **no reference was found in the repo**. It does not mean "unused".

Classification (delete/refactor/add) is **deliberately absent**. This file contains facts only.

---

## Corrections to the dispatch brief (verified)

| Brief said | Measured | Evidence |
|---|---|---|
| docs/ holds 2264 files | 2268 on disk, 2197 git-tracked | `find docs -type f \| wc -l`; `git ls-files docs \| wc -l` |
| ~47 live workflows | **16 workflows** made up of **47 `.bpmn` version files** | `ls .context/designer/projects` → 16 dirs; `git ls-files .context/designer \| grep bpmn` → 47 |
| termlink 0.11.1766 | **termlink 0.11.1716** | `termlink --version` |
| tests/ 1634 files | 1634 on disk, but **1213 git-tracked**. 409 `.pyc` files and `.pytest_cache` are untracked | `git ls-files tests \| wc -l`; `git ls-files tests \| grep -c pyc` → 0 |

---

## Q1 — Flask routes

**Total: 159 rules** (158 excluding `static`), from `app.url_map`. The source has 156 `@bp.route` and 2 `@app.route` decorators (`grep -rhoE '@[a-z_]+\.(route|…)' web`).

**How reachability was tested:** a route counts as referenced if any non-test file under `web/` (templates, JS, py) contains one of the following:
- `url_for('<endpoint>')`, or
- the literal path, with the route's own decorator line excluded, or
- the bare endpoint string. This third form is needed because `web/shared.py:136` `NAV_GROUPS` builds the nav from endpoint strings, such as `"config.config_page"` at `shared.py:187`.

The first two forms alone flagged 17 routes. Five of those (`/config`, `/embeddings`, `/escalation-drift`, `/reviewer/audit`, `/api/_identity`) are reached through NAV_GROUPS or other endpoint-string references, so they were removed from the list.

**Orphan candidates (no UI reference found in web/): 12 of 158 (7.6%).**

| Route | Endpoint | Methods | Refs outside web/ (tests) | Origin (first commit adding path) |
|---|---|---|---|---|
| `/api/bvp/driver/propose` | bvp.bvp_driver_propose | POST | 0 code refs; mentioned only in `.tasks/active/T-2332*`, `.tasks/completed/T-2330*` | 2026-06-11 T-2332 |
| `/api/fleet/status` | fleet.fleet_status_api | GET | **0 anywhere** outside `web/blueprints/fleet.py:80` | 2026-04-23 T-1206/T-1103 |
| `/approvals/continuous-state` | approvals.continuous_state_fragment | GET | **0 anywhere** outside `web/blueprints/approvals.py:911`. The docstring says it is a "fragment so the card can refresh", but no template or JS polls it | 2026-08-27 T-3200 |
| `/api/concerns` | quality.concerns_api | GET | 2 (1 test) | 2026-04-07 T-1022 |
| `/api/decisions` | discovery.decisions_api | GET | 2 (1) | 2026-04-07 T-1023 |
| `/api/learnings` | discovery.learnings_api | GET | 2 (1) | 2026-04-07 T-1023 |
| `/api/patterns` | discovery.patterns_api | GET | 2 (1) | 2026-04-07 T-1024 |
| `/api/test-summary` | quality.test_summary | GET | 4 (3) | 2026-04-07 T-1016 |
| `/api/healing/<task_id>` | session.healing_diagnose | POST | 5 (1) | 2026-02-14 T-058 |
| `/api/session/init` | session.session_init | POST | 2 (1) | 2026-02-14 T-058 |
| `/api/session/status` | session.session_status | GET | 5 (3) | 2026-02-14 T-058 |
| `/search/feedback/analytics` | discovery.feedback_analytics | GET | 4 (1) | 2026-02-24 T-267 |

Notes:
- The `/api/*` JSON endpoints were added as machine APIs (T-1016, T-1022, T-1023 and T-1024 each say "JSON API"). Having no link from a template is therefore consistent with how they were designed. Whether any external client calls them: **no usage data exists**.
- **3 routes have zero references anywhere in the repo** apart from their own decorator: `/api/bvp/driver/propose`, `/api/fleet/status` and `/approvals/continuous-state`.
- The method is a heuristic. Paths built dynamically in JS (string concatenation) could produce false "orphan" results. Of the 12, only the 3 above were spot-checked repo-wide with `grep -rln` (excluding `.git`, `.context` and `.agentic-framework`).

## Q2 — Templates

**84 templates** (`find web/templates -name '*.html'`; all 84 are git-tracked).

- **Rendered by no blueprint/py (by quoted filename):** 10. Seven of these are `_partials/*` pulled in through `{% include %}`: `arc_badge`, `badge`, `bvp_badge`, `chat_tab`, `inline_select`, `search_input`, `search_results`. The other three are listed below.
- **Included/extended by no other template:** 69. This is expected: most are page templates rendered directly.
- **Neither rendered nor included — 3:**
  - `web/templates/_stale_tasks_items.html`: referenced only by its fabric card and by `.tasks/completed/T-2785*`. Git history: T-2793 (2026-08-04) and T-3012 (2026-08-15).
  - `web/templates/_work_queue_items.html`: referenced only by its fabric card and by `.tasks/completed/T-2785*`. Git history: 2026-08-15 T-3012.
  - `web/templates/_partials/ask_answer_card.html`: referenced by its fabric card, `.tasks/completed/T-381*` and `docs/reports/T-388*`. Created 2026-03-09 (T-381), last touched 2026-03-11 (T-430).
- A dynamically built template name (such as an f-string) would not be detected. `grep -n "_items" web/blueprints/*.py web/shared.py` found no such construction.

**Static assets:** 33 git-tracked files under `web/static`. For each tracked asset, `git grep -F <basename> -- web` found at least one reference elsewhere in web/, so **0 are unreferenced**. The other 59 on-disk files are git-ignored `web/static/ux-review/*.png` screenshots.

## Q3 — Docs

| Bucket | Count (on disk) |
|---|---|
| `docs/generated/` (1275 `components/` + 13 `articles/`) | 1288 (1223 tracked) |
| `docs/reports/` total | 843 |
| — of which `docs/reports/T-[0-9]*` (per-task artefacts) | **666** |
| — of which non-T reports (`E*`, `fw-*`, `arc-*`, `VALUE-REVIEW*`, etc.) | 177 |
| `T-[0-9]*` files elsewhere in docs/ | 25 (total T-* in docs = 691) |
| `docs/screenshots/` | 18 |
| **Evergreen `.md`** (outside generated/reports/screenshots, not T-*) | **74** (list: `/tmp/gE_evergreen.txt` at run time) |

**Drift scan covered all 74 evergreen docs, not a sample.** The scan extracted every `fw <verb>` and every `bin|lib|agents|web|tests|policy|docs|.tasks|.fabric/...` path. Verbs were checked against the 103 top-level case arms of `bin/fw` (from line 5130 to the `esac` at line 10032). Paths were checked for existence.

- 62 of the 74 docs contain at least one reference. Across them, the scan found 224 distinct verb references and 211 distinct path references.
- The first pass flagged 17 docs. Manual review of each flag cleared 9 as false positives:
  - illustrative examples such as `lib/auth.ts` and a sample `.fabric/components/fw.yaml`
  - prose like "fw is …"
  - prefix fragments like `lib/bus`
  - quoted commit messages
- **Confirmed drift: 8 of 74 evergreen docs (10.8%)**:

| Doc | Dead reference(s) |
|---|---|
| `docs/plans/2026-02-14-phase4-watchtower-implementation.md` | `agents/context/lib/add-decision.sh`, `agents/resume/lib/status.sh` (neither exists; `agents/resume/` holds only `AGENT.md`, `resume.sh`) |
| `docs/plans/2026-02-14-phase4-watchtower-intelligence-design.md` | `agents/watchtower/` |
| `docs/prompts/framework-self-audit.md` | `.tasks/templates/zzz-default.md`; the actual templates are `default.md`, `inception.md` and `path-c-deep-dive.md`. **Side note:** `CLAUDE.md:459` names the same missing `zzz-default.md` |
| `docs/recovered/strand-2026-07/README.md` | `.tasks/active/T-2505-…md` (the task is now in `completed/`) |
| `docs/research/executable-workflow/architecture-c9070637.md` | `docs/designer/user-guide.md` (no `docs/designer/` dir), `docs/reports/T-027-claude-aef-review-response.md`, `docs/reports/T-027-zai-review-response.md`, `policy/profile` |
| `docs/research/executable-workflow/roadmap-5be23719.md` | `docs/architecture/executable-workflow-contract-runtime.md` (dir holds only `parallel-execution-*.md`) |
| `docs/upstream-patterns/openclaw/EVALUATION-SUMMARY.md` | `docs/reports/T-007…`, `T-008…`, `T-009…`, `T-010…` (4 reports) |
| `docs/upstream-patterns/openclaw/README.md` | `docs/reports/EVALUATION-SUMMARY.md` |

Of the 224 verb references, 0 were confirmed dead. All 13 verb flags were prose false positives.

Limitation: the scan only checks whether a verb exists. It does not validate subcommands or flags.

## Q4 — Tests

**1213 tracked files:** 744 `.bats`, about 406 `.py` and 25 `.sh`. The rest are 27 `.bpmn` fixtures plus md/json. 3 more `test_*.py` files live under `web/`.

**Tests referencing source files that no longer exist: 0 confirmed.**
- The first pass (any path-like string) flagged 86 files. Nearly all of these are synthetic fixture paths created inside the test, such as `lib/foo.sh`, or `.json` names truncated to `.js` by the regex.
- The second pass was scoped to `$PROJECT_ROOT/…` and `$FRAMEWORK_ROOT/…` path references plus Python `import web.*` / `import lib.*` over 1176 files. It flagged 14. All 14 were checked and are false positives:
  - fixture paths
  - a regex that is itself the subject of the test (`tests/governance/test_precompact_handover_robust.bats:54` greps for `agents/handover/handover\.sh`, which exists)
  - boundary-hook inputs like `lib/utils.sh`
- Limitation: dynamically built paths are not covered.

**Skips / xfail:**
- bats: 37 `skip` lines in 24 files. **All are conditional/environmental**, for example: missing shellcheck/flock/git, detached HEAD, audit lock contention, apt unreachable, or a demo transcript not yet produced (`tests/integration/test_arc010_hm_a_demo_evidence.bats:95,106,115`). **0 unconditional skips** sit at the top of an `@test`.
- pytest:
  - 75 `pytest.skip(` calls (runtime and conditional)
  - 5 `pytest.mark.skipif`
  - 1 `pytestmark =`
  - 0 `pytest.mark.skip`, other than a string inside a test fixture (`tests/unit/test_reviewer_static_scan.py:497`)
  - `web/conftest.py:50` auto-skips `framework_repo`-marked tests on consumer projects (T-1823)
- **xfail: 1 site.** `tests/playwright/test_all_routes_size.py:107` is gated on `KNOWN_OVER_CAP`, which is `{}` (line 44), so the xfail is currently dormant.

**Tests whose subject is the test tree itself** (named candidates, from filename plus grep for tests/ scanning):
- `tests/lint/bats-dead-negation.bats`
- `tests/lint/bats-silent-skip.bats`
- `tests/lint/no-orphaned-test-dirs.bats`
- `tests/lint/no-project-markers-above-bats-tmpdir.bats`
- `tests/lint/no-untracked-test-files.bats`
- `tests/unit/t3048_bats_leg_guard.bats`

That is 6 files. They lint the test suite and do not test product code. This list is UNVERIFIED as exhaustive: the grep caught only static `tests/…` scans.

Test-tree layout (on disk): unit 1045, playwright 314, integration 98, web 75, fixtures 38, lint 20, e2e 17, governance 6, spikes 4, manual 4.

## Q5 — BPMN / Workflow Designer

- **16 workflows / 47 version files** in `.context/designer/projects/`: **8 `aef-*`, 8 `draft-*`**.
  - aef: audit-cron, dispatch-loop, existing-project-onboarding, greenfield-onboarding, inception-flow, session-lifecycle, task-lifecycle, tier0-escalation
  - draft: arc-lifecycle, continuous-run-loop, exception-handling, inception-readiness, knowledge-leveling, t2584-scratch, task-creation, trigger-handling
- There are 27 more `.bpmn` files under `tests/fixtures`. The vendored self-copy `.agentic-framework/.context/designer/projects/` holds **only the 8 aef-* dirs**.
- **Ratification is a filename/id prefix only. Confirmed:** no code tests for `aef-` as a ratification check. The code keys on `draft-` instead:
  - `web/blueprints/designer.py:194` sets `is_draft`
  - `agents/designer/designer.sh:369-379` implements draft mode
  - `tools/corpus_explain.py:165` prints "rail: n/a (drafts are excluded…)"
  - `agents/audit/audit.sh:3153-3170` emits an INFO for drafts untouched for 30 days or more
- **What the prefix actually changes:**
  1. **Vendoring.** `bin/fw:580-622` ships every map except `draft-*` to consumers. It is written as "include everything minus drafts", so any non-draft map is vendored, whether or not it is aef-*.
  2. **Display.** A DRAFT badge appears in the `/designer` gallery (`designer_landing.html:105`).
  3. **Lint/explain.** Drafts are excluded from the lint baseline and from explain.
  4. **Stale-draft INFO** in the audit.
- **Gating:** no aef-* workflow **blocks** anything. The only code that names a specific ratified map is a stderr hint in `agents/task-create/update-task.sh:249-250`, which points a blocked agent at `aef-task-lifecycle` node `tl_archive`. The AC gate it sits in is implemented in shell independently of the map. Map-vs-code parity is audited by a conformance rail (T-2621, per CLAUDE.md), which is lib/agents scope and was not inspected here.
- **Dangling references in workflows: 0 confirmed.**
  - fw verbs: 68 verb mentions across the 16 workflows. The 4 flagged (`wrapper`, `is`, `exec`, `verbs`) are all prose, e.g. "bin/claude-fw is already the outer supervisor".
  - Repo paths (`bin|lib|agents|web|tools|policy/*.{sh,py,html,js,yaml}`): 0 missing.
  - Slash references: `/clear` (39) and `/compact` (5) are Claude Code built-ins. `/resume` (23) and `/review` (4) exist in `.claude/commands/`. `/approvals`, `/inception`, `/arcs`, `/tasks`, `/api` and `/audits` are Watchtower route prefixes, and `/bin` is a path fragment.

## Q6 — TermLink integration

**fw verbs that wrap termlink:**
- `fw termlink` (`bin/fw:2971` → `agents/termlink/termlink.sh:1119-1129`). Subverbs: check, spawn, exec, status, cleanup, dispatch, wait, result, update, record-outcome, help.
- Other callers of the termlink binary, found by `git grep`, excluding md and tests:
  - `bin/claude-fw` (`--termlink`)
  - `agents/context/continuous-driver.sh` (`fw continuous`)
  - `lib/reviewer/dispatch_cli.py` (`fw reviewer --dispatch`)
  - `lib/peer.py` (`fw peer`)
  - `lib/pickup.sh`, `lib/pickup-channel-bridge.sh` (`fw pickup`)
  - `lib/consumer-recover.sh` (`fw consumer-recover --via termlink`)
  - `agents/audit/*`, `agents/monitor/liveness-check.sh`, `lib/termlink_worker.py`, `lib/worker_identity.py`, `lib/templates/scripts/*` (be-reachable, recent-dm, agent-identity)
  - 4 hooks under `agents/context/check-*.sh`
- **Web surfaces calling termlink:**
  - `/api/termlink/sessions` (`web/blueprints/terminal.py:161` `termlink list --json`)
  - `/orchestrator` (`orchestrator.py:70` `termlink list --json`)
  - `/fleet` + `/api/fleet/status` (`fleet.py:40` `termlink fleet status --json --verbose --timeout 5`)
  - `/api/fleet/net-test` (`fleet.py:99` `termlink net test --json --timeout --profile`)

**Subcommands missing from installed termlink 0.11.1716: 0 confirmed.**
- `termlink --help` lists 42 top-level commands.
- Every two-word invocation found in code was probed with `termlink <a> <b> --help`. That is 23 distinct pairs, e.g. `pty inject/output`, `event emit/wait/poll`, `hub status/probe`, `remote list/exec/push/profile`, `agent inbox/contact/identity`, `channel post/create/list/claim`, `fleet status`, `net test`. All resolve.
- The 3 non-resolving pairs are prose: "fleet health" appears in the `fleet.py:1` docstring, and "hub don…" and "identity is" are also prose.
- The flags used by `fleet.py` (`--json`, `--verbose`, `--timeout`, `--profile`) all exist in the corresponding `--help` output.
- `termlink inject` (`continuous-driver.sh:294`) and `termlink attach` (`bin/claude-fw:90`) are not in the top-level help listing, but `--help` resolves for both ("Inject keystrokes into a PTY-backed session" / "Attach to a PTY session"). They are therefore accepted as hidden aliases.
- `continuous-driver.sh:60,350` documents (G-097) that `termlink inject` into a live Claude TUI exits 0 and delivers nothing. That is a behavioural gap, not a missing subcommand.

---

## Commands run (disclosure)

- **fw verbs run: none.**
- **Python:** `from web.app import app` to list `url_map`. This constructs the app but does not start a server. It printed the "FW_SECRET_KEY not set — using file key" notice.
- **termlink:** the brief allowed `termlink --help` once. More than that was run:
  - `termlink --help`, `termlink --version`
  - `termlink pty|fleet --help`
  - `termlink attach|inject --help`
  - `termlink fleet status --help`, `termlink net test --help`
  - `termlink <a> <b> --help` for 23 pairs
  - `termlink list --json` once, as an existence probe; the output was discarded
  
  All of these are read-only help/list calls.
- Everything else was `git grep`, `git log`, `find`, `grep`, `ls` and inline Python reading files.
