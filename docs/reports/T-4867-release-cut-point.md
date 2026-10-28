# T-4867 — v1.8.15 release cut-point: the latest bleeding-edge point whose fixes are all field-confirmed

## Answer

**There is no useful cut point yet. Applied strictly, the rule lets nothing past v1.8.14 itself, which is where
master already is.** Commit 5 after v1.8.14 (1282db1d9, T-4317: hook context uses `CLAUDE_PROJECT_DIR`) is the first
to carry a consumer-facing fix with no field verdict. Only one confirmed fix lands before it, and only half of it
(T-4227). Even the earliest tag on the line, v1.8.14-be.1, brings 66 consumer-facing fixes with no verdict. Up to
be.3 the count reaches 271. Those are the ~1000 commits of 18–22 October, which landed before the per-fix field-test
loop started. The later tags are mostly confirmed: be.6 … be.11 add none unconfirmed. But master can only
fast-forward, so a release cannot include be.6 without everything before it. Since v1.8.14 there are 466
consumer-facing fix tasks: 123 have WORKS (directly, or FAILS that was then fixed and WORKS) and 343 do not. A strict
cut leaves out all 123.

There are two ways forward, and the operator chooses:

- **(a) Count a general upgrade run as enough for the early bulk.** ring20-dashboard upgraded v1.8.14 → be.46 in one
  step: doctor 0 FAIL before and after, fast lane 17031 passed, no rollback. Every other reporting peer runs be.31 or
  later with a clean doctor. Under that looser rule, **release up to be.46**. It includes all 123 confirmed fixes and
  330 consumer-facing fixes that only an upgrade run covers. It leaves out 13 fixes from be.47, be.48 and HEAD, which
  no peer has installed yet.
- **(b) Use the cherry-pick release-branch model** (T-4868, inception).

## Method

- **Range.** `v1.8.14..HEAD` on bleeding-edge: 1744 commits. HEAD is 14 commits past be.48. The baseline is
  v1.8.14 (2328ae76b), which is what `origin/master` holds.
  - v1.8.14 was a security-hotfix tag on master. The v1.8.14-be.1/2/3 tags are on bleeding-edge but not in v1.8.14,
    so they fall inside this range. They are treated as cut-point candidates, the same as v1.8.15-be.N.
  - Tag positions are commit counts from v1.8.14 (`git rev-list --count`).
- **Fix tasks.** A fix task is the T-id that opens a commit subject. It is placed at the first tag range where one of
  its commits touches something other than bookkeeping.
  - Bookkeeping commits touch only `.tasks/active|completed/`, `.context/`, `.fabric/` or `.agentic-framework/` (the
    self-vendor mirror). They are excluded. That removes task files, handovers, ACs, episodic, vendor-sync-only commits
    and the daily generators.
  - 613 fix tasks remain.
- **Classification rule.** It is stated once and applied mechanically.
  - A fix is **consumer-facing** if any of its non-bookkeeping commits touches a path that ships to consumers: `bin/`,
    `lib/`, `agents/`, `policy/`, `web/`, `tools/`, `.tasks/templates/`, `install.sh`, or
    `.claude/{commands,skills,hooks}/`. That is the vendored set plus the install and template surfaces.
  - Every other fix is **internal**: only `tests/`, `docs/`, `CLAUDE.md`/`FRAMEWORK.md`, research artefacts and field
    reports. Internal fixes never block a cut point.
  - The rule overcounts a little. Framework-only tooling under `lib/`, such as release and the unit-suite runner,
    counts as consumer-facing. That cannot change the answer: the first blocking commit changes hook context, which is
    plainly consumer-facing.
- **Field status sources.**
  - `docs/reports/field-test-v1.8.15-results.md`: the verdict tables by tag and project, the `- T-XXXX: WORKS` lines,
    and the be.37 … be.45 rows that name fixes (T-4777, T-4779, T-4797, T-4812 … T-4819, T-4831, T-4832, T-4836,
    T-4838, T-4845).
  - The v1.8.11, v1.8.13 and v1.8.14 field-test reports, for task ids whose bleeding-edge commits fall in this range.
    For example, T-4426, T-4350 and T-4453 were field-tested on the v1.8.14-be tags. Those rows name the report they
    come from.
- **Field status values.**
  - **WORKS**: at least one positive verdict. The field-test report row says who and at which tag.
  - **FAILS/PARTIAL → X**: a negative or partial verdict, followed up by fix X. It counts as confirmed only if X has
    WORKS.
  - A fix with mixed verdicts whose follow-up chain ends in WORKS counts as WORKS. This covers the file-list chain
    T-4692 → T-4697 → T-4705 → T-4712 → T-4717 → T-4723/T-4724, T-4675 → T-4683, and T-4720 → T-4740.
  - **UNCONFIRMED — covered by upgrade run, no specific verdict**: a peer's full upgrade installed it (at or before
    be.46, ring20-dashboard's v1.8.14 → be.46), but nobody reported on this fix.
  - **UNCONFIRMED — not yet installed by any peer**: be.47, be.48 and HEAD.
- **Composite verdicts are not split per fix.** Examples are ring20's be.37 "15 WORKS, 2 FAILS", 832's lettered parts
  E/F, and dimitri-mint-dev's A/B/C/D/H. Where the report names no fix, they count only as upgrade-run coverage.

## The cut point

| Candidate | Unconfirmed consumer-facing fixes it would ship | Confirmed fixes it would leave out |
|---|---:|---:|
| v1.8.14 (master today) | 0 | 123 (all) |
| commit 4 after v1.8.14 (e46947031) | 0 | 122 (ships half of T-4227 only, so not useful) |
| v1.8.14-be.1 (earliest tag) | 66 | 108 |
| v1.8.15-be.3 | 271 | 86 |
| v1.8.15-be.11 | 277 | 45 |
| v1.8.15-be.17 | 280 | 32 |
| v1.8.15-be.46 (rule (a)) | 330, all covered by an upgrade run | 0 |
| v1.8.15-be.48 / HEAD | 340 / 343 | 0 |

**Strict rule: there is no useful cut point. Rule (a): be.46.**

be.46 leaves out these 13 consumer-facing fixes, none of which a peer has installed:

- be.47: T-4787, T-4789, T-4791, T-4840, T-4849, T-4851, T-4852, T-4853
- be.48: T-4854, T-4863
- HEAD: T-4857, T-4858, T-4859

ring20-dashboard filed T-4851 … T-4859 and can confirm them at its next upgrade.

**The 123 confirmed consumer-facing fixes, all left out by a strict cut at v1.8.14:**
T-3924, T-4115, T-4227, T-4235, T-4332, T-4350, T-4367, T-4368, T-4395, T-4396, T-4399, T-4405, T-4408, T-4409,
T-4413, T-4421, T-4426, T-4453, T-4479, T-4485, T-4499, T-4509, T-4510, T-4511, T-4512, T-4513, T-4529, T-4554,
T-4555, T-4568, T-4626, T-4627, T-4628, T-4629, T-4630, T-4636, T-4647, T-4650, T-4652, T-4653, T-4654, T-4656,
T-4657, T-4658, T-4659, T-4661, T-4662, T-4665, T-4666, T-4667, T-4670, T-4672, T-4673, T-4675, T-4678, T-4679,
T-4680, T-4681, T-4682, T-4683, T-4684, T-4685, T-4687, T-4688, T-4689, T-4690, T-4691, T-4692, T-4693, T-4694,
T-4695, T-4697, T-4699, T-4700, T-4701, T-4703, T-4704, T-4706, T-4707, T-4708, T-4711, T-4712, T-4714, T-4716,
T-4717, T-4718, T-4720, T-4723, T-4724, T-4726, T-4730, T-4731, T-4732, T-4733, T-4740, T-4741, T-4748, T-4751,
T-4753, T-4754, T-4756, T-4757, T-4762, T-4763, T-4766, T-4769, T-4777, T-4779, T-4783, T-4795, T-4797, T-4812,
T-4813, T-4814, T-4816, T-4817, T-4819, T-4830, T-4831, T-4832, T-4836, T-4838, T-4845.

