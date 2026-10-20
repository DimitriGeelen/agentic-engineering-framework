# T-4516 — LAN address inventory (shipped paths)

**Scope:** tracked files under `lib agents bin web policy tools docs templates .tasks/templates`.
**Matcher:** `tools/lan-address-lint.py` `RFC1918` (10/8, 172.16/12, 192.168/16; not
inside a longer dotted run or a `v1.2.3.4`-style version string).
**Snapshot:** `HEAD` at `3b3fc30d5` (before the T-4516 fixes), 2026-10-20.
Addresses are counted, not quoted.

**Total:** 134 files, 390 address occurrences.

## Disposition by kind

| Kind | Disposition |
|---|---|
| Framework code (bin/lib/agents) | `bin/fw` doctor Ollama probe now resolves the host at runtime (`OLLAMA_HOST` > `.context/settings.yaml` `ollama_host` > `http://localhost:11434`, same order as `web/config.py`). Comments/help text use placeholders (`<host>`, `<remote-host>`, `hub.example.lan`, `203.0.113.x` TEST-NET-3). |
| Probe/harness scripts (tools/t17xx) | `${OLLAMA_HOST:-http://localhost:11434}`. |
| Operational docs | `docs/deployment-runbook.md` → `<LXC_HOST>`, `<OLLAMA_HOST>`, `<TRAEFIK_NODE_1|2>`; listener-heartbeat doc → `<hub-host>`; generated component doc follows its test header. |
| Watchtower web | Comment and settings help text use placeholders; `web/static/ux-review/index.html` link made relative (`/settings/appearance`). |
| Policy config | `policy/anti-patterns.yaml` example → `watchtower.example.lan`. `policy/designer-pin.yaml` `source_origin` **kept, allowlisted**: it is the live pull origin for `fw designer sync --from-tag`; moving it is an operator decision (see T-4516). |
| Historical reports / research | Kept unchanged (records). Exempted by path in `policy/lan-address-allowlist.yaml`. |

After the fixes, `tools/lan-address-lint.py` reports clean; with an empty allowlist the
only hits are `docs/reports/*`, `docs/research/*` and the designer pin.

## Framework code (bin/lib/agents: comments, help text, live probe) — 8 files, 10 addresses

| Path | Count |
|---|---:|
| `agents/metrics/api-usage.sh` | 2 |
| `lib/pending.sh` | 1 |
| `lib/reviewer/static_scan.py` | 1 |
| `lib/templates/scripts/agent-conversation-list.sh` | 1 |
| `lib/templates/scripts/agent-conversation-status.sh` | 1 |
| `lib/templates/skills/broadcast-chat.md` | 2 |
| `lib/templates/skills/recent-chat.md` | 1 |
| `lib/watchtower.sh` | 1 |

## Historical reports (records, kept; allowlisted) — 111 files, 345 addresses

