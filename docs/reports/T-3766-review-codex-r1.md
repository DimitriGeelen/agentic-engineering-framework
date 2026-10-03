Three criteria are **MET** and three are **NOT MET**. The resolver leaks multiline values, the boundary exemption extends to child-command writes, and registry trust fails open when Git discovery fails.

I reviewed the implementation and tests and ran read-only, in-memory probes with synthetic values. No real credentials were read. The Bats suites and `fw handover --commit` were not run because this session prohibits filesystem writes.

| Acceptance criterion | Result | Evidence |
|---|---|---|
| AC1: RCA with three dated recurrences | **MET** | The task’s `## RCA` identifies the October 1 recurrence and two October 3 recurrences, explains the missing machine-readable location and boundary obstruction, and describes prevention. |
| AC2: Credential location per backend, never a stored value | **MET** | [review-backends.yaml](/opt/999-Agentic-Engineering-Framework/policy/review-backends.yaml:39) contains credential blocks for all six backends, including the required OpenRouter variable/path and CLI authentication sources. The checked-in blocks contain locations and descriptions, not credentials. Validation has a separate disclosure flaw described below. |
| AC3: One resolver, env/file fallback, never printing values, runner use | **NOT MET** | Env/file fallback exists, but output confidentiality fails. [run_exec / _pump](/opt/999-Agentic-Engineering-Framework/lib/review_credential.py:243) leak multiline environment values. Runner integration is a documented launch convention; the task records that no committed paid-seat runner exists to integrate. |
| AC4: Exact registered-file exemption, resolver-only and read-only | **NOT MET** | [_cred_exempt_spans](/opt/999-Agentic-Engineering-Framework/agents/context/check-project-boundary.sh:442) accepts relative executables merely named `fw` and exempts `--source` arguments belonging to commands **after `--exec`**. The complete boundary Python classifier returned `SAFE` for both cases. |
| AC5: CLAUDE.md, learning, concern | **MET** | Required wording appears in [CLAUDE.md](/opt/999-Agentic-Engineering-Framework/CLAUDE.md:1722); L-691 records the resolver in [learnings.yaml](/opt/999-Agentic-Engineering-Framework/.context/project/learnings.yaml:5083); OBS-597 exists in [concerns.yaml](/opt/999-Agentic-Engineering-Framework/.context/concerns.yaml:1678). |
| AC6: Tests establish fallback, clear errors, and no stdout/stderr value disclosure | **NOT MET** | [t3766_review_credential.bats](/opt/999-Agentic-Engineering-Framework/tests/unit/t3766_review_credential.bats) covers ordinary fallback/error/masking cases, but its single-line fixtures miss a reproduced disclosure. The unconditional no-disclosure requirement does not hold. |

The security findings are:

1. **Multiline values escape stdout/stderr masking.** Environment values are accepted without rejecting newlines ([resolve](/opt/999-Agentic-Engineering-Framework/lib/review_credential.py:220)), but `_pump` replaces the complete secret separately within each line. My probe produced:

   ```text
   Single-line fake value → ****
   FAKE-FIRST\nFAKE-SECOND → FAKE-FIRST\nFAKE-SECOND
   ```

   Both output streams use this function. Additionally, registry validation includes rejected `source` values verbatim in errors: a synthetic `sk-fakecredential123` was reproduced in the diagnostic ([line 87](/opt/999-Agentic-Engineering-Framework/lib/review_credential.py:87)). Malformed YAML can also expose source excerpts through uncaught parser exceptions.

   Ordinary execution places the resolved value in the child’s environment, not its initial argv. However, arbitrary children can write it into logs, pass it to subprocess arguments, or encode it past the mask. Those channels are unrestricted; the docstring acknowledges intentional output exfiltration.

2. **The boundary exemption permits operations beyond resolver reads.** The classifier returned `SAFE` for a relative executable named `../../tmp/fw`, without verifying that it is the framework executable. It also returned `SAFE` for a legitimate resolver invocation whose `--exec` child receives `--source /root/.litellm-openrouter.env` and writes to that path. I supplied this as command text only; no write was executed.

   The exemption scanner does not stop at `--exec`, whereas the resolver parser does. Consequently, it treats a child argument as an authorized resolver read. Direct `cat` of the same path correctly returned `BLOCKED`, establishing the control.

3. **Registry edits can retarget resolution; commitment is not authorization.** Healthy Git discovery rejects uncommitted credential-block edits. But [committed_credentials](/opt/999-Agentic-Engineering-Framework/lib/review_credential.py:117) returns `None` on Git execution errors, timeouts, or unsuccessful discovery, causing fallback to working-tree credentials. A mocked Git-unavailable probe confirmed this fail-open result. Non-Git registries likewise use mutable credentials.

   Committed edits are accepted without operator approval. A retargeted file must satisfy the ownership/mode/size checks and contain the selected `NAME=VALUE`; this is **not** an unrestricted whole-file dump. Nevertheless, a qualifying secret can reach an arbitrary child and be exfiltrated. Final-component symlink checks also do not prevent symlinked parent directories or the race between `lstat` and `read_text`.

4. **Paid `--exec` requires approval, but does not consume it.** [main](/opt/999-Agentic-Engineering-Framework/lib/review_credential.py:302) checks an approved, unconsumed proposal for the selected task/backend before execution. OpenRouter remains pinned paid. However, `run_exec` neither reserves nor consumes the proposal. [open_approval](/opt/999-Agentic-Engineering-Framework/lib/review_cost.py:337) considers it consumed only after a separate cost record exists, allowing repeated executions against one approval until that logging occurs.

VERDICT: FAIL