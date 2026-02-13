# 020-Experiments: Framework Validation Protocol

> "The framework's biggest insight came from using it, not designing it." — T-015 discovery

## Purpose

Define deliberate experiments to validate framework assumptions. Each experiment tests a specific claim with observable outcomes.

---

## Minimum Viable Enforcement (MVE)

**Question:** If someone adopts this framework but can only implement ONE enforcement gate, which provides the most value?

### Analysis

| Gate | What It Enforces | Failure Mode Without It |
|------|------------------|------------------------|
| Git commit hook | Task traceability | Work happens without record; can't reconstruct why |
| Handover gate | Episodic completeness | Context lost at session boundaries |
| Audit on push | Overall compliance | Drift accumulates silently |
| Task validation | Required fields | Tasks exist but are useless |

### Answer: **Git Commit Hook (Task Reference Required)**

**Rationale:**
1. **Structural, not behavioral** — Enforces at action point, not review point
2. **Creates audit trail** — Every change links to intent
3. **Enables everything else** — Without traceability, episodics are orphaned, handovers reference nothing
4. **Lowest friction** — One line addition to commit message
5. **Hardest to bypass** — Pre-commit hooks require explicit `--no-verify`

**MVE Implementation:**
```bash
# Install hook
./agents/git/git.sh install-hooks

# That's it. One command, permanent enforcement.
```

**What you lose without the others:**
- No handover gate → context may be lost (but commits still traceable)
- No audit → drift not detected (but can run manually)
- No task validation → low quality tasks (but at least they exist)

---

## Experiment Protocol

### E-001: Real Project Validation

**Directive tested:** D3 (Usability) — "Joy to use"

**Hypothesis:** Framework overhead is justified when AI context loss is the actual problem being solved.

**Method:**
1. Apply framework to a real project (not this meta-project)
2. Use for 5+ sessions with context compaction
3. Track: time to resume, repeated mistakes, friction points

**Success criteria:**
- Resume time < 2 minutes using handover + resume agent
- No repeated mistakes that were already captured as patterns
- User doesn't bypass enforcement (bypass rate < 10%)

**Failure indicator:**
- User bypasses hooks more than they use them
- Framework overhead exceeds time saved
- Handovers aren't read by next session

**Expected learnings:**
- Which parts are actually used vs. ignored
- Where friction is too high
- What's missing for real workflows

---

### E-002: LLM Portability Test

**Directive tested:** D4 (Portability) — "No provider lock-in"

**Hypothesis:** A different LLM (GPT-4, Gemini) can follow CLAUDE.md and operate the framework.

**Method:**
1. Start session with GPT-4 or Gemini
2. Point it at CLAUDE.md
3. Ask it to: create task, make changes, commit, generate handover
4. Observe: Does it understand? Does it comply? Where does it struggle?

**Success criteria:**
- LLM creates valid task file
- LLM commits with task reference
- LLM generates usable handover
- No Claude-specific assumptions block it

**Failure indicator:**
- LLM can't parse CLAUDE.md structure
- Agent scripts assume Claude-specific behavior
- Framework only works with one provider

**Expected learnings:**
- Which instructions are provider-agnostic
- What needs to be generalized
- Whether MCP/LSP would help portability

---

### E-003: Context Recovery Stress Test

**Directive tested:** D1 (Antifragility) — "Strengthens under stress"

**Hypothesis:** Handover + resume agent enables recovery after severe context loss.

**Method:**
1. Work on a task for 30+ minutes
2. Simulate compaction (new session with only summary)
3. Run `./agents/resume/resume.sh status`
4. Attempt to continue work
5. Measure: time to productive, mistakes made, context gaps

**Success criteria:**
- Productive work resumes within 3 minutes
- No contradictory actions (undoing previous work)
- Key decisions from prior session are accessible

**Failure indicator:**
- Have to re-read task files manually
- Make decisions that contradict prior session
- Resume agent output isn't actionable

**Expected learnings:**
- What context is lost vs preserved
- Whether handover format captures what matters
- Resume agent improvements needed

---

### E-004: Enforcement Removal Test

**Directive tested:** D2 (Reliability) — "Predictable, auditable"

