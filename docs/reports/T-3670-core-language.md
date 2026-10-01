# T-3670: Core-module language (inception research artifact)

## Origin
On 2026-10-01, after seven Tier 0 review rounds (T-3593/T-3594), the operator asked: "This brings us to a more flexible question if the language we're using is appropriate. And we should go to, for established core modules, go to a more typed, strict language."

## Two separate problems
1. **Tier 0 is a parsing problem.** Every review round found another shell expansion the hand-written matcher did not model: brace expansion, line continuation, ANSI-C quoting, quote removal, and normalisation collisions. A typed language does not fix this by itself. A REAL bash parser does: the classifier works on the expanded command tree, which closes the class instead of the instance. The best available is mvdan.cc/sh (Go, used by shfmt); Python has bashlex (weaker).
2. **The core's own implementation language is a reliability problem.** The bash failure modes recorded in learnings fail silently (Directive 2 breach):
   - heredoc inside `$(…)` (L-332/L-408);
   - backticks in `python3 -c "…"` (L-528);
   - `set -e` not applying inside `if` conditions (T-3203);
   - `cmd1; cmd2` judged only on cmd2;
   - pipefail/SIGPIPE false reds (L-387);
   - dead `! cmd` assertions (T-3138).
   A typed, strict language turns many of these into compile errors. Hooks fire on every tool call, so compiled-binary latency matters too.

## Agent lean (to be tested in dialogue)
- Established, security-critical core → **Go**: a real bash parser, a single static binary (Directive 4 portability; it helps the P-01 installer), strong typing, fast cold start.
- Everything else stays where it is; Python goes `mypy --strict` for new and touched modules.
- **Pilot:** the Tier 0 classifier, whose ~170 tests plus the round 3-7 review probes are an executable spec.

## Effect on the open Tier 0 decision
The agent revised its recommendation from "one more regex fix round" to: accept the current state with the remaining round-7 findings documented as residuals, deploy the pre-push guard (`fw git install-hooks`), close T-3593/T-3594, and let the parser-based rewrite (this inception's pilot) close the self-approval and normalisation class properly.

## Operator rulings (2026-10-01)
- "Core, core, core, ultra, very high value, a huge impact": start with an architectural assessment and rewrite advice from SEVEN agents (three internal harnesses plus four external).
- **Stage 1 is the question itself:** a sharp question that shapes comparable responses, reviewed before anything goes out. v1 → three-model question review → v2 (docs/reports/T-3670-question-v2.md).
- **Threat model: BOTH** a mistaken cooperative agent AND a determined adversarial one, "as strong as possible". The hooks are one layer; the operator wants a harder mechanism as well. They report that requests to the harness vendor for stronger enforcement have gone unanswered, so the design must list vendor-only gaps as an evidenced request.
- **Agents WILL run as non-root users,** with "a good and frictionless way to allow elevated execution". This is D5 in question v2, and it is consistent with P-01 IW-2 (the installer creates a normal user).

## Reflection after reading back (2026-10-01, the operator asked for it)
- **I framed this too narrowly.** I treated it as "which language for the hooks" because the Tier 0 rounds were in front of me. The operator's original aim is governance that does NOT depend on the harness. PreToolUse hooks are Claude Code's mechanism, and opencode runs none of ours (P-063). Hardening the hooks, in any language, keeps governance tied to one vendor's extension point, and that vendor's own docs say Bash permission rules "aren't a security boundary".
- **The answer was already partly designed, and I didn't look first.** T-2428 (payload mediation, GO June 2026, arc in progress) puts the governance brain in a proxy on the model⟷harness wire, outside the agent's cage, with an OS cage for what the wire cannot see. Its headline mechanic is exactly the operator's "both, as strong as possible". The non-root ruling (D5) and the elevation broker are the cage and its door.
- **The language question changes shape.** It is no longer "rewrite the bash core". It becomes: what do the NEW components (the proxy, the broker, the cage tooling, the parser-based classifier the proxy uses) get written in? And what happens to the hook core: it becomes a thin per-harness adapter, or a defence-in-depth layer. T-586 already decided TypeScript for new components, partly implemented. A polyglot answer may be right: for example the proxy in TS or Go, and a classifier needing a real bash parser where the best parser lives.
- **The Tier 0 seven-round history is evidence FOR the architecture shift,** not just for a better parser. Text classification inside the agent's own trust domain cannot hold against a determined adversary. The external reviewers should say whether that is right.
- **What changed in the question (v3):** harness independence is the primary decision; T-2428 and T-586 are prior decisions to weigh; TypeScript is added; polyglot is allowed.

## Dialogue Log
- 2026-10-01, operator raised the language question (above). The agent separated the parsing problem from the implementation-language problem, proposed Go plus a Tier 0 pilot, and filed this inception with IW-1..IW-5.
