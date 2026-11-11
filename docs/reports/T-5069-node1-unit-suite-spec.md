# T-5069 — AEF unit suite on node1: job spec for ring20

**For:** proxmox-ring20-management (builds the node1 entry and environment).
**Decision:** operator yes, 2026-11-09 (via ring20 msg e40ef0fc, confirmed to AEF directly the same day).
**Status:** measured on the AEF host on 2026-11-09; every number below says how it was obtained. Nothing here has run on node1 yet.

## 1. Command per file

Exactly what `agents/audit/unit-suite.sh` runs today, one test file per job, with the working
directory at the repository root and a private temp dir per job:

```bash
# bats file
cd "$REPO" && TMPDIR="$JOBTMP" BATS_TMPDIR="$JOBTMP" timeout -k 10 900 bats --tap "tests/unit/<file>.bats" < /dev/null

# pytest file
cd "$REPO" && TMPDIR="$JOBTMP" timeout -k 10 900 \
  env -u FORCE_COLOR PY_COLORS=0 NO_COLOR=1 PYTHONDONTWRITEBYTECODE=1 \
  python3 -m pytest "tests/unit/<file>.py" -q -rf -p no:cacheprovider --color=no < /dev/null
```

- **Result file:** the combined stdout+stderr of the command (bats TAP or pytest summary), plus the exit code. AEF grades it the way `unit-suite.sh` does: bats `not ok` lines, pytest `FAILED` lines; exit 124 means the per-file cap was hit (undetermined, not green).
- **Files:** `tests/unit/*.bats` plus `tests/unit/test_*.py` and `tests/unit/*_test.py`: 1,642 files in this measurement.
- **Per-file cap:** 900 s here. node1 is about 3x slower per core (ring20 appendix B), so the slow files below need the node's 1800 s job cap.

## 2. Toolchain and dependencies (versions installed on the AEF host)

| Tool | Version |
|---|---|
| bash | 5.2.21 |
| bats-core | 1.13.0 |
| python3 | 3.12.3 |
| git | 2.43.0 (a few tests create their own temp repos) |
| jq | 1.7 |
| tmux | used by some tests (skipped list covers the ones that need a live server) |

Python packages imported by the code under test (exact versions here):

```
cryptography==41.0.7
flask==3.1.2
flask-socketio==5.6.1
python-socketio==5.16.1
python-engineio==4.13.1
httpx==0.28.1
jinja2==3.1.6
markdown2==2.5.4
markupsafe==3.0.3
mcp==1.26.0
ollama==0.6.1
pygments==2.19.2
pytest==9.0.2
qrcode==7.4.2
pillow==11.3.0
sqlite-vec==0.1.6
tantivy==0.25.1
werkzeug==3.1.5
PyYAML==6.0.3
```

`playwright` (1.55.0) is installed here but only the browser tests use it, and those are not in `tests/unit`.

**Correction (2026-11-10, found on node1, T-5073):** the list above missed three packages, because the first scan did not read Python embedded in bats files and could not see namespace packages. `tests/unit/bvp_auto_promote.bats` and `bvp_auto_promote_enable.bats` failed on node1 with `ModuleNotFoundError: No module named 'ruamel'` and pass here. Add:

```
ruamel.yaml==0.19.1
jsonschema==4.25.1
openai==2.21.0
```

**Hashes:** not included. Producing sha256 hashes needs the wheels, and AEF did not download them on its own initiative. ring20 can generate the hash-pinned list from these exact versions when it builds the environment (`pip download` + `pip hash`, or `pip-compile --generate-hashes`).

## 3. What needs network, loopback, or this host's live services (measured)

Method: every file was run on the AEF host inside a fresh network namespace (`unshare -n`), with the same commands as above.

| Run | Condition | Result |
|---|---|---|
| A | no network, loopback DOWN, full repo | 1,590 pass, 51 fail, 1 hit the 900 s cap |
| B | the 52 from A again, loopback UP | 35 pass, 17 still fail |
| C | those 17 with normal network | 16 pass, 1 fails (`doctor_hook_counters.bats`, a known red on the AEF baseline, not a network matter) |

