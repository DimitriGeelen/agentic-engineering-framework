# T-3102 — `fw worktree remove` must not be blocked by non-work dirt

> **STATUS: corrected.** Everything below the divider is the FIRST cut, preserved
> as filed. Its classification basis (governance-only) was measurably too narrow
> and unblocked nothing. The correction is appended at the end under
> **[CORRECTION] The basis was too narrow**; read that section for the shipped
> rule. The first cut's findings on the strand guard, the `--not --remotes`
> predicate, and the T-2831 supersession all survive unchanged.

---

# [FIRST CUT] `fw worktree remove` must not be blocked by governance-only dirt

## The measured problem

Governance state (`.context/**`, `.tasks/**`) is **tracked** content. Every linked
worktree therefore holds a *fork* of it, and hooks firing in the **main** session
mutate that fork independently of anything the worktree's own work did (T-2822,
OBS-179). Measured 2026-08-20:

| worktree | dirty | governance | source |
|---|---:|---:|---:|
| inception-gov-payload-mediation | 26 | 23 | 3 |
| rca-worktree-push-strand | 5 | 4 | 1 |
| t100196-vendor-fix | 2 | 1 | 1 |
| t100199-close | 17 | 15 | 2 |

git's dirty check has no opinion about *what* is dirty, so it refused
`fw worktree remove` on every worktree. That made `--force` routine (OBS-177) —
and `--force` on a worktree with unlanded commits destroys them.

## The classification rule

`_wt_is_governance_path <relpath>` in `lib/worktree.sh`:

```
.context/*  -> GOVERNANCE
.tasks/*    -> GOVERNANCE
everything else -> SOURCE
```

