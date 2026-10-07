# T-3980 — Git in worker-written trees (G-112)

**Status:** inception, research artifact (C-001). Filed 2026-10-07.
**Origin:** ring20 T-2281 §9 Q5, their G-232: root ran git inside a directory a worker wrote, and git
configuration can execute commands.

## Question

Before AEF ever runs workers under a uid other than the operator's, how should the framework's own
git calls in worker-written trees be made safe, and should a guard refuse a uid split until they are?

## Why it is safe today, and why that is not enough

Every AEF worker runs as the operator's uid (CLAUDE.md, repeatedly: "every agent here runs as the
same user"). Git running in a worker tree executes nothing the worker could not already execute, so
no privilege boundary is crossed. `lib/govd_sandbox.py` already sketches an `agent_uid`; the day a
consumer adopts it, every call below runs worker-controlled commands with the operator's authority.

## Where AEF runs git in a tree a worker wrote

| Path | What it runs | Tree |
|---|---|---|
| `lib/integrate.py` (`_git`, `_git_rc`, conflict `show :stage:path`, `status`) | merge, show, status, worktree remove --force | the worker's worktree |
| `lib/worktree.sh` (`do_worktree_remove`, `gc`, `status`) | status --porcelain, rev-list, worktree remove | the worker's worktree |
| `agents/termlink/termlink.sh` (dispatch) | `git -C <project> rev-parse` for the review revision | the project (shared) |
| `lib/reviewer/reverify.py`, `drift.py`, `static_scan.py` | diff, log, show over the reviewed tree | the reviewed tree |

## What in a tree can make git execute

- `core.fsmonitor` (a command run on status/diff),
- `core.hooksPath` and the hooks themselves,
- `diff.<driver>.textconv`, `filter.<driver>.clean/smudge` (via `.gitattributes`, which IS in the tree),
- `core.sshCommand`, `credential.helper`, `core.editor`/`sequence.editor`, `gpg.program`,
  `include.path` pulling any of the above in.

A linked worktree's per-worktree config lives under the MAIN repo's `.git/worktrees/<name>/` (and
`config.worktree` when `extensions.worktreeConfig` is on); with a uid split the worker should not be
able to write the main `.git`, but `.gitattributes` and anything inside the worktree it can.

## Constraint that rules out the obvious fix

`-c core.hooksPath=/dev/null` on every call would also switch off AEF's own hooks where they are the
point (the pre-commit and pre-push gates during `fw integrate` landing). Neutralising has to be
per-call: read-only inspection calls (status, diff, show, log, rev-parse) get the full neutral set;
calls whose hooks are AEF's controls keep hooks and neutralise the rest.

## Options

- **A. One helper, `fw_git_untrusted`, per call class.** Inspection calls: `-c core.fsmonitor=
  -c core.hooksPath=/dev/null -c diff.external= --no-textconv --no-ext-diff`, `GIT_CONFIG_NOSYSTEM=1`,
  attributes from a controlled file (`-c core.attributesFile=/dev/null` does not override in-tree
  `.gitattributes`, so `GIT_ATTR_NOSYSTEM` plus `--no-textconv` / filters disabled by
  `-c filter.<x>.clean=` is needed per driver, which is why this is not trivial). Mutating calls in
  the main checkout keep hooks.
- **B. Run them as the worker's uid** (ring20's other half): the worker's own config can only hurt
  the worker. Clean, but needs the uid split to exist first.
- **C. Sanitised copy** (ring20's "line to hold"): copy the worker's result into an operator-owned
  directory with no config/attributes and inspect that. Strongest; costs a copy per inspection.
- **D. Gate only**: refuse to enable `agent_uid` while A/B/C is not in place, and do nothing else now.

## Recommendation (for the operator)

**GO on D now plus A for the inspection calls**, and leave B/C to the arc-009 inception (T-3977),
where the isolation model is decided. D is a few lines and closes the risk window structurally: no
uid split can be switched on before the git calls are safe. A removes the cheapest exploit paths
(fsmonitor, hooks, textconv) at no cost to today's same-uid installs.

## Dialogue log

- 2026-10-07 ring20: "never safe.directory plus a sanitized copy turned out to be the line to hold."
- 2026-10-07 AEF reply named the four paths above and committed to fixing before any uid split.
