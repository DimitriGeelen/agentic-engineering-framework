# T-435: Claude Code Settings — Inception Research

## Status: NO-GO (Deferred)

This inception was prematurely executed before proper exploration. The research artifact
was written directly to `docs/claude-code-settings.md` rather than following the standard
inception flow.

## Research Artifact

See: [docs/claude-code-settings.md](../claude-code-settings.md)

Contains:
- All Claude Code settings the framework depends on (4 scope levels)
- Why each setting is configured the way it is
- Framework consequences if changed
- 6 recommendations for improving agent success rate

## Decision

**NO-GO** — Defer. The research artifact exists but the inception was not properly
conducted. Human must review the 6 recommendations and decide which to implement.
Reopen as proper inception when ready.

## Recommendations Pending Review

1. Consider `alwaysThinkingEnabled: true`
2. Set `BASH_DEFAULT_TIMEOUT_MS` higher for long operations
3. Add `SessionEnd` hook for auto-handover
4. Add `UserPromptSubmit` hook for task gate
5. Consider sandbox mode for external adopters
6. Pin model for consistency

## Next Steps (when reopened)

- Review each recommendation against D1-D4 directives
- Score implementation effort vs. impact
- Create build tasks for approved recommendations
