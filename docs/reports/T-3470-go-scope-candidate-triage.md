# T-3470 — triage of the 25 GO-scope candidates

**Date:** 2026-09-25
**Origin:** operator question — *"we have a number of huge inceptions that we
GO-recorded, but you never managed to create build tasks from that, and
therefore all the work we've done is just sitting there"*
**Predecessors:** OBS-535 (the misread), T-3469 (the tiering fix)

## What this triages

After T-3469, the GO-scope scan reports three tiers. Only one of them means
*nobody built this*:

| tier | n | meaning |
|---|---:|---|
| candidate | 25 | no build-class follower at all |
| in-flight | 60 | followers exist, at least one still in `active/` |
| linked-late | 101 | followers exist and all completed |

This document triages the **25 candidates** only. The other 161 are a
bookkeeping backlog, not lost work, and are out of scope here.

## Method and its limit

For each candidate: read the inception's subject, then probe the codebase for
the mechanism it approved. **These probes are grep-shaped and indicative, not
proof.** A HIT means something plausibly related exists; it does not prove the
GO's scope was delivered. Verdicts marked **confirmed** were checked by reading
the implementing code; the rest carry their confidence explicitly.

Stating that plainly matters, because the failure this whole thread is about
was a measurement being read as more certain than it was.

## Verdicts

### A. Genuinely unbuilt, still worth doing → build tasks filed (4)

| id | subject | evidence | confidence |
|---|---|---|---|
| T-3072 | blast radius for **open** tasks | **confirmed.** `lib/bvp.sh:355` states `blast_radius` is derivable only once `components:` resolves, which happens at `work-completed` — the status `fw bvp` excludes. The axis exists and is `unknown` for exactly the tasks it was approved to score. The source comment calls this "the expected state, not an anomaly". | confirmed |
| T-2280 | `fw doctor` WARN when ≥2 Watchtower instances share a cookie | **confirmed.** No instance/cookie-collision check exists in `lib/doctor*.sh` or `bin/fw`. CLAUDE.md §Watchtower Port documents this exact collision biting in production — `:3000` was 832's Watchtower, and 224 verification lines returned 200 from the wrong server. | confirmed |
| T-3108 | enforcement code forks with the branch | **confirmed.** `lib/enforcement.sh` has no branch awareness. The baseline hash is branch-blind, so a branch carrying different hook config reads as baseline drift rather than as a different branch. Sharpened by OBS-534 this week. | confirmed |
| T-3114 | release channels — consumers pick stable or experimental at `init` | no `release_channel` / `--channel` anywhere in `lib/` or `bin/fw`. Directly relevant to the T-3185 release-train model, which now provides the two-branch structure a channel selector would sit on. | high |

### B. Shipped by another route — the GO landed, the link never did (11)

The work exists; no task ever recorded `related_tasks:` pointing back. Same
bookkeeping class as `linked-late`, but with no follower task to point at, so
the classifier cannot see it.

| id | subject | what exists |
|---|---|---|
| T-488 | framework status report + self-test | `fw self-test` verb (`bin/fw:1316`) |
| T-468 | tool-call telemetry | `lib/hook-telemetry.sh`, `.context/working/.tool-counter` |
| T-1505 | doctor hook-health / hook failure rate | `lib/hook-telemetry.sh` |
| T-1338 | triage human review queue, classify automatable | `fw review-queue`, `lib/verify-acs.sh`, later `fw task delegate` (D-626/T-3445) |
| T-1299 | Watchtower restart needs `setsid` | `setsid` present in `bin/fw` |
| T-2234 | consumer-update dispatch exercise | `lib/consumer-recover.sh` + the documented `fw consumer-recover` verb |
| T-792 | TermLink dispatch pattern (cwd, timeout) | `agents/dispatch/AGENT.md`, `develop.md`; the timeout-orphan rule is in CLAUDE.md |
| T-533 | TermLink-first dispatch rerouting hook | `FW_DISPATCH_LIMIT` in `bin/fw` |
| T-3100 | error incident register | `lib/errors.sh` |
| T-2995 | cross-project dispatch containment | the T-559 project-boundary gate (refuses cross-project reads) |
| T-878 | global install violates project isolation | `lib/upgrade.sh:1808` "Shim migration + global install sync" — **partial**: the section exists; whether the isolation violation was fixed is not established |

Confidence: **medium-to-high** for the first ten. T-878 is explicitly
unresolved and stays flagged.

### C. Homed elsewhere — never AEF's to build (5)

