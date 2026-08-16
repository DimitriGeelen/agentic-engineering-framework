# T-3047 — Triage batch 5 (M-05, M-10, M-15, M-20, M-25, M-30, M-35)

Read-only triage of recovered upstream bug reports against current framework code
(HEAD = `e7f93adbf`, branch `t2539-staging`, 2026-08-17). No source, task, or
`.context/` file was modified.

## M-05 — LIVE

- **defect:** Seven findings from ring20's T-711 AEF upgrade/test run; the still-live
  one is F-2 — `fw test all` runs `bats tests/unit/` with no directory guard, so
  vendored consumers that ship no `tests/` dir get a hard bats ERROR instead of a skip.
- **evidence:** `bin/fw:8612-8615` (the `all` branch) is `if command -v bats …; then
  bats "$FRAMEWORK_ROOT/tests/unit/"` — no `[ -d ]` / `ls *.bats` test, unlike its three
  siblings: integration `bin/fw:8650`, governance `bin/fw:8659`, lint `bin/fw:8668`, all
  of which guard with `[ -d … ] && ls …/*.bats >/dev/null 2>&1`. Same gap in the
  `unit` subcommand at `bin/fw:8489`. Behaviour confirmed:
  `bats /opt/999-Agentic-Engineering-Framework/tests/nonexistent-dir/` →
  `ERROR: Test file "…" does not exist.` / `not ok 1 bats-gather-tests`.
  Other findings in the same message are no longer reproducible: F-1 (`fw upgrade`
  no-op in vendored mode) now has a three-leg upstream-resolution + clone path
  (`lib/upgrade.sh:831-861`, `--from-upstream` / `.framework.yaml upstream_repo:` /
  `.agentic-framework/.upstream` sentinel, T-1634/T-2232); F-3/F-4 (CSRF unenforced,
  `/api/tests/run` fork-bomb) — the blanket `/api/*` exemption is gone and
  `csrf_protect` has no TESTING bypass (`web/app.py:100-130`, T-1343/G-048).
- **if LIVE:** Add the same `[ -d "$FRAMEWORK_ROOT/tests/unit/" ] && ls
  "$FRAMEWORK_ROOT/tests/unit/"*.bats >/dev/null 2>&1` guard to both the `all` leg
  (`bin/fw:8613`) and the `unit` leg (`bin/fw:8489`). No task in `.tasks/active/` and no
  entry in `.context/concerns.yaml` mentions the missing unit-dir guard (grepped both).

## M-10 — FIXED

- **defect:** `lib/episodic.sh` stripped only the opener/closer lines of an HTML comment,
  so the `## Decisions` template's *interior* placeholder lines (`### [date] — [topic]`,
  `- **Chose:** …`) leaked into every generated episodic as fake decisions.
- **evidence:** The line-by-line filter no longer exists. `agents/context/lib/episodic.sh:133-145`
  now delegates to `extract_decisions.py` with an explicit comment naming this exact defect
  ("it filtered the comment DELIMITERS but not the comment INTERIOR (so the template's own
  `[what was decided]` placeholders were emitted as real decisions — 77% of episodics in
  this tree) … Reported by 050-email-archive, reproduced independently by 832 at 81%"),
  shipped under T-3015 and pinned by `tests/unit/test_extract_decisions.py` (file present).
  Emitter side reads the extractor's YAML whole (`agents/context/lib/episodic.sh:329-340`).
  The canonical structural rule now lives in `lib/comment_strip.py:1-30` (T-2954).

## M-15 — NOT-OURS

- **defect:** None in this framework — it is a request to install an ed25519 deploy key for
  the `claude-collective` OneDev project (ID 38) on host .122, so a cohort agent can
  `git push` its local tree. Infrastructure/credential handoff, no framework code path.
- **evidence:** Message body (`docs/reports/T-3047-recovered-upstream-messages.md:322-357`)
  names only OneDev at `192.168.10.201:6611`, `instance/secrets/onedev_ed25519` on .107, and
  cross-hub federation breakage — no file in this repo. Tracked task ids cited are the
  senders' own (`T-209` cohort side, `T-699` ring20 side), not framework tasks.

## M-20 — FIXED

