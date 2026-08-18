# T-3064 — mutation log (A7)

Every load-bearing assertion in `tests/unit/t3064_designer_onboarding_install.bats`
was mutation-tested: a mutant that *should* break it was applied, the suite went
red on that assertion, the mutant was reverted, and the suite went green again.

## Why the run used a mirror, not the tree

Two workers were dispatched onto T-3064 in the same checkout at the same time
(both `claude -p`, both editing `bin/fw`, `lib/upgrade.sh`,
`agents/designer/designer.sh`). Mutating a live file under a second writer would
have handed that writer a corrupted read, so the run was done against a mirror at
`/tmp/t3064-mut` — `FRAMEWORK.md` + the four files under test, with
`tests/test_helper.bash`'s upward walk resolving `FRAMEWORK_ROOT` to the mirror.
Baseline on the mirror: 11/11 green, identical to the live tree.

## Why the driver refuses to say "survived"

The first driver reported three mutants as `*** SURVIVED ***` when in fact none of
them had applied — the mutation string had been mangled through shell quoting and
the `assert` inside it failed, leaving the file untouched. A suite that is green
because nothing was mutated is indistinguishable, in the driver's output, from a
suite that is green because the assertion is weak. That is the same false-green
shape this task exists to close, reproduced inside its own verification.

`run-mutant.sh` therefore fails loudly (exit 2) when the mutant script errors, and
again when the file is byte-identical after it runs. Only a mutant that provably
changed the file is allowed to produce a survived/killed verdict.

## Results — 13 mutants, 13 killed, 0 survived

| # | mutant | subject | killed by |
|---|--------|---------|-----------|
| M1 | drop `chmod 0444` after the vendored copy | `_self_vendor_designer` | t2 |
| M2 | delete the superseded-build prune loop | `_self_vendor_designer` | t3 |
| M3 | invert the source-exists guard (never copy) | `_self_vendor_designer` | t1, t2, t3 |
| M4 | `do_sync --from` → direct `_install_readonly` (verification bypassed) | `do_install` | t4, t5 |
| M5 | absent vendored build returns 0 instead of 5 | `do_install` | t6 |
| M5b | absent-build message drops the artifact path | `do_install` | t6 |
| M6 | remove `designer-pin.yaml` from the sync list | `_self_vendor_policy` | t9 |
| M7 | install writes to `FRAMEWORK_ROOT` instead of `PROJECT_ROOT` | `do_install` | t7 |
| M8 | diverge the vendored pin from the source pin | live tree | t10 |
| M9 | alter the vendored build's bytes | live tree | t11 |
| M10 | remove the already-installed short-circuit | `do_install` | t8 |
| M11 | render the REFUSED branch in the success wording | `fw_init_install_designer` | t13 |
| M12 | silence the absent-build branch | `fw_init_install_designer` | t14 |
| M13 | onboarding does not install the designer at all (the pre-fix state) | `lib/init.sh` | t12, t13, t14 |

Every test t1–t14 is killed by at least one mutant, so no assertion in the file is
inert. M11 and M12 are the two that matter most for A4: they do not break the
install, they only make its *rendering* lie — M11 prints the success line over a
refusal, M12 prints nothing over an absent build. Both are exactly "finished
claiming success with no artifact installed", and an assertion that only checked
the exit code would have let both through.

## Assertion scoping

M4's and M5b's kills depend on t4/t6 anchoring on the **verdict line**, not on a
substring of the whole output:

```
run grep -c '^sha256 MISMATCH — refusing to vendor an unpinned build$' "$TEST_TEMP_DIR/t4.out"
[ "$output" = "1" ]
```

`[[ "$output" == *"MISMATCH"* ]]` would also have passed if any other line in the
command's output happened to carry the word. That exact weakness was found by
mutation testing during A1 — a SKIP mutant survived `*"WARN"*<message>*` because
an earlier `fw doctor` check had already printed a WARN — and the line-scoped form
is what killed it. Note the ANSI strip before the anchor: `designer.sh` colours
unconditionally, so the verdict line does not *start* with its own text and `^`
would otherwise match nothing, failing for a reason that looks like content.

## Reproducing

```
bash /tmp/t3064-mut/run-mutant.sh "<name>" <file-relative-to-mirror> <mutant.py>
```

The mirror is a temp artefact and is not committed; the mutant scripts are small
enough to re-derive from the table above, and the point of the log is the verdict
column, not the tooling.