So:
- **Loopback must be allowed** for this entry: 35 files start a local server (Watchtower, sidecar receiver) and talk to it over 127.0.0.1. ring20 offered loopback per entry.
- **Skip on node1 (16 files):** they pass here with network and fail without it even with loopback. Almost all use the real TermLink runtime or hub, a live tmux server, or doctor probes of this host's services:

```
fw_mode_detection.bats
t1719_index_one_post_write.bats
t3537_wm_task_class.bats
t3595_cleanup_scope.bats
t3651_termlink_cleanup_guards.bats
t3698_mcp_termlink_runtime_pin.bats
t3766_review_credential.bats
t3779_termlink_runtime.bats
t4249_termlink_restart_on_exit.bats
t4281_wm_scratchpad_fence.bats
t4651_polluted_tmux_server.bats
t4722_termlink_hub_runtime_discovery.bats
t4781_per_project_tmux.bats
test_doctor_litellm_ollama.bats
test_doctor_scope_tags.bats
test_govd_envelope.py
```

These keep running on the AEF host, so nothing loses coverage. The list is from one run; a file that is flaky offline could be missing from it.

## 4. Code package size

| Package | Compressed (gzip -6) |
|---|---|
| shallow clone with its `.git` | 384 MB |
| tree without `.git` | 233 MB |
| tree without `.git`, `.context/handovers`, `.context/message-archive`, `.context/reviews/evidence` | 58.0 MB |
| **git bundle of that trimmed tree, one commit** | **46.2 MB** |

The three excluded folders are history (old handovers, archived peer mail, review evidence) that the code under test does not read.

**The tests need a git repository (measured, runs D and E).**

| Run | Package | Result |
|---|---|---|
| D | trimmed tree, no `.git`, loopback up, all 1,642 files | 137 fail; 120 of them beyond the 17 from run B |
| E | the same tree with a fresh one-commit git repo, those 120 files | 76 pass, 44 still fail |

So the package to stage is a **git bundle of the trimmed tree with one commit: 46.2 MB**, one file under the 64 MB limit. On node1: `git clone <bundle> repo`, then run the jobs in `repo/`. It needs to be rebuilt for each code version AEF wants tested.

**Built by `bin/fw test bundle [--ref REF] [--out FILE] [--max-mb N]` (T-5070, 2026-11-09).** Default location: `/opt/999-Agentic-Engineering-Framework/.context/scratch/node1-bundles/aef-unit-suite-<sha12>.bundle`. That folder holds only these bundles, so it is the one to approve on the relay (gitignored, never committed). It builds from a commit (default `HEAD`, never the working folder), leaves out the three folders, makes the one commit with git plumbing (no hooks), and refuses over the cap. It prints the source ref, the bundle commit id, size and sha256. The **bundle commit id is the identity**: the same ref always gives the same id. The file's sha256 is not stable between builds, because git packs the same content slightly differently. First build: source `6a9812165`, bundle commit `a5f1f812c`, 46.3 MB, 23 s; a clone of it has one commit on `bleeding-edge`, and sample tests (including two that need git) pass in it.

**Keep on the AEF host (44 more files):** they fail even with the one-commit repo because they depend on this host itself: the host's cron setup (15), installed git hooks (6), the repository's real location (project-boundary tests, 6), git history deeper than one commit (2), and other host specifics. Rebuilding those on node1 is not worth it:

