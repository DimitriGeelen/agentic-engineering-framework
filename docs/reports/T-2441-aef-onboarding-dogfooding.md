# T-2441 — AEF Onboarding Dogfooding (live install into /opt/505-Ring20-Site)

**Task:** T-2441 · **Date:** 2026-06-21 · **Source project:** 505-Ring20-Site (greenfield)
**Method:** Ran the operator's 6-step install prompt for real against an empty `/opt/505-Ring20-Site`,
through a TermLink shell rooted in the target (project-boundary-safe). Captured friction at each step.
**Purpose:** antifragile feedback — surface real onboarding friction and feed it back into AEF as
remediation proposals (delivered via `fw pickup` per governance). The new app's own build is separate.

---

## What works (be fair — most of the path is sound)

- `install.sh` **exists** and the prompt's GitHub URL (`.../agentic-engineering-framework/master/install.sh`)
  **matches the real repo**. Install ran clean, exit 0, 79s. Detected 18 vendored consumers; installed to
  `~/.agentic-framework` without touching the dev framework at /opt/999.
- `fw init --provider claude|cursor|generic` **is real** (default `generic`); STEP 3 accurate.
- The bash 4.4+ / git 2.20+ / python 3.8+ floors in STEP 1 **match AEF's actual requirements**
  (`lib/preflight.sh`: associative arrays + nameref need 4.4).
- **`fw init` auto-creates git** — the prompt's STEP 3 self-heal claim is *confirmed true* (ran init before
  `git init`, `.git` was created, no error).
- **5 greenfield onboarding tasks** scaffolded correctly (T-001 health → T-005 first handover).
- STEP 6's governance framing (initiative≠authority, [ASK] gates, approval verbs are the human's) is strong
  and well-aligned with the Authority Model.

---

## Findings (10) — each with evidence + RCA + proposed structural remediation

### F1 — Public install path ships a stale framework  [reliability / inefficiency]
- **Symptom:** GitHub-master `install.sh` delivered **fw v1.6.25**; this machine's dev HEAD is **v1.6.66**
  (~40 patch versions behind). A real new-app onboarder gets a months-old framework.
- **RCA:** `master` on GitHub lags the canonical origin (onedev). The mirror divergence is even surfaced by
  `fw doctor` ("Mirror divergence: 1 ref(s) differ between origin and github"). The public front door is the
  one surface with no freshness guarantee.
- **Remediation:** gate the github mirror push on release; or have `install.sh` warn when the cloned VERSION
  is N behind the latest tag; publish releases as tags and let `install.sh --tag` pin.

### F2 — Installer hands you a shim it calls "legacy"  [usability]
- **Symptom:** install output: `Linked fw → /root/.local/bin/fw (legacy — upgrade for project-local routing)`.
- **RCA:** the global shim predates project-local routing; the message is honest but lands as "you just
  installed something obsolete" on first contact.
- **Remediation:** either install the project-local-routing shim by default, or soften the message to a
  forward action ("after `fw init`, routing becomes project-local automatically").

### F3 — Version reporting is inconsistent and uninformative  [reliability]
- **Symptom:** install reports `fw v1.6.25`; runtime `fw --version` (bare **and** project-local) reports
  **`vdev`**. User cannot tell what version they are on.
- **RCA:** `fw --version` resolves a git-describe/dev fallback instead of the stamped VERSION file.
- **Remediation:** `fw --version` should read the stamped `VERSION` (matching install-time report) and only
  fall back to `vdev` when no VERSION exists.

### F4 — Greenfield `fw init` produces an invalid value-drivers.yaml  [bug]
- **Symptom:** `Validation: 1 error(s) out of 42 checks` on a fresh init →
  `✗ yaml-2bv  BVP value-drivers definitions (T-2229) — missing keys: drivers`.
- **RCA:** the greenfield scaffold for `policy/value-drivers.yaml` omits the required `drivers` key, so
  *every* new project fails its own init validation out of the box.
- **Remediation:** fix the greenfield template to include a valid `drivers:` block (or make `yaml-2bv`
  tolerate the documented greenfield shape). Add a fresh-init bats assertion (sibling to
  `upgrade_fresh_machine_simulation.bats`).

### F5 — Session init fails on the happy path  [bug]
- **Symptom:** `fw init` prints `⚠ Session init failed — run 'fw context init' manually`. The manual recovery
  *does* work (`fw context init` → Pass 8/Warn 1/Fail 0), but the first-run happy path is broken.
- **RCA:** init's inline session activation fails in the greenfield context; the fallback message is the only
  thing keeping onboarding alive.
- **Remediation:** make init's session activation succeed greenfield, or auto-run the recovery instead of
  delegating it to the brand-new user.

### F6 — `fw doctor` is slow  [inefficiency]
- **Symptom:** ~**72s** per run. STEP 4's "fix and re-run" loop compounds it; 3 calls timed out a 120s budget.
- **RCA:** doctor runs the full host+project check set every invocation; no fast/scoped mode.
- **Remediation:** a `fw doctor --quick` (project-only, skip host/network probes) for the onboarding loop.

### F7 — A fresh consumer's `fw doctor` is polluted with host + other-project noise  [usability / reliability]
- **Symptom:** from `/opt/505`, doctor's 8 warnings are mostly **not about /opt/505**:
  `Cron registry edited but not generated: /opt/999-...`, `Mirror divergence origin↔github`,
  `Global install ... 261MB`, `~/.local/bin/fw symlinks to stale /root/.agentic-framework`.
- **RCA:** host-level and global-install checks are interleaved with project checks and not visually
  separated by ownership; a new user cannot tell whether **their** project is healthy.
