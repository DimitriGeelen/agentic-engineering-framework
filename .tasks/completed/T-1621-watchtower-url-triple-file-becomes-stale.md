---
id: T-1621
name: "Watchtower URL triple-file becomes stale when host LAN IP changes"
description: >
  Watchtower URL triple-file becomes stale when host LAN IP changes

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-30T19:05:28Z
last_update: '2026-08-16T22:24:39Z'
date_finished: 2026-04-30T19:12:24Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1621: Watchtower URL triple-file becomes stale when host LAN IP changes

## Problem Statement

`bin/watchtower.sh` writes the LAN URL into `.context/working/watchtower.url` once at process start, using `detect_lan_ip` (`bin/watchtower.sh:38`, which is `ip -4 addr show scope global | awk '{print $2}' | head -n 1`). The URL file is the agent-facing source of truth — `bin/fw watchtower url` and downstream consumers (`fw task review` URL emission, handover artefacts, QR codes pasted into chat) all read this file.

**Failure mode observed today (2026-04-30, this host `dimitrimintdev`):** NetworkManager DHCP-bounced `enp5s0` between `192.168.10.123` and `192.168.10.107` eight times across the day (lease changes at 17:17, 17:22, 17:50, 18:37, 19:00, 19:11, 20:55 UTC+02). Watchtower was running across the bounces. The URL file kept its first-write value (`.123`) until the human caught it ("lan is 107") and forced a restart. Every Watchtower link the agent emitted in the interim — review URLs, approval queue, file links — pointed at `.123` and 404'd from any LAN client after the lease moved.

**For whom:** the human (clicking stale links from chat / handover artefacts), and any cron job / consumer-side tooling that reads `watchtower.url` and caches the value.

**Why now:** witnessed firsthand this session. Same class will recur on any laptop, any Wi-Fi roam, any DHCP-renewal IP shuffle, any DNS-failover VPN flap. Single-host LAN tools usually don't notice; agents do because they paste the URL into messages that outlive the lease.

## Assumptions

- A1: `detect_lan_ip` itself is correct — when called fresh after the bounce, it returns the current address (verified: returned `.107` while file held `.123`).
- A2: `bin/watchtower.sh` writes the URL file exactly once (at line 208 in the start path). No periodic refresh, no NetworkManager hook, no on-read regeneration.
- A3: `fw watchtower url` (`bin/watchtower.sh:286-296`) reads the file verbatim with no liveness check.
- A4: Refreshing the URL on every read is cheap (< 5 ms — single `ip -4` call).
- A5: Clients that have already cached the URL (chat messages, QR codes already shown) cannot be retroactively fixed — the win is bounded to *future* reads.
- A6: A NetworkManager dispatcher hook (`/etc/NetworkManager/dispatcher.d/`) would be the correct OS-level fix but adds host-config dependency that doesn't ship with the framework.

## Exploration Plan

- Spike 1 (DONE inline): grep NetworkManager journal to confirm DHCP bouncing is the root cause — confirmed, 8 lease transitions today on this host.
- Spike 2 (DONE inline): inspect `detect_lan_ip` + `bin/fw watchtower url` to confirm read-side does no liveness check — confirmed at `bin/watchtower.sh:286-296`.
- Spike 3: cost-shape the fix candidates (1) refresh-on-read, (2) NM dispatcher hook, (3) periodic cron, (4) bind+advertise hostname — see Recommendation.

## Technical Constraints

- macOS bash 3.2 compat (T-518) — any patch must avoid `declare -A`.
- `detect_lan_ip` is single-IP-aware (`head -n 1`) — picks first global address, no ordering rule. Could pick wrong IP on multi-IP hosts (e.g. wired + Wi-Fi simultaneously). This is a separate fragility but in scope here only as a gotcha to avoid making worse.
- Triple-file is documented in CLAUDE.md as the source-of-truth for the port/url/pid trio (T-885, T-1287, T-1376) — any fix must keep external read semantics ("read the file, don't guess").

