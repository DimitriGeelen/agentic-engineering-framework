# Inception Gate Friction Audit

## 1. Exact Gate Logic (commit-msg hook, lines 51-86)

Two gates, both in `.git/hooks/commit-msg`:

**Gate A — Exploration Commit Limit (T-126):**
- Detects inception tasks via `grep "^workflow_type: inception"` on the task file
- Checks for `**Decision**: GO|NO-GO|DEFER` pattern in the task file
- If no decision: counts all commits matching `$TASK_REF` via `git log --oneline --grep`
- **Threshold: 2 commits.** At `>= 2`, blocks with exit 1
- Commits 0-1 show info note: "commit N/2 before gate"

**Gate B — Research Artifact (C-001, lines 89-118):**
- After first commit, requires `docs/reports/${TASK_REF}-*` to exist on disk OR in staged changes
- Blocks with: "no research artifact (C-001/G-009)"

**Decision detection:** Looks for literal `**Decision**: GO` in the task markdown. Set by `fw inception decide`.

## 2. Session Trigger Evidence

No blocked commits in current session's git reflog. The gate is functional but wasn't triggered because T-629 (current inception) likely hasn't hit 2 commits yet.

## 3. Historical Blocking — SIGNIFICANT

**Known concern: R-032** in concerns.yaml (severity: medium, score: 8, status: watching since 2026-02-19):
> "2-commit inception gate incompatible with 5-10 session deep explorations. Forces --no-verify, which is logged but not ideal."

**Bypass log evidence — 24+ inception-related bypasses:**

| Task | Bypasses | Reason |
|------|----------|--------|
| T-191 | **16** | Deep 5-phase inception (5-10 sessions), decision premature at each phase |
| T-194 | **4** | Genesis discussion artifacts, research capture |
| T-124 | **4** | Inception experiment cycles 2-3 |

**91 total entries** mention "inception" in the bypass log. The gate has been bypassed far more often than it has usefully blocked work.

**114 inception-tagged commits** exist in project history — the 2-commit limit means the gate would theoretically fire on ~56 of those (every inception with >2 commits).

## 4. Simultaneous Inception + Build Workflow

**The real problem:** When inception produces a GO decision, build tasks (T-626, T-627) are created. But if focus is still on the inception task, or if commits reference the inception ID, the gate fires.

**Current workaround:** Either:
1. Record `fw inception decide T-XXX go` before building (proper path)
2. Create separate build tasks with new IDs (proper but friction)
3. `--no-verify` bypass (improper but common — 24+ logged instances)

**Gap:** The gate counts ALL commits with the task ID, not just exploration-type commits. A commit that fixes a typo in the research artifact counts the same as one that creates it.

## 5. Is the 2-Commit Limit Appropriate?

**No. It's too low for multi-phase inceptions, and the counting method is wrong.**

Evidence:
- T-191 needed **16 bypasses** across 5 phases — the gate was wrong every time
- T-124 needed 4 bypasses across experiment cycles
- R-032 has been an active concern for 5 weeks with no resolution
- The gate doesn't distinguish commit types (research artifact update vs. exploration spike vs. task creation)

**Appropriate for:** Quick inceptions (1-2 sessions, simple go/no-go)
**Inappropriate for:** Multi-phase inceptions, deep explorations, research-heavy tasks

## 6. TermLink Workers and the Inception Gate

**TermLink workers DO hit the gate** if they:
- Use `git commit` (not `--no-verify`)
- Reference an inception task ID in the commit message
- The inception task has no recorded decision

TermLink workers spawned via `fw termlink dispatch` use the project's git hooks. There's no special bypass path. A TermLink worker committing under an inception task ID would be blocked at commit 3+.

**Mitigation:** TermLink workers typically get their own build task IDs, so this is rare in practice. But if a worker is doing research under the inception ID, it will hit the gate.

## 7. Proposed Better Inception Gate Rules

### Option A: Configurable Threshold with Task-Level Override
```yaml
# In task frontmatter:
inception_commit_limit: 10  # Override default of 2
```
- Default stays at 2 for quick inceptions
- Deep inceptions declare their expected scope upfront
- Gate reads the task file for the override
- **Pro:** Simple, explicit. **Con:** Requires knowing scope upfront.

### Option B: Phase-Aware Counting (Recommended)
Instead of counting raw commits, count **phase transitions**:
- Phase = a set of commits between decision checkpoints
- Gate triggers when a phase has >N commits without a phase checkpoint
- `fw inception checkpoint "Phase 2 complete"` resets the counter
- Decision is the final checkpoint

**Implementation:**
```bash
# Count commits since last checkpoint marker
LAST_CHECKPOINT=$(git log --oneline --grep="$TASK_REF.*checkpoint\|$TASK_REF.*phase\|$TASK_REF.*decision" -1 --format=%H 2>/dev/null)
if [ -n "$LAST_CHECKPOINT" ]; then
    PHASE_COMMITS=$(git log --oneline "$LAST_CHECKPOINT"..HEAD --grep="$TASK_REF" | wc -l)
else
    PHASE_COMMITS=$(git log --oneline --grep="$TASK_REF" | wc -l)
fi
```
- **Pro:** Scales to any inception depth. **Con:** Requires new `checkpoint` command.

### Option C: Warn, Don't Block (Simplest)
- Change gate from `exit 1` (block) to `exit 0` (warn)
- Still logs, still reminds about decisions
- No bypass needed → bypass log stays clean
- Research artifact gate (Gate B) still blocks — that one is genuinely useful

**Pro:** Zero friction, zero bypasses. **Con:** Loses forcing function for simple inceptions.

### Recommendation: Option C (warn-only) + Option A (override for block)

Default behavior: **warn** at 2 commits, don't block. Add `inception_gate: strict` to task frontmatter for tasks that SHOULD block (quick go/no-go decisions). This matches observed reality — the gate is bypassed in >90% of multi-commit inceptions, meaning the block adds friction without preventing anything.

**The research artifact gate (Gate B) should remain blocking** — it has zero bypasses in the log and genuinely prevents knowledge loss.
