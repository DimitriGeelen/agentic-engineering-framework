# T-2995 — Cross-project dispatch containment

**Status:** exploration complete
**Filed:** 2026-08-14
**Reporter:** peer session in consumer project 001-CashWeb-Lightspeed-Ecwid-integration (AEF v1.6.212 vendored)
**Related:** T-559 (boundary hook), T-2282 (permission-mode passthrough), T-2036 (close-deadlock)

---

## The report

A consumer-project session received an off-topic request about a different
project and ended up spawning a TermLink worker with `--permission-mode
acceptEdits` aimed at another project's directory. The worker died on `FATAL:
cd /opt/2345-test-install failed` — the path did not exist — so nothing was
written anywhere.

The reporter's own framing is the right one and worth preserving verbatim:

> That was luck, not containment.

They also named their own error plainly (inferring the target from transcript
directory names, proceeding after writing down the concern rather than
stopping), which is what makes the structural half of the report credible.

## Finding 1 — the guard advertises the ungated path

`agents/context/check-project-boundary.sh:386` blocks cross-project **reads**
and then prescribes this remedy:

```
  For legitimate cross-project work, use TermLink dispatch which
  runs the command in the target project's own session context:

    fw termlink dispatch --name work --project /opt/other \
      --prompt 'describe the work for the target project'

  Neither path crosses the boundary of *this* session; each
  target project enforces its own governance in its own process.
