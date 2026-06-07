# T-2098: fw upgrade — playwright test step MCP-aware fallback

**Status:** inception (research artifact, C-001)
**Filed:** 2026-05-29
**Sibling:** T-2097 (seed-files merge strategy)
**Parent cluster:** T-2078 (fw upgrade reliability)

---

## Problem Statement

`fw test playwright` (and the upgrade flow that calls it) emits this when neither project nor framework has `tests/playwright/`:

```
SKIP: no tests/playwright/ found in project or framework
```

Location: `bin/fw:6267`. The block above it (`bin/fw:6262-6266`) handles the **pip-package-missing** case actionably ("Install: pip install playwright pytest-playwright && playwright install chromium"). The tests-missing case is dead-silent: the user gets no diagnosis, no install offer, no actionable next step.

**Failure mode:** consumers that have Playwright MCP installed (every consumer in the fleet does — it's in the recommended MCP server set, `lib/upgrade.sh:964`) **silently skip UI regression testing**. The consumer may have full ability to run Playwright tests (npm MCP + pip pytest-playwright); they just don't have a tests folder yet. The framework knows this is the common case and never offers to scaffold or initialize.

**Why structurally allowed:** the SKIP path was written defensively ("if we can't run it, don't fail") but lost the opportunity to bridge the gap. The script doesn't probe what the consumer DOES have — only what it doesn't.

**User intent (quoted):**

> "we know they all have playwright MCP, and if not should install playwright (check mcp first if not suggests to install y/n)"

---

## Scope Fence

**In scope:**
- Probe for the Playwright MCP (`@playwright/mcp` npm package + `.mcp.json` `playwright` entry).
- If MCP present but `tests/playwright/` absent → offer to scaffold a minimal `tests/playwright/` (conftest + one smoke test) y/n.
- If MCP absent → offer to install (`npx @playwright/mcp@latest` or instruct user to add to `.mcp.json`) y/n.
- Only SKIP as a last resort with a clear diagnostic of what was probed and what was found.

**Out of scope (other arcs):**
- Generalising the y/n install pattern to all SKIP paths in `bin/fw test` (could become a follow-up if signal warrants).
- Browser binary management (Playwright's own `playwright install chromium`) — already handled by the pip-missing block.
- MCP server lifecycle (start/stop/restart) — that's TermLink/MCP infrastructure, not the test step's concern.

---

## Candidate Strategies

### A. Probe-then-prompt (matches user intent literally)

`fw test playwright` step:
1. Check `tests/playwright/` exists → if yes, current happy path.
2. Check pip `playwright` importable → if no, current pip-missing message.
3. Check Playwright MCP available (probe `.mcp.json` for `playwright` entry AND check `npx @playwright/mcp@latest --version` succeeds) → record `mcp_ok=1/0`.
4. If `mcp_ok=1` AND no `tests/playwright/`: prompt "Playwright MCP detected. Scaffold minimal tests/playwright/? [y/N]".
5. If `mcp_ok=0` AND no `tests/playwright/`: prompt "Playwright MCP not detected. Install (`npx @playwright/mcp@latest`) and re-run? [y/N]".
6. SKIP only if both probes fail AND user declined.

**Pros:** matches user request 1:1. Actionable at every branch.
**Cons:** interactive prompt — needs to handle non-TTY (CI/cron) gracefully (default to N + clear message).

### B. Auto-scaffold on MCP-detect

Same as A, but when MCP is detected and tests are absent, automatically create a minimal `tests/playwright/` skeleton (no prompt) and run it. SKIP only if MCP missing.

**Pros:** zero-friction; consumer immediately gets baseline UI test coverage.
**Cons:** writes files without consent; may not match the consumer's preferred test layout.

### C. Diagnostic SKIP (no prompt, just better message)

Probe MCP + pip + tests-folder; emit a structured diagnostic of what was found and a single copy-pasteable command to fix the gap. Always SKIP.

**Pros:** no interaction model needed; works in CI.
**Cons:** still SKIPs by default — same root failure mode as today, just with prettier explanation.

---

## Decision Criteria

A GO answer should specify:
1. Which strategy (A/B/C)
2. Non-TTY behaviour (CI/cron) — default = no install
3. What "scaffold minimal tests/playwright/" looks like (conftest.py + one smoke test against the consumer's `/health` endpoint? Or just an empty folder + README?)
4. How MCP availability is probed (.mcp.json parse vs `npx` invocation vs both)
5. Failure mode if user says Y but install/scaffold fails (clear error, exit non-zero, don't silently SKIP)

---

## Recommendation

**Recommendation:** GO with **Strategy A (probe-then-prompt)** + explicit non-TTY handling.

**Rationale:**
- Matches user intent verbatim ("check mcp first if not suggests to install y/n").
- Asks before writing files — respects consumer's project layout.
- Non-TTY case (CI) falls through to diagnostic SKIP, so the behaviour in automated contexts stays current — only interactive sessions get the upgrade.
- The probe logic is small (~30 lines) and self-contained in `bin/fw:6252-6272`.

**Evidence supporting GO:**
- Every consumer in the fleet already has Playwright MCP installed (`.mcp.json` includes `playwright` by default since T-866).
- The pip-missing block already proves the actionable-SKIP pattern works (it gives a copy-pasteable install line).
- Inverse case (consumer has tests but no MCP) is already correctly handled by the existing path.
- The gap is the **MCP-present-but-no-tests** quadrant — the most common case in the fleet.

**Suggested follow-ups (on GO):**
- T-2098-V1: MCP probe helper (read `.mcp.json`, check for `playwright` entry, optionally invoke `npx @playwright/mcp@latest --version` with 3s timeout).
- T-2098-V2: scaffold helper — creates `tests/playwright/conftest.py` + `tests/playwright/test_smoke.py` (health check against project's web URL). Idempotent.
- T-2098-V3: wire probe + scaffold into `bin/fw test playwright` step. Non-TTY → diagnostic SKIP, TTY → y/n prompt.
- T-2098-V4: bats coverage — fixture with MCP + no tests, run step, confirm scaffold offered. Non-TTY fixture confirms diagnostic SKIP.

**Rejected alternatives:**
- B (auto-scaffold) — writes files without consent; risks conflict with consumer's preferred layout.
- C (diagnostic SKIP only) — preserves the silent-SKIP root failure; user explicitly asked for the install prompt.

---

## Dialogue Log

Inception filed in response to user follow-up during fw upgrade evaluation:

> "also incept better strategy for SKIP: no tests/playwright/ found in project or framework, as we know they all have playwright MCP, and if not should install playwright (check mcp first if not suggests to install y/n)"

Agent eval: this is the **same class** of failure as T-2097 (silent SKIP where the framework actually has information to act). Filed as separate inception per "one inception = one question" — the seed-files merge (T-2097) and the playwright probe (T-2098) have independent goals, separate implementations, and could land on different GO decisions.
