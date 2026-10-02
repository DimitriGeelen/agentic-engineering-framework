# T-3723: Standing warm reviewer and research agents (inception)

## Origin (operator, 2026-10-02)
> "we're doing a lot of external reviews with our subscriber providers like Codex and Z.ai and also Google Antigravity … we start up the harness every time and need to fully load it up, which costs a lot of tokens … also counts for the Anthropic reviewers … have a standing agent there for reviewing, which in case of Anthropic for instance we limit to 800 or 900k, so keep it warm for a long time. And then push out, inject review questions all the time via sidecar or other TermLink mechanisms."

## Evidence so far
- **Cold-start cost, Claude.** The first turn of every recent dispatch worker writes 85,756–88,371 cache tokens (`cache_creation_input_tokens`) before it reads the question: CLAUDE.md, the tool schemas and the hook preamble. Workers w-t-3693c, w-t-3694, w-t-3694b, w-t-3695, w-t-3696 and w-t-3697 were measured from `/tmp/tl-dispatch/*/result.jsonl`.
- **Volume.** A single task needs 2-4 Codex rounds (T-3693, T-3694, T-3695), and a rung-5 panel needs 3 vendors per criterion. Each round is a cold start.
- **Not yet measured:** cold-start cost for codex, opencode/Z.ai and Antigravity; how long each vendor's prompt cache stays warm; and the latency difference between a warm and a cold reviewer.

## The tension: warm versus independent
T-3580 hardened reviews around **one fresh process per review**:
- a fixed preamble plus the brief, with no peer-consult text;
- an HMAC-signed dispatch record, and a signed start and completion;
- a reviewer that is never a producer.

A long-lived reviewer that remembers review N while doing N+1 breaks independence (anchoring, remembered producer content) and breaks per-review provenance.

**Candidate resolution:** keep the **process and the prompt cache warm**, but give **each question a fresh conversation**.
- Claude Code: `/clear` (or a new session in the same process).
- opencode: `opencode serve`, with a new session per question.
- Codex: a new thread per question, if its CLI or app-server allows it.
- Antigravity: unknown.

Each question keeps its own signed dispatch, start and completion. The "standing" part is the process plus the cache, never the memory.

## Delivery vehicle
T-3693 (closed 2026-10-02) gives every agent a receiver, a ready flag and one-line injection into a TermLink-registered session. A standing reviewer is simply an agent whose receiver accepts review and research questions. Answers return over the same API as REPLIED. This also exercises the sidecar under real load.

## Spike plan (to run before any build; IW-1..IW-4 on the task)
1. Per vendor, measure the cold-start cost (tokens or time) against a warm second question in the same process, with a fresh conversation for that question.
2. Per vendor, prove a question N+1 sees nothing from question N: a canary planted in question N must be absent from answer N+1.
3. Decide how T-3580 provenance maps to a warm process: is a signed dispatch per question enough when the process is shared?
4. Lifecycle: the context cap (operator: ~800-900K for Claude), a restart policy, liveness (T-3685) and costs logged per question.

## Dialogue Log
- 2026-10-02: the operator proposed standing warm agents per vendor, fed by sidecar injection. The agent measured the Claude cold-start cost (about 86K cache tokens per worker), named the independence and provenance tension with T-3580, and proposed "warm process and cache, fresh conversation per question" as the shape to test. Filed as an inception with GO on a spike only.
