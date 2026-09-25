# T-3487 — Remove human-approval gate on `fw bvp confirm` and `fw arc close`

**Nature of this change:** sovereignty waiver, not a defect repair. Operator
instruction, verbatim (2026-09-26): *"We're going to cut out any human need
for approval. BVP and ARC drivers. That's in the design. So you can implement
it. Will be overwritten later… ask AEF agent."*

Branch: `t3487-remove-bvp-arc-approval-gate`, built on top of
`t3485-bvp-quadrant-value-axis` (`e67d7e95b1b1e3f12b5735d7268c616046c8ee84`).
Final commit: `6adf45442c831c2e6fd7ac32ea2ffb02ca79b6be`. **Not pushed.**

---

## 1. Gates reproduced as refusing, BEFORE the change

Verification method: two ad-hoc `git worktree` checkouts (one at the T-3485
base commit, one at the final T-3487 commit), used only as execution
sandboxes — never touched via `git checkout` in the main checkout, and both
removed (`git worktree remove --force`) once verification was complete. All
edits to `lib/bvp.sh`/`lib/arc.sh` themselves were built via git plumbing
(`git hash-object` / `update-index` / `write-tree` / `commit-tree` against a
scratch index file), never touching the main checkout's working tree.

**Methodological note, read before trusting any "ran via bin/fw" claim
below:** `bin/fw` contains a deliberate re-exec-to-authority mechanism (T-3111,
R7 leg L2, `bin/fw:_fw_reexec_authority`) — when invoked from inside a linked
worktree it silently re-execs the **main checkout's** `bin/fw` with
`FRAMEWORK_ROOT` redirected to the main checkout, so the worktree's own
`lib/*.sh` is never actually loaded unless `FW_NO_REEXEC=1` is set. My first
pass of test-suite comparisons (§5) was invalidated by this — both "before"
and "after" runs were silently executing the *main checkout's* code, which is
why they came back byte-identical. Every number below was re-run with
`FW_NO_REEXEC=1` and I confirm the discrepancy in §5.

For the identity-gate reproduction itself, I bypassed `bin/fw` entirely and
sourced `lib/bvp.sh` / `lib/arc.sh` directly (`source lib/bvp.sh; bvp_dispatch
"$@"`), which sidesteps the reexec question altogether.

**`fw bvp confirm`, BEFORE (base commit), `CLAUDECODE=1`, no override:**
```
$ CLAUDECODE=1 <source lib/bvp.sh from BASE>; bvp_dispatch confirm T-9001
Error: agents must not invoke 'fw bvp confirm' directly (§ACD, M6).
  ...
RC=1
```

**`fw arc close`, BEFORE (base commit), `CLAUDECODE=1`, no override, against a
freshly-created `in-progress` scratch arc with a valid demo file:**
```
$ CLAUDECODE=1 <source lib/arc.sh from BASE>; arc_dispatch close alpha --demo demo.md --decision "shipped"
Error: agents must not invoke 'fw arc close' directly (§ACD/G-062, T-1671).
  ...
RC=1
$ grep '^status:' alpha.yaml
status: in-progress
```

Both refusals reproduced cleanly before any code was touched.

---

## 2. What changed, file by file

Both changes are **opt-in restore switches**, not outright deletion — chosen
because the operator explicitly said "will be overwritten later," which reads
as "removal is provisional," and a switch lets that reversal happen with an
env var rather than a code change.

### `lib/bvp.sh` — `cmd_confirm`

- The call site (`if not acd_gate('confirm', args, ...): return 1`) is now
  wrapped: `if os.environ.get('FW_REQUIRE_BVP_CONFIRM_APPROVAL') == '1': if
  not acd_gate(...): return 1`. Unset (default) → the gate is not invoked at
  all; `confirm` proceeds under `$CLAUDECODE=1` with no
  `--i-am-human`/`--from-watchtower`.
- `acd_gate()` itself is **byte-identical** to before. Its other 4 call sites
  (`weight`, `driver --add`, `driver --remove`, `auto-promote --enable`) are
  untouched — confirmed by diff (see §5, negative controls).
- Added `fm['confirmed_via']` (see §3).
- Docstring, `--help` text, and the printed confirmation line updated to
  document the new env var and the `confirmed_via` field.

Env var: **`FW_REQUIRE_BVP_CONFIRM_APPROVAL=1`** restores the exact original
refusal.

### `lib/arc.sh` — `arc_close()`

- The inline `if [ "${CLAUDECODE:-}" = "1" ] && ...; then <refusal>; fi` block
  is now `if [ "${FW_REQUIRE_ARC_CLOSE_APPROVAL:-}" = "1" ] && [
  "${CLAUDECODE:-}" = "1" ] && ...; then <refusal>; fi`. Unset (default) → the
  whole block is skipped; `arc close` falls through to the (unrelated,
  still-enforced) `--demo`/`--headline-mechanic` checks.