Prefix match, applied to the *destination* path of each `git status --porcelain
--untracked-files=all` record (rename records `R old -> new` classify on `new`;
git's quoting is stripped first). `_wt_dirty_summary` returns:

| rc | meaning | behaviour |
|---|---|---|
| 0 | clean | proceed |
| 1 | ≥1 SOURCE path dirty | **refuse**, naming the specific paths (first 5 + `... N more`) |
| 2 | governance-only | **proceed**, printing one discard-summary line |

Source wins in a mixed worktree: the presence of *any* uncommitted source makes
the removal lossy, whatever else is dirty.

## Why governance dirt is discardable under T-2822

T-2822's adopted GO is source-only: **governance state inside a linked worktree is
non-authoritative by construction.** Master is the authority; the worktree's copy
is a stale branch of it that nothing ever reads back. Discarding it loses nothing
master does not already hold. That is what makes rc=2 safe to proceed on — not
"the files are regenerable", but "this copy is not the authoritative one".

### Supersession of T-2831

T-2831 split dirt into *regenerable machine-local state* vs *content registers*,
with an exact-match allowlist, and refused `.tasks/**`,
`.context/project/decisions.yaml` and `.context/working/feedback-stream.yaml`
**unconditionally** — `--force` included — on the theory that they were
irreplaceable content.

Under T-2822 that theory is wrong for the *worktree copy specifically*: the
authoritative copy is on master and is untouched by the removal. T-3102 therefore
supersedes T-2831 **for governance paths only**.

What T-2831 was actually protecting — *never silently discard uncommitted work* —
survives intact as the SOURCE class, which is still refused unconditionally with
`--force` included. `--force` remains the named strand-override, not a
content-discard action (T-2831 AC3). `--force` semantics are unchanged and its
discard scope is not widened by this task.

The two allowlist designs are not in tension once the question each answers is
named. T-2831's narrowness was right for *"is this file regenerable?"* — a
per-file property, where a prefix rule would have swept in
`feedback-stream.yaml`. T-3102's prefix rule is right for *"is this file
authoritative in THIS working copy?"* — a per-directory property, uniform across
the governance tree.

## Separation from the unlanded-commit guard

The two guards answer different questions and must stay separate:

- **dirty classifier** — "is there uncommitted work here?" (working tree)
- **`_wt_unpushed_summary`** — "would removing this strand commits?" (`rev-list
  <branch> --not --remotes`)

Governance-only dirt sets the proceed flag (`gov_discard` in the first cut, renamed
`discard_ok` by the correction) and falls *through* to the unlanded
guard, which still refuses independently. A worktree whose dirt is governance-only
but whose branch holds commits on no remote **still refuses**, and the refusal
message says `commits not on any remote` and offers `push`, never
`uncommitted SOURCE`. Test 4 pins this, including the negative assertion that the
source wording is absent — the operator must be able to tell the two remedies
apart.

The SOURCE refusal message likewise names the distinction explicitly, so an
operator hitting it is not left guessing which of the two problems they have.

## Step-3 dry run against the real repo (read-only, nothing removed)

Produced by sourcing `lib/worktree.sh` and calling `_wt_dirty_summary` against
each live worktree — read-only, no mutation (`git worktree list` still reports 5
entries afterwards):

| worktree | branch | dirty | gov | src | dirt class → decision | unlanded (`--not --remotes`) |
|---|---|---:|---:|---:|---|---:|
| inception-gov-payload-mediation | worktree-inception-gov-payload-mediation | 26 | 23 | 3 | **SOURCE-dirt → REFUSE** (`.agentic-framework/bin/fw`, `.agentic-framework/lib/reviewer/static_scan.py`, `VERSION`) | 3 |
| rca-worktree-push-strand | worktree-rca-worktree-push-strand | 5 | 4 | 1 | **SOURCE-dirt → REFUSE** (`VERSION`) | 1 |
| t100196-vendor-fix | t100196-vendor-fix | 2 | 1 | 1 | **SOURCE-dirt → REFUSE** (`VERSION`) | 0 |
| t100199-close | t100199-close | 17 | 15 | 2 | **SOURCE-dirt → REFUSE** (`VERSION`, `lib/ts/dist/loop-detect.js`) | 0 |

**All four still refuse.** None is governance-only — every one carries a dirty
`VERSION`, and two carry more. This is the correct outcome under the new rule and
it is worth stating plainly: the fix does **not**, on its own, make any of the four
live worktrees removable. It removes governance dirt as a *cause* of refusal; the
residual source dirt is a real, separate reason that the operator must resolve
deliberately.

Note also that the classifier now names `VERSION` as the blocking path, where the
old message named 23 files without distinguishing them. That naming is the
operational win here even though the verdict is unchanged.

### On the "6 and 37 unlanded commits" figure

The task brief cited two worktrees holding 6 and 37 unlanded commits. Those
numbers are `origin/master..HEAD` — commits *ahead of master*. Under the
predicate the removal guard actually uses (`rev-list <branch> --not --remotes`,
chosen deliberately in T-2829 because the T-100196 flow FF-lands onto master and
leaves `origin/<branch>` stale or absent), the counts are **3 and 1**:

| worktree | `--not --remotes` | `origin/<branch>..HEAD` | `origin/master..HEAD` |
|---|---:|---:|---:|
| inception-gov-payload-mediation | 3 | 3 | 6 |
| rca-worktree-push-strand | 1 | (no remote ref) | 37 |
| t100196-vendor-fix | 0 | (no remote ref) | 0 |
| t100199-close | 0 | (no remote ref) | 0 |

The safety claim in the brief survives the correction — both worktrees still hold
a non-zero strand count and both still refuse — but the magnitude does not. Most
of those 37 commits are already on a remote; only one is at risk. Worth recording
because `origin/master..HEAD` is the intuitive thing to reach for and it
overstates strand risk by an order of magnitude here.

## Mutation testing

Three one-line mutations, run against
`t3102_worktree_governance_dirt.bats` + `worktree_remove_dirty_class.bats`
(14 tests). All reverted; `lib/worktree.sh` verified byte-identical afterwards.

| # | Mutation | Killed by | Count |
|---|---|---|---:|
| M1 | invert the governance match (`.context/*|.tasks/*) return 0` → `return 1`) | t3102 #1 (governance-only proceeds), #4 (mixed), #5 (unlanded), #8 (count), #9 (classifier unit); dirty-class #1 | 6 |
| M2 | unlanded guard falls through on governance-only dirt (add `&& [ "$gov_discard" != "1" ]` to the refusal condition) | **t3102 #5** — governance-only dirt + unlanded commits must STILL refuse | 1 |
| M3 | drop source-path naming (`echo "  ${source[$i]}"` → `echo "  <redacted>"`) | t3102 #2, #3, #4, #7; dirty-class #2, #3 | 6 |

No mutant survived, so no equivalence argument is needed. M2 is the one that
matters most: it is precisely the "governance dirt unlocks removal of unlanded
work" regression this task must not introduce, and exactly one test — the one
written for it — catches it. That narrow kill is the intended shape, not a
coverage gap: the other tests deliberately hold the branch fully pushed so their
refusals can only come from the dirty classifier.

## Test results

| suite | tests | result |
|---|---:|---|
| `t3102_worktree_governance_dirt.bats` (new) | 10 | pass |
| `worktree_remove_dirty_class.bats` (T-2831, reconciled) | 4 | pass |
| `worktree_remove_guard.bats` | 5 | pass |
| `t2825_worktree_remove.bats` | 7 | pass |
| `t3101_worktree_unlanded.bats` | 8 | pass |
| `t100196_worktree_gc.bats` | 7 | pass |
| `t2469_worktree_create.bats` / `t2466_worktree_status.bats` | 6 / 8 | pass |
| `t3098_worktree_governance_write.bats` | 14 | pass |
| integrate + sweep + transcript + audit-cron worktree suites | 41 | pass |

`worktree_remove_dirty_class.bats` required reconciliation: three of its four
tests asserted that `.tasks/**`, `decisions.yaml` and `feedback-stream.yaml` dirt
BLOCKS removal — the exact rule T-3102 reverses. They were rewritten to pin
T-2831's surviving invariant over the SOURCE class, plus the mirror-image
misclassification risk (a governance *look-alike* such as `docs/context/notes.md`
must not be swept into the discardable class). The supersession is recorded in
that file's header rather than left implicit.


---

# [CORRECTION] The basis was too narrow

## What the first cut's own dry run proved

The table above is the first cut's honest self-report, and it is the finding that
invalidates the first cut: **all four live worktrees still refused.** Every one
carried a dirty `VERSION`; two also carried `.agentic-framework/**` and
`lib/ts/dist/**`. Verified independently by the dispatching session: those are the
*only* non-`.context/`/`.tasks/` dirty paths across all four.

So the first cut removed governance dirt as a *cause* of refusal and unblocked
**nothing operationally**. A guard that refuses 4/4 of the real cases it was
written for has not changed the operator's incentive to reach for `--force`,
which is the behaviour (OBS-177) the task exists to remove.

The mistake was not the mechanism. It was picking the classification basis from
the *symptom that was measured* (governance was 23 of 26 dirty paths, so
governance looked like the whole problem) rather than from the *question being
asked* ("is this dirt work?"). `VERSION` is 1 of 26 and it is 100% of the reason
the guard fired.

## The corrected rule

```
blocking dirt = a dirty path that is NOT _wt_is_discardable_dirt
_wt_is_discardable_dirt = _wt_is_ignorable_path  +  .tasks/*  −  .fabric/*
```

`_wt_is_ignorable_path` (`lib/worktree.sh`, the `fw worktree gc` helper) already
enumerates exactly the right set — "vendored, generated, or session-local churn",
i.e. content that is not work. It is **reused**, not restated. A second copy of
that pattern list is the drift bug this whole task exists to fix; the new
predicate is four lines and delegates.

`tests/unit/t3102_worktree_governance_dirt.bats` test 20 pins the reuse
structurally: it asserts each shared path is classed the same by *both*
predicates, so a future edit to the gc set that silently diverges from the dirt
set fails a test rather than rotting.

### Delta +: `.tasks/*` is listed here and NOT added to `_wt_is_ignorable_path`

**Two callers, two correct answers. Do not unify them.**

`gc` calls `_wt_is_ignorable_path` for a **landing** decision — "did this
branch's work reach master, so the branch can be reclaimed?" There, a `.tasks/`
file **is a deliverable**: a branch whose only content is a new task file has
done real work, and adding `.tasks/` to gc's ignorable set would let gc reclaim
it as `no-deliverables`.

The dirt classifier asks a **different question** — "would discarding this
*working copy* lose anything?" There the T-2822 answer for `.tasks/` is no: the
worktree's copy is a non-authoritative fork and master holds the authority.

Both answers are right for their own question. The comment on
`_wt_is_discardable_dirt` says this in the source, explicitly, so the next reader
does not "clean up" the apparent inconsistency into a bug.

### Delta −: `.fabric/*` is ignorable for gc but is NOT discardable here

**This is the class the brief invited us to find, and it is real.** The brief
listed `.fabric/` as "generated — regenerable by `fw fabric scan`". Checked
rather than assumed:

`fw fabric scan` **skips cards that already exist**
(`agents/fabric/lib/register.sh:203` `Card already exists`, and the scan loop's
`skipped` counter at :326-339). It only creates *missing* cards — it never
rewrites a present one. So a **modified** card is not regenerable at all. And
cards carry hand-authored prose: `purpose:`, and fields like
`standalone_reason: frontend asset / documentation leaf — no code-dependency
edges (T-2511)`, which cite task ids and could not be re-derived.

Discarding a dirty `.fabric/` card would therefore silently destroy content. It
stays ignorable for **gc** — where the question is "is a changed card a
deliverable?", and no is defensible — but it **blocks** here, where the question
is "would discarding it lose content?", and the answer is yes.

Cost of the exclusion: zero. None of the four live worktrees carries `.fabric/`
dirt. It buys the guard's honesty for free. (Note in passing, out of scope: gc's
own treatment of `.fabric/` has the same hazard from the other direction — a
branch whose only change is a card edit classifies as `no-deliverables` and is
reclaimable. Not touched here; flagged for whoever owns gc.)

