# T-1151: Watchtower Truncation Audit

**Date:** 2026-04-12
**Scope:** All slice operations (`[:N]`, `.split()[:N]`), length caps, and explicit truncation in `web/blueprints/*.py`

## Classification Key

| Category | Meaning | Risk |
|----------|---------|------|
| **display-only** | Truncated value is rendered in HTML/UI only — never flows into forms, APIs, or `fw` commands that write to task files | Safe |
| **write-through** | Truncated value flows into a form pre-fill, API payload, or `fw` CLI argument that writes to a permanent record (task file, decision log, YAML store) | **Unsafe** |
| **error-display** | Truncated stderr/stdout shown in error messages — never persisted | Safe |
| **file-identity** | Hash/slug slicing for filenames or IDs — not content truncation | Safe |
| **list-cap** | Limits number of items returned (e.g., `[:20]`) — not content truncation | Safe |

## Findings

### approvals.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 74 | `resolved[:20]` | list-cap | Safe | Caps resolved approvals to last 20 for display |
| 122 | `problem.split("\n")[:2]` | display-only | Safe | `problem_excerpt` — shown in approval cards, not written back |
| 125 | `problem_excerpt[:197] + "..."` | display-only | Safe | Same `problem_excerpt` for card display |
| 141-146 | `rationale_hint` — NO truncation | _(fixed by T-1150)_ | Safe | Comment documents the fix; pre-fill is now full-length |
| 317 | `command_hash[:12]` | file-identity | Safe | Hash prefix for filename — not content |
| 344 | `command_hash[:12]` | file-identity | Safe | Same pattern, resolved file |
| 392 | `result.stderr[:100]` | error-display | Safe | Error message in batch-complete HTML response |
| 394 | `str(e)[:100]` | error-display | Safe | Exception message in batch-complete HTML response |

### inception.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 116 | `" ".join(rec_lines)[:300]` | display-only | Safe | `_recommendation` field for list-view batch review (T-959). Only rendered in inception list table. |
| 119 | `rec_lines[:3]` | display-only | Safe | Scans first 3 lines for GO/NO-GO/DEFER keyword extraction |
| 221-225 | `rationale_hint` — NO truncation | _(fixed by T-1091/T-1150)_ | Safe | Comment documents the fix; detail page pre-fill is full-length |
| 317 | `(stderr or stdout)[:200]` | error-display | Safe | htmx error response fragment |

### cockpit.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 141 | `[:3]` on `top_tasks` | list-cap | Safe | Top 3 tasks for human verification widget |
| 173 | `[:3]` on `needs_decision` | list-cap | Safe | Top 3 scan recommendations |
| 175 | `[:3]` on `framework_recommends` | list-cap | Safe | Top 3 scan recommendations |
| 177 | `[:3]` on `opportunities` | list-cap | Safe | Top 3 scan opportunities |
| 213 | `stderr[:300]` | error-display | Safe | Scan failure error message |
| 242 | `rec.get("summary", rec_id)[:100]` | error-display | Safe | Success confirmation — HTML-only, action already executed via `run_fw_command` |
| 243 | `stderr[:200]` | error-display | Safe | Action failure error message |
| 272 | `rec.get("summary", rec_id)[:100]` | display-only | Safe | Deferred confirmation message |
| 295 | `rec.get("summary", rec_id)[:100]` | display-only | Safe | Applied confirmation message |
| 296 | `stderr[:200]` | error-display | Safe | Apply failure error message |
| 309 | `stderr[:200]` | error-display | Safe | Focus failure error message |

### tasks.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 470 | `(stderr or stdout)[:200]` | error-display | Safe | Task create error |
| 487 | `(stderr or stdout)[:200]` | error-display | Safe | Horizon update error |
| 502 | `(stderr or stdout)[:200]` | error-display | Safe | Owner update error |
| 518 | `(stderr or stdout)[:200]` | error-display | Safe | Type update error |
| 536 | `(stderr or stdout)[:200]` | error-display | Safe | Complete task error |
| 552 | `(stderr or stdout)[:200]` | error-display | Safe | Status update error |

### discovery.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 57 | `cols[2][:120]` | display-only | Safe | Architectural decision text from `005-DesignDirectives.md` — display table only |
| 71 | `d.get("decision", "")[:120]` | display-only | Safe | Operational decision text for display table |
| 192 | `[:8]` on saved answers list | list-cap | Safe | Last 8 saved Q&A files |
| 196 | `title[:80]` | display-only | Safe | Saved answer title in sidebar list |
| 336 | `[:60]` on slug | file-identity | Safe | Slug for Q&A filename generation |
| 399 | `[:60]` on slug | file-identity | Safe | Slug for conversation filename |
| 421 | `title[:120]` | **write-through** | **Medium** | Conversation title written to `.context/qa/conversations/*.json`. Truncation silently shortens the saved title vs. the original. |
| 459 | `[:20]` on conversation files | list-cap | Safe | Last 20 conversations in list |

