# T-3041 spike — does a shared POSIX group make concurrent multi-uid writes safe, or does it convert clean failures into silent lost updates?

**Task:** T-3041 (inception) · **Type:** empirical spike · **Date:** 2026-08-16
**Claim under test:** `docs/reports/T-3041-multi-uid-aef.md` §5A —

> "does **not** fix rows 5/6, and makes them worse in a specific way — today a
> second principal gets a clean `EACCES`; group-writable, it gets a *successful*
> write that silently discards the other's state. Setgid inheritance also does
> not apply to files moved in from outside the tree, which is exactly how the
> temp+`mv` aggregates are written."

This is a measurement, not an argument. Every number below is from a run on this
host with two real uids.

---

## 1. Setup

| Item | Value |
|---|---|
| Principals | `root` (uid 0) and `dimitri-mint-dev` (uid 1000), via `sudo -u` |
| Shared group | **`ollama` (gid 985)** — pre-existing, contains *both* principals (`getent group ollama` → `dimitri-mint-dev,root`) |
| Groups created | **none** — no `/etc/group` mutation was needed or performed |
| Scratch dir | `/tmp/t3041-spike-IlIdou/` (created, used, removed) |
| Framework state touched | none — only this report file was written under `/opt/999-…` |
| Iterations | **200 per principal per experiment = 400 expected**, both processes released by a wall-clock barrier so the measured window is genuine contention |
| Group-write config | target dir `chgrp ollama; chmod 2775` (setgid), both workers run under `umask 0002` |
| Payload | a `focus.yaml`-shaped document (~240 bytes, 8 keys) plus a `counter`, so the read-modify-write window is realistic rather than a single integer |

Harness: `worker.py` (three modes — `rmw`, `tmpmv`, `append`) + `run.sh` driver.
Every failure is caught and classified rather than raised, because *which*
failures are silent is the entire question.

**Honest caveat on harness loudness.** My worker fails loudly on a torn read (a
Python `yaml.YAMLError` / empty-document exception). The real call sites do not:
`agents/context/lib/pattern.sh` pipes the file through `awk`, which will happily
process a truncated file and emit a truncated result with exit 0. So the
"loud failure" counts below are an **upper bound** on how loud the framework
actually is. Where I report a parse error, the framework reports nothing.

---

## 2. E1 — in-place read-modify-write, shared group + setgid + umask 0002

Both principals: `yaml.safe_load` → `counter += 1` → `open(path,'w')` truncate +
`safe_dump`. This is the `.context/working/*` shape (row 5).

| Run | Expected | Successful writes | Final counter | Lost | Error classes |
|---|---:|---:|---|---:|---|
| main | 400 | 114 | **file unparseable** | total | `YAMLParseError` 240, `EmptyRead` 46 |
| rep1 | 400 | 76 | **file unparseable** | total | `YAMLParseError` 275, `EmptyRead` 49 |
| rep2 | 400 | 216 | 181 | 219 | `YAMLParseError` 27, `EmptyRead` 157 |
| rep3 | 400 | 50 | **file unparseable** | total | `YAMLParseError` 304, `EmptyRead` 46 |

**Zero permission errors. The shared group worked exactly as advertised — and
that is the problem.** In 3 of 4 runs the shared file ended structurally
corrupt. The surviving run lost 219 of 400 updates (55%).

The corruption is not subtle. The final file from the main run:

```yaml
blockers: []
counter: 59
current_task: T-3041
focus_session: S-2026-0816-SPIKE
last_writer: root
oot: 45          # ← tail of "root: 45" from a longer previous write
ot: 21           # ← same, one truncation later
pending_decisions: []
priorities: []
reminders:
- Run audit before pushing
- Create handover before ending session
witness:
  dimitri: 68
  root: 87
56               # ← orphaned integer, no key
```

Mechanism: `open(path,'w')` truncates to 0 then writes N bytes. A second writer
whose document is *shorter* leaves the previous writer's tail bytes in place.
There is no atomicity anywhere in this shape.

---

## 3. E2 — temp file + rename, shared group + setgid

The `pattern.sh` shape (row 6): write a temp file, `mv` it over the target.
`os.replace` is the same `rename(2)` syscall coreutils `mv` uses on one
filesystem. Two variants: temp created **outside** the tree (`mktemp` with no
args — the literal `pattern.sh:124` shape) and **inside** the setgid dir.

