# T-4253 — Greenfield run triage: aef-install-20261017T144241Z-dimitrimintdev

**Source:** `/opt/0909-boot-into-timeshift-snapshots/.context/install-findings/aef-install-20261017T144241Z-dimitrimintdev/`
(FINAL-REPORT.md, findings/F-01..F-49.yaml). Pickup P-001 from 0909.

**Checked against:** `bleeding-edge` at `1ff556264` (2026-10-17). The run installed from `master` commit `704c9988`,
which is **568 commits behind** this checkout. A finding can therefore be real on the install surface and already
fixed here; those rows say so (`not-reproducible` = fixed on bleeding-edge, still live on master until the next release).

**Scope note:** the task says 48 findings; the record holds **49** (F-49 was filed after the pickup header counts were
written). F-49 is triaged too.

**Verdict vocabulary:** `confirmed` (defect present in current source, file:line cited) · `not-reproducible`
(fixed on bleeding-edge, or source no longer has the cited behaviour) · `prompt-side` (the install prompt, not the
framework) · `environment` (host state; framework contribution, if any, is owned elsewhere).

**Priority:** P1 = blocker or security/false-green on first run · P2 = degraded, or friction every new user hits ·
P3 = friction a user can route around · P4 = cosmetic.

## Triage table

| id | severity | class | verdict | owner | priority | note |
|---|---|---|---|---|---|---|
| F-01 | degraded | environment | environment | T-4248 | P1 | Host dispatch env exports FRAMEWORK_ROOT/PROJECT_ROOT; install.sh does not sanitise them. bin/fw:1311 still trusts an inherited FRAMEWORK_ROOT. |
| F-02 | friction | environment | environment | T-4248 | P3 | Dispatch wrapper writes `.context/dispatch-results/` into the target; root cause of F-03. |
| F-03 | friction | ux-friction | confirmed | PROPOSED-NEW-1 | P3 | lib/init.sh:122-135 collects any top-level entry, lib/init.sh:707-708 sets `has_code=true` when any exist; `.context/` holding two foreign .md files flips greenfield to existing-project mode. |
| F-04 | degraded | prompt-defect | prompt-side | T-4237 | P3 | Yield-point command (`fw sidecar inbox`) needs a pre-install form in the prompt. |
| F-05 | degraded | framework-defect | confirmed | T-4251 | P1 | Consequence of lib/init.sh:186 (`--is-inside-work-tree`): hooks installed into the enclosing `/.git/hooks`. |
| F-06 | degraded | environment | environment | T-4251 | P2 | `/.git` on the host is environmental; the framework part (not detecting it) is T-4251. |
| F-07 | degraded | framework-defect | confirmed | T-4251 | P1 | lib/init.sh:866-867 only warns on failed bootstrap commit; install.sh:479 still prints "All verification steps passed" (no HEAD check). Hint `git add -A` targets the enclosing repo. |
| F-08 | cosmetic | ux-friction | confirmed | PROPOSED-NEW-2 | P4 | Installer next-steps say `fw serve`, help offers both `serve` and `watchtower start` with no preferred form. |
| F-09 | cosmetic | framework-defect | confirmed | PROPOSED-NEW-3 | P4 | lib/vector_index_health.py:537-542 emits WARN inside the grace window it itself states (`limit 24h`). Deliberate per T-3747 comment, but contradicts its own text. |
| F-10 | friction | framework-defect | confirmed | T-2997 | P3 | Exactly T-2997 ("fw doctor claude-fw drift compares router against wrapper"), still captured. |
| F-11 | friction | framework-defect | confirmed | PROPOSED-NEW-4 | P2 | bin/fw:3721 emits one project WARN per host-wide DM rail; 13 of 31 fresh-install warnings. |
| F-12 | friction | framework-defect | confirmed | PROPOSED-NEW-5 | P3 | bin/fw:3821 (and agents/audit/audit.sh:4258) WARN "No sidecar watcher"; init/install neither start one nor mention it. |
| F-13 | friction | framework-defect | confirmed | T-4251 | P2 | bin/fw:4176-4200 enumerates `git worktree list` of whatever repo encloses PROJECT_ROOT; disappears once the project has its own repo. |
| F-14 | degraded | framework-defect | confirmed | T-4248 | P1 | bin/fw:1311 keeps an inherited FRAMEWORK_ROOT, bin/fw:1340 derives AGENTS_DIR from it, bin/fw:10542 resolves hook scripts there, bin/fw:10551 logs `missing-hook` and fails open. Every gate open in phase 1 while doctor's clean-env exercise says OK. Fail-open-on-missing-gate may merit its own task once T-4248 lands. |
| F-15 | friction | framework-defect | confirmed | PROPOSED-NEW-6 | P3 | bin/fw:4398 WARN "Cron registry present but not generated" on a fresh init that seeded the registry, while the same run prints OK for the cron job. |
| F-16 | friction | framework-defect | confirmed | PROPOSED-NEW-7 | P3 | lib/branch-hygiene.sh:637 `git status --porcelain` without `-uall` collapses an untracked dir to 1 entry; remedy text offers removal of init-seeded tasks. Path relativity to `/` is T-4251. |
| F-17 | friction | framework-defect | confirmed | PROPOSED-NEW-8 | P2 | install.sh:448 runs `fw doctor &>/dev/null` and reports "passes ✓" on exit 0 regardless of 31 WARNs; nothing is shown. |
| F-18 | friction | framework-defect | confirmed | T-4251 | P2 | Task counter read from the enclosing repo's `.tasks/` (consequence of init.sh:186). |
| F-19 | cosmetic | ux-friction | confirmed | PROPOSED-NEW-9 | P4 | .tasks/templates/default.md:19 ships framework-repo corpus figures ("0 of 3032 tasks") into consumer tasks. |
| F-20 | degraded | framework-defect | confirmed | T-4252 | P1 | Plain `fw sidecar inbox` drains a host-shared DM rail (lib/sidecar_cli.py:74 "machine-wide — T-3405"); 198 messages for other projects marked read. |
| F-21 | friction | prompt-defect | prompt-side | T-4252 | P2 | Dispatch preamble prescribes the draining form; T-4252 covers the preamble. |
| F-22 | blocker | framework-defect | confirmed | T-4251 | P1 | Commit went to the enclosing `/` repo and hit its stale lock; root cause lib/init.sh:186. |
| F-23 | friction | ux-friction | confirmed | PROPOSED-NEW-10 | P3 | install.sh prints no "restart your agent session" step for an agent that was already running when hooks were installed. |
| F-24 | degraded | prompt-defect | prompt-side | T-4248 | P2 | `env -u` workaround covers agent commands only; harness hooks inherit the env. Real fix is T-4248 (F-14). |
| F-25 | friction | ux-friction | prompt-side | T-4237 | P3 | Focus is per session key by design; prompt should add `fw work-on` as the first post-restart step. |
| F-26 | friction | framework-defect | confirmed | PROPOSED-NEW-11 | P3 | agents/context/lib/safe-commands.sh:508 takes `$2` as the git sub-verb, so `git -C <dir> rev-parse` reads `-C` and misses the allowlist at :523. The `2>&1` half is likely already handled (T-3344 strip at :488, present in the run commit) — re-test on the compound form before scoping it in. |
| F-27 | degraded | prompt-defect | prompt-side | T-4237 | P2 | Prompt has no step for the onboarding gate; framework half is F-28. |
| F-28 | degraded | framework-defect | confirmed | PROPOSED-NEW-12 | P1 | agents/context/check-active-task.sh:258/291/333 bootstrap exemption lists work-on/task create/context focus/inception only; the onboarding block advertises `fw onboarding skip` (:1055) which the same gate refuses. Not T-3669 (render-gate deadlock, different pair). |
| F-29 | friction | environment | environment | T-4248 | P3 | Dispatch env still injects path vars after restart. |
| F-30 | friction | framework-defect | confirmed | PROPOSED-NEW-13 | P3 | lib/init.sh:867 advises `git commit -m "T-000: bootstrap"`; focus-drift gate (agents/context/check-active-task.sh:775) refuses T-000 when focus is set. No T-000 special case anywhere in the gate. |
| F-31 | blocker | framework-defect | confirmed | T-4251 | P1 | lib/init.sh:186 `git -C "$target_dir" rev-parse --is-inside-work-tree` — unchanged since the run commit. Root of F-05/07/13/18/22/46. |
| F-32 | friction | ux-friction | confirmed | PROPOSED-NEW-14 | P4 | First full commit (3580 files) silent for ~130 s; no progress line. Dimension depends on vendored tree size. |
| F-33 | cosmetic | ux-friction | confirmed | PROPOSED-NEW-15 | P4 | agents/git/lib/hooks.sh:1542-1557 prints "Hook content differs … reinstalling" on a first install (lists 5 names in `_names`, absence counts as "differs"). |
| F-34 | friction | ux-friction | confirmed | T-4239 | P3 | Dashboard not started by install; T-4239's first-run scope. |
| F-35 | degraded | doc-defect | not-reproducible | T-4239 | P2 | FW_HOST now documented in help (bin/watchtower.sh:653) — absent at 704c9988. The 0.0.0.0/no-auth default itself remains T-4239. |
| F-36 | degraded | framework-defect | not-reproducible | T-4239 | P2 | Fixed on bleeding-edge by T-4041 (bin/watchtower.sh:407-408 start, :601-602 do_url use the bound host). T-4041 is NOT on master: still live for installs until release. |
| F-37 | friction | framework-defect | confirmed | T-4239 | P2 | bin/watchtower.sh:399 calls `ensure_firewall_open` unconditionally; lib/firewall.sh:42 runs `ufw allow` even for a loopback bind. System change, undocumented. |
| F-38 | cosmetic | prompt-defect | prompt-side | T-4237 | P4 | Port auto-allocation + persist (bin/watchtower.sh:398 `persist_port`) is real; prompt describes a fixed default. |
| F-39 | friction | framework-defect | confirmed | PROPOSED-NEW-16 | P3 | web/templates/_continuous_halt.html:11-17 renders "RUNNING" whenever `continuous.halted` is false — absence of the halt file reads as a running loop. |
| F-40 | cosmetic | framework-defect | confirmed | PROPOSED-NEW-17 | P4 | web/blueprints/quality.py:16-22 `_compute_audit_status` returns PASS for zero counts (never-run audit); home shows UNKNOWN. |
| F-41 | degraded | unknown | confirmed | T-4239 | P1 | Exposure confirmed (/terminal + unauthenticated /api/sessions/profiles under default 0.0.0.0 bind); whether it spawns shells is unverified — T-4239 must verify before ranking. If it spawns, this is the top item. |
| F-42 | cosmetic | ux-friction | confirmed | PROPOSED-NEW-18 | P4 | Seeded framework learnings/patterns/decisions shown on /decisions, /patterns, /learnings, /project as the project's own, unlabelled. |
| F-43 | friction | prompt-defect | prompt-side | T-4237 | P3 | `fw inception start` leaves status captured by design (lib/inception.sh:152 comment); prompt must say `fw work-on`. |
| F-44 | friction | doc-defect | confirmed | PROPOSED-NEW-19 | P3 | CLAUDE.md §Inception Discipline item 6 (C-001 artifact first) vs the G-067/T-2194 open-questions gate ordering conflict. |
| F-45 | cosmetic | framework-defect | confirmed | PROPOSED-NEW-20 | P4 | .tasks/templates/inception.md:84 `fw task review T-XXX`; agents/task-create/create-task.sh:484/494/521 substitute only `id:` and the heading. |
| F-46 | cosmetic | framework-defect | confirmed | T-4251 | P3 | Foreign counter persists (T-998) after the project got its own repo — same root as F-18. |
| F-47 | friction | framework-defect | confirmed | T-4159 | P3 | lib/shell_write_scan.py:61-63 MENTION_RE matches `T-998-….md` in a heredoc body; redirect target was commands.log. Same class T-4159 already names. |
| F-48 | cosmetic | ux-friction | environment | external: TermLink | P4 | "delivered-unconfirmed" is TermLink's status vocabulary; gap homing (T-1333) puts it in the TermLink repo, no AEF task. |
| F-49 | friction | framework-defect | confirmed | T-3763 | P3 | Deprecated `remote push` is T-3763 (lib/pickup.sh:573). The second half — per-project P-NNN (lib/pickup.sh:340-367) in a host-shared inbox can overwrite another project's envelope — is a separate bug: PROPOSED-NEW-21. T-3059 (no lock, same project) is a different race. |