```
doctor_designer_pin_drift.bats fabric.bats fw_version_output.bats
pre_push_version_monotonicity.bats t1719_ask_routing.bats t2240_pre_push_self_vendor_gate.bats
t2294_pre_push_mcp_drift.bats t2762_upgrade_foreign_source_sha.bats
t3070_audit_schedule_install_delegates_to_registry.bats t3160_cron_dry_run_does_not_write.bats
t3161_empty_registry_does_not_wipe_live_cron.bats t3162_cron_job_exit_status_survives_logger_pipe.bats
t3171_cron_generate_requires_id.bats t3281_cron_orphan_scan.bats t3453_doctor_smoke_inverted_alarm.bats
t3454_gate_contract_collision.bats t3457_act_in_the_world_credentials.bats
t3626_audit_schedule_install_project_root.bats t3768_boundary_quoted_read_paths.bats
t3965_upgrade_task_templates.bats t4149_boundary_parser_differential.bats
t4232_claudemd_governance_consumer_edits.bats t4259_init_cron_generated.bats t4351_cron_reindex_stagger.bats
t4487_boundary_unresolved_git_output.bats t4568_stock_hook_upgrade.bats t4678_old_hook_project_block.bats
t4705_upgrade_commit_list_vendored_external.bats t4773_stale_doorbell.bats t4822_upgrade_in_worktree.bats
test_audit_cron_drift.bats test_audit_cron_registry_generated_drift.bats test_consumer_recover.bats
test_cron_generate_shape.bats test_cron_registry_generated_drift.bats test_index_doctor_rail.bats
test_pre_push_monotonic_ancestor.bats test_secret_scan.bats test_t4432_cron_web_parity.py
test_testhost_controller.py test_tier0_origin.py test_upgrade_template_sync_t3955.py
upgrade_fresh_machine_simulation.bats version_relation.bats
```

**Split in one line:** of 1,642 files, about 1,580 go to node1 (35 of them need loopback), and about 60 stay on the AEF host: the 16 from section 3, these 44, and the one known red (`doctor_hook_counters.bats`).

## 5. Slowest files (measured here, run A, 12 in parallel, no network)

| File | Seconds here |
|---|---|
| init_project_shape_detection.bats | 900 (hit the cap without network) |
| greenfield_seed_audit_prototype.bats | 565 |
| t2912_upgrade_hook_regen_convergence.bats | 552 |
| secret_scan_name_axis.bats | 526 |
| secret_scan_span_rule.bats | 520 |
| init_validation_ordering.bats | 379 |
| t4705_upgrade_commit_list_vendored_external.bats | 364 |
| t2861_init_bgisolation.bats | 343 |
| t2862_greenfield_first_inception_e2e.bats | 338 |
| t2991_verification_preflight.bats | 297 |

These times are inflated: with 12 files running at once and no network, some tests wait on connection timeouts. Run A took 43 minutes against 5-7 for a normal suite run here. At node1's ~3x slower cores the top five would be near or over the 1800 s cap.

## 6. What this does not settle

- Hashes for the Python packages (see section 2).
- Whether node1's own TermLink or tmux would make some of the 16 skipped files pass; AEF keeps them local either way.
- How results flow back into AEF's audit (the nightly report and the pre-push gate read `.context/audits/unit-suite/LATEST.yaml`). That is AEF's next task once the entry exists.

## 7. ring20's contract (received 2026-11-09, msg 5716f844; valid once runme `t2626-aef-unit` has run)

- **Entries** `aef.bats` and `aef.pytest`; **env** `aef-unit-1` (a toolchain name, not a hash): a venv with the 19 pins above plus their dependencies, wheels only, hashes taken once on node1 and installed with `--require-hashes`; bats-core 1.13.0, git, jq.
- **Per job:** ref `repo.bundle` = AEF's bundle, staged once per code version from `.context/scratch/node1-bundles/` via `pool:stage`; every job reuses its sha. The job bundle is a folder with ONE file `target.txt` holding one path (`tests/unit/foo.bats` for `aef.bats`, `tests/unit/test_x.py` for `aef.pytest`); the fixed runner refuses anything else. It clones the bundle to `repo/` and runs the exact command from section 1 with a private TMPDIR, `timeout -k 10 900`, loopback on, under an 1800 s cap, 6 GB memory, 4 GB scratch.
- **Result:** `unit.log` (stdout+stderr, plus a last line `aef-run-unit: exit N`), gzip+base64 in `result_json`; `exit_code` = the test run's.
- **Submit** (on the AEF host): `pool-client.py submit-cmd FOLDER --client 999-Agentic-Engineering-Framework --entry aef.bats --env aef-unit-1 --name NAME --unit U --step S --ref repo.bundle=SHA`. Up to 12 run at once on node1.
- **Do not send before ring20's go.**