| Run | Variant | Expected | Successful writes | Final counter | **Lost** | Errors | Final mode/owner |
|---|---|---:|---:|---:|---:|---|---|
| E2a | tmp outside | 400 | 400 | 200 | **200** | **none** | `600 dimitri:dimitri` |
| E2b | tmp inside setgid | 400 | 400 | 200 | **200** | **none** | `600 dimitri:ollama` |
| rep1 | tmp outside | 400 | 400 | 200 | **200** | **none** | `600 dimitri:dimitri` |
| rep2 | tmp outside | 400 | 400 | 200 | **200** | **none** | `600 dimitri:dimitri` |
| rep3 | tmp outside | 400 | 320 | 200 | **200** | `EACCES` 80 | `600 root:root` |

**Every run lost exactly 200 updates — one principal's entire 200-write history,
discarded with zero diagnostic.** The file is never corrupt (rename is atomic),
never errors, and always parses. It is simply missing half the state. The
`witness` map in the surviving document contained only the winning principal's
key; the loser's contribution left no trace at all.

The 50% figure is exact rather than approximate because the two workers run at
comparable speed and leapfrog in lockstep: each reads value *v* and writes *v+1*,
so *N* rounds produce *N* increments regardless of which process wins each round.
That is a property of the shape, not of my timing.

### 3.1 Does setgid save the ownership? No.

rep3 is the interesting one: 80 `EACCES` appeared **mid-run**, because root won
an `mv` and the resulting file was `0600 root:root` — locking the other
principal out for the remainder. Deterministic sequential probes:

| Probe | Setup | Result after one root temp+mv | Next `dimitri` write |
|---|---|---|---|
| **P2** | setgid dir, tmp created **inside** the tree | `600 root:ollama` | **`EACCES` 5/5** |
| **P3** | setgid dir, tmp created **outside** (`pattern.sh` literal) | `600 root:root` | **`EACCES` 5/5** |

Setgid propagates the *group* correctly when the temp file is made inside the
tree (`root:ollama`, P2) — and it makes no difference, because **`mkstemp`/
`mktemp(1)` hard-code mode `0600`, which `rename(2)` preserves verbatim.** The
group is right and the group bit is gone. `umask 0002` is irrelevant: umask can
only clear permission bits, and `mktemp` never offers any to clear.

So for row 6, Candidate A as specified does not even deliver the group-writable
outcome it is being blamed for. It delivers `0600`, owned by whoever wrote last.

---

## 4. E3 — append-only JSONL (control)

Both principals `open(O_WRONLY|O_APPEND|O_CREAT)` and `os.write` one JSON line
per iteration.

| Expected lines | Actual lines | Torn/interleaved | Per-writer | Unique `(writer,i)` pairs | Lost |
|---:|---:|---:|---|---:|---:|
| 400 | **400** | **0** | root 200 / dimitri 200 | 400 | **0** |

Every line parsed as JSON. Line lengths fall in 49–57 bytes with no outliers —
no concatenation, no truncation. File is newline-terminated. Final mode
`664 root:ollama`; no ownership flip is possible because the file is never
recreated.

**The control holds exactly as `lib/outcome.py` documents it.** This is the one
shape in the framework that de-roots for free.

*(Correction to my own first pass: an initial trailing-newline check reported
`False`. That was a heredoc-quoting bug in the checking script — `b'\n'` reached
Python as a literal backslash-n. Verified directly with `od -c`: the file ends
`}\n`. E3 is clean; the finding is unchanged.)*

---

## 5. E4 — no shared group, default permissions

What does the framework do *today*, before any group change?

| Run | Setup | Second principal | Expected | Successful writes | Final | **Lost** | Error class |
|---|---|---|---:|---:|---:|---:|---|
| **E4a** | root-owned `644`, concurrent | dimitri | 400 | 200 (all root) | 200 | 200 | `EACCES` 37 + **`EmptyRead` 163** |
| **P1** | root-owned `644`, **sequential** | dimitri | 200 | 0 | — | 200 | **`EACCES` 200/200 — clean** |
| **E4b** | dimitri-owned `644`, concurrent | **root** | 400 | 290 | 200 | **90** | **none — zero `EACCES`** |
| **E4c** | dimitri-owned, root uses temp+mv | **root** | 400 | 400 | 200 | **200** | **none — zero `EACCES`** |
| **P4** | E4c aftermath (`600 root:root`) | dimitri next write | 5 | 0 | — | — | `EACCES` 5/5 |

Three things fall out:

1. **The clean-`EACCES` premise is true only uncontended.** P1 (dimitri alone
   against a root-owned file) is a perfect 200/200 `EACCES` — exactly the
   artefact's description. But under actual concurrency (E4a) only 37 of 200
   attempts reached the permission check: the other **163 died earlier on a torn
   read**, because root's truncate-write left the world-readable file empty or
   half-written. 82% of today's failures in that direction are already
   *corruption*, not a clean refusal.

