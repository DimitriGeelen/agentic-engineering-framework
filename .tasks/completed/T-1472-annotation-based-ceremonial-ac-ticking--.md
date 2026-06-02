---
id: T-1472
name: "Annotation-based ceremonial AC ticking — replace AGENT_PATTERNS regex with marker-driven detection (OBS-019)"
description: |
  Level D fix for OBS-019. Replace AGENT_PATTERNS regex in
  lib/inception.sh:tick_inception_decide_acs with HTML-comment marker
  detection (`<!-- @auto-tick-on-decide -->`). Keep the regex as a
  fallback for existing tasks. Update inception template to ship with
  markers on ceremonial ACs.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [governance, inception, obs-019, level-d]
components: [lib/inception.sh, tests/unit/inception_tick_marker.bats]
related_tasks: [T-1466, T-1455, T-1444]
created: 2026-04-25T19:36:32Z
last_update: 2026-04-25T19:40:42Z
date_finished: 2026-04-25T19:40:42Z
---

# T-1472: Annotation-based ceremonial AC ticking — replace AGENT_PATTERNS regex with marker-driven detection (OBS-019)

## Context

OBS-019 (captured during T-1466 RCA): `lib/inception.sh:tick_inception_decide_acs` matches "ceremonial" ACs (the ones the decide command itself satisfies — "Problem statement validated", "Recommendation written with rationale", etc.) via regex against AC text. Every new AC wording variant requires extending `AGENT_PATTERNS`. T-1455 GO 500 was the first symptom (custom AC wording wasn't ticked → AC gate blocked → episodic gen failed → endpoint 500'd).

**Level D fix (per CLAUDE.md Error Escalation Ladder):** replace text-pattern matching with annotation-based ticking. Templates declare which ACs are ceremonial via a marker; tick logic reads the marker, not the text.

**Design (rejected alternative):** HTML comment marker `<!-- @auto-tick-on-decide -->` adjacent to each ceremonial AC line. Adjacent placement is self-documenting and survives AC reordering. Rejected: frontmatter list `inception_decide_acs: [1, 2, 3]` — brittle to reordering, divorces the marker from the content it controls, harder to read in raw MD.

**Backwards compatibility:** keep AGENT_PATTERNS regex as fallback for existing inception tasks without markers. New template ships with markers; old tasks still tick.

## Acceptance Criteria

### Agent
- [x] `tick_inception_decide_acs` reads `<!-- @auto-tick-on-decide -->` markers and ticks every AC line that has the marker on its line or the line above
- [x] AGENT_PATTERNS regex retained as fallback (covers existing tasks without markers)
- [x] `.tasks/templates/inception.md` updated: ceremonial ACs gain `<!-- @auto-tick-on-decide -->` markers
- [x] Bats regression: synthesize task with markered ACs (one with non-standard wording the regex would NOT match), run `tick_inception_decide_acs`, assert all markered ACs are ticked
- [x] Bats regression: synthesize task WITHOUT markers but with regex-matching wording, assert fallback still ticks them
- [x] Existing `tests/unit/lib_inception.bats` and `tests/unit/inception_tick_decision_recorded.bats` pass with no regression (28/28)

## Verification

cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/lib_inception.bats tests/unit/inception_tick_decision_recorded.bats tests/unit/inception_tick_marker.bats >/dev/null

## Decisions

### 2026-04-25 — marker placement
- **Chose:** HTML comment `<!-- @auto-tick-on-decide -->` on the AC line or directly above
- **Why:** adjacent to the content it controls; survives reordering; visible in raw MD; doesn't render in Watchtower (HTML comments stripped)
- **Rejected:** frontmatter list `inception_decide_acs: [1, 2, 3]` — brittle to reordering; divorced from content; requires renumbering on AC insertion
- **Rejected:** YAML field per AC — over-engineered

## Updates

### 2026-04-25T19:36:32Z — task-created [task-create-agent]
- **Action:** Created via fw inception start, then converted to build (bounded design space)

### 2026-04-25T19:38:00Z — status-update [task-update-agent]
- **Change:** workflow_type: inception → build

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a8f08cd5
- **Timestamp:** 2026-06-02T14:57:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 1
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/lib_inception.bats tests/unit/inception_tick_decision_recorded.bats tests/unit/inception_tick_marker.bats >/dev/null`
### 2026-04-25T19:40:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