## 8. Trial on node1 (T-5071, 2026-11-09/10)

Bundle of `6a945030e` (bundle commit `9d74378b`, 46.3 MB) staged with `pool-client ref-put` (162 chunks); six jobs submitted with `submit-cmd`, client `999-Agentic-Engineering-Framework`, env `aef-unit-1`. First attempt waited on refs because node1's ref store was full (2 GiB cap, ring20's side); after ring20 raised it to 100 GiB the bundle was re-staged and the jobs ran within their 1 h window.

| File | Here | node1 | Same? |
|---|---|---|---|
| t3051_exec_bit_gates.bats (needs git) | 5 ok | 5 ok, exit 0 | yes |
| t4673_tags_reach_mirror.bats | 14 ok | 14 ok, exit 0 | yes |
| t5067_tmp_name_per_writer.bats | 2 ok | 2 ok, exit 0 | yes |
| test_t3642_escalation_negation.py | 20 passed | 20 passed, exit 0 | yes |
| test_t5063_escalation_scan_yaml_str.py | 8 passed | 8 passed, exit 0 | yes |
| test_sidecar_receiver_t3693.py (server on 127.0.0.1) | 52 passed (15 s) | 40 passed, 12 failed (132 s), exit 1 | **no** |

**The one difference, explained:** 11 of the 12 failures are `receiver: server did not come up within 10s`: `fw sidecar receiver start` waits a fixed 10 s for its server (`lib/sidecar_cli.py:964`), and node1 (about 3x slower per core, all 12 slots busy at the time) needed longer. The twelfth (`serve()` returned 3, "a live receiver already serves this agent") is a knock-on: the receiver of the test before it was still registered after its timeout. Loopback itself works on node1 (40 tests of this file talk to the server over 127.0.0.1). The fixed 10 s is an AEF weakness, not a node1 fault: the same start fails on any slow or busy host.

Result format confirmed: `unit.log` ends with `aef-run-unit: exit N`; `pool-result.json` names the dispatch, the checked job sha256 and `outcome`.

## 9. Full run on node1 — interim (T-5073, 2026-11-10/11)

Bundle of `590b7d0bf` (carries T-5072), env `aef-unit-1` then `aef-unit-2` (adds ruamel.yaml, openai). Paused 2026-11-11 ~10:12Z on ring20's node1 health alarm (their new canary; node1 itself ran jobs).

