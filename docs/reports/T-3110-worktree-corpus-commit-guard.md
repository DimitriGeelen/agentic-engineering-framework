# T-3110 — L1: task-corpus commit guard in the shared pre-commit hook

**Leg:** R7 / L1 (keystone) of `docs/design/task-corpus-concurrency-model.md`.
**Status:** built, verified, live-fired. Tree left dirty for the parent.

## What shipped

| File | Change |
|---|---|
| `agents/git/lib/worktree-corpus-guard.sh` | **new** — the predicate library + `scan-staged` script mode |
| `agents/git/lib/hooks.sh` | pre-commit template gains the guard block; `# VERSION=1.2` → `1.3`; `COMMIT_MSG_HOOK_VERSION` 1.11 → 1.12 + matching heredoc marker (PL-078) |
| `tests/unit/t3110_worktree_corpus_commit_guard.bats` | **new** — 22 tests |
| `.git/hooks/pre-commit`, `.git/hooks/commit-msg` | reinstalled via `bin/fw git install-hooks` (live repo state, not tracked) |
| `.fabric/components/agents-git-lib-worktree-corpus-guard.yaml` | **new** — fabric card |
| `docs/reports/T-3110-worktree-corpus-commit-guard.md` | this file |

Exec bits verified after every write: guard `-rwxrwxr-x`, all four installed hooks `-x`.

## The predicate (AC 1, AC 2)

Three sourceable functions in `worktree-corpus-guard.sh`, callable by `fw doctor`
/ audit without executing anything (the T-3101 one-predicate-many-surfaces shape):

- `fw_worktree_corpus_authority_root [dir]` — walks `--git-common-dir` back to the main checkout
- `fw_worktree_corpus_staged_paths [dir]` — staged `.tasks/` paths
- `fw_worktree_corpus_commit_refused [dir]` — **the predicate**: linked worktree AND ≥1 staged `.tasks/` path

Linked-worktree detection delegates to `lib/paths.sh:fw_is_linked_worktree` — the
same primitive the T-3098 write-time sibling calls. Not re-implemented, not a
`.claude/worktrees` substring test.

The file is dual-mode: sourced (library) or executed (`scan-staged`, exit 1 =
refuse). The sourced/executed discrimination is made once at the top, because
`return` outside a function is an error in the executed case.

## Two decisions worth naming

**1. The guard is resolved from the AUTHORITY, not from `$FRAMEWORK_ROOT`.**
Every other scanner in the pre-commit hook resolves off
`git rev-parse --show-toplevel`, which *in a linked worktree is the worktree* —
i.e. the replica's own possibly-months-stale tracked copy. Resolving there would
reproduce the exact R7 circularity the leg exists to break. The block walks back
via `--git-common-dir` instead, then tries three shapes: framework repo,
`.agentic-framework/` vendored consumer, `.framework.yaml` `framework_path:`.
`tests/unit/t3110_…bats:20` pins this, and mutation M2 (below) proves it has teeth.

**2. Degradation is ALLOW + a scoped warning, not silence and not fail-closed.**
Fail-closed on a missing dependency would block every commit in the repo.
Silence is the T-2647 failure mode (a control that no-ops is indistinguishable
from one that passed). So: warn, but only where it could have mattered — a
linked worktree of a repo that has a `.tasks/` directory. The main checkout and
every worktree-free consumer print nothing, ever. Two tests pin both halves.

## Bypass (AC 4, AC 5)

`FW_ALLOW_WORKTREE_CORPUS_COMMIT=1 git commit …` — env prefix, not a flag,
because `git commit` rejects unknown options and a flag contract could not be
honoured by the downstream consumer (L-399 / T-1890). Named verbatim in the block
message. Every bypass that actually bypassed a real refusal appends a Tier-2
entry — timestamp, task, flag, caller, worktree, main_checkout, **staged_paths** —
to the **authority's** `.context/working/.gate-bypass-log.yaml`, not the replica's
forked copy. Nothing is logged when the gate would not have fired.

## Verification

`bats tests/unit/t3110_worktree_corpus_commit_guard.bats` → **22/22 ok**.
Fixture is a real `git worktree add` driving a real `git commit` through the real
hook `fw git install-hooks` generates, in a **consumer shape** (`.framework.yaml`
+ `framework_path:`) so the resolution branch 31 vendored consumers will take is
the one under test.

