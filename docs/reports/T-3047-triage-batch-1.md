# T-3047 — Recovered upstream message triage, batch 1

Scope: M-01 M-06 M-11 M-16 M-21 M-26 M-31 M-36. Read-only triage; no fixes applied.
Source: `docs/reports/T-3047-recovered-upstream-messages.md`.

## M-01 — NOT-OURS
- **defect:** ring20-management's own skills MANIFEST catalogue drifted — a `generate-manifest.py` referenced by their docs never existed and per-skill manifests are sparse.
- **evidence:** Envelope names `local_gap: G-057`, `local_task: T-607`, `source_project: proxmox-ring20-management`, and artefact `.context/working/T-607/upstream-pickup-P-025.yaml`. None of those exist here: `ls .context/working/T-607` → `No such file or directory`; `find . -name "generate-manifest*"` → no results; our `G-057` (`.context/project/concerns.yaml:1500`) is an unrelated "no UI re-decide" gap. The framework's own manifest surface is `agents/mcp/manifest.py` + `agents/mcp/framework-mcp-manifest.json`, both present and unrelated to per-skill manifests. Defect lives in the ring20/150-skills-manager skill catalogue.

## M-06 — LIVE
- **defect:** `fabric drift` reports two false-positive classes — (1) cards whose `location:` is an external `https://` URL are joined onto `$PROJECT_ROOT` and reported "file missing"; (2) `depends_on` targets under `.agentic-framework/` flagged as stale edges.
- **evidence:** Part (1) is live. `agents/fabric/lib/drift.sh:58-64` — only an absolute-path (`${loc:0:1} = "/"`) branch exists; everything else becomes `$PROJECT_ROOT/$loc` and hits `[ ! -f "$resolved" ]`. `grep -c http agents/fabric/lib/drift.sh` → `0`: no URL skip anywhere in the file. Isolated repro of that exact branch with `location: https://zoneedit.com` → `FLAGGED: saas-account-zoneedit -> https://zoneedit.com (file missing) [resolved=/tmp/m06/https://zoneedit.com]`. The T-2519 gitignore escape at `drift.sh:76` does not catch it (a URL is not gitignored).
  Part (2) is fixed: `_resolves_on_disk` (`drift.sh:122-141`) treats any relative-path-with-slash target that exists on disk as resolved, so `.agentic-framework/agents/task-create/update-task.sh` resolves and is not stale (T-2427/G-070) — this is exactly the reporter's recommended fix (2).
- **if LIVE:** the orphan-detector branch at `drift.sh:58-64` needs an `http://*|https://*` skip before the file-existence test. No task or concern covers it: `grep -rln "drift.*URL\|saas-account" .tasks/active/*.md` → no matches; no matching entry in `.context/concerns.yaml`.

## M-11 — NOT-OURS
- **defect:** credential escalations raised by 150-skills-manager's `fw-authority` land in that project's queue and never appear on the consumer project's Watchtower `/approvals`, forcing a CLI workaround.
- **evidence:** `grep -rl "fw-authority" bin/ lib/ web/ agents/` → no matches; the framework has no `fw-authority` integration at all. `web/blueprints/approvals.py:85,116` globs only `APPROVALS_DIR` (`pending-*.yaml` / `resolved-*.yaml`) under this project's own `.context/`, which is correct behaviour for a per-project approval queue. The escalation record (`ESC-20260517203159-61yy`) is produced and stored by `/opt/150-skills-manager`, a different repo. The reporter's own option_a is a cross-project feature request, not a framework defect.

## M-16 — NOT-OURS
- **defect:** ring20-management's TermLink hub is pinned at 0.9.2127 while the fleet CLI is 0.11.1, so the doorbell+mail conversation-arc verbs and auto-heal stack are unavailable, and their heartbeat cron emits envelopes with `agent_id: null`.
- **evidence:** Every remedial step in the message targets TermLink and host systemd, not this repo: `brew upgrade termlink`, `systemctl restart termlink-hub`, `TERMLINK_RUNTIME_DIR=/var/lib/termlink`, `termlink fleet doctor`. Per CLAUDE.md §TermLink Integration, TermLink is a machine-wide binary deliberately outside the framework's per-project vendoring; the framework only wraps it via `fw termlink`. This is an infrastructure upgrade request addressed to an operator, describing no framework code defect.

