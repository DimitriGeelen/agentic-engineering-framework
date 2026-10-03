Reviewed HEAD `39d09dd15140dd2f9828ae650277915e44b54400`, which includes `2a39cffe5`. **The round-3 finding is closed, but AC4 remains NOT MET because other spellings bypass the boundary gate.**

| Acceptance criterion | Result | Evidence |
|---|---|---|
| AC1 — RCA with three dated recurrences | **MET** | Task `## RCA` records October 1 and two October 3 recurrences, root cause, structural causes, and prevention. |
| AC2 — Credential location per backend, never a value | **MET** | All six [registry blocks](/opt/999-Agentic-Engineering-Framework/policy/review-backends.yaml:56) contain credential metadata and pass validation. OpenRouter names the required variable/file; CLI backends identify their authentication sources. |
| AC3 — One resolver, environment/file fallback, confidentiality, runner use | **MET** | [Resolver](/opt/999-Agentic-Engineering-Framework/lib/review_credential.py:278) implements environment precedence and registered-file fallback. In-memory probes confirmed both, sanitized missing-value errors, multiline refusal, and literal output masking. The task documents `--exec` as the runner interface; no existing paid-seat runner requires rewiring. |
| AC4 — Exactly registered files, resolver-only, read-only exemption | **NOT MET** | The strict exemption is fixed, but surrounding quote stripping lets direct reads and writes escape classification. See finding below. |
| AC5 — CLAUDE.md, learning, concern | **MET** | Required guidance appears in [CLAUDE.md](/opt/999-Agentic-Engineering-Framework/CLAUDE.md:1722), [L-691](/opt/999-Agentic-Engineering-Framework/.context/project/learnings.yaml:5083), and [OBS-597](/opt/999-Agentic-Engineering-Framework/.context/concerns.yaml:1678). |
| AC6 — Tests for fallback, clear errors, confidentiality | **MET** | [Tests](/opt/999-Agentic-Engineering-Framework/tests/unit/t3766_review_credential.bats:115) cover empty-environment fallback and missing-value diagnostics; approved-child output masking is covered at line 206. Independent in-memory probes confirmed the core behaviors. |

**Round-3 verification:** The [strict grammar](/opt/999-Agentic-Engineering-Framework/agents/context/check-project-boundary.sh:460) rejected plain `--exec`, `'--exec'`, `--ex""ec`, and `--ex\ec` with a child `--source`. Each produced zero exemption spans and `BLOCKED`. The absolute resolver control produced `SAFE`. Assignment/env prefixes, subshell wrapping, here-string input, and relative resolver paths were also rejected.

**High-severity finding: direct credential access survives alternative path spellings.** The [quote stripper](/opt/999-Agentic-Engineering-Framework/agents/context/check-project-boundary.sh:190) removes quoted arguments before both write and read detection. The classifier also fails to normalize escaped or relative paths.

Using HEAD’s actual Python classifier, with registry discovery replaced by the registered path and worktree discovery by an empty list, produced these results. These are command-text probes, not executed commands:

| Probe | Classifier |
|---|---|
| `cat /root/.litellm-openrouter.env` | `BLOCKED` |
| `cat "/root/.litellm-openrouter.env"` | **`SAFE`** |
| `cat /roo\t/.litellm-openrouter.env` | **`SAFE`** |
| `cat ../../root/.litellm-openrouter.env` from the project root | **`SAFE`** |
| `cat <<< "$(cat /root/.litellm-openrouter.env)"` | **`SAFE`** |
| `printf x > "/root/.litellm-openrouter.env"` | **`SAFE`** |

A sanctioned resolver invocation followed by `&& cat "/root/.litellm-openrouter.env"` also returned `SAFE`.

These are pre-existing classifier weaknesses, not incorrect exemption spans introduced by the round-3 fix. Nevertheless, they defeat AC4: a same-user shell can read the credential without resolver masking or target it for writing. The approved-child encoding residual does not explain these cases; they require no resolver execution or paid approval.

For symlinks, the resolver’s [component-by-component opens](/opt/999-Agentic-Engineering-Framework/lib/review_credential.py:215) apply `O_NOFOLLOW` to parent and final components. I found no resolver symlink bypass. I also found no additional direct resolved-value disclosure in the resolver’s ordinary output path.

Fix the boundary classifier to preserve and interpret path arguments, including quotes, escapes, relative paths, and substitutions. Add regression cases with an absolute resolver control and quoted sibling reads/writes.

No real credential was read or modified. Bats and `fw handover --commit` were not run because this session prohibits filesystem writes.

VERDICT: FAIL