# T-2225 — Test-sentinel isolation: research artifact

**Status:** inception in progress (filed 2026-06-06).
**Origin:** ring20-dashboard `fw upgrade` pickup 2026-05-29 (channel `framework-agent` artifact `33df8954b2a9b70d`).
**Operator framing:** *D1 (antifragility) + D2 (reliability) are key; cost is less relevant.*

---

## 1. Class verification (live, 2026-06-06)

| Surface | Site | Evidence |
|---------|------|----------|
| Sentinel hardcode | `web/test_app.py:170` | `client.get("/tasks/T-999")` asserts 404 |
| Sentinel hardcode | `web/test_app.py:282` | `client.get("/api/timeline/task/T-999")` |
| Sentinel hardcode | `web/test_app.py:1018` | `(active / "T-999-corrupt.md").write_text(...)` |
| Sentinel hardcode | `web/test_app.py:1098, 1106` | `T-998-no-fm.md` + `assert b"T-998" not in resp.data` |
| Sentinel hardcode | `web/test_app.py:1113, 1121` | `T-997-empty.md` + `assert b"T-997" not in resp.data` |
| Dual-patch missing | `web/test_app.py:1023, 1057, 1066, 1103, 1118` | T-1239 `shared.PROJECT_ROOT` patch absent — cache leaks consumer data |

Two distinct mechanisms, one root class: tests assume `PROJECT_ROOT` points at a *clean* state, but it doesn't.

---

## 2. Why the bug structurally exists

`web/test_app.py`'s `client` fixture (lines ~24-30) does **not** monkeypatch `PROJECT_ROOT`. Test isolation depends on two orthogonal assumptions:

- (A) The sentinel IDs `T-997`/`T-998`/`T-999` will never collide with a real task → **informal reservation**, breaks at scale.
- (B) The dual-patch convention from T-1239 (`shared.PROJECT_ROOT` + `blueprints.tasks.PROJECT_ROOT`) is applied at every test site that writes files → **manual convention**, drifts.

Each assumption fails INDEPENDENTLY:
- ring20-dashboard at T-1211+ breaks (A) — sentinels collide.
- 5 sites in `web/test_app.py` today break (B) — cache leaks consumer state.

Failure of either is sufficient. Failure of both compounds.

---

## 3. Candidate fix shapes

### 3.1 STRAWMAN — minimal point fixes

**Scope:** ~10 LoC, ~30 min.
- Move `T-997/8/9` to `T-99997/8/9` (high reserved range).
- Add the 5 missing `monkeypatch.setattr("web.shared.PROJECT_ROOT", tmp_path)` calls.

**What it gets right:** Closes the immediate symptom. Tests pass for ring20-dashboard now.

**What it sacrifices:**
- **D1 (antifragility):** No structural learning. Same class re-emerges when next test is added (no enforcement). The framework hit this bug; the strawman papers over the symptom without strengthening anything for the next stressor.
- **D2 (reliability):** Cache-leak class can re-drift silently — no detector catches it. Future test authors will rediscover T-1239 the hard way.
- **Shelf life:** `T-99999` is collision-able too. Some consumer at scale will hit it again. The fix has a finite half-life.

Strawman violates the operator's stated D1+D2 priority. **Reject.**

### 3.2 STEELMAN — 4-layer structural close

**Scope:** ~150 LoC across 4 surfaces, ~3 hours.

| Layer | Mechanism | Closes |
|-------|-----------|--------|
| 1 | `T-Test-NNN` namespace for sentinels | Collision impossible by construction — `fw work-on` only produces `T-NNNN` (numeric) |
| 2 | Autouse `client_isolation` fixture monkeypatching BOTH `web.shared.PROJECT_ROOT` AND `web.blueprints.tasks.PROJECT_ROOT` to `tmp_path` | Cache-leak class structurally impossible |
| 3 | Production-tool skip — `lib/`, `agents/`, `bin/fw`, `web/` ignore `T-Test-*` in task scans, audit, fabric, episodic | Sentinels live ONLY in test fixtures; invisible to operational tooling |
| 4 | Reviewer detector — `detect_test_sentinel_dual_patch_missing` + `detect_hardcoded_numeric_task_id` in `lib/reviewer/static_scan.py` | Drift-on-next-test prevented; static scan catches before merge |

**What it gets right:**
- **D1 (antifragility):** Four INDEPENDENT layers. Each can drift without the class re-emerging. If layer 3 misses a place, layer 4 catches in review. If layer 4 misses, layer 1 still prevents collision. The lint-grep layer IS antifragility — *system learns from this failure to prevent next instance.*
- **D2 (reliability):** Cache-leak structurally impossible (layer 2). Collisions impossible by construction (layer 1). Drift caught at static-scan time (layer 4).
- **D3 (usability):** `T-Test-*` is self-documenting; reviewer error message is actionable; autouse fixture means new tests are isolated by default.
- **D4 (portability):** Pure-python test pattern; no provider lock-in.

