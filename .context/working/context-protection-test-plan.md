# Context Protection Live Test Plan (P-009 Validation)

## Objective
Validate that the Claude Code PostToolUse hook fires automatically and
the 5-layer defense-in-depth system works in a real session.

## Pre-conditions
- `.claude/settings.json` exists with PostToolUse hook → checkpoint.sh
- Counter file at `.context/working/.tool-counter`
- Post-commit hook v1.1 installed

## Test Protocol

### Phase 1: Hook Activation (first 5 tool calls)
1. Start new session (`claude` or `/resume`)
2. After first tool call, check: `cat .context/working/.tool-counter`
3. **Expected**: Counter > 0 (proves hook is firing)
4. If counter is 0: hook not loading — check `.claude/settings.json` path

### Phase 2: Warning Thresholds (natural work)
1. Do real work (Phase 3 of Watchtower, or any task)
2. Monitor for warnings appearing in tool outputs:
   - At ~40 calls: "Note: X tool calls since last commit. Commit work frequently."
   - At ~60 calls: "WARNING: X tool calls. Consider: fw handover --checkpoint"
   - At ~80 calls: "CRITICAL: X tool calls. ACTION: Run fw handover --emergency NOW"
3. **Expected**: Warnings appear without manual intervention

### Phase 3: Commit Reset
1. When warning fires, make a commit
2. Check counter: `cat .context/working/.tool-counter`
3. **Expected**: Counter resets to 0, warnings stop

### Phase 4: Checkpoint Handover
1. After ~50 tool calls, run: `fw handover --checkpoint`
2. **Expected**: 
   - Checkpoint file created in `.context/handovers/CHECKPOINT-*.md`
   - LATEST.md NOT overwritten
   - Counter resets to 0

### Phase 5: Emergency Handover (optional — only if context gets low)
1. If context warnings appear, run: `fw handover --emergency`
2. **Expected**: 
   - Handover file with 0 [TODO] sections
   - All data machine-gathered
   - Auto-committed
   - Counter resets to 0

## Learnings to Capture

After the test, record answers to:
1. **Threshold calibration**: Are 40/60/80 the right numbers? Too early? Too late?
2. **Warning visibility**: Do stderr warnings actually appear in the conversation?
3. **Hook performance**: Does the hook add noticeable latency to tool calls?
4. **False positives**: Do commits happen frequently enough that warnings rarely fire?
5. **Counter accuracy**: Does the counter correlate with actual context consumption?
6. **Emergency handover quality**: Is the machine-generated handover sufficient for recovery?

## Success Criteria
- [ ] Hook fires automatically (counter increments without manual invocation)
- [ ] At least one warning threshold reached during natural work
- [ ] Commit resets counter to 0
- [ ] No tool calls blocked (always exit 0)
- [ ] No noticeable performance degradation

## Failure Modes to Watch
- Hook path not found (absolute path in settings.json)
- Hook script not executable
- Counter file permissions issue
- stderr output not surfaced in conversation
- Hook causes tool call timeout
