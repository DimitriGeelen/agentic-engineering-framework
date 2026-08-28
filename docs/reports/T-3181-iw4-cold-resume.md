# T-3181 IW-4 — is the PreCompact handover compaction-grade? Measured, two arms.

**Question (IW-4):** *"Is our PreCompact handover already compaction-grade, and how would
we know? Nobody has taken `LATEST.md` into a genuinely cold session and measured whether
it resumes. Cheap to falsify; nothing should be built on top of it before it is."*

**Status before this run:** deferred, confidence 1. The only evidence was a `/compact`
resume that "seemed to work" — which T-3181 itself correctly refused to count, because a
`/compact` reinjects a SessionStart banner and so never tested `LATEST.md` standing alone.

**Answer: NO — PARTIALLY at best.** Two independent workers, different context loads,
converged on the same verdict and the same primary defect.

---

## Design

Two TermLink workers, same five questions, one variable: what context was loaded.

| Arm | Project dir | Loads `CLAUDE.md`? | Conversation history |
|---|---|---|---|
| **A — strict cold** | `/tmp/t3181-cold-arma` (contains only `LATEST.md`) | no | none |
| **B — realistic cold** | the repo | yes (auto) | none |

Arm B is the control. A resuming session in the real world *does* have `CLAUDE.md`; Arm A
tests the stricter claim. **The difference between the arms attributes the deficiency**:
if B passes where A fails, the handover is fine and the standing instructions carry the
resume. If both fail, the deficiency is the handover's own.

Both were told explicitly not to explore — the experiment measures what the handover
*carries*, not what a worker can re-derive by digging.

### Contaminants found while building the cold arm — disclosed, not hidden

The first cold directory was **not cold**. An upward `CLAUDE.md` scan found a **119KB
verbatim copy of the project `CLAUDE.md`** sitting in the session scratchpad since
2026-08-25. Arm A would have loaded the entire framework operating guide and almost
certainly returned "YES, I can resume" — a false green produced by the experiment's own
staging directory, in the same family as the rest of this arc's findings.

A second contaminant survives and is disclosed rather than eliminated: **`/CLAUDE.md`**,
470 bytes, a leaked test fixture (`fixture-consumer`, `PROJECT_HEADER_MARKER_LINE`) at
filesystem root, inherited by any `claude` session anywhere on this host. It contains no
framework guidance and no session state, so Arm A's validity holds. Captured as OBS-352.

---

## Result

| | Arm A (cold) | Arm B (control) |
|---|---|---|
| **Verdict** | PARTIALLY | PARTIALLY |
| **Biggest missing fact** | what the 52 uncommitted changes are | any state at all for T-1719 |
| **Biggest volume-without-signal** | ~430 bare task IDs in three frontmatter arrays | ~420 bare task IDs in three frontmatter arrays |

**The control did not rescue it.** Arm B had the full 119KB operating guide and still
returned PARTIALLY. So the gap is not "the reader lacks framework knowledge" — it is the
handover's own content. That is the finding the second arm exists to produce, and it is
the reason a single-arm version of this experiment would have been uninterpretable.

### Defect 1 — the Suggested First Action points at a task the document does not describe

Both arms independently flagged this, and it is the sharpest result.

`LATEST.md` says **"Continue T-1719: Embeddings strategy V1 — Slice 1…"**. T-1719 then
appears exactly once more in the entire document: as a bare ID inside `tasks_active:`.
It is absent from `tasks_touched:`, absent from the five "Work in Progress" entries, and
unrelated to the arc the session actually worked (`continuous-run`: T-3203, T-3206,
T-3207, T-3208). Its title is truncated mid-phrase.

Arm B put it best: **"state is transmitted, intent is not."**

The one executable instruction in the document contradicts everything else in the
document, and a cold reader cannot tell which to believe.

### Defect 2 — roughly a third of the document is bare IDs neither arm could use

`tasks_active` / `tasks_parked` / `tasks_awaiting_review` carry ~420-430 task IDs with no
titles and no state. Arm A measured the unusable fraction at "roughly two-thirds" once
the duplicated sections and telemetry are included.

Duplicated section pairs both arms named:
- `## Awaiting Your Action (Human)` vs `### Partial-Complete — awaiting human (249 tasks)`
- `## Deferred With No Revisit Date` vs `### Deferred Inceptions — Watching for Recurrence`

### Defect 3 — the diffstat truncates without saying so

The handover reports **52 uncommitted changes**, then shows a "Files Changed This Session"
diffstat naming 4 files while stating 13 changed. Nine filenames are simply absent, with
no ellipsis or count to signal the omission. Arm A called this its single largest gap:
a cold reader cannot know whether the tree holds half-finished work to resume or scratch
output to discard, and so cannot safely touch it.

Note the shape — **a truncation that does not announce itself reads exactly like a
complete list.** Same family as the rest of this arc.

### Defect 4 — "None" is indistinguishable from "unfilled"

Decisions, failures and blockers all read `None` across 20,262 turns. Arm A: *"I cannot
tell a genuinely clean session from an unfilled template."*

### What the handover does carry well (both arms agreed)

Session/predecessor IDs, HEAD sha and recent commit subjects, the current arc and the
command to inspect it, the five in-flight tasks each with a one-line last-action, the
dirty-tree count, the tool surface, and the standing hazards (G-077/G-084, G-083,
OBS-308/307). This is real and it is the reason the verdict is PARTIALLY and not NO.

---

## Disposition