### The other classes were checked too, not assumed

| class | discardable because | verified at |
|---|---|---|
| `.context/*` | non-authoritative fork; master is the authority (T-2822) | first cut, unchanged |
| `.agentic-framework/*` | vendored copy of this repo's own source, rewritten wholesale | `bin/fw:_self_vendor` (`fw vendor self`) |
| `VERSION` | derived from `FW_VERSION` in `bin/fw`, restamped | `lib/version.sh:298` (`fw version sync`) |
| `lib/ts/dist/*` | build output of `lib/ts/src` | `lib/ts/package.json` `"build": "bash ../build.sh"` |
| `*.budget-status`, `*.hook-counter`, `*.tool-counter`, `*.loop-detect.json` | session-local counters, rewritten on next tool call | — |

## The two guards stay separate — re-verified after widening

Widening the discardable class must not weaken the strand guard, so that is
tested twice, not argued:

- test 5 (first cut) — governance-only dirt + unlanded commits → still refuses
- test 19 (new) — vendored/generated dirt + unlanded commits → still refuses

Both also assert the refusal says `commits not on any remote` and does **not**
say `uncommitted SOURCE`, so the operator can tell the two remedies apart. M4
below is the mutation that proves those assertions bite.

**Which predicate each surface uses** (first cut's finding, restated because it
is easy to lose):