2. **When the second principal is root, today's behaviour is already the silent
   lost update.** E4b: zero permission errors anywhere, 90 updates silently
   discarded. Root's DAC bypass means it never sees `EACCES` on anyone's file.
   Half of the multi-uid matrix loses state silently *right now*, with no group
   and no config change.

3. **Row 6 already fires today.** E4c: root writes a dimitri-owned aggregate via
   temp+mv, 400/400 succeed with no error, 200 updates vanish, and the file ends
   `0600 root:root` — after which dimitri gets `EACCES` on every subsequent write
   (P4). The ownership-flip lockout the artefact predicts for row 6 does not
   require the shared group. It is the current behaviour.

---

## 6. Verdict

**The claim's direction is confirmed; its premise is overstated, and Candidate A
is worse than the artefact says.** The second half is proved and then some: under
a shared group + setgid + umask, temp+`mv` produced 400/400 *successful* writes
across six runs while silently discarding exactly 200 updates each time — one
principal's entire history, no error, no corruption, no trace, a file that parses
cleanly and is simply wrong; and the in-place `.context/working/` shape is worse
still, ending structurally unparseable in 3 of 4 runs. But the premise "today a
second principal gets a clean `EACCES`" holds only for an unprivileged second
principal writing uncontended (P1: 200/200 clean). When the second principal is
root — which is the actual AEF situation, since root is the incumbent writer —
today's failure is *already* the silent lost update (E4b: 90 lost, zero errors;
E4c: 200 lost plus an ownership lockout), because root bypasses DAC entirely. So
Candidate A does not create the silent-loss failure mode; it *generalises* an
existing one from the root-writes direction to both directions, which is still a
strict worsening but not the clean loud→silent conversion the artefact describes.
The sharper finding is the one the artefact only gestures at: for row 6 Candidate
A **does not even buy the shared write it is trading safety for** — `mktemp`
hard-codes `0600` and `rename(2)` preserves it, so the aggregate lands `0600`
owned by the last writer and the other principal is locked out on the next write
whether or not the temp file was created inside the setgid tree (P2 `600
root:ollama` → `EACCES` 5/5; P3 `600 root:root` → `EACCES` 5/5). Setgid fixes the
group and the mode denies it; `umask 0002` cannot help because `mktemp` never
offers a bit to clear. Meanwhile the append-only control was flawless — 400/400
lines, zero torn, zero lost — which is the actionable half of the result: the
evidence points at Candidates B/E (per-principal split, append-only aggregates),
and says a shared group is not merely insufficient for rows 5/6 but actively
converts a detectable failure into an undetectable one in the one direction that
currently still fails loudly.

### Implications for the inventory table (§3 of the artefact)

- **Row 5** — verified. In-place RMW on `.context/working/*` corrupts, not just
  loses. Promote from "inferred" to measured.
- **Row 6** — verified, and it fires **today** without any group change (E4c/P4).
  The `mv`-replaces-ownership lockout is current behaviour, not a Candidate A
  side-effect.
- **Row 7** — verified again, independently. Append-only is clean under two uids.
- **New**: root's DAC bypass makes the failure matrix asymmetric. Any reasoning
  that treats "second principal" as symmetric will mispredict half the cases.

### What this does not prove

Both principals here were root and one unprivileged user. A genuine
two-*unprivileged*-principal test would need a second ordinary uid, which I did
not create (creating users was outside the scratch-only constraint). P2 and P3
exercise the decisive group-mediated path directly — a root-created `0600
root:ollama` file versus a fellow group member — so the Candidate A conclusion
does not depend on the missing case. The E4b/E4c asymmetry findings are
specifically *about* root and do not generalise to two unprivileged principals.

---

## 7. Artefacts created and removed

| Created | Removed |
|---|---|
| `/tmp/t3041-spike-IlIdou/` (scratch: `worker.py`, `run.sh`, 13 experiment dirs, `results/`) | yes — `rm -rf` after measurement |
| POSIX groups | **none created** — used the pre-existing `ollama` (gid 985) |
| Users, system files, `/etc/group`, `/etc/passwd` | **none touched** |
| Temp files under `/tmp` from `mktemp` | consumed by `rename(2)`; failure paths `unlink`ed; leftovers swept in cleanup |
| Framework state (`.context/`, `.tasks/`, `/var/lib/termlink`, hub, services) | **not touched** |
| Files written under `/opt/999-…` | this report only |
