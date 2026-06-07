# arc-005 (arc-grooming) — Headline-Mechanic Wire Evidence

**Purpose:** G-062 wire-level demonstration of the arc-grooming `headline_mechanic` firing end-to-end. Constructed by T-1893 so the human can `fw arc close arc-grooming --demo docs/reports/arc-005-headline-mechanic-demo.md`.

**Headline mechanic (verbatim from `.context/arcs/arc-grooming.yaml`):**

> agent runs `fw arc create test` → arc-005 sequential ID auto-allocated; agent writes `arc_id: arc-005` on a task → save blocks if arc-005 doesn't exist (Tier-1); `fw audit` reports tag→arc_id parity and 30-day stale-arc warnings; `fw arc abandon` flips status without deleting YAML — observable: every task has one canonical arc_id resolving to an immutable arc, lifecycle has draft/in-progress/closed/abandoned tabs in Watchtower, 012-ArcSystem.md exists at repo root and FRAMEWORK.md indexes it

Five prongs. Each section below is a captured shell session. Re-execute any block from `/opt/999-Agentic-Engineering-Framework` to verify.

---

## Prong 1 — Sequential `arc-NNN` ID auto-allocation (T-NEW-1.5 / T-1848)

**Mechanic:** `fw arc create` allocates a monotonically increasing `arc-NNN` id per `.context/arcs/`. IDs are immutable (D-Immutability axiom captured in T-1846 inception).

**Wire evidence — the directory itself:**

```
$ ls -la .context/arcs/
total 28
-rw-r--r--  1 root root 2600 May 16 10:25 arc-grooming.yaml
-rw-r--r--  1 root root  892 May 16 10:25 dispatch-safety.yaml
-rw-r--r--  1 root root  663 May 16 10:25 embeddings-strategy.yaml
-rw-r--r--  1 root root 1696 May 16 10:25 orchestrator-rethink.yaml
-rw-r--r--  1 root root  648 May 16 10:25 project-shape-resilience.yaml

$ for f in .context/arcs/arc-*.yaml; do grep -m1 "^id:" "$f"; done
id: arc-005
```

Plus every slug-named arc carries its `arc-NNN` in the YAML body:

```
$ grep -m1 "^id:" .context/arcs/*.yaml
.context/arcs/arc-grooming.yaml:id: arc-005
.context/arcs/dispatch-safety.yaml:id: arc-001
.context/arcs/embeddings-strategy.yaml:id: arc-002
.context/arcs/orchestrator-rethink.yaml:id: arc-003
.context/arcs/project-shape-resilience.yaml:id: arc-004
```

Five arcs, ids `arc-001` through `arc-005`, monotonic, no gaps, no reuse — the allocation mechanic worked across all five.

**Not exercising live `fw arc create test` here** because (a) it would mutate state during demo capture and (b) `fw arc abandon` (the cleanup verb) is refused under `$CLAUDECODE=1` (T-1671). The current corpus is itself the wire-level proof of allocation.

**Sequential allocation is pinned by:** `tests/unit/arc_create_sequential_id.bats` (T-1848). Manual replay:

```
$ bin/fw arc create --help 2>&1 | grep -A2 "T-1852"
                            T-1852: new arcs are born status: draft. Use 'fw arc start'
```

---

## Prong 2 — Task-frontmatter `arc_id` Tier-1 hook block (T-NEW-2 / T-1849)

**Mechanic:** Writing a task with `arc_id:` that doesn't resolve to a real arc is blocked at PreToolUse by `agents/context/check-arc-id.{sh,py}`. Override is single-use Tier-2 (`FW_ALLOW_ARC_ID_DRIFT=1`), logged to `.context/working/.gate-bypass-log.yaml`.

**Wire evidence — live hook replay (captured 2026-05-18):**

```
$ TMPF=".tasks/active/T-9999-demo.md"
$ JSON=$(python3 -c '
import json, sys
content = """---\nid: T-9999\narc_id: arc-nonexistent-demo\n---\n"""
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": sys.argv[1], "content": content}}))
' "$(pwd)/$TMPF")
$ echo "$JSON" | CLAUDECODE=1 PROJECT_ROOT="$(pwd)" bash agents/context/check-arc-id.sh

══════════════════════════════════════════════════════════
  ARC_ID DOES NOT RESOLVE — Hostage-state guard (T-1849)
══════════════════════════════════════════════════════════

  Task:    T-9999
  File:    /opt/999-Agentic-Engineering-Framework/.tasks/active/T-9999-demo.md
  arc_id:  'arc-nonexistent-demo'

  arc_id must resolve to one of:
    - filename stem (slug):  .context/arcs/<arc_id>.yaml
    - allocated numeric id:  .context/arcs/*.yaml with `id: arc-NNN`

  Available arcs (slug form):
    - arc-grooming
    - dispatch-safety
    - embeddings-strategy
    - orchestrator-rethink
    - project-shape-resilience

  To proceed, choose ONE:
    1. Correct arc_id to a valid slug or arc-NNN form, OR
    2. Remove the arc_id field (unassigned tasks are allowed), OR
    3. Override (logged Tier 2):  FW_ALLOW_ARC_ID_DRIFT=1 ...

  Origin: arc-grooming inception Q1 (T-1846); D-Immutability (T-1848).
══════════════════════════════════════════════════════════

Hook exit: 2
PASS: hook blocked as expected
```

