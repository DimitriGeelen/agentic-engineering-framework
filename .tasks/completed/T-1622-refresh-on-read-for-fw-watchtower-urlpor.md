---
id: T-1622
name: "Refresh-on-read for fw watchtower url/port — fix stale LAN IP from DHCP rotation
  (T-1621 GO)"
description: >
  Refresh-on-read for fw watchtower url/port — fix stale LAN IP from DHCP rotation
  (T-1621 GO)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-30T19:13:12Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-04-30T19:16:14Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1622: Refresh-on-read for fw watchtower url/port — fix stale LAN IP from DHCP rotation (T-1621 GO)

## Context

Build follow-up to T-1621 (GO). Implement refresh-on-read for `bin/fw watchtower url`: when Watchtower is running, regenerate the LAN URL from `detect_lan_ip` instead of reading the cached `watchtower.url` file. The file remains as fallback for the stopped state. `do_port` does not change — DHCP rotation does not change the listening port. `do_status` already uses fresh `detect_lan_ip` (`bin/watchtower.sh:252`), no change needed there.

## Acceptance Criteria

### Agent
- [x] `do_url` (`bin/watchtower.sh:292`) regenerates LAN URL from `detect_lan_ip` when `is_running` is true; falls back to cached `URL_FILE` when stopped; falls back to `localhost:$port` when neither is available — `bin/watchtower.sh:292-313` post-T-1622
- [x] `do_port` is unchanged — DHCP rotation does not affect port (verified by argument: port is process-bound, IP is interface-bound)
- [x] Bats test pins the contract: running + IP-bouncing scenario asserts `do_url` returns current `detect_lan_ip`-derived value, NOT the stale file content — `tests/unit/watchtower_url_refresh.bats` 8/8 pass; case 5 plants stale `.123:3000` file, asserts `do_url` returns fresh `.107:3000`
- [x] Existing `bin/fw watchtower port|url` callers still work — no signature change, just a fresher answer when applicable — verified end-to-end: stale-file plant test confirmed `fw watchtower url` returns fresh value
- [x] `bash -n bin/watchtower.sh` parses

### Human
<!-- Removed — all criteria agent-verifiable -->

## Verification

# Pin: do_url pulls from detect_lan_ip when running
grep -q "T-1622" bin/watchtower.sh
grep -q "is_running" bin/watchtower.sh
# Bats coverage exists and passes
test -f tests/unit/watchtower_url_refresh.bats
bats tests/unit/watchtower_url_refresh.bats
# Source still parses
bash -n bin/watchtower.sh
# Existing port/url commands still functional
bin/fw watchtower port >/dev/null
bin/fw watchtower url | grep -qE '^https?://'

## RCA

**Symptom:** Every `fw task review T-XXX` URL the agent emitted into chat over a multi-hour window pointed at `192.168.10.123:3000` while the host was actually serving on `192.168.10.107`. The human caught it ("lan is 107") only after attempting to open one of the links from a phone.

**Root cause:** `do_url` in `bin/watchtower.sh:292` read `URL_FILE` verbatim. The file was written exactly once at process start (line 208) using `detect_lan_ip` at *that* moment. NetworkManager DHCP-bounced `enp5s0` between `.123` and `.107` 8 times across the day (journalctl evidence). Each lease change rotated the host IP without restarting Watchtower, so the cached file outlived its truth value. Read-side had no liveness check.

**Why structurally allowed:** The triple-file (port/url/pid) was designed under T-885/T-1287/T-1376 as the single source of truth — any process reads the file, no process probes. That contract is correct for the *port* (process-bound, doesn't rotate) and for the *pid* (immutable for a given process). It was *also* applied to the *url*, which contains an interface-bound LAN IP that rotates independently of Watchtower's lifecycle. Nobody noticed because LXC 170 prod uses a static IP — the dev-laptop-on-DHCP regime was never exercised. No bats test, no `fw doctor` check, no audit rule covered "URL file matches current `detect_lan_ip` while running."

**Prevention:**
1. **Code:** `do_url` now branches on `is_running` and refreshes from `detect_lan_ip` when running (file becomes stopped-state fallback). Multi-line `T-1622` comment in source explains the why.
2. **Test:** `tests/unit/watchtower_url_refresh.bats` 8 cases — including the witness scenario (stale file planted, refresh asserted) — pin the contract so future "let's just cache it again" refactors break red.
3. **Doc trail:** T-1621 inception captures the witness + the design choice (refresh-on-read vs NM dispatcher hook vs cron). Future agents grepping for "watchtower url stale" land on the inception immediately.
4. **Multi-IP-host fragility (`detect_lan_ip` `head -n 1`)**: filed as out-of-scope in T-1621 scope fence. Will be picked up if/when a multi-interface host surfaces a wrong-pick incident — single-witness rule, do not fix speculatively.

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

### 2026-04-30T19:13:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1622-refresh-on-read-for-fw-watchtower-urlpor.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-844f4afb
- **Timestamp:** 2026-06-02T14:58:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 10
     - evidence: `bin/fw watchtower port >/dev/null`
  2. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `test -f tests/unit/watchtower_url_refresh.bats`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 11
     - evidence: `bin/fw watchtower url | grep -qE '^https?://'`
### 2026-04-30T19:16:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
