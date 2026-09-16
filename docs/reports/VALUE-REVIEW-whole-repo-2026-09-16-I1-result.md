# I1 — RESOLVED: write-time hooks fire; the counter that said otherwise is racy

**Task:** T-3370 · **Date:** 2026-09-16 · **Authorised by the operator** ("run the I1 check").
Confidence: **MEASURED** (direct observation, reproduced).

## The question

Judge finding I1: *"Do the ~12 hooks matched only on `Write|Edit` actually fire?"* — raised
because both independent `.hook-counter` snapshots in the evidence (A §16, B §15) listed
**only** hooks matched on `Bash` or `*`. If write-time gates were not firing, the
framework's central claim (yardstick C1: "enforced structurally, not by agent discipline")
would be false.

## The pre-registered check, run verbatim

> "Under a scratch task, copy `.hook-counter`, perform **one** Edit on a task file, and
> diff. The keys for those hooks either appear or they do not."

Run under T-3370 with a single `Edit` **tool call** — not a `sed`, which would have fired
`Bash` hooks and answered a different question.

## Result — the gates are live

Every `Write|Edit`-matched hook incremented by exactly 1 on one Edit:

| hook | before | after |
|---|---|---|
| check-arc-id | 7 | 8 |
| check-onboarding-gate | 7 | 8 |
| check-human-ac-tick | 7 | 8 |
| check-inception-schema | 7 | 8 |
| check-inception-decisions | 7 | 8 |
| check-heredoc-cmd-sub | 7 | 8 |
| check-worktree-governance-write | 7 | 8 |
| check-settings-edit | 7 | 8 |
| commit-cadence | 7 | 8 |
| check-active-completed-dup | 6 | 7 |
| check-fabric-new-file | 4 | 4 — **correctly** unchanged: PostToolUse on *new* files |

**I1 outcome: healthy.** Not DELETE, not ADD. The judge listed "healthy" as a possible
outcome and it is the one that occurred.

## But the instrument is broken — a real defect, found underneath the false alarm

`lib/hook-telemetry.sh:_fw_telemetry_increment` is a **non-atomic read-modify-write**:
`mapfile` the whole file → edit the array in memory → `printf '%s\n' "${lines[@]}" > "$file"`.
No lock, no temp-and-rename. Two hooks firing concurrently both read, both write, and the
**last writer wins with its own stale view** — silently discarding every key it had not read.

Reproduced with the framework's own function (`docs/reports/VALUE-REVIEW-I1-race-repro.sh`),
8 processes × 200 increments:

```
expected: 8 keys x 200 = 1600 total
actual keys: 3
actual sum: 17
duplicate keys: k6
```

**98.9% of increments lost. 5 of 8 keys vanished from the file.** A duplicate key appeared —
which is exactly the damage visible in the live file today:

```
$ cat -A .context/working/.hook-counter | head -4
budget-gate=39$
$                     <- blank line (empty key)
budget-gate=31$       <- shadowed stale duplicate, never incremented again
check-active-completed-dup=7$
```

The first `budget-gate` is the live one; the second is a corpse from a clobbered write.

## What this explains, and what it costs

- **It explains I1 itself.** The two evidence snapshots showing "only Bash/* hooks" were
  **clobbered files**, not evidence of unfired gates. The alarm was an instrument artefact.
  Seven concurrent workers were running during this review — precisely the condition.
- **It is a C2 false green of its own.** `fw doctor` and the T-1629 hook-threshold
  escalation both consume this counter. Hook-failure escalation is therefore reading
  lossy data and will under-report: a monitoring instrument that silently loses ~99% of
  its signal under load reads identically to a quiet, healthy system.
- **The counter cannot be cited as evidence of anything** in any session that ran
  concurrent workers — including, in both directions, in this review.

## Not fixed

Research is not authorization. Candidate fixes — `flock` around the read-modify-write, or
write-to-temp + atomic `mv` — both need weighing against the file's own stated **<5 ms per
fire** budget (`lib/hook-telemetry.sh:15`), which is why it was written lock-free in the
first place. That is a design call, filed as **OBS-417**, for the operator.
