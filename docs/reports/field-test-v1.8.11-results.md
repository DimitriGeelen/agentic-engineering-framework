# Field evidence for v1.8.11 (bleeding-edge after v1.8.10)

Positive field tests from other agents are the release approval (T-4146). One row per fix;
a fix with no positive row blocks the no-ask release path.

| Fix | 055-agentic-fleet-cockpit (e63ffd423, vendored, 2026-10-14, msg 913410c4) | 832-Workflow-designer (1146a7450) | ring20 |
|---|---|---|---|
| fw upgrade (vendored, fresh clone, dry run first) | WORKS — doctor 0 FAIL before/after | upgraded, healthy (0 reverted) | — |
| T-4127 / T-4081 Watchtower decisions + detector (G-114) | WORKS — nothing staged; 0 reverted / 60 d; Watchtower restarted onto new code | WORKS (0 reverted) | v1.8.10 live check PASS |
| T-4166 / T-4200 index reconcile + doctor regression | WORKS — upgrade did not abort; audit "no armed stale index entries"; doctor ran to end | — | — |
| T-4149 boundary hook lexer | WORKS — 5/5 outside writes exit 2, in-project 0 | — | — |
| T-4150 budget classifier tokeniser | WORKS — ; rm, $(..), backticks, <(..) blocked; quoted ; not split | — | — |
| T-4145 sidecar PEER-DATA framing | WORKS — body framed under UNTRUSTED header | — | — |
| T-4170 claude-fw restart banner | NOT EXERCISED (session predates wrapper) | — | — |
| T-4108 / T-4125 own-launcher check | BROKEN for a consumer with a tracked bin/fw shim → T-4203 | — | — |
| T-4133 readiness memoisation | — | — | round-1 retest 96.1 s → 43.7 s; round-2 retest pending |

## Round 2 — 832-Workflow-designer on bleeding-edge 495901b5d (2026-10-16, msg 5196b215)

Upgraded from 1146a7450 via re-vendor (39 local fixes re-applied, 0 conflicts, revert scan 0).

| Fix | 832 result |
|---|---|
| T-4210 lint skips non-shell shebangs | WORKS — "2 skipped non-shell shebang", 0 ShellCheck fail |
| T-4122 lint speed | NOT MEASURED (no before timing) |
| fw test lint in a consumer | **BROKEN** — exit 1: Silent-Skip lint reads `.agentic-framework/tests/` (absent in a consumer) → **T-4219** |
| T-4132 upgrade restart notice + doctor currency | WORKS — upgrade NOTE and doctor WARN both seen |
| T-4147 CONTEXT_WINDOW default | WORKS for "explicit value kept" (1000000); 800K default NOT EXERCISED |
| T-4167 stale-index pre-commit guard | WORKS — older .tasks blob refused with remedies; FW_ALLOW_STALE_INDEX=1 passes with Tier-2 WARN |
| T-4171 budget warn/urgent | NOT EXERCISED |
| T-4196 handover --no-push | WORKS for --no-push; push announcement NOT EXERCISED |
| T-4131 truncation names --show; long-body warning | WORKS — --show prints full framed body; 4500-char warning fires, short body silent |
| T-4207 held mail via prompt hook | WORKS for the hook; doctor/audit held-hours WARN NOT EXERCISED |
| T-4211 secret scan without catalogue | NOT EXERCISED (catalogue present; 39-file commit passed, no false hit) |
| T-4203/T-4204 | NOT EXERCISED (budget never critical) |
| T-4209 fw audit --check | WORKS — fabric-coverage 5.7 s vs 54 s for the structure section |

Not yet field-tested by anyone after round 2: T-4122 (speed), T-4137, T-4152, T-4153/T-4154, T-4156,
T-4162/T-4163 (estate pilot not yet live), T-4170, T-4171, T-4191, T-4197, T-4203/T-4204, T-4208,
T-4211, T-4216; partly: T-4147 (default), T-4196 (announcement), T-4207 (WARN).

## Round 3 — 832-Workflow-designer on bleeding-edge 956f05f36 (2026-10-17, msg 26c3e3cf)

Upgraded via re-vendor (38 local fixes re-applied, 0 conflicts; their 101-script sweep green).

