# T-3047 — Triage of the 39 recovered upstream messages

One verdict per message, each with a file:line or command citation. Produced by five
parallel TermLink workers (`t3047-triage-1..5`), each given a disjoint slice of the
message set and forbidden from editing anything but its own batch report. Batch
reports are kept alongside this file as the unmerged evidence.

| verdict | count | meaning |
|---|---:|---|
| LIVE | 11 | the faulty code path is still present as described |
| FIXED | 8 | code changed such that the defect cannot occur; fixing commit cited |
| NOT-OURS | 20 | defect lives in a consumer, TermLink, or infra — or the message describes no defect at all |
| STALE | 0 | subject no longer exists |
| **total** | **39** | |

Nothing here was fixed by this pass. Verdicts of FIXED were reached by reading the
current code, not by trusting the report's age — the eleven LIVE findings are all
four months old and all still reproduce.

---
## M-01 — NOT-OURS
- **defect:** ring20-management's own skills MANIFEST catalogue drifted — a `generate-manifest.py` referenced by their docs never existed and per-skill manifests are sparse.
- **evidence:** Envelope names `local_gap: G-057`, `local_task: T-607`, `source_project: proxmox-ring20-management`, and artefact `.context/working/T-607/upstream-pickup-P-025.yaml`. None of those exist here: `ls .context/working/T-607` → `No such file or directory`; `find . -name "generate-manifest*"` → no results; our `G-057` (`.context/project/concerns.yaml:1500`) is an unrelated "no UI re-decide" gap. The framework's own manifest surface is `agents/mcp/manifest.py` + `agents/mcp/framework-mcp-manifest.json`, both present and unrelated to per-skill manifests. Defect lives in the ring20/150-skills-manager skill catalogue.

## M-02 — NOT-OURS

- **defect:** Watchtower's `/infra` L2 Storage layer classifies pools on `usage_percent`
  only, ignoring the `state`/`health`/`warnings` fields that ring20's `services-check.sh`
  emits, so a corrupt thin-pool renders green.
- **evidence:** the named target file does not exist in this repo and never has —
  `ls web/blueprints/infra.py` → `No such file or directory`; `git log --all --
  web/blueprints/infra.py` → empty (no history); `grep -rn storage_pools web/` → no
  matches. `web/blueprints/` holds 36 blueprints, none of them `infra`. The file is
  part of the ring20-dashboard consumer's own Flask app, not the framework's Watchtower.
  The message's own summary calls it "the framework-side consumer", but the code lives
  on the consumer.

---

## M-03 — FIXED

- **defect:** The episodic generator's `grep -v '^##'` filter greedily consumed `###` H3
  decision headings, so every decision in a task merged into one flat mapping with
  duplicate keys silently overwritten by `yaml.safe_load`.
- **evidence:** The reported commit is present in this repo —
  `git log --oneline -1 7dedefca726be9f0cadfb88e2946d785d958f53a` →
  `7dedefca7 T-1631: G-082 fix — preserve ### H3 date/topic headings in episodic decisions + post-write YAML validation`.
  The line-filter parse no longer exists at all: `agents/context/lib/episodic.sh:147`
  delegates the whole section to `extract_decisions.py`, with a comment at
  `agents/context/lib/episodic.sh:139-144` (T-3015) forbidding reintroduction of a line
  filter and naming `tests/unit/test_extract_decisions.py` as the pin. The prevention
  layer the message describes is also present: post-write `yaml.safe_load` validation
  with `exit 2` at `agents/context/lib/episodic.sh:439-448`, comment-tagged
  "T-1631 / G-082 prevention".

## M-04 — LIVE

- **defect:** Seven-finding upgrade/test-suite report from proxmox-ring20-management;
  the one still reproducing is F-2 — `fw test unit` invokes `bats` on
  `$FRAMEWORK_ROOT/tests/unit/` with no directory guard, so a vendored consumer
  that ships no `tests/unit/` gets a hard error instead of a skip.
- **evidence:** `bin/fw:8484-8492` — the bats leg is guarded only by
  `command -v bats`, and calls `bats "$FRAMEWORK_ROOT/tests/unit/"` at
  `bin/fw:8489`. The sibling legs *do* guard: pytest at `bin/fw:8496`
  (`[ -d "$FRAMEWORK_ROOT/tests/unit/" ]`), integration at `bin/fw:8517-8518`
  (`[ -d … ] && ls …*.bats`). Reproduced against this repo's own vendored copy,
  which ships `tests/integration` but no `tests/unit`:

  ```
  $ ls .agentic-framework/tests
  integration
  $ bats "$PWD/.agentic-framework/tests/unit/"; echo "exit=$?"
  ERROR: Test file "/opt/999-Agentic-Engineering-Framework/.agentic-framework/tests/unit" does not exist.
  exit=1
  ```

  Per-finding status of the rest:
  - **F-1 (fw upgrade no-op in vendored mode) — FIXED.** `lib/upgrade.sh:833-843`
    now carries the three-leg upstream resolution chain (`--from-upstream` flag →
    `.framework.yaml upstream_repo:` → `.agentic-framework/.upstream` sentinel,
    T-1634 / T-2232), and `lib/update.sh:103-149` reads `upstream_repo:` and
    clones it. The "upstream_repo not consulted" path no longer exists.
  - **F-3 (recursive fork-bomb via /api/tests/run) — FIXED by precondition
    removal.** The route still shells `fw test` with no recursion guard
    (`web/blueprints/quality.py:111-115`), but the trigger was the test-mode CSRF
    bypass, which is gone (F-4). No in-process recursion guard exists, so this
    would return if a CSRF exemption were ever re-added.
  - **F-4 (CSRF not enforced in test mode) — FIXED.** `web/app.py:102-130`
    enforces on every POST/PATCH/PUT/DELETE; the `/api/*` blanket exemption was
    removed by T-1343 / G-048 (`web/app.py:120-123`). Only `health`,
    same-origin JSON `/search/*`, and `designer_api.*` are exempt — there is no
    `TESTING`/pytest branch. Missing token → `abort(403)` at `web/app.py:130`.
  - **F-5, F-6 (subprocess monkeypatch target, stale content assertions) —
    consumer-side test drift** against a vendored snapshot; not re-verified,
    no framework code path asserted.
  - **F-7 (tantivy missing on CT 200) — NOT-OURS**, self-declared
    `severity: environmental`.