- `arc_abandon()` and `arc_approve_driver --none`
  (`_arc_approve_driver_acd_gate`) are **untouched** — confirmed by diff (see
  §5, negative controls).
- Added `closed_via` (see §3), written via the same
  regex-replace-or-append pattern already used for `demo_evidence`.

Env var: **`FW_REQUIRE_ARC_CLOSE_APPROVAL=1`** restores the exact original
refusal.

### Diff scope, confirmed

```
git diff e67d7e9..t3487-remove-bvp-arc-approval-gate --stat
 lib/arc.sh | 37 ++++++++++++++++++++++++++++++++++---
 lib/bvp.sh | 48 +++++++++++++++++++++++++++++++++++++++---------
 2 files changed, 73 insertions(+), 12 deletions(-)
```
`grep -n QUAD_VALUE_WITHHELD` on both base and after copies of `lib/bvp.sh`
returns byte-identical hits at the same line numbers — the T-3485 value-axis
repair is untouched.

---

## 3. WHO / BY-WHAT-AUTHORITY after the change

`confirmed_by`/`confirmed_at` (bvp) and the pre-existing `closed_at`/
`decision`/`demo_evidence` (arc) no longer distinguish "a human ran this" from
"an agent ran this," because `$USER` is the OS user either way and the
refusal — the only thing that used to *prove* a human was involved — is now
opt-in. I added:

- `confirmed_via: agent | human | watchtower` on `bvp confirm`.
- `closed_via: agent | human | watchtower` on `arc close` (arc frontmatter
  previously had **no** who/how field at all for closure).

Derivation (identical three-way split the removed gate used to enforce):
`--from-watchtower` → `watchtower`; else `--i-am-human` → `human`; else
`$CLAUDECODE == '1'` → `agent`; else (plain human terminal, gate never fired
for this case anyway) → `human`.

**Verified, not assumed** (worktree-sourced runs, `lib/bvp.sh`/`lib/arc.sh`
from the AFTER commit):

```
$ CLAUDECODE=1 <bvp confirm T-9001, no flag>
OK: confirmed bvp_scores for T-9001
  Confirmed by: root  at: 2026-09-25T23:02:10Z  via: agent
$ grep confirmed_via T-9001*.md
confirmed_via: agent

$ CLAUDECODE=1 <arc close alpha --demo demo.md --decision shipped, no flag>
Closed arc 'alpha' at 2026-09-25T23:04:11Z — shipped
  closed_via: agent
$ grep closed_via alpha.yaml
closed_via: agent

$ CLAUDECODE=1 FW_REQUIRE_ARC_CLOSE_APPROVAL=1 <arc close beta ... --i-am-human>
Closed arc 'beta' ...
  closed_via: human
```

**Is this sufficient?** Partially. It answers "which of the three legal paths
fired," which is strictly more than existed before for `arc close` (nothing)
and adds a distinguishing bit for `bvp confirm` (`$USER` alone couldn't tell
agent from human). It does **not** answer "was this the *right* call" —
that judgment lived entirely in the refusal itself, and removing the refusal
removes the only structural check on it. `confirmed_via`/`closed_via` are a
forensic record, not a control. If the operator wants an actual control back
(e.g. "agent confirms are fine, but flag any BVP confirm on a task above a
certain cost tier for review"), that is new design, not something this
provenance field gives you for free.

---

## 4. `--headline-mechanic` / `--demo` classification

**Determination: independent evidence-quality requirements, NOT part of the
identity gate. Left untouched.**

Code read to support this:

- `_arc_validate_headline_mechanic()` (`lib/arc.sh:268-294`) is called from
  `arc_create()` (`lib/arc.sh:411`), not `arc_close()`. It validates length
  (30-500 chars), requires an observable-action verb, and rejects
  substrate-only phrasing. **It reads only its `$1` text argument** — no
  reference to `CLAUDECODE`, `i_am_human`, or `from_watchtower` anywhere in
  the function body.
- The `--demo` validation inside `arc_close()` (`lib/arc.sh:837-863` in the
  base numbering) runs **after** the identity-gate block and is not
  conditioned on it — it fires for every caller, agent or human, gate on or
  off. Confirmed by direct test: with the identity gate at its new default
  (off), closing an arc under `$CLAUDECODE=1` with no `--demo` still refuses:
  ```
  Error: --demo is required to close an arc (§ACD/G-062).
  RC=2
  ```
  And with the gate restored (`FW_REQUIRE_ARC_CLOSE_APPROVAL=1`) plus
  `--i-am-human`, a too-small demo file (161 bytes, needs ≥256) still refuses
  on size, independent of the identity override having already succeeded.

These are correctly described in the code's own comments as "§ACD Layer A/B"
— they share the §ACD *name* and the same closure-quality motivation, but
structurally they are input-validation, not the identity/authority check. The
operator's instruction named removing "human need for approval," which reads
as the identity check specifically; conflating it with the demo/headline
checks would have been a wider removal than authorised. Left both fully
enforced.

---

## 5. Negative-control results

All run against the AFTER worktree's own `lib/*.sh` (via `FW_NO_REEXEC=1` or
direct-source, per the methodological note in §1).

