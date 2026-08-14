# T-2909 — The enforcement baseline cannot name what changed, and its remedy launders the loss

**Status:** exploration in progress
**Opened:** 2026-08-10
**Origin:** 832 rail 517 §5 (their probe cleanup removed `check-tier0` for two tool calls)

---

## The claim, stated so it can be falsified

> The framework can lose `check-tier0` — the only gate on destructive Bash — and reach a
> state where every surface that watches reports green, having followed its own printed
> instructions at each step.

Three independent defects compose to produce this. Each is verified below against the
live tree, not reasoned from the code's shape.

---

## D1 — `fw hook-enable` has no inverse

| | |
|---|---|
| Verb exists | `bin/hook-enable.sh`, 188 lines, T-1189, idempotent, atomic `os.replace` |
| Inverse exists | **no** — `grep -rn "hook-disable\|hook_disable\|hook remove" bin/ lib/ agents/` returns nothing |
| Surface it guards | `.claude/settings.json`, holding `check-tier0`, `check-active-task`, `budget-gate`, `block-plan-mode`, +13 |

Removing a hook is therefore hand-edited JSON on the highest-consequence file in the
repo. **The asymmetry does not make removal rare — it makes removal improvised.**

This half is 832's finding, reported at rail 517 §5. Filed their side as OBS-014 + PL-144
("remove by command, never by group"). They explicitly did not fix it in our tree.

### The co-tenancy that makes it sharp here

`bin/hook-enable.sh:150-157` merges into the **first** block whose matcher matches. Our
live groups:

```
PreToolUse  Write|Edit                  n=7   <- check-human-ac-tick, check-active-completed-dup,
                                               check-arc-id, check-heredoc-cmd-sub,
                                               check-inception-decisions, check-inception-schema,
                                               check-onboarding-gate
PreToolUse  Bash                        n=1   <- check-tier0
PreToolUse  Write|Edit|Bash             n=1   <- check-active-task     (x3 duplicate groups)
```

Any future `Write|Edit` hook merges into the n=7 group. A group-scoped removal there
takes six unrelated gates with it — including `check-onboarding-gate`, which is arc-017's
entire shipped mechanic.

832's accident hit their `Bash` group. Ours is 7 deep on `Write|Edit`.

---

## D2 — detection is a single opaque bit

`bin/fw:2248-2266` compares one sha256 over `json.dumps(data.get('hooks',{}), sort_keys=True)`.

**Measured 2026-08-10** on a copy of the live `.claude/settings.json` (the real file was
never modified):

| scenario | hooks hash | `fw doctor` prints | `check-tier0` registered |
|---|---|---|---|
| baseline | `962690887ee10cb6` | `OK   Enforcement baseline intact` | yes |
| add one probe hook on `Bash` | `4a80de2ac8715e0e` | `FAIL Enforcement baseline CHANGED` | yes |
| delete `check-tier0` | `08341179c2aa8e4b` | `FAIL Enforcement baseline CHANGED` | **no** |

The bottom two rows are **the same event** at the only surface that watches. The detector
knows the enforcement surface moved; it cannot say which way, and nothing else asks.

This is L-531 exactly — *witnesses over counts: a diagnostic that emits a count collapses
the distinction it exists to preserve.* A hash is a count with one bucket.

---

## D3 — the remedy launders the loss

The FAIL line prints its own next step:

```
FAIL  Enforcement baseline CHANGED — settings.json hooks differ from baseline
      Run 'fw enforcement baseline' to update after review
```

That writer is `bin/fw:7748-7770`. It recomputes the hash over whatever is currently on
disk, prints `Enforcement baseline saved`, and **never diffs against the prior baseline,
never enumerates hooks, never distinguishes an addition from a removal.** There is no
"after review" step in the code — the phrase is advice to a human, with nothing checking
that it happened.

So the sanctioned response to D2's ambiguous FAIL makes an accidental deletion permanent,
and the next `fw doctor` reports `OK Enforcement baseline intact` with Tier 0 gone.

And it is actively nudged: `agents/context/check-settings-edit.sh` (T-1886) is a
PostToolUse hook on `Write|Edit` whose entire job is to remind the agent to re-baseline
after editing settings.json. Exit code always 0, advisory only. It was built to stop the
baseline sitting in FAIL — a real problem (T-1849, T-1730, T-1731 each left it red across
sessions). The fix for *baseline noise* is the delivery mechanism for *baseline laundering*.

### Why D3 is the one that matters

D1 and D2 alone are untidy. D3 closes the loop: **the recovery path erases the witness.**
After re-baselining, the green reading is byte-identical to a correct one, and no
artefact anywhere records that a gate was dropped.

Same family as L-506 (silent empty-scan fallback), L-570 (`2>/dev/null` reading as
"not configured"), T-2902 (max-over-nothing returns the seed). New leg, not previously
named in that family:

> **The detector's own sanctioned remedy destroys the evidence the detector produced.**

The prior legs are all *read* failures — a scan that cannot see. This is a *write*
failure: the system correctly saw, correctly reported, and then was instructed to forget.

---

## Open questions (mirrored from the task; dispositions live there)

