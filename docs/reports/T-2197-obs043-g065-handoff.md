# T-2197 — OBS-043 Handoff: G-065 Cascade Closure

**Status:** Ready for operator action. Sovereignty preserved — agent has surfaced; operator decides.

**Pattern:** Same as T-2184's OBS-048 handoff doc (G-064 readiness). Mechanical
state survey, class-correct URLs, evidence checklist; agent does not flip
gap status or tick Human ACs autonomously.

---

## Cascade summary

```
T-1702 (boundary hook extend)  ──┐
                                  ├─→ G-065 (boundary hook read-blind)
T-1707 (fw doctor scope tagging)──┘
```

- **T-1702** "Boundary hook: extend to outside-path arguments + scope-tag fw doctor findings"
  - Status: `work-completed` (2026-05-31T18:14:08Z), `owner: human`
  - Originally had 3 Agent ACs (#5/#6/#7) deferred to T-1707; T-1707 shipped before T-1702 closed, so the deferred ACs landed.
- **T-1707** "fw doctor scope tagging — split project vs host findings (T-1702 Stream 2)"
  - Status: `work-completed` (2026-05-27T05:51:09Z), `owner: human`
  - Body claims "Closes G-065".
- **G-065** in `.context/project/concerns.yaml:1879` — `status: watching`, `closed_date:` not set. Still open despite both closing-evidence tasks shipping.

The cascade is structurally complete; the gap-register state is the trailing
indicator that hasn't caught up.

---

## Per-task Human AC state

Each task has exactly one unticked `### Human` AC (verified via `grep -c "^- \[ \]"`).

### T-1702 — `[REVIEW]`

> Allowlist captures the right balance — strict enough to catch cross-project
> violations, permissive enough not to break normal shell hygiene.

**Steps (from task body):**
1. Review allowlist diff in `agents/context/check-project-boundary.sh`
2. Try a representative session: editing files, running tests, checking logs
3. Note any false positives (legitimate command blocked) or false negatives (cross-boundary access slipping through)

**Expected:** No false positives in normal work; cross-project access blocked.

**Review URL:** http://192.168.10.107:3000/review/T-1702

### T-1707 — `[REVIEW]`

> Output reads correctly — host-level warnings unambiguous, project warnings still clean.

**Steps (from task body):**
1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor 2>&1 | head -80`
2. Look for `[host]` tags on findings that need attention from `/root` session
3. Check summary line if host count > 0

**Expected:** `[host]` only appears on machine-level findings (not project ones).

**Review URL:** http://192.168.10.107:3000/review/T-1707

---

## G-065 status flip recommendation

**Current state:** `status: watching` (concerns.yaml:1916). No `closed_date`.

**Source of truth — verbatim from G-065 description:**

> `agents/context/check-project-boundary.sh` (PreToolUse on Bash) detects
> `cd /outside/...` and blocks it. It does NOT match commands whose
> *arguments* point outside PROJECT_ROOT — e.g. `du /root/x`,
> `find /root/x`, `grep -r ... /root/x`, `cat /root/x/file`.

**Closing evidence — what shipped:**

- T-1702 extended the boundary hook to match outside-path arguments (not just `cd`).
- T-1707 added scope-tagging to `fw doctor` (`[host]` vs `[project]` findings), which surfaces machine-level issues without burying project-level ones.
- Combined, these address both legs of G-065's `what_remains`: (a) hook matches argument paths; (b) doctor distinguishes scopes.

**Recommended status flip:**

```yaml
- id: G-065
  ...
  status: closed                       # was: watching
  closed_date: 2026-06-04              # today
  resolution: >
    Closed by T-1702 (hook now matches outside-path arguments via
    extended allowlist) + T-1707 (fw doctor `[host]` vs `[project]`
    scope tagging). Both partial-complete on `[REVIEW]` Human AC at
    time of writing — closure presumes operator's [REVIEW] passes.
```

**Decision rule:** flip only after BOTH `[REVIEW]` ACs above pass. If either
fails, leave G-065 open; the gap re-opens on the failing surface.

---

## Operator evidence checklist

Mechanical sequence to walk through (one-line copy-pasteable commands per
§Copy-Pasteable Commands):

1. **Review T-1702**:
   ```
   cd /opt/999-Agentic-Engineering-Framework && firefox http://192.168.10.107:3000/review/T-1702
   ```
2. **Review T-1707**:
   ```
   cd /opt/999-Agentic-Engineering-Framework && firefox http://192.168.10.107:3000/review/T-1707
   ```
3. **If both pass — flip G-065** (one-line edit, then commit):
   ```
   cd /opt/999-Agentic-Engineering-Framework && sed -i.bak '/^- id: G-065/,/^- id:/{s/^  status: watching$/  status: closed\n  closed_date: 2026-06-04/}' .context/project/concerns.yaml && rm .context/project/concerns.yaml.bak
   ```
   Then commit with the closing-evidence cross-reference:
   ```
   git add .context/project/concerns.yaml && FW_SWITCH_FOCUS=1 git commit -m "T-2197: close G-065 (boundary hook read-blind) — T-1702 + T-1707 evidence"
   ```
4. **Verify**: `grep -A1 "id: G-065" .context/project/concerns.yaml | head -3` should show `status: closed`.

---

## Why this surfaces now

OBS-043 has been in `bin/fw note triage` for at least two prior sessions. Memory
`[[project_arc009_loop_closed.md]]` mentions T-2160 partial-complete pending
[REVIEW] which is in the same operator-queue class.

The handoff doc converts a stale observation into a concrete operator surface
with class-correct URLs, an exact status-flip patch, and the closure-rule
("flip only after both [REVIEW] pass"). It does not consume sovereignty:
the operator still decides whether the [REVIEW] passes, whether to flip,
and how to commit.

Cross-refs: [[feedback_handoff_url_per_class]] (class-correct review URLs),
[[feedback_check_watchtower_log_before_assuming_automation]] (don't assume
the cascade already fired), T-2184 (OBS-048 G-064 handoff precedent).