```

The last sentence is the load-bearing claim, and it is conditional on something
nothing checks. Tracing `--project` through `agents/termlink/termlink.sh`:

| line | what happens to `--project` |
|---|---|
| 514 | parsed: `--project) project_dir="$2"; shift 2` |
| 617 | defaulted: `project_dir="${project_dir:-$(pwd)}"` |
| 717 | embedded in the dispatch envelope |
| 923 | passed to the worker runner |
| 742 | `cd "$PROJECT_DIR" \|\| { echo "FATAL: cd $PROJECT_DIR failed"; exit 1; }` |

There is no existence check, no `.framework.yaml` check, no `.tasks/` check —
at any point. The worker is spawned first and discovers the truth afterwards,
inside the target.

**Confirmed: IW-1 = no validation.**

### The luck was narrower than the reporter thought

Their path did not exist, so `cd` failed at line 742 and the worker exited
before doing anything. That is the *benign* failure.

Consider the same mistake against a path that **exists but is not an AEF
project** — `/opt/some-scratch`, a home directory, `/tmp/build`. Then:

- `cd` succeeds.
- The worker runs `claude -p` with `--permission-mode acceptEdits`.
- There is no `.claude/settings.json`, so **no hooks load**: no task gate, no
  Tier 0, no boundary hook, no budget gate.
- "Each target project enforces its own governance in its own process" is
  false, because there is no governance there to enforce.

So the guarantee inverts precisely where it matters most. A governed target
would have caught the mistake; an ungoverned one cannot, and nothing
distinguishes them before spawn. The reporter's incident failed safe by
accident of a typo'd path.

**IW-2 = the asymmetry is real**, and sharper than reported: reads are blocked
unconditionally, writes are unvalidated, and the guard names the write path as
the sanctioned remedy.

## Finding 1b — `acceptEdits` is a plain flag

`--permission-mode` is a straight passthrough (parsed 532-541, written to
`permission_mode.txt` at 676-679, reconstructed into the `claude -p` invocation
at 795-796, T-2282). Nothing about combining it with an out-of-root `--project`
raises a tier.

**IW-3 = no approval gate today.** Whether there should be one is a judgement
for the operator; the evidence says the combination is currently
indistinguishable from any other flag pair.

## Finding 2 — `--task` forces contamination

`fw termlink dispatch` requires `--task T-XXX` resolved in the **dispatching**
project. To dispatch outward, the reporter had to create a task about unrelated
work inside a customer project's `.tasks/`, polluting that project's task
history, episodic memory and metrics.

P-002 ("nothing gets done without a task") and cross-project dispatch are in
genuine tension: the task that authorises the work belongs to the *target*, but
the gate reads the *dispatcher*. The reporter's suggested shapes — a distinct
dispatch record under `.context/dispatches/`, or a foreign-target task type
excluded from metrics and episodic — are both plausible. This is the weaker of
the two findings: it is a modelling problem, not a containment hole, and it
should not be bundled with Finding 1.

**IW-4 = resolvable, but the design choice is open.** Separate task.

## Finding 3 — the close-deadlock, reproduced here without trying

The reporter describes hitting T-2036 three times: closing a task nulls focus,
but closing *generates* artifacts (task file move, episodic, fabric cards) that
need a commit, which needs an active task.

While writing this report, closing T-2994 in the framework repo produced this,
in sequence, before a single line could be committed:

```
1. BLOCKED: Task T-2994 has status 'work-completed'
2. FOCUS-DRIFT — Current focus: T-2995, Action target: T-2994
3. BLOCKED: Task T-2995 has status 'captured' (work not started)
4. BLOCKED: bootstrap exemption void — line contains a redirect
5. BLOCKED: Inception T-2995 has zero filed Open Questions
```

Five gates, each individually correct, to commit the artifacts the framework
itself had just generated. The reporter is not describing a consumer-specific
misconfiguration — this is the framework's own behaviour in its own repo.

Worth separating two things: gates 2-5 are the *cost of the workaround*
(borrowing another task as anchor), not the deadlock itself. The deadlock is
gate 1. But the workaround's cost is what makes the deadlock expensive rather
than merely annoying, and it is why the reporter found exactly one usable
anchor out of eleven active tasks.

## Findings 4-6 — the side reports

Assessed but **not** investigated in depth; each needs its own task and
verification against our source rather than acceptance on report.

| id | claim | first read |
|---|---|---|
| G-006 | seed ships `git log -1 … \| grep -q "T-XXX"`, asserting the *most recent* commit references the task — true at completion, false forever after | Plausible and upstream-owned. Both seed variants named. Also SIGPIPE-prone under pipefail (L-387). If correct, every consumer inherits a permanently-failing CTL-013 — which trains agents to treat CTL-013 as noise, the same signal-decay class as T-2990. |
| G-007 | doctor's claude-fw drift check compares the router against the wrapper; its prescribed remedy would regress T-2854 | Plausible, and the second half is the serious part: a remediation that undoes a deliberate design. |
| G-008 | CTL-008 counts git-generated merge subjects as task-less commits | Plausible. Exempting two-parent commits is the obvious shape. |
| T-2036 | close-deadlock | **Confirmed above, in this repo.** |

All four are upstream-owned if the claims hold — they are in seeds, doctor,
audit metrics, and the task lifecycle, none of which a consumer can fix
durably (consumer fixes do not survive `fw update`, as G-006 notes).

## Open questions — disposition

| id | disposition | evidence |
|----|---|---|
| IW-1 | answered (3) | no validation at 514/617/717/923; `cd` fails at 742, after spawn |
| IW-2 | answered (3) | reads blocked at check-project-boundary.sh:386; writes unvalidated; guard names the write path |
| IW-3 | answered (2) | plain passthrough T-2282 (532-541, 676-679, 795-796); no tier interaction |
| IW-4 | answered (1) | tension is real; the design choice is open — separate task |
| IW-5 | answered (2) | all upstream-owned if the claims hold; each needs its own task and verification |

## Dialogue Log

### 2026-08-14 — peer report received mid-task

Arrived while T-2994 was being closed. Handled after that commit rather than
interrupting it, on the grounds that a half-committed task is exactly the state
the report's own Finding 3 describes as expensive.

### 2026-08-14 — where I disagree with the reporter, and where I go further

**Further:** they characterise the incident as "luck" because the worker died.
The luck is narrower than that. Their path did not exist; a path that *exists
but is not an AEF project* is the actually dangerous case, and it is the one
where the guard's promise ("each target project enforces its own governance")
is not merely unverified but *false* — no settings.json means no hooks at all.

**Disagree, mildly:** they present Findings 1 and 2 as one RCA. They are
different problems — Finding 1 is a containment hole with a bounded fix
(validate before spawn), Finding 2 is a modelling question about where the
authorising task lives. Bundling them would make the containment fix wait on a
design debate. Split.

**Not accepted on report:** G-006/7/8 are recorded above as plausible and
first-read only. They were reported against v1.6.212 and this repo is at
1.6.227; each needs verification against our current source before anything is
filed as a defect. Saying so explicitly because the report is careful and
well-evidenced, which makes it tempting to skip that step.