- **Remediation:** segment doctor output into `[project]` vs `[host]` sections (host block already tagged
  `[host]` — extend it and put project-health first + a one-line project verdict).

### F8 — Bare `fw` routes to the global legacy shim, not the consumer-local fw  [reliability]
- **Symptom:** from inside `/opt/505`, `command -v fw` → `/root/.agentic-framework/bin/fw` (the global shim),
  not `/opt/505/.agentic-framework/bin/fw`.
- **RCA:** this is the **T-1257 hazard live** — the prompt (and a lot of guidance) uses bare `fw`, which on a
  machine with a global install resolves to the global shim rather than the project-local fw.
- **Remediation:** the install/onboarding text should resolve and print the project-appropriate fw path
  (`.agentic-framework/bin/fw` in consumers); or make the global shim always re-exec the project-local fw
  when a `.framework.yaml` is found in the cwd ancestry.

### F9 — Watchtower STEP 5 gives a false-positive health signal  [reliability — silent failure, Directive 2]
- **Symptom:** `fw serve` found default :3000 held by a **foreign service**, correctly **refused to signal it**
  — but then did **not** start /opt/505's Watchtower anywhere. `fw watchtower url` still reports
  `http://192.168.10.107:3000` and `curl` returns **HTTP 200** *from the foreign server*. STEP 5's verification
  ("curl returns 200 → dashboard up") passes while the project's own dashboard never started.
- **RCA:** the url/port resolver falls back to the default port without confirming the answering server is
  *this project's* Watchtower; the "refused foreign port" branch doesn't auto-pick a free port.
- **Remediation:** when the resolved port is foreign, `fw serve` should auto-select a free port (or exit
  non-zero), and `fw watchtower url`/health should verify an identity marker (project root in `/healthz`)
  before reporting reachable.

### F10 — `fw serve` from a fresh consumer misidentifies the project as /opt/999  [bug — project resolution]
- **Symptom:** `fw serve --port 3005` run from `/opt/505` logs
  `Starting Watchtower on port 3005 (project: /opt/999-Agentic-Engineering-Framework)`. PROJECT_ROOT is empty
  (not inherited); yet bare *and* project-local fw resolve Watchtower state to :3000 / the dev framework.
- **RCA (hypothesis, owed to AEF):** the global shim / shared Watchtower triple-file resolves to the
  framework-dev project on this host rather than the cwd consumer — sibling to the inherited/poison
  PROJECT_ROOT class (T-2391/T-2392) and the bare-shim routing (T-1257). On a non-dev host (no /opt/999) this
  specific bleed would not occur, but dogfooding-on-the-dev-host is a real onboarding context.
- **Remediation:** `fw serve`/`fw watchtower` must resolve the project strictly from the cwd `.framework.yaml`
  ancestry, never a host-global default; add a fresh-consumer integration assertion.
- **UPDATE (2026-06-21, T-2445 session — framing CORRECTED):** Reproduced live and **disproved the
  "consumer mis-ID" framing.** A real operator terminal (no `CLAUDE_PROJECT_DIR`) resolves the consumer
  correctly — a fresh `fw init` consumer's `watchtower status` prints "not running" (✓). The /opt/999 bleed
  came from running inside the `aef-install-505` **TermLink shell**, which inherited
  `CLAUDE_PROJECT_DIR=/opt/999` from the long-lived TermLink daemon. The real residual is narrower:
  `bin/fw:195-197` (T-2390) trusts `CLAUDE_PROJECT_DIR` with no cwd-consistency check, so any subprocess of a
  CC-spawned daemon (TermLink, cron) mis-resolves — the daemon-poison class T-2391 fixed for `PROJECT_ROOT`
  but not for `CLAUDE_PROJECT_DIR`. Agent/automation-facing only; never bites real operators. Tracked +
  proposed fix in **T-2446** (`horizon: next`, high-blast core resolver — focused live-fire session). Third
  plan-hypothesis disproven this batch (cf. F5 RCA, F9 plan).

---

## Prompt-vs-design assessment (the install prompt itself)

**Accurate:** install.sh existence + URL, `--provider`, bash/git/python floors, auto-git, STEP 6 governance.

**Gaps vs AEF design:**
1. **Bare `fw` everywhere** contradicts the consumer-path guidance (T-1257 / §Copy-Pasteable Commands). The
   prompt should use `.agentic-framework/bin/fw` for consumer steps, or verify `fw --version` resolves to the
   project-local fw before each step.
2. **No Session Start / End Protocol.** STEP 6 starts work but never runs `fw context init` (working memory)
   or `fw handover` (session end). An agent onboarded by this prompt has no session-lifecycle discipline.
3. **STEP 5 verification trusts curl-200** without confirming the answering server is the project's own (F9).
4. **STEP 2 pipes unpinned `master` with no integrity check** — every other AEF surface is version-disciplined;
   the bootstrap front door has neither a pin nor a checksum (supply-chain-shaped gap).

---

## Proposed remediation grouping (delivered as `fw pickup` proposals — AEF dispositions into inceptions)

- **Bug-report envelope:** F4 (invalid value-drivers), F5 (session-init fail), F9 (false-positive health),
  F10 (project misID). These are correctness defects on the greenfield path.
- **Feature-proposal envelope:** F1 (stale public version), F2 (legacy messaging), F3 (version reporting),
  F6 (`doctor --quick`), F7 (doctor scope segmentation), F8 (shim routing), + the 4 prompt-vs-design gaps.

Pickups are **proposals, not build instructions** (G-020); AEF triage scopes accepted ones into inception
tasks with their own ACs.
