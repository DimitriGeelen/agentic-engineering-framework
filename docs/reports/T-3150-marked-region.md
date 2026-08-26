# T-3150 — marked project-owned region in CLAUDE.md replaces the positional split

**Status:** implemented, tests green, uncommitted in the working tree.

## What changed

Three files, nothing else.

### `lib/upgrade.sh`

Three small helpers added immediately above `do_upgrade()`, plus wiring in step `[1/10]`:

| Helper | Job |
|---|---|
| `_fw_project_owned_check FILE` | Prints one line per unmatched marker (empty = well-formed). Always exits 0; the caller decides what an unmatched marker means. |
| `_fw_project_owned_count FILE` | How many regions are opened. |
| `_fw_project_owned_region FILE N` | Prints the N'th region, marker lines included. |

`_fw_project_owned_region` deliberately returns **one region per call** rather than
filling an array: `mapfile -d ''` needs bash 4.4 and this file still has to run under
macOS's bash 3.2 (the same reason `_sed_i` exists here).

Step `[1/10]` now:

1. **Refuses first.** Before extracting anything, it runs the check. Any unmatched
   marker → `REFUSED` on stderr naming the file and the line number, `return 1`.
   Nothing is rewritten, no `.bak` is written, and no later upgrade step runs. Both a
   dangling `begin` and a stray `end` refuse — guessing at to-EOF, or falling through
   to the positional path, would destroy exactly the content the markers were added to
   protect.
2. Extracts the header positionally, as before.
3. Collects every marked region in file order, **skipping any region whose content is
   already contained in the header** (that region sits above `## Core Principle` and is
   therefore already carried). This content de-duplication is what makes a second
   upgrade a no-op.
4. Builds `governance_tail = governance [+ "\n" + regions]` and uses it for *all three*
   consumers of the old `$governance`: the "Already up to date" comparison, the
   `--dry-run` line count, and the `printf` that writes the file. Missing any one of
   those would have made the up-to-date check permanently false and rewritten CLAUDE.md
   on every run.
5. Prints a `KEPT N project-owned region(s)` line — only when regions exist, so the
   no-marker output is unchanged.

With no markers, `regions` is empty, `governance_tail == governance`, and the written
bytes are identical to the pre-change path. Test 4 asserts that mechanically rather than
by inspection (see below).

The comment block above the helpers carries the pre-change expression verbatim, in
backticks, on a line beginning `The previous form was` — that is the control test's
reference point.

### `lib/templates/claude-project.md`

Added the marker pair with a one-line explanation, in `## Project-Specific Rules`.

**Placed ABOVE `## Core Principle`, deliberately.** Everything below that heading in the
template *is* the governance payload that gets copied into every consumer on every
upgrade. A marker pair living down there would be re-extracted from the consumer as a
region and re-appended below governance on each run — the exact duplication rule 3
forbids. Above the line it lands in the header, gets de-duplicated, and stays put.

`lib/harvest.sh` diffs the template against consumers by `##` heading; the addition is
HTML comments only, so it adds no heading and harvest is unaffected.

### `tests/unit/upgrade_marked_region.bats`

Eight tests, no skips. Fixtures only — every consumer CLAUDE.md is written by the test.

## Test results, verbatim

```
$ bats tests/unit/upgrade_marked_region.bats
1..8
ok 1 T-3150: a marked region BELOW ## Core Principle survives the rebuild
ok 2 T-3150 [control]: the pre-change positional form DROPS that region, so the fixture discriminates
ok 3 T-3150: BOTH marked regions survive — the second is not dropped
ok 4 T-3150: no markers => byte-identical to the pre-change positional rebuild
ok 5 T-3150: an UNCLOSED marker refuses the rewrite and names file and line
ok 6 T-3150: a stray end marker also refuses rather than guessing
ok 7 T-3150: running upgrade twice is idempotent — no duplication, second run is a no-op
ok 8 T-3150: a region ABOVE ## Core Principle is kept once, not duplicated
```

```
$ bats tests/unit/upgrade_fresh_machine_simulation.bats
1..11
ok 1 fresh-machine: vendored bin/fw runs --version in scrubbed env
ok 2 fresh-machine: vendored bin/fw upgrade --dry-run completes in scrubbed env
ok 3 fresh-machine: vendored bin/fw upgrade --dry-run shows the bare-from-consumer + auto-clone handoff plan
ok 4 fresh-machine: vendored tree ships reviewer catalogues alongside lib/reviewer (G-011 pairing)
ok 5 fresh-machine: fw reviewer smoke-run resolves vendored catalogues in scrubbed env (G-011 guard)
ok 6 fresh-machine: vendored tree ships runtime-referenced git/audit scripts (G-001 payload completeness)
ok 7 fresh-machine: missing secret-scan is LOUD and strict mode blocks (G-001 no-silent-skip)
ok 8 T-2793 AC4: live (non-dry-run) fw upgrade safely overwrites its own currently-executing bin/fw
ok 9 T-2793: vendored consumer agrees with itself about its version
ok 10 T-2793: the router reaches the consumer's own CLI with no global install
ok 11 T-2793: the router ignores a STALE global install when the project has its own
```

