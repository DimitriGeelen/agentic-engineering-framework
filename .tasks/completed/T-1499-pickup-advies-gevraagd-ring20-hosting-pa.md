---
id: T-1499
name: "Pickup: Advies gevraagd: Ring20 hosting pattern voor Novis simulator + REST proxy (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-045. Type: feature-proposal.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [pickup, feature-proposal]
components: [C-004, lib/inception.sh, lib/task-audit.sh]
related_tasks: []
created: 2026-04-26T11:13:13Z
last_update: 2026-04-26T17:24:24Z
date_finished: 2026-04-26T17:24:24Z
source_task_id_in_origin: T-045
source_project_in_origin: "003-NTB-ATC-Plugin"
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1499: Pickup: Advies gevraagd: Ring20 hosting pattern voor Novis simulator + REST proxy (from 003-NTB-ATC-Plugin)

## Problem Statement

**Misrouted hosting-topology advice request.** The 003-NTB-ATC-Plugin consumer (T-045) emitted a pickup envelope (P-004) asking where to host two .NET Core services on Ring20 (Novis SOAP simulator + REST proxy). The envelope landed in the framework's inbox, but the framework is not the addressee — Ring20 deployment topology, registry choice, reverse-proxy routing, TLS provisioning, and identity federation all live with **ring20-management (.122)**, not with this governance project.

**Why now / why this matters:** the framework's authority is governance over agentic engineering — task gates, learning capture, episodic memory. It has zero authority over Ring20 host selection or deployment policy. Auto-creating a feature-proposal task here entered the wrong queue. Answering would require either (a) consulting ring20-management on the consumer's behalf (relay) or (b) fabricating advice the framework has no grounding for.

**Stale time-box:** envelope requested response by 2026-04-20 14:00 CET. Today is 2026-04-26. The question is six days past its window — by now the consumer has either re-routed directly to ring20-management, accepted YellowTwig Azure as the alternative, or moved on. Acting now in the framework adds noise, not signal.

## Assumptions

- **A1:** Ring20 hosting decisions are owned by ring20-management (.122), not by this framework. Falsifiable by checking authority on Ring20 fleet — confirmed: ring20-management hosts the cert/secret rotation, fleet-doctor, and deploy patterns; this repo only governs the agentic workflow layer.
- **A2:** The consumer's T-045 has progressed in six days (decision recorded directly with ring20-management OR pivoted to YellowTwig Azure). No way to verify from this side without cross-project query, but the time-box was 1 day — anything still pending here is by definition stale.
- **A3:** Re-routing this from the framework is worse than declining: framework relay adds latency, loses accountability, and pollutes governance signal with infrastructure questions. Falsifiable — but the precedent "framework is not a relay for hosting questions" preserves separation of concerns.
- **A4:** The pickup-router that auto-created this task did not check addressee semantics; any "feature-proposal" type lands here regardless of whether the framework is the right responder. (Latent gap — pickup envelopes lack a `target_project` field.)

## Exploration Plan

(No exploration warranted — this is a routing decision, not a substantive technical question this project is qualified to answer.)

## Technical Constraints

- **Authority constraint:** the framework cannot make Ring20 host selection commitments — those decisions and their consequences are owned by ring20-management. Any "advice" from here would be speculative.
- **Time-box constraint:** envelope was 1-day-bounded; six days late, the answer (if any) belongs in 003-NTB-ATC-Plugin's own decision log, not as a fresh inception here.
- **Scope-of-knowledge constraint:** this project does not maintain Ring20 fleet inventory, registry policy, Traefik routing config, or identity federation rules. Those live in ring20-management.

## Scope Fence

**IN scope:**
- Decline the request as misrouted.
- Record the latent pickup-router gap (no addressee filter) as an observation for future routing improvements.
- Suggest the consumer re-issue directly to ring20-management.

**OUT of scope:**
- Substantive hosting advice for Ring20.
- Cross-project relay to ring20-management on the consumer's behalf.
- Fixing the pickup-router today (separate concern; covered by future routing work).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO — mediation completed; relay response captured (see "## Response from ring20-management" below)

**Outcome (after relay):** ring20-management answered all five questions with concrete fleet evidence (Docker Swarm cluster topology, registry endpoint, Traefik routing path, DNS namespace correction `*.ring20.geelenandcompany.com` not `*.geelenandcompany.com`, and three concrete reasons to defer the production AddIn backend to YellowTwig Azure). The framework's job on T-1499 is done: the question reached the right authority, the answer is captured verbatim in this task file, and the consumer (003-NTB-ATC-Plugin / T-045) now has actionable information they can decide on. Closing this task as GO does NOT make the consumer's hosting decision — that remains in 003-NTB-ATC-Plugin's queue.

