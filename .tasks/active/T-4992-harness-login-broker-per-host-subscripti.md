---
id: T-4992
name: "Harness login broker: per-host subscription login approved in the operator's browser (ring20-management T-2582)"
description: >
  proxmox-ring20-management (msg 3447897a, operator request). Need: agents on other hosts need their OWN subscription login per harness (Claude, Codex, Antigravity, Mistral, Z.AI); today: copied desktop logins (shared refresh tokens; Codex invalidated the first host), API keys (billing; operator is subscription-only), or typing in a terminal. Requirements R1 one operator approval in his browser, nothing to copy; R2 login made on the target host, never copied; R3 no secret through chat/argv/logs/push (fingerprint only); R4 login into a scratch home, swap only after a real prompt answered; R5 failure leaves the old login intact; R6 harness-neutral (device-code and paste-code flows). Working instances at ring20: codex device-code with scratch CODEX_HOME and swap-on-success; Antigravity via pty with a one-shot LAN approval page. Ask: a framework surface such as fw login <harness> --host <target> with the approval page in Watchtower. They will send both scripts and edge cases.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-11-01T22:11:28Z
last_update: 2026-11-01T22:11:28Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
---

# T-4992: Harness login broker: per-host subscription login approved in the operator's browser (ring20-management T-2582)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->
Agents on other hosts need their own subscription login per harness. Copying a desktop login, using an API key, or typing in a terminal are each a bad answer (description; ring20-management msg 3447897a).

**Evidence from ring20-management (msg e6a22976, 2026-11-01):**
- **Scripts** (on their OneDev, master): `scripts/agy-node1-login.py` and `scripts/codex-node1-login.py`. The codex one uses a scratch CODEX_HOME and swaps only on success, locks against concurrent logins, and pushes to the phone on failure.
- **Edge cases:**
  1. pty driving through ssh/incus with select and ANSI stripping; menus detected by their text;
  2. the TUI wraps a 600-character OAuth URL and inserts spaces; fixed with `stty cols 4000` and a regex over the buffer with CR/LF removed;
  3. block-buffered stdout hid the "open this link" line; fixed with line buffering;
  4. the operator does not use phone links, only a page on screen;
  5. agy finds its login through $HOME, and uses the token file when there is no keyring;
  6. `codex login` deletes the old login before it has a new one, so never log in on the live home.
- **Weakness today (their own analysis):** the one-shot code page is served by the script on the LAN: random port and path, no TLS, no auth, one POST, 15 minutes. The pointer to it is a fixed, unauthenticated Watchtower static URL. Nothing proves the POST came from the operator.
  - Anyone on the LAN can deny the login (the old login stays intact).
  - Worse, anyone can post an authorization code from **their own** Google sign-in, so the host is logged into the wrong account. PKCE does not stop this.
- **Their mitigations:**
  1. compare the token's account email with the expected account before the swap;
  2. a random page name, removed on first view;
  3. for a framework surface: the page served by Watchtower behind its own session/auth, with a CSRF token, and the operator shown the account that will be stored before the swap.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

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

**Recommendation:** DEFER

**Rationale:** Proposal received; touches subscription credentials on remote hosts, so the operator decides whether AEF owns it; ring20 offers two working scripts and edge cases as evidence.

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
