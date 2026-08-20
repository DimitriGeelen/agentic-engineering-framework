# T-3107 — duplicate-ID detection spans all corpus views (slice 2 of 3)

**Status:** built and verified against the live corpus; unverified by the parent
(worker leaves the tree dirty). §5 records what was actually run.
**Design record:** `docs/design/task-corpus-concurrency-model.md`, rule **R5**.
**Siblings:** T-3104 (`fw_task_view_dirs`, slice 1), T-3105 (`pass_over` /
`warn_unenumerable`, slice 3). Both are on master; this slice consumes both.

---

## 1. What was broken

`agents/audit/audit.sh` answered *"are there duplicate task IDs?"* by scanning
`$TASKS_DIR/{active,completed}` — the main checkout, one of five `.tasks/` views
in this repo. It printed `No duplicate task IDs` for seven weeks while T-2505,
T-2506 and T-2428 each named **two different tasks** in two different views.

The line was never false. It was unfalsifiable: it named no scope, so *"I found
nothing"* and *"I looked nowhere"* rendered identically. T-3105 already fixed the
second half of that (the count is now printed); this slice fixes the first half
(the count is now over the whole corpus).

---

## 2. The judgement call — and where the brief was wrong

The brief specified the discriminator as **content hash**:

> | Same ID in 2+ views, **content differs** | fork artifact | **WARN** |
> | Same ID in 2+ views, **content identical** | normal git replication | silent |
>
> *"Compare by content hash, not path."*

**Measured against the live corpus, that rule produces 2744 findings.** It is
the exact failure the brief warned against, one paragraph above the table that
specifies it.

| Discriminator | Findings on the live 5-view corpus |
|---|---:|
| content hash (**as briefed**) | **2744** |
| `created:` frontmatter (**as built**) | **3** |
| filename slug | 3 |

The reason is a class the brief's model does not have a slot for. A worktree
pinned to an older commit holds an **older revision of the same task** — same
ID, same task, different bytes. That is neither a fork artifact nor a
byte-identical replica; it is the ordinary state of nearly every task in every
worktree, and it accounts for 2744 of the 2911 multi-view IDs here. Only 167 IDs
are byte-identical across every view.

So the question the check asks is not *"do these files differ?"* but *"are these
the same **task**?"* — identity, not content:

| Property | Behaviour across views | Usable as identity? |
|---|---|---|
| bytes | drift freely with branch position | no |
| `created:` frontmatter | fixed at allocation, never rewritten | **yes** |
| filename slug | fixed at allocation, changes only on rename | yes (fallback) |

The shipped rule: **same ID, different `created:` → two tasks minted onto one
number.** For an ID where any view's copy lacks a parseable `created:`, the
check falls back to the filename slug rather than skipping the ID.

**Correction to this report's own earlier figure.** An earlier revision said *18
legacy files* carry no parseable `created:`. Re-measured against the shipped
parser over all five views: **161 file instances, spanning 76 distinct IDs**, of
which **68 are multi-view** and therefore actually route through the slug
fallback. The origin of "18" is not recoverable and the number is not used by
anything, but it understated the fallback's reach by an order of magnitude —
which matters, because the fallback is the only path 68 of the 2911 multi-view
IDs are classified by. All 68 classify as *same task*; the fallback contributes
zero findings, so the "exactly 3, zero false positives" result is unchanged.

Both discriminators independently select exactly `{T-2428, T-2505, T-2506}` and
nothing else — the three known 2026-07-01 collisions, zero false positives.

### 2.1 A second, smaller correction to the brief

The brief's table implies the three classes are mutually exclusive verdicts. In
the corpus they are not: an ID can be a within-view duplicate **and** a
cross-view fork simultaneously. The implementation emits both verdicts
independently (FAIL and WARN in the same run) rather than letting one mask the
other; `tests/unit/t3107_corpus_duplicate_ids.bats` test 7 pins that.

---

## 3. What shipped

### Four classes, three verdicts

| Class | Meaning | Verdict |
|---|---|---|
| same ID twice **inside one view** | allocator bug, live | **FAIL** — `Duplicate task IDs detected (G-052)` |
| across views, **identity differs** | fork artifact — two tasks, one number | **WARN** — `Cross-view task-ID collisions`, every path named with its identity |
| across views, **identity same, bytes differ** | replication lag — same task, older revision | silent; counted as `same-task at differing revisions` |
| across views, **byte-identical** | git replication | silent; counted as `byte-identical in every view` |

The two silent classes are not invisible — they are summarised inside the PASS
line, so a reader can see how much of the corpus was replication and how much
was genuinely distinct.

### The PASS line (T-3105 shape, AC 4)

```
[PASS] No duplicate task IDs — examined 13363 task file(s) across 5 corpus
       view(s) (167 ID(s) byte-identical in every view, 2741 same-task at
       differing revisions)
```

