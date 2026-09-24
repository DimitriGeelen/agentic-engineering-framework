# Provenance — external review documents

Two of the four external reviews referenced by EWCR Arc 0 (roadmap §4, task 3) live here.
The other two — Claude and Z.ai — were transferred earlier and live as
`architecture-c9070637.md` §17 and §18; they are not duplicated here.

| File | sha256 | Source |
|---|---|---|
| `T-032-deepseek-review-response.md` | `4dae4098b2602b2794525292e1aa3053e0c486b23a67d9c3292ce80dc3a4d8a9` | `/opt/0503-codex-cli-playground/docs/reports/` |
| `T-032-mistral-review-response.md` | `0eecb8af7be56ba045581167ef66b73fd9d2aa17fcd241f84defc0e7d17bfb0e` | `/opt/0503-codex-cli-playground/docs/reports/` |

**Transferred:** 2026-09-24, by the operator running `run-me.sh` at the repository root.

**Hashes verified twice**: by the transfer script at copy time, and independently
afterwards with `sha256sum` against the values 832-Workflow-designer published on the DM
rail `dm:3bba15e681b3a078:d1993c2c3ec44c94` offset 2 and recorded in 0503's own
`docs/reports/T-047-aef-refusal-matrix-disposition.md`. Both match the published values
exactly, so these are byte-identical to the artefacts 832 attested to.

**Why a manual copy.** Two agent-driven attempts failed, in different ways, and both are
worth remembering rather than retrying blind:

1. A dispatched worker rooted in the source project declined to export the documents on an
   authorisation it could not verify from where it stood. That was a correct refusal — the
   first prompt gave it nothing checkable.
2. A second attempt, which handed it the verifiable chain (the source project's own T-040
   and T-047 records, plus the hub messages requesting the transfer), never ran: the model
   API's safeguard classifier flagged the prompt as exfiltration-shaped and blocked it.

So an agent-driven file transfer between two projects of the same operator has no route
today that both the receiving project's boundary gate and the sending side's judgement
accept. The operator in the loop is the route. Recorded on T-3389.

**Correlation:** `arc:ewcr-governed-delivery` (the seam correlation 832's operator ruled on
2026-09-22; `EWCR-ARC0-ATTEST-832` remains readable history for the traffic that carried it).
