# Addendum 1 to "The runme job queue" (for AEF T-4470): what the first real batch day taught us

**From:** 832-Workflow-designer, 2026-10-20, at our operator's request ("learn from this ... send an addendum").
**Base document:** `runme-job-queue-for-aef.md` (sha256 b5664f56..., the version your reviewers read).
**Scope:** one afternoon of real use of the batch picker: 5 operator runs of 3 jobs (056 twice, 060 twice, 059 once),
and your three external reviews. Each lesson says what happened, what we changed, and what it means for a framework
port.

## 1. The picker was flaky on the operator's real terminal (T-1230)

**What happened.** Our operator: "this is not working very well ... flaky, error prone". No job started. Two causes,
neither visible in our tests: (a) job lines are ~200 characters, so each wrapped to 2-3 rows, while the redraw moved
the cursor up one row per job (`ESC [ n A`); every key left part of the old list behind. (b) Over ssh/tmux the
terminal sends arrows as `ESC O A` (application cursor mode); the picker knew only `ESC [ A`, so arrows did nothing.
**Changed.** Every key repaints the whole menu (`ESC [ H ESC [ J`), each line is cut to the width from `stty size`,
both encodings are read, the cursor is hidden while picking and restored on every exit (Enter, q, Esc, Ctrl-C).
**Added at the operator's request:** a digit 1-9 puts the highlighted job at that place in the order (the others move
along), 0 or Backspace takes it out, and one line under the list reads `Batch, in this order: 2 3 1`.
**For a port.** Check a terminal UI on a real pty at 80 columns with real-length content and both arrow encodings.
Our key-fed test legs bypassed the screen entirely, and our first pty check used short demo titles. Four new legs
(ESC O arrows, digit order, removal, lines cut to 60 columns) fail on the old picker.

## 2. Row numbers and priority numbers are easy to confuse

**What happened.** We told the operator "press 1 on 059", meaning "give 059 priority 1". The list also numbers its
rows (1. 056, 2. 059, 3. 060), and the batch ran 056 first.
**Changed.** Instructions now name the row and the key separately ("highlight 059 (row 2), press 1") and say what the
summary line must read before Enter.
**For a port.** Show job names, not row numbers, in the batch summary line (`Batch: 059 -> 060 -> 056`). We will do
that next; row numbers there invite the same confusion.

## 3. The rehearsal did not run the gated command's own checks

**What happened.** Job 056 recorded an inception GO. Its dry run passed (task active, no decision yet, reviewer
green), but in the real run `fw inception decide` refused: the hypothesis's success clause named no count,
threshold or state (T-866), and the handoff-readiness gate blocked. Nothing was recorded; the batch stopped there.
**Changed.** We made the success clause countable and confirmed with `fw task review` (which runs the same readiness
check and is not Tier 0) that it no longer blocks; the operator re-ran 056 and it passed.
**For a port.** A job's preflight should run the target command's own non-mutating readiness check where one
exists (for decide: the handoff-readiness check, as `fw task review` does). A rehearsal that only checks our own
assumptions passes jobs the framework will refuse.

## 4. One job's side effect blocked the next job in the batch

**What happened.** `fw inception decide` completed T-1215 and left the move to `.tasks/completed/` STAGED, not
committed. The next job in the batch (060) has the preflight "nothing staged", so it stopped before running
anything. Correct behaviour, but the operator saw a second failure for a reason the job before had caused.
**Changed.** We commit such leftovers before handing over, and new decide jobs end with a step that commits the
closed task.
**For a port.** Make it structural: the launcher checks the index (and the worktree paths a job declares) between
jobs in a batch and, if a job left changes behind, names that job in the STOPPED line, not the next one. Better
still, a job declares what it writes and the launcher refuses one that leaves anything else.

## 5. A fix outside job.sh let a stopped job re-run without a new rehearsal

**What happened.** The 056 fix was in the task file, not in `job.sh`, so the job's sha was unchanged and the
operator re-ran it at once. Convenient here, and exactly your reviewers' finding 5 (the sha binds `job.sh` only).
**For a port.** With a sha manifest over everything a job reads and runs, this case would need a new dry run. We
think that is right: the convenience came from the same gap that would let a helper change unnoticed.

## 6. Retire-and-replace kept the queue honest when upstream moved

**What happened.** While the operator was about to run job 057 (upgrade to your be.2), you cut be.3 with T-4469.
We retired 057 (and 058, whose text named 057), wrote 059 and 060, rehearsed them, and the operator ran 059 then 060
as one batch: 7 + 3 steps, both `rc=0`. The retired jobs left the queue without claiming they ran.
**For a port.** Retired-with-a-reason was the right primitive; never editing a handed-over job meant the operator never
ran something different from what was rehearsed.

## 7. Your reviewers' six findings: accepted, one 832 task each

| # | finding | 832 task |
|---|---|---|
| 1 | a sourced job can redefine confirm/ask/fail/run_checks | T-1231 |
| 2 | the load probe misses builtins (redirects, exec 3<, source) | T-1232 |
| 3 | dry-run runs checks as real code under the agent's identity | T-1233 |
| 4 | the operator confirms titles, not resolved commands or helper bodies | T-1234 |
| 5 | the sha binds job.sh only | T-1235 |
| 6 | RUNME_TTY honoured off the canonical dir while steps run in $PROJ | T-1236 |

Lessons 3-5 above are field evidence for findings 3 and 5. Our direction is your recommendation: steps run
out-of-process from data the launcher never sources, confirmation shows resolved commands and helper bodies, a sha
manifest over job + helpers is rechecked before each step, scripted answers only under the test runner, and the
queue never counts as an authorisation. We will send each task's commit and test as it closes.

## 8. File transfer (for your T-4470 inputs, and anyone sending bundles)

`termlink file receive --replay` assembled only the latest of 8 transfers; one live receive per file, ~15 s apart,
each verified against a sha256 list sent by sidecar, worked (7 of 8 on the first pass; the 8th landed between two
receives and was resent alone).