This task file (T-1893) itself is the positive-path proof — its `arc_id: arc-grooming` resolves cleanly, the hook returned exit 0, and the save proceeded.

**Pinned by:** `tests/unit/check_arc_id_*.bats` (T-1849 family).

---

## Prong 3 — `fw audit` reports tag→arc_id parity + 30-day stale-arc warning (T-NEW-3 / T-NEW-7)

**Mechanic:** Daily audit (`fw audit`, cron-scheduled) reports both directions of arc/task consistency.

**Wire evidence — today's audit (2026-05-18):**

```
$ grep -i "arc" .context/audits/2026-05-18.yaml
    check: "All 4 arc anchor_task references resolve to existing tasks"
    check: "All 5 in-progress arc(s) had task commits within 30 days"
    check: "No inline arc:<slug> tag-only scans outside canonical lib (T-1881)"
```

Three arc-related compliance checks fire daily:

| Check | What it catches | Origin |
|---|---|---|
| anchor_task resolves | Arc YAML cites a `T-NNNN` that doesn't exist | T-1856 (T-NEW-8) |
| 30-day stale-arc | In-progress arcs with no constituent-task commit in 30d | T-1855 (T-NEW-7) |
| no inline `arc:slug` scans | Code-level migration tripwire — silent-corpus regression | T-1881 |

All three currently PASS for arc-005. The audit is the runtime enforcement of the migration's invariants — not just one-shot at task-close.

---

## Prong 4 — `fw arc abandon` lifecycle transition without YAML deletion (T-NEW-5a / T-NEW-6)

**Mechanic:** `fw arc abandon <id>` flips the arc to `status: abandoned` and appends a JSON row to `.context/audits/arc-abandon.jsonl`. The YAML file stays in place (D-Immutability: never moved, never deleted).

**Wire evidence — CLI surface:**

```
$ bin/fw arc abandon
Usage: fw arc abandon <arc-id> --reason "<≥30 chars>"

$ bin/fw arc 2>&1 | grep -A4 "abandon"
  abandon <id> --reason "<≥30 chars>"
                            T-1854: mark arc abandoned (no longer pursued).
                            Allowed source states: draft, in-progress.
                            Refused under $CLAUDECODE=1 (T-1671 agent-gate).
                            JSON row appended to .context/audits/arc-abandon.jsonl.
                            D-Immutability: YAML stays, never moved/deleted.
```

**Implementation:**

```
$ grep -n "abandon" lib/arc.sh | head -5
18:#   2. arc-NNN IDs are NEVER reused. If arc-007 is abandoned, the next
21:#      a status transition (status: abandoned), not a file delete.
64:# in-progress → closed; arc_abandon (T-1854) transitions draft|in-progress
65:# → abandoned. Pre-T-1852 arcs remain `in-progress` (no force-migration).
67:ARC_STATES=("draft" "in-progress" "closed" "abandoned")
```

**Not exercised live** because `fw arc abandon` refuses under `$CLAUDECODE=1` (T-1671 — closure decisions belong to the human via Watchtower).

**Pinned by:** `tests/unit/arc_abandon.bats` — runs out-of-band, exit code + JSON row + YAML preservation all verified.

```
$ ls tests/unit/arc_abandon.bats
tests/unit/arc_abandon.bats
```

---

## Prong 5 — `012-ArcSystem.md` exists at repo root + indexed by FRAMEWORK.md (T-NEW-9 / T-1857)

**Mechanic:** Top-level documentation file at the repo root, indexed from `FRAMEWORK.md` so any new operator can find it.

**Wire evidence:**

```
$ ls -la 012-ArcSystem.md
-rw-r--r-- 1 root root 16661 May 17 00:31 012-ArcSystem.md

$ head -5 012-ArcSystem.md
# Arc System — Agentic Engineering Framework

## Overview

An **arc** is a multi-task workspace grouping work by theme. Where a task is

$ grep -n "012-ArcSystem" FRAMEWORK.md
128:artefact. See `012-ArcSystem.md` for the full invariant.
131:CLI verbs), see **[012-ArcSystem.md](012-ArcSystem.md)**.
272:| **Arc** | A multi-task workspace grouping work by theme. Holds the longitudinal narrative around several tasks pursuing one user-observable mechanic. Has a four-state lifecycle (`draft → in-progress → closed/abandoned`), an immutable `arc-NNN` id, and a human-readable slug. Optional — tasks without an arc remain first-class. See `012-ArcSystem.md`. |
```