| surface | question | predicate | counts on the two strands |
|---|---|---|---|
| `fw worktree remove` strand guard | "would removing this **lose** work?" | `rev-list <branch> --not --remotes` | **3** and **1** |
| intuitive/ad-hoc check | "how far **ahead of master** is this?" | `origin/master..HEAD` | **6** and **37** |
| `fw worktree gc` | "did this work **land**?" | content comparison (T-100142; patch-id fails under re-derivation) | — |

Both are correct for their own question. `--not --remotes` is the one the guard
uses and the one that bounds real risk; `origin/master..HEAD` overstates strand
risk by an order of magnitude here (most of the 37 are already on a remote).

## Refreshed dry run — read-only, nothing removed

Same method as before: source `lib/worktree.sh`, call `_wt_dirty_summary` and
`_wt_unpushed_summary` against each live worktree. No mutation
(`git worktree list` still reports 5 entries afterwards).

| worktree | branch | dirty | gov | vend/gen | blocking dirt | dirt verdict | strand guard (`--not --remotes`) | net |
|---|---|---:|---:|---:|---|---|---:|---|
| inception-gov-payload-mediation | worktree-inception-gov-payload-mediation | 26 | 23 | 3 | **none** | discardable → PROCEED | **3** → REFUSE | refuses on commits |
| rca-worktree-push-strand | worktree-rca-worktree-push-strand | 5 | 4 | 1 | **none** | discardable → PROCEED | **1** → REFUSE | refuses on commits |
| t100196-vendor-fix | t100196-vendor-fix | 2 | 1 | 1 | **none** | discardable → PROCEED | 0 → allow | **removable** |
| t100199-close | t100199-close | 17 | 15 | 2 | **none** | discardable → PROCEED | 0 → allow | **removable** |

**All four flipped to zero blocking dirt.** Two are now removable (they were not
before, under either the original guard or the first cut). Two still refuse — on
the unlanded-commit guard, which is the correct and intended outcome, and which
is precisely the refusal `--force` used to be reached for because the *dirt*
refusal was firing first and drowning it out.

