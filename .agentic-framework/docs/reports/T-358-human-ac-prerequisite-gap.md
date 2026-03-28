# T-358: Human AC Prerequisite Gap — Research

**Date:** 2026-03-09
**Method:** Survey of active task Human ACs + CLAUDE.md analysis

---

## Problem

T-325 established Human AC format (Steps/Expected/If-not), but doesn't address **deployment prerequisites**. Human ACs assume code is already deployed/available. Example: T-357 said "run `fw init` in temp dir" without "first `brew upgrade fw`."

## Evidence

Survey of 5 active tasks with Human ACs:

| Task | Has Deployment Prereqs? | Self-Contained? |
|------|---|---|
| T-332 (awesome-lists) | No | No — "PRs submitted" with no steps |
| T-336 (Reddit post) | No | Partial — lacks steps/expected |
| T-365 (Watchtower docs) | Partial | Yes — RUBBER-STAMP with full format |
| T-361 (Fabric docs) | Partial | Yes — RUBBER-STAMP with full format |
| T-334 (Launch sequence) | No | No — steps present but missing deployment context |

**Pattern:** Tasks created after T-325 (T-361, T-365) follow the format well. Tasks created before or outside the doc system (T-332, T-336, T-334) don't.

## What T-325 Covers vs. What's Missing

**Covered:** Steps + Expected + If-not format, confidence markers, "if a human AC cannot be made specific, replace or remove it"

**Missing:**
- Guidance on prerequisite discovery (what needs to be deployed/installed first?)
- Pattern for distributed software testing (package manager path vs. local dev)
- Acknowledgment that "Steps" should start from the human's actual starting state, not the agent's assumed state

## Proposed Fix

Add one clause to the T-325 format requirements in CLAUDE.md:

> **Prerequisite awareness:** Steps must start from the human's actual environment, not the agent's dev context. If the feature requires deployment (package upgrade, server restart, config push), include those steps first. Ask: "What must the human do before step 1 is possible?"

This is additive to T-325 — no structural changes needed.

## Go/No-Go Assessment

**GO** — The fix is a one-paragraph addition to CLAUDE.md. No new tooling, no structural changes. Evidence from 5 tasks shows the gap is real (3/5 missing prerequisites).

**NO-GO criteria not met:**
- Not too complex (single paragraph)
- Not already solved (T-325 covers format, not prerequisites)
- Not speculative (concrete evidence from task survey)
