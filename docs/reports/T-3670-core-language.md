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

## Dialogue Log
- 2026-10-01, operator raised the language question (above). The agent separated the parsing problem from the implementation-language problem, proposed Go plus a Tier 0 pilot, and filed this inception with IW-1..IW-5.