| Fix | 832 result |
|---|---|
| T-4219 fw test lint in a consumer | WORKS — exit 0 (211 pass, 54 warn, 0 fail; Silent-Skip NOT APPLICABLE), was exit 1 |
| T-4223 /gaps register parse once + concurrent gauges | WORKS — real register 10-11 s → 3.8-4.1 s (5 runs, load 13); remainder is 832's own slowest gauge. (A suggested follow-up, T-4247, was closed as not needed: gauges already run only for watching gaps.) |

Other field results since round 2: 1409 upgraded 1.8.3 → 1.8.10 healthy (doctor 0 FAIL) and found G-117 (upgrade
drops consumer text in CLAUDE.md governance sections, T-4232); 1023 confirmed the env-leak mechanism behind T-4222.

## Round 4 — ring20 (proxmox-ring20-management) on bleeding-edge 112c098b9 (2026-10-17, msg 0d463b3e)

Upgraded vendored ed683536a → 112c098b9 (v1.8.10+579) from a pinned clone; their commit 6aa9e807c, rollback c4dce8461.

| Fix | ring20 result |
|---|---|
| T-4250 delegate writes the project-correct fw path | WORKS — `fw task delegate T-2400` wrote `.agentic-framework/bin/fw reviewer T-2400 …` (Verification, Updates close path and dry-run hint; no `bin/fw` anywhere); reviewer PASS auto-ticked the AC; `--status work-completed` ran the delegation-written line with exit 0 and completed. Was: 9 of 11 closes refused with exit 127. |

Side findings from the same upgrade: (a) step [1/10] rewrote CLAUDE.md governance sections before the vendor step's
T-3850 refusal, leaving CLAUDE.md ahead of the installed code (filed as T-4278); (b) doctor 3 FAIL before and after
(their pre-existing settings.json hook drift); (c) 2 merge conflicts in their locally patched files, resolved locally.

## Round 5 — ring20-dashboard on bleeding-edge a75c25472 (2026-10-17/18, msg 49af751f)

Installed a75c25472 (1.8.10+454) plus their 37 local patches, zero fuzz; upgrade ALL OK; doctor 0 FAIL before and
after; fast lane 16734 passed before, after 6 order-dependent failures in test_t1831 (pass alone; known class there).

| Fix | ring20-dashboard result |
|---|---|
| T-4132 Watchtower restart notice after upgrade | WORKS — "NOTE Watchtower (pid 161) predates the upgraded web/ files - restart it" |
| T-4171 budget warn/urgent reach the operator | WORKS — "BUDGET URGENT (T-4171): context ~91% of 900000 … restart at 95%" |
| T-4208 receiver census | WORKS — one receiver |
| T-4147 CONTEXT_WINDOW | their explicit 900000 honoured; the default itself not exercised |
| T-4122/T-4210, T-4167, T-4170, T-4196, T-4197, T-4156, T-4131, T-4207, T-4211, T-4203/T-4204 | NOT EXERCISED (no shellcheck; no restart yet; no --commit handover; etc.) |

Security findings from a review they ran on our code:
- **A — CONFIRMED, release blocker: T-4286.** lib/estate_push.py refuses a private key only by catalogue pattern
  NAME, and redact() leaves the key body; a missing or broken catalogue redacts nothing. Not live anywhere yet.
- **B — not reproduced:** shell_write_scan.py depth cap (ctx.depth < 4); a task-file truncate inside 0..6 levels of
  `bash -c` was still reported. Second look at what is skipped past depth 4 is optional.
- Docs suggestion: pin the full 40-char sha in upgrade docs.

## Round 6 — dimitri-mint-dev greenfield v2.2 run 4 on bleeding-edge fb8caf3b3 (2026-10-18, msg 86d31421)

Installer from bleeding-edge (`--branch bleeding-edge`, recorded deviation), NO v2.1 workarounds; cross-checked by a
clean-container smoke (ubuntu:24.04, their T-126 S1). 46 findings (24 framework-defect; 3 blocker).
Record: /opt/0909-aef-greenfield-v22/.context/install-findings/aef-install-20261018T090519Z-dimitrimintdev/.

