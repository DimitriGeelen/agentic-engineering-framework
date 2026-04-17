---
type: issue-report
title: "fw work-on races on task-ID allocation — parallel calls produce collisions"
reported: 2026-04-17
reporter: agent (incidental find during T-1277/T-1278 investigation)
investigated_by: agent
severity: medium
frequency: whenever 2+ `fw work-on` or `fw task create` run within the allocation window
related_task: T-1279
status: rca-complete
tags: [bug, tooling, race-condition, task-system, rca]
---

# Issue Report — `fw work-on` Task-ID Race

## Symptom

During the T-1277/T-1278 session, four distinct `fw work-on` calls fired within ~2 seconds and all produced `T-1278` files:

| File | created | name |
|---|---|---|
| `T-1278-fix-inception-decide-on-consumer-project.md` | 10:16:31Z | Fix inception decide on consumer projects |
| `T-1278-e2e-test-inception-decide-on-consumer-pr.md` | 10:16:32Z | E2E: Test inception decide on consumer project |
| `T-1278-e2e-test-inception-decide-on-vendored-co.md` | 10:16:32Z | E2E test: inception decide on vendored consumer |
| `T-1278-fix-unbounded-git-push-in-handover-auto-.md` | 10:16:33Z | Fix unbounded git push in handover auto-trigger |

All four have `id: T-1278` in YAML frontmatter. Filename clash was avoided only because all four had distinct slugs.

## Root cause (confirmed)

`agents/task-create/create-task.sh:111-126`:

```bash
generate_id() {
    local max_id=0
    shopt -s nullglob
    for f in "$TASKS_DIR"/active/T-*.md "$TASKS_DIR"/completed/T-*.md; do
        ...
        id=$(basename "$f" | grep -oE 'T-[0-9]+' | grep -oE '[0-9]+')
        if [ -n "$id" ] && [ "$((10#$id))" -gt "$max_id" ]; then
            max_id=$((10#$id))
        fi
    done
    printf "T-%03d" $((max_id + 1))
}
```

Pure read — no lock, no atomic claim. Between this function returning `T-1278` and the actual task file being written (slug generation, template copy, frontmatter substitution take non-zero time), any other invocation that calls `generate_id()` observes the same `max_id=1277` and also returns `T-1278`.

On this repo the race window is widened by the ~6-minute tail of RAG context enrichment that `fw work-on` does (the command doesn't return until enrichment completes, but the file is written much earlier — still, the window for the `generate_id()` read vs. first write is on the order of seconds, and 4 concurrent invocations landed in it).

## Why there are multiple concurrent callers

- The user explicitly called `fw work-on …` (one source).
- Autonomous cron agents periodically call `fw work-on` for liveness / pickup / peer-learning work (several sources — see `.context/cron-registry.yaml`).
- Cross-session TermLink dispatches call `fw work-on` on the orchestrator's behalf.
- The investigation itself exec-looped on the broken `bin/fw` (T-1278), queueing up retries.

Any session with background automation + ambient cron hits this race sooner or later.

## Impact

- **Duplicate IDs in the task store** — four tasks share `T-1278`.
- **Commit-message traceability compromised** — `git commit -m "T-1278: …"` matches any of four tasks; grep-based task-history tooling returns nondeterministic results.
- **Episodic memory corruption risk** — `generate-episodic T-1278` picks whichever file glob hits first.
- **Silent overwrite potential** — if two parallel invocations had the same slug, the second `cp` of the template would clobber the first. No collision detection.
- **Downstream fabric/audit logic** — any tool that assumes `T-NNNN` is a unique key is compromised.
- **Human confusion** — `fw task show T-1278` is ambiguous.

Not caught by `fw audit` (no uniqueness check), not caught by any bats test.

## Hot fix (manual, applied nowhere — documented for the human)

The three stray T-1278 files from this session should be renamed to the next free IDs. Since T-1279 is now taken by this task, stray reassignments start at T-1280:

- `T-1278-fix-inception-decide-on-consumer-project.md` → `T-1280-…`
- `T-1278-e2e-test-inception-decide-on-consumer-pr.md` → `T-1281-…`
- `T-1278-e2e-test-inception-decide-on-vendored-co.md` → `T-1282-…`
- (`T-1278-fix-unbounded-git-push-in-handover-auto-.md` is the duplicate of my manually-created `T-1277` — delete it; my T-1277 is the source of truth.)

I have NOT applied these renames — they require a human call (which ID wins, whether to merge content). Flagged in T-1279 ACs.

## Durable fix (tracked in T-1279)

1. Wrap `generate_id()` and the subsequent file-write in `keylock_acquire "task-id-allocation"` (lib/keylock.sh already exists). Lock covers the read-max → write-file sequence end-to-end.
2. Lock timeout 10s; fail loudly with retry guidance on contention.
3. Audit rule: duplicate `id:` frontmatter values across `.tasks/` → FAIL.
4. Repair tool: `fw task reid T-XXXX --new T-YYYY`.
5. Bats regression test: 5 parallel `create-task.sh` → 5 distinct IDs.

## Relationship to T-1277 / T-1278

Incidental find during their investigation. Unrelated to the 4h stall or the shim self-loop mechanically, but amplified by them:

- T-1278's exec loop caused `fw work-on` to retry and exec multiple times → more concurrent callers.
- The ~6-minute tail on `fw work-on` (RAG enrichment) keeps the allocation window wider than it should be.

All three bugs share a family: "framework plumbing operates without bounds or locks when concurrency appears." Worth a class-level learning after all three are fixed.

## Next actions

- [ ] Framework: ingest this observation + T-1279 into episodic memory
- [ ] Human: decide whether to rename or delete the three stray T-1278 files (see Hot fix section)
- [ ] After T-1279 ships: consider an umbrella learning about framework concurrency assumptions
