---
id: T-1290
name: "Rewrite _watchtower_url as 3-layer discovery (T-1284 B3)"
description: >
  Rewrite _watchtower_url as 3-layer discovery (T-1284 B3)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-17T20:27:14Z
last_update: 2026-04-17T20:27:14Z
date_finished: null
---

# T-1290: Rewrite _watchtower_url as 3-layer discovery (T-1284 B3)

## Context

B3 of T-1284 (the actual bug fix). Replace the 4-fallback port probe
in `_watchtower_url` (which picked :8080/Open WebUI when it answered
arbitrary paths) with a 3-layer discovery that is deterministic and
safe:

1. **Layer 1 — triple:** Read `.pid/.port/.url` (written by B2).
   Verify pid alive + verify pid listens on that port. Return url.
2. **Layer 2 — identity:** For configured port(s), call
   `/api/_identity` (B1). Match only if `service=="watchtower"` AND
   `project_root` equals our project root. Return matching url.
3. **Layer 3 — fail loud:** No match → stderr message + exit 1.
   No arbitrary port probing, no task-path probing.

Preserves existing public signature: stdout URL on success, exit 1
on failure. `WATCHTOWER_URL` env override still respected.

## Acceptance Criteria

### Agent
- [x] When valid triple exists + pid alive + identity matches:
      `_watchtower_url` returns the `.url` contents without probing
- [x] When triple is missing/stale: falls through to Layer 2 identity
      handshake; returns matching url only when `service==watchtower`
      AND `project_root` equals current project root
- [x] When no Watchtower reachable: writes actionable error to stderr
      ("No Watchtower reachable. Start one with: fw serve" or similar)
      and exits non-zero — does NOT return a URL to a masquerader
- [x] Existing `WATCHTOWER_URL` env var still takes precedence
      (fast path unchanged)
- [x] With Open WebUI (:8080) running + Watchtower NOT running,
      function exits non-zero (never returns :8080). This is the
      T-1284 regression test. (Verified by simulating stale PID
      + wrong config port; function returned exit 1 with no url.)

## Verification

# With Watchtower up + triple present, url comes from triple.
URL=$(source lib/watchtower.sh && _watchtower_url) && echo "url=$URL"
test "$URL" = "$(cat .context/working/watchtower.url)"

# Identity handshake confirms it IS watchtower, not a masquerader.
curl -sf --max-time 3 "$URL/api/_identity" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['service']=='watchtower' and d['project_root']=='$PWD', d; print('identity ok')"

# Regression: even if we point WATCHTOWER_URL at the wrong port, env wins fast-path.
WATCHTOWER_URL=http://example.invalid:9999 bash -c 'source lib/watchtower.sh; _watchtower_url' | grep -q '^http://example.invalid:9999$' && echo "env precedence ok"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-17T20:27:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1290-rewrite-watchtowerurl-as-3-layer-discove.md
- **Context:** Initial task creation