IW-4 moves from **deferred, confidence 1** to **answered, confidence 3**. The question
asked whether the handover is compaction-grade and how we would know. It is not, and the
way we know is now a repeatable two-arm procedure rather than an impression.

The four defects are handover-generator defects, not loop defects. They belong to the
handover agent, and they are separable from arc-012's loop work — recorded here so the
next person does not have to re-run the experiment to find them.

**Reproduce:** copy `LATEST.md` into a directory with no `CLAUDE.md` above it (verify with
an upward scan — do not assume), dispatch a worker with the five questions above, and
dispatch a second in-repo as control. Cost: two workers, ~2 minutes.

## Provenance

Arm A ran in `/tmp/t3181-cold-arma`; its report is reproduced above in full because it
was written outside the repo and would otherwise have been lost (T-818). Arm B wrote
directly to `docs/reports/T-3181-cold-resume-armB.md`. Worker dirs:
`/tmp/tl-dispatch/t3181-cold-arm{a,b}`, both exit 0.

---

## Appendix — Arm A report, verbatim
# Cold-Resume Report — S-2026-0828-1702

## 1. NEXT ACTION

Run `bin/fw task show T-1719` to load the full task file for
*"Embeddings strategy V1 — Slice 1 (post-write hook + happiness signal + one-provider…)"*,
which the handover names under **Suggested First Action**, and read its acceptance
criteria to find the first unticked Agent AC.

I can state this, but I state it with a flag: it is the only executable instruction in
the document, and it **contradicts everything else in the document**. T-1719 appears
exactly once outside that line — as a bare ID in `tasks_active:`. It is not in
`tasks_touched:`, not among the five "Work in Progress" entries, and not part of the
current arc (`continuous-run`), which is what the session actually worked on
(T-3203, T-3206, T-3207, T-3208, T-3090). So the next action is really two steps:
open T-1719, and simultaneously check whether resuming it is correct at all versus
continuing the arc work in flight (T-3181, T-3202, T-3171, T-3174, T-100201).

There is a second blocker on *any* action: **52 uncommitted changes** are reported and
the document never says what they are or whether they are safe to build on. The
"Files Changed This Session" diffstat lists 4 filenames but says "13 files changed" —
9 filenames are simply absent.

## 2. SUFFICIENT

- Session/predecessor IDs and timestamp — enough to locate the prior transcript.
- The name of the next task: T-1719, with a truncated title.
- The current arc: `continuous-run`, in-progress, 27 tasks, plus the command to inspect
  it (`fw arc show continuous-run`).
- The five in-flight tasks with their status and a one-line "last action" each.
- Working tree is dirty: 52 uncommitted changes.
- HEAD is at `70b08ef2b`, with the five most recent commit subjects.
- The tool surface: `bin/fw task list`, `bin/fw review-queue`, `fw note triage`,
  `fw inception status`, `fw audit`, `fw costs current`.
- Standing hazards likely to bite: G-077/G-084 (Bash task gate), G-083 (autonomous loop
  and interactive session share one working tree), OBS-308/307 (audit lock self-poisons
  and can hang a push).

## 3. MISSING

- **What T-1719 actually requires.** Title is truncated mid-phrase. No ACs, no files, no
  design doc, no "which provider", no definition of "happiness signal", no prior progress.
- **Why T-1719 is the suggested action** when the session was working the `continuous-run`
  arc. No rationale connects them; the arc is not stated as paused or completed.
- **What the 52 uncommitted changes are** — which files, which task they belong to,
  whether they are half-finished work to resume, scratch output to discard, or must be
  committed before anything else. This is the single largest gap.
- **9 of the 13 changed filenames** — the diffstat is truncated without saying so.
- **The branch name / whether a worktree is in play.** Given G-074 (stranded worktree
  divergence) and G-083 (shared working tree), this is load-bearing, not cosmetic.
- **Whether an autonomous loop is currently ARMED.** T-3206 is described as "loop ledger
  records ARMED"; the document never says the live state, and G-083 says a concurrent
  loop can collide with me in this same tree.
- **Any decision, failure, or blocker.** All three sections read "None" across 20,262
  turns — so I cannot tell a genuinely clean session from an unfilled template.
- **What `[REVIEW]`/`[RUBBER-STAMP]`/horizon mean operationally**, and whether the
  245-item human queue blocks agent work or runs beside it.

## 4. VOLUME WITHOUT SIGNAL

Roughly two-thirds of the document, none of which changed my answers:

- The frontmatter ID lists — `tasks_active`, `tasks_parked`, `tasks_awaiting_review`
  (~430 bare IDs, no titles, no state).
- `## Awaiting Your Action (Human)` — 5 of 245 shown, plus a paragraph explaining
  the prefix legend.
- `### Partial-Complete — awaiting human (249 tasks)` — same tasks, listed twice.
- `### Deferred Inceptions — Watching for Recurrence` — near-duplicate of
  `## Deferred With No Revisit Date` above it.
- `## Token Usage` and the ~20 frontmatter metrics (`commits_per_turn`,
  `edit_bursts`, `failed_tool_call_rate`, …) — telemetry, not state.
- `## Observation Inbox` — 5 of 228 truncated mid-word; urgent-flagged but
  unattached to any next action.
- `## Handover Quality Feedback (for next session to complete)` — empty checkboxes.

## 5. VERDICT

**PARTIALLY** — I can name and start one concrete action, but the document's own
suggestion contradicts the work it says was in flight, and it describes 52 uncommitted
changes without saying what they are, so I cannot safely touch the tree until I look
outside this file.