## M-21 — FIXED
- **defect:** with `.secret-scan-patterns` absent, `scan_staged`'s pipe leaked a non-zero status under `set -o pipefail`, so the pre-commit hook hard-blocked the first commit after `fw upgrade` with a misleading "detected matches" message.
- **evidence:** Live repro against the current script in a scratch repo with no patterns file:
  `PROJECT_ROOT=/tmp/ssrepro bash agents/git/lib/secret-scan.sh scan-staged` → prints `WARNING: SECRET SCAN IS RUNNING WITHOUT PATTERNS — catalogue missing:` … `Strict mode: set FW_SECRET_SCAN_STRICT=1 to make this block commits.` and `exit=0`. Fails open, does not block.
  T-2656 rewrote the missing-catalogue branch at `agents/git/lib/secret-scan.sh:86-102`: unmissable stderr warning, `return 0`, with blocking now opt-in via `FW_SECRET_SCAN_STRICT=1`. This addresses the reporter's fix shapes (b) and (c). Shape (a) is also satisfied — `.secret-scan-patterns` now ships in the payload (`ls .secret-scan-patterns` → present, 1698 bytes), and the warning text points at `fw upgrade` / `fw vendor self` as the reseed path.

## M-26 — LIVE
- **defect:** `bin/watchtower.sh` silently substitutes `FRAMEWORK_ROOT` when the caller forgets to export `PROJECT_ROOT`, so Flask serves the framework's own empty `.tasks/`/`.context/` and the operator sees a fresh-install Setup Checklist for a project with hundreds of tasks.
- **evidence:** `bin/watchtower.sh:208` still reads verbatim `export PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"` — no die, no warn; line 209 merely logs the resolved value. All three proposed defences are absent:
  (1) no guard — nothing between line 208 and the `python3 -m web.app` launch at line 211 validates the value;
  (2) no doctor check — the only identity code, `lib/watchtower.sh:30` and `:79` (`_watchtower_identity_matches`), compares the served `project_root` against `"${PROJECT_ROOT:-${FRAMEWORK_ROOT:-}}"`, i.e. the *same* fallback, so a misconfigured instance matches itself and passes;
  (3) no banner — `web/config.py:18` repeats the fallback (`Path(os.environ.get("PROJECT_ROOT", str(_FRAMEWORK_ROOT)))`) and no template detects `PROJECT_ROOT == FRAMEWORK_ROOT`.
- **if LIVE:** a fix would have to make `bin/watchtower.sh:208` refuse to launch (or loudly warn) when `PROJECT_ROOT` is unset, equals `FRAMEWORK_ROOT`, or has basename `.agentic-framework`. Partially adjacent coverage exists but does not cover this: **G-069** (`.context/project/concerns.yaml:2162`, status `resolved`) is the sibling class in `web/shared._discover_project_root` walking past the framework root — a different code path, and it is closed. No open task or concern covers `watchtower.sh:208`: `grep -rln "silent.*fallback.*PROJECT_ROOT" .tasks/active/*.md` → no matches.

## M-31 — NOT-OURS
- **defect:** none — this is a prod-deploy approval relay asking ring20-management to validate an operator approval and fire a OneDev job-run for commit `2fbf6a0` of project 025-WokrshopDesigner.
- **evidence:** The payload is an approval envelope under the `ring20-prod-deploy-gate §4.B` protocol, addressed `@ring20-management`, requesting `POST /~api/job-runs` against `onedev.docker.ring20.geelenandcompany.com`. No framework file, command, or code path is named; the deploy gate, the OneDev instance, and the target project all live outside this repo. Pure handoff/approval traffic, no defect claim.

## M-36 — LIVE
- **defect:** Watchtower's `web.app` does not close accepted client sockets on handler completion or exception, so connect-then-abort churn (health probes, smoke tests) accumulates CLOSE-WAIT sockets and unbounded threads until routes time out.
- **evidence:** `web/app.py:494` still serves via `app.run(host=host, port=port, debug=args.debug, threaded=True)` — the Werkzeug dev server in unbounded thread-per-connection mode. None of the three proposed fixes is present: no explicit socket close or handler teardown (`grep -n "close_connection\|daemon_threads\|request_queue_size\|CLOSE_WAIT\|T-1524" web/app.py bin/watchtower.sh` → no matches), and no connection/thread cap (the only `max_workers` in the file is `web/app.py:304`, an unrelated single-worker executor for a subprocess call). No fix ever landed: `git log --all -i --grep="CLOSE_WAIT\|socket leak\|close-wait"` → zero commits. Fix (3) is partly in place already — `web/smoke_test.py:122` uses `urlopen(req, timeout=5)` inside a `with`, which does close. The reporter's `T-1524` is ring20's task id, not ours (our `.tasks/completed/T-1524-t-1523-throwaway-test.md` is unrelated).
- **if LIVE:** a fix would have to replace the bare `app.run(threaded=True)` with a bounded, socket-closing WSGI server (a capped `ThreadedWSGIServer` subclass, or waitress/gunicorn) so accepted sockets are closed on handler exit and connection count is bounded. No task or concern covers it: no `CLOSE-WAIT` entry in `.context/project/concerns.yaml` and `grep -rln "CLOSE-WAIT\|close_wait" .tasks/active/` → no matches.
