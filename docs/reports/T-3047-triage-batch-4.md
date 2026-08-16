# T-3047 — Triage batch 4

Scope: M-04, M-09, M-14, M-19, M-24, M-29, M-34, M-39 from
`docs/reports/T-3047-recovered-upstream-messages.md`.

Triage only — no source file was edited. All verdicts carry a citation from
current framework code (`VERSION` = 1.6.450) or a command that was actually run.

---

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
