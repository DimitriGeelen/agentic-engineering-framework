# Healing Agent

> Antifragile error recovery and pattern learning.

## Purpose

The healing agent implements the **healing loop** from the framework:

1. **Classify** failures by type (code, dependency, environment, design, external)
2. **Lookup** existing patterns for similar failures
3. **Suggest** recovery actions using the Error Escalation Ladder
4. **Log** resolutions as patterns for future learning

This makes the system **antifragile** (D1) — it strengthens from failures.

## Commands

### diagnose — Analyze task issues

```bash
./agents/healing/healing.sh diagnose T-015
```

When a task is in `issues` or `blocked` status, diagnose:
- Classifies the failure type
- Searches for similar patterns in patterns.yaml
- Suggests recovery actions per the Error Escalation Ladder

**Output:**
```
=== HEALING LOOP DIAGNOSIS ===
Task: T-015 - Fix API timeout
Status: issues

=== FAILURE CLASSIFICATION ===
Type: external
Category: External service issue
Typical causes: API down, rate limit, network timeout

=== SIMILAR PATTERNS ===
FP-001: API timeout on external calls
  Mitigation: Add retry with exponential backoff

=== SUGGESTED RECOVERY ===
A. Don't repeat the same failure:
   - Check patterns.yaml for known mitigations

B. Improve technique:
   - Add retry logic with backoff
   - Add circuit breaker
   - Cache responses where possible
...
```

### resolve — Record resolution

```bash
./agents/healing/healing.sh resolve T-015 --mitigation "Added retry with exponential backoff"
```

After fixing an issue:
- Records failure pattern to patterns.yaml
- Records learning to learnings.yaml
- Adds resolution note to task updates

**Options:**
- `--mitigation "text"` — What fixed the issue
- `--pattern "name"` — Short name for the pattern (prompted if not provided)

### patterns — Show known patterns

```bash
./agents/healing/healing.sh patterns
```

Lists all failure patterns with mitigations:
```
FP-001: Timestamp update loop
  Mitigation: Only update active tasks, not completed ones
  From: T-013

FP-002: sed returns malformed integers
  Mitigation: Use simpler grep -c piped through tr -d
  From: T-014
```

### suggest — Check all problem tasks

```bash
./agents/healing/healing.sh suggest
```

Scans all tasks with `issues` or `blocked` status and suggests actions.

## Error Escalation Ladder

The diagnose command suggests actions using the graduated response model:

| Level | Response |
|-------|----------|
| **A** | Don't repeat the same failure — lookup patterns |
| **B** | Improve technique — better approach for this type |
| **C** | Improve tooling — automate the check |
| **D** | Change ways of working — update practices |

## Failure Types

| Type | Keywords | Typical Causes |
|------|----------|----------------|
| code | error, exception, bug, syntax, crash | Logic error, null reference, type mismatch |
| dependency | package, module, version, conflict | Missing package, version conflict |
| environment | config, path, permission, connection | Wrong config, missing env vars |
| design | architecture, approach, refactor | Wrong approach, needs redesign |
| external | api, service, network, timeout | API down, rate limit |

## Workflow

1. Task encounters problem → set status to `issues`
2. Run `healing.sh diagnose T-XXX`
3. Apply suggested fix
4. Run `healing.sh resolve T-XXX --mitigation "what I did"`
5. Set task status back to `started-work`
6. Continue work

## Integration

The healing agent integrates with:
- **Context Fabric** — Reads/writes patterns.yaml, learnings.yaml
- **Audit Agent** — Audit checks for Tier 0 violations use similar patterns
- **Episodic Memory** — Resolutions are captured in task summaries

## Example Session

```bash
# Task hits an issue
$ grep "^status:" .tasks/active/T-015-*.md
status: issues

# Diagnose the problem
$ ./agents/healing/healing.sh diagnose T-015
=== HEALING LOOP DIAGNOSIS ===
Task: T-015 - Fix API calls
Type: external
...suggests adding retry logic...

# After fixing
$ ./agents/healing/healing.sh resolve T-015 --mitigation "Added retry with exponential backoff"
Pattern recorded: FP-003
Learning recorded: L-005

# Continue work
$ sed -i 's/^status:.*/status: started-work/' .tasks/active/T-015-*.md
```

## Related

- `.context/project/patterns.yaml` — Failure patterns storage
- `.context/project/learnings.yaml` — Learning storage
- `CLAUDE.md` — Error Escalation Ladder
- `010-TaskSystem.md` — Healing loop specification