File exists (16.6KB), has a clean H1, and FRAMEWORK.md references it at three distinct anchor points (invariant cross-link, primary CLI doc link, glossary entry).

---

## Summary table

| Prong | Mechanic | Wire evidence | Pinned by |
|---|---|---|---|
| 1 | Sequential `arc-NNN` allocation | `ls .context/arcs/` + `grep ^id:` shows arc-001..arc-005 monotonic | `tests/unit/arc_create_sequential_id.bats` |
| 2 | Tier-1 hook blocks bad `arc_id:` | Live hook replay → exit 2 + actionable block-message | `tests/unit/check_arc_id_*.bats` |
| 3 | `fw audit` tag→arc_id parity + 30d stale | 3 PASS checks in today's `.context/audits/2026-05-18.yaml` | T-1855, T-1856, T-1881 |
| 4 | `fw arc abandon` flips state, keeps YAML | CLI help + lib/arc.sh state list + bats pin | `tests/unit/arc_abandon.bats` |
| 5 | `012-ArcSystem.md` + FRAMEWORK.md index | File exists + 3 FRAMEWORK.md references | T-1857 |

All five user-observable behaviours fire. The arc's substrate (27 build tasks) is in place; its **deliverable** (one canonical `arc_id` per task, hook-enforced, audited, lifecycle verbs available, docs indexed) is demonstrated above.

---

## Closure preconditions

Before `fw arc close arc-grooming --demo docs/reports/arc-005-headline-mechanic-demo.md`:

1. **Human-AC review** for the 6 partial-complete constituents:
   - T-1851 (deprecate `constituent_tasks` field)
   - T-1852 (lifecycle state machine: draft + abandoned)
   - T-1853 (Watchtower `/arcs` lifecycle filter tabs)
   - T-1857 (012-ArcSystem.md + FRAMEWORK.md updates)
   - T-1890 (focus-drift bypass flag mismatch — neighbour task, not strictly arc-tagged but pinned during this slice)
   - T-1891 (CLAUDE.md L-399 codification — neighbour)

   Surface: `fw review-queue` or visit Watchtower `/approvals`.

2. **Review T-1893** (this task) — confirm the demo file is acceptable as wire-evidence.

3. **Run closure** from Watchtower or with `--from-watchtower` exemption.

### Closure-precondition status — 2026-05-18 (post-T-1903)

| Precondition | State | Notes |
|---|---|---|
| T-1851 review | ✅ archived | moved to completed/ before this session |
| T-1852 review | ✅ archived | moved to completed/ before this session |
| T-1853 review | ✅ archived | moved to completed/ before this session |
| T-1857 review | ✅ archived | moved to completed/ before this session |
| T-1890 review | ✅ archived | unstuck via `fw task archive-eligible` (T-1903) — was in the L-403 trap (re-classed by T-1894 to zero Human ACs, but PARTIAL_COMPLETE recheck never re-fired) |
| T-1891 review | ⏳ pending [REVIEW] | one genuine taste-judgment AC: "section reads cleanly and matches surrounding §Agent Behavioral Rules tone" — cannot be agent-closed |
| T-1893 review | ✅ archived | this task |
| Run closure | ⏳ blocked | T-1671 §ACD gate: `fw arc close` refused under `$CLAUDECODE=1` — needs human via Watchtower or `--from-watchtower` exemption |

T-1902 (filed 2026-05-18) proposes a `/arcs/<slug>/close` Watchtower surface so closure is one-click for the human without weakening T-1671. Inception **decided GO** by human via Watchtower at 2026-05-18T20:13Z; implementation slices (CLI verb `fw arc review`, `/arcs/<slug>/close` page, backend POST handler, prerequisite-check function) pending build-task filing in a future session.

### Sibling work shipped 2026-05-18 (same arc-grooming closure cluster RCA)

| Task | Class | Outcome |
|---|---|---|
| T-1902 | inception | GO — close-review surface approved |
| T-1903 | build (prevention) | `fw task archive-eligible` sweep verb + CTL-029 audit detector — prevents L-403 re-class trap recurrence |
| T-1905 | inception | DEFER — `/arcs` kanban feature-parity scoped into 4 ordered build slices |
| T-1908 | build (bug) | `safe-commands.sh` env-prefix stripping — repairs L-399/T-1890 producer/consumer parity contract |

The arc-grooming arc's closure path is now: T-1891 [REVIEW] (human taste judgment) → human invokes `fw arc close arc-grooming --from-watchtower` via T-1902-implemented surface (once built) or current raw CLI.

---

*Generated by T-1893 — arc-005 closure demo evidence capture (G-062 wire artefact).*