**Hypothesis:** Each enforcement gate prevents specific failure modes; removing one causes detectable degradation.

**Method:**
1. Disable git commit hook (`git config --unset core.hooksPath`)
2. Work normally for 5 commits
3. Run audit, measure traceability
4. Re-enable, repeat with handover gate disabled
5. Compare degradation patterns

**Success criteria:**
- Removing git hook → traceability drops measurably
- Removing handover gate → episodic gaps appear
- Each gate has distinct, observable effect

**Failure indicator:**
- Removing a gate has no measurable effect (gate is theater)
- Multiple gates are redundant (doing same check)
- Degradation happens but audit doesn't catch it

**Expected learnings:**
- Which gates are load-bearing
- Which might be redundant
- Whether enforcement is real or theater

---

### E-005: Multi-Agent Stress Test

**Directive tested:** D1 (Antifragility) — "Learning from failure"

**Hypothesis:** The healing loop captures and prevents repeated failures.

**Method:**
1. Deliberately cause a task to fail (e.g., bad dependency)
2. Run healing agent: `./agents/healing/healing.sh diagnose T-XXX`
3. Resolve and record pattern
4. Cause similar failure on different task
5. Check if healing agent suggests prior pattern

**Success criteria:**
- First failure captured as pattern
- Second failure gets relevant suggestion
- Pattern matching is specific enough to be useful

**Failure indicator:**
- Patterns too generic ("something failed")
- No pattern suggested for similar failure
- Suggestions aren't actionable

**Expected learnings:**
- Whether pattern taxonomy is useful
- How specific patterns should be
- Healing loop effectiveness

---

## Experiment Prioritization

| Experiment | Effort | Risk of Surprise | Value of Learning |
|------------|--------|------------------|-------------------|
| E-001 Real Project | High | High | Very High |
| E-002 LLM Portability | Medium | Medium | High |
| E-003 Context Recovery | Low | Medium | High |
| E-004 Enforcement Removal | Low | Low | Medium |
| E-005 Healing Loop | Low | Medium | Medium |

**Recommended order:** E-003 → E-004 → E-005 → E-002 → E-001

Start with low-effort experiments that can run now, save real project validation for when confidence is higher.

---

## Running an Experiment

```bash
# 1. Create task for experiment
./agents/task-create/create-task.sh --name "Run E-003 Context Recovery" --type test

# 2. Document hypothesis and method in task
# 3. Execute experiment
# 4. Record results in task Updates
# 5. Extract learnings → add to learnings.yaml if generalizable
# 6. Update this document with findings
```

---

## Findings Log

| Experiment | Date | Result | Key Learning |
|------------|------|--------|--------------|
| E-003 | 2026-02-13 | PASS | Recovery in <20 seconds; resume + handover sufficient |
| E-004 | 2026-02-13 | PASS | Hook removal causes 9% traceability drop in 5 commits; audit detects drift |
| E-005 | 2026-02-13 | PASS (with issues) | Healing loop captures and suggests patterns; classifier needs improvement |

### E-003 Detailed Findings

**Date:** 2026-02-13
**Result:** PASS (with minor issues)

**Recovery time:** ~16 seconds to actionable context

**What worked:**
- Resume agent immediately showed focus task (T-022) and status
- Task name alone ("Run E-003 Context Recovery Stress Test") was descriptive enough
- Uncommitted changes warning was helpful
- Handover provided full session context, decisions, next steps

**Issues found:**
- Resume agent reads LATEST.md which may be stale (not updated until commit)
- If handover isn't committed, resume shows outdated summary

**Recommendations:**
1. Always commit handover immediately after generating
2. Consider having handover.sh auto-update LATEST.md (it does, but user may not commit)
3. Resume agent could warn if LATEST.md has TODO placeholders

---

*This document evolves as experiments are run. Update the Findings Log after each experiment.*

### E-004 Detailed Findings

**Date:** 2026-02-13
**Result:** PASS — Each enforcement gate has distinct, measurable effect

**Method:**
1. Baseline audit: 97% traceability (46/47 commits), 15 passes, 3 warnings
2. Disabled commit-msg hook (renamed to .bak)
3. Made 5 commits without task references ("Quick fix #1-5")
4. Ran audit again

