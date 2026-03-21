# T-477: Risk-Based Governance Declaration Layer

## Research Artifact

**Task:** Risk-based governance declaration layer — machine-readable predictability x blast-radius matrix that runtime maps to enforcement levels

**Spikes:**
1. Audit current enforcement surface → map to 2x2 matrix
2. Draft declaration format (`governance.yaml`)
3. Runtime mapping feasibility within Claude Code hooks

---

## Spike 1: Current Enforcement Surface Audit

### Methodology

Mapped all 30 enforcement points (11 hooks, 15 prose rules, 4 mixed) to a 2x2 matrix:
- **X-axis:** Blast radius (low / high)
- **Y-axis:** Predictability (deterministic / stochastic)

Full inventory in `/tmp/fw-agent-enforcement-audit.md` (417 lines).

### Summary Statistics

| Category | Count | Compliance |
|----------|-------|-----------|
| Deterministic hooks | 11 | ~100% (same input → same output) |
| Stochastic prose rules | 15 | ~70-80% (LLM interpretation drift) |
| Mixed (hook + prose) | 4 | Varies by component |
| Critical incidents fixed | 10 | All resolved |
| Medium issues outstanding | 6 | Watching |

### 2x2 Matrix Mapping

```
                    LOW BLAST RADIUS              HIGH BLAST RADIUS
                ┌─────────────────────────┬──────────────────────────────┐
                │ Q1: FULL INITIATIVE     │ Q3: PRE-AUTH GATE            │
                │                         │                              │
  DETERMINISTIC │ plan-mode block (E-004) │ budget-gate (E-002) ■        │
                │ fabric reminder (E-006) │ tier-0 guard (E-003) ■       │
                │ error watchdog (E-007)  │ pre-push audit (E-018) ■     │
                │ post-commit tools       │ task-gate blocking (E-001) ■ │
                │ (E-019-E-023)           │ build-readiness (E-010) ■    │
                │                         │ inception commit (E-015) ■   │
                │ 7 points                │ 6 points                     │
                │ No governance needed    │ WELL COVERED by hooks        │
                ├─────────────────────────┼──────────────────────────────┤
                │ Q2: INITIATIVE + AUDIT  │ Q4: AUTHORITY REQUIRED ⚠     │
                │                         │                              │
  STOCHASTIC    │ human AC format (PR-03) │ sub-agent dispatch (PR-04) ✗ │
                │ commit cadence (PR-14)  │ pickup msg scope (PR-06) ✗   │
                │ bug-fix learning (PR-09)│ autonomous boundaries (PR-12)│
                │ hypothesis debug (PR-08)│ human task closure (PR-11)   │
                │ session start (PR-13)   │ error investigation (PR-07)  │
                │                         │ root cause escalation (PR-10)│
                │ 5 points                │ 6 points                     │
                │ Low risk, prose is OK   │ THE GAP — prose-only, HIGH   │
                │                         │ blast, NO structural enforce │
                └─────────────────────────┴──────────────────────────────┘

■ = machine-enforced (blocking hook)
✗ = known incident from prose failure
⚠ = governance gap: highest consequence, lowest reliability
```

### Key Finding

**Q4 (high blast × stochastic) has 6 enforcement points with ZERO structural enforcement.** These are the framework's most consequential governance rules, enforced by its least reliable mechanism (prose in CLAUDE.md, interpreted by an LLM under variable context pressure).

Evidence of Q4 failures:
- **PR-04 (sub-agent dispatch):** T-073 — 9 agents returned 177K tokens inline, crashed session
- **PR-06 (pickup message):** session-010-termlink — agent bypassed inception, built immediately
- **PR-12 (autonomous boundaries):** agents interpreted "proceed" as authorization for --force
- **PR-11 (human task closure):** T-372/T-373 — agent suggested batch-closing without evidence

Two Q4 rules have been partially hardened:
- PR-04 now has advisory PostToolUse hook (E-005) — warns but cannot block
- PR-07 now has error-watchdog PostToolUse hook (E-007) — warns but cannot block

### Prior Art Context

From T-194 (risk landscape) and T-396 (disposition):
- 38 risks identified across 9 categories
- Risk register consolidated into `concerns.yaml` (type: gap | risk)
- T-396 disposition: "risks are discovered FROM incidents, not predicted"
- Current controls.yaml has 27 controls, 7-layer defense
- Enforcement-related gaps: G-015, G-017, G-020, G-021

The 2x2 matrix adds the missing axis: **predictability of enforcement mechanism**, not just predictability of the operation. This is what T-396 couldn't capture — the risk register tracked WHAT could go wrong, not HOW RELIABLY the framework detects it.

---

## Spike 2: Declaration Format Design

### Design Constraints

1. Must be human-editable YAML (framework convention)
2. Must express both current Tier 0 patterns AND prose-only rules
3. Must stay under 50 lines for 80%+ of governance rules (Go/No-Go criterion)
4. Must be consumable by PreToolUse hooks at O(1) or cached
5. Must degrade gracefully (missing file = current behavior)