- **if LIVE:** F-2 needs one guard on `bin/fw:8489` matching the shape already
  used at `bin/fw:8496` / `8517` — skip (or report "no unit tests") when
  `$FRAMEWORK_ROOT/tests/unit/` is absent, rather than letting bats exit 1.
  No task or concern covers it: `grep -rn "tests/unit" .context/concerns.yaml`
  and a scan of `.tasks/active/` returned nothing on this guard.

---

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

## M-06 — LIVE
- **defect:** `fabric drift` reports two false-positive classes — (1) cards whose `location:` is an external `https://` URL are joined onto `$PROJECT_ROOT` and reported "file missing"; (2) `depends_on` targets under `.agentic-framework/` flagged as stale edges.
- **evidence:** Part (1) is live. `agents/fabric/lib/drift.sh:58-64` — only an absolute-path (`${loc:0:1} = "/"`) branch exists; everything else becomes `$PROJECT_ROOT/$loc` and hits `[ ! -f "$resolved" ]`. `grep -c http agents/fabric/lib/drift.sh` → `0`: no URL skip anywhere in the file. Isolated repro of that exact branch with `location: https://zoneedit.com` → `FLAGGED: saas-account-zoneedit -> https://zoneedit.com (file missing) [resolved=/tmp/m06/https://zoneedit.com]`. The T-2519 gitignore escape at `drift.sh:76` does not catch it (a URL is not gitignored).
  Part (2) is fixed: `_resolves_on_disk` (`drift.sh:122-141`) treats any relative-path-with-slash target that exists on disk as resolved, so `.agentic-framework/agents/task-create/update-task.sh` resolves and is not stale (T-2427/G-070) — this is exactly the reporter's recommended fix (2).
- **if LIVE:** the orphan-detector branch at `drift.sh:58-64` needs an `http://*|https://*` skip before the file-existence test. No task or concern covers it: `grep -rln "drift.*URL\|saas-account" .tasks/active/*.md` → no matches; no matching entry in `.context/concerns.yaml`.

## M-07 — FIXED

- **defect:** a no-terminal operator authorizing an inception GO had no decide affordance
  on `/review/T-XXX`; the clearance lived on the separate `/approvals` page (3 clicks +
  tab switch instead of 1).
- **evidence:** `web/blueprints/review.py:159-160` now 302-redirects an inception task
  away from the partial-complete surface to the class-correct one:
  `if fm.get("workflow_type") == "inception": return redirect(url_for("inception.inception_detail", task_id=task_id), code=302)`.
  That destination renders exactly the proposed form —
  `web/templates/inception_detail.html:521-529`: `<form action="/inception/{{ task_id }}/decide" method="post">`
  with GO / NO-GO radios and a required `rationale` textarea. The handler
  `web/blueprints/inception.py:495-518` (`record_decision`) does the requested single
  transaction: it writes the `.context/working/.reviewed-<task_id>` review marker (T-1120)
  *and* shells `fw inception decide <id> <decision> --rationale … --from-watchtower`
  (T-1262) in one POST. The requested capability exists; the surface is a redirect rather
  than an inline form on `/review`, which delivers the same one-click operator flow.

---

## M-08 — NOT-OURS

- **defect:** None described. This is a design proposal from ring20-management (OOB
  WebAuthn + ntfy + Watchtower approval surface) asking five questions of the framework
  agent — pattern endorsement, shared-component shape, Tier-0 hook write-format
  stability, cred-gate dir layout, audit format.
- **evidence:** Message body at `docs/reports/T-3047-recovered-upstream-messages.md:136`
  — `"msg_type":"design-proposal"`, `"asks":[...]`, `"ring20_offer":"Build cred-gate slice
  first as T-733 follow-up"`. No defect, no reproduction, no framework code path named as
  faulty. The referenced artifacts live in the consumer
  (`proxmox-ring20-management/.context/working/T-733/...`,
  `proxmox-ring20-management/docs/reports/T-733-...`).

## M-09 — NOT-OURS

- **defect:** None in this framework. This is a peer-to-peer
  `gap-cross-reference` from ring20-management to ring20-dashboard, telling that
  agent their `/review-form-with-inception-buttons` fix converges with ring20's
  own T-733/T-734 WebAuthn work, and asking three coordination questions about
  where their `/api/inception/T-XXX/decide` endpoint should land.
- **evidence:** The message self-classifies:
  `"no_action_required": "This is FYI cross-reference, not a request. Reply at
  your cadence; I'm not blocking on it."` (message body, line 168 of the recovered
  file). All three `questions_for_you` are addressed to `ring20-dashboard-agent@121`,
  not to the framework. Separately, the underlying gap it cites
  (`G-WATCHTOWER-INCEPTION-DECIDE-NO-TERMINAL-GAP` — no terminal-free path to
  record an inception decision) does not apply to this repo: the POST route
  exists at `web/blueprints/inception.py:495` and shells
  `fw inception decide … --from-watchtower` at `web/blueprints/inception.py:517`.