Per CLAUDE.md §Gap Homing (T-1333): *a gap belongs in the register where the
FIX lives, not where it was HIT.*

| id | subject | owner |
|---|---|---|
| T-1121 | TermLink TLS cert regenerates on hub restart, breaks TOFU | TermLink repo — and TermLink shipped it (`termlink tofu verify/list/clear` exist) |
| T-600 | TermLink attach-self | TermLink repo |
| T-571 | TermLink supervisor event loop | TermLink repo |
| T-168 | propagate learnings to Sprechloop | a different project |
| T-686 | article angle 3 — landscape differentiation | content, not framework code (`docs/deep-dives/` exists) |

### D. The GO's deliverable *was* the research (2)

| id | subject | note |
|---|---|---|
| T-815 | traceAI / OpenTelemetry evaluation vs framework directives | an evaluation; its output is the verdict, not a build |
| T-3081 | a learning that prescribes its own fix at application TBD | a characterisation; no build artefact was implied |

### E. Unbuilt, and not worth building (3)

| id | subject | why not |
|---|---|---|
| T-534 | well-known priority tags (critical/urgent/blocking) | superseded by BVP scoring + `horizon`, which do this job with evidence rather than a label |
| T-1139 | pickup patch-delivery type | superseded by the sidecar file-transfer rail (arc-011) |
| T-3084 | BVP value axis does not discriminate inside its quadrant | real, but the same defect as T-3072 seen from the other side — fixing the cost axis for open tasks is the prerequisite. Folded into T-3072 rather than filed twice (CLAUDE.md §Task Sizing: one bug, one task) |

## Summary

| verdict | n |
|---|---:|
| A — unbuilt, filed | 4 |
| B — shipped, unlinked | 11 |
| C — homed elsewhere | 5 |
| D — research was the deliverable | 2 |
| E — unbuilt, not worth it | 3 |

**The operator's concern lands on 4 tasks, not 185.** Three of the four are
confirmed by reading the implementing code, not by grep.

## The honest caveat

Category B is the weakest column. "A mechanism with a matching name exists" is
not "the GO's scope shipped". Each B row would need the inception's acceptance
criteria read against the code to be certain. That was not done for all eleven,
and this report should not be cited as if it had been.

What makes B tolerable at this confidence: being wrong about a B row costs a
re-filed build task, while being wrong about an A row costs duplicated work. So
the effort went into confirming A.

## A defect in the classifier, found by using it

Filing the four build tasks moved the candidate count 25 → 18. Only **five**
inceptions were genuinely linked (T-3072, T-3084, T-2280, T-3108, T-3114), so
the expected count was 20. Two more moved for a bad reason.

**T-3469's own task file quotes the audit Evidence line** — `T-3114, T-3108,
T-3100, T-3084, T-3081` — inside its `## Result` block. T-3469 is a build task
created after those inceptions, so the classifier read those five IDs as
propagation and relabelled them `in-flight`. Two of them (T-3100, T-3081) have
no implementing work at all; they were reclassified purely because a task
*discussing* the finding mentioned them.

**The direction of the error is the bad one.** A body mention cannot remove a
finding — only a declared `related_tasks:` link does that, and that part is
sound. But it can move a finding out of `candidate`, which means the tier
errs toward reporting **fewer** abandoned decisions than there are. A
classifier whose failure mode is under-reporting the alarming number is the
same shape as the defect T-3469 set out to fix, one level down.

Scale here is small — 2 of 25 — and the tier is advisory, never a gate. But it
is real, it was found by using the thing rather than by reasoning about it, and
it is recorded rather than smoothed over. Filed as its own observation; the
candidate counts in this report are from the **pre-filing** run, which is
unaffected.

Sharpening the signal (require the mentioning task to declare a component
overlap, or to name the inception in a structured field rather than prose) is
a build, not a caveat — deliberately not done inside a triage task.

## What this does not accomplish

The 25 stay flagged by the scan. **The scan measures linkage, and a report is
not linkage.** Filing build tasks with `related_tasks:` clears the four in
category A; the other 21 remain candidates forever unless something writes the
verdict back into the corpus.

Closing that loop needs a decision this report does not make: whether a triage
verdict is **corpus state** (a `disposition:` field the scan consults, so
"shipped elsewhere" and "homed in TermLink" become first-class answers) or
**just a report** (in which case the scan will keep asking, correctly, and the
answer will keep living somewhere it cannot see). Surfaced, not assumed —
it is a governance change, not a chore.
