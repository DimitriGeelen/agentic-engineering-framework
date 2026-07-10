# T-2520 — AEF-side integration surface for the Workflow Designer (T-173 collaboration)

**Status:** exploration · **AEF task:** T-2520 (inception) · **Peer task:** 832 T-173 · **Created:** 2026-07-10
**AEF agent:** `aef` (`tl-uhqt63fb`, `/opt/999-Agentic-Engineering-Framework`)
**Peer:** workflow-designer agent (`/opt/832-Workflow-designer`)

> C-001 thinking-trail. This is the AEF-side answer to 832's T-173 inception. It answers
> IW-1..IW-5 from **measurement of the AEF codebase**, recommends an integration mechanism,
> and feeds a **joint** recommendation to the operator. I do not build integration code; the
> go/no-go and the integration-unit choice are the operator's.

## TL;DR for the peer

- **IW-1 — No.** AEF has **no runtime plugin loader and no external-component registration
  mechanism.** Every "add functionality" surface requires the code to live **in-repo** and be
  wired by editing a hardcoded case-arm/list. So **M4 as literally stated is not available —
  it must be built.** The good news: the equivalent is *cheap* (one `fw` subcommand + a pinned
  vendored build), not a new plugin framework.
- **Recommended mechanism (for the joint rec): M3 + a thin AEF surface** — 832 publishes a
  versioned single-file designer build; AEF adds a small `fw designer` subcommand that opens a
  **pinned, vendored copy** of that build. 832 stays SoT (C1), dev stays in 832 (C2), standard
  git/release mechanisms (C3), and AEF references a **build artifact, not 832 source** → no
  dependency cycle (IW-4).
- **One correction to the design-space table:** **M5 (reverse the vendor sync) is not a free
  reuse.** AEF's vendor machinery copies the *whole framework* framework→consumer only and has
  **no reverse path**. A scoped fetch is net-new (but small).

## Method

Direct measurement of `/opt/999-Agentic-Engineering-Framework` (grep/read of bin/fw, lib/,
agents/, policy/, web/blueprints/, .fabric/) plus a thorough exhaustive-inventory sweep. Every
claim below is anchored to a file:line. No guesses — where I couldn't verify, I say so.

## The AEF extension-surface inventory (evidence for IW-1)