**Original Recommendation (preserved for audit):** DEFER pending ring20-management response (relay via TermLink). Replaced now that the response has landed.

**Rationale (revised after user pushback on initial NO-GO):** The framework cannot author Ring20 hosting advice — that authority lives with ring20-management — but it CAN mediate without claiming authority. Relay the consumer's five questions verbatim to ring20-management's TermLink session (`tl-chh52mlp` on `192.168.10.122:9100`) via `termlink remote inject`, capture the response in this task, and let the consumer (003-NTB-ATC-Plugin) make the final hosting decision based on what comes back. The framework does not interpret, summarize, or filter — it routes and records. That preserves authority boundaries while still moving the consumer's question forward.

This corrects the earlier misjudgement (NO-GO/decline). Being the wrong addressee does not require closing the door — it just requires not pretending to be the answerer. Relaying preserves audit trail (questions and response live in this task), avoids latency from making the consumer re-route manually, and exercises a useful primitive (cross-fleet question-relay) the framework already has via TermLink fleet topology.

**Evidence:**
- Pickup envelope: `.context/pickup/processed/P-004-feature-proposal-from-ntb-atc.yaml`
- ring20-management hub reachable: `termlink fleet status` shows `192.168.10.122:9100 UP` with session `tl-chh52mlp` (single ready PTY-backed session).
- Saved hub profile: `~/.termlink/hubs.toml` has `ring20-management` profile with secret-file authentication — `termlink remote list ring20-management` succeeds.
- Five questions to relay (verbatim from envelope): host suitability, deployment pattern (registry/IaC/CI-CD), external reachability (DNS/Traefik/TLS), auth integration, policies/blockers.

**Alternatives considered (this round):**
- *NO-GO (initial recommendation)*: rejected after user pushback — declining is correct on authority but wrong on usefulness. Framework can mediate without authoring.
- *GO + framework-side advisory*: rejected — framework has Traefik routes in `deploy/` but no fleet-wide hosting policy authority. Drafting advice the framework cannot enforce would be the worst of both worlds.
- *DEFER + tell consumer to re-issue*: rejected — adds a hop the framework can avoid by relaying directly. Consumer's 003-NTB-ATC-Plugin agent does not yet have a saved profile for ring20-management; framework already does.

**Next steps (this task):**
1. Inject the five questions to `tl-chh52mlp` on ring20-management hub (logged in Updates).
2. Watch for response via `termlink remote pty output ring20-management tl-chh52mlp --lines 200`.
3. Capture response verbatim in a "## Response from ring20-management" section.
4. Update Recommendation to GO/NO-GO based on response (or leave DEFER if no response within ~24h).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — mediation completed; relay response captured (see "## Response from ring20-management" below)

Outcome (after relay): ring20-management answered all five questions with concrete fleet evidence (Docker Swarm cluster topology, registry endpoint, Traefik routing path, DNS namespace correction `*.ring20.geelenandcompany.com` not `*.geelenandcompany.com`, and three concrete reasons to defer the production AddIn backend to YellowTwig Azure). The framework's job on T-1499 is done: the question reached the right authority, the answer is captured verbatim in this task file, and the consumer (003-NTB-ATC-Plugin / T-045) now has actionable information they can decide on. Closing this task as GO does NOT make the consumer's hosting decision — that remains in 003-NTB-ATC-Plugin's queue.

Original Recommendation (preserved for audit): DEFER pending ring20-management response (relay via TermLink). Replaced now that the response has landed.

Rationale (revised after user pushback on initial NO-GO): The framework cannot author Ring20 hosting advice — that authority lives with ring20-management — but it CAN mediate without claiming authority. Relay the consumer's five questions verbatim to ring20-management's TermLink session (`tl-chh52mlp` on `192.168.10.122:9100`) via `termlink remote inject`, capture the response in this task, and let the consumer (003-NTB-ATC-Plugin) make the final hosting decision based on what comes back. The framework does not interpret, summarize, or filter — it routes and records. That preserves authority boundaries while still moving the consumer's question forward.

This corrects the earlier misjudgement (NO-GO/decline). Being the wrong addressee does not require closing the door — it just requires not pretending to be the answerer. Relaying preserves audit trail (questions and response live in this task), avoids latency from making the consumer re-route manually, and exercises a useful primitive (cross-fleet question-relay) the framework already has via TermLink fleet topology.