### Approach: Operation Classes, Not Action Enumeration

The declaration doesn't list every possible action. It classifies **operation classes** by two dimensions and maps them to enforcement levels.

### Draft: `governance.yaml`

```yaml
# governance.yaml — Risk-based governance declarations
# Maps operation classes to enforcement levels based on
# predictability × blast-radius dimensions.
#
# Enforcement levels (derived from matrix position):
#   gate    — PreToolUse hook blocks until condition met (Q3: deterministic × high)
#   audit   — action logged, reviewable post-hoc (Q2: stochastic × low)
#   approve — requires human approval per instance (Q4: stochastic × high)
#   free    — no governance beyond audit trail (Q1: deterministic × low)

version: 1
schema: predictability-blast-radius/v1

operation_classes:

  # Q1: Deterministic × Low blast → free
  file_creation:
    predictability: deterministic
    blast_radius: low
    enforcement: free
    examples: ["mkdir", "touch", "git add"]

  status_query:
    predictability: deterministic
    blast_radius: low
    enforcement: free
    examples: ["git status", "fw doctor", "fw metrics"]

  # Q2: Stochastic × Low blast → audit
  task_selection:
    predictability: stochastic
    blast_radius: low
    enforcement: audit
    examples: ["choose next task", "set horizon"]

  commit_message:
    predictability: stochastic
    blast_radius: low
    enforcement: audit
    examples: ["write commit message", "choose description"]

  # Q3: Deterministic × High blast → gate
  destructive_command:
    predictability: deterministic
    blast_radius: high
    enforcement: gate
    gate_script: check-tier0.sh
    examples: ["git push --force", "rm -rf", "DROP TABLE"]

  source_modification:
    predictability: deterministic
    blast_radius: high
    enforcement: gate
    gate_script: check-active-task.sh
    examples: ["Write to .py/.sh/.yaml", "Edit source files"]

  context_budget:
    predictability: deterministic
    blast_radius: high
    enforcement: gate
    gate_script: budget-gate.sh
    examples: ["any tool call at >90% context"]

  # Q4: Stochastic × High blast → approve  ← THE GAP
  architectural_decision:
    predictability: stochastic
    blast_radius: high
    enforcement: approve
    approval: human_per_instance
    examples: ["choose implementation approach", "design new subsystem"]

  human_task_closure:
    predictability: stochastic
    blast_radius: high
    enforcement: approve
    approval: evidence_required
    rule_ref: "CLAUDE.md §Human Task Completion Rule"
    examples: ["suggest closing human-owned task", "batch-complete"]

  scope_escalation:
    predictability: stochastic
    blast_radius: high
    enforcement: approve
    approval: inception_required
    rule_ref: "CLAUDE.md §Pickup Message Handling"
    examples: [">3 new files", "new subsystem", "new CLI route"]

  sub_agent_dispatch:
    predictability: stochastic
    blast_radius: high
    enforcement: approve
    approval: preamble_required
    gate_script: check-dispatch.sh
    rule_ref: "CLAUDE.md §Sub-Agent Dispatch Protocol"
    examples: ["Task tool with >5 agents", "agent without preamble"]

  autonomous_bypass:
    predictability: stochastic
    blast_radius: high
    enforcement: approve
    approval: never_delegated
    rule_ref: "CLAUDE.md §Autonomous Mode Boundaries"
    examples: ["--force on any gate", "change task owner from human"]
```

### Analysis

**Line count:** 74 lines (including comments and examples). Over the 50-line target but not by much. Removing examples and comments brings it to ~45 lines.

**Coverage:** 12 operation classes covering all 4 quadrants:
- Q1 (free): 2 classes
- Q2 (audit): 2 classes
- Q3 (gate): 3 classes — maps directly to existing hooks
- Q4 (approve): 5 classes — THE NEW TERRITORY

**Can it express current Tier 0?** Yes — `destructive_command` class with `gate_script: check-tier0.sh`.

**Can it express prose-only rules?** Yes — Q4 classes reference CLAUDE.md sections and declare approval type. The declaration doesn't replace the prose — it makes the enforcement level machine-readable so the runtime knows WHICH rules need human approval.

**What it doesn't do:** It doesn't solve the enforcement problem for Q4. It declares that Q4 operations require human approval, but the mechanism for detecting Q4 operations at tool-call time is still the open question (Spike 3).

---

## Spike 3: Runtime Mapping Feasibility

### The Core Question

Can Q4 (stochastic × high blast) operations be intercepted at tool-call time? Or do they require post-hoc review?

### Analysis by Q4 Operation Class