---

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

## M-11 — NOT-OURS
- **defect:** credential escalations raised by 150-skills-manager's `fw-authority` land in that project's queue and never appear on the consumer project's Watchtower `/approvals`, forcing a CLI workaround.
- **evidence:** `grep -rl "fw-authority" bin/ lib/ web/ agents/` → no matches; the framework has no `fw-authority` integration at all. `web/blueprints/approvals.py:85,116` globs only `APPROVALS_DIR` (`pending-*.yaml` / `resolved-*.yaml`) under this project's own `.context/`, which is correct behaviour for a per-project approval queue. The escalation record (`ESC-20260517203159-61yy`) is produced and stored by `/opt/150-skills-manager`, a different repo. The reporter's own option_a is a cross-project feature request, not a framework defect.

## M-12 — NOT-OURS

- **defect:** none in the framework — an urgent ops request to run `ntfy user add
  operator-phone` + `ntfy access` on host 192.168.10.107 and return the password.
- **evidence:** `grep -rn "ntfy user add\|operator-phone" lib/ bin/ agents/` → no matches.
  The framework's only ntfy surface is the `FW_NTFY_URL` / `NTFY_URL` config key
  (CLAUDE.md §Configuration, T-2439) which resolves a server URL; it does not provision
  ntfy accounts or ACLs. This is server administration on a ring20 host plus a credential
  handoff, with no framework code path involved.

---

## M-13 — NOT-OURS

- **defect:** None. A request to `cohort_hub` for Claude Collective brand assets (logo
  SVG/PNG, LinkedIn cover, palette spec) plus a push of those assets to the OneDev
  `claude-collective` repo.
- **evidence:** `docs/reports/T-3047-recovered-upstream-messages.md:247-263` — "Request —
  two parallel deliverables: 1) Send the Claude Collective logo + SVG source to
  ring20-manager … 2) Push the same assets to OneDev claude-collective repo". Asset
  delivery and a third-party repo; nothing in this framework repo is implicated.

## M-14 — LIVE

- **defect:** The B-005 enforcement-config gate refuses *every* write to
  `.claude/settings.json` regardless of content, so a consumer cannot add a
  purely additive project-local PreToolUse matcher (new tool target, new script,
  nothing existing modified) without an operator paste-in.
