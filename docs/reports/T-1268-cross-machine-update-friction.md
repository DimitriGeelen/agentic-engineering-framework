# T-1268: Cross-machine update propagation friction — research artifact

**Status:** Inception in progress (started-work 2026-04-23)
**Owner:** agent
**Linked task:** `.tasks/active/T-1268-cross-machine-update-propagation-frictio.md`

## Problem (recap)

Agents detect drift in artefacts that sit outside their current project boundary but cannot self-heal it. Two recurrences in session 2026-04-15:

1. Global `/root/.agentic-framework` install — boundary gate blocked cross-repo `fw update`. Agent had to hand `cd /root && /root/.agentic-framework/bin/fw update` back to the human.
2. TermLink binary update needed `cargo` on target host. Host lacked cargo, so agent could pull source (0.9.400 → 0.9.872) but not rebuild. Workaround: build elsewhere, scp in.

The boundary gate is correct. The question is what affordance replaces the blocked action so drift actually closes instead of being handed off indefinitely.

## Spike A — Completion rate of copy-pasteable update commands

**Method:** Grep the bypass log + handover archive for "copy-pasteable" patterns and measure how often the user followed through (subsequent commit / doctor improvement).

(Findings populated below as evidence is collected.)

## Spike B — Boundary-blocked actions surfaced in fw doctor / fw audit

**Method:** Search for `boundary` / `cross-repo` / `not in current project` strings across the framework codebase and count distinct call sites.

(Findings populated below.)

## Spike C — TermLink binary distribution options

**Options enumerated:**
- C1: GitHub Releases prebuild matrix (linux-x86_64, linux-aarch64, darwin-x86_64, darwin-aarch64). User downloads platform-appropriate tarball.
- C2: Homebrew formula with bottle (already exists for macOS — extend to Linux via Linuxbrew).
- C3: `cargo install --git` with documented "cargo required on every target" caveat (status quo).
- C4: Self-extracting installer script — `curl ... | bash` that detects platform and pulls the right release artefact.
- C5: Container/OCI image — `docker run` style execution; orthogonal to per-host install.

(Trade-off matrix populated below.)

## Spike D — "Pending updates" registry design

**Sketch:** When agent detects drift it cannot fix in place, append to `.context/working/pending-updates.yaml` with: command, rationale, target host, detected-at, last-reminded-at. `fw doctor` surfaces unresolved entries; Watchtower renders one-click copy. A 24h timer auto-pings via push notification (T-notify).

## Spike E — Cross-machine dispatch via TermLink remote exec

**Sketch:** Replace "build elsewhere, scp in" with `termlink remote exec <host> "cargo install --path crates/termlink-cli"`. Requires termlink running on target. For framework upgrades: `termlink remote exec <host> "cd /opt/<project> && .agentic-framework/bin/fw update"`. Authority model: agent on host A must hold task context that authorizes mutation on host B; gate enforced symmetrically.

## Dialogue Log

(Populated as exploration produces decisions.)

## Recommendation

(Drafted after spikes complete.)