**Counts by verdict (49):** confirmed 35 · not-reproducible 2 · prompt-side 7 · environment 5.

**Counts by owner (49 rows):** PROPOSED-NEW 20 rows · T-4251 8 (F-05,06,07,13,18,22,31,46) · T-4248 5
(F-01,02,14,24,29) · T-4237 5 (F-04,25,27,38,43 — the prompt-publication task) · T-4239 5 (F-34,35,36,37,41) ·
T-4252 2 (F-20,21) · T-2997 1 (F-10) · T-4159 1 (F-47) · T-3763 1 (F-49) · external TermLink 1 (F-48).
21 proposals in total: the 20 PROPOSED-NEW rows plus PROPOSED-NEW-21 split out of F-49.

Note on T-4238 (preflight deps): no finding in this run maps to it — PyYAML/Flask were present on dimitri-mint-dev.

## Proposed new tasks

One bug per task. All `workflow_type: build` unless stated. Horizon: `now` for P1/P2, `next` for P3, `later` for P4.

1. **PROPOSED-NEW-1** — *fw init classifies a target as existing-project when it holds only a `.context/` dir with no code.*
   Scope: lib/init.sh:122-135/707-708 — ignore framework-owned dirs (`.context/`, `.tasks/`, `.claude/`) when deciding greenfield vs existing. Findings: F-03. build, `next`.
2. **PROPOSED-NEW-2** — *Installer next-steps and fw help disagree on how to start Watchtower (`fw serve` vs `fw watchtower start`).*
   Scope: pick one canonical verb, print it in install.sh and mark the other an alias in help. Findings: F-08. build, `later`.
3. **PROPOSED-NEW-3** — *Vector-index doctor check WARNs inside its own stated grace window.*
   Scope: lib/vector_index_health.py:537-542 — emit INFO/SKIP within INDEX_MAX_AGE_HOURS of init, keep cron FAIL. Findings: F-09. build, `later`.
4. **PROPOSED-NEW-4** — *fw doctor reports host-wide DM-rail backlog as per-project warnings.*
   Scope: bin/fw:3721 — fold DM rails into one host-scoped summary line, not counted as project WARNs, no drain advice. Findings: F-11 (13 of 31 fresh-install warnings). build, `now`.
5. **PROPOSED-NEW-5** — *init/install neither start nor mention the sidecar watcher that doctor requires (R14).*
   Scope: add `fw sidecar start` to installer next steps (or start it), or doctor INFO until first session. Findings: F-12. build, `next`.
6. **PROPOSED-NEW-6** — *fw init seeds a cron registry but leaves it ungenerated; doctor WARNs and also prints cron OK.*
   Scope: bin/fw:4398 + init — either generate at init (no install) or say "run fw cron install" in installer next steps; make the two cron lines agree. Findings: F-15. build, `next`.