Discard summary lines emitted, verbatim:

```
26 discardable file(s) dirty in inception-gov-payload-mediation: 23 governance (non-authoritative fork; master is the authority), 3 vendored/generated (regenerable) -- discardable
 5 discardable file(s) dirty in rca-worktree-push-strand: 4 governance (...), 1 vendored/generated (regenerable) -- discardable
 2 discardable file(s) dirty in t100196-vendor-fix: 1 governance (...), 1 vendored/generated (regenerable) -- discardable
17 discardable file(s) dirty in t100199-close: 15 governance (...), 2 vendored/generated (regenerable) -- discardable
```

The message names the *class*, not just a count, because the two discardable
classes are safe for different reasons and the operator should be able to see
which one they are looking at. The governance-only wording is preserved verbatim
from the first cut so its meaning does not shift under the tests that pin it.
The SOURCE refusal still names the specific blocking paths — the first cut's real
operational win, kept.

## Mutation testing (re-run)

Four mutations against
`t3102_worktree_governance_dirt.bats` + `worktree_remove_dirty_class.bats` +
`t100196_worktree_gc.bats`. All reverted; `lib/worktree.sh` verified
byte-identical afterwards (`cmp`).

| # | Mutation | Killed by | Count |
|---|---|---|---:|
| M1 | drop the `_wt_is_ignorable_path` reuse — revert to the governance-only basis | 11 (VERSION), 12 (`.agentic-framework`), 13 (`lib/ts/dist`), 16 (mixed naming), 18 (both classes), 19 (strand+vend), 20 (reuse parity) | 7 |
| M2 | drop the `.fabric/*` exclusion | **17** (`.fabric` card must block) | 1 |
| M3 | drop the `.tasks/*` inclusion | 1, 4, 5, 8, **14**, 20 | 6 |
| M4 | let discardable dirt suppress the unlanded-commit guard | **5**, **19** | 2 |

**No mutant survived, so no equivalence argument is needed.** M2 and M4 are the
narrow ones and that narrowness is intended: M2 is killed only by the test written
for the `.fabric/` exclusion (nothing else exercises a non-regenerable generated
path), and M4 only by the two strand-separation tests (every other test holds the
branch fully pushed so its verdict can come from the dirt classifier alone).

## Test results (re-run)

| suite | tests | result |
|---|---:|---|
| `t3102_worktree_governance_dirt.bats` | **20** (10 original + 10 correction) | pass |
| `worktree_remove_dirty_class.bats` | 4 | pass |
| `worktree_remove_guard.bats` | 5 | pass |
| `t2825_worktree_remove.bats` | 7 | pass |
| `t3101_worktree_unlanded.bats` | 8 | pass |
| `t100196_worktree_gc.bats` | 7 | pass |
| `t2469_worktree_create.bats` / `t2466_worktree_status.bats` | 6 / 8 | pass |
| `t3098_worktree_governance_write.bats` | 14 | pass |
| transcript / sweep / audit-cron worktree suites | 13 | pass |
| **total** | **92** | **92 pass, 0 fail** |

**Every one of the first cut's 10 tests passes unchanged** — no test had to be
weakened or rewritten to accommodate the correction. That is the point of having
kept the governance-only discard wording verbatim.

The 10 added tests: dirty `VERSION` alone does not block; `.agentic-framework/lib/foo.sh`
alone does not block; `lib/ts/dist/foo.js` alone does not block; `.tasks/T-1.md`
alone does not block (and is reported as *governance*, not vendored);
`lib/foo.sh` **does** block; `VERSION` + `lib/foo.sh` blocks and names
`lib/foo.sh` while *not* naming `VERSION`; a dirty `.fabric/` card **does** block;
mixed governance + vendored reports both classes with correct counts;
vendored/generated dirt + unlanded commits still refuses; and the
predicate-parity check pinning the `+.tasks / −.fabric` deltas against the gc set.

## Nothing here contradicts the brief

One departure, taken under the brief's own instruction to check rather than
follow it off a cliff: **`.fabric/*` is excluded** from the discardable set,
because `fw fabric scan` does not regenerate modified cards. Everything else
matches — the predicate is reused not copied, `.tasks/` is listed separately with
the two-callers comment in source, source-path naming is preserved, the strand
guard stays separate and is tested for it, and all four worktrees flipped.
