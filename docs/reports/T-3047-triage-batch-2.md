# T-3047 — Triage batch 2 (M-02, M-07, M-12, M-17, M-22, M-27, M-32, M-37)

Read-only triage of recovered upstream messages against current framework code
(`/opt/999-Agentic-Engineering-Framework`, branch `t2539-staging`, 2026-08-17).
No source file, task file, or `.context/` file was modified.

---

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

## M-12 — NOT-OURS

- **defect:** none in the framework — an urgent ops request to run `ntfy user add
  operator-phone` + `ntfy access` on host 192.168.10.107 and return the password.
- **evidence:** `grep -rn "ntfy user add\|operator-phone" lib/ bin/ agents/` → no matches.
  The framework's only ntfy surface is the `FW_NTFY_URL` / `NTFY_URL` config key
  (CLAUDE.md §Configuration, T-2439) which resolves a server URL; it does not provision
  ntfy accounts or ACLs. This is server administration on a ring20 host plus a credential
  handoff, with no framework code path involved.

---

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

## M-32 — NOT-OURS

- **defect:** none — a deploy-coordination handoff asking how to host a static site on a
  Cloudron dev slot in Ring20 infra (app type, artefact transfer method, target URL),
  explicitly requesting no destructive action be taken.
- **evidence:** the message contains no defect claim, names no framework file, command, or
  behaviour, and concerns `/opt/023-geelenandcompany.com` on host 107 plus Cloudron/Ring20
  infrastructure. Falls squarely in the "pure requests/handoffs that describe no framework
  defect" class.

---

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