### session.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 127 | `error_msg[:300]` | error-display | Safe | Hook execution error |
| 158 | `error_msg[:300]` | error-display | Safe | Command error |
| 171 | `stdout[:500]` | error-display | Safe | Command output preview |
| 178 | `error_msg[:500]` | error-display | Safe | Error preview |
| 199 | `output[:3000]` | error-display | Safe | Full output preview in details block |

### timeline.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 70-75 | `_truncate(text, max_len=100)` | display-only | Safe | Helper function for narrative display text |
| 100 | `first_ts[:16]`, `last_ts[:16]` | display-only | Safe | Timestamp formatting in timeline narrative |
| 160 | `_truncate(narrative)` | display-only | Safe | Timeline event short narrative |

### metrics.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 113 | `f.stem[:5]` | display-only | Safe | Fallback task ID from filename stem |
| 114 | `fm.get("name", "")[:40]` | display-only | Safe | Task name for metrics display only |

### fabric.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 220-221 | `lines[:2000]` + truncation notice | display-only | Safe | Source code preview in component detail — read-only display |
| 298 | `desc[:77] + "..."` | display-only | Safe | Subsystem description for overview |

### docs.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 81 | `purpose[:100] + "..."` | display-only | Safe | Component purpose in docs listing |

### enforcement.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 74 | `entries[:20]` | list-cap | Safe | Last 20 enforcement log entries |

### costs.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 36 | `session[:8]` | file-identity | Safe | Session hash prefix for display ID |
| 124 | `[:10]` on timestamp | display-only | Safe | Extract date portion from ISO timestamp |
| 154 | `[:10]` on dates | display-only | Safe | Date range formatting |

### settings.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 181 | `models[:5]` | list-cap | Safe | First 5 models from provider API |

### quality.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 153 | `detail[:3000] + "\n... (truncated)"` | display-only | Safe | Test failure details in HTML output |

### core.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 26 | `f.stem[:5]` | display-only | Safe | Fallback task ID |
| 28 | `fm.get("name", "")[:40]` | display-only | Safe | Task name for alert ticker |
| 40 | `c.get("title", "")[:50]` | display-only | Safe | Concern title for alert ticker |
| 51 | `[:3]` on handovers | list-cap | Safe | Last 3 handovers for recent activity |
| 170 | `fm.get("name", "")[:50]` | display-only | Safe | Current focus task name |
| 421 | `f.read_text()[:800]` | display-only | Safe | Header preview for episodic file listing |
| 424 | `m.group(1)[:60]` | display-only | Safe | Task name from episodic header |

### cron.py

| Line | Pattern | Category | Risk | Notes |
|------|---------|----------|------|-------|
| 141 | `files[:5]` | list-cap | Safe | First 5 log files per cron job |

## Summary

| Category | Count | Status |
|----------|-------|--------|
| display-only | 24 | Safe — no action needed |
| error-display | 18 | Safe — transient error messages |
| list-cap | 11 | Safe — pagination/limiting |
| file-identity | 6 | Safe — hash/slug slicing |
| write-through | **1** | **Needs review** |
| fixed (T-1150) | 2 | Already remediated |

**Total truncation sites audited: 62**

## Write-Through Finding

### discovery.py:421 — Conversation title truncation

```python
"title": title[:120],
```

**Data flow:** User-provided conversation title -> `title[:120]` -> written to `.context/qa/conversations/*.json` -> reloaded and displayed in conversation list.

**Impact:** Low-medium. The truncated title is persisted as the permanent record. If the user's original title exceeded 120 characters, the saved version is silently shorter. However:
- 120 characters is generous for a title (longer than a tweet)
- The original question is preserved separately in `final_question` and `history` fields
- This is a Q&A artifact, not a governance record

**Recommendation:** Accept as-is OR add a `full_title` field alongside the truncated display title. Not urgent.

## Recommendations

1. **No urgent action required.** The T-1150 fix correctly addressed the only high-risk write-through (approval rationale pre-fill). All remaining truncation sites are display-only, error-display, list-caps, or file-identity slicing.

2. **discovery.py:421** is the only remaining write-through. Consider preserving the full title or documenting the 120-char cap as intentional. Low priority.

3. **Pattern established:** The codebase correctly separates display concerns from write concerns. The `rationale_hint` pattern in both `approvals.py` and `inception.py` now has explicit comments (T-1091, T-1150) documenting why truncation was removed. This is the right approach.

4. **Guard against regression:** Any new form pre-fill or API write path should be reviewed for truncation. The risk pattern is: read from task file -> truncate for display -> use truncated value as form default -> human submits -> truncated value written back. This is the exact pattern T-1150 caught.
