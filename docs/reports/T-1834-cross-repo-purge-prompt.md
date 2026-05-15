# Cross-repo handout — T-1834 framework history purge

**Filed:** 2026-05-15 · **Owner:** Dimitri · **Anchor task:** [T-1834](../../.tasks/active/T-1834-purge-msoauth-client-secret-from-framewo.md)

---

## What this is

A paste-ready prompt to give to any agent (Claude Code session, TermLink dispatch
worker, another assistant) that may be operating on a **clone of the Agentic
Engineering Framework repo**. After the framework's master branch is
force-purged via `git filter-repo`, every existing clone retains the leaked
blob in its local history until purged or re-cloned.

This prompt is **not** for consumer projects that have a vendored
`.agentic-framework/` directory — those have no framework git history and are
not affected.

---

## When to use it

Send this prompt to:

- Any framework-developer workstation that has cloned
  `agentic-engineering-framework` (OneDev or GitHub)
- Production deployments at LXC 170 (`/opt/watchtower-prod`,
  `/opt/watchtower-dev`) if they pull from the framework remote
- Any CI runner with a cached framework checkout
- Any TermLink worker that operates on a framework clone

If unsure whether a target is affected, send it the prompt — the prompt's
first step is a self-check that exits cleanly on unaffected targets.

---

## Delivery channels

- **TermLink inject** (preferred for interactive agents): `termlink inject <session> --enter "<paste prompt>"`
- **TermLink push** (async, file delivery): `termlink push --to <session> --file docs/handouts/T-1834-cross-repo-purge-prompt.md`
- **framework:pickup** envelope: write to `.context/pickup/<target>/` and let the bridge propagate
- **Manual paste** to a fresh Claude Code session: open the target machine's session, paste the **Prompt body** below

---

## Prompt body — paste from here to end of file

> You are operating on a machine that may have a clone of the **Agentic
> Engineering Framework** (`agentic-engineering-framework`) repo. On 2026-05-15
> the framework's master branch was rewritten via `git filter-repo` to remove
> a leaked credential from history. Your local clone may still contain the
> leaked blob. This task purges it.
>
> **Anchor task:** T-1834 (in the framework repo).
> **Leak coordinates:** commit `79e3361d`, file
> `.context/spikes/T-1736-prompts.jsonl`. Do not read or open this file under
> any circumstances; the secret-redaction rule applies even to read-only
> inspection.
>
> ---
>
> **Step 0 — Path isolation**
>
> Identify the framework clone path on this machine. Operate **only** within
> that path. Do not read, list, or `cd` to any other path on this machine.
>
> If you cannot find a framework clone (no directory contains both
> `FRAMEWORK.md` and `.git/`), STOP and report `unaffected: no framework clone found`.
>
> ---
>
> **Step 1 — Detect**
>
> ```
> cd <framework-clone-path>
> git log 79e3361d -- .context/spikes/T-1736-prompts.jsonl 2>&1 | head -3
> ```
>
> - If the command prints a commit header, your clone has the leak. Continue.
> - If the command prints `fatal: bad object 79e3361d` or similar, your clone
>   is already clean (either re-cloned after purge, or never had the history).
>   STOP and report `unaffected: leak commit absent`.
>
> ---
>
> **Step 2 — Choose remediation path**
>
> **Option A — clean re-clone (preferred for production deployments and CI):**
>
> 1. `git status --short` — if dirty, stash with `git stash push -u -m "pre-T-1834"`
> 2. Note the upstream URL: `git remote get-url origin`
> 3. `cd ..` and rename the existing clone aside:
>    `mv <name> <name>.pre-T-1834-backup`
> 4. `git clone <upstream-url>` (the rewritten upstream)
> 5. Restore any stashed work in the new clone if needed
> 6. Continue to Step 3
>
> **Option B — in-place filter-repo (preferred for dev workstations):**
>
> 1. `git fetch origin --prune`
> 2. Confirm working tree clean (`git status --short`); commit or stash anything outstanding
> 3. Snapshot refs:
>    `git for-each-ref --format='%(refname) %(objectname)' > .git/refs-backup-T-1834-$(date +%s)`
> 4. Run filter-repo:
>    `git filter-repo --invert-paths --path .context/spikes/T-1736-prompts.jsonl --force`
> 5. Re-add the upstream remote (filter-repo strips it):
>    `git remote add origin <upstream-url>`
> 6. Fetch and reset to upstream:
>    `git fetch origin && git reset --hard origin/master`
> 7. Continue to Step 3
>
> ---
>
> **Step 3 — Verify**
>
> ```
> git log --all -- .context/spikes/T-1736-prompts.jsonl
> ```
> Must return empty.
>
> ```
> agents/git/lib/secret-scan.sh scan-tree
> ```
> Must return zero findings. If the script is missing, your clone is older
> than 2026-05-15 — `git pull` first, then re-run.
>
> ---
>
> **Step 4 — Report**
>
> Post a single-line report back to the bus channel **`framework-purge-T-1834`**:
>
> ```
> bin/fw bus post --task T-1834 --agent purge-worker \
>   --summary "host=<hostname> path=<clone-path> outcome=<option-A|option-B|unaffected> head=<new-sha-or-na>"
> ```
>
> If `fw bus post` is unavailable on the target, fall back to:
>
> ```
> termlink emit --tag T-1834-purge --kv "host=<hostname>,outcome=<...>,head=<...>"
> ```
>
> ---
>
> **Refuse if**
>
> - You cannot identify the framework clone unambiguously
> - You see uncommitted work that would be lost and cannot be safely stashed
> - The upstream URL is unknown or unreachable
> - You are unsure whether this is a framework clone vs a vendored consumer copy
>
> **Escalate to human if**
>
> - `filter-repo` fails for any reason
> - Step 3 scan-tree still finds hits after Step 2
> - Re-clone (Option A) cannot reach the rewritten upstream within 5 minutes
> - You find more than one clone of the framework on the same machine — purge
>   one at a time, reporting after each
>
> **Do not**
>
> - Read or list the contents of `.context/spikes/T-1736-prompts.jsonl`
> - Quote the leaked credential in chat, even by reference to its value
> - Push to any remote you didn't originally pull from
> - Apply this purge to consumer projects (those with vendored `.agentic-framework/`)

---

## Verification (for the operator who dispatched this prompt)

After the worker reports back, verify by cross-checking the bus channel:

```
bin/fw bus manifest T-1834 | grep purge-worker
```

Expected: one entry per dispatched target, each with `outcome=` set to
`option-A`, `option-B`, or `unaffected`.

Re-dispatch to any target whose report did not arrive within 30 minutes.

---

## Related

- T-1828 — original mirror-stall task (this purge closes it)
- T-1834 — anchor task (in framework repo)
- T-1843 — mirror stderr observability (surfaced GH013 as the real cause)
- T-1844 — pre-commit secret-scan hook (prevents the next instance at commit time)
- L-378 — never quote secret values verbatim in chat
