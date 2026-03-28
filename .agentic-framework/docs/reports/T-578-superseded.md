# T-578: PostToolUse Loop Detection (SUPERSEDED)

Already built in T-594. Production implementation: `lib/ts/src/loop-detect.ts`

3 detectors: generic_repeat, ping_pong, no_progress. SHA256 hashing, warn at 5, block at 10.