## Scope Fence

**IN scope:**
- Decide whether `bin/fw watchtower url` should refresh from `detect_lan_ip` instead of (or in addition to) reading the cached file.
- Decide whether `bin/watchtower.sh` should self-refresh (e.g., on `status`, or periodically).
- Bats coverage to pin the chosen behaviour.

**OUT of scope (deferred):**
- Multi-IP host support — `detect_lan_ip` returning wrong IP when host has multiple global addresses (file as separate task if/when we observe it).
- NetworkManager dispatcher integration — host-OS-specific, not a framework concern.
- Hostname-based URL emission (`http://dimitrimintdev:3000`) — requires DNS or `/etc/hosts` on every client, breaks "open from phone".
- LXC 170 prod Watchtower — has static IP + systemd, not affected.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Root cause is environmental but the framework can mitigate cheaply on the read path.
- Fix scope ≤ 1 file (`bin/watchtower.sh`) plus 1 bats test.
- No regression risk to the triple-file consumers documented in CLAUDE.md.

**NO-GO if:**
- The only correct fix is a NetworkManager / systemd-networkd dispatcher hook (host-OS-specific) — not a framework concern.
- Refresh-on-read introduces latency or non-determinism that breaks `fw doctor` / handover output stability.

**DEFER if:**
- DHCP bouncing is environmental noise on this one host and won't recur for other users — wait for second sighting.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:** Witnessed firsthand this session — the URL file's first-write semantic combined with DHCP IP rotation (8 lease changes today on this host) emitted stale `.123` URLs in chat for hours. The cheapest fix that actually works is to make `bin/fw watchtower url` (and `bin/fw watchtower port` for symmetry) regenerate the LAN URL from `detect_lan_ip` on every read, while keeping the file as a fallback for when the watchtower process is stopped (so we can still surface "where it WAS running"). Cost: ~10 lines in `bin/watchtower.sh` plus a bats test. Bound: read-path only — write semantics unchanged, file remains the documented triple-file. Refresh frequency = on-demand (one `ip -4` call per `fw watchtower url`), so no extra daemon, no NM hook, no cron. Multi-IP-host fragility (`head -n 1` picking wrong interface) is real but separate; flagged as gotcha, deferred to a sibling task if/when observed.

**Evidence:**
- NetworkManager journal `journalctl --since "1 day ago" -u NetworkManager`: 8 lease transitions on `enp5s0` between `192.168.10.123` and `192.168.10.107` over 2026-04-30, last transition at 20:55 UTC+02 to `.107`.
- `bin/watchtower.sh:208`: URL written once via `printf '%s\n' "$url" > "${URL_FILE}.tmp" && mv` at start. No re-emit.
- `bin/watchtower.sh:286-296`: `do_url` reads `URL_FILE` verbatim with no liveness check.
- `bin/watchtower.sh:38-44`: `detect_lan_ip` is `ip -4 addr show scope global | head -n 1` — cheap, fresh per call.
- This session: `cat .context/working/watchtower.url` returned `http://192.168.10.123:3000` while `ip -br addr` showed `enp5s0 192.168.10.107/24` and `detect_lan_ip` returned `.107`. Stale-by-construction.
- `git log --all -p -- .context/working/watchtower.url`: only `.107` ever committed — confirming `.123` was a runtime-write that DHCP outran, never a hand-edit.
- T-885 / T-1287 / T-1376 (Watchtower port resolution discipline) already established the triple-file as authoritative; this fix preserves that contract on the write side and adds a thin liveness check on the read side.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Witnessed firsthand this session — the URL file's first-write semantic combined with DHCP IP rotation (8 lease changes today on this host) emitted stale `.123` URLs in chat for hours. The cheapest fix that actually works is to make `bin/fw watchtower url` (and `bin/fw watchtower port` for symmetry) regenerate the LAN URL from `detect_lan_ip` on every read, while keeping the file as a fallback for when the watchtower process is stopped (so we can still surface "where it WAS running"). Cost: ~10 lines in `bin/watchtower.sh` plus a bats test. Bound: read-path only — write semantics unchanged, file remains the documented triple-file. Refresh frequency = on-demand (one `ip -4` call per `fw watchtower url`), so no extra daemon, no NM hook, no cron. Multi-IP-host fragility (`head -n 1` picking wrong interface) is real but separate; flagged as gotcha, deferred to a sibling task if/when observed.

