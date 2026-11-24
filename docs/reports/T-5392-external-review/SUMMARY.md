# T-5392 external review — summary (2026-11-24)

Lens: AEF is a generic framework vendored into unrelated projects; ring20 is one operator's estate.
Reviewers: codex (OpenAI) and opencode (Z.ai), isolated run, host details stripped from the bundle.
Independence: opencode `independent`; codex `non-independent` (it ran a tool, `exec` marker) — its findings agree with opencode's and are kept, labelled.

**Verdict: NO-GO from both** for the design as built.

## Where they agree
1. ring20/node1 runner and exclusion list sit in vendored `agents/audit/` → every consumer gets them (both HIGH).
2. Defaults hard-code ring20 identities and protocol: hubs, client id, aef2.* entries, aef-unit-2 env, pool-client path, `ring20.pool.stage/1`, feed.health format (both HIGH/MEDIUM).
3. `lib/test-bundle.sh` is a generic capability with node1 assumptions baked in (out path, 64 MB cap, help text, excludes) (HIGH/MEDIUM).
4. Unconfigured consumers need an explicit disabled state: no network, no tool lookup, no audit noise, exit 0 "not configured" (HIGH).
5. Options: none of 1–3 fits as stated. Trial through an operator script (option 3). Never put the wrapper in a vendored path; a project-local pinned copy only. Option 1 (widen read boundary) opens a prompt-injection channel from another party's folder (MEDIUM).
6. Trust: verify the wrapper's sha256 before every run and fail closed; re-pin only by operator action; least privilege; treat pool output as untrusted (HIGH).

## Codex-only findings worth acting on
- **Incomplete runs exit 0** (`not_sent` / `not_collected` with no new failure) — a false green. Give them a non-success status (HIGH, a real defect).
- `build_report()` names the bundled exclusion file even when `--exclude-file` overrides it (MEDIUM).
- The wrapper switch has no proof it keeps the 12-open cap or re-checks health per submission (HIGH).

## Shape both propose
Framework: a generic, optional, off-by-default "remote test pool" runner (select, grade, hold-while-unhealthy, report) driven by an adapter command and project-local config. ring20/node1: this project's local config plus ring20's tooling, outside vendored paths. Cron entry stays local.