- **evidence:** `agents/context/check-active-task.sh:331-349` — the gate is a
  bare path match with no diff inspection:

  ```
  case "$FILE_PATH" in
      */settings.json)
          if echo "$FILE_PATH" | grep -q '\.claude/settings\.json$'; then
              ... echo "BLOCKED: Cannot modify .claude/settings.json ..." >&2
              exit 2
  ```

  The block fires before any content is read — the hook never parses
  `tool_input`'s new/old content, so ADD-NEW-MATCHER and
  MODIFY-EXISTING-MATCHER are indistinguishable to it. The block message quoted
  in the report ("Changes to hook configuration require human review. Policy:
  B-005 (Enforcement Config Protection)") is still emitted verbatim at
  `agents/context/check-active-task.sh:342-344`. Note the alternative route is
  also still shut: the general exempt-path block at
  `agents/context/check-active-task.sh:353-357` would exempt `$PROJECT_ROOT/.claude/*`,
  but B-005 is deliberately evaluated *before* it (comment at line 333).
- **if LIVE:** A fix would have to make B-005 content-aware — parse the proposed
  JSON, and allow only when the pre-edit matcher set is a subset of the post-edit
  set and every added `command` resolves to an existing executable inside
  `$PROJECT_ROOT` (the reporter's option_a), or introduce a separately-gated
  `.claude/hooks.local.json` merged at runtime (option_b). No task or concern
  covers it: `grep -n "settings.json" .context/concerns.yaml` returns nothing,
  and no `.tasks/` file matches "additive PreToolUse".

---

## M-15 — NOT-OURS

- **defect:** None in this framework — it is a request to install an ed25519 deploy key for
  the `claude-collective` OneDev project (ID 38) on host .122, so a cohort agent can
  `git push` its local tree. Infrastructure/credential handoff, no framework code path.
- **evidence:** Message body (`docs/reports/T-3047-recovered-upstream-messages.md:322-357`)
  names only OneDev at `192.168.10.201:6611`, `instance/secrets/onedev_ed25519` on .107, and
  cross-hub federation breakage — no file in this repo. Tracked task ids cited are the
  senders' own (`T-209` cohort side, `T-699` ring20 side), not framework tasks.

## M-16 — NOT-OURS
- **defect:** ring20-management's TermLink hub is pinned at 0.9.2127 while the fleet CLI is 0.11.1, so the doorbell+mail conversation-arc verbs and auto-heal stack are unavailable, and their heartbeat cron emits envelopes with `agent_id: null`.
- **evidence:** Every remedial step in the message targets TermLink and host systemd, not this repo: `brew upgrade termlink`, `systemctl restart termlink-hub`, `TERMLINK_RUNTIME_DIR=/var/lib/termlink`, `termlink fleet doctor`. Per CLAUDE.md §TermLink Integration, TermLink is a machine-wide binary deliberately outside the framework's per-project vendoring; the framework only wraps it via `fw termlink`. This is an infrastructure upgrade request addressed to an operator, describing no framework code defect.

## M-17 — NOT-OURS

- **defect:** none in the framework — a request that the ring20-dashboard operator upgrade
  their TermLink hub (0.9.2127 → ≥0.11.x), restart it with
  `TERMLINK_RUNTIME_DIR=/var/lib/termlink`, and run `/be-reachable`.
- **evidence:** TermLink is an external, machine-wide binary from a separate repo —
  `CLAUDE.md:1339-1340`: "**Repo:** `https://github.com/DimitriGeelen/termlink`",
  "`brew install DimitriGeelen/termlink/termlink`", and the same section states the
  machine-wide model is deliberate ("Do not propose per-project TermLink installs").
  The framework only wraps it via `fw termlink`; hub version and runtime dir are
  consumer-host operations. The referenced remediation task (T-1296) is a ring20 task,
  not a framework one.

---

## M-18 — NOT-OURS

- **defect:** None in this framework. A Discourse admin request: create a `cohort-bot`
  user, issue an API key, grant trust level 1+, confirm topic-7 posting rights. The
  observed failure is a Discourse-side `403 invalid_access`.
- **evidence:** `docs/reports/T-3047-recovered-upstream-messages.md:446` — "Live smoke
  fails: **403 invalid_access** … confirms either the key is scoped to a different user
  OR `cohort-bot` user doesn't exist on the Discourse instance". The code involved is
  the consumer's own client (`cohort_hub/discourse.py` in 002-Claude-Partner-Network);
  the fix is infrastructure admin work, explicitly scoped as "~10 minutes of Discourse
  admin work on your side. No code changes on .107 needed".

## M-19 — FIXED

- **defect:** Two defects on `fw update` to v1.6.7 from a vendored consumer —
  (1) the project-boundary hook resolved `PROJECT_ROOT` to `.agentic-framework/`
  itself, making the entire host project "outside the project"; (2)
  `fw update --rollback` reported "No rollback point recorded" while the backup
  directory sat on disk.
- **evidence:** **Defect 1** — `lib/paths.sh:40-43` (the file
  `agents/context/check-project-boundary.sh:33` sources) now detects the vendored
  case and walks up exactly as the reporter proposed:

  ```
  if [[ "$(basename "$FRAMEWORK_ROOT")" = ".agentic-framework" ]] \
     && [[ -f "$(dirname "$FRAMEWORK_ROOT")/.framework.yaml" ]]; then
      PROJECT_ROOT="$(dirname "$FRAMEWORK_ROOT")"
  ```

  Landed in commit `5a9f2baac` (2026-05-14, "T-1822: fix project-boundary
  cwd-trap in vendored .agentic-framework/"; task file
  `.tasks/completed/T-1822-fix-project-boundary-cwd-trap--vendored-.md`).
  Verified empirically against this repo's vendored copy:

  ```
  $ bash -c 'unset PROJECT_ROOT FRAMEWORK_ROOT; source ./.agentic-framework/lib/paths.sh; \
             echo "FRAMEWORK_ROOT=$FRAMEWORK_ROOT"; echo "PROJECT_ROOT=$PROJECT_ROOT"'
  FRAMEWORK_ROOT=/opt/999-Agentic-Engineering-Framework/.agentic-framework
  PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework
  ```

  The root resolves to the parent, not to `.agentic-framework` — the reported
  inversion cannot occur.

  **Defect 2** — `lib/update.sh:250-255`: `_do_rollback` keys on *directory
  existence* at the resolved root (`local rollback_dir="$project_root/.agentic-framework.rollback"`;
  `if [ -d "$rollback_dir" ]`), not on an in-process state file. The "No rollback
  point recorded" string at `lib/update.sh:288` is only reachable on the
  git-based legacy leg, which is tried *after* the vendored leg. With defect 1
  fixed, `$project_root` is the consumer root, so the backup the reporter saw
  "one parent up" is now exactly where the lookup happens. Residual (not the
  reported defect, noted for completeness): the reporter's suggested
  `.rollback-meta.yaml` marker was not implemented — `lib/update.sh:205` writes
  only a `.fw-not-a-project` sentinel — so rollback still depends on correct
  `PROJECT_ROOT` resolution rather than being self-describing.

---

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

## M-21 — FIXED
- **defect:** with `.secret-scan-patterns` absent, `scan_staged`'s pipe leaked a non-zero status under `set -o pipefail`, so the pre-commit hook hard-blocked the first commit after `fw upgrade` with a misleading "detected matches" message.
- **evidence:** Live repro against the current script in a scratch repo with no patterns file:
  `PROJECT_ROOT=/tmp/ssrepro bash agents/git/lib/secret-scan.sh scan-staged` → prints `WARNING: SECRET SCAN IS RUNNING WITHOUT PATTERNS — catalogue missing:` … `Strict mode: set FW_SECRET_SCAN_STRICT=1 to make this block commits.` and `exit=0`. Fails open, does not block.
  T-2656 rewrote the missing-catalogue branch at `agents/git/lib/secret-scan.sh:86-102`: unmissable stderr warning, `return 0`, with blocking now opt-in via `FW_SECRET_SCAN_STRICT=1`. This addresses the reporter's fix shapes (b) and (c). Shape (a) is also satisfied — `.secret-scan-patterns` now ships in the payload (`ls .secret-scan-patterns` → present, 1698 bytes), and the warning text points at `fw upgrade` / `fw vendor self` as the reseed path.

## M-22 — LIVE

- **defect:** `fw pickup process` gates the TermLink bridge on the file's executable bit,
  but the bridge script is not tracked executable, so on any consumer install derived from
  git the bridge is skipped silently — pickups process "successfully" while TermLink
  delivery is lost.
- **evidence:** both legs are still present, unchanged, and the suggested fix was never
  applied.
  - Gate, verbatim as reported — `lib/pickup.sh:473-474`:
    `if [ -f "$processed_path" ] && [ -x "$bridge" ]; then` / `"$bridge" "$processed_path" 2>/dev/null || true`.
    The proposed `[ -f ] && bash "$bridge"` form (the T-2052/T-2061 secret-scan pattern)
    is absent.
  - Exec bit — `git ls-files -s lib/pickup-channel-bridge.sh` →
    `100644 082ea80639918b7e21c01a14186b07defbabba39 0 lib/pickup-channel-bridge.sh`.
    Mode **100644**, not 100755. Any consumer whose install comes from the clone path
    (`lib/upgrade.sh:937` `git clone --depth=1 … "$_tmpd/fw"`) receives the bridge without
    `+x` and the gate fails closed and silent. The local working copy shows `-rwxrwxr-x`
    only because of a stray local bit (May 26) — exactly the masking described in OBS-090.
  - The cross-search the reporter recommended still returns the same single offender:
    `grep -rn '\[ -x ' lib/` → `lib/pickup.sh:473` is the only invocation-gate hit (the
    other matches are `chmod`-preservation and dispatch-target probes).
  - Mitigating but not covering: `fw vendor`'s directory copy uses `rsync -a`
    (`bin/fw:520`, i.e. line 212 of `do_vendor`), which *does* preserve permissions — so a
    consumer vendored from a dev checkout carrying the stray `+x` works. That is precisely
    why this has stayed latent.
- **if LIVE:** flip `lib/pickup.sh:473` to gate on `-f` and invoke via `bash "$bridge"`,
  and/or `git update-index --chmod=+x lib/pickup-channel-bridge.sh`. **Partially covered,
  not closed:** the exec-bit class has two resolved concerns and two regression tests, and
  *neither test's scope reaches this file* — `tests/unit/t2486_exec_bit.bats:32` asserts
  100755 only for "exec-style `$FW_LIB_DIR/*.sh` targets" (fw-dispatched verbs), and
  `tests/unit/t2498_bin_scripts_executable.bats:12` covers only `bin/*.sh`. `.context/concerns.yaml`
  OBS-090 (status: resolved, fixed_in T-2498) names this exact recurrence mechanism —
  "OBS-087 was fixed for `lib/*.sh` exec-routed verbs and its regression test asserted
  those targets only … so the class re-surfaced in a sibling surface" — and
  `lib/pickup-channel-bridge.sh` is a third such sibling. No active task or open concern
  names this file's exec bit; `.tasks/active/T-2913-*` mentions the bridge but about
  channel-posting behaviour, not the gate.

---

## M-23 — LIVE

- **defect:** `pickup_next_id()` scans only inbox/processed/rejected and ignores
  `auto-deferred/`, so an ID already consumed by an auto-deferred envelope is reissued;
  the auto-defer `mv` then overwrites the earlier envelope with no error, silently
  losing a filed pickup.
- **evidence:** Both cooperating gaps are still present, verbatim as reported.
  Gap (A) — `lib/pickup.sh:306`:
  `for dir in "$PICKUP_INBOX" "$PICKUP_PROCESSED" "$PICKUP_REJECTED"; do` — the
  allocator's scan list, with `PICKUP_AUTO_DEFERRED` declared at `lib/pickup.sh:26` but
  absent from that loop.
  Gap (B) — `lib/pickup.sh:424`:
  `mv "$file" "$PICKUP_AUTO_DEFERRED/" 2>/dev/null || true` — plain `mv`, no `-i`, no
  destination-existence check, and errors suppressed. The sibling auto-defer at
  `lib/pickup.sh:435` (`if mv "$file" "$PICKUP_AUTO_DEFERRED/" 2>/dev/null; then`) has the
  same shape; it writes a breadcrumb but still clobbers a same-named destination.
- **if LIVE:** A fix must add `"$PICKUP_AUTO_DEFERRED"` to the `pickup_next_id()` scan
  loop at `lib/pickup.sh:306` and make both auto-defer `mv` calls collision-safe (rename
  on existing destination rather than overwrite). **No existing coverage found:** `grep
  -n "G-046" .context/concerns.yaml` returns nothing, and no active task references
  `pickup_next_id` (`grep -rln "pickup_next_id" .tasks/active/` → no matches; the only
  corpus hit is the completed `T-774-pickup-pipeline-core--libpickupsh-with-r.md`, which
  is the original implementation, not a fix). This defect is uncovered and needs a task.

## M-24 — LIVE

- **defect:** The audit's commit-traceability check reads only the *first*
  `T-NNNN` in a commit subject, so a multi-ref commit (`T-A/T-B-side:`,
  `T-A + T-B:`) is flagged as orphaned whenever the first ref does not resolve,
  even though a later ref does.
- **evidence:** `agents/audit/audit.sh:2476` is the reported line, unchanged in
  substance:

  ```
  task_ref=$(echo "$commit_line" | grep -oE "T-[0-9]+" | head -1)
  ```

  followed at `agents/audit/audit.sh:2478` by a single-ref existence test
  (`find "$TASKS_DIR" -name "${task_ref}-*.md"`). The two escape hatches added
  since the report are both orthogonal to this failure mode: revert-chain
  suppression (T-2058, `agents/audit/audit.sh:2481-2488`) and root-commit
  exemption (T-2851, `agents/audit/audit.sh:2496-2498`). Neither examines the
  second or later T-ref. The same `head -1` pattern also survives at
  `agents/audit/audit.sh:2749` for origin-line resolution.
- **if LIVE:** A fix would replace the `head -1` capture at
  `agents/audit/audit.sh:2476` with ANY-resolves semantics — iterate every
  `grep -oE "T-[0-9]+" | sort -u` ref and only fall through to the orphan warn
  when all of them fail to resolve (the reporter supplied this patch verbatim).
  The sibling `agents/audit/audit.sh:2749` wants the same treatment. No task or
  concern covers it: `grep -n "G-067" .context/concerns.yaml` returns nothing
  and no `.tasks/` file matches "multi-ref commit" / "ANY-resolves".

---

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

## M-26 — LIVE
- **defect:** `bin/watchtower.sh` silently substitutes `FRAMEWORK_ROOT` when the caller forgets to export `PROJECT_ROOT`, so Flask serves the framework's own empty `.tasks/`/`.context/` and the operator sees a fresh-install Setup Checklist for a project with hundreds of tasks.
- **evidence:** `bin/watchtower.sh:208` still reads verbatim `export PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"` — no die, no warn; line 209 merely logs the resolved value. All three proposed defences are absent:
  (1) no guard — nothing between line 208 and the `python3 -m web.app` launch at line 211 validates the value;
  (2) no doctor check — the only identity code, `lib/watchtower.sh:30` and `:79` (`_watchtower_identity_matches`), compares the served `project_root` against `"${PROJECT_ROOT:-${FRAMEWORK_ROOT:-}}"`, i.e. the *same* fallback, so a misconfigured instance matches itself and passes;
  (3) no banner — `web/config.py:18` repeats the fallback (`Path(os.environ.get("PROJECT_ROOT", str(_FRAMEWORK_ROOT)))`) and no template detects `PROJECT_ROOT == FRAMEWORK_ROOT`.
- **if LIVE:** a fix would have to make `bin/watchtower.sh:208` refuse to launch (or loudly warn) when `PROJECT_ROOT` is unset, equals `FRAMEWORK_ROOT`, or has basename `.agentic-framework`. Partially adjacent coverage exists but does not cover this: **G-069** (`.context/project/concerns.yaml:2162`, status `resolved`) is the sibling class in `web/shared._discover_project_root` walking past the framework root — a different code path, and it is closed. No open task or concern covers `watchtower.sh:208`: `grep -rln "silent.*fallback.*PROJECT_ROOT" .tasks/active/*.md` → no matches.

## M-27 — NOT-OURS

- **defect:** `external-tester-vpn`'s IP disagrees across ring20 registries
  (`data/infrastructure.yaml` and Technitium DNS say .150, the live service is at .202),
  producing an 18-day-stale "VPN disconnected" card.
- **evidence:** the drifted registry is not in this repo —
  `ls data/infrastructure.yaml` → `No such file or directory`;
  `grep -rn "external-tester-vpn\|external_tester_vpn"` across `*.py`/`*.sh`/`*.yaml`
  (excluding `.git/`, worktrees, and the T-3047 archive itself) → no matches. The message
  itself scopes the fix to another owner: "Proposed reconciliation (ring20-manager owns)",
  with steps against Technitium DHCP/DNS and ring20's `data/infrastructure.yaml`. No
  framework code path is implicated.

---

## M-28 — NOT-OURS

- **defect:** None. Four design questions from ring20-dashboard to ring20-manager about a
  signed-RPC remediation pilot (OpenVPN client-cert reissue script availability, RPC
  envelope placement, `termlink remote exec` allowlist, audit sink preference).
- **evidence:** `docs/reports/T-3047-recovered-upstream-messages.md:1082-1090` — "What I'm
  asking / 1) Do you have a shell-callable script today for OpenVPN client-cert reissue…".
  The one finding it does report is a TermLink gap, not a framework one:
  line 1093 — "termlink command-allowlist exists on `remote push` (PL-057) but NOT on
  `remote exec`". TermLink is a separate repo (`DimitriGeelen/termlink`); per §Gap Homing
  that belongs in TermLink's register, not this one.

## M-29 — NOT-OURS

- **defect:** None in this framework. A prod-deploy approval relay: wd-agent asks
  ring20-management to validate an operator approval under the
  *ring20-prod-deploy-gate §4.B* protocol and fire
  `POST /~api/job-runs` on OneDev project 35 to deploy
  025-WokrshopDesigner to `workshop-designer.geelenandcompany.com`.
- **evidence:** Every named artefact is external to this repo — OneDev job
  "Deploy to Cloudron (prod)", commit `afca8351` on the workshop-designer tree,
  and the gate document `ring20-prod-deploy-gate §4.B`. Confirmed absent here:
  `grep -rn "prod-deploy-gate" .` over the repo returns no policy, hook, or
  command implementing that gate; the deploy verb `POST /~api/job-runs` appears
  nowhere in `bin/fw`, `lib/`, or `web/`. It is an approval message under another
  project's protocol, not a defect report against this framework.

---

## M-30 — NOT-OURS

- **defect:** None — it withdraws/supersedes a previously relayed production-deploy approval
  (`ring20-prod-deploy-gate §4.B`, chat-arc offset 2282) because the operator had already
  deployed via direct Run Job. Pure coordination message about a consumer's deploy gate.
- **evidence:** Message body (`docs/reports/T-3047-recovered-upstream-messages.md:1148-1154`)
  references only `https://workshop-designer.geelenandcompany.com/`, commit `afca835`, and
  wd-agent's own commit freeze. No framework file, command, or gate is named; nothing in this
  repo implements `ring20-prod-deploy-gate`.

## M-31 — NOT-OURS
- **defect:** none — this is a prod-deploy approval relay asking ring20-management to validate an operator approval and fire a OneDev job-run for commit `2fbf6a0` of project 025-WokrshopDesigner.
- **evidence:** The payload is an approval envelope under the `ring20-prod-deploy-gate §4.B` protocol, addressed `@ring20-management`, requesting `POST /~api/job-runs` against `onedev.docker.ring20.geelenandcompany.com`. No framework file, command, or code path is named; the deploy gate, the OneDev instance, and the target project all live outside this repo. Pure handoff/approval traffic, no defect claim.

## M-32 — NOT-OURS

- **defect:** none — a deploy-coordination handoff asking how to host a static site on a
  Cloudron dev slot in Ring20 infra (app type, artefact transfer method, target URL),
  explicitly requesting no destructive action be taken.
- **evidence:** the message contains no defect claim, names no framework file, command, or
  behaviour, and concerns `/opt/023-geelenandcompany.com` on host 107 plus Cloudron/Ring20
  infrastructure. Falls squarely in the "pure requests/handoffs that describe no framework
  defect" class.

---

## M-33 — NOT-OURS

- **defect:** None. A deployment handoff asking ring20-management to host the static
  geelenandcompany.com site on a Cloudron DEV slot, with three infrastructure questions
  (app type, delivery mechanism, target domain).
- **evidence:** `docs/reports/T-3047-recovered-upstream-messages.md:1221-1228` — "ASK:
  deploy Dimitri's geelenandcompany.com hub … to a Cloudron DEV environment in your
  Ring20 infra", followed by "Please DO NOT shred or deploy anything yet". Pure
  infrastructure coordination; the only framework-adjacent mention is G-157 (cross-host DM
  read deadlock), which is the sender's stated *reason for reposting on agent-chat-arc*,
  not a defect filed against this repo — and G-157 is a TermLink/hub transport concern.

## M-34 — NOT-OURS

- **defect:** None in this framework. An infrastructure request: wd-agent asks
  ring20-management to provision `stage.geelenandcompany.com` on Cloudron
  (Static Website / Surfer app + DNS) with a CI/CD auto-deploy, or alternatively
  to issue Cloudron credentials via Infisical so wd-agent can wire it.
- **evidence:** The ask is entirely Cloudron/DNS/deploy-key provisioning for a
  static site at `/opt/023-geelenandcompany.com` on host .107 — no framework
  file, command, or gate is named, and the message asks for provisioning
  ("What do you need from me to start — a tarball, the git remote to push to, or
  a deploy key?") rather than reporting a defect. Under the task's own rubric,
  a pure request/handoff describing no framework defect is NOT-OURS.

---

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

## M-36 — LIVE
- **defect:** Watchtower's `web.app` does not close accepted client sockets on handler completion or exception, so connect-then-abort churn (health probes, smoke tests) accumulates CLOSE-WAIT sockets and unbounded threads until routes time out.
- **evidence:** `web/app.py:494` still serves via `app.run(host=host, port=port, debug=args.debug, threaded=True)` — the Werkzeug dev server in unbounded thread-per-connection mode. None of the three proposed fixes is present: no explicit socket close or handler teardown (`grep -n "close_connection\|daemon_threads\|request_queue_size\|CLOSE_WAIT\|T-1524" web/app.py bin/watchtower.sh` → no matches), and no connection/thread cap (the only `max_workers` in the file is `web/app.py:304`, an unrelated single-worker executor for a subprocess call). No fix ever landed: `git log --all -i --grep="CLOSE_WAIT\|socket leak\|close-wait"` → zero commits. Fix (3) is partly in place already — `web/smoke_test.py:122` uses `urlopen(req, timeout=5)` inside a `with`, which does close. The reporter's `T-1524` is ring20's task id, not ours (our `.tasks/completed/T-1524-t-1523-throwaway-test.md` is unrelated).
- **if LIVE:** a fix would have to replace the bare `app.run(threaded=True)` with a bounded, socket-closing WSGI server (a capped `ThreadedWSGIServer` subclass, or waitress/gunicorn) so accepted sockets are closed on handler exit and connection count is bounded. No task or concern covers it: no `CLOSE-WAIT` entry in `.context/project/concerns.yaml` and `grep -rln "CLOSE-WAIT\|close_wait" .tasks/active/` → no matches.

## M-37 — LIVE

- **defect:** `memory-recall.py` surfaces prior art from learnings/patterns/decisions (and
  completed episodics) only — it never searches the OPEN task corpus, so an existing,
  correct, still-open diagnosis cannot be found at `fw work-on` time and gets rediscovered
  at full cost (T-1390 → T-1537, 25 days, with a measured accuracy regression).
- **evidence:** the recall path is unchanged since it was first written.
  - `agents/context/lib/memory-recall.py:30-31` — `def load_knowledge_items(): """Load all
    learnings, patterns, and decisions from YAML files."""` — the loader reads
    `.context/project/learnings.yaml` (line 36) and its pattern/decision siblings, and
    nothing else.
  - `agents/context/lib/memory-recall.py:174-176` — `def recall(...)` calls
    `load_knowledge_items()` and returns from that set only; there is no third source and
    no `.tasks/active/` scan. The only task-file reader in the module,
    `get_task_context()` (lines 125-130), opens the *one* focused task to build the query
    string — it does not search the corpus.
  - `git log --oneline -- agents/context/lib/memory-recall.py` → a single commit,
    `593eca631 T-246: Memory recall — surface prior knowledge on focus set`. The file has
    not been touched since it was created; the requested extension was never made.
- **if LIVE:** `load_knowledge_items()` (or a peer loader called from `recall()`) needs a
  third source that scans `.tasks/active/` for `status != work-completed`, scores task
  *body* text with IDF-style weighting, and renders an OPEN TASKS block with
  id/status/horizon/age plus the matching line. **No existing coverage:** no task
  references T-1540 or open-task recall (`grep -rl "memory-recall" .tasks/active/` returns
  only `T-2907-six-read-only-consumers-still-resolve-le.md`, an unrelated path-resolution
  task; the four completed hits are T-246 and the learnings-dedup line), and neither
  `.context/concerns.yaml` nor `.context/project/concerns.yaml` mentions recall or prior-art.
  The reference implementation the reporter offers (`scripts/task-prior-art.py` +
  `tests/test-task-prior-art.sh`, 13 assertions) lives in the ring20 repo, not here.

## M-38 — FIXED

- **defect:** The P-011 verification gate ran the `## Verification` block line-by-line with
  no shell syntax pre-check (unparseable multi-line constructs presented as failed
  assertions), and had no concept of HTML comments — so the old template's `<!-- … -->`
  example commands were executed verbatim, issuing real HTTP requests and greps.
- **evidence:** Finding 1 is closed — `agents/task-create/update-task.sh:1175-1176` calls
  `check_verification_parseable "$verify_cmds"` and exits 1 **before** the read/`eval`
  loop, with the T-2991 comment at lines 1170-1174 stating the ordering is deliberate
  ("Checking after the loop would report the same finding and prevent nothing").
  Finding 2 is closed — `extract_verification_block` (`lib/verification-port.sh:175-181`)
  pipes the block through `lib/comment_strip.py`, which implements the structural rule
  documented at `lib/comment_strip.py:1-10` (`<!--` opens a span only as first non-blank
  token; span ends at first `-->`; comment lines dropped whole). Verified live against the
  exact template residue the message quotes:

  ```
  $ printf '## Verification\n<!-- Shell commands that MUST pass.\n     curl -sf http://localhost:3000/page\n     grep -q "expected" out.txt\n-->\necho real-command\n\n## Next\n' > /tmp/vtest.md
  $ source lib/verification-port.sh; extract_verification_block /tmp/vtest.md
  echo real-command
  ```

  The three commented example lines are dropped; only the real command survives, so
  neither the curl nor the grep is executed. Note the fix went further than the request:
  `lib/comment_strip.py:11-19` records that the naive DOTALL regex the request implies was
  itself a false-green source (T-2921), which is why the rule is structural.
  Finding 3 the message classifies itself as "not a framework bug" (line 1400) — an
  authoring hazard, out of scope for a code verdict.

## M-39 — LIVE

- **defect:** `register_blueprints()` has no project-local extension point, so a
  consumer's own Watchtower pages can only live inside the vendored tree that
  `fw upgrade` overwrites — the blueprints and their registration lines are
  silently deleted on the next sync.
- **evidence:** `web/blueprints/__init__.py` is 54 lines and registers a fixed,
  hard-coded list — every import is `from web.blueprints.<name> import bp`
  (`web/blueprints/__init__.py:9-40`). There is no `PROJECT_ROOT` branch and no
  Jinja search-path extension:

  ```
  $ grep -c "web-local" web/blueprints/__init__.py
  0
  $ grep -rn "web-local" web/ --include=*.py
  (no output)
  ```

  The file's own header comment states the only supported mechanism —
  `web/blueprints/__init__.py:4`: *"Adding a new blueprint: import it here and
  append to _BLUEPRINTS."* — which is precisely the vendored-tree edit the
  reporter says `fw upgrade` erases. Nothing in `web/` consults `PROJECT_ROOT`
  for blueprint discovery, so the reported exposure (7 consumer blueprints,
  6 templates) is unchanged.
- **if LIVE:** A fix would add a post-registration branch to
  `register_blueprints()` that imports any modules under
  `$PROJECT_ROOT/web-local/blueprints/*.py` and appends
  `$PROJECT_ROOT/web-local/templates` to the Jinja loader search path —
  opt-in by directory existence, loud-but-non-fatal on import error, and
  refusing name collisions with framework blueprints rather than shadowing them.
  No task or concern covers it: `grep -rn "blueprint" .context/concerns.yaml`
  returns only unrelated entries (`.context/concerns.yaml:94` AC parsing,
  `:377`/`:385` sys.path resolution), and no `.tasks/` file matches
  `web-local/blueprints`. The related filing P-035 (`.framework.yaml` allowlist,
  G-145) is referenced by the message but is not present in this repo's register
  either.

---

## Filed tasks (A4)

Ten tasks for eleven LIVE findings — M-04 and M-05 are the same defect (the missing
`[ -d ]` guard on the bats leg), reported independently by two projects three days
apart, so they share one task rather than becoming a duplicate pair.

| finding | task | defect |
|---|---|---|
| M-04 | T-3048 | `fw test unit/all` bats leg has no directory guard |
| M-05 | T-3048 | same as M-04 (independent report) |
| M-06 | T-3049 | `fabric drift` treats a URL `location:` as a missing file |
| M-14 | T-3050 | B-005 settings.json gate never reads the diff |
| M-22 | T-3051 | pickup bridge gated on an untracked exec bit |
| M-23 | T-3052 | `pickup_next_id` ignores `auto-deferred/` |
| M-24 | T-3053 | audit reads only the first T-ref in a commit subject |
| M-26 | T-3054 | `watchtower.sh` falls PROJECT_ROOT back to FRAMEWORK_ROOT |
| M-36 | T-3055 | Watchtower dev server unbounded — CLOSE_WAIT growth |
| M-37 | T-3056 | memory-recall never searches open tasks |
| M-39 | T-3057 | no project-local Watchtower blueprint extension point |

Every one of these is between four months and two weeks old and every one still
reproduces against current code. None was covered by an existing task — a `grep` over
`.tasks/active/` for each defect signature returned nothing before filing.