**`lib/inception.sh` (`fw inception decide`, T-1259) — untouched, still
refuses:**
```
$ CLAUDECODE=1 <inception decide T-9002 go --rationale "...">
ERROR: Agents must not invoke 'fw inception decide' directly (T-679, T-1259)
RC=1
```

**`arc_abandon` — untouched, still refuses:**
```
$ CLAUDECODE=1 <arc abandon delta --reason "...">
Error: agents must not invoke 'fw arc abandon' directly (§ACD/G-062, T-1671).
RC=1
```

**`arc_approve_driver --none` — untouched, still refuses:**
```
$ CLAUDECODE=1 <arc approve-driver delta --none --justification "...">
Error: agents must not invoke 'fw arc approve-driver --none' directly (§ACD, M6).
RC=1
```

**Other 4 `acd_gate()` callers in `lib/bvp.sh` — untouched, still refuse:**
```
$ CLAUDECODE=1 <bvp weight --set D1=3 --rationale "...">        → RC=1 (refused)
$ CLAUDECODE=1 <bvp driver --add scratch-driver --weight 3 ...>  → RC=1 (refused)
$ CLAUDECODE=1 <bvp driver --remove scratch-driver ...>          → RC=1 (refused)
$ CLAUDECODE=1 <bvp auto-promote --enable>                       → RC=1 (refused)
```

**Test suite, before/after (curated set — see caveat below).**