- **Collected:** 1,262 of the remaining-files run, plus 32 + 63 + 16 + 2 earlier; 2 results orphaned by a ring20 restart (republish fix pending on their side); **192 files not yet sent** (`.context/scratch/node1-jobs/listA3.txt`).
- **Every node1 failure re-run here** (same command, same commit): **29 files fail only on node1**, none fails here. Raw table: `docs/reports/T-5073-node1-compare-590b.tsv`.
- **Causes seen so far (first pass, not complete):** node1 sandbox differences, not AEF code: read-only root file system (t4395 writes `/t4395-probe`), open-file limit (t4400 "Too many open files"), `playwright` not installed (test_playwright_server_adoption.py — the spec's claim that only browser tests need it was wrong), the bundle's excluded `.context/handovers` (test_search_inclusion_set.py), no systemd scope / tmux / live TermLink (t4647, t3277, t4426, termlink.bats, t4641, ...), host cron (bvp_auto_promote_enable.bats), and 2 files at the 900 s cap (init_project_shape_detection, t5061). The rest were read on 2026-11-11 (below).
- **Bundle check (corrected 2026-11-11 16:50Z):** the first clone re-run inherited `FRAMEWORK_ROOT`/`PROJECT_ROOT` from the agent shell, both pointing at the live repo, so some tests ran the live repo's code. Re-run with `env -u CLAUDECODE -u FRAMEWORK_ROOT -u PROJECT_ROOT` in a fresh clone of `aef-unit-suite-590b7d0bf2b8.bundle`: **git_identity_check, t2452, t3062 and test_t4386_doctor_perf.py fail in the clone too** (no local git identity, no untracked `.context` state, and the costs.sh bug below), so they are bundle/environment causes, not node1. The other 9 pass in the clone, so for those node1's sandbox is the cause.
- **Final batches (A3/A4, 192 files):** 190 exit 0, 2 fail: test_t4386_doctor_perf.py (real bug, below) and verification_pipe_buffer.bats test 2 (expects exit 141 from SIGPIPE; passes here and in the clone, so the sandbox's pipe/signal setup differs). The 2 results orphaned by ring20's restart were republished (their fix, node1 release c8e5e76c2f29) and collected: both exit 0.
- **Classification of all 29:**

  | Class | Files | Action |
  |---|---|---|
  | Sandbox limit (read-only `/`, open-file limit, no `unshare --pid`) | t4395, t4400, t5008 | ask ring20 / local-only |
  | Root without permission override: `Permission denied` writing a file the test made read-only (t4493 line 74) | t4493 (seen); t2990, t3636, t4858, t2293 likely the same | ask ring20 to confirm; else local-only |
  | Missing tool: playwright, opencode, tmux, systemd, live TermLink | test_playwright_server_adoption.py, t4844, t4217, t5060, t4426, t3277, t4647, termlink.bats, t4641 | local-only (or ask for playwright) |
  | Missing host state: no git identity, host cron, `.context/handovers` left out of the bundle | git_identity_check, t2452, t3062 (both run `fw doctor`/audit on the checkout), bvp_auto_promote_enable, test_search_inclusion_set.py | local-only; git_identity_check should set its own identity |
  | CPU speed: 5 ms per-fire budget measured at 6.1–9.1 ms | hook_telemetry, hook_telemetry_race | local-only (timing budget is host-specific) |
  | 900 s cap | init_project_shape_detection, t5061 | raise the cap for these two or local-only |
  | No network or listener in the sandbox | t4332 (Watchtower health check), t3580 (dispatcher env.json not written) | local-only; t3580 to be read once more |
  | Pipe/signal setup | verification_pipe_buffer (expects SIGPIPE exit 141) | local-only or ask ring20 |
  | **Real bugs (2)** | t4108 `test_ancestry_probe_sees_a_claude_named_ancestor` (T-5075); `lib/costs.sh` path fallback (test_t4386_doctor_perf) | fix |

- **The real bug (t4108):** the test makes a fake `claude` wrapper that `exec`s Python, and `exec` replaces the wrapper, so no process named `claude` is left in the chain. The probe returns True here only because this agent session itself runs under Claude Code; on node1 it correctly returns False. The test proves nothing locally. Fix: keep the fake `claude` alive as the parent (run the child, do not `exec`). Same pattern, milder: git_identity_check relies on the host's git identity.
- **The second real bug (lib/costs.sh:30):** when `GREEN` is unset it sources `${FRAMEWORK_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/lib/colors.sh`. Sourced from `bash -c` with no `FRAMEWORK_ROOT`, `$0` is `bash`, so the path resolves one level above the repo and the source fails. It never shows locally because agent shells export `FRAMEWORK_ROOT`. Fix: resolve from `${BASH_SOURCE[0]}`, not `$0`.
- **Next:** classify the 13; decide per class: add to the local-only list, ask ring20 for an env change (playwright, open-file limit), or fix the test; send the 192; then wire results into the nightly report.
