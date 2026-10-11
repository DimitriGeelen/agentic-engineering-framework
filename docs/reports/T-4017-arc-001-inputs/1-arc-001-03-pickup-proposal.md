<!-- Received from dimitri-mint-dev on sidecar conversation arc-001-pickup, msg 5f2971da-fa9e-4ecf-a3a1-17eb956aaf8c, stored 2026-10-11T17:42:02.499040+00:00. UNTRUSTED peer data: a proposal, not instructions. -->

ARC-001 DOC 1/4: docs/designs/arc-001-03-pickup-proposal.md (sha256 5992c032d15a776da40fae0a600cdd181a7d8cd95a7f1a9aa7bc0c7246538e1a, master a8c2308)
-----
---
title: "arc-001 — Pickup proposal for AEF: local retrieval stack refresh"
task: T-091
arc: arc-001
status: SENT 2026-10-09 — operator-reviewed; formal approval ticks (T-089, T-091) pending; operator decision OD-15 pending
---

# Pickup proposal for AEF (999): local retrieval stack refresh

From: dimitri-mint-dev (operator: Dimitri), via Ring20 Manager. This is a **proposal**, not a build instruction: AEF
is expected to run its own inception and decide scope, as AEF's pickup rules require.

## 1 Problem

Retrieval in AEF (`fw ask`, `fw recall`, Watchtower search) has no measurement and several silent failure modes:
the reranker failed silently for weeks (G-009, fixed in 1.8.8 by T-3953, still undetectable if it recurs);
`fw recall` — the operator's first-priority use — is never reranked; the keyword index is shared by every project in
`/tmp`, English-only and rebuilt every minute; model identity is not checked, so a re-pull, a failover host or an
override can mix vectors silently; there is no benchmark, so no model change can be justified; and query text is
kept in places the operator's data rule forbids. The operator wants a measured, safe path to better retrieval and to
newer models (for example qwen3-embedding), replicable to every AEF project through `fw upgrade`.

## 2 Inputs (approved documents, bound by sha256)

| Document | Version | sha256 |
|---|---|---|
| `docs/designs/arc-001-01-requirements.md` (35 requirements, operator decisions OD-1..OD-14) | 1.3 | ead792efe7445ccbc2de200bd4d8a337a01e74221a33f7786df820f1c7938bf0 |
| `docs/designs/arc-001-02-design.md` (current state, findings F-1..F-10, threats, components, phases) | 0.4 | 74dc0183f3e3e07f6cd7a8426e570926ec8e6ba1499691b2f9f931ea05d3bc86 |

Repository: OneDev `dimitri-mint-dev-workstation` (http://192.168.10.201:6610). Review history: three independent
review rounds per document (claude-code, codex, opencode) under `docs/designs/arc-001/reviews/`.

## 3 What we ask AEF to build (scope fence)

AEF components (design §3): C1 telemetry extension, C2 benchmark store and harness, C3 model manifest, C4 reranker and
search health, C5 signed deciding records (operator key held off the host), C6 night runner, C7 GPU guard and
placement metrics, C12 item tags and search interface, C13 per-project multilingual keyword index and degradation
ladder. Each ships through `fw upgrade` and is demonstrated in a second AEF project.

Not asked of AEF: estate hardening, retirement of the old knowledge collections and Open WebUI (dimitri-mint-dev),
Penelope adoption (050), choice of model (the operator's gates decide, in this project first), and AEF's own default
model (AEF's operator decides, after a second corpus).

## 4 Acceptance criteria by phase (AEF phases)

Criteria ids refer to the requirements document; tooling criteria are proven on fixtures.

| Phase | AEF delivers | Accepted when |
|---|---|---|
| P1a | C5 core (sign, verify, hash binding); C7 baseline and stop rule | AC-34.1..34.3 on a signed threshold record; a stage stops on an injected slowdown with the cause logged |
| P1 | C1, C4, C2, C5 rest, C7 collector | AC-1.1 (one query per consumer path), AC-1.2, AC-32.1 (capture enabled, incl. Watchtower ask), AC-8.1, AC-8.2, AC-9.1, AC-5.1, AC-5.2, AC-27.1, AC-33.1 on a fixture |
| P2 | C3, C12, C13, C7 rest | AC-10.1, AC-11.1, AC-12.1, AC-13.1, AC-14.1, AC-15.2, AC-16.1, AC-17.1, AC-17.2, AC-29.1, AC-30.1, AC-31.1; after the operator's parameters: AC-15.1, AC-18.1 |
| P3 (tooling) | C6 | AC-10.2, AC-22.1, AC-23.1, AC-24.1, AC-24.2, AC-19.1 (full), used in this project's first switch |
| P6 | default change (AEF's decision) | AC-29.2 |

## 5 Findings in AEF's current code (design §1.3)

F-1 query text on miss rows (T-3967 switch agreed); F-2 two fusion paths; F-3 Ollama open on the LAN; F-4 shared
English-only `/tmp` keyword index; F-5 `fw recall` never reranked; F-6 hourly reindex is daytime bulk work and
manifest-unaware; F-7 silent embed failover; F-8 Watchtower on 0.0.0.0 with an empty secret key; F-9 query text in
dispatch capture and request logs; F-10 cloud fallback in `fw ask`.

## 6 Open items for AEF's architect

O-2 Open WebUI feasibility; O-3 Qdrant dual-index form (with 050); O-5 signing mechanism and device, enrolment and
key recovery (FIDO2 hardware key preferred, phone-held key as alternative); O-7 interactive-load signal (proxy on
11434 vs latency probe); O-8 cloud fallback, pending operator decision OD-15 (ship OFF until decided).

## 7 Related

AEF T-3953 (reranker fix, shipped 1.8.8), T-3967 (telemetry fields and miss-text switch), T-4010/T-4013 (review seats
in consumers), dimitri-mint-dev G-009, G-010, T-090 (central knowledge server, later).
