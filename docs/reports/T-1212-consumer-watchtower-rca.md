# T-1212: RCA — Consumer Watchtower Pages Missing

**Status:** NO-GO (superseded by T-1213)
**Date:** 2026-04-13

## Problem Statement

Consumer Watchtower pages showed: terminal page 404, approvals page bare/broken.
Recurring across all 11 consumer projects after fw upgrade.

## Findings

Investigation revealed this task was scoped incorrectly. The real problem was:
- Inception decision cards on /approvals lacked recommendations, rationale, and context
- The "missing pages" were actually missing *content* on existing pages

## Decision

**NO-GO** — Superseded by T-1213 which correctly scoped the problem as
"inception decision cards show bare radio buttons without context."

T-1213 received GO and was implemented as T-1214.

## Lessons

Wrong scope identification wastes inception effort. When multiple symptoms
appear (404s, bare pages, missing content), investigate all before creating
a task — the root cause may connect them differently than first assumed.