| Path | Count |
|---|---:|
| `docs/reports/EWCR/drive-6-procasfit-handback.md` | 5 |
| `docs/reports/EWCR/drive-7-procasfit-handback.md` | 4 |
| `docs/reports/SEQ-T3411/r1-procasfit-handback.md` | 3 |
| `docs/reports/SEQ-T3411/r2-procasfit-handback.md` | 1 |
| `docs/reports/T-1106-watchtower-port-bleed-rca.md` | 1 |
| `docs/reports/T-1109-web-sync-rca.md` | 1 |
| `docs/reports/T-1121-termlink-tls-tofu.md` | 3 |
| `docs/reports/T-1126-termlink-communication-protocol.md` | 2 |
| `docs/reports/T-1270-peer-learning-cron.md` | 2 |
| `docs/reports/T-1284-watchtower-port-discovery-redesign.md` | 1 |
| `docs/reports/T-1326-coord-answer-to-121.yaml` | 2 |
| `docs/reports/T-1388-approvals-snapshot.md` | 3 |
| `docs/reports/T-1388-watchtower-inception-no-redecide.md` | 1 |
| `docs/reports/T-1499-ring20-hosting-mediation.md` | 1 |
| `docs/reports/T-1539-blind-reviewer-walkthrough.md` | 3 |
| `docs/reports/T-1540-iter1-walkthrough.md` | 2 |
| `docs/reports/T-1540-iter2-walkthrough.md` | 1 |
| `docs/reports/T-1540-iter3-walkthrough.md` | 1 |
| `docs/reports/T-1597-blind-review-SUMMARY.md` | 24 |
| `docs/reports/T-1597-blind-review-W1.md` | 7 |
| `docs/reports/T-1597-blind-review-W2.md` | 5 |
| `docs/reports/T-1597-blind-review-W3.md` | 5 |
| `docs/reports/T-1597-blind-review-W4.md` | 5 |
| `docs/reports/T-1597-blind-review-W5.md` | 4 |
| `docs/reports/T-1611-werkzeug-vs-gunicorn-local.md` | 1 |
| `docs/reports/T-1621-watchtower-url-triple-file-becomes-stale.md` | 10 |
| `docs/reports/T-1667-angle-1-structural-enforcement.md` | 1 |
| `docs/reports/T-1691-proxy-comparison.md` | 4 |
| `docs/reports/T-1740-spike-c.md` | 1 |
| `docs/reports/T-1744-promotion-decision.md` | 1 |
| `docs/reports/T-1745-rca-watchtower-decision-silent-failure.md` | 2 |
| `docs/reports/T-1830-fw-upgrade-incident-meta-rca.md` | 1 |
| `docs/reports/T-2002-ux-review-arc-007-s0-s1.md` | 2 |
| `docs/reports/T-2030-review-link-generation.md` | 2 |
| `docs/reports/T-2081-review-complete-button-render-race.md` | 2 |
| `docs/reports/T-2100-prompt-fork-bomb-containment.md` | 1 |
| `docs/reports/T-2118-review-handoff-palette-rca.md` | 2 |
| `docs/reports/T-2123-ac-routing-debt-rca.md` | 2 |
| `docs/reports/T-2125-inception-handoff-url-rca.md` | 9 |
| `docs/reports/T-2126-fw-task-review-scroll-rca.md` | 1 |
| `docs/reports/T-2133-review-checkbox-htmx-target-error-rca.md` | 2 |
| `docs/reports/T-2138-review-handoff-author-time-gap.md` | 2 |
| `docs/reports/T-2139-evidence/block-message-build.txt` | 1 |
| `docs/reports/T-2139-evidence/block-message-inception.txt` | 1 |
| `docs/reports/T-2181-chat-output-bare-path-rca.md` | 5 |
| `docs/reports/T-2184-obs048-g064-handoff.md` | 2 |
| `docs/reports/T-2197-obs043-g065-handoff.md` | 4 |
| `docs/reports/T-2231-upgrade-fragility-recurrence.md` | 1 |
| `docs/reports/T-2274-readme-research.md` | 1 |
| `docs/reports/T-2277-watchtower-csrf-pollution.md` | 3 |
| `docs/reports/T-2347-arc-closure-ux-rca.md` | 1 |
| `docs/reports/T-2351-arc-close-form-prepop-rca.md` | 1 |
| `docs/reports/T-2441-aef-onboarding-dogfooding.md` | 1 |
| `docs/reports/T-2522-bpmn-aef-mapping-contract.md` | 1 |
| `docs/reports/T-272-deploy-watchtower-ring20.md` | 4 |
| `docs/reports/T-2757-designer-consumer-vendoring.md` | 1 |
| `docs/reports/T-2785-height-guard-investigation.md` | 1 |
| `docs/reports/T-279-watchtower-deployment-model.md` | 4 |
| `docs/reports/T-3022-recall-latency-scaling.md` | 1 |
| `docs/reports/T-3040-recovered-messages-20260816.md` | 15 |
| `docs/reports/T-3047-recovered-upstream-messages.md` | 18 |
| `docs/reports/T-3047-triage-batch-2.md` | 1 |
| `docs/reports/T-3047-triage-batch-5.md` | 2 |
| `docs/reports/T-3047-triage.md` | 3 |
| `docs/reports/T-3181-cold-resume-armB.md` | 1 |
| `docs/reports/T-324-buildspec-scrub.md` | 5 |
| `docs/reports/T-325-human-ac-handoff-quality.md` | 1 |
| `docs/reports/T-3447-struktur-double-hover.md` | 1 |
| `docs/reports/T-3475-sidecar-slice1-transport.md` | 3 |
| `docs/reports/T-3538-arc-closeout-pack.md` | 3 |
| `docs/reports/T-3557-render-review-2026-09-29.md` | 1 |
| `docs/reports/T-3557-spike-prompt.md` | 1 |
| `docs/reports/T-3557-spike-verdicts.md` | 1 |
| `docs/reports/T-3563-arc-story.md` | 1 |
| `docs/reports/T-3564-build-prompt.md` | 1 |
| `docs/reports/T-3564-rereview-prompt.md` | 1 |
| `docs/reports/T-3564-review-prompt.md` | 3 |
| `docs/reports/T-3574-T-3575-render-review.md` | 1 |
| `docs/reports/T-3574-T-3575-rereview-prompt.md` | 2 |
| `docs/reports/T-3574-T-3575-review-prompt.md` | 2 |
| `docs/reports/T-3586-T-3587-review-prompt.md` | 2 |
| `docs/reports/T-3586-T-3587-review.md` | 1 |
| `docs/reports/T-3587-render-review.md` | 3 |
| `docs/reports/T-3587-review-prompt.md` | 4 |
| `docs/reports/T-3590-review.md` | 1 |
| `docs/reports/T-375-agent-5-settings.md` | 2 |
| `docs/reports/T-3751-2a-review-brief.md` | 1 |
| `docs/reports/T-3751-review-google.md` | 1 |
| `docs/reports/T-3806-cross-hub-send.md` | 1 |
| `docs/reports/T-3855-cross-hub-sidecar.md` | 1 |
| `docs/reports/T-3879-1409-pickup-t1676-verbatim.md` | 1 |
| `docs/reports/T-388-search-ux-overhaul-research.md` | 1 |
| `docs/reports/T-3930-worker-brief.md` | 2 |
| `docs/reports/T-3960-ring20-s1-contract-check.md` | 1 |
| `docs/reports/T-3960-worker-brief.md` | 1 |
| `docs/reports/T-3977-worker-brief.md` | 1 |
| `docs/reports/T-4017-arc-001-inputs/1-arc-001-03-pickup-proposal.md` | 1 |
| `docs/reports/T-4017-arc-001-inputs/4-arc-001-01-requirements.md` | 2 |
| `docs/reports/T-549-openclaw-evaluation-research.md` | 1 |
| `docs/reports/T-549-openclaw-pickup-prompt.md` | 2 |
| `docs/reports/T-885-service-registry.md` | 1 |
| `docs/reports/T-962-v6-security-model.md` | 4 |
| `docs/reports/approvals-batch-2026-05-20.md` | 36 |
| `docs/reports/fw-agent-t629-07-cmdlen.md` | 1 |
| `docs/reports/fw-agent-t636-03-bridge.md` | 1 |
| `docs/reports/fw-agent-t636-05-mobile-qr.md` | 2 |
| `docs/reports/orchestrator-rethink-closure-readiness.md` | 3 |
| `docs/reports/orchestrator-rethink-demo/README.md` | 1 |
| `docs/reports/procasfit-2026-09-27-round-2.md` | 1 |
| `docs/reports/triage-2026-05-13-review-queue.md` | 30 |
| `docs/reports/value-prioritisation-demo/README.md` | 2 |