**Failed chains that do not yet end in WORKS:**

- T-4515 → T-4552. dimitri-mint-dev reported the partial and could confirm.
- T-4631 → T-4639. ring20-dashboard could confirm.
- T-4775 → T-4843 (worker binary and version line for every worker kind). 832 could confirm.

**Who could confirm the unconfirmed fixes.**

- The be.1 … be.3 bulk (271 fixes): any peer that has upgraded past the tag, which is every reporting peer. No tester
  is assigned to any of them. Appendix A of the field-test report groups them by area (upgrade/vendor, hooks/gates,
  …), which is the natural way to hand them out.
- Later fixes: the per-tag rows below name a tester, taken from the field-test report's "still unexercised, and who
  reports" lists.

## Per-tag overview

"Commits since v1.8.14" gives the tag's position. Each fix is counted at the tag where it first lands.

| Tag | Date | Commits since v1.8.14 | Fix tasks first landing here | Consumer-facing | of which not confirmed | Internal |
|---|---|---:|---:|---:|---:|---:|
| v1.8.14-be.1 | 2026-10-20 | 256 | 113 | 81 | 66 | 32 |
| v1.8.14-be.2 | 2026-10-20 | 274 | 6 | 6 | 4 | 0 |
| v1.8.14-be.3 | 2026-10-20 | 320 | 21 | 16 | 16 | 5 |
| be.1 | 2026-10-20 | 356 | 14 | 12 | 10 | 2 |
| be.2 | 2026-10-21 | 622 | 106 | 88 | 81 | 18 |
| be.3 | 2026-10-22 | 987 | 146 | 105 | 94 | 41 |
| be.4 | 2026-10-22 | 1027 | 12 | 10 | 4 | 2 |
| be.5 | 2026-10-23 | 1064 | 17 | 14 | 2 | 3 |
| be.6 | 2026-10-23 | 1079 | 6 | 5 | 0 | 1 |
| be.7 | 2026-10-23 | 1093 | 4 | 3 | 0 | 1 |
| be.8 | 2026-10-23 | 1099 | 1 | 1 | 0 | 0 |
| be.9 | 2026-10-23 | 1121 | 6 | 6 | 0 | 0 |
| be.10 | 2026-10-23 | 1140 | 5 | 4 | 0 | 1 |
| be.11 | 2026-10-23 | 1168 | 6 | 4 | 0 | 2 |
| be.12 | 2026-10-23 | 1184 | 4 | 3 | 1 | 1 |
| be.13 | 2026-10-23 | 1191 | 1 | 1 | 0 | 0 |
| be.14 | 2026-10-23 | 1193 | 1 | 1 | 0 | 0 |
| be.15 | 2026-10-23 | 1211 | 4 | 4 | 1 | 0 |
| be.16 | 2026-10-24 | 1239 | 7 | 4 | 0 | 3 |
| be.17 | 2026-10-24 | 1252 | 4 | 3 | 1 | 1 |
| be.18 | 2026-10-25 | 1305 | 19 | 15 | 10 | 4 |
| be.19 | 2026-10-25 | 1316 | 5 | 4 | 2 | 1 |
| be.20 | 2026-10-25 | 1333 | 6 | 2 | 2 | 4 |
| be.21 | 2026-10-25 | 1338 | 2 | 1 | 0 | 1 |
| be.22 | 2026-10-26 | 1367 | 11 | 6 | 2 | 5 |
| be.23 | 2026-10-26 | 1373 | 1 | 1 | 0 | 0 |
| be.24 | 2026-10-26 | 1378 | 2 | 2 | 1 | 0 |
| be.25 | 2026-10-26 | 1384 | 2 | 2 | 1 | 0 |
| be.26 | 2026-10-26 | 1395 | 4 | 1 | 1 | 3 |
| be.27 | 2026-10-26 | 1419 | 8 | 8 | 6 | 0 |
| be.28 | 2026-10-26 | 1424 | 2 | 1 | 1 | 1 |
| be.29 | 2026-10-27 | 1431 | 1 | 0 | 0 | 1 |
| be.30 | 2026-10-27 | 1433 | 1 | 0 | 0 | 1 |
| be.31 | 2026-10-27 | 1440 | 3 | 2 | 0 | 1 |
| be.32 | 2026-10-27 | 1443 | 1 | 1 | 0 | 0 |
| be.33 | 2026-10-27 | 1447 | 2 | 0 | 0 | 2 |
| be.34 | 2026-10-27 | 1452 | 1 | 0 | 0 | 1 |
| be.35 | 2026-10-27 | 1462 | 2 | 1 | 1 | 1 |
| be.36 | 2026-10-27 | 1466 | 2 | 0 | 0 | 2 |
| be.37 | 2026-10-27 | 1471 | 1 | 1 | 1 | 0 |
| be.38 | 2026-10-27 | 1481 | 3 | 3 | 2 | 0 |
| be.39 | 2026-10-27 | 1483 | 1 | 1 | 1 | 0 |
| be.40 | 2026-10-27 | 1499 | 6 | 6 | 1 | 0 |
| be.41 | 2026-10-27 | 1515 | 5 | 5 | 5 | 0 |
| be.42 | 2026-10-27 | 1553 | 8 | 6 | 2 | 2 |
| be.43 | 2026-10-27 | 1568 | 1 | 1 | 0 | 0 |
| be.44 | 2026-10-27 | 1581 | 1 | 1 | 1 | 0 |
| be.45 | 2026-10-27 | 1599 | 4 | 3 | 2 | 1 |
| be.46 | 2026-10-28 | 1644 | 8 | 8 | 8 | 0 |
| be.47 | 2026-10-28 | 1698 | 10 | 8 | 8 | 2 |
| be.48 | 2026-10-28 | 1730 | 3 | 2 | 2 | 1 |
| HEAD | 2026-10-28 | 1744 | 3 | 3 | 3 | 0 |

## Fixes by tag range

Kind: consumer-facing or internal (rule above). Internal fixes never block a cut point. "x @ be.N" means project x reported WORKS on tag be.N.

### v1.8.14-be.1 (v1.8.14..v1.8.14-be.1, 2026-10-20) — 113 fix tasks

Confirmed or failed-then-followed-up (all consumer-facing unless marked):

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-3924 | consumer | WORKS — 832-Workflow-designer @ v1.8.14-be.3 (v1.8.14 report) | fw config set/get resolve keys against the registry case-insensitively (inception_commit_l |
| T-4227 | consumer | WORKS — 010-termlink @ be.3 | usage errors no longer logged as hook crashes; lib/hook-crashes.sh acknowledge empties the |
| T-4298 | internal | WORKS — dimitri-mint-dev @ v1.8.11 (v1.8.11 report) | hook-warning test runs in its own throwaway project (it wrote missing-hook entries into th |
| T-4332 | consumer | WORKS — dimitri-mint-dev @ bleeding-edge 58b62c5a5 (v1.8.13 report) | watchtower start exits 0 after 'Health check passed' — detect_lan_ip always status 0 (no i |
| T-4350 | consumer | WORKS — dimitri-mint-dev @ v1.8.14-be.1 (v1.8.14 report) | incremental reindex updates small deltas in place (no full-size scratch copy) |
| T-4367 | consumer | WORKS — ring20-dashboard @ v1.8.13 candidate on bleeding-edge (v1.8.13 report) | git diff/log/show/diff-tree/diff-index/whatchanged --output is a write, not a read (allowl |
| T-4368 | consumer | WORKS — ring20-dashboard @ v1.8.13 candidate on bleeding-edge (v1.8.13 report) | classify git check-attr, check-ref-format, diff-index as read-only (diff-index --output st |
| T-4395 | consumer | WORKS — dimitri-mint-dev @ bleeding-edge 58b62c5a5 (v1.8.13 report) | boundary read check judges >=2-slash paths under an existing top-level dir outside KNOWN_T |
| T-4396 | consumer | WORKS — ring20-mgmt @ v1.8.13 candidate on bleeding-edge (v1.8.13 report) | safe-commands accepts read-only for/while/until loops (body + word list judged per command |
| T-4399 | consumer | WORKS — 832-Workflow-designer @ v1.8.14-be.3 (v1.8.14 report) | corpus_spec keeps BPMN default="<flow>" on gateways/activities through parse/emit; hard er |
| T-4405 | consumer | WORKS — ring20-mgmt @ v1.8.13 candidate on bleeding-edge (v1.8.13 report) | bare-from-consumer upgrade handoff replays the caller's argv exactly (minus target and --f |
| T-4408 | consumer | WORKS — ring20-mgmt @ v1.8.13 candidate on bleeding-edge (v1.8.13 report); dimitri-mint-dev @ bleeding-edge 58b62c5a5 (v1.8.13 report) | GIT_DIR/GIT_WORK_TREE/GIT_COMMON_DIR/GIT_INDEX_FILE/GIT_OBJECT_DIRECTORY prefixes admitted |
| T-4409 | consumer | WORKS — ring20-mgmt @ v1.8.13 candidate on bleeding-edge (v1.8.13 report); dimitri-mint-dev @ bleeding-edge 58b62c5a5 (v1.8.13 report) | git judged from its effective cwd (tracked cd, payload cwd, PWD only when it is PROJECT_RO |
| T-4413 | consumer | WORKS — dimitri-mint-dev @ bleeding-edge 58b62c5a5 (v1.8.13 report) | recall-health cron check WARNs (not installed yet) when no crontab is deployed; FAIL kept  |
| T-4421 | consumer | WORKS — 832-Workflow-designer @ v1.8.14-be.3 (v1.8.14 report) | fabric describe reads .mjs/.cjs/.mts/.cts headers and skips a leading shebang (832) |
| T-4426 | consumer | WORKS — ring20-dashboard @ 89c4823f3 (v1.8.14 report) | claude-fw tmux wrap redraws Claude Code (C-l) after copy mode ends, on attach and on resiz |

**Consumer-facing, UNCONFIRMED (66)** — all covered by upgrade runs (every reporting peer has since upgraded past v1.8.14-be.1), none has a specific verdict; any upgraded peer could confirm. Subjects: field-test report Appendix A.

<details><summary>ids</summary>

T-4228, T-4306, T-4311, T-4315, T-4316, T-4317, T-4320, T-4330, T-4331, T-4336, T-4340, T-4341, T-4342, T-4343, T-4344, T-4346, T-4347, T-4348, T-4349, T-4351, T-4363, T-4364, T-4369, T-4370, T-4373, T-4374, T-4375, T-4377, T-4379, T-4381, T-4386, T-4387, T-4388, T-4389, T-4390, T-4391, T-4392, T-4394, T-4397, T-4400, T-4403, T-4406, T-4410, T-4411, T-4412, T-4416, T-4417, T-4418, T-4419, T-4422, T-4423, T-4424, T-4425, T-4427, T-4430, T-4431, T-4432, T-4433, T-4436, T-4438, T-4441, T-4445, T-4448, T-4449, T-4450, T-4452

</details>

**Internal (31)**, do not block: T-4246, T-4328, T-4338, T-4339, T-4345, T-4365, T-4366, T-4371, T-4372, T-4376, T-4378, T-4382, T-4383, T-4384, T-4385, T-4393, T-4398, T-4414, T-4420, T-4428, T-4429, T-4434, T-4435, T-4439, T-4440, T-4442, T-4443, T-4444, T-4446, T-4447, T-4451

### v1.8.14-be.2 (v1.8.14-be.1..v1.8.14-be.2, 2026-10-20) — 6 fix tasks

Confirmed or failed-then-followed-up (all consumer-facing unless marked):

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4115 | consumer | WORKS — dimitri-mint-dev @ v1.8.14-be.2 (v1.8.14 report) | classify 'fw task stale' as read-only in the task-gate allowlist (doctor advises it at nul |
| T-4453 | consumer | WORKS — dimitri-mint-dev @ v1.8.14-be.2 (v1.8.14 report) | fw upgrade run from a framework checkout vendors that checkout, prints Commit: <sha> (<tag |

**Consumer-facing, UNCONFIRMED (4)** — all covered by upgrade runs (every reporting peer has since upgraded past v1.8.14-be.2), none has a specific verdict; any upgraded peer could confirm. Subjects: field-test report Appendix A.

<details><summary>ids</summary>

T-4454, T-4455, T-4456, T-4457

</details>

**Internal (0).**

### v1.8.14-be.3 (v1.8.14-be.2..v1.8.14-be.3, 2026-10-20) — 21 fix tasks

Confirmed or failed-then-followed-up (all consumer-facing unless marked):

| Fix | Kind | Field status | What it does |
|---|---|---|---|

**Consumer-facing, UNCONFIRMED (16)** — all covered by upgrade runs (every reporting peer has since upgraded past v1.8.14-be.3), none has a specific verdict; any upgraded peer could confirm. Subjects: field-test report Appendix A.

<details><summary>ids</summary>

T-4094, T-4180, T-4190, T-4256, T-4268, T-4458, T-4459, T-4460, T-4461, T-4462, T-4464, T-4467, T-4468, T-4469, T-4481, T-4482

</details>

**Internal (5)**, do not block: T-4380, T-4463, T-4470, T-4472, T-4484

### be.1 (v1.8.14-be.3..v1.8.15-be.1, 2026-10-20) — 14 fix tasks

Confirmed or failed-then-followed-up (all consumer-facing unless marked):

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4479 | consumer | WORKS — 010-termlink @ be.3 | write scan uses herestrings (SIGPIPE fail-open on >64KB commands under pipefail), sed -i a |
| T-4485 | consumer | WORKS — ring20-dashboard @ bleeding-edge 056573e34 (v1.8.14 report) | git --output check judges the words bash hands git (shared shell_write_scan.git_output_ris |

**Consumer-facing, UNCONFIRMED (10)** — all covered by upgrade runs (every reporting peer has since upgraded past be.1), none has a specific verdict; any upgraded peer could confirm. Subjects: field-test report Appendix A.

<details><summary>ids</summary>

T-4473, T-4474, T-4475, T-4476, T-4478, T-4480, T-4488, T-4490, T-4491, T-4494

</details>

**Internal (2)**, do not block: T-4483, T-4489

### be.2 (v1.8.15-be.1..v1.8.15-be.2, 2026-10-21) — 106 fix tasks

Confirmed or failed-then-followed-up (all consumer-facing unless marked):

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4499 | consumer | WORKS — dimitri-mint-dev @ be.2 | shell write scanner treats a single-quoted fw sidecar send --body as data |
| T-4509 | consumer | WORKS — ring20-dashboard @ be.2 | register G-121 (read-only allowlist bypasses from ring20-dashboard, reproduced on HEAD) an |
| T-4510 | consumer | WORKS — ring20-dashboard @ be.2 | read-only allowlist refuses GNU sed's e command and the e/w flags of s — options whitelist |
| T-4511 | consumer | WORKS — ring20-dashboard @ be.2 | is_bash_safe_command refuses process substitution <( / >( anywhere on the line (quote-awar |
| T-4512 | consumer | WORKS — ring20-dashboard @ be.2 | option checks read the program's argv through one dequoting tokenizer (option_words); find |
| T-4513 | consumer | WORKS — ring20-dashboard @ be.2 | read-only allowlist refuses git grep -O / --open-files-in-pager (any abbreviation, short b |
| T-4515 | consumer | FAILS/PARTIAL → T-4552 (no verdict; could confirm: dimitri-mint-dev (reported the T-4515 partial)) | install-hooks never comments out or drops a consumer's hook lines — old-framework extras s |
| T-4529 | consumer | WORKS — dimitri-mint-dev @ be.2 | a same-hub project is resolvable as a bare --to: _PROJECT_ID_RE accepts four-digit fleet i |

**Consumer-facing, UNCONFIRMED (80)** — all covered by upgrade runs (every reporting peer has since upgraded past be.2), none has a specific verdict; any upgraded peer could confirm. Subjects: field-test report Appendix A.

<details><summary>ids</summary>

T-2657, T-2661, T-2680, T-2698, T-2749, T-2756, T-2768, T-2772, T-2859, T-2861, T-2906, T-2913, T-2958, T-2961, T-2998, T-3079, T-3135, T-3136, T-3143, T-3154, T-3160, T-3162, T-3698, T-3709, T-3715, T-3720, T-3735, T-3762, T-3763, T-3777, T-3778, T-3798, T-3801, T-3811, T-3838, T-3848, T-3853, T-3861, T-3862, T-3863, T-3866, T-4033, T-4048, T-4354, T-4357, T-4358, T-4361, T-4401, T-4407, T-4437, T-4465, T-4486, T-4487, T-4492, T-4493, T-4495, T-4496, T-4497, T-4498, T-4500, T-4501, T-4502, T-4503, T-4504, T-4505, T-4507, T-4514, T-4516, T-4518, T-4519, T-4521, T-4522, T-4523, T-4524, T-4526, T-4528, T-4530, T-4531, T-4536, T-4539

</details>

**Internal (18)**, do not block: T-2721, T-2962, T-3689, T-3712, T-3761, T-3808, T-3809, T-3810, T-4362, T-4415, T-4508, T-4520, T-4525, T-4537, T-4538, T-4540, T-4543, T-4544

### be.3 (v1.8.15-be.2..v1.8.15-be.3, 2026-10-22) — 146 fix tasks

Confirmed or failed-then-followed-up (all consumer-facing unless marked):

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4235 | consumer | WORKS — dimitri-mint-dev @ be.3 | fw upgrade unshallows a shallow source itself instead of refusing — fw_source_fetch_histor |
| T-4554 | consumer | WORKS — dimitri-mint-dev @ be.3 | vendor pre-flight treats files matching a release tag as framework-owned |
| T-4555 | consumer | WORKS — dimitri-mint-dev @ be.3 | fw upgrade regenerates an existing cron source when the renderer changed (not only on job  |
| T-4568 | consumer | WORKS — 010-termlink, dimitri-mint-dev, ring20-mgmt @ be.4 | install-hooks recognises a stock pre-block framework hook by template digest (stock-hook-d |
| T-4626 | consumer | WORKS — dimitri-mint-dev, ring20-dashboard @ be.3 | read-only allowlist refuses sort --compress-program (any abbreviation) and rg --pre / --ho |
| T-4627 | consumer | WORKS — ring20-dashboard @ be.3 | read-only allowlist refuses git ls-remote/fetch --upload-pack (any abbreviation, -u in any |
| T-4628 | consumer | WORKS — ring20-dashboard @ be.3 | read-only allowlist refuses uniq/xxd with a second (output) operand and gunzip without -c/ |
| T-4629 | consumer | WORKS — ring20-dashboard @ be.3 | read-only allowlist admits git remote only bare/-v/show/get-url and git reflog unless expi |
| T-4630 | consumer | WORKS — ring20-dashboard @ be.3 | read-only allowlist refuses journalctl --vacuum-*/--rotate/--flush/--sync/--relinquish-var |
| T-4631 | consumer | FAILS/PARTIAL → T-4639 (no verdict; could confirm: ring20-dashboard (reported the T-4631 partial)) | read-only allowlist refuses git help -w/--web (any abbreviation, short bundle, quoted/expa |
| T-4636 | consumer | WORKS — 010-termlink @ be.3 | run claude-fw and termlink spawn in a systemd scope under agentic.slice, outside login ses |
| T-4647 | consumer | WORKS — 010-termlink, 832 @ be.3 | file dispatch env allow-list fix (SEV-1 T-4635); T-4635 review prompt + bundle |

**Consumer-facing, UNCONFIRMED (93)** — all covered by upgrade runs (every reporting peer has since upgraded past be.3), none has a specific verdict; any upgraded peer could confirm. Subjects: field-test report Appendix A.

<details><summary>ids</summary>

T-4159, T-4160, T-4164, T-4165, T-4169, T-4172, T-4173, T-4174, T-4175, T-4182, T-4183, T-4185, T-4189, T-4192, T-4193, T-4195, T-4198, T-4199, T-4215, T-4221, T-4230, T-4231, T-4234, T-4238, T-4240, T-4241, T-4244, T-4254, T-4258, T-4259, T-4260, T-4263, T-4266, T-4269, T-4272, T-4285, T-4290, T-4292, T-4323, T-4324, T-4326, T-4327, T-4333, T-4334, T-4335, T-4337, T-4352, T-4353, T-4402, T-4506, T-4534, T-4535, T-4541, T-4542, T-4545, T-4547, T-4548, T-4549, T-4550, T-4551, T-4552, T-4558, T-4560, T-4561, T-4562, T-4563, T-4566, T-4571, T-4572, T-4577, T-4578, T-4581, T-4582, T-4584, T-4590, T-4591, T-4594, T-4597, T-4602, T-4607, T-4608, T-4609, T-4612, T-4617, T-4618, T-4622, T-4623, T-4624, T-4633, T-4634, T-4637, T-4638, T-4639

</details>

**Internal (41)**, do not block: T-4325, T-4329, T-4533, T-4546, T-4553, T-4556, T-4557, T-4565, T-4567, T-4569, T-4570, T-4573, T-4575, T-4579, T-4580, T-4583, T-4585, T-4586, T-4587, T-4588, T-4589, T-4592, T-4593, T-4595, T-4596, T-4598, T-4599, T-4600, T-4601, T-4603, T-4605, T-4606, T-4610, T-4611, T-4613, T-4615, T-4616, T-4619, T-4620, T-4621, T-4635

### be.4 (be.3..be.4, 2026-10-22)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4649 | internal | n/a (internal) | record ring20 per-patch triage vs be.3 (37 patches: 5 covered, 3 movable, 9 need extension |
| T-4650 | consumer | WORKS — 010-termlink, dimitri-mint-dev, ring20-mgmt @ be.4 | admit glob FILE operands in sed -n print-only forms (option_words globs mode, kind G); scr |
| T-4651 | internal | n/a (internal) | A-after-B close test on a private tmux server — control, spawn-env builder, run.sh runtime |
| T-4659 | consumer | WORKS — ring20-mgmt @ be.4 | claude-fw PTY line drops inherited FW_*, re-exports only claude-fw's own |
| T-4652 | consumer | WORKS — 010-termlink, dimitri-mint-dev, ring20-mgmt @ be.4 | hooks fail closed when python decoder/matcher is unusable — bash-only degraded scan in che |
| T-4653 | consumer | WORKS — ring20-mgmt @ be.4 | partial-complete finalization re-runs ## Verification (P-011) before archiving |
| T-4660 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | act on submitter replies — classifier, fw issues replies/confirm-close, sync auto-close, o |
| T-4665 | consumer | WORKS — 010-termlink, ring20-mgmt @ be.4 | spawn-env allow-lists TermLink variables by exact name (RUNTIME_DIR, RUNTIME_DIR_FALLBACK, |
| T-4666 | consumer | WORKS — 010-termlink, ring20-mgmt @ be.4 | spawn-env builds the worker PATH by construction (framework bin, resolved claude/termlink/ |
| T-4668 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | CLAUDE.md — submitter replies close issues (confirmed / close-ok), standing routine; T-466 |
| T-4664 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | confirm-close records a submitter's confirmed fix as a WORKS row in docs/reports/field-tes |
| T-4669 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | fw issues reply-ack settles one no-action submitter reply with a reply-acked ledger row (n |

### be.5 (be.4..be.5, 2026-10-23)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4661 | consumer | WORKS — ring20-mgmt @ be.5 | fw upgrade through a linked worktree's bin/fw keeps that worktree as source (no T-3111 aut |
| T-4663 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | board 'Awaiting review' column also admits partial-complete (agent done) tasks without a r |
| T-4670 | consumer | WORKS — ring20-mgmt, 010-termlink, 050 @ be.5, be.6 | paths.sh foreign-dir rule is containment-based (realpath + walk to nearest project root);  |
| T-4671 | internal | WORKS — ring20-mgmt @ be.5 | register-gate test runs in a temp git project; live_repo_guard fails tests that change the |
| T-4672 | consumer | WORKS — ring20-mgmt, 050, 832 @ be.5, be.6 | fw upgrade re-installs the pinned Workflow Designer in consumers that had one installed (d |
| T-4658 | consumer | WORKS — ring20-mgmt @ be.5 | _route_to_operator writes escalation guidance as one line so it cannot change the criterio |
| T-4654 | consumer | WORKS — ring20-mgmt @ be.5 | fabric orphan checks share one location predicate; IPv4/CIDR/host:port/descriptive locatio |
| T-4673 | consumer | WORKS — 010-termlink @ be.5 | release/be tags pushed to every remote and read back with ls-remote; fw mirror status/sync |
| T-4675 | consumer | WORKS — ring20-mgmt, 832 @ be.5 | dispatch worker dirs live under the project (.context/dispatch), /tmp/tl-dispatch is a rea |
| T-4657 | consumer | WORKS — ring20-mgmt @ be.5 | /api/v1 health/ask/ask-stream/search degrade to JSON when the optional LLM/embeddings/sear |
| T-4656 | consumer | WORKS — ring20-mgmt @ be.5 | audit D12 reads $CONTEXT_DIR/bypass-log.yaml (the writer path) and excludes approved incep |
| T-4655 | internal | WORKS — ring20-mgmt, 832, dimitri-mint-dev @ be.5, be.9 | metrics.sh counts stores by YAML parse (indent/prefix-tolerant, ERROR not 0), strips quote |
| T-4676 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | cron estimator sweeps commit their own writes (one commit per sweep, only files they wrote |
| T-4678 | consumer | WORKS — ring20-mgmt, 832 @ be.5 | install-hooks keeps an old non-stock framework hook's project block whole — residue is any |
| T-4674 | internal | n/a (internal) | pin that a --project worker runs the TARGET's fw (two-project fixture); run.sh already re- |
| T-4662 | consumer | WORKS — ring20-mgmt, 050 @ be.5, be.6 | safe-commands no-cwd refusal becomes an explicit contract — _FW_PAYLOAD_CWD opt-in documen |
| T-4667 | consumer | WORKS — ring20-mgmt, 010-termlink, 050, 832 @ be.5, be.6 | checkpoint.sh usage error prints to stderr (via fw_hook_usage_exit), exit 1 kept; bats ass |

### be.6 (be.5..be.6, 2026-10-23)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4677 | internal | WORKS — ring20-mgmt, 832 @ be.6, be.8 | aef-task-lifecycle v4 — plain-language names/notes for the business lens; ids, fw commands |
| T-4681 | consumer | WORKS — ring20-mgmt @ be.6 | finalizing a partial-complete task no longer re-applies the T-4024 empty-Verification auth |
| T-4679 | consumer | WORKS — ring20-mgmt @ be.6 | in_file markers are literal by default, re: prefix opts into regex; MARKER MISSING names t |
| T-4680 | consumer | WORKS — ring20-mgmt @ be.6 | fw upgrade through a framework clone inside the consumer tree (e.g. a tag clone) uses that |
| T-4683 | consumer | WORKS — ring20-mgmt, 010-termlink, 832 @ be.6, be.8 | dispatch shadow guard fires only when a run of that name exists in another root; first cod |
| T-4682 | consumer | WORKS — ring20-mgmt @ be.6 | fw termlink spawn runs the caller-resolved termlink (TERMLINK_BIN wins) by absolute path — |

### be.7 (be.6..be.7, 2026-10-23)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4684 | consumer | WORKS — ring20-mgmt, 050, 010-termlink, 832, dimitri-mint-dev @ be.7, be.8, be.9 | fw init and fw upgrade gitignore .context/dispatch/ in consumers (shared lib/dispatch-giti |
| T-4685 | consumer | WORKS — ring20-mgmt, 050, 010-termlink @ be.7 | FW_TASKS_DIR_OVERRIDE names its project root; bare =1 no longer keeps a value inside anoth |
| T-4686 | internal | WORKS — ring20-mgmt @ be.7 | t4217 test 2 pins every claude-fw tmux-wrap gate (env -i, built PATH, FW_AGENT_SCOPE=0, st |
| T-4687 | consumer | WORKS — ring20-mgmt, 050 @ be.7; ring20-mgmt bats, 050 live @ be.7 | _FW_PAYLOAD_CWD alone derives PROJECT_ROOT (nearest .framework.yaml); no-project git refus |

### be.8 (be.7..be.8, 2026-10-23)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4688 | consumer | WORKS — ring20-mgmt, dimitri-mint-dev, 050 @ be.8, be.9; dimitri-mint-dev @ be.9 | fw upgrade no longer self-vendors its source — a clone used as upgrade source stays byte-i |

### be.9 (be.8..be.9, 2026-10-23)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4689 | consumer | WORKS — ring20-mgmt, dimitri-mint-dev, 010-termlink @ be.9, be.10; ring20-mgmt, dimitri-mint-dev @ be.9 | ignore .fleet-failure-state.json, vector-index-health.json + 13 more; rail tools/working-i |
| T-4691 | consumer | WORKS — ring20-mgmt, 050, dimitri-mint-dev @ be.9; all three @ be.9 | doctor preview pipelines use awk, not head (SIGPIPE 141 under errexit); upgrade advisory c |
| T-4693 | consumer | WORKS — ring20-mgmt, dimitri-mint-dev @ be.9 | watchtower currency reads a fixed /proc start time + 2 s tolerance (no STALE flap after re |
| T-4690 | consumer | WORKS — ring20-mgmt, dimitri-mint-dev, 010-termlink @ be.9, be.10; ring20-mgmt, dimitri-mint-dev @ be.9 | pre-commit writes the closing commit's episodic footprint and carries feedback-stream, so  |
| T-4694 | consumer | WORKS — ring20-mgmt, dimitri-mint-dev, 010-termlink @ be.9, be.10; ring20-mgmt, dimitri-mint-dev @ be.9 | post-commit leaves a committed, clean episodic alone unless pre-commit predicted it, so a  |
| T-4692 | consumer | WORKS — ring20-mgmt, 050, dimitri-mint-dev, 010-termlink @ be.9, be.10 | fw upgrade summary lists the files it left to commit, with one git add line |

### be.10 (be.9..be.10, 2026-10-23)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4696 | internal | n/a (internal) | refuse bats runs whose TMPDIR is inside the repo (setup_suite in each test dir) + lint aga |
| T-4697 | consumer | WORKS — ring20-mgmt, 050, 010-termlink, dimitri-mint-dev @ be.10; ring20-mgmt, 010-termlink, 050 @ be.10 | upgrade commit list names only paths the upgrade journalled |
| T-4695 | consumer | WORKS — 050 @ be.10 | cron outputs are committed by their job or untracked; lib/cron_commit.py run/check rail |
| T-4699 | consumer | WORKS — ring20-mgmt, 010-termlink @ be.10 | session-silent-scanner scans only this project's transcript dirs and skips foreign-cwd ses |
| T-4700 | consumer | WORKS — ring20-mgmt, 010-termlink @ be.10 | session-silent-scanner counts old transcripts instead of logging each, rotates log past 1  |

### be.11 (be.10..be.11, 2026-10-23)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4704 | consumer | WORKS — ring20-mgmt, dimitri-mint-dev, 010-termlink @ be.11; all three @ be.11 | fw upgrade Next steps names the consumer's focused task (or T-XXXX + fw work-on), never th |
| T-4705 | internal | WORKS — ring20-mgmt, dimitri-mint-dev @ be.11 | pin the vendored-consumer external-clone upgrade shape; files-to-commit list prints on be. |
| T-4706 | consumer | WORKS — dimitri-mint-dev, ring20-mgmt, 010-termlink, 050 @ be.11, be.15 | Watchtower keep-alive cron records outages, doctor WARNs on them; tests may not touch the  |
| T-4707 | consumer | WORKS — ring20-mgmt, dimitri-mint-dev, 010-termlink, 050 @ be.11, be.14, be.16; ring20-mgmt, dimitri-mint-dev @ be.11; 010-terml | null-focus block names what voided a close commit; printed close hint pinned end to end |
| T-4708 | consumer | WORKS — ring20-mgmt, 010-termlink, 050 @ be.11, be.15; ring20-mgmt, 010-termlink @ be.11 | doctor hook-config check parses hook commands with shlex; shell tests, builtins and assign |
| T-4709 | internal | n/a (internal) | fence git discovery in the T-4705 bats (lint invariant red blocked every push) |

### be.12 (be.11..be.12, 2026-10-23)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4710 | internal | WORKS — ring20-mgmt, dimitri-mint-dev, 050 @ be.12, be.14, be.16 | pin the close hint for never-committed active files — end-to-end bats runs the printed lin |
| T-4712 | consumer | WORKS — ring20-mgmt, dimitri-mint-dev @ be.12, be.14 | upgrade file list keeps vendored files an earlier uncommitted upgrade left dirty (stamp-ma |
| T-4703 | consumer | WORKS — ring20-mgmt, dimitri-mint-dev @ be.12, be.14 | release work-dir retention (release_scratch_prune after publish) + fw doctor .context/scra |
| T-4713 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | SCRATCH_WARN_GB in web/blueprints/config.py (config registry parity invariant was red, blo |

### be.13 (be.12..be.13, 2026-10-23)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4714 | consumer | WORKS — ring20-mgmt @ be.13 | claude daemon / bg-pty-host never a conversation holder; bg session (comm 2.1.304, argv 'c |

### be.14 (be.13..be.14, 2026-10-23)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4711 | consumer | WORKS — ring20-mgmt, dimitri-mint-dev, 010-termlink @ be.14 | Watchtower keep-alive and start defer to a systemd-managed Watchtower; WATCHTOWER_ENSURE c |

### be.15 (be.14..be.15, 2026-10-23)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4715 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | designer gallery cards show their latest diagram picture (/api/thumb); the page never rend |
| T-4716 | consumer | WORKS — ring20-mgmt, dimitri-mint-dev @ be.15 | /designer opens the base designer's project browser; AEF card list moves to /designer/corp |
| T-4717 | consumer | WORKS — ring20-mgmt, 050, dimitri-mint-dev @ be.15; ring20-mgmt, 050 @ be.15 | upgrade file list runs the helper beside the running lib/upgrade.sh (never via FRAMEWORK_R |
| T-4718 | consumer | WORKS — ring20-mgmt, dimitri-mint-dev @ be.15 | one Designer nav entry (the base designer); drop the 'Designer corpus' entry |

### be.16 (be.15..be.16, 2026-10-24)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4723 | consumer | WORKS — dimitri-mint-dev @ be.16; dimitri-mint-dev @ be.24 | upgrade file list stays bounded on a home-directory consumer |
| T-1555 | internal | n/a (internal) | escalation-drift-daily — 1 generated file(s) |
| T-387 | internal | n/a (internal) | docs-daily — 4 generated file(s) |
| T-4725 | internal | n/a (internal) | t2266/t2267 assert the T-4688 contract (do_upgrade no longer self-vendors agents/ or web/) |
| T-4732 | consumer | WORKS — 050, ring20-mgmt, dimitri-mint-dev, 010-termlink @ be.16, be.17; all three @ be.16; 010-termlink @ be.17 | re-pin designer 0.25.0 -> 0.26.0 (832 announce f482a114, release commit 85ec730c; ?browse= |
| T-4733 | consumer | WORKS — 050 @ be.16 | context_tokens.py decodes the transcript as strict UTF-8 whatever the locale (C/C.UTF-8 us |
| T-4724 | consumer | WORKS — 050, ring20-mgmt, dimitri-mint-dev @ be.16; all three @ be.16; dimitri-mint-dev @ be.24 | upgrade file list (or its reason line) prints under the change counters, before Next steps |

### be.17 (be.16..be.17, 2026-10-24)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4719 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: ring20-mgmt, 010-termlink (installed, not exercised) | close hint pushes to a named remote — git push <upstream/only/origin/first> HEAD, omitted  |
| T-4726 | consumer | WORKS — 010-termlink @ be.17 | inception review hint derives the decide verb from the parsed Recommendation (GO/NO-GO/DEF |
| T-4737 | internal | n/a (internal) | research artifact — 832 designer data-API contract, live probe, per-endpoint recommendatio |
| T-4720 | consumer | WORKS — 010-termlink, ring20-mgmt @ be.17; 010-termlink @ be.17 | fw vendor writes only changed files (rsync -rlpgoD --checksum; cp fallback stages + cmp) s |

### be.18 (be.17..be.18, 2026-10-25)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4727 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 010-termlink (operator-only decide) | fw inception decide warns on stderr and writes '**Diverges from Recommendation**: <REC>' i |
| T-4741 | consumer | FAILS/PARTIAL → T-4762 WORKS (010-termlink @ be.24) | placeholder audit ignores stubs quoted in n-backtick code spans or double quotes; one shar |
| T-4740 | consumer | WORKS — ring20-mgmt @ be.18; 010-termlink @ be.18 | fw vendor writes the pinned designer build and vendor metadata (VERSION, sentinels, .gitig |
| T-4738 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 050 (asked for it) | CLOSE_HINT_PUSH config key (default 1); 0 drops the '&& git push' clause from the update-t |
| T-4742 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | Watchtower key store accepts an Anthropic key (ANTHROPIC_API_KEY env override; /settings f |
| T-4739 | internal | n/a (internal) | v1.8.15 field-evidence report — 80 fixes with peer verdicts, 286 of 359 vendored-path ids  |
| T-4747 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | ignore .context/working/watchtower-outages.jsonl in consumers (T-4706 keep-alive log); reg |
| T-4744 | internal | n/a (internal) | t3221 test 17 pins the invariant, not a call-site count — every commit-allowing NOTE branc |
| T-4746 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | exclude -be tags from the T-4680 in-tree clone upgrade label (t4431 test 11 green) |
| T-4745 | internal | n/a (internal) | rename tests/unit/hermetic.py to _hermetic.py so pytest discovery skips the helper (docstr |
| T-4748 | consumer | WORKS — dimitri-mint-dev @ be.24 | audit grades a generated-but-never-installed crontab WARN (doctor parity) — fresh fw init  |
| T-4729 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | agent-dispatch gate counts only allowed dispatches, keyed per session |
| T-4728 | internal | n/a (internal) | dissolve the Bash rewiring of six task-file gates — check-human-ac-tick already refuses ev |
| T-4730 | consumer | WORKS — 010-termlink @ be.18; 010-termlink @ be.24 | fw termlink dispatch/spawn/wait/record-outcome answer --help |
| T-4734 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | decide on a completed task says archived and names inception correct |
| T-4731 | consumer | WORKS — ring20-mgmt @ be.18; dimitri-mint-dev @ be.24 | boundary gate admits reads of TermLink state (~/.termlink, runtime dir) |
| T-4736 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 050 (reported the finding) | fw upgrade prunes superseded designer builds from the consumer root |
| T-4749 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | Anthropic LLM provider (official SDK, streaming, refusal fallback) registered from env/key |
| T-4750 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | continuous-mode stop driver yields for dispatched TermLink workers (FW_DISPATCHED_WORKER=1 |

### be.19 (be.18..be.19, 2026-10-25)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4698 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: ring20-mgmt (reported the finding) | self-deferral gate skips foreign-qualified task ids (AEF/TermLink/framework/upstream T-X,  |
| T-4721 | internal | n/a (internal) | ship reference launcher install/launcher/aef-start.sh — continue last conversation by defa |
| T-4722 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: ring20-mgmt, 010-termlink | resolve TermLink runtime dir from the running hub (systemd unit env, termlink hub status)  |
| T-4701 | consumer | WORKS — ring20-mgmt @ be.19; dimitri-mint-dev @ be.24 | fw upgrade names every tracked runtime file under .context/working with the literal git rm |
| T-4751 | consumer | WORKS — 010-termlink @ be.24 | boundary gate admits its own remedy — fw config set BOUNDARY_EXTRA_READ_PATHS <outside pat |

### be.20 (be.19..be.20, 2026-10-25)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4642 | internal | n/a (internal) | t2922 fixture pins a free configured port — tests 5/7 were stale since T-3379 (placeholder |
| T-4641 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | fw termlink check reports a termlink whose --version fails (WARN + exit 1) instead of dyin |
| T-4640 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | doctor tags the orphan-UFW-rule WARN [host] (machine state, T-1707); greenfield allowlist  |
| T-4644 | internal | n/a (internal) | fw_self_test.bats runs fw self-test once in setup_file (was 4x, 606s -> ~140s, under the 9 |
| T-4645 | internal | n/a (internal) | t3684 live E2E test_4 gives scratch project B a vendored launcher shim before fw sidecar e |
| T-4646 | internal | n/a (internal) | t3693 live inject leg seeds the per-session ready record (T-3745 contract) instead of the  |

### be.21 (be.20..be.21, 2026-10-25)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4755 | internal | n/a (internal) | v1.8.15 report records ring20 be.18/be.19 verdicts — T-4740 WORKS LIVE, T-4731 WORKS, T-47 |
| T-4753 | consumer | WORKS — ring20-mgmt @ be.21 | sidecar start/stop refuse when an inherited PROJECT_ROOT names another project than the cw |

### be.22 (be.21..be.22, 2026-10-26)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4752 | internal | WORKS — ring20 @ be.23 | store ring20's wc-conformance-mapping/0.1 draft (mapping + checker) verbatim as received m |
| T-4756 | consumer | WORKS — ring20 @ be.22 | bin/fw names an inherited non-project PROJECT_ROOT it discards (one stderr line; silent fo |
| T-4754 | consumer | WORKS — ring20 @ be.22; dimitri-mint-dev @ be.24 | fw upgrade groups tracked runtime files (N x <dir>/* / <glob rule> / path, largest first)  |
| T-4758 | internal | n/a (internal) | v1.8.15 report records ring20 be.21 verdict — T-4753 WORKS |
| T-4761 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | sidecar_cli main installs the rail identity on argparse exit too — T-4753 reorder left --h |
| T-4762 | consumer | WORKS — 010-termlink @ be.24 | placeholder audit strips code spans per block, so a span split across a folded description |
| T-4760 | internal | n/a (internal) | h3 test harness passes PYDECIDE's 5th arg (T-4727 diverges); pin harness argc to the shell |
| T-4759 | internal | n/a (internal) | fw_vendor_completeness test 8 finds the FRAMEWORK.md sentinel write by target, not literal |
| T-4763 | consumer | WORKS — 010-termlink @ be.24 | shell_write_scan honours single-quote literal backticks — tokenise refusal judged on lexer |
| T-4764 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 832 / any designer user | re-pin designer 0.26.0 -> 0.27.0 (832 announce 604650eb, commit 8d2bffe2; io panel shows p |
| T-4765 | internal | n/a (internal) | t4212 fixture is a real project, so fw no longer falls back to the live repo; assert paths |

### be.23 (be.22..be.23, 2026-10-26)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4757 | consumer | FAILS/PARTIAL → T-4766 WORKS (ring20 @ be.24) | fw sidecar settle-sent — a sender settles its own outstanding consult; the sweep stops nud |

### be.24 (be.23..be.24, 2026-10-26)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4767 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 832 / any designer user | re-pin designer 0.27.0 -> 0.28.0 (832 announce 4cd11df7, commit 7eb864d4; io attributes ed |
| T-4766 | consumer | WORKS — ring20 @ be.24 | fw sidecar waiting asks the ack ledger (retry.closed_ids/is_open) so ladder-closed consult |

### be.25 (be.24..be.25, 2026-10-26)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4769 | consumer | WORKS — ring20 @ be.25 | Human-AC tick audit names ticks licensed only by an uncommitted ledger row (summary line,  |
| T-4768 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 832, 010-termlink (next CLI decide) | CLI inception decide commits the decision with its Human-tick provenance row (git commit - |

### be.26 (be.25..be.26, 2026-10-26)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4770 | internal | n/a (internal) | v1.8.15 report records be.18-be.24 verdicts from TermLink, ring20 and dimitri-mint-dev (11 |
| T-4771 | internal | n/a (internal) | v1.8.15 report records TermLink be.24 (T-4762/T-4763/T-4751/T-4730 WORKS) and ring20 be.25 |
| T-4772 | internal | n/a (internal) | v1.8.15 report records TermLink be.25 (clean upgrade; T-4768/T-4769 present, not exercised |
| T-4773 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 010-termlink (next replayed doorbell) | prompt hook names a replayed sidecar doorbell's handled ids as stale; doorbell carries its |

### be.27 (be.26..be.27, 2026-10-26)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4774 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | arc focus AGE/DRIFT warning in handover and fw doctor (lib/arc_focus_health.py, ARC_FOCUS_ |
| T-4780 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 832 / any designer user | re-pin designer 0.28.0 -> 0.29.0 (832 announce 0bd386ad; io field editing, whole io names) |
| T-4775 | consumer | FAILS/PARTIAL → T-4843 (no verdict; could confirm: 832 (reported the T-4775 partial)) | spawn PATH ranks native ~/.local/bin/claude ahead of a caller-resolved npm claude; run.sh  |
| T-4778 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 010-termlink (next reviewer run) | reviewer auto-tick requires positive evidence — never on needs_human, only for a named cat |
| T-4777 | consumer | WORKS — 832 @ be.31; dimitri-mint-dev @ be.41; 832 @ be.31 | close path git writes only when PROJECT_ROOT is the top of its own repo (no staging into a |
| T-4779 | consumer | WORKS — 832 @ be.45 | stale-review counts only reviewed work that differs at HEAD (dist/ release artifacts exclu |
| T-4776 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | run.sh kill watchdog escalates TERM -> KILL after a grace period; timeout recorded in clos |
| T-4782 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | hook lint — no backtick or $( in double-quoted python -c blocks; check-tier0 approval card |

### be.28 (be.27..be.28, 2026-10-26)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4781 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: dimitri-mint-dev, 832 (after a claude-fw relaunch) | claude-fw runs one tmux server per project (fw-agents-<project id>), sidecar finds it, doc |
| T-4784 | internal | n/a (internal) | observation triage c (OBS-457..OBS-604) |

### be.29 (be.28..be.29, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4793 | internal | n/a (internal) | CC-16 supervisor-refusal equivalent route — variant equivalent: field, runner accepts it o |

### be.30 (be.29..be.30, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4794 | internal | WORKS — ring20 @ be.31 | CC-23 judges by variants; question append moves to variant worker-field-accepted (requires |

### be.31 (be.30..be.31, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4795 | consumer | WORKS — 832 @ be.31 | re-pin designer 0.29.0 -> 0.30.0 (832 msg 97852295; field-catalog ref picker, add-field or |
| T-4796 | internal | n/a (internal) | CC-08 equivalent route — expect_equivalent / admissible_histories_equivalent admit takeove |
| T-4783 | consumer | WORKS — ring20 @ be.31 | destructive-command gate refuses a tmux kill-server/kill-session that names no -S/-L socke |

### be.32 (be.31..be.32, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4797 | consumer | WORKS — dimitri-mint-dev @ be.41 | generate_id parses task ids in bash — no 3 forks per file per corpus view (1409: minutes p |

### be.33 (be.32..be.33, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4798 | internal | n/a (internal) | v1.8.15 report records be.26-be.32 verdicts (ring20 be.31: T-4783, T-4794 WORKS) and ring2 |
| T-4799 | internal | WORKS — ring20 @ be.33 | CC-21 refused-before-start gets the equivalent route; CC-10 answer-path steps move to an a |

### be.34 (be.33..be.34, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4800 | internal | n/a (internal) | draft wc v0.3.4 — refusal before rule 1, optional dispatch closure + fence_reject(dispatch |

### be.35 (be.34..be.35, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4801 | internal | n/a (internal) | research — local backend is already GO'd by T-4435 (cond. 1/3/4); recommend option A (stor |
| T-4802 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: ring20, 010-termlink (conformance runs) | lib/dispatch_records.py — local backend for the shared worker contract (§6.2 store + confo |

### be.36 (be.35..be.36, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4804 | internal | n/a (internal) | v1.8.15 report records be.31-be.35 verdicts (832 T-4777/T-4795 WORKS, ring20 T-4799 WORKS, |
| T-4805 | internal | n/a (internal) | conformance runner judges shared base steps plainly; the equivalent is required only on a  |

### be.37 (be.36..be.37, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4803 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: ring20, 010-termlink (conformance runs) | vector hand-backs carry commission (= dispatch id); CC-16 adds handback-wrong-commission - |

### be.38 (be.37..be.38, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4812 | consumer | WORKS — dimitri-mint-dev @ be.41 | close path writes Updates entries inside ## Updates, not after ## Reviewer Verdict |
| T-4806 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 1409 (Dauerlauf armed) | disarm records disarmed_at/disarmed_reason, not a termination; claude-fw brakes a restart  |
| T-4811 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | claude-fw passes TERMLINK_IDENTITY_FILE to termlink spawn via --env so the tmux backend se |

### be.39 (be.38..be.39, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4818 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 010-termlink (T-3600) | CC-16 handback-absent-commission (step 3, confirmed by TermLink T-3600 and ring20); AEF ad |

### be.40 (be.39..be.40, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4815 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | reviewer skips AC-bearing HTML comments in every detector, not only _parse_agent_acs |
| T-4816 | consumer | WORKS — ring20 @ be.40 | tick guard honours git's bare -- (setup_revisions cuts argv there): words after it are pat |
| T-4813 | consumer | WORKS — ring20 @ be.40 | doctor Hook path validation tokenises with shlex, skips bash/sh -c (and python -c/-m, node |
| T-4819 | consumer | WORKS — dimitri-mint-dev @ be.41 | doctor attributes resolver-loop.timer by the service's WorkingDirectory (realpath vs PROJE |
| T-4817 | consumer | WORKS — ring20 @ be.40 | tick guard reads a sidecar --body value through the lexer: every quoting of its text is da |
| T-4814 | consumer | WORKS — ring20 @ be.40 | fw upgrade summary names every .upstream it KEPT/PRESERVED with a diff -u line and keep/ta |

### be.41 (be.40..be.41, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4824 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 055 | record 055's T-483 patch as received (sidecar c00f8e5f) |
| T-4821 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | drop duplicated Work Proposal bullet from consumer template; refresh removes identical CLA |
| T-4820 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 055 | worktree without focus.yaml borrows main checkout's focus — no gate deadlock |
| T-4822 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | fw upgrade in a linked worktree runs the release it was handed (no T-3111 redirect for upg |
| T-4823 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | fw upgrade removes a tracked superseded designer build that matches the published one and  |

### be.42 (be.41..be.42, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4832 | consumer | WORKS — 832 @ be.43 | field-catalog design from two consultations (832 measurements, independent Codex review);  |
| T-4834 | internal | n/a (internal) | worktree-grant gate offer from 055 recorded (hook + tests); converted to inception, DEFER  |
| T-4831 | consumer | WORKS — 832 @ be.43 | GET /api/instances — live tasks on aef-task-lifecycle map; tests, recommendation |
| T-4830 | consumer | FAILS/PARTIAL → T-4845 WORKS (832 @ be.45) | POST /api/validate — thin wrapper over 832's pinned validate-workflow.py run_xml; pin + sy |
| T-4835 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | review seats run with PYTHONDONTWRITEBYTECODE=1 in signed env (no false T-3986 void on __p |
| T-4833 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | consumer CLAUDE.md template carries the Worktree Policy (opt-in only); bats pins template, |
| T-4836 | consumer | WORKS — 832 @ be.43 | deliver the pinned designer validator to consumers (vendor, vendor self, install, upgrade) |
| T-4837 | internal | n/a (internal) | field report — verdicts be.37..be.41 (ring20, TermLink, 832, 055, dimitri-mint-dev) |

### be.43 (be.42..be.43, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4838 | consumer | WORKS — 832 @ be.43 | re-pin designer 0.30.0 -> 0.31.0, build and validator from the same kit (832 msg 9079c0e9) |

### be.44 (be.43..be.44, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4841 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 1409 (re-measure at ~20 worktrees) | create-task holds task-id-allocation only around id+write; children never inherit the lock |

### be.45 (be.44..be.45, 2026-10-27)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4843 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 832 (reported the T-4775 partial) | every worker kind records its binary and version (stderr.log + meta.json) via one run.sh h |
| T-4844 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: 832 (reported the opencode seat finding) | opencode review seat gets a signed SEAT_TMP-only allowance; a seat that exits 0 with no ve |
| T-4845 | consumer | WORKS — 832 @ be.45 | POST /api/validate answers ok:true on every successful check (832 T-1300 §1); errors carri |
| T-4848 | internal | n/a (internal) | ACs; field report — 832 be.43 and dimitri-mint-dev be.41 verdicts |

### be.46 (be.45..be.46, 2026-10-28)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4846 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | owned TMPDIR + orphan sweep for the P-011 gate and fw test; TMP_USE_WARN_PCT WARN in docto |
| T-4847 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | fw config set edits a flat key's own lines in place instead of re-dumping .framework.yaml |
| T-4825 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | focus-drift gate reads a sidecar --body value as data via T-4817's lexer (_blank_data_args |
| T-4828 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | arc-focus AGE only for an old AND quiet arc — active arc reports age on the OK line |
| T-4826 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | smoke test re-probes a failed route once (bounded) before reporting it |
| T-4809 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | audit G-099 check skips never-armed/disarmed sessions (doctor T-4358 parity); regression t |
| T-4807 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | fw config get honours the FW_* env tier for registry keys; --file reads the stored value;  |
| T-4827 | consumer | UNCONFIRMED — covered by upgrade run, no specific verdict; could confirm: any upgraded peer | gate block names the real non-safe segment (culprit loop uses the verdict's git-cwd contex |

### be.47 (be.46..be.47, 2026-10-28)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4840 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: any upgraded peer | audit watchdog writes the timeout record itself, then TERM, then KILL |
| T-4849 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: any upgraded peer | upstream_repo readers use get_yaml_field (folded/quoted-aware) |
| T-4791 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: any upgraded peer | close gate refuses work-completed while the task's vendored changes are unsynced |
| T-4789 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: any upgraded peer | pre-push FAIL refusal names each failing check and its evidence |
| T-4787 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: any upgraded peer | fw note promote reads the inbox as YAML, gives a short name, keeps the full text in descri |
| T-4851 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: ring20-dashboard (filed it) | degraded Tier 0 fallback covers every fast-path class; drift-guard bats |
| T-4853 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: ring20-dashboard (filed it) | check-agent-dispatch fails closed when python3 is broken |
| T-4852 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: ring20-dashboard (filed it) | degraded boundary gate refuses writes under /etc /usr /var /boot |
| T-4860 | internal | n/a (internal) | ACs; field report — 832 be.45, ring20-dashboard be.46 upgrade |
| T-4861 | internal | n/a (internal) | failure output in t2293 t3 and fw_pending_remind test 5; t2293 restore keeps the manifest  |

### be.48 (be.47..be.48, 2026-10-28)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4862 | internal | n/a (internal) | MCP manifest tests run on a private framework tree, never the live repo |
| T-4863 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: any upgraded peer | create-task sets frontmatter keys by anchored line, not text replace |
| T-4854 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: ring20-dashboard (filed it) | /health reports warm-up state; opt-in WATCHTOWER_WARM_BEFORE_SERVE |

### HEAD (be.48..HEAD, 2026-10-28)

| Fix | Kind | Field status | What it does |
|---|---|---|---|
| T-4857 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: ring20-dashboard (security review) | tick guard reads the guarded-path mention from the original command; a sidecar --body is b |
| T-4858 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: ring20-dashboard (security review) | awk tokenizer reads postfix ++/-- as operand-ending, so / after it divides and system()/pi |
| T-4859 | consumer | UNCONFIRMED — not yet installed by any peer; could confirm: ring20-dashboard (security review) | tick guard mention is cwd-aware — a cwd inside the task dir (hook or cd, symlinks followed |