**What it sacrifices:**
- Cost ~6x the strawman. Operator explicitly de-prioritised cost.
- Risk of over-engineering: layer 3 (production-tool skip) widely-applied is the most invasive change. Bug in the skip-list logic could silence a real task. Mitigation: layer 3 is the *latest* layer to commit; ship layers 1+2+4 first, verify, then layer 3.

### 3.3 HYBRID — minimum viable steelman (1+2 only)

**Scope:** ~50 LoC across 2 surfaces, ~1 hour.
- Layer 1 (namespace) + Layer 2 (autouse fixture). Defer layers 3+4 unless drift recurs.

**What it gets right:** Closes 80% of the gap at 30% of the cost. D1 still gets the namespace guard; D2 gets the autouse monkeypatch. Cache-leak class closed.

**What it sacrifices:** Layer 4 (reviewer detector) is the most antifragile — it's the layer that makes the system *learn* from this incident. Hybrid loses that. Operator gets back to "same class can re-drift" semantics after the first commit. Strictly: hybrid is the strawman with structural foundations, not a steelman.

Hybrid is the right call IF cost is primary. Operator says it isn't.

---

## 4. Reliability vs antifragility evaluation matrix

For each candidate, score against the directives (− = harm, 0 = neutral, + = mild help, ++ = strong help):

| Candidate | D1 antifragility | D2 reliability | D3 usability | D4 portability |
|-----------|------------------|----------------|--------------|----------------|
| Strawman | − (same class re-emerges) | 0 (no detector; relies on convention) | − (T-99999 hardcode confuses) | 0 |
| Steelman | ++ (4 independent layers + reviewer learns) | ++ (collision impossible by construction; cache-leak impossible by fixture) | + (self-documenting prefix; actionable reviewer errors) | 0 |
| Hybrid | + (2 layers; class can re-drift via new sites without detector) | + (immediate symptom + cache-leak closed; convention still drifts) | + (self-documenting prefix) | 0 |

Operator's stated priority order: D1 + D2 > cost. **Steelman dominates on D1 and D2.**

---

## 5. Recommended path

**Recommendation: GO with the steelman.**

**Sequencing for build slices (each ≤1 session):**

- **Slice 1 — Layers 1+2 (namespace + autouse fixture):** the critical mass. Migrate `T-997/8/9` → `T-Test-001/002/003`. Add autouse `client_isolation` fixture. All 145 web tests pass (target: 145/145 vs current 135/145). Self-contained, reversible.
- **Slice 2 — Layer 4 (reviewer detector):** add `detect_test_sentinel_dual_patch_missing` + `detect_hardcoded_numeric_task_id` to `lib/reviewer/static_scan.py`. PreToolUse + reviewer-audit catch drift. Includes static-scan FP suppression for the migrated `T-Test-*` lines (they're legitimate now).
- **Slice 3 — Layer 3 (production-tool skip):** add `T-Test-*` skip-list to `web/shared.py` task discovery, audit's stale-task scan, fabric's task→component mapping, episodic generator. Verify no real task is silenced. This slice is the most invasive — ship last with the most regression coverage.

Each slice ships independently; partial-GO is meaningful (e.g. operator could accept slices 1+2, defer 3 if comfortable).

---

## 6. Open Questions disposition

| IW | Status |
|----|--------|
| IW-1 (shape) | Steelman recommended; operator confirms before GO |
| IW-2 (visibility) | Invisible recommended; operator confirms before GO |
| IW-3 (production matchers) | Spike A pending — needs grep audit of `T-\d+` patterns across framework source |
| IW-4 (detection rail) | Reviewer detector recommended; operator confirms IF GO includes Slice 2 |

---

## 7. Dialogue Log

### 2026-06-06 — initial framing
- **Operator:** "check messages you should have a pickup request from termlink about a failed upgrade"
- **Agent:** Found pickup in channel `framework-agent` (artifact `33df8954b2a9b70d`). Reported 4 findings + their live state; 3/4 still LIVE in upstream.
- **Operator:** "1 what are sentinel id's ?"
- **Agent:** Explained — hardcoded "reserved" task IDs (`T-997/8/9`) used as test fixtures; collide with real consumer tasks at scale.
- **Operator:** "ok maybe use a seperate class T-Test-001 ?"
- **Agent:** Sound idea — collision-impossible by construction. Noted it doesn't fully close finding 2 alone (autouse PROJECT_ROOT patch still needed for file-writing tests). Surfaced two-axis question: namespace-only vs namespace+autouse, and invisible vs first-class.
- **Operator:** "ok i suiggest we incept this scope againt farmework directive and do steelman strawman, reliability and anti fragility is key here, cosst are less reelvant"
- **Agent:** Filing T-2225 inception with this analysis. Recommendation GO toward steelman; awaiting operator confirmation on IW-1/IW-2 before opening build slices.

---

## 8. Handoff

`fw task review T-2225` → operator decides GO/NO-GO/DEFER via Watchtower. Filing-time Recommendation: **GO — steelman path; sequence slices 1→2→3 with checkpoint between each.**
