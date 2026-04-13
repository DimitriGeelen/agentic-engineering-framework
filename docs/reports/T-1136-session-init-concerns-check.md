# T-1136: Upstream Session-Init Concerns Check

**Status:** GO
**Date:** 2026-04-12

## Problem Statement

010-termlink independently implemented a session-init concerns check.
On `fw context init`, the agent reads `concerns.yaml` and displays open gaps
with ID, title, and age. This prevents cross-session failure blindness.

## Findings

- `concerns.yaml` is available at init time (project-level file)
- Current `fw context init` shows pass/warn/fail counts but not individual gaps
- The patch adds 3 lines to init output showing open concerns
- Low risk: read-only display, no state mutation

## Decision

**GO** — Upstream the concerns-at-init display. Separate build task for implementation.
Simple, low-risk enhancement that prevents agents from starting sessions
unaware of known structural problems.