I did not run the full corpus (663 `.bats` files + 223 pytest files under
`tests/unit/`) twice — a single `bin/fw test unit` pass alone did not finish
inside a 580s timeout with the harness's own gate suite going. Given the hard
constraint against backgrounding anything and finishing everything in one
turn, running the complete corpus twice (before + after) was not feasible. I
instead grepped for every test file containing `CLAUDECODE` (the direct
proxy for "exercises one of these identity gates or something that shares
their shape") — **65 files: 59 `.bats`, 6 pytest** — and ran that curated set
before and after. This is a **scoped subset, not the full suite**; the
complete-corpus run is a real gap, named here rather than glossed over.

First pass (bin/fw invoked normally, i.e. **silently re-exec'd to the main
checkout** per the §1 caveat — reported for transparency, not trusted):
BEFORE bats 564/593, pytest 255/258; AFTER bats 564/593, pytest 255/258.
Identical — because both runs were actually exercising the *same* main-checkout
code, telling me nothing about my diff.

Re-run with `FW_NO_REEXEC=1` (genuinely exercising each worktree's own code):

| Suite | BEFORE | AFTER | Delta |
|---|---|---|---|
| curated `.bats` (59 files) | 564 pass / 29 fail | 564 pass / 29 fail | 0 — identical failing tests, both runs |
| curated pytest (6 files) | 255 pass / 3 fail | 253 pass / 5 fail | **-2 pass / +2 fail** |

The 29 bats failures and 3 of the pytest failures
(`test_govd_sandbox.py::test_repo_source_resolves_and_matches_emitted`,
`test_tier0_origin.py::test_derive_classifies_this_very_pytest_run_as_test`,
`test_tier0_origin.py::test_a_real_project_is_not_a_sandbox`) are **identical
in both BEFORE and AFTER** — pre-existing, environment-dependent (a linked
worktree's `.git` is a file, not a directory, which a couple of fixtures
assert on), and unrelated to this change.

The 2 new AFTER-only failures are **exactly and only** the expected
consequence of the change:
```
FAILED tests/unit/test_arc_close_agent_gate.py::test_close_refused_when_claudecode_set_no_override
FAILED tests/unit/test_arc_close_agent_gate.py::test_refusal_message_includes_anchor_redirect
```
Both assert that `fw arc close` refuses by default under `$CLAUDECODE=1` with
no override — which is precisely the behaviour this task removed. This is the
suite correctly detecting the change, not a regression. **I did not modify
these tests** — that's a follow-up decision for the operator (mark them
`FW_REQUIRE_ARC_CLOSE_APPROVAL=1`-conditional, or accept them as now
documenting the opt-in path, or revert if the change itself is reverted).

**The suite did NOT go green-to-green — but only on one of the two gates, and
that itself is a finding.** I searched for any existing bats/pytest file
exercising `fw bvp confirm`'s identity gate specifically
(`grep -rl "cmd_confirm\|bvp confirm\|bvp_confirm"` across `tests/unit/`) and
found none that tests the refusal — the 4 hits that mention "bvp confirm" at
all are incidental references in unrelated tests (M3 mechanics, delegation
classifier docs). **`fw bvp confirm`'s §ACD gate had zero test coverage before
this change, and still has none after.** Per the task's own instruction: this
is a finding, not something to paper over. The `arc_close` gate had coverage
and the coverage caught the change; the `bvp confirm` gate had no coverage and
nothing caught it either way.

---

## 6. `lib/inception.sh`'s sibling gate — reported, not fixed

`lib/inception.sh:481` (`do_inception_decide`):
```bash
if [ "${CLAUDECODE:-}" = "1" ] && [ "$i_am_human" = false ] && [ "$from_watchtower" = false ]; then
    echo -e "${RED}ERROR: Agents must not invoke 'fw inception decide' directly (T-679, T-1259)${NC}" >&2
    ...
    exit 1
fi
```
Identical shape to the two gates this task removed (refuse under
`$CLAUDECODE=1` unless `--i-am-human`/`--from-watchtower`), guarding GO/NO-GO/
DEFER decisions on inception tasks. **Not touched.** The operator's
instruction named "BVP and ARC drivers" only; extending the waiver here would
be scope creep I was explicitly told not to commit. If the operator wants this
removed too, it is a follow-up decision, not an inference for me to make.

---

## 7. Branch and commit

- Branch: `t3487-remove-bvp-arc-approval-gate`
- Base: `t3485-bvp-quadrant-value-axis` @ `e67d7e95b1b1e3f12b5735d7268c616046c8ee84`
- Tip commit: `6adf45442c831c2e6fd7ac32ea2ffb02ca79b6be`
- Built via git plumbing (scratch index file, never touching the main
  checkout's working tree or real index). Two throwaway `git worktree`
  checkouts were used **only** for execution/verification (running `fw bvp
  confirm` / `fw arc close` against real fixtures, and the test suite) and
  were removed (`git worktree remove --force`) before finishing.
- `git branch -vv` confirms the branch exists locally, pointing at the commit
  above; it was never pushed (no `origin/t3487-...` ref exists, and no push
  was attempted).

---

## 8. Concerns about this instruction

1. **The removal is asymmetric with its own audit trail.** `confirmed_via`/
   `closed_via` tell you *that* an agent acted without a human, but nothing
   downstream reads them yet — no doctor WARN, no audit check, no dashboard
   surfacing "N agent-confirmed BVP scores this week" the way, e.g., the
   arc-driver-reviewer's `approved_by: reviewer:...` provenance is audited
   (`check_arc_driver_reviewer_record`). Recording provenance without
   anything reading it is a half-measure — it satisfies the letter of "stay
   reconstructable" but not the spirit of "stay governed." I did not build
   that audit surface because it wasn't asked for, but it is the natural next
   piece if this waiver is meant to be more than a one-off.

2. **`fw bvp confirm`'s gate had zero test coverage, and now the removal of a
   completely untested control is itself untested.** This isn't a defect in
   what I did — it's a pre-existing coverage gap this task surfaced. Worth a
   follow-up task on its own regardless of whether the waiver stands.

3. **The two mechanisms this task removes were the *only* structural
   difference between "an agent decided this" and "a human decided this" for
   these two verbs.** For `bvp confirm`, that boundary (F7/D8 in the code's
   own comments) was explicitly designed as a sovereignty boundary — "only
   the human confirms." For `arc close`, the Default-to-OPEN principle it
   enforced exists specifically because of a *repeated* incident class (4
   instances by the time T-1671 shipped, per the code's own history
   comments). Both were deliberate responses to prior incidents, not
   arbitrary friction. Making them opt-in is fully reversible mechanically
   (flip the env var), but it is not "free" in the sense that whatever
   originally motivated Default-to-OPEN for arc closure and D8 for BVP
   confirmation is still true; only the enforcement of it changed. If "will
   be overwritten later" means the mechanism reverts, that's clean. If it
   means something else — a different control replaces this one — that
   design doesn't exist yet, and until it does, this task's actual effect on
   the system is a strict widening of what agents can unilaterally do, with a
   log line and no gate. I'd rather say that plainly than let "reversible"
   read as "risk-free."

---

## Task-file bookkeeping

Agent ACs ticked in `.tasks/active/T-3487-remove-human-approval-gate-on-fw-bvp-con.md`
as evidence landed; `## Verification`, `## Decisions`, and `## Recommendation`
filled in the same task file. Task left at `started-work` — the Human AC
(operator reviews the diff) is intentionally unticked; `--status
work-completed` was never invoked.
