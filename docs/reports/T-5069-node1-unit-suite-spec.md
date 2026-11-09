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