- **defect:** `fw upgrade` step [5/10] announced "UPDATED Hooks regenerated (missing N
  hook(s): …)" while the write silently no-op'd — `settings.json` and `.bak` came out
  byte-identical and the announced hooks were absent.
- **evidence:** `lib/upgrade.sh:1640-1690` now (a) re-runs the hook analysis *after* the
  write (`hook_analysis_after` → `missing_count_after` / `stale_after` /
  `nonportable_after`, `lib/upgrade.sh:1650-1656`), and (b) byte-compares pre vs post with
  `cmp -s "$_t2912_pre" "$settings_file"` (`lib/upgrade.sh:1658`, T-2912). The exact
  reported outcome is now `FAILED  Regeneration made no change; still $reason …`
  (`lib/upgrade.sh:1667`) with `failed_steps` incremented; a partial write degrades to
  `PARTIAL  Hooks regenerated but gap remains: missing N hook(s): …`
  (`lib/upgrade.sh:1681`). `UPDATED` (`lib/upgrade.sh:1689`) is now reachable only when the
  file actually changed AND the post-write re-scan finds no gap — precisely the
  "suggested fix shape" in the report.

## M-25 — FIXED

- **defect:** Two claimed `fw audit` false-positive classes — (1) "Commit X references
  non-existent task Y" firing for tasks that exist in `.tasks/completed/`, hypothesised as
  an `active/`-only existence scan; (2) "CTL-012: Completed task T-XXX has unchecked AC"
  firing on tasks with no unchecked checkbox.
- **evidence:** (1) The existence check is not `active/`-scoped: `agents/audit/audit.sh:2478`
  is `task_file=$(find "$TASKS_DIR" -name "${task_ref}-*.md" -type f …)` with
  `TASKS_DIR=$PROJECT_ROOT/.tasks` (`lib/paths.sh:17`) — a recursive find over both
  subdirectories. Confirmed: `find .tasks -name 'T-001-*.md' -type f` →
  `.tasks/completed/T-001-define-success-metrics.md`. The described cause is not present in
  the code and the contradiction does not reproduce. (2) The CTL-012 scanner is scoped to the
  `## Acceptance Criteria` block, requires a line-anchored `^- \[ \]`, excludes `### Human`,
  and filters prose-DEFERRED scope-cut markers
  (`agents/audit/completed-task-scan.py:203-251`, T-2202 shipped 2026-06-13 — two days
  after this report — plus the T-2385 grandfather cutoff). Live run over this repo's
  completed corpus: `python3 agents/audit/completed-task-scan.py .tasks .context/episodic
  docs/reports` → `unchecked_ac count: 4` (T-436, T-678, T-2494, T-2389), every one a real
  unticked AC line; zero false positives.

## M-30 — NOT-OURS

- **defect:** None — it withdraws/supersedes a previously relayed production-deploy approval
  (`ring20-prod-deploy-gate §4.B`, chat-arc offset 2282) because the operator had already
  deployed via direct Run Job. Pure coordination message about a consumer's deploy gate.
- **evidence:** Message body (`docs/reports/T-3047-recovered-upstream-messages.md:1148-1154`)
  references only `https://workshop-designer.geelenandcompany.com/`, commit `afca835`, and
  wd-agent's own commit freeze. No framework file, command, or gate is named; nothing in this
  repo implements `ring20-prod-deploy-gate`.

## M-35 — NOT-OURS

- **defect:** Capability drift on the ring20-dashboard *TermLink hub* (192.168.10.121:9100)
  — no WS upgrade endpoint (arc-004 push), no `inbox.queued` aggregator topic, no
  `hub.governor_status` RPC — because that hub runs a divergent termlink fork lineage.
- **evidence:** All three rails are TermLink-binary surfaces, not framework code: the hub is
  a `termlink` build reporting `0.11.806` on its own fork
  (`docs/reports/T-3047-recovered-upstream-messages.md:1258-1268`), and the remedy the sender
  asks for is "rebuild/upgrade the dashboard hub from the shared termlink lineage". Per
  CLAUDE.md §TermLink Integration, TermLink is a machine-wide binary installed via
  Homebrew/cargo from `https://github.com/DimitriGeelen/termlink` — deliberately outside this
  repo. Per §Gap Homing (T-1333) the fix homes in the TermLink repo, not here.