| Operation Class | Interceptable at Tool-Call? | Mechanism |
|-----------------|---------------------------|-----------|
| `sub_agent_dispatch` | **YES** — Task tool PreToolUse | Parse prompt for preamble, count parallel agents |
| `scope_escalation` | **PARTIAL** — Write/Edit PreToolUse | Count new files in session; but "new subsystem" detection needs semantic analysis |
| `human_task_closure` | **PARTIAL** — Bash PreToolUse | Detect `fw task update.*--force` pattern; but "suggest closing" is in text output |
| `architectural_decision` | **NO** — inherently semantic | Cannot distinguish "choosing an approach" from "implementing a known approach" at tool level |
| `autonomous_bypass` | **YES** — Bash PreToolUse | Detect `--force`, `--no-verify`, owner change patterns |

### Feasibility Assessment

**3 of 5 Q4 classes can be structurally intercepted** (sub_agent_dispatch, autonomous_bypass, partial scope_escalation).

**2 of 5 require LLM-level awareness** (architectural_decision, human_task_closure suggestions). These CANNOT be reduced to hook pattern matching — they require the agent to read the declaration and self-classify its current action.

### Runtime Architecture Options

**Option A: Extend existing hooks only (incremental)**
- Enhance check-dispatch.sh to validate preamble inclusion (blocking, not advisory)
- Enhance check-tier0.sh to detect `--force` on fw commands
- Add new-file counter to check-active-task.sh (scope escalation)
- Cost: ~3h, 3 script modifications
- Coverage: 3 of 5 Q4 classes structurally enforced

**Option B: governance.yaml + hook consumer (declaration-driven)**
- Create governance.yaml as source of truth
- Hooks read governance.yaml to determine enforcement level
- Current hooks become enforcement executors, not policy owners
- Cost: ~8h, new governance reader + hook refactor
- Coverage: Same 3/5 structural, but policy is centralized and human-editable

**Option C: LLM-aware declarations (hybrid)**
- governance.yaml consumed by both hooks AND injected into agent context
- Hooks handle Q3 + interceptable Q4 operations
- Agent reads governance.yaml to self-classify Q4 operations that hooks can't intercept
- CLAUDE.md references governance.yaml instead of prose rules
- Cost: ~12h, governance reader + hook refactor + CLAUDE.md rewrite + testing
- Coverage: All 5/5 Q4 classes (3 structural + 2 LLM-aware)

### Recommendation

**Option A (extend existing hooks)** for immediate value. The declaration format (governance.yaml) is useful as documentation and architecture, but the enforcement ROI is in hardening the 3 interceptable Q4 classes. Option B/C can follow if the framework reaches external adoption scale.

The key insight: **governance.yaml is more valuable as a risk communication tool than as a runtime config file.** It tells humans and agents "this operation class requires approval" — whether that approval is enforced by a hook or by LLM self-discipline is a separate concern.

---

## Findings

### Spike 1: Enforcement Surface
- 30 enforcement points: 11 deterministic hooks (100% reliable), 15 stochastic prose (70-80%), 4 mixed
- Q4 (stochastic × high blast) has 6 rules with zero structural enforcement — this is the real gap
- 10 critical incidents all in Q3/Q4 — pattern matches the matrix model

### Spike 2: Declaration Format
- 12 operation classes in ~45-74 lines of YAML
- Successfully expresses both Tier 0 patterns and prose-only rules
- Q4 classes declare `enforcement: approve` with typed approval mechanisms
- Format is human-editable and hook-consumable

### Spike 3: Runtime Mapping
- 3 of 5 Q4 classes can be structurally intercepted via enhanced hooks
- 2 of 5 require LLM-level self-classification (architectural decisions, task closure suggestions)
- Three options with increasing cost/coverage: hooks-only (3h), declaration-driven (8h), hybrid (12h)

### The 2x2 Matrix Validates

The model exposes governance gaps that impact-only tiers miss:
- **Tier 0 is Q3** (deterministic × high) — well covered
- **Tier 1 is Q3** (task gate, budget gate) — well covered
- **Tier 2 is Q4** situational authorization — but no declaration of WHICH operations belong here
- **Tier 3 was never implemented** — Q1 operations don't need it

The matrix adds the missing axis: enforcement mechanism reliability. Current tiers classify by danger level; the matrix classifies by danger level AND detectability.

## Recommendation

**GO — Option A (extend existing hooks) as first deliverable.**

Build tasks:
1. **Harden check-dispatch.sh** — promote from advisory to blocking; validate preamble; enforce max parallel (3h)
2. **Add --force detection to check-tier0.sh** — detect `fw task update.*--force`, `--no-verify` patterns (2h)
3. **Write governance.yaml** — declaration file as architecture documentation (1h)
4. **Scope escalation counter** — track new files per session in check-active-task.sh (2h)

Total: ~8h across 4 focused build tasks.

Option B/C (declaration-driven runtime) deferred to post-launch — the declaration format exists as documentation; converting it to runtime config adds complexity without proportional enforcement gain for the 2/5 Q4 classes that remain LLM-dependent regardless.