This is the line's **shape**, not today's output. On the live corpus the three
forks fire, and a finding suppresses the PASS entirely (the check did not come
up clean) — see §4. The parenthetical is omitted when both silent-class counts
are zero, which is every single-view corpus.

### Degenerate view sets never PASS (AC 5)

| Condition | Verdict |
|---|---|
| `fw_task_view_dirs` not defined (stale `lib/paths.sh`) | `warn_unenumerable` — names the stale library |
| `fw_task_view_dirs` returns zero views | `warn_unenumerable` |
| scanner errors / emits no `STATS` line | `warn_unenumerable`, first 5 lines of output as evidence |
| views enumerable, zero task files | `pass_over 0` → WARN, *candidate set empty* |

### One definition of the corpus (AC 1)

The view set comes from `fw_task_view_dirs` (`lib/paths.sh`, T-3104). The old
block's `os.environ.get('TASKS_DIR')` root is gone; test 15 greps the shipped
source to keep it gone.

**Nuance on AC 1's wording.** "No second definition of the corpus remains in
`agents/audit/audit.sh`" is satisfied *for this check*. Many other checks in that
file still enumerate `$PROJECT_ROOT/.tasks/active` directly — correctly so: per
R2 the main checkout is the sole **authority**, so questions about task *status*,
*quality* and *lifecycle* are questions about the authority, not about the union.
Only ID uniqueness is a global invariant that spans views. Collapsing the two
would be the same mistake `lib/paths.sh` warns about for `_wt_is_ignorable_path`.

---

## 4. Live-corpus run

Five views (`git worktree list`): the main checkout plus
`inception-gov-payload-mediation`, `rca-worktree-push-strand`,
`t100196-vendor-fix`, `t100199-close`.

| Metric | Value |
|---|---:|
| views enumerated | 5 |
| task files with a parseable `id:` | 13363 |
| distinct IDs | 3094 |
| IDs present in 2+ views | 2911 |
| — byte-identical in every view (silent) | 167 |
| — same task, differing revisions (silent) | 2741 |
| — **identity differs → WARN** | **3** |
| within-view duplicates (FAIL) | 0 |
| scan wall time | ~1.3 s |

**The three known collisions surface.** All three are reported, each with every
view path and its `created:` value. Verbatim output of the shipped block against
the live corpus (`$W` = `.claude/worktrees`, `$R` = repo root; nothing else
elided — the check names *every* path, it does not summarise the tail):

```
[WARN] Cross-view task-ID collisions: 3 ID(s) name a different task in another corpus view
       Evidence: FORK T-2428 (identity differs by created:)
    - $W/inception-gov-payload-mediation/.tasks/active/T-2428-governance-by-payload-mediation.md  [2026-06-18T19:50:00Z]
    - $W/rca-worktree-push-strand/.tasks/active/T-2428-worktree-teardown-strands-unpushed-commi.md  [2026-07-01T09:18:46Z]
    - $W/t100196-vendor-fix/.tasks/active/T-2428-governance-by-payload-mediation.md  [2026-06-18T19:50:00Z]
    - $W/t100199-close/.tasks/active/T-2428-governance-by-payload-mediation.md  [2026-06-18T19:50:00Z]
    - $R/.tasks/active/T-2428-governance-by-payload-mediation.md  [2026-06-18T19:50:00Z]
FORK T-2505 (identity differs by created:)
    - $W/inception-gov-payload-mediation/.tasks/active/T-2505-worktree-usage-policy--refine-per-task-d.md  [2026-07-01T11:31:04Z]
    - $W/t100196-vendor-fix/.tasks/completed/T-2505-ratify-p-03-red-team-test-contract-spec-.md  [2026-07-06T08:13:37Z]
    - $W/t100199-close/.tasks/completed/T-2505-ratify-p-03-red-team-test-contract-spec-.md  [2026-07-06T08:13:37Z]
    - $R/.tasks/completed/T-2505-ratify-p-03-red-team-test-contract-spec-.md  [2026-07-06T08:13:37Z]
FORK T-2506 (identity differs by created:)
    - $W/inception-gov-payload-mediation/.tasks/active/T-2506-reconcile-main-checkout-stranded-uncommi.md  [2026-07-01T11:38:17Z]
    - $W/t100196-vendor-fix/.tasks/completed/T-2506-pre-compact-handover-silently-drops-sess.md  [2026-07-06T09:18:30Z]
    - $W/t100199-close/.tasks/completed/T-2506-pre-compact-handover-silently-drops-sess.md  [2026-07-06T09:18:30Z]
    - $R/.tasks/completed/T-2506-pre-compact-handover-silently-drops-sess.md  [2026-07-06T09:18:30Z]
       Mitigation: Two tasks were minted onto one number across views (L-506 leg 2). Re-number
       the losing side in its worktree, or land/discard that worktree so the corpus holds one
       task per ID
```

An earlier revision of this section rendered T-2428 with a `(+ 3 further views
holding the 2026-06-18 task)` summary line. The shipped block emits no such
line — it names every path, because collapsing the tail is exactly the habit
that made the original check unfalsifiable.