Evidence:
- Pickup envelope: `.context/pickup/processed/P-004-feature-proposal-from-ntb-atc.yaml`
- ring20-management hub reachable: `termlink fleet status` shows `192.168.10.122:9100 UP` with session `tl-chh52mlp` (single ready PTY-backed session).
- Saved hub profile: `~/.termlink/hubs.toml` has `ring20-management` profile with secret-file authentication — `termlink remote list ring20-management` succeeds.
- Five questions to relay (verbatim from envelope): host suitability, deployment pattern (registry/IaC/CI-CD), external reachability (DNS/Traefik/TLS), auth integration, policies/blockers.

Alternatives considered (this round):
- *NO-GO (initial recommendation)*: rejected after user pushback — declining is correct on authority but wrong on usefulness. Framework can mediate without authoring.
- *GO + framework-side advisory*: rejected — framework has Traefik routes in `deploy/` but no fleet-wide hosting policy authority. Drafting advice the framework cannot enforce would be the worst of both worlds.
- *DEFER + tell consumer to re-issue*: rejected — adds a hop the framework can avoid by relaying directly. Consumer's 003-NTB-ATC-Plugin agent does not yet have a saved profile for ring20-management; framework already does.

Next steps (this task):
1. Inject the five questions to `tl-chh52mlp` on ring20-management hub (logged in Updates).
2. Watch for response via `termlink remote pty output ring20-management tl-chh52mlp --lines 200`.
3. Capture response verbatim in a "## Response from ring20-management" section.
4. Update Recommendation to GO/NO-GO based on response (or leave DEFER if no response within ~24h).

**Date**: 2026-04-26T17:24:24Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-26T14:46:42Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** This pickup envelope asks for Ring20 hosting topology advice (host selection, registry pattern, reverse-proxy routing, TLS provisioning, identity federation). None of those domains are owned by this framework — they live with ring20-management (.122). The framework's role is governance over agentic engineering workflows, not infrastructure decisions. Furthermore, the envelope's 1-day time-box expired on 2026-04-20; it is six days stale. Acting now would either (a) require relaying to ring20-management — adding latency and losing accountability — or (b) fabricating advice without grounding. Neither serves the consumer. The cleanest answer is to decline as misrouted and let the consumer re-issue directly to ring20-management or accept the YellowTwig Azure alternative their architect already proposed.

### 2026-04-26T14:46:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8e04fe26
- **Timestamp:** 2026-06-02T14:57:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
## Response from ring20-management

