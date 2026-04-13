# T-1129: 4 Learnings from TermLink Session (010-termlink T-944)

**Status:** GO
**Date:** 2026-04-12

## Problem Statement

4 learnings from cross-project 010-termlink session needed evaluation and capture:
- PL-003: Subagent scope violation (agents editing files outside their project)
- PL-004: Format convention assumptions (YAML vs JSON)
- PL-005: Stale gaps auto-closure (concerns.yaml entries persisting after resolution)
- PL-006: Dog-food Watchtower (use own tooling for review, not raw CLI)

## Findings

All 4 learnings captured (L-002 through L-005 in learnings.yaml).
2 of 4 warranted structural fixes:
- PL-003 already addressed by project boundary hook (check-project-boundary.sh)
- PL-006 partially addressed by T-1119/T-1120 (fw task review command)

## Decision

**GO** — All learnings captured. PL-003 and PL-006 have structural prevention.
PL-004 and PL-005 remain advisory learnings.
