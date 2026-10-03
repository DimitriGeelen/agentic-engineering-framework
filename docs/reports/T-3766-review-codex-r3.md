Five criteria are **MET**; AC4 is **NOT MET**. A quoted `--exec` bypasses the boundary scanner’s child-command cutoff.

I read the brief, both prior reports, implementation, and tests. Verification used synthetic, in-memory probes; no real credentials were read. Bats and `fw handover --commit` were not run because this session prohibits filesystem writes.

| Acceptance criterion | Result | Evidence |
|---|---|---|
| AC1 — RCA with three dated recurrences | **MET** | The [task RCA](/opt/999-Agentic-Engineering-Framework/.tasks/active/T-3766-rca-agents-repeatedly-ask-the-operator-f.md:276) records October 1 and two October 3 recurrences, root cause, structural causes, and prevention. |
| AC2 — Credential location per backend, never a value | **MET** | [Registry](/opt/999-Agentic-Engineering-Framework/policy/review-backends.yaml:45) supplies metadata for all six backends, including OpenRouter’s required variable/path and CLI authentication sources. No credential values are stored in these blocks. |
| AC3 — One resolver, fallback, confidentiality, runner use | **MET** | [Resolver](/opt/999-Agentic-Engineering-Framework/lib/review_credential.py:279) implements environment-first resolution and ordered file fallback. Synthetic probes confirmed fallback, sanitized errors, control-character refusal, and masking. The [runner decision](/opt/999-Agentic-Engineering-Framework/.tasks/active/T-3766-rca-agents-repeatedly-ask-the-operator-f.md:355) establishes `--exec` as the launch interface; no committed paid-seat runner exists to rewire. |
| AC4 — Exactly registered files, resolver-only, read-only exemption | **NOT MET** | [Boundary scanner](/opt/999-Agentic-Engineering-Framework/agents/context/check-project-boundary.sh:470) searches quote-stripped text for literal `--exec`. Quoting that argument lets a child’s `--source` receive the exemption. |
| AC5 — CLAUDE.md, learning, concern | **MET** | Required guidance exists in [CLAUDE.md](/opt/999-Agentic-Engineering-Framework/CLAUDE.md:1722), [L-691](/opt/999-Agentic-Engineering-Framework/.context/project/learnings.yaml:5083), and [OBS-597](/opt/999-Agentic-Engineering-Framework/.context/concerns.yaml:1678). |
| AC6 — Tests for file fallback, clear errors, no value disclosure | **MET** | [Tests](/opt/999-Agentic-Engineering-Framework/tests/unit/t3766_review_credential.bats:106) cover those requirements. Independent synthetic probes confirmed their core behavior. This is not a claim that I reran the Bats suite. |

The remaining finding is a **resolver-only boundary bypass**. Using the actual Python classifier with an in-memory registered-file set produced:

```text
$PROJECT_ROOT/bin/fw review credential openrouter --exec -- tool --source /root/.litellm-openrouter.env
→ BLOCKED

$PROJECT_ROOT/bin/fw review credential openrouter '--exec' -- tool --source /root/.litellm-openrouter.env
→ SAFE

$PROJECT_ROOT/bin/fw review credential openrouter --ex""ec -- tool --source /root/.litellm-openrouter.env
→ SAFE
```

The shell converts both quoted spellings into `--exec`. The resolver consequently passes `--source FILE` to the child, but the boundary scanner exempts it as a resolver argument. That child can interpret the path as a write target. Direct redirections remain blocked; this bypass concerns child-mediated access. Paid approval remains required.

This is distinct from the accepted residual concerning an approved child encoding its credential: **the boundary incorrectly grants a resolver-read exemption to child arguments**. The existing child-cutoff test also uses relative `bin/fw`, so it can pass merely because relative executables are refused. Add absolute-path controls and shell-equivalent quoted/escaped variants.

Every Round 2 fix was assessed:

| Fix | Assessment |
|---|---|
| R2-1 — Unknown credential keys leak | **Fixed.** Synthetic credential-shaped keys produced sanitized diagnostics. |
| R2-2 — PATH/cwd executable spoofing | **Fixed for the reported cases.** Both variants were blocked; the absolute resolver control passed. The separate quoted-`--exec` bypass remains. |
| R2-3a — HEAD failures trigger fallback | **Fixed.** Mocked HEAD failure with existing refs, or failed ref enumeration, refused. Successful empty ref enumeration retained the intended unborn-repository fallback. |
| R2-3b — Parent-component symlink race | **Fixed.** Component-relative opens pin directory descriptors and apply `O_NOFOLLOW` throughout; the final open also uses `O_NONBLOCK`. |
| R2-3c — Internal-backend file credentials and permissive files | **Fixed within the accepted model.** Validation refuses files without approval; synthetic mode checks accepted `0600` and rejected `0644`/writable files. |
| R2-4 — Concurrent approval consumption | **Fixed.** The actual `flock` implementation with an in-memory ledger admitted exactly one of four concurrent consumers. Consumption precedes child launch. |

For the requested confidentiality and retargeting checks:

- **Resolver disclosure:** I found no remaining direct resolved-value leak through ordinary stdout/stderr, diagnostics, cost records, or initial process arguments. Values enter the child environment; output masking covers literal occurrences.
- **Approved-child disclosure:** A child can encode output, write separate logs, or populate descendant arguments. This is explicitly documented and accepted under the stated threat model.
- **Registry retargeting:** Committed edits can select another qualifying private `NAME=VALUE` file. This is documented and bounded by registration, file checks, single-variable parsing, masking, and approval before child execution—not an arbitrary whole-file dump.
- **Paid execution:** Missing approval prevented child launch in an independent probe. Approval consumption is now serialized.

VERDICT: FAIL