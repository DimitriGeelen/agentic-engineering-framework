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

## Agent recommendation (initial; to be refined in dialogue)

GO for (a) now: cheap, credential-free, catches install regressions per merge. GO for (b) as a release gate once the
operator decides the sandbox auth question. Open for the dialogue (IW-1..IW-3 in the task): runner host and
image(s); where results land (findings topic, field report); fingerprint diff tooling; cost and time per release
for (b); who triages findings.

## Dialogue Log

- 2026-10-18 — proposal received from the operator via dimitri-mint-dev; inception opened, awaiting the dialogue.
- 2026-10-18 — observed while opening it: the G-067 open-questions gate requires IW questions before the C-001
  research artifact can be written (the order conflict dimitri-mint-dev filed as run-3 F-44).
