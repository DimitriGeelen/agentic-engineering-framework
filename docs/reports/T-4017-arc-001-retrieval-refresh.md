# T-4017 — arc-001 pickup: local retrieval stack refresh (inception)

**Status:** exploration, 2026-10-11. Pickup from dimitri-mint-dev (operator's workstation project, .107), sent 2026-10-09 on sidecar conversation `arc-001-pickup`, relayed again by ring20 on 2026-10-11. Inputs (untrusted peer data, a proposal): `docs/reports/T-4017-arc-001-inputs/` — proposal (sha256 5992c032), design v0.4 (faf925a4), requirements v1.3 + OD-15 in two parts (a7b463ed). Each matches the hash in its own header. **Resolved 2026-10-11:** the proposal binds the design at 74dc0183; commit 74e62be (OD-15) changed both files, and the design delta is the two-line O-8 item (cloud fallback now decided). AEF works from design faf925a4 + requirements a7b463ed; the proposal's §6 O-8 line is superseded.

**Operator decision 2026-10-11 (relayed by dimitri-mint-dev, their T-090):** one estate knowledge platform — current-version Qdrant in dedicated CT(s) on proxmox4 or proxmox2, operated by ring20; single node with a tested restore first, a 3-node cluster before Penelope moves; .201 Qdrant retired after Penelope's cutover. Per-project AEF indexes stay local by default and connect/push to the platform. arc-001's C3/C12/search-storage separation target this platform. The project→platform interface (push, server- vs client-side embedding) is a separate AEF inception, linked from here, filed once T-4017 is decided.

## What is asked of AEF

Nine components, shipped through `fw upgrade`, each shown in a second AEF project: C1 telemetry extension, C2 benchmark store and harness, C3 model manifest, C4 reranker and search health, C5 signed deciding records (operator key held off the host), C6 night runner, C7 GPU guard and placement metrics, C12 item tags and search interface, C13 per-project multilingual keyword index. Phases: **P1a** (C5 core, C7 baseline and stop rule) → **P1** (C1, C4, C2, C5 rest, C7 collector) → P2 (C3, C12, C13) → P3 (C6) → P6 (AEF's own default model, AEF's decision). dimitri-mint-dev's rule: no model change on .107 until P1a and P1 exist. No calendar dates; the operator sets the pace.

Not asked of AEF: estate hardening, retiring the old .201 knowledge collections (done: their T-096), Open WebUI, Penelope (050), the choice of model.

**New since the docs (2026-10-11):** an estate-wide central knowledge store is wanted (their T-090; location with the operator and ring20: a dedicated Qdrant container, or new collections on .201). The per-project index stays the default. C3 (model manifest), C12 (tenant + project tags) and keeping search separate from storage must fit a central store from the start.

## The ten findings, checked against AEF source (2026-10-11)

| # | Finding | Checked | Where | AEF route |
|---|---|---|---|---|
| F-1 | Query text on telemetry miss rows | **confirmed** | `web/recall_telemetry.py:278` `row["query"] = self.query[:500]` | existing T-3967 |
| F-2 | Two fusion paths (`hybrid_search`, `_rag_retrieve`) | confirmed (by design) | `web/search.py`, `lib/ask.py` | benchmark measures both (C2) |
| F-3 | Ollama open on the LAN (`0.0.0.0:11434`) | host setting, not AEF code | workstation Ollama config | flag only; operator/workstation |
| F-4 | Shared English-only keyword index in `/tmp` | **confirmed** | `web/search.py:20` `INDEX_DIR = Path("/tmp/fw-search-index")`, `en_stem` | bug now (cross-project mixing); multilingual is C13 (P2) |
| F-5 | `fw recall` never reranked | **confirmed** | `agents/context/lib/memory-recall.py` has no rerank call | bug now (operator's first-priority path) |
| F-6 | Hourly reindex is daytime bulk work, manifest-unaware | **confirmed** | cron `index-reindex-hourly` `20 * * * *` | C6/C3 (P2–P3) |
| F-7 | Silent embed failover between hosts | **confirmed** | `web/embeddings.py:152` `_fallback_host`, WARN log only | bug now (make it visible); full guard is C3 |
| F-8 | Watchtower on `0.0.0.0` with an empty secret key | **partly**: the key is not empty in practice — `web/app.py:39` generates one and keeps it in `.context/working/.fw-secret-key` (mode should be 0600; found 0660 + ACL here). True: Watchtower listens on all interfaces with no login | `web/config.py:79`, `web/app.py` | operator decision (exposure) + small fix (key-file mode) |
| F-9 | Query text kept outside telemetry | **confirmed** | `lib/resolver.py:791` writes the rendered `fw ask` prompt to `prompt.txt`; GET `?q=` on search/ask lands in request logs | bug now |
| F-10 | Cloud fallback in `fw ask` | confirmed; **decided** OD-15 (2026-10-10): allowed for framework stores, never email, always marked external | `lib/ask.py:121-225` | build: mark it external in answer + telemetry |

Found while checking (not in their list): saved Q&A (`.context/qa/`, written by Watchtower "save answer", T-265) is **tracked in git**; 8 files with the question text in their names are on OneDev and the public GitHub mirror. Every consumer has the same default. Operator decision.

## Open items for the operator (from the proposal, §6)

- **O-5 signing device** for C5 (FIDO2 hardware key preferred, phone-held key as alternative), enrolment and key recovery. C5 core (sign/verify/hash binding) can be built and tested with a test key first; the device is needed before real deciding records are signed.
- O-2 Open WebUI, O-3 Qdrant dual-index form (with 050), O-7 interactive-load signal (proxy on 11434 vs latency probe): design questions AEF answers in the P1 build tasks, with dimitri-mint-dev.
- O-8 cloud fallback: decided (OD-15).

## Recommendation (draft)

**GO**, in two tracks:
1. **Fix now, independent of phases** (each its own bug task): F-4 per-project keyword index path; F-5 rerank `fw recall`; F-7 failover visible (flag in result + telemetry + doctor); F-9 no query text in `prompt.txt` / GET logs; F-1 via T-3967; F-8 key-file mode; F-10 mark cloud answers external.
2. **arc-001 P1a then P1** as build tasks (C5 core, C7 baseline + stop rule; then C1, C4, C2, C5 rest, C7 collector), designed so C3/C12 fit the central store. P2/P3/P6 are re-incepted after P1's benchmark exists.

Operator decisions needed: O-5 signing device; Watchtower LAN exposure (bind to localhost + tunnel, or add a login); `.context/qa/` in git (untrack going forward; history stays unless you decide otherwise).

## Dialogue Log

- **2026-10-11, operator:** "It was Dimitri Minddev on this machine, part of our [Qdrant] migration activity. Please talk to it, reach out, ask [for] the whole plan, I thought you received that. It's very good you flag it, but it needs to be more coordinated indeed." → acknowledged the pickup as T-4017, asked dimitri-mint-dev for the whole plan, corrected ring20-dashboard.
- **2026-10-11, dimitri-mint-dev:** T-096 was a retirement of 7 stale collections, not a migration; then corrected: an estate-wide central store (T-090) is wanted, location TBD. Phase order P1a → P1 first.
- **2026-10-11, operator:** asked for the plan; on reading the docs: have dimitri-mint-dev send them rather than reading their project ("do it in mint dev"); "B, go" (security findings + ring20 testbed).