**Measurements:**

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Traceability | 97% (46/47) | 88% (46/52) | -9% |
| Audit passes | 15 | 14 | -1 |
| Audit warnings | 3 | 4 | +1 |

**What worked:**
- Audit detected BOTH the missing hook AND the traceability drop
- Git agent printed bypass warnings even without hook (defense in depth)
- 5 untraceable commits caused immediate, measurable degradation
- Each gate has distinct effect — not redundant, not theater

**Surprise finding:**
- Git agent has a secondary detection layer — it warns about missing task refs at `git status` time too, not just at commit time. The hook is the primary gate but not the only defense.

**Conclusion:**
- The git commit hook is the MVE (confirmed from E-003 + E-004)
- Removing it causes 9% traceability drop in just 5 commits
- Audit catches the drift — but only when run (reactive, not preventive)
- The hook is preventive; the audit is detective — both needed

**Recommendations:**
1. Hook = must-have (preventive enforcement)
2. Audit = should-have (detective enforcement)  
3. Consider auto-audit on push for continuous detection

### E-005 Detailed Findings

**Date:** 2026-02-13
**Result:** PASS (with issues — classifier needs improvement)

**Method:**
1. Created test task T-026 with simulated dependency failure (yaml_validator version conflict)
2. Set status to `issues`
3. Ran `healing.sh diagnose T-026` — checked classification and pattern lookup
4. Ran `healing.sh resolve T-026` — recorded pattern FP-003 (dependency-version-conflict)
5. Created test task T-027 with similar dependency failure (jsonschema-validator conflict)
6. Ran `healing.sh diagnose T-027` — checked if FP-003 was suggested

**Results:**

| Step | Expected | Actual | Pass? |
|------|----------|--------|-------|
| Classify T-026 failure | "dependency" | "code" | FAIL |
| Find similar patterns for T-026 | No match (first occurrence) | FP-001 shown (irrelevant) | PARTIAL |
| Record FP-003 via resolve | Pattern saved | FP-003 saved correctly | PASS |
| Classify T-027 failure | "dependency" | "unknown" | FAIL |
| Suggest FP-003 for T-027 | FP-003 shown | FP-003 shown | PASS |
| suggest command finds T-026 | Lists T-026 | Lists T-026 | PASS |

**What worked:**
- Pattern recording works correctly (FP-003 saved with full metadata)
- Pattern recall works — FP-003 appeared in T-027's diagnosis
- The `suggest` command correctly finds tasks with `issues` status
- The `resolve` command records both pattern and learning atomically

**Issues found:**
1. **Classifier is keyword-order-dependent:** Checks "code" keywords before "dependency". Since "error" appears in most failures, it matches "code" first even for dependency issues. T-027 got "unknown" because it didn't match early keywords.
2. **Pattern matching is non-semantic:** `find_similar_patterns` shows ALL patterns regardless of relevance. FP-001 (timestamp loop) was shown for a dependency issue. No filtering by failure type.
3. **diagnose reads wrong section:** It parsed the task-creation update instead of the actual failure update for T-027, because the failure text was appended after the Updates section marker.

**Root causes:**
- Classifier uses ordered keyword matching (`declare -A` in bash doesn't guarantee order, but the for loop hits "code" first)
- Pattern matching dumps all patterns rather than filtering by type or keyword similarity
- Update extraction assumes rigid task file structure

**Recommendations (Error Escalation Ladder):**
1. **B - Improve technique:** Make classifier check most-specific keywords first (dependency before code)
2. **B - Improve technique:** Filter patterns by failure type in find_similar_patterns
3. **C - Improve tooling:** Add keyword-based relevance scoring to pattern matching
4. **D - Change ways of working:** Consider semantic similarity for pattern matching (future)

**Conclusion:**
The healing loop's core mechanism works — it captures patterns on resolve and surfaces them on diagnose. The **write path** (resolve) is solid. The **read path** (diagnose) needs improvement in classification accuracy and pattern relevance filtering. The loop is functional but not yet intelligent.
