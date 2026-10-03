Three acceptance criteria are **MET**; three are **NOT MET**. Round 1 fixes address several original examples, but confidentiality, resolver-only boundary access, and single-use approval guarantees remain incomplete.

I reviewed the brief, Round 1 report, implementation, and tests, and ran synthetic, in-memory probes. No real credentials were read. Bats suites and `fw handover --commit` were not run because this session permits only filesystem reads.

| Acceptance criterion | Result | Evidence |
|---|---|---|
| AC1 — RCA with three dated recurrences | **MET** | The [task RCA](/opt/999-Agentic-Engineering-Framework/.tasks/active/T-3766-rca-agents-repeatedly-ask-the-operator-f.md:276) records October 1 and two October 3 recurrences, root cause, structural causes, and prevention. |
| AC2 — Credential location per backend, never a stored value | **MET** | All six entries in [review-backends.yaml](/opt/999-Agentic-Engineering-Framework/policy/review-backends.yaml:45) contain credential metadata. OpenRouter has the required variable/path; CLI backends name their authentication sources. The checked-in blocks contain no credential values. |
| AC3 — One resolver, fallback, never printing values, runner use | **NOT MET** | Env/file fallback exists, but diagnostic disclosure and arbitrary-child exfiltration remain possible. See findings below. Runner use is a documented launch convention; the [task decision](/opt/999-Agentic-Engineering-Framework/.tasks/active/T-3766-rca-agents-repeatedly-ask-the-operator-f.md:355) states there is no committed paid-seat runner to integrate. |
| AC4 — Exact registered-file exemption, resolver-only and read-only | **NOT MET** | The exemption checks executable spelling, not identity or effective working directory. Two spoofed invocations returned `SAFE` in classifier probes. |
| AC5 — CLAUDE.md, learning, concern | **MET** | Required guidance appears in [CLAUDE.md](/opt/999-Agentic-Engineering-Framework/CLAUDE.md:1722), [L-691](/opt/999-Agentic-Engineering-Framework/.context/project/learnings.yaml:5083), and [OBS-597](/opt/999-Agentic-Engineering-Framework/.context/concerns.yaml:1678). |
| AC6 — Tests establish fallback, clear errors, no stdout/stderr disclosure | **NOT MET** | [Tests](/opt/999-Agentic-Engineering-Framework/tests/unit/t3766_review_credential.bats:106) cover ordinary fallback/error/masking cases, but the unconditional confidentiality claim remains false. New tests omit the reproduced unknown-field disclosure. |

The remaining security findings are:

1. **Validation still discloses credential-shaped text.**  
   [validate_credential](/opt/999-Agentic-Engineering-Framework/lib/review_credential.py:80) interpolates unknown mapping keys into diagnostics using both `{k!r}` and `credential.{k}`. Supplying a synthetic credential as a mapping key reproduced it in the returned error; `load_registry` propagates that diagnostic to CLI stderr. The fix protects rejected `source` values, but does not justify the brief’s claim that validation prints only field names/indices.

   Ordinary resolved values are masked in child stdout/stderr and injected through the environment, not initial argv. However, the arbitrary child can encode output, write unmasked logs, or put the value into descendant process arguments. Those channels remain unrestricted, as the module docstring acknowledges.

2. **The boundary exemption remains usable by an unrelated executable.**  
   With the registered-file set supplied in memory, the actual Python classifier produced:

   ```text
   PATH=/tmp fw review credential openrouter --source /root/.litellm-openrouter.env
   → SAFE

   cd /tmp && bin/fw review credential openrouter --source /root/.litellm-openrouter.env
   → SAFE
   ```

   An attacker-controlled `/tmp/fw` or `/tmp/bin/fw` can interpret that argument as a read or write target. [The exemption](/opt/999-Agentic-Engineering-Framework/agents/context/check-project-boundary.sh:458) accepts these spellings without resolving executable identity. Thus access widens beyond resolver reads, although the exempt token itself still must match a registered filename.

   Controls behaved correctly: direct `cat`, `../../tmp/fw`, child-command `--source`, and direct output redirection were blocked.

3. **Registry trust still permits retargeting and has a remaining Git-error fallback.**  
   [committed_credentials](/opt/999-Agentic-Engineering-Framework/lib/review_credential.py:148) treats any failed `rev-parse --verify -q HEAD` following failed `ls-tree` as an unborn repository. A mocked sequence of successful discovery followed by two operational Git failures returned `None`, enabling working-tree credential fallback. It did not refuse.

   A committed credential edit also remains sufficient to authorize a new location, without human approval. Nontracked/non-Git registries use mutable metadata. Consequently, an edit can select another qualifying `NAME=VALUE` file and deliver its selected value to a child for exfiltration. This is bounded by file checks and parsing; it is **not an arbitrary whole-file dump**. OpenRouter execution still requires a proposal, but credential metadata can also be attached to an internal backend.

4. **Approval consumption is sequentially effective but not atomic.**  
   Paid `--exec` still requires an approved proposal: my no-proposal probe returned failure without launching a child. The resolver now logs consumption before launch.

   However, [log_cost](/opt/999-Agentic-Engineering-Framework/lib/review_cost.py:388) checks consumption and appends separately, without locking. An in-memory concurrency probe exercising the real function recorded **two successful uses of one proposal**. Two concurrent executions can therefore pass before either records consumption.

Every Round 1 fix was assessed:

| Round 1 item | Assessment |
|---|---|
| 1a — Multiline masking | **Fixed for the reported env-value case.** `_single_line` rejects LF, CR, and tab; synthetic probes confirmed refusal. Ordinary single-line output was masked. |
| 1b — Validation/YAML disclosure | **Partially fixed.** Rejected source values and CLI YAML diagnostics are sanitized. Unknown mapping keys still leak. |
| 2a — Arbitrary executable named `fw` | **Partially fixed.** Original relative/absolute examples are rejected; PATH and changed-directory variants remain accepted. |
| 2b — Child `--source` exemption | **Fixed.** Scanning stops at `--exec`; the original child-argument case was blocked. |
| 3a — Git failure fallback | **Partially fixed.** Discovery errors and missing Git with a `.git` ancestor refuse. HEAD-operation failures can still trigger fallback. |
| 3b — Symlinks/read race | **Partially fixed.** Static parent symlinks are rejected; `O_NOFOLLOW` and descriptor checks protect the final component. A parent can still be replaced between `realpath` and `open`; intermediate components are not pinned. |
| 3c — Committed retargeting | **Unfixed, explicitly documented residual.** Commitment establishes attribution, not authorization. |
| 4 — Approval reuse | **Partially fixed.** Sequential reuse is prevented; concurrent consumption remains possible. |

VERDICT: FAIL