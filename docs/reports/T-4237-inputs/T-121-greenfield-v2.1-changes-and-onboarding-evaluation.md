# T-121 — Greenfield prompt v2.1: live-run evidence, change per finding, onboarding evaluation

**For:** the AEF framework agents (README inception AEF T-4237). Answers the four criteria of the AEF operator
(msg aca212bd).
**Prompt:** `docs/proposals/aef-greenfield-install-prompt-v2.1.md` (supersedes the review-only v2 from T-118).
**Target:** `/opt/0909-boot-into-timeshift-snapshots`, Linux Mint 22.3, bash 5.2.21, git 2.43.0, Python 3.12.3,
PyYAML 6.0.3, Flask 3.1.2; installer from GitHub master 704c9988, fw v1.8.10 vendored, provider claude.
**How it was run:** headless, as TermLink dispatch workers (`fw termlink dispatch`). The orchestrator
(dimitri-mint-dev) wrote the operator's [ASK] answers into each worker prompt. Prompts:
`docs/proposals/greenfield-runs/`.

## (2) Runs and evidence

| Run | Id | Outcome | Findings |
|---|---|---|---|
| 1 | aef-install-20261017T141820Z-dimitrimintdev | install.sh exit 0, but `fw init` failed (`<target>/lib/init.sh` not found) — the dispatch wrapper's FRAMEWORK_ROOT/PROJECT_ROOT leaked into the installer. Stopped at STEP 2 (orchestrator rule "stop on failure") | 5 (`/tmp/aef-findings/<run>/findings/`) |
| 2 | aef-install-20261017T142628Z-dimitrimintdev | Stopped before STEP 2: the orchestrator's rule "target must be empty" tripped on the dispatch wrapper's own result file in the target | 3 |
| 3 | aef-install-20261017T144241Z-dimitrimintdev | **Full run, STEPs 0-7.** Installed with `env -u` cleaning; own git repo created by hand; Watchtower 127.0.0.1:3004; inception T-998 primed with the grub-btrfs research; 49 findings published (TermLink topic `aef-install-findings`, offsets 202-251, read back) and delivered (pickup P-001) | **49** |

Run-3 record: `/opt/0909-boot-into-timeshift-snapshots/.context/install-findings/aef-install-20261017T144241Z-dimitrimintdev/`
(findings F-01..F-49 as YAML, run.yaml, commands.log, evidence/, FINAL-REPORT.md, published.yaml).
Counts: framework-defect 26, ux-friction 10, prompt-defect 6, environment 4, doc-defect 2, unknown 1;
blocker 2, degraded 13, friction 24, cosmetic 10.

Summary per finding: see the appendix at the end (F-01..F-48 as delivered to AEF; F-49 on TermLink).

## (3) What changed in the prompt, per finding

| Finding (run) | Change in v2.1 |
|---|---|
| Run 1 + run 2 stops (orchestrator rules) | New **bad-news-first rule**: on failure, record and continue with every step that can still run. STEP 2 "Deterministic install failure" bullet. |
| Run 1 F-01, run 3 F-01, F-24, F-29 (env leak) | New **Clean environment** section: list the six variables, `env -u` on the installer and every `fw` call, and a note that this does not clean the hook environment. |
| Run 2 F-01, run 3 F-02 (dispatch writes into target) | **Headless runs** section: harness files in the target are recorded, and the install proceeds. |
| Run 3 F-04, F-20, F-21 (sidecar drain, no pre-install form) | **Headless runs** section: `fw sidecar inbox --peek` only; skip before install. |
| Run 3 F-06, F-22, F-31, F-18, F-05 (enclosing repo at /) | STEP 2 pre-check 1: `git rev-parse --show-toplevel`, then `git init <dir>` if it is not the target. |
| Run 1 F-03 (PATH tools overwritten) | STEP 2 pre-check 2: back up `~/.local/bin/{fw,claude-fw}`; explains the router. |
| Run 1 F-02, run 3 F-07 (success banner after failure) | STEP 2 **Do not trust the installer's last line**: check `.framework.yaml` and the vendored `bin/fw` yourself. |
| Run 1 "never from /opt/999" (operator ruling) | STEP 2: never install from a local clone or development repo. |
| Run 3 F-09..F-17 (31 warnings) | STEP 3: expect many warnings on v1.8.10; record each anyway. |
| Run 3 F-27, F-28 (onboarding gate T-532) | New STEP 3.2 **Onboarding gate**: [ASK] work through or skip; the skip path that works on v1.8.10. |
| Run 3 F-14, F-24 (gates fail open before the restart) | STEP 3b: restart from a plain shell, not inside another project's claude-fw; **prove governance is active** (doctor hook-crash count, first gate blocks). |
| Run 3 F-34..F-38, F-41 (Watchtower) | STEP 4: port read with `watchtower port`; URL is `127.0.0.1:<port>` under a local bind; terminal page exposed to the LAN under the default bind. |
| Run 3 F-43, F-44 (inception start then gates) | STEP 5 Explore-first: `fw work-on T-XXX` after `inception start`, then IW-1, then the C-001 artifact, in that order. |
| Run 3 onboarding times | STEP 5 capture: three onboarding times. |
| Run 3 header counts cover only F-01..F-47 / F-48 | STEP 6.7: AEF delivery with `--remote`/`--session` (T-4243); counts written last. |

## (3b) Left out of the prompt, and why

| Finding(s) | Why not in the prompt |
|---|---|
| F-09, F-10, F-11, F-13, F-15, F-16, F-17 (individual doctor warnings) | Framework defects to fix in doctor/init; a prompt listing each warning would rot. The prompt says "expect many, record each". |
| F-19, F-42 (seeded framework content shown as project content) | Product defects with no user-side workaround. |
| F-26 (T-532 write detector), F-30 (focus-drift), F-47 (Human-AC tick guard false positive) | Gate behaviour; the prompt already says "satisfy the gate the way its message says, record it". |
| F-32, F-33 (first commit size, fresh install wording) | Cosmetic, no action for the installer user. |
| F-39, F-40 (Watchtower claims a continuous run / audit UNKNOWN vs PASS) | Product defects; STEP 4 already asks for empty-state observations. |
| F-45, F-46 (inception wording, foreign task counter) | Cosmetic, and F-46 disappears with pre-check 1 (own git repo). |
| F-48, F-49 (TermLink post reporting) | Transport detail; no effect on the record. |
| AEF-side fixes themselves | Out of scope for a user prompt: AEF T-4238 (deps), T-4239 (bind), T-4240 (restart notice), T-4241 (work-on --help), T-4243 (pickup trap), T-4248 (env leak + success banner + dispatch writes into target), T-4251 (enclosing repo), T-4252 (sidecar drain). **When those ship, the matching v2.1 workarounds (Clean environment, pre-checks 1-3, onboarding skip path, Watchtower URL) should be removed again.** |

## (4) Test feedback

**Worked as written:**
- the findings schema and its field order (49 well-formed records);
- `/tmp` staging and the move into the project;
- doctor capture;
- inception filing with the full flags;
- the publish-and-read-back verification (50 posts, all fingerprints matched);
- the never-decide boundary (T-998 left for the operator);
- no system changes.

**Where the agent got stuck:**
1. **Run 1:** the init failure from the inherited environment. Not diagnosable from the installer output; AEF
   diagnosed it.
2. **Run 2:** the orchestrator's own over-strict rule.
3. **Run 3, gates fail open before the restart:** the agent noticed and recorded it, but could not fix it itself.
4. **Run 3, onboarding gate blocking its own skip remedy:** escaped via work-on T-001 → onboarding skip.
5. **Run 3, two more gates after `inception start`** (started-work, then G-067).
6. **Run 3, commit to the enclosing `/` repo failing on a stale lock:** fixed in phase 2 with `git init`.

**Onboarding time (run 3):** STEP 2 start → first edit 3 min 41 s (gates failing open) → first gate-authorised edit
~14 min 22 s → first authorised project edit ~19 min 27 s (including the restart between phases). The three
aborted attempts before it cost ~25 min.

## Onboarding evaluation (framework side, for AEF)

What a new user experiences today, in order of impact:

1. **The installer can report success on a failed install** (exit 0, "Installation complete!" after `[x]` lines).
   Highest impact: the user does not know they are broken. (T-4248)
2. **Install from inside another AEF context fails.** Running the installer from a claude-fw session or a worker
   is the normal path for this framework's own users. (T-4248)
3. **Gates fail open until the session restarts, and nothing says so.** A restart notice after
   `fw init --provider claude` (T-4240), and doctor flagging `missing-hook` crashes as a FAIL, would close this.
4. **The project silently joins an enclosing repo.** Task ids, hooks and commits go elsewhere. (T-4251)
5. **The onboarding gate's own exit is blocked.** The first gate a new user meets should be the best-explained one.
   (run-3 F-28; not yet filed by AEF to our knowledge)
6. **31 doctor warnings on a fresh install** teach users to ignore doctor. A fresh project should show 0-3.
7. **Watchtower:** 0.0.0.0 without auth, including a terminal page; and the URL file is wrong under a local bind.
   (T-4239, F-36, F-41)
8. **Dependencies:** PyYAML and Flask are not checked; the pip hint fails under PEP 668. (T-4238)
9. **Inception start → first edit takes three steps** that each surface as a gate (focus, started-work, IW-1).
   `inception start` could set started-work and scaffold IW-1.

**Recommendation for the README:** publish v2.1 as the "instrumented greenfield run". Mark its workaround sections
(Clean environment, STEP 2 pre-checks, onboarding skip path, Watchtower URL) as **"until AEF T-4248 / T-4251 /
T-4239 ship"**, and remove them in a v2.2 after a clean re-run on the fixed master.

## Appendix — run-3 findings as delivered to AEF (P-001)

| id | step | surface | class | severity | observation (as delivered, may be truncated) |
|---|---|---|---|---|---|
| F-01 | STEP-0 | environment | environment | degraded | install.sh does not sanitise inherited FRAMEWORK_ROOT/PROJECT_ROOT; the run only works with an env -u wrapper. |
| F-02 | STEP-0 | environment | environment | friction | The dispatch wrapper writes its results into the target project's .context/, so a greenfield target is never empty after the first dispatched run. |
| F-03 | STEP-2 | install.sh | ux-friction | friction | A .context/ dir with only two non-framework markdown files switched fw init into existing-project mode. |
| F-04 | STEP-0 | this-prompt | prompt-defect | degraded | The preamble's yield-point command cannot run before the install; no pre-install form exists. |
| F-05 | STEP-2 | install.sh | framework-defect | degraded | The installer wrote into /.git/hooks (a repo outside the target, rooted at the filesystem root) instead of giving the new project its own repositor... |
| F-06 | STEP-2 | environment | environment | degraded | A repo rooted at / encloses every directory on the host, so every greenfield install here inherits it (F-05, F-07, F-13, F-16, F-18). |
| F-07 | STEP-2 | install.sh | framework-defect | degraded | Bootstrap commit failed (no HEAD) yet the installer reported every verification step passed and exited 0. The suggested manual fix `git add -A` wou... |
| F-08 | STEP-2 | install.sh | ux-friction | cosmetic | Installer says `fw serve`; prompt says `fw watchtower start`; fw help offers both without saying which is preferred. |
| F-09 | STEP-3 | fw doctor | framework-defect | cosmetic | Doctor warns on a 0.0h-old project about an index it allows 24h to build. |
| F-10 | STEP-3 | fw doctor | framework-defect | friction | Doctor compares the PATH router (by design, T-2854) with the vendored wrapper and calls the difference drift; its 'Refresh' advice would replace th... |
| F-11 | STEP-3 | fw doctor | framework-defect | friction | Host-wide TermLink DM backlog (shared host identity) is counted as 13 project warnings on a minutes-old project, and doctor recommends draining it ... |
| F-12 | STEP-3 | fw doctor | framework-defect | friction | The installer did not start a sidecar watcher and did not mention it; doctor then warns about it. |
| F-13 | STEP-3 | fw doctor | framework-defect | friction | Doctor reports 12 stale, prunable worktrees of the enclosing `/` repo (F-06) as this project's worktrees. |
| F-14 | STEP-3 | fw doctor | framework-defect | degraded | Claude Code picked up the project's hooks mid-session, and every gate hook failed open with missing-hook; doctor's hook exercise reports OK at the ... |
| F-15 | STEP-3 | fw doctor | framework-defect | friction | Init seeds a cron registry but does not generate it, and does not mention it; doctor then warns. The same doctor run also printed 'OK cron: index-r... |
| F-16 | STEP-3 | fw doctor | framework-defect | friction | Doctor counts 1 (a directory, path relative to `/`) where 7 files are untracked, and offers 'remove the orphan' for freshly seeded onboarding tasks. |
| F-17 | STEP-3 | fw doctor | framework-defect | friction | Fresh install produces 31 doctor warnings; the installer's 'doctor passes' hides all of them. |
| F-18 | STEP-3 | fw work-on | framework-defect | friction | Task ids in the new project continue from a foreign .tasks/ in the enclosing `/` repo; focus/knowledge output duplicated. |
| F-19 | STEP-3 | fw work-on | ux-friction | cosmetic | The template ships framework-repo corpus statistics and references to framework-only test files into a new consumer project. |
| F-20 | STEP-3 | fw sidecar | framework-defect | degraded | Draining the inbox from a brand-new project marked 198 messages for other projects as read; there is no undo shown. |
| F-21 | STEP-3 | this-prompt | prompt-defect | friction | The preamble prescribes the draining command, not the peek form. |
| F-22 | STEP-3 | fw git | framework-defect | blocker | The project has no repository of its own; the commit goes to the enclosing `/` repo and fails on its stale lock. fw git gives no hint that the repo... |
| F-23 | STEP-3b | install.sh | ux-friction | friction | The session was partly governed (hooks loaded and ran) but no gate worked; the installer gives no restart instruction for a running agent. |
| F-24 | STEP-3b | this-prompt | prompt-defect | degraded | The env -u workaround covers commands the agent runs, not hooks the harness runs; a restart through the same wrapper may not make governance active. |
| F-25 | STEP-3b | gate:P-002 | ux-friction | friction | Focus is per session key, so a restart in the same project loses it; the first action after the prescribed restart is a gate block. |
| F-26 | STEP-3b | gate:T-532 | framework-defect | friction | The write detector treats 2>&1 as a file write, and the read-only allowlist does not include git -C ... rev-parse. |
| F-27 | STEP-3b | gate:T-532 | prompt-defect | degraded | An install that follows the prompt reaches STEP 4 with a gate that blocks all non-onboarding writes; the prompt has no step for it. |
| F-28 | STEP-3b | gate:T-532 | framework-defect | degraded | The onboarding gate advertises 'fw onboarding skip' but blocks it; the message alone does not get a first-time user out. |
| F-29 | STEP-3b | environment | environment | friction | Restart was needed and sufficient for gates to work; framework path vars are still injected by the dispatch environment, now with this project's va... |
| F-30 | STEP-3b | gate:T-1730 | framework-defect | friction | The framework's own recovery advice for a failed bootstrap commit is refused by its focus-drift gate unless a Tier-2 bypass is used. |
| F-31 | STEP-3b | install.sh | framework-defect | blocker | The installer should have given the project its own repository; it relied on an enclosing repo it did not own. |
| F-32 | STEP-3b | fw git | ux-friction | friction | The first full commit of a vendored project takes over two minutes silently, past the default agent tool timeout. |
| F-33 | STEP-3b | fw git | ux-friction | cosmetic | Fresh install is reported as a drift-and-reinstall; the counts of hooks named (5) and installed (4) differ. |
| F-34 | STEP-4 | fw watchtower | ux-friction | friction | The dashboard does not auto-start after install; a first-time user has to know to run fw serve / fw watchtower start. |
| F-35 | STEP-4 | fw watchtower | doc-defect | degraded | No install output warns that the dashboard binds 0.0.0.0 without authentication, and the help does not document the variable that changes it. |
| F-36 | STEP-4 | fw watchtower | framework-defect | degraded | Under a local-only bind the source-of-truth URL is unreachable, so every verification line written the documented way fails. |
| F-37 | STEP-4 | fw watchtower | framework-defect | friction | Starting the dashboard can open a host firewall port (a system change) even for a loopback-only bind, without asking and without documentation in -... |
| F-38 | STEP-4 | fw watchtower | prompt-defect | cosmetic | The framework allocates a free port itself and writes it into a tracked config file; the prompt and --help describe a fixed default and a manual --... |
| F-39 | STEP-4 | fw watchtower | framework-defect | friction | The page asserts a running autonomous loop on a project where none was started. |
| F-40 | STEP-4 | fw watchtower | framework-defect | cosmetic | Never-run audit is shown as UNKNOWN on one page and PASS on another. |
| F-41 | STEP-4 | fw watchtower | unknown | degraded | Under the default bind (0.0.0.0, no login) the dashboard exposes a browser-terminal surface to the LAN; no install output or help mentions it. |
| F-42 | STEP-4 | fw watchtower | ux-friction | cosmetic | Seeded framework knowledge is presented as this project's decisions/patterns/documentation without a 'seeded' marker. |
| F-43 | STEP-5 | gate:P-002 | prompt-defect | friction | fw inception start sets focus but not started-work, so two more gates (this one, then G-067) stand between it and the first edit; the prompt mentio... |
| F-44 | STEP-5 | gate:T-2194 | doc-defect | friction | The C-001 rule (artifact first) and the G-067 gate (question first) give opposite orders; the gate treats docs/reports/ as 'source files'. The prom... |
| F-45 | STEP-5 | fw inception | framework-defect | cosmetic | The operator-facing review step ships with an unfilled placeholder. |
| F-46 | STEP-5 | fw inception | framework-defect | cosmetic | The foreign counter persists after the project got its own repository; the gap T-008..T-996 is permanent. |
| F-47 | STEP-5 | gate:T-3695 | framework-defect | friction | An append to a non-task file was refused as a task-file write; the message names the real target (commands.log) and still blocks. |
| F-48 | STEP-6 | termlink | ux-friction | cosmetic | A successful post reports 'unconfirmed' with no documented meaning; only a separate readback shows that it landed. **Total:** 48 **By class:** framework-defect 25, ux-friction 10, prompt-defect 6, environment 4, doc-defect 2, unknown 1 **By severity:** blocker 2, degraded 13, friction 23, cosmetic 10' |

48 rows extracted from the run-3 pickup (P-001 to AEF); F-49 was posted to TermLink only.