Evidence:
- NetworkManager journal `journalctl --since "1 day ago" -u NetworkManager`: 8 lease transitions on `enp5s0` between `192.168.10.123` and `192.168.10.107` over 2026-04-30, last transition at 20:55 UTC+02 to `.107`.
- `bin/watchtower.sh:208`: URL written once via `printf '%s\n' "$url" > "${URL_FILE}.tmp" && mv` at start. No re-emit.
- `bin/watchtower.sh:286-296`: `do_url` reads `URL_FILE` verbatim with no liveness check.
- `bin/watchtower.sh:38-44`: `detect_lan_ip` is `ip -4 addr show scope global | head -n 1` — cheap, fresh per call.
- This session: `cat .context/working/watchtower.url` returned `http://192.168.10.123:3000` while `ip -br addr` showed `enp5s0 192.168.10.107/24` and `detect_lan_ip` returned `.107`. Stale-by-construction.
- `git log --all -p -- .context/working/watchtower.url`: only `.107` ever committed — confirming `.123` was a runtime-write that DHCP outran, never a hand-edit.
- T-885 / T-1287 / T-1376 (Watchtower port resolution discipline) already established the triple-file as authoritative; this fix preserves that contract on the write side and adds a thin liveness check on the read side.

**Date**: 2026-04-30T19:12:24Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-30T19:12:24Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Witnessed firsthand this session — the URL file's first-write semantic combined with DHCP IP rotation (8 lease changes today on this host) emitted stale `.123` URLs in chat for hours. The cheapest fix that actually works is to make `bin/fw watchtower url` (and `bin/fw watchtower port` for symmetry) regenerate the LAN URL from `detect_lan_ip` on every read, while keeping the file as a fallback for when the watchtower process is stopped (so we can still surface "where it WAS running"). Cost: ~10 lines in `bin/watchtower.sh` plus a bats test. Bound: read-path only — write semantics unchanged, file remains the documented triple-file. Refresh frequency = on-demand (one `ip -4` call per `fw watchtower url`), so no extra daemon, no NM hook, no cron. Multi-IP-host fragility (`head -n 1` picking wrong interface) is real but separate; flagged as gotcha, deferred to a sibling task if/when observed.

Evidence:
- NetworkManager journal `journalctl --since "1 day ago" -u NetworkManager`: 8 lease transitions on `enp5s0` between `192.168.10.123` and `192.168.10.107` over 2026-04-30, last transition at 20:55 UTC+02 to `.107`.
- `bin/watchtower.sh:208`: URL written once via `printf '%s\n' "$url" > "${URL_FILE}.tmp" && mv` at start. No re-emit.
- `bin/watchtower.sh:286-296`: `do_url` reads `URL_FILE` verbatim with no liveness check.
- `bin/watchtower.sh:38-44`: `detect_lan_ip` is `ip -4 addr show scope global | head -n 1` — cheap, fresh per call.
- This session: `cat .context/working/watchtower.url` returned `http://192.168.10.123:3000` while `ip -br addr` showed `enp5s0 192.168.10.107/24` and `detect_lan_ip` returned `.107`. Stale-by-construction.
- `git log --all -p -- .context/working/watchtower.url`: only `.107` ever committed — confirming `.123` was a runtime-write that DHCP outran, never a hand-edit.
- T-885 / T-1287 / T-1376 (Watchtower port resolution discipline) already established the triple-file as authoritative; this fix preserves that contract on the write side and adds a thin liveness check on the read side.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9a7c213e
- **Timestamp:** 2026-06-02T14:58:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-30T19:12:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