Note the direction of the collision: the **worktree** copies are the
2026-07-01 mintings, and master later re-issued the same three numbers for
unrelated work (2026-07-06 for T-2505/T-2506; T-2428's master copy predates the
worktree one). T-3103 reconciled the *authority*; the worktree replicas still
carry the losing side, which is exactly why a single-view check could not see it
and a union check can.

---

## 5. Verification

Everything below was executed on 2026-08-20 against this repo at
`fb5a9539a` (branch `t2539-staging`), with the shipped `agents/audit/audit.sh`.

### 5.1 The bats rail — 16/16

```
bats tests/unit/t3107_corpus_duplicate_ids.bats
1..16   # all ok
```

The rail does not test a copy: `tests/helpers/audit-dup-task-ids-block.sh`
`sed`-extracts the block from `agents/audit/audit.sh` between
`^if ! declare -F fw_task_view_dirs` and `# end duplicate-task-ID scan`, and
`eval`s it against stub emitters. Fixtures are real `git worktree add` trees.

Siblings re-run green: `t3104_task_corpus_views.bats`,
`t3105_audit_set_reporting.bats`, `t2297_audit_structure_batched.bats`.
`t2298_audit_structure_no_perfile_fork.bats` test 3 (`go_scope_unprop_list=`)
is **RED — and was already RED at `HEAD`**: `git show
HEAD:agents/audit/audit.sh | grep -c go_scope_unprop_list=` returns 0. Not
caused by this slice, not fixed by it.

### 5.2 Live corpus — 3 findings, and they are the right 3

`STATS files=13363 views=5 identical=167 revisions=2741 within=0 forks=3`,
in 1.34 s wall. Every figure in §4's table reproduces exactly, including the
independently-recomputed `distinct IDs: 3094` / `IDs in 2+ views: 2911`
(167 + 2741 + 3 = 2911 ✓).

The three forks are exactly `{T-2428, T-2505, T-2506}` — the three known
2026-07-01 collisions — and nothing else. Zero within-view duplicates.

Rendered a second time through `audit.sh`'s **real** `warn`/`fail`/`pass_over`
emitters (not the test stubs) to confirm the in-audit shape: one `[WARN]` with
the full evidence block and mitigation, `pass=0 warn=1 fail=0`. The check now
contributes a WARN to the audit, so `fw audit`'s exit code moves 0 → 1 on this
repo until the three collisions are reconciled. That is the intended effect.

### 5.3 Mutation testing — 4 mutations, 4 killed

Each is a single-token edit, applied and reverted in place; `md5sum -c` and
`cmp` against a pristine copy confirmed byte-identical restoration after each,
and `test -x` confirmed the exec bit survived each write (OBS-336).

| # | Mutation | Killed by |
|---|---|---|
| M1 | identity → content hash (`r[2]` → `r[4]`) | test 9 *SAME task at DIFFERENT revisions stays silent* |
| M2 | within-view detection disabled (`len(v) > 1` → `> 99`) | tests 4, 5, 7 |
| M3 | slug fallback removed (`by_created = all(...)` → `True`) | test 10 *fallback to filename slug* |
| M4 | PASS no longer suppressed by a WARN (drop the `-z "$dup_forks"` guard) | test 6 |

M1 is the load-bearing one: it is precisely the "simplify it back to a hash
compare" regression §2 exists to prevent, and a single named test refuses it.

No mutation survived, so none needed an equivalence argument.

**Gap this exposes.** No test covers the case where *some* copies of an ID carry
`created:` and others do not. `by_created = all(...)` chooses the slug for that
ID; `any(...)` would choose `created:` and compare a value against `None`.
Mutating `all` → `any` is therefore **not** killed by the current rail. It does
not arise on the live corpus (an ID's copies are replicas, so the field is
present in all or none), which is why it was not caught — but a 17th test would
close it cheaply.

### 5.4 Before/after `fw audit` comparison — NOT DONE

Skipped deliberately, for two reasons, in order of weight:

1. **It writes to `.context/`, which this worker is forbidden to touch.**
   `--output` redirects only the report YAML; `DISC_DIR="$AUDITS_DIR/discoveries"`
   (`agents/audit/audit.sh`, near the report-emit block) is hard-wired to
   `.context/audits/discoveries` and is written regardless of `--output`. A full
   run would dirty files outside this slice's write-set.
2. Two full runs cost ~20 minutes, and a truncated run is indistinguishable from
   a regression — so it is not safe to bound with `timeout`.

§5.2's real-emitter render covers the substantive part of the "after" side (the
exact lines the audit will print, and the pass/warn/fail accounting). What
remains unverified is only the end-to-end run: section ordering, the YAML report
serialisation of this finding, and the observed exit code. **The parent should
run `bin/fw audit` once before landing** and confirm exit 1 with the WARN
present.
