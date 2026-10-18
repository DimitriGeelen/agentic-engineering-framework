# T-4299 — Standing greenfield orchestrator (inception)

**Question:** should AEF own a standing greenfield test orchestrator — a scripted container smoke on every merge to
master, and the full agent-driven greenfield run as a release gate — and if so, in what shape?

**Origin:** operator proposal (Dimitri, 2026-10-18), relayed by dimitri-mint-dev (msg 0da7b1cc), asking AEF to open
this inception with him.

## The proposal (as relayed)

1. **Two levels.**
   - (a) A scripted smoke test, no agent, on every merge to master: minutes, no credential. Exists today as
     dimitri-mint-dev `docs/proposals/testbed/s1-smoke-inside.sh` (ubuntu:24.04, no mounts, 3m25s, one VERDICT
     line per fix).
   - (b) The full agent-driven greenfield run as a RELEASE GATE on every release candidate (about 45 min of model
     time).
2. **Isolation:** a throwaway container or VM per run, never the operator workstation. Several OS images later
   (Portability).
3. **Regression signal:** diff findings by fingerprint against the previous run: new / fixed / still open.
4. **Their contribution:** the prompt (v2.1, v2.2 next), the findings schema, the headless pre-answers, the run 1-4
   lessons, the container work in progress (their inception T-126). They stay the field site until AEF's runner
   exists.
5. **Open design question:** Claude Code auth inside the sandbox. Their recommendation: a dedicated revocable token
   from `claude setup-token`, passed at run time, never in the image. Operator has not chosen.

## Evidence so far

- Run 3 (2026-10-17, master 704c9988): 49 findings. Run 4 (2026-10-18, bleeding-edge fb8caf3b3): 46 findings,
  3 blockers (F-20 auto-init in a non-project cwd, then F-21 hooks live mid-session, then F-25 boundary gate blocks
  the real target), a security finding (F-34: UFW rule to Anywhere for a loopback bind, T-4297). AEF's own unit
  suite (about 11,000 tests) saw none of these: nothing exercises install.sh + fw init + a first session end to end
  on a clean machine.
- Run 4 changed the operator workstation: a UFW rule, rewritten ~/.local/bin, an accidental project from F-20.
  Workstation noise: 31 doctor WARNs vs 6 in a clean container.
- The v1.8.11 field evidence report (docs/reports/field-test-v1.8.11-results.md, round 6) shows the run is also
  the strongest per-fix field test available: 9 fixes verified WORKS in one run.
- **Container spike done (dimitri-mint-dev T-126, msg 65d06812, 2026-10-18).** Level 2 (full, with an agent) in a
  throwaway ubuntu:24.04 container, no mounts: 8 m 37 s total (install 205 s, fresh session 283 s), 19 findings,
  no host side effects. Level 1 (scripted, no credential): 3 m 25 s. Auth: a dedicated `claude setup-token` token
  passed only via `docker exec --env-file`, never in the image; the record is grepped for the token before keeping.
  It found a blocker no workstation run could see: Watchtower cannot start on a clean machine (markdown2 missing,
  PEP 668 blocks pip) → T-4304. Their recommendation for IW-2: Docker on the runner host, dedicated token fetched
  from Infisical at run time; a VM only later, for other OS images. Scripts on their side:
  docs/proposals/testbed/{s1-smoke-inside.sh, s2-full-inside.sh}, plus a 14-line host runme.
- **Runner handed off (dimitri-mint-dev T-127, msg 71143abf, 2026-10-18).** Packaged at
  tools/greenfield-testbed/ in their repo (README, Dockerfile with prereqs and Claude Code, no credential and
  deliberately no markdown2; run.sh host runner; level-1 and level-2 inside scripts; infisical-token.sh; fpdiff.py
  with 7/7 tests). Verified on .107: L1 137 s, 8 VERDICT lines, no containers left; L2 with a token file 315 + 345 s,
  26 findings, leak-clean; L2 with the token fetched from Infisical 765 + 311 s, 32 findings, leak-clean (slot
  aef-testbed/prod/CLAUDE_CODE_OAUTH_TOKEN, read-only identity set up by ring20 T-2404; any other runner gets its own
  identity). Token only in a mode-600 temp env file for one `docker exec`; records grepped for it; unpacked records
  defused (.framework.yaml and .claude renamed) because of the T-4317 trap. Limits: no TermLink in the container, one
  OS image, open outbound network.
- **Finding for IW-3 (fingerprints).** Two L2 runs of the SAME build diffed as "new 31 | fixed 25 | still open 1":
  mostly the same defects under different fingerprints, because each agent computed them differently. Agent-written
  fingerprints are not stable. Their proposal: a tool computes the fingerprint deterministically from a recorded
  field (normalise the first error line, sha1, step:surface:hex); the agent never writes it. Level-1 VERDICT diffs are
  deterministic today.

## Agent recommendation (initial; to be refined in dialogue)

GO for (a) now: cheap, credential-free, catches install regressions per merge. GO for (b) as a release gate once the
operator decides the sandbox auth question. Open for the dialogue (IW-1..IW-3 in the task): runner host and
image(s); where results land (findings topic, field report); fingerprint diff tooling; cost and time per release
for (b); who triages findings.

## Dialogue Log

- 2026-10-18 — proposal received from the operator via dimitri-mint-dev; inception opened, awaiting the dialogue.
- 2026-10-18 — observed while opening it: the G-067 open-questions gate requires IW questions before the C-001
  research artifact can be written (the order conflict dimitri-mint-dev filed as run-3 F-44).
- 2026-10-18 — dimitri-mint-dev reports the container spike (above). It answers IW-1's feasibility and timing
  question with measurements and gives a concrete IW-2 proposal; IW-2 (which credential, where it lives) stays the
  operator's decision.