7. **PROPOSED-NEW-7** — *Untracked-task doctor check miscounts (dir collapsed to 1) and suggests removing init-seeded tasks.*
   Scope: lib/branch-hygiene.sh:637 add `--untracked-files=all`, project-relative paths, no removal advice for onboarding-tagged tasks. Findings: F-16. build, `next`.
8. **PROPOSED-NEW-8** — *install.sh reports "fw doctor passes ✓" while hiding every doctor WARN, and never checks HEAD.*
   Scope: install.sh:448 — print WARN count + first lines; add an unresolved-HEAD check to post-install verification so F-07 cannot exit "All verification steps passed". Findings: F-17 (F-07 overlap with T-4251 on the HEAD leg). build, `now`.
9. **PROPOSED-NEW-9** — *Task template ships framework-repo corpus statistics into consumer projects.*
   Scope: .tasks/templates/default.md:19 and siblings — drop live corpus counts from template comments. Findings: F-19. build, `later`.
10. **PROPOSED-NEW-10** — *Installer gives no restart instruction to an agent session that was running during install.*
    Scope: install.sh final banner — when `$CLAUDECODE` is set, say hooks take effect only after restart. Findings: F-23. build, `next`.
11. **PROPOSED-NEW-11** — *Read-only allowlist misses `git -C <dir> <read-verb>`.*
    Scope: agents/context/lib/safe-commands.sh:506-523 — skip `-C <dir>` / `--git-dir=` before taking the sub-verb; bats case. Re-test the `2>&1` compound form from F-26 and include it only if it reproduces. Findings: F-26. build, `next`.
