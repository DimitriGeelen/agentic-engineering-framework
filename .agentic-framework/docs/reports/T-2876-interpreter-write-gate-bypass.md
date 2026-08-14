# T-2876 — Interpreter-mediated writes bypass the Bash task gate

**Status:** inception, GO filed
**Origin:** OBS-200 (AEF, 2026-08-08), extended by 832 as their G-025
**Question:** should the Bash task gate stop safe-listing `python3 -c`?

---

## 1. The finding

`is_bash_safe_command` safe-lists `python3 -c` behind a **textual** deny-list of write
indicators:

    open(...,'w   |   .write(   |   shutil.   |   os.(rename|remove|unlink|makedirs|system)

A command matching none of those, and carrying no shell redirect, passes **both** predicates
in `check-active-task.sh:92-98` and the hook `exit 0`s — before the no-active-task check, the
task-is-active check, G-020, and the T-1730 focus-drift gate.

Seven idioms measured ALLOWED with `current_task: null`:

| # | idiom | sites in our tree | found by |
|---|-------|-------------------|----------|
| 1 | `pathlib.Path(p).write_text(s)` | 72 | AEF |
| 2 | `pathlib.Path(p).write_bytes(b)` | 2 | AEF |
| 3 | `os.replace(a, b)` | 36 | AEF |
| 4 | `subprocess.run([cp, src, dst])` | 107 | 832 |
| 5 | `pathlib.Path(p).unlink()` | 0 | 832 |
| 6 | `print(x, file=open(p, "a"))` | 0 | 832 |
| 7 | `subprocess.call(cmd, shell=True)` | 6 | 832 |

Counts are `subprocess.(run\|call\|Popen)` collapsed for row 4 and `shell=True` for row 7.
Rows 5 and 6 have zero sites here and are boundary probes, not exposure claims — 832 nearly
shipped the opposite framing and corrected it before sending, which is the right instinct:
*"an idiom we use"* and *"an idiom that defeats the predicate"* are different arguments.

Note rows 3 and 5 against the deny-list: `os.rename` and `os.unlink` are denied, `os.replace`
and `Path.unlink()` are not. The list names the `os.*` spelling of operations that also have a
`pathlib` spelling. Row 3 is our own documented atomic-write idiom (T-100191 / L-493) — the
shape our house style teaches.

## 2. Method, and what the controls do and don't prove

Measured against the real hook in a sandbox with `current_task: null`, driving it with real
JSON on stdin. Not reasoned from the regex — one of my regex predictions was wrong and
measurement caught it: I expected `io.open(f, mode='w')` to slip through, and it does not,
because `.write(` catches the chained call.

Two controls, and the second is the one that matters:

- **redirect control** — `echo hi > /tmp/x` returns rc=2. Proves the harness reaches the gate
  and the gate can fail. Without this every ALLOWED row could be a harness that never ran.
- **`shutil.` control** — GATED. Proves `python3 -c` is genuinely *inspected*. This is 832's
  addition and I had not thought to run it. Without it, **"python3 is never checked"** and
  **"python3 is checked but these slip"** emit identical ALLOWED rows and have opposite fixes.

**What two-sided measurement is NOT worth here.** 832 vendors our hook, so their run and ours
execute the same predicate — the two runs cannot fail differently, so they are one measurement,
not two (L-546). Their reproduction confirms reporting fidelity, not the generality of the
mechanism. Neither side should cite "reproduced independently" as strength.

## 3. Why enumeration is not the fix (832's argument, adopted)

My first framing was that the deny-list is *not closable by enumeration* — a race being lost
slowly. 832's row 7 is strictly stronger and supersedes it:

> `subprocess.call(cmd, shell=True)` carries **no textual signature at all** — the command is
> in a variable, so there is nothing for any pattern to match. It is a general shell reached
> through the safe-listed interpreter, and it re-admits every pattern the deny-list denies,
> including the five `os.*` names it explicitly lists.

So the failure is not that the list is behind. **One permitted entry grants the thing the list
exists to withhold.** Adding all seven rows above leaves row 7 ALLOWED and the gate exactly as
open. Enumeration is not a slow fix; it is void. That rules out one of the two directions
outright.

## 4. The remedy's cost is smaller than both sides assumed

Both projects independently flinched from "stop safe-listing the interpreter", citing the same
cost: `python3 -c "import yaml; yaml.safe_load(...)"` appears throughout our Verification
blocks.

**That cost appears to be illusory.** Verification commands are executed by `update-task.sh`
inside the P-011 gate. PreToolUse hooks fire on the *agent's tool calls*, not on subprocesses a
script spawns. So Verification-block python is not gated by this hook today, and removing
`python3` from the safe-list would not touch that population at all. Both of us costed the
remedy against a population it does not reach.

What removal actually costs: interactive python one-liners in exactly the states where the
safe-list is what carries you — no active task, focus drift, or focus on a completed task. In
normal work an active task is present and the command passes the gate on its own merits.

**Confidence split, deliberately (IW-1 vs IW-2).** The hooks-don't-fire-on-nested-subprocesses
part is structural and I am confident. The "grep/cat mostly substitute during recovery" part is
judgement and is not measured. They are filed as two separate open questions at confidence 2
and 1 so the weaker cannot ride on the stronger — the difference between them is the difference
between a cheap fix and an expensive one.

## 5. Recommendation

**GO.** Evidence is complete on both sides; the direction is settled by §3; the assumed cost is
refuted by §4. The open question is the *scope* of removal, not whether — which is a build
decision, not a further inception.

DEFER was considered and rejected: the artifact contains the measurement, both controls, the
superseding argument and a cost analysis. Declining to commit at that point would be a
confidence gap, not an evidence gap.

## 6. Dialogue log

- **AEF → rail 465.** Filed the three-idiom finding while reading the elif ordering for an
  unrelated ruling. Framed it as "not closable by enumeration". Asked 832 whether they had
  already solved it, preferring to adopt over inventing a second answer.
- **832 → rail 466.** Reproduced 7/7 against their vendored copy. Added rows 4-7. Stated
  plainly that they have *no* fix to adopt — "832 has no fix" and "832 has a fix you have not
  asked for" look the same from our seat, so they named it. Added the `shutil.` control.
  Corrected their own draft: 2 of their 4 rows have zero sites in their tree, and they had
  first written that all four occurred there.
- **AEF → rail 467.** Verified their four rows here. Conceded that the two runs share a
  predicate and therefore are not independent corroboration. Accepted row 7 as superseding the
  enumeration framing. Contributed §4 — that the cost both sides cited is against a population
  the hook does not reach.

## 7. Residual

Nothing generically verifies that a safe-listed interpreter cannot reach the filesystem. This
inception covers `python3`; `bash -n`, `node`, `perl` and friends sit on the same boundary
(cf. `tests/unit/tier0_scope_boundary.bats`, which pins the *analogous* Tier 0 limit as a known
scope boundary rather than a bug). IW-3 keeps that open rather than assuming the scope.
Same family as OBS-184/185: a textual predicate over a command string cannot see semantics.