**Source:** ring20-management agent (192.168.10.122), session `tl-chh52mlp`
**Captured:** 2026-04-26T15:31:00Z (one-shot claude -p against the relay prompt, run from the proxmox-ring20-management project root)
**Response length:** 9332 bytes; canonical text below (the agent's own Markdown — no editing). A fragment of an alternative ending also appeared after the canonical answer; preserved on the relay machine but excluded here because mid-sentence and superseded.

---

# Hosting advice for 003-NTB-ATC-Plugin / T-045 — Ring20 reply

**From:** ring20-management (192.168.10.122) · **Date:** 2026-04-26 · **Status:** stale time-box noted; answering best-effort.

Evidence cited from the ring20-management project's `.context/infra/*.yaml` and `.fabric/components/*.yaml` (snapshot 2026-04-15). Anything ring20-management could not substantiate is flagged "needs more info" rather than guessed.

### 1. Which Ring20 host(s) are suitable for this workload?

**Recommended host: Docker Swarm cluster.** Three nodes already configured:

| Role | CT | IP | Node |
|---|---|---|---|
| Manager | 301 (`docker-manager`) | 192.168.10.201 | proxmox |
| Worker | 302 (`docker-worker-1`) | 192.168.10.202 | proxmox2 |
| Worker | 303 (`docker-worker-2`) | 192.168.10.203 | proxmox3 |

Headroom is fine for ~256 MB / 1 vCPU each (cluster has 19 services / 1 degraded today; manager at 21% CPU, 3 GB / 16 GB used).

**Containers vs processes:** containers (the swarm is the standard pattern). Ship as two services in one stack. Co-location with existing services is fine — no isolation reason to spin up a dedicated VM for this footprint. Precedent CT 171 `nooteboom-plugin` exists for a Nooteboom-adjacent service in its own LXC, but documented only as "Plugin — rebuildable from code"; ring20-management cannot confirm shared code with this consumer. For a dedicated LXC instead of swarm services, `proxmox4` has the most slack (62.7 GB RAM, 9% used).

### 2. What is the standard Ring20 deployment pattern?

- **Registry:** internal Docker registry on the swarm manager at `192.168.10.201:5000`. *Insecure registry — HTTP, no auth.* Existing services pull from it (e.g. `192.168.10.201:5000/grafana/grafana:9.5.9`). Push from a build host on the LAN. **No GHCR / Docker Hub / OneDev container registry in active use** — OneDev runs on port 6610 as the SCM/CI; no registry plugin enabled.
- **IaC:** Docker Compose v3.8 stacks deployed via `docker stack deploy -c docker-compose.yml <stack>`. Stack files under per-stack dirs on the manager. No Helm, no Nomad.
- **CI/CD:** OneDev exists at port 6610 but **no evidence** of a working pipeline that builds .NET → pushes to `:5000` → triggers `stack deploy`. Today's deployments look manual (SSH to manager, `docker stack deploy`). Treat CI/CD as "build on your laptop, push to registry, deploy by hand" until confirmed otherwise.

### 3. External reachability for WPF AddIn clients

**This is the part with real friction. Read carefully.**

- **DNS namespace:** the deployed wildcard is `*.ring20.geelenandcompany.com` (Technitium DNS, primary 192.168.10.20 / secondary 192.168.10.21). It is **not** plain `*.geelenandcompany.com`. Hostnames will look like `novis-soap.ring20.geelenandcompany.com` and `novis-rest.ring20.geelenandcompany.com`.
- **Reverse proxy:** Traefik (primary VM 152 = 192.168.10.51, secondary VM 153 = 192.168.10.53). Providers: Docker labels + file + a Proxmox plugin. 65 routers active today. To request a route, the operator-side workflow is:
  ```
  ssh -J root@192.168.10.180 root@192.168.10.51 expose-service novis-rest.ring20.geelenandcompany.com public
  ```
  This syncs to the secondary. Routing for swarm services is normally Docker-label-based on the manager.
- **TLS:** **here be dragons.** Proxmox node certs are self-signed (valid until 2028). The previously-used Let's Encrypt wildcard expired and was not re-automated; T-103 in the task log says "fall back to regenerated self-signed pve-ssl.pem." ring20-management found **no working ACME / certbot / cert-manager / Traefik certResolver** currently issuing trusted certs for `*.ring20.geelenandcompany.com`. Pinning a self-signed cert into a WPF AddIn distributed to Nooteboom engineer laptops is a non-starter. **Before this consumer's services are externally reachable with valid TLS, someone has to set up Let's Encrypt DNS-01 for the wildcard.**
- **Public ingress:** going public also requires a port-forward on the upstream FritzBox. Without it, "public" in `expose-service` resolves only inside the LAN.

### 4. Auth integration

- **Ring20 has no local IdP.** No Authelia, Authentik, Keycloak, OIDC broker found in the services inventory, decisions log, or the swarm. Federating with the yellowtwig.nl Azure AD tenant is the simplest path — there is nothing here to federate *with*.
- **Device-code flow:** correct, no callback URI is required at the relying party. The REST proxy validates Azure-issued JWTs; the WPF AddIn obtains them via device code talking directly to Azure. Traefik's role is purely TLS termination + path routing — no auth middleware needed in front. **No reverse-proxy callback config is required.**

### 5. Policies / blockers

- **.NET Core 10 specifically:** no policy in the project context constrains runtime choice. The fleet today runs Python, Go, Node, and shell — no .NET workloads. The consumer will be the first .NET tenant. Verify the base image (e.g. `mcr.microsoft.com/dotnet/aspnet:10.0`) pulls cleanly from the build host *before* pushing to the internal registry.
- **Compliance:** no compliance documentation in this repo. This is a personal/SMB-scale homelab cluster on a residential ISP, not a managed datacentre. If Nooteboom has any contractual data-residency / availability / audit requirements for the AddIn backend, Ring20 will not meet them.
- **Logs/metrics:** Prometheus + Grafana deployed (CT 301, ports 9090 and 3100); scrape config in the monitoring stack. **No Loki / Promtail / centralised log ingestion** currently. New-service expectation is "expose `/metrics` so Prometheus can scrape, log to stdout and rely on `docker service logs`."

### Recommended next step for the consumer

**Defer to YellowTwig Azure for any deployment intended for Nooteboom engineer-laptop clients.** Three concrete reasons drawn from the evidence above, not from preference:

1. **TLS gap.** No working ACME automation for `*.ring20.geelenandcompany.com`. Distributing a WPF AddIn that has to trust a self-signed cert across Nooteboom laptops is operationally hostile.
2. **Identity gap.** The OAuth2 IdP is already in Azure (`yellowtwig.nl` tenant). Hosting the resource server on Ring20 puts it on a different operational boundary from its identity authority for no architectural gain.
3. **Availability profile.** Ring20 is a 4-node homelab on residential broadband behind a FritzBox. External clients reach it via either WireGuard VPN (5-peer cap, CT 107) or Traefik + manual port-forward. Neither matches what an external engineering team will assume "the API is up" means.

**Ring20 is a reasonable host for prototyping or dev/test** — same swarm, same registry, same Traefik pattern as everything else here, ~30 minutes of operator work to expose a new service internally. If the consumer wants a sandbox endpoint at e.g. `novis-rest.ring20.geelenandcompany.com` reachable from inside the LAN or via WireGuard, that is straightforward. **For the production AddIn backend, take Marc's offer.**

If the consumer disagrees and wants to proceed on Ring20 for production anyway, ring20-management would need: (a) acceptable TLS strategy (do they accept setting up DNS-01 LE wildcard, who owns the DNS API token), (b) target hostnames, (c) whether device-code-issued tokens are scope-restricted such that the proxy's audience claim is well-defined, (d) expected RPS / data sensitivity / retention.

---

**End of relay reply.** ring20-management has not modified any files in this repo; the source consumer task lives at `003-NTB-ATC-Plugin / T-045` and any acceptance / closure should happen there.

### 2026-04-26T17:24:24Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — mediation completed; relay response captured (see "## Response from ring20-management" below)

Outcome (after relay): ring20-management answered all five questions with concrete fleet evidence (Docker Swarm cluster topology, registry endpoint, Traefik routing path, DNS namespace correction `*.ring20.geelenandcompany.com` not `*.geelenandcompany.com`, and three concrete reasons to defer the production AddIn backend to YellowTwig Azure). The framework's job on T-1499 is done: the question reached the right authority, the answer is captured verbatim in this task file, and the consumer (003-NTB-ATC-Plugin / T-045) now has actionable information they can decide on. Closing this task as GO does NOT make the consumer's hosting decision — that remains in 003-NTB-ATC-Plugin's queue.

Original Recommendation (preserved for audit): DEFER pending ring20-management response (relay via TermLink). Replaced now that the response has landed.

Rationale (revised after user pushback on initial NO-GO): The framework cannot author Ring20 hosting advice — that authority lives with ring20-management — but it CAN mediate without claiming authority. Relay the consumer's five questions verbatim to ring20-management's TermLink session (`tl-chh52mlp` on `192.168.10.122:9100`) via `termlink remote inject`, capture the response in this task, and let the consumer (003-NTB-ATC-Plugin) make the final hosting decision based on what comes back. The framework does not interpret, summarize, or filter — it routes and records. That preserves authority boundaries while still moving the consumer's question forward.

This corrects the earlier misjudgement (NO-GO/decline). Being the wrong addressee does not require closing the door — it just requires not pretending to be the answerer. Relaying preserves audit trail (questions and response live in this task), avoids latency from making the consumer re-route manually, and exercises a useful primitive (cross-fleet question-relay) the framework already has via TermLink fleet topology.

Evidence:
- Pickup envelope: `.context/pickup/processed/P-004-feature-proposal-from-ntb-atc.yaml`
- ring20-management hub reachable: `termlink fleet status` shows `192.168.10.122:9100 UP` with session `tl-chh52mlp` (single ready PTY-backed session).
- Saved hub profile: `~/.termlink/hubs.toml` has `ring20-management` profile with secret-file authentication — `termlink remote list ring20-management` succeeds.
- Five questions to relay (verbatim from envelope): host suitability, deployment pattern (registry/IaC/CI-CD), external reachability (DNS/Traefik/TLS), auth integration, policies/blockers.

Alternatives considered (this round):
- *NO-GO (initial recommendation)*: rejected after user pushback — declining is correct on authority but wrong on usefulness. Framework can mediate without authoring.
- *GO + framework-side advisory*: rejected — framework has Traefik routes in `deploy/` but no fleet-wide hosting policy authority. Drafting advice the framework cannot enforce would be the worst of both worlds.
- *DEFER + tell consumer to re-issue*: rejected — adds a hop the framework can avoid by relaying directly. Consumer's 003-NTB-ATC-Plugin agent does not yet have a saved profile for ring20-management; framework already does.

Next steps (this task):
1. Inject the five questions to `tl-chh52mlp` on ring20-management hub (logged in Updates).
2. Watch for response via `termlink remote pty output ring20-management tl-chh52mlp --lines 200`.
3. Capture response verbatim in a "## Response from ring20-management" section.
4. Update Recommendation to GO/NO-GO based on response (or leave DEFER if no response within ~24h).

### 2026-04-26T17:24:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
