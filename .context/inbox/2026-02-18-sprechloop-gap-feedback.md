# Framework Feedback: Two Structural Gaps Found in Project Onboarding

**Source:** sprechloop project (001-sprechloop), discovered 2026-02-18 during audit
**Priority:** High (G-001), Medium (G-002)
**Filed by:** agent during T-023 audit review

---

## G-001: Hook Config Not Propagated to New Projects

### Problem

When a project uses the shared framework via `.framework.yaml`, Claude Code hooks
(budget-gate.sh, checkpoint.sh, check-active-task.sh, check-tier0.sh, pre-compact.sh,
post-compact-resume.sh, error-watchdog.sh) are **not automatically registered**.

The framework's own `.claude/settings.json` has the full hook config, but projects
must manually create `.claude/settings.local.json` with `PROJECT_ROOT=...` prefixed
commands. There is no `fw init` step, template, or doctor check that handles this.

### Impact

sprechloop ran its entire lifetime (~20 sessions) without:
- Budget enforcement (no PreToolUse budget-gate.sh)
- Context checkpoint warnings (no PostToolUse checkpoint.sh)
- Error watchdog (no PostToolUse error-watchdog.sh)
- Pre-compact handover (no PreCompact hook)

Only check-active-task.sh and check-tier0.sh happened to work because the
project's git commit-msg hook was installed separately.

### Suggested Fix

**Option A (recommended):** Add a `fw hooks install` command that:
1. Reads the framework's `.claude/settings.json` as template
2. Prefixes all commands with `PROJECT_ROOT=<project_root>`
3. Writes to `<project_root>/.claude/settings.local.json`
4. Merges with existing settings if present

**Option B:** Add a doctor check:
```
[FAIL] No .claude/settings.local.json — budget hooks not active
       Mitigation: Run 'fw hooks install' to register hooks
```

**Option C:** Make `fw init` (or `/new-project`) auto-generate the hook config
as part of project scaffolding.

### Manual Fix Applied

Created `/opt/001-sprechloop/.claude/settings.local.json` manually with all hooks
from the framework template, prefixed with `PROJECT_ROOT=/opt/001-sprechloop`.

---

## G-002: Handover Open Questions Lost Between Sessions

### Problem

The handover agent writes an "Open Questions / Blockers" section as prose in
markdown. These items are **not registered** in any structured tracking system
(gaps.yaml, tasks, assumptions). They exist only in the handover file.

When the next session starts, the resume agent reads the handover but there is
no structural enforcement to ensure open questions are acted on. They can be
(and were) silently dropped.

### Evidence

Handover S-2026-0218-1030 contained this open question:

> 3. Context budget monitoring hooks (checkpoint.sh, budget-gate.sh) are missing
>    from this project — referenced in CLAUDE.md but not installed. Gap to address.

This was never registered as a gap, task, or assumption. It was only discovered
when a human explicitly asked to audit gaps.

### Suggested Fix

**Option A (recommended):** Enhance the handover agent to classify each open question:
- If it's a spec-reality gap → auto-register in gaps.yaml (or prompt agent to)
- If it's actionable work → create a task
- If it's informational → leave as prose (but tag as "noted")

**Option B:** Add a resume agent step that parses LATEST.md open questions and
prompts: "These open questions from last session have no tracking. Register them?"

**Option C:** Add an audit check:
```
[WARN] Handover has N open questions with no corresponding gaps/tasks
       Mitigation: Register open questions via 'fw gaps add' or 'fw task create'
```

---

## Summary

Both gaps share a root cause: **the framework assumes agents will manually do the
right thing** (register hooks, register gaps) instead of **structurally enforcing it**.
This contradicts the core principle that enforcement should be structural, not
discipline-based. The fix in both cases is to add mechanical gates or automation
at the transition points (project init, session handover).