Live-fire in a throwaway `--detach` worktree of this repo (created and removed;
no branch minted, worktree list restored, main checkout's staged rename untouched):

| Case | Result |
|---|---|
| `.tasks/` commit from the replica | **refused**, message named `/opt/999-…` as authority and the staged path |
| source-only commit from the same replica | **allowed** (`88bcc0b5a`, discarded with the worktree) |
| `.tasks/` staged in the main checkout | guard exit 0 |

Adjacent suites re-run green: `hook_version_marker_parity` (0 not-ok),
`git_install_hooks_git_path` (0), `t2813_install_hooks_write_failure` (0),
`test_secret_scan` (0), `init_head_bootstrap` (0), `t3098_worktree_governance_write` (0).
`test_large_file_scan.bats` exceeds 280s and was not completed — it `dd`s
11 MiB at `bs=1` (11.5 M syscalls); pre-existing slowness, and out of blast
radius by construction (plain `git init` fixture, no worktree, no `.tasks/`).

## Mutation table (AC 10)

All four applied one line at a time, run, then reverted (`diff -q` clean, suite back to 22/22).

| # | Mutation | Killed |
|---|---|---|
| M1 | `fw_worktree_corpus_staged_paths`: `git diff --cached` → `git ls-files --cached` (the plausible copy of `dup-task-scan.sh`'s idiom) | 6, 7, 8, 13, 17 |
| M2 | hook: `AUTHORITY_ROOT=$(dirname --git-common-dir)` → `AUTHORITY_ROOT="$PROJECT_ROOT"` (the "simplify to match its siblings" mistake) | 9, 12, 20, 21 |
| M3 | bypass log dir `$authority/.context/working` → `$wt/.context/working` | 12 |
| M4 | predicate drops `fw_is_linked_worktree "$dir" \|\| return 1` (every checkout treated as a replica) | **1, 2**, 15 |

M4 is the one that matters: tests 1 and 2 are the AC-6 main-checkout tests, and
they fail the instant the discrimination is removed.

An earlier, weaker M2 — changing only the *first* candidate path — killed just
test 21, because the third resolution branch (`$AUTHORITY_ROOT/.framework.yaml`)
still reached the authority. Worth recording: the three-candidate chain is
defence in depth, so a partial regression in it is survivable but also harder to
detect. Only collapsing `AUTHORITY_ROOT` itself disarms the leg.

## Where I think the brief is wrong

**`agents/dispatch/preamble.md` (L-419) instructs every dispatch worker to do
exactly what this gate now refuses.** Lines 99-101:

```bash
bin/fw task update T-XXX --status work-completed && \
  git add .tasks/active/T-XXX-*.md && \
  FW_SWITCH_FOCUS=1 bin/fw git commit -m "T-XXX: work-completed transition"
```

`fw git commit` runs plain `git commit` (`agents/git/lib/commit.sh:172`) — hooks
fire. And CLAUDE.md §Parallelism limits tells workers to use
`fw worktree create` for any parallel work that edits files. So the framework
currently documents a protocol that this gate blocks, in the exact configuration
it recommends. That is the L-399 producer/consumer split T-1890 is about, shipping
on one side only: gate here, protocol there.

T-3098 does not have this problem — it is a PreToolUse hook on Write/Edit, and
`fw task update` is a *script*, so it never fires (the Tier 0 scope boundary).
L1 is the first leg that actually reaches that flow.

I did not edit the preamble — it is outside the 10 ACs and it is a governance
document, so the call is the parent's. What I did instead: the block message
carries a dedicated `DISPATCH WORKERS:` paragraph naming `preamble.md` (L-419) by
name and giving the correct move (leave the frontmatter delta uncommitted, say so
in the final message, parent sweeps it at the authority). A worker that trips this
can resolve it without asking the operator, which is AC 3's actual requirement.
**Recommendation: file a follow-up to reconcile `preamble.md` with L1** — either
qualify the L-419 protocol with "main checkout only", or point workers at
`FW_ALLOW_WORKTREE_CORPUS_COMMIT=1` so the bypass log measures how often the
documented flow needs it.

Everything else in the brief held up, including the hooks-path claim — verified
independently from all four live worktrees and from the throwaway one, all five
resolving to `/opt/999-Agentic-Engineering-Framework/.git/hooks`.

## False-positive measurement

Branch-unique commits touching `.tasks/` on every live worktree branch, relative
to the session branch:

| Worktree branch | unique commits | of which touch `.tasks/` |
|---|---:|---:|
| `worktree-inception-gov-payload-mediation` | 6 | 4 |
| `worktree-rca-worktree-push-strand` | 37 | 4 |
| `t100196-vendor-fix` | 0 | 0 |
| `t100199-close` | 0 | 0 |

Eight commits total would have been refused — and they are, by subject line,
*precisely* the incident set the design record cites: `T-2506: … register gap
G-083`, `T-2505: file inception — worktree usage/lifecycle policy`, `T-2428: file
high-priority remediation request`. The gate's entire historical hit-set is the
defect set. No false positive found in the live corpus.

## Honest limits (unchanged from the design record)

- Commit-time, not write-time: an uncommitted duplicate still exists on disk. R2
  (`check-worktree-governance-write.sh`) is the write-time leg and is stronger,
  but version-dependent — which is exactly what this leg is not.
- Assumes `core.hooksPath` is not overridden to a per-worktree path. In this repo
  it is set explicitly to the shared `.git/hooks`.
- `git commit --no-verify` skips it, like every other pre-commit gate.
- **Vendored consumers do not have the guard yet.** `bin/fw vendor self` /
  `fw upgrade` were not run — that is L4's job and a much larger mutation than
  this task's scope. Until then, consumers hit the degradation warning (only if
  they use worktrees), never a false block.
