# T-3020 — where `fw doctor`'s four minutes go

**Measured:** 2026-08-15, on the framework repo at 15,074 tracked files.
**Result:** 222s total. Three checks account for 197s (89%). None of them are new.

## The measurement

Doctor's own output lines, timestamped, with gaps ≥4s:

| Gap | Check that produced the next line |
|-----|-----------------------------------|
| **90s** | Large-file gate |
| 4s | Hook exercise from /tmp |
| **60s** | Test infrastructure (bats installed, 3908 unit tests) |
| **47s** | TermLink (termlink 0.11.720) |
| 5s | Session tokens |

Everything else in the run is sub-second. The full run was 222s in the timed
pass and 233s in an untimed one; the difference is noise, not instrumentation.

Method: `stdbuf -oL bin/fw doctor | stdbuf -oL awk '{printf "%4d %s\n",
systime()-s, $0}'`. Line-buffered on both sides, or awk batches doctor's output
and every gap collapses to zero — which is how a first attempt at this measured
nothing and looked like a clean bill of health.

## Was it the check I just added?

No. T-3019's `recall usage` check, added in this session, measures **0.121s**.
Its sibling `vector index` freshness measures **0.949s**. Together they are 0.5%
of the run.

This is worth stating explicitly rather than concluding by elimination: I added
a doctor check an hour before noticing doctor was slow, and the honest first
hypothesis was that I had caused it. The measurement says otherwise, and the
measurement is the reason to believe it.

## Was it a regression at all?

Not from this session, and not from any single change. It is **gradual decay by
construction**.

`agents/git/lib/large-file-scan.sh` last changed on **2026-05-15** (T-1845),
three months ago. Its `scan_tree` loop forks `stat` once per tracked file:

```sh
while IFS= read -r path; do
    ...
    size=$(stat -c %s "$root/$path" 2>/dev/null || echo 0)
```

Fork cost is linear and measured at **1.94 ms/file**:

| Files | Bare `stat` loop |
|-------|------------------|
| 1,000 | 1.94s |
| 4,000 | 7.91s |
| 15,074 | 30.04s |

The full `scan-tree` is 85s (`real 1m25s`, of which **`sys` is 1m10s** — the
signature of fork-dominated work, not of I/O or computation). The gap between
30s and 85s is the per-file allowlist check, which forks again.

So: the check was fast when it was written and gets slower every time a file is
added to the repo. `.tasks/completed/` alone grows on every task close. Nothing
ever crossed a threshold, nothing ever went red, and the cost arrived one
millisecond at a time.

That shape matters more than the number. A control that degrades continuously
has no moment where anyone is prompted to look — which is the same reason the
vector index sat five months stale (T-3004) and the same reason this arc keeps
finding instruments that were healthy-looking rather than healthy.

## The other two

**Test infrastructure (60s)** — counts 3,908 unit tests. Scales with the test
suite, which also only grows.

**TermLink (47s)** — a hub/fleet probe. Constant-ish, but 47s of a health check
spent waiting on the network is a different question from the other two: it is
not decay, it is a timeout budget nobody has looked at. Worth noting that
doctor's stated purpose is a *local* health check.

## What is not being claimed

- No fix is proposed here. This task diagnoses and records; changing doctor's
  behaviour is a separate task, and optimising before measuring is how the wrong
  check gets optimised.
- The three fixes are not equivalent. Large-file gate is a straightforward
  batching problem (`git ls-files -z | xargs -0 stat -c '%s %n'` replaces 15,074
  forks with a handful). Test-count and TermLink are policy questions — should
  doctor count tests at all, and should it wait 47s on a network peer — and
  those are the operator's to answer, not mine.

## Practical consequence, today

`fw doctor` appears in `## Verification` blocks across the task corpus, and in
pre-push. Every one of those pays 222s. The T-3014 close in this session timed
out my own 5-minute wrapper because of it — the close itself succeeded, but the
signal I got was a timeout, which is exactly the kind of ambiguous failure that
costs a session's confidence in its own tooling.