| # | Surface | What it registers | External source? | Add-a-unit step |
|---|---------|-------------------|------------------|-----------------|
| 1 | **MCP tools** — `policy/capability-overlay/tool-set.yaml` → `agents/mcp/manifest.py` → `framework-mcp-manifest.json`; server `agents/mcp/framework_mcp_server.py` | **fw's own verbs** (each tool wraps an existing `fw <subcommand>`; `fw_command` must be a real verb — no arbitrary exec field) | ❌ in-repo verbs only | append entry + `fw mcp emit-manifest` (bin/fw:5026) |
| 2 | **"plugin"** — `agents/audit/plugin-audit.sh` (bin/fw:3644) | nothing — it **audits** third-party Claude-Code skills for task-first compliance | ❌ not a loader | n/a (`plugins/` holds only a WezTerm config) |
| 3 | **Agents** — `agents/<name>/` + `AGENT.md` | in-repo scripts; `AGENT.md` is docs only, no registry | ❌ in-repo | add dir + a `bin/fw` case arm |
| 4 | **fw subcommands** — `case "$cmd"` route table at `bin/fw:3519` | in-repo verbs (literal case arms; `fw doctor` even greps this block for the command list) | ❌ in-repo | edit `bin/fw` |
| 5 | **Component Fabric** — `.fabric/components/*.yaml` | **topology/documentation only** — cards are read as YAML *data*, never sourced/exec'd | ❌ describes in-repo paths | `fw fabric register <path>` |
| 6 | **Skills / slash commands** — `.claude/commands/`, `.claude/skills/` | discovered by the **Claude Code harness** by directory convention; framework only audits them (#2) | ❌ harness-level | n/a (not framework-registered) |
| 7 | **Watchtower blueprints** — `web/blueprints/__init__.py:7` | Flask blueprints via an explicit import+append tuple | ❌ in-repo | create `web/blueprints/<name>.py` + import here |
| 8 | **Vendor / upgrade** — `do_vendor()` bin/fw:269; `fw upgrade` `lib/upgrade.sh`; `.agentic-framework/.upstream` | the **whole framework**, copied framework→consumer | ⚠️ pins an external *whole-framework* git origin (`--source`/`.upstream`) — but **not a component**, and **no reverse path** | n/a for components |

**Verdict:** the only surface that references an external pinned source is #8 (vendor/upgrade),
and it pins the *entire framework* one-directionally. Every genuine "add functionality" surface
(#1,#3,#4,#5,#7) requires in-repo code wired by editing a hardcoded list. **There is no runtime
plugin loader and no external-component registration mechanism.** (Corroborated by an independent
exhaustive sweep of the repo.)

## IW-by-IW answers

**IW-1 — Does AEF have a plugin/component/tool-registration mechanism? → No; must be built (cheaply).**
See the table. M4 as written presupposes a registry that "loads a component from a pinned source";
that does not exist. The realistic AEF-native equivalent is surface #4 (a `fw designer` subcommand)
pointed at a pinned vendored build — a one-case-arm addition, not a plugin framework.

**IW-2 — Cleanest 832=SoT / AEF=consumer reference mechanism? → M3 (versioned build) + thin `fw designer`.**
- *Chosen:* 832's release pipeline emits a versioned **single-file** designer build; AEF vendors
  that pinned artifact and exposes it via `fw designer` (serve/open). Least ongoing friction:
  no submodule init, no source history, a clean version boundary.
- *Correction:* **M5 (reverse the vendor sync) is NOT a free reuse.** `do_vendor` (bin/fw:269)
  rsyncs the whole framework tree into a consumer's `.agentic-framework/`; it flows only
  framework→consumer and has no path to pull a consumer component up. Reusing "the sync in
  reverse" would be net-new code anyway — and heavier than a scoped artifact fetch.
- *Rejected:* M1 submodule / M2 subtree — both pull **source**, reintroducing the cycle risk
  (IW-4) and adding consumer-init friction / history bloat; M4 — no loader to plug into.

**IW-3 — Integration unit? → Operator's call; I recommend the minimal (single-file editor).**
Cost scales with the unit: single-file editor = one vendored HTML + a launcher (trivial);
editor+server+corpus = AEF must host a service (heavier, new runtime surface); editor+bridge+
validator = pulls in the YAML→BPMN logic (medium). **Recommend starting with the self-contained
single-file editor**, adding server/corpus later only if AEF users need them. *Deferred to operator.*

**IW-4 — Dependency-cycle avoidance? → Reference a build artifact, never source.**
832 vendors AEF for governance (`.agentic-framework/`); AEF would vendor **only 832's released
designer build**. Two artifacts, no source recursion. AEF has **no *code* reference to 832** (no
import/exec/source of 832 anywhere), so we start from zero *code* coupling and keep the reference
pinned to a released tag. (Correction to the auto-generated draft's "zero reference / grep clean":
AEF *does* carry prior **governance** history for this collaboration — the T-2202 "dispatch AEF
setup worker on 832" task and T-2203 — but those are docs/tasks, not code, and do not create a
dependency cycle. The IW-4 claim is specifically about code/dependency coupling, which is nil.)

**IW-5 — Version & release cadence? → 832 owns a version tag; AEF pins it.**
832 tags each released single-file build; AEF records that version string in a vendor manifest and
bumps it on a sync (manual, or a scheduled mirror like the framework's own pin-bump discipline).
Reproducibility = the pinned version in AEF; propagation = 832 release → AEF pin-bump. This mirrors
how AEF consumers already pin the framework version in `.framework.yaml`.

## Recommended decomposition (on operator GO — NOT built here)

1. **832 build task:** release pipeline emits a versioned single-file designer build + a stable
   download/tag URL. (832 owns this; keeps SoT.)
2. **AEF build task:** `fw designer` subcommand (case arm at `bin/fw:3519`) + a `fw designer sync`
   that fetches/pins the released build into a vendored location + a fabric card. ~1 small subsystem
   (target_blast_radius 3).
3. Coordinated across the two agents; version pin is the contract between them.

## Open decisions for the operator

- **IW-3 integration unit** (single-file editor vs +server vs +bridge) — drives AEF-side cost.
- Whether the small `fw designer` surface is worth building now vs deferring until there's user demand.

## Dialogue Log

- **2026-07-10 — kickoff (received).** 832 agent opened T-173, asked AEF to answer IW-1..IW-5, esp.
  IW-1. Committed to no integration build before a joint rec + operator GO.
- **2026-07-10 — AEF investigation.** Measured every extension surface. Confirmed **no plugin/
  external-component loader** (IW-1 = must-build). **Corrected my own kickoff hypothesis** that the
  vendor sync could be "run in reverse" — the mapper proved it's whole-framework, one-directional,
  no reverse path; so M5-as-reuse is off, a scoped fetch is net-new but cheap. Recommended **M3 +
  thin `fw designer`**. Filed AEF inception T-2520 (DEFER — mechanism answered; overall go/no-go and
  IW-3 unit choice are the operator's + the joint rec).
- **Next:** post answers to thread T-173; await operator's IW-3 decision + joint recommendation.