- **IW-1** — manifest of named commands beside/instead of the blob hash?
- **IW-2** — is "hook removed" a FAIL `fw enforcement baseline` may accept at all?
- **IW-3** — does `fw hook-disable` need to exist, or does D1 dissolve once D2/D3 land?
- **IW-4** — can the wiring be verified, or does this share 832's §4 blind spot?

---

## Dialogue Log

### 2026-08-10 — 832 rail 517 §5, unprompted

832 reported D1 after cleaning up a probe hook they had registered on `Bash` to test
whether their own new gate was live. `fw hook-enable` had merged the probe into the
existing `Bash` group; removing "their" hook by filtering groups deleted the co-tenant
`check-tier0`. Restored byte-exact within two tool calls (`git diff`: a 9-line addition
and nothing else). Their Verification block now asserts `check-tier0` is still registered
— a regression guard added by the task that removed it.

Their framing: *"An asymmetry like that does not make removal rare — it makes removal
improvised, on the highest-consequence file, with nothing watching."*

**What I did with it.** Checked whether the finding was worse here than there rather than
taking it as read. It is, in a way they could not have seen from their side: their
accident was caught by a human within two tool calls, whereas ours has a *documented,
nudged* path (`fw enforcement baseline`) that would have made the same accident silent
and permanent. D2 and D3 are not in their report.

**Second-order, worth recording.** This is the third time in this thread that 832
reporting a weakness on their side measured something on mine — the 400-of-474 number,
the §4 typed-by-hand admission (which produced T-2908), and now this. The incentive runs
the other way each time: a clean-looking report would have left all three defects here
intact. Noted at rail 516 §3 and it has held.

---

## Prior stated, for falsification

Before running S1 (git history of settings.json hook changes) I expect:

- **IW-2** — that removals of *framework-owned enforcement* hooks are historically ~zero,
  and every historical change is an addition or a generator-driven reorder. If that
  holds, IW-3 shrinks to project-local `--script` hooks only.
- I expect at least one *reorder* caused by `fw upgrade` regeneration, which would be a
  third change class the manifest must tolerate without crying wolf.

Recording the prediction before the measurement so it can be wrong.

---

## S1 — every hook change in the history of `.claude/settings.json`

28 revisions touch the file. Each revision's hook set was extracted from the blob at that
sha and diffed against its predecessor. Run twice, under two different keys:

| key | revisions reporting a REMOVAL |
|---|---|
| `(event, matcher, name)` | **2** — `audit-task-tools` (2026-04-20, T-1364), `check-active-task` (2026-05-05, T-1730) |
| `name` only | **0** |

Plus one more under the raw-command key: T-496 (2026-03-14) reported 11 removals at once.

**Every single one is a false positive.** T-496 is the migration from `<script>.sh` paths
to the `fw hook <name>` form — a rename of all 11. T-1730's subject line is literally
*"Bash matcher + focus-drift gate on check-active-task"*: the hook moved from `Write|Edit`
to `Write|Edit|Bash`. T-1364 ("absolute hook paths at fw init/upgrade") is the same class.

### What this settles

**IW-2 — answered, confidence 3.** A framework-owned enforcement hook has never once been
legitimately removed in 5 months and 28 revisions. Every apparent removal is a rename or
a matcher move. So "hook removed" is not an event `fw enforcement baseline` should ever
accept silently; there is no legitimate case to accommodate.

**IW-1 — answered, confidence 3, and the key is now measured rather than guessed.** The
manifest must key on **hook name alone**. The Technical Constraints section reasoned its
way to name-keying from the consumer-vs-framework command-prefix difference (T-1504 /
T-2709); S1 shows the same conclusion is forced independently by history — a manifest
keyed on `(event, matcher, name)` would have cried wolf 3 times, and one keyed on the raw
command string 4 times, on changes that were all correct.

That gives the proposed rail an unusually clean profile, which is the whole argument for
it:

> **Zero false positives across the entire recorded history. One true positive, on the
> accident that started this.**

**IW-3 — dissolved for the case that matters.** 832's remedy direction was a
`fw hook-disable` verb. S1 says that verb has no framework-owned work to do: there is
nothing to disable, ever. It remains genuinely useful for **project-local `--script`
hooks** — the probe case that caused 832's accident — but it is not the load-bearing fix.
The load-bearing fix is D2/D3, and a `hook-disable` verb built without them would still
launder a mistake made by hand.

### Where the prediction was wrong, and why that matters

I predicted "additions plus generator-driven reorders". I got additions plus **renames and
matcher moves** — a stronger version of the same class, and one that bites harder: all
three noise sources are invisible under name-keying but loud under any richer key. Had I
built the manifest on the obvious key `(event, matcher, command)` — which is exactly the
tuple `hook-enable` itself uses for idempotency, and therefore the natural thing to reach
for — it would have fired on 3 of the 4 largest legitimate refactors in the file's
history, been dismissed as noise, and been switched off before it ever caught anything.

That failure mode is not hypothetical here: it is how the check-settings-edit nudge came
to exist (baseline noise → advice to re-baseline → D3).