```
$ bats tests/unit/lib_upgrade.bats
1..12
ok 1 upgrade: do_upgrade --help shows usage
ok 2 upgrade: do_upgrade --help shows what gets upgraded
ok 3 upgrade: do_upgrade rejects unknown option
ok 4 upgrade: do_upgrade rejects nonexistent directory
ok 5 upgrade: do_upgrade rejects project without .framework.yaml
ok 6 upgrade: do_upgrade rejects upgrading framework itself
ok 7 upgrade: do_upgrade --dry-run shows dry run mode
ok 8 upgrade: do_upgrade shows version info
ok 9 upgrade: do_upgrade shows current version match
ok 10 upgrade: detects resume.md drift vs lib/templates/resume-md.md and refreshes with .bak
ok 11 upgrade: resume.md matches template — reports OK, no .bak written
ok 12 upgrade: missing resume.md — created from template
```

**Note on the invocation.** The task specified `bash tests/unit/*.bats`. That form does
not run bats tests — bash sources the file, `load`/`@test` are undefined, and it exits
after a pile of "command not found" noise with no test ever executed. That is a false
green of exactly the shape this repo keeps finding: an invocation that cannot see its
subject reads identically to one that looked and was satisfied. All three suites were run
with `bats <file>` (Bats 1.13.0, on PATH at `/usr/local/bin/bats`).

## Did the `[control]` test actually fail against the old expression?

**Yes — verified two ways, and the second is the stronger one.**

**1. Within the control test itself.** It recovers the pre-change header expression from
the source comment, applies it to the same fixture the fix is tested against, and appends
the template governance — reproducing the old rebuild exactly. Against that output:

- `PROJECT_HEADER_MARKER_LINE` **present** and `Four Constitutional Directives`
  **present** — proof the expression ran and produced the header it was supposed to
  produce, so a green assertion below is not a recovery that silently returned nothing.
- `REGION_ONE_PAYLOAD` **absent**, `## Project Completion Rules` **absent** — the old
  expression dropped the below-the-line region. That is the defect, reproduced.

**2. The whole suite was run against the pre-change `lib/upgrade.sh`** (`git show
HEAD:lib/upgrade.sh`, restored afterwards; the file is byte-identical to the new version
now). Result — **7 of 8 red**:

```
not ok 1 T-3150: a marked region BELOW ## Core Principle survives the rebuild
#   `[[ "$out" == *"REGION_ONE_PAYLOAD"* ]]' failed
not ok 2 T-3150 [control]: the pre-change positional form DROPS that region, so the fixture discriminates
#   `[[ "$old_expr" == sed\ -n\ * ]]' failed
not ok 3 T-3150: BOTH marked regions survive — the second is not dropped
#   `[[ "$out" == *"REGION_ONE_PAYLOAD"* ]]' failed
not ok 4 T-3150: no markers => byte-identical to the pre-change positional rebuild
#   `old_header=$(eval "$old_expr ...")' failed with status 126
not ok 5 T-3150: an UNCLOSED marker refuses the rewrite and names file and line
#   `[ "$status" -ne 0 ]' failed
not ok 6 T-3150: a stray end marker also refuses rather than guessing
#   `[ "$status" -ne 0 ]' failed
not ok 7 T-3150: running upgrade twice is idempotent — no duplication, second run is a no-op
#   `[ "$(grep -c '^<!-- project-owned: begin -->$' "$proj/CLAUDE.md")" -eq 1 ]' failed
ok 8 T-3150: a region ABOVE ## Core Principle is kept once, not duplicated
```

Two honest qualifications on that run:

- **Tests 2 and 4 went red for a mechanical reason, not a behavioural one.** Both recover
  the old expression from the source comment, and against the old source that comment
  does not exist — the recovery returns empty and the guard `[[ "$old_expr" == sed -n * ]]`
  catches it (test 4 hit the empty-command path first, status 126). This is the documented
  and intended failure mode of the recovery technique borrowed from
  `verification_extractor_anchoring.bats`: the control's job is to be red when it has lost
  its reference point. Their *behavioural* content is proven by the in-test assertions in
  (1) above, which run against the recovered expression while the fix is in place.
- **Test 8 passes against both old and new code, and is not claimed as a defect test.**
  Content above `## Core Principle` always survived; test 8 is the duplication guard for
  rule 3 — it asserts the region is kept exactly *once*. It measures the new
  de-duplication only in the sense that a naive implementation appending every region
  unconditionally would make it red.

Tests 1, 3, 5, 6 and 7 are unambiguous: they fail against the old code and pass against
the new, on identical fixtures.

## Not done / out of scope

- **Not committed** — changes are in the working tree for parent review, as instructed.
- No worktree was created; all work is in the main checkout.
- Only `lib/upgrade.sh`, `lib/templates/claude-project.md` and the new bats file were
  touched. `bin/fw`, `lib/config.sh`, `agents/audit/audit.sh` and `web/blueprints/config.py`
  were not opened — `git status` confirms they still carry only the other session's edits.
- The vendored `.agentic-framework/lib/upgrade.sh` copy in this repo was **not** refreshed;
  that is `fw vendor self`'s job and would have exceeded the file allowlist.
