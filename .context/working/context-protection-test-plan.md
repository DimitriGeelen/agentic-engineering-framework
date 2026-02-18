# Context Protection Live Test Plan (P-009 Validation)

## Objective
Validate that token-aware context monitoring works in a real session.

## Pre-conditions
- `.claude/settings.json` exists with PostToolUse hook → checkpoint.sh
- Counter file at `.context/working/.tool-counter`
- Post-commit hook v1.1 installed
- JSONL transcript available at `~/.claude/projects/*/UUID.jsonl`

## Test Protocol

### Phase 1: Hook Activation (first 5 tool calls)
1. Start new session (`claude` or `/resume`)
2. Check: `./agents/context/checkpoint.sh status`
3. **Expected**: Counter > 0 AND token count shown (proves both hook and token reading work)
4. If counter is 0: hook not loading — check `.claude/settings.json`
5. If tokens unavailable: transcript not found — check `~/.claude/projects/`

### Phase 2: Token Accuracy
1. Run status at different points during work
2. Compare reported tokens to observed compaction behavior
3. **Expected**: Token count grows as conversation progresses
4. Note the lag (reading shows previous call's tokens, ~10-30K behind actual)

### Phase 3: Warning Thresholds (natural work)
1. Work normally — warnings fire at 100K / 130K / 150K tokens
2. Monitor for stderr warnings appearing in tool outputs
3. **Expected**: Warnings appear without manual intervention when thresholds crossed
4. Note: tokens are only checked every 5th tool call

### Phase 4: Commit Reset
1. When tool call counter is high, make a commit
2. Check counter: `./agents/context/checkpoint.sh status`
3. **Expected**: Tool call counter resets to 0; token count unchanged (tokens reflect actual state)

### Phase 5: Checkpoint Handover
1. Run: `fw handover --checkpoint`
2. **Expected**:
   - Checkpoint file created in `.context/handovers/CHECKPOINT-*.md`
   - LATEST.md NOT overwritten
   - Tool call counter resets to 0

### Phase 6: Handover at Critical (only if context gets high)
1. If token warnings appear, run: `fw handover`
2. **Expected**:
   - Full handover with [TODO] sections for agent enrichment
   - Machine-gathered task list and git state
   - Auto-committed

## Results (2026-02-14)

| Test | Status | Notes |
|------|--------|-------|
| Phase 1: Hook activation | PASSED | Counter increments, tokens readable |
| Phase 2: Token accuracy | PASSED | ~81K at status check, consistent with session activity |
| Phase 3: Warning thresholds | PENDING | Need to reach 100K naturally |
| Phase 4: Commit reset | PASSED | Counter 11 → 0 on commit |
| Phase 5: Checkpoint handover | PASSED | Checkpoint created, LATEST preserved |
| Phase 6: Emergency handover | SKIPPED | Not needed this session |

## Learnings Captured

1. **Token data location**: `message.usage` in JSONL transcript entries (L-009)
2. **Compaction threshold**: ~155-165K tokens observed across sessions (L-010)
3. **Reading lag**: ~1 API call behind actual, ~10-30K tokens (L-011)
4. **grep false matches**: Can't use grep alone — command text contains "input_tokens" too (L-012)
5. **Antifragile pattern**: Failure → post-mortem → capability (AF-001)

## Success Criteria
- [x] Hook fires automatically (counter increments without manual invocation)
- [ ] At least one warning threshold reached during natural work
- [x] Commit resets tool call counter to 0
- [x] Token reading returns accurate context size
- [x] No tool calls blocked (always exit 0)
- [x] No noticeable performance degradation (~23ms per check)
