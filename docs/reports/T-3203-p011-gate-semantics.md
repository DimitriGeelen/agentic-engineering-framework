# T-3203 — what P-011 actually does to a verification line

**Verdict: the gate was right, the documentation was wrong, and the rehearsal
the documentation prescribed was wrong in the direction that hides the defect.**

## The gate's shape

`agents/task-create/update-task.sh:1215`:

```bash
if (unset TASKS_DIR CONTEXT_DIR _FW_PATHS_LOADED; eval "$_close_locks_cmd"; cd "$PROJECT_ROOT" && eval "$cmd") > /tmp/verify-$$.out 2>&1; then
```

A subshell that **is the condition of an `if`**, inside a script running
`set -euo pipefail` (line 14). POSIX suppresses errexit for a compound command
in an `if` condition, and that suppression reaches through the subshell.

Therefore, measured not assumed:

| option | state in the gate | evidence |
|---|---|---|
| `pipefail` | **LIVE** | `false \| true` → FAIL |
| `errexit` | **SUPPRESSED** | `false; true` → PASS |

## The consequence

In `cmd1; cmd2` only `cmd2`'s status reaches the verdict. So this passes:

```
cd /nonexistent; echo ok
```

Setup fails, the assertion never meaningfully runs, the line reports success.

## Blast radius

Re-derive rather than trust:

```bash
python3 - <<'PY'
import glob,re
tot=semi=0
for f in glob.glob('.tasks/active/*.md')+glob.glob('.tasks/completed/*.md'):
    s=open(f,encoding='utf-8',errors='replace').read()
    m=re.search(r'^## Verification\s*$(.*?)(^## |\Z)', s, re.M|re.S)
    if not m: continue
    for ln in m.group(1).split('\n'):
        t=ln.strip()
        if not t or t.startswith('#'): continue
        tot+=1
        if ';' in t: semi+=1
print(tot, semi)
PY
```

**10,997 verification lines; 2,644 contain `;`** (2026-08-28). Not 2,644 defects —
most put the assertion last, which is correct. It is the population in which the
defect can hide, which is the number that matters for deciding whether to change
the gate.

## The rehearsal was wrong

The template prescribed `bash -c 'set -eo pipefail; <line>'`. That adds an
errexit the gate does not have. Measured over 10 lines, 3 diverge:

| line | gate | `set -eo` (old) | `set -o` (corrected) |
|---|---|---|---|
| `false; true` | PASS | **FAIL** | PASS |
| `cd /nonexistent; echo ok` | PASS | **FAIL** | PASS |
| `grep -q MISS f; true` | PASS | **FAIL** | PASS |
| `false \| true` | FAIL | FAIL | FAIL |
| `true \| grep -q MISS` | FAIL | FAIL | FAIL |
| `false && true` | FAIL | FAIL | FAIL |
| `true` / `false` | PASS / FAIL | PASS / FAIL | PASS / FAIL |

**The divergence is one-directional**: the old wrapper only ever fails lines the
gate accepts. That is why it survived — it produces false REDS, never false
greens, so it never let anything broken through. But it is not harmless: an
author who "fixes" a line to satisfy it is repairing something that was never
broken, while the line that genuinely is broken (`cmd1; cmd2` where cmd1 fails)
passes *both* and is never surfaced by either.

Pinned by `tests/unit/t3203_p011_gate_semantics.bats` (11 tests), including a
guard on the gate's own shape so the file cannot keep passing against a gate that
has changed.

## Provenance of this measurement

Peer 832 raised the P-011 errexit property on the chat arc; peer 577 independently
measured their own rehearsal wrapper wrong in both directions the same morning.
Both are corroboration, not the source: every row above was re-measured here
against this repository's own `update-task.sh`, because a claim inherited from a
peer's codebase is a hypothesis about ours, not a finding in ours.
