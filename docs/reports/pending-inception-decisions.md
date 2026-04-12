# Pending Inception Decisions — 2026-04-12

12 inception tasks are ready for human GO/NO-GO decisions.
Review at: http://localhost:3000/approvals (Watchtower must be running)

## High Priority

| Task | Recommendation | Summary |
|------|---------------|---------|
| **T-1135** | GO | Persistent TermLink agent sessions — always-on receptionist per project. Cross-agent coordination with /opt/termlink confirmed: 3 code changes in TermLink, tag-based exemption, naming convention agreed. |
| **T-1109** | GO | fw upgrade silently skips web/ sync — enumeration divergence between do_upgrade and do_vendor. Upgrade worker confirmed: 11 consumers still missing hook scripts after upgrade. |
| **T-1101** | GO | fw inception decide --force bypass — RCA + remediation. CRITICAL gap. |

## Medium Priority

| Task | Recommendation | Summary |
|------|---------------|---------|
| **T-1134** | GO | Upstream portable date helpers from 010-termlink. 3 files use GNU-only `date -d`. |
| **T-1136** | GO | Upstream session-init concerns check. Display open gaps at session start. |
| **T-1139** | GO | Add patch-delivery type to pickup processor. 2 patches rejected today. |
| **T-1102** | GO | bin/fw vs .agentic-framework/bin/fw — framework error messages broken in consumers. |
| **T-1104** | GO | CLAUDE.md / fw help / code drift — structural enforcement of doc parity. |

## Lower Priority

| Task | Recommendation | Summary |
|------|---------------|---------|
| **T-1121** | GO | TermLink U-001: TLS cert TOFU violation. Upstream fix (persist cert). |
| **T-1125** | GO | TermLink U-003: send-file silent loss. Upstream fix (delivery confirmation). |
| **T-1122** | DEFER | TermLink U-002: hub-level inbox. Deferred pending T-1135 persistent sessions. |
| **T-1107** | DEFER | Task-ID collision defense-in-depth. Pending T-1106 outcome. |

## Quick Decision Commands

```bash
# Review all in Watchtower:
open http://localhost:3000/approvals

# Or decide via CLI (one at a time):
cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-1135 go --rationale "your rationale"
cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-1109 go --rationale "your rationale"
cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-1101 go --rationale "your rationale"
```