12. **PROPOSED-NEW-12** — *Onboarding gate advertises `fw onboarding skip` but its own bootstrap exemption refuses it.*
    Scope: agents/context/check-active-task.sh:258/291/333 add `onboarding (skip|status)`; add a test that every remedy a gate's block message prints passes that gate. Findings: F-28 (+F-27 framework half). build, `now`.
13. **PROPOSED-NEW-13** — *init.sh's T-000 bootstrap recovery commit is refused by the focus-drift gate.*
    Scope: special-case T-000 in the focus-drift gate for scaffolding commits, or change lib/init.sh:863/867 advice to use the focused task. Findings: F-30. build, `next`.
14. **PROPOSED-NEW-14** — *First full commit of a vendored project runs ~130 s with no progress output.*
    Scope: print a "committing N files, may take a minute" line in the commit path when staged count is large. Findings: F-32. build, `later`.
15. **PROPOSED-NEW-15** — *fw git install-hooks reports "content differs — reinstalling" on a first install.*
    Scope: agents/git/lib/hooks.sh:1542-1557 — distinguish absent from differing, and list only hooks actually written. Findings: F-33. build, `later`.
16. **PROPOSED-NEW-16** — */approvals shows "Continuous run is RUNNING" when no continuous run exists.*
    Scope: web/templates/_continuous_halt.html:11 + its context provider — three states (no run / running / halted). Render surface: needs a [REVIEW] Human AC. Findings: F-39. build, `next`.
17. **PROPOSED-NEW-17** — */quality renders a never-run audit as PASS.*
    Scope: web/blueprints/quality.py:16-22 — "not run yet" when no audit file / zero checks, matching home's UNKNOWN. Findings: F-40. build, `later`.
18. **PROPOSED-NEW-18** — *Seeded framework knowledge appears as the project's own on /decisions, /patterns, /learnings, /project.*
    Scope: label seeded entries by source (framework vs project) or filter by default. Findings: F-42. build, `later`.
19. **PROPOSED-NEW-19** — *C-001 (artifact first) and the G-067 open-questions gate prescribe opposite orders for inception start.*
    Scope: reconcile CLAUDE.md §Inception Discipline item 6 with the T-2194 gate message so both name the same first step. Findings: F-44. build (doc), `next`.
20. **PROPOSED-NEW-20** — *Inception template's Human AC ships the placeholder `fw task review T-XXX`.*
    Scope: agents/task-create/create-task.sh:484-521 — substitute T-XXX throughout the inception body, not only `id:` and heading. Findings: F-45. build, `later`.
21. **PROPOSED-NEW-21** — *Pickup envelopes named by per-project P-NNN collide in the host-shared TermLink inbox.*
    Scope: lib/pickup.sh:340-367/610 — prefix inbox filenames with the source project (or content hash) so two projects' P-001 cannot overwrite. Findings: F-49 (second half; first half is T-3763). build, `now`.

## Filed as (parent, 2026-10-17)

PROPOSED-NEW-1..21 → T-4254..T-4274 in order (now: T-4257, T-4261, T-4265, T-4274; next: T-4254, T-4258, T-4259,
T-4260, T-4263, T-4264, T-4266, T-4269, T-4272; later: T-4255, T-4256, T-4262, T-4267, T-4268, T-4270, T-4271, T-4273).

## Top priorities (P1)

F-31/F-22/F-05/F-07 (T-4251), F-14/F-01 (T-4248), F-20 (T-4252), F-28 (PROPOSED-NEW-12), F-41 (T-4239, verify /terminal).
Two P2 items are already fixed on bleeding-edge but not on master (F-35, F-36 via T-4041): they stay live for every
install until the next release.
