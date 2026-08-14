# T-2992 — Suppression without a register

**Status:** exploration in progress
**Filed:** 2026-08-14
**Parents:** T-2990 (incident + detection), T-2991 (prevention)

---

## Why this exists

T-2990 removed 56MB of ImageMagick PostScript from the repo root. T-2991 closed
the mechanism that wrote it — P-011 eval'ing the Python body of a multi-line
verification command as bash.

Neither addresses the part that actually cost three months.

The junk was written four times between 2026-05-04 and 2026-08-12. The first two
instances were *seen*. Someone noticed them, correctly worked out that the commit
path needed a gate, shipped that gate (T-1845's large-file scanner), and then
wrote this beside two new `.gitignore` rules:

```
# 2nd instance (2026-05-23 session): `sys` = 14MB ImageMagick PostScript export
# with literal filename "sys", created 2026-05-16. Same class as `/os` — some
# `convert/magick` call writes a bare extensionless output name into repo root.
# Gate blocks the COMMIT; CREATION is still un-prevented (root-cause task pending).
/sys
```

Read that last line again. It is an accurate statement of exactly what remained
open, written by someone who understood the problem. It names no task. No task
was filed. And the two lines it annotates removed `git status` — the only surface
that would have put the question in front of anyone again.

Two more instances followed. Neither was covered by those rules, so both *did*
appear in `git status`, as `??`, for days. Still nobody looked. By then the class
had been normalised: junk at the root was a thing that happened.

## The shape being explored

> A suppression that carries a deferral note, with no entry in a register that
> anything checks.

Three properties compound:

1. **The suppression is load-bearing.** It exists because the signal was real and
   noisy. Removing it is not obviously correct.
2. **The note is honest.** It records what is still open. This is why it feels
   like the work was captured.
3. **Nothing reads it.** `concerns.yaml` is scanned by `fw audit` and rendered in
   Watchtower `/gaps`. A comment beside an ignore rule has no reader and no
   expiry. It is worse than no comment, because it makes the suppression look
   considered — which is what stops the next person from asking.

## Open questions

| id | question | confidence at filing |
|----|----------|----------------------|
| IW-1 | How many suppression sites carry a deferral note with no task/gap id? | 0 — no data |
| IW-2 | Is a mechanical rail possible, or does "deferral note" need judgement? | 1 — suspect mechanical, unproven |
| IW-3 | Gate at write time, or audit at rest? | 1 — depends on IW-1 and IW-2 |

## Spike 1 — census

Time-box: 20 minutes. Scan suppression surfaces for deferral prose, and check
whether each names a task/gap/observation id.

Surfaces: `.gitignore`, `.secret-scan-allowlist`, `.large-file-allowlist`,
`.secret-scan-patterns`, bats `skip "..."`, pytest `skip`/`xfail`, reviewer
overrides.

### Results

| surface | sites w/ deferral prose | of those, naming no task/gap id |
|---|---|---|
| `.gitignore` | 6 | 3 raw → **1** after de-noising¹ |
| `.secret-scan-allowlist` | 1 | 0 |
| `.large-file-allowlist` | 0 | — |
| bats `skip "…"` | 3 | 3 raw → **1** genuine² |
| pytest `skip`/`xfail` | 2 | 2 raw → **0** genuine² |
| **total** | **12** | **~2** |

¹ Two of the three "unnamed" `.gitignore` hits are the T-2990 comment I wrote
today describing this very incident, and one is a wrapped continuation line of a
comment whose first line names T-2866. The single genuine historical instance is
the one this inception was filed about.

² Most test skips are **runtime-conditional**, not deferrals — `skip "No pending
proposals to render"` means the fixture had no data on this run. Only two are
real admissions of unfinished work:
- `tests/unit/t2924_update_task_owner_gate.bats:127` — `skip "legacy drift not yet reconciled"`
- `tests/unit/t2932_note_count_urgent_filter.bats:215` — `skip "no observation quotes the string yet — guard is not yet exercised"`

**Control probe:** deferral prose in ordinary `lib/` + `agents/` comments: **184**.

**Register, for comparison:** `concerns.yaml` holds **87** gap entries and is
actively used. The register is not the problem. Routing to it is.

### What the numbers actually say

Three findings, and the third is the one that matters:

1. **A1 holds, weakly.** Sites exist beyond the two `.gitignore` lines, but the
   genuine population is ~2, not ~40. The class is real and rare.

2. **A2 is refuted as stated, and IW-2 with it.** Prose is not a discriminator —
   184 comments across `lib/` and `agents/` carry the same vocabulary and are
   almost all ordinary explanation. Any rail keyed on "a comment promising future
   work" would be ~94% noise. The *suppression site* has to be the anchor, and
   the prose only the qualifier.

3. **Not all suppressions are equal, and this is the real finding.** The census
   makes an asymmetry visible that the original framing missed:

   | suppression | what it emits when it fires |
   |---|---|
   | `skip "…"` | prints `skipped` with its reason, **every run** |
   | allowlist entry | echoed by the scanner that consults it |
   | `.gitignore` rule | **nothing, ever** |

   A skipped test announces itself in the output of every suite run. An allowlist
   entry is visible wherever the scan reports. A `.gitignore` rule is the only
   one of the three that removes a signal **silently and permanently** — there is
   no run, no report, and no moment at which it says "I am suppressing something".

   That asymmetry is exactly what happened here. The `/os` and `/sys` rules did
   not merely fail to remind anyone; they deleted the surface that would have.
   The other two instances, uncovered by any rule, *did* keep appearing in
   `git status` — which is why they were at least visible, even though nobody
   acted.

   So the target is not "suppression sites" in general. It is the small subclass
   that is structurally silent.

## Dialogue Log

### 2026-08-14 — operator directive

> "also clean junk from root as suggested and RCA how it could endup tehre, and
> incept and implement a structural remediation"

Decomposed into three deliverables rather than one, because they are three
different questions with three different blast radii:

- **T-2990** — remove the junk, RCA the mechanism, detect the next instance.
- **T-2991** — prevent creation at the gate that was writing it.
- **T-2992** (this) — why did it survive three months? That is not the same
  question as "what wrote it", and fixing the mechanism does not answer it.

Splitting it this way was a judgement call, not a request. The operator asked for
"a structural remediation"; the mechanism fix (T-2991) is arguably that, and this
inception could be read as scope creep. It is filed because the RCA turned up an
explicit written admission that a root cause was known and unfiled, which is a
different failure from the one being remediated, and the four-instance history is
evidence that the mechanism fix alone would not have surfaced it any sooner.

### 2026-08-14 — hypothesis discarded before it could mislead

The first mechanism hypothesis was that an unbalanced quote inside
`python3 -c "…"` let the remainder execute as bash. It was wrong. A reproduction
with a fake `import` on PATH disproved it in one run: bash concatenates adjacent
quoted segments into a single argument, so Python still receives the whole body.

Recorded because the wrong hypothesis was plausible enough to have been written
into an RCA and believed. The filenames (`os`, `sys`, `yaml`, `yaml,sys`) were
the evidence that redirected the search — they map exactly to `import` lines, and
that only makes sense if something was executing lines of a Python body one at a
time. Which is precisely what P-011 does.

### 2026-08-14 — the spike moved the recommendation, and it should be said plainly

This inception was filed at **GO** on the strength of the incident. The rationale
predicted the census would justify a rail: *"the answer is useful whether the
count is 1 or 40."*

The count came back ~2, and the control probe came back 184. Both cut against the
version of the rail I had in mind when filing — a scan for deferral prose. On
that evidence, a prose-keyed rail is not worth building: it would carry a ~94%
false-positive surface to police a population of two.

The recommendation stays GO, but for a **materially narrower** thing than filed,
and it is the census that narrowed it. What survived is not "find deferral
notes"; it is the structural asymmetry the census exposed — `.gitignore` is the
only common suppression that emits nothing when it fires. That target is small,
sharp, cheap, and would have caught this exact incident. Everything else the
original framing swept in is either self-announcing or noise.

Recording the shift rather than quietly rewriting the rationale, because the
filed rationale is on record and a reader comparing the two deserves to know the
evidence moved it rather than a change of mind.