## Operational docs — 3 files, 17 addresses

| Path | Count |
|---|---:|
| `docs/deployment-runbook.md` | 15 |
| `docs/generated/components/tests-unit-test_doctor_litellm_ollama.md` | 1 |
| `docs/operations/listener-heartbeat-systemd.md` | 1 |

## Policy config — 2 files, 2 addresses

| Path | Count |
|---|---:|
| `policy/anti-patterns.yaml` | 1 |
| `policy/designer-pin.yaml` | 1 |

## Probe/harness scripts — 4 files, 8 addresses

| Path | Count |
|---|---:|
| `tools/t1700-ollama-harness.sh` | 3 |
| `tools/t1703-probe-matrix.sh` | 1 |
| `tools/t1704-hermes3-probe.sh` | 2 |
| `tools/t1706-tool-loop-probe.sh` | 2 |

## Research logs / manifests (records, kept; allowlisted) — 3 files, 5 addresses

| Path | Count |
|---|---:|
| `docs/research/executable-workflow/governance-cadence.md` | 1 |
| `docs/research/executable-workflow/questions-and-dispositions.md` | 1 |
| `docs/research/executable-workflow/source-manifest.yaml` | 3 |

## Watchtower web (code comment, template help text, static page) — 3 files, 3 addresses

| Path | Count |
|---|---:|
| `web/blueprints/tasks.py` | 1 |
| `web/static/ux-review/index.html` | 1 |
| `web/templates/settings.html` | 1 |