| Fix | Result |
|---|---|
| T-4248 inherited env ignored | WORKS (workstation and container) |
| T-4248 "with a warning" | **FAILS** — install.sh prints none; the vendored fw warns later on every call → T-4298 |
| T-4248 failed step → non-zero/FAILED | NOT EXERCISED (covered by tests/unit/t4248_install_init_failure.bats) |
| T-4248 ~/.local/bin backup | WORKS in the container; skipped on the workstation (files identical) |
| T-4251 own repo, installer-created dir | WORKS; the / or HOME case not exercised |
| T-4252 plain inbox safe | WORKS (no cursor moved) |
| T-4261 WARN count | WORKS; failed-bootstrap half not exercised |
| T-4265 onboarding skip | WORKS, also through a live T-532 gate |
| T-4257 one INFO line | WORKS |
| T-3083 doctor speed | WORKS — 25 s / 40 s workstation, 10 s container |

New from this run: blocker cascade F-20 → F-21 → F-25 — a no-TTY `fw` call from a non-project cwd auto-ran `fw init`
there (T-2746, promoted to now); the accidental project's hooks went live; T-559 then blocked the real target.
Security F-34: `watchtower start` adds a UFW rule to Anywhere even for a loopback bind → T-4297.

## Round 7 — dimitri-mint-dev greenfield level-2 run in a throwaway container (2026-10-18, msg 65d06812)

Ubuntu 24.04 container, no mounts, Claude Code installed inside, dedicated token via `docker exec --env-file`
(record grepped for the token: clean). Phase 1 (install) 205 s, phase 2 (fresh session in the project) 283 s,
total 8 m 37 s; governance active after restart, first gate-authorised edit at 5 m 34 s. 19 findings (11 framework
defects), against 43.6 min and 46 findings on the workstation (run 4). Level 1 (scripted, no credential): 3 m 25 s.

| Fix | Verdict |
|---|---|
| T-4248 inherited env ignored, backup | PARTIAL — env ignored and backup WORKS; still no warning → T-4298 |
| T-4251 own repo | WORKS |
| T-4252 plain inbox safe | WORKS — but prints a traceback, exit 1, when termlink is absent → T-4308 |
| T-4261 WARN count | PARTIAL (detail not given) |
| T-4265 onboarding skip | WORKS |
| T-3083 doctor speed | WORKS — 6 s |

New, only visible on a clean machine: **blocker** — Watchtower cannot start, `markdown2` missing, nothing installs it,
PEP 668 blocks pip → T-4304. Also `/embeddings` 500 on an empty project → T-4305; `watchtower stop` reports failure on
a zombie → T-4306; the P-013 render gate false-positives on the task template comment naming web/app.py → T-4307.

## Release cut — 2026-10-18, master e42aa41bf, tag v1.8.11

Operator answered "yes, release v1.8.11" after the explicit question (fixes without a positive field test were listed
in it). Fixes that shipped with **no field result yet** — NOT EXERCISED, verified by tests and on this host only:

| Fix | What | Re-test asked of |
|---|---|---|
| T-4303 | hooks route when bin/fw does not parse (G-118) | 055, 832 |
| T-2746 | no implicit fw init outside a project | dimitri-mint-dev |
| T-4298 | inherited-env notice once (install.sh), fw warns once per shell | dimitri-mint-dev |
| T-4304 | Watchtower names missing Python modules | dimitri-mint-dev |
| T-4305 | /embeddings empty state, no 500 | dimitri-mint-dev |
| T-4307 | render gate ignores HTML comments | ring20 (T-2406), dimitri-mint-dev |
| T-4308, T-4312 | inbox NOT CHECKED without termlink | dimitri-mint-dev |
| T-4297 | no firewall change without opt-in | dimitri-mint-dev |
| T-4264 | git global options read-only; git -c gated | 832 |
| T-4232 | CLAUDE.md upgrade refuses instead of dropping project lines | 1409, 832 |
| T-4286 | estate push-key leak | ring20-dashboard |
| T-4296, T-4284, T-4283, T-4314 | init without HOME; boundary-gate false positives; orphan receiver; ledger audit outside git | — |
| T-4249 | (from round 4) | 1409 |

Test-only changes (no field test applicable): T-4293..T-4295, T-4300..T-4302, T-4313, T-4318.

## Round 8 — on the released v1.8.11 (e42aa41bf), 2026-10-18 (T-4328)

**ring20 (proxmox-ring20-management, T-2406, msg 69eca905):** upgrade 112c098b9 → v1.8.11 from a pinned tag clone,
rc 0; 7 locally patched files 3-way merged clean; post-overlay verify 0 mismatches.

| Fix | Verdict |
|---|---|
| T-4307 render gate ignores template comments | **WORKS** — fresh build task (unmodified template, 0 commits) closed with no render refusal |
| T-4250 | **WORKS** (their G-235 closed) |
| T-4232 CLAUDE.md refusal | NOT EXERCISED — "Already up to date", nothing of theirs inside managed sections |
| T-4297 firewall | NOT EXERCISED — no ufw on that CT |

**dimitri-mint-dev (T-130, msgs ecb1d433, e17f5580):** upgrade 1.8.10 → 1.8.11, doctor 0 failures; README A+
byte-identical to their v2.2.1; testbed L1 against master: all 8 checks pass.

| Fix | Verdict |
|---|---|
| T-4297 no firewall change without opt-in | **WORKS** — a Watchtower restart left ufw byte-identical |
| T-4298 installer inherited-env warning | **WORKS** — L1 verdict diff vs bleeding-edge: T-4248-env-warning FAILS → WORKS |
| T-4308 inbox exit 3 without termlink | **WORKS** (L1) |
| T-4170, T-4171, T-4114/T-4126/T-4149 | **WORKS** |
| T-4232 CLAUDE.md upgrade | WORKS — no project lines removed (their project section only names the project) |

Pending from them: a level-2 run with prompt v2.2.1 for T-2746, T-4304, T-4305, T-4307, T-4312.

## Round 9 — dimitri-mint-dev level-2 container run on v1.8.11 (T-133, msg 3f53e5e9, 2026-10-18)

master e42aa41bf, prompt v2.2.1, throwaway container, token from Infisical. Phase 1 208 s, phase 2 241 s, rc 0,
leak-clean, 11 findings, all fingerprints in the computed format. Verdicts read from the record.

| Fix | Verdict |
|---|---|
| T-4298 inherited-env line | **WORKS** — exactly one line naming FRAMEWORK_ROOT, PROJECT_ROOT; install landed in the target |
| T-4248 backup, T-4251, T-4265, T-4261, T-3083 (doctor 9 s) | **WORKS** |
| T-4308 / T-4312 inbox without termlink | **WORKS** — NOT CHECKED, exit 3 |
| T-4304 Watchtower missing modules | **WORKS** — one line naming flask_socketio, markdown2 + apt command; no traceback (cosmetic F-05: a port-allocation line precedes it) |
| T-4305 /embeddings | **WORKS** — HTTP 200; all 37 nav pages 200 |
| T-4307 render gate | **WORKS** |
| T-2746 no silent init | **WORKS** — re-tested by hand (the run's header used a non-existent verb; prompt defect on their side): exit 1 "not in an AEF project", nothing created |
| T-4297 firewall | no change made; printed-advisory path NOT EXERCISED (no ufw) → F-07, T-4330 |

New findings filed: F-07 → T-4330 (no advisory when ufw absent); F-02 → T-4331 (installer's doctor exit 2 vs manual 0);
F-06 → T-4306 (stale pid now blocks start and restart); F-08 → T-4332 (start exits 1 after "Health check passed");
F-03 → T-4333 (skipped onboarding tasks stay active); F-09 → T-4334 (G-020 title vs Policy label); F-11 → existing
T-2054 (close clears focus; next commit blocked).
Committed to report: 832 (T-4303, T-4264, T-4232), 055 (T-4303), ring20-dashboard (T-4286), 1023 (general).

## Findings

- **T-4203** (055 item 7): `_fw_is_own_launcher` / `cmd_classify._Ctx` refuse a consumer's tracked
  `bin/fw` shim, so `bin/fw git commit` and `bin/fw handover --commit` are refused at critical
  budget — the wrap-up commands CLAUDE.md prescribes. Blocks the no-ask release path until fixed
  or the release notes tell consumers what to do.
- **T-4204** (055 follow-up, pre-existing): the commit-checkpoint allowance admits an env-prefixed
  launcher (`PROJECT_ROOT=/x … fw git commit`) that the classifier refuses.
- **T-4219** (832 round 2): `fw test lint` exits 1 in every vendored consumer (Silent-Skip lint reads
  the framework's own tests/, which a consumer lacks). Must be fixed before v1.8.11.
