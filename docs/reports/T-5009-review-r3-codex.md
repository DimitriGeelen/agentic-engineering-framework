# T-5009 review round 3 — codex (subscription), 2026-11-12

Brief: docs/reports/T-5009-review-r3-brief.md. Dispatch rv-t5009-r3-codex-af0876eac0e5. Stored verbatim below.

The core controls are proportionate. The likely over-engineering is in moving results out, not in using a VM. One trusted collaborator lowers the likelihood of deliberate abuse, but it does not make every dependency or test safe.

**1. Keep the isolation; simplify the plumbing.**

Keep the disposable VM, no network card, no credentials in the guest, resource limits, and hostile-output handling. For the pilot, keep one run at a time and the offline dependency template. Relax those only when actual tests demonstrate a need.

Drop the output disk and reader VM unless you already need substantial binary artifacts. That sacrifices convenient artifact collection, but removes another VM lifecycle and filesystem-reading workflow.

Do not weaken isolation based on the PR author. That creates a second execution policy you must maintain and eventually retire.

There is one important qualification: **this arrangement does not fully isolate the maintainer’s estate.** The shared hypervisor remains the boundary protecting the credential-bearing container and storage node. You have explicitly accepted escape risk; none of A–D removes it. The standalone laptop is the clearest improvement to that boundary.

**2. Choose A for the pilot.**

A has the fewest moving parts and avoids reading a guest-written filesystem. Use a fixed controller-side run definition, with only the PR payload varying. Keep privileged API operations independent of guest-supplied paths, identifiers, and commands.

Its practical limits are manageable:

- **Debugging and large logs:** serial output is awkward for huge logs, binary artifacts, and interactive debugging. Capture a bounded log, visibly mark truncation, and retain the exact commit, template version, and run configuration so failures can be reproduced. Apply a total byte limit and rate limit to the stream, not just the 64 KB result.
- **Results:** framing and schema validation prevent some parsing problems; they do not make the result truthful. PR code can forge “pass” output or interfere with the harness. An external controller must distinguish completion, timeout, malformed output, and missing results. Maintainer review must still assess changes to checks themselves.
- **Parallelism:** two vCPUs and one run at a time limit throughput regardless of transport. Start there; measure run time before increasing concurrency. Test workers can run inside the VM within its resource budget.
- **Maintenance:** the dependency template will need deliberate refreshes. Missing offline dependencies should produce a clear failure, not trigger an emergency network exception.

The extra storage permissions in A deserve checking: a pool-scoped token is not automatically a complete boundary once storage privileges are added. Use dedicated storage where feasible, and verify the token cannot affect unrelated workloads.

**B** is reasonable if artifact recovery becomes essential. The reader VM contains filesystem parsing, but adds attachment, cleanup, failure recovery, and maintenance work. Large artifacts still need a defined route from that VM to the controller.

**C** puts guest-controlled disk parsing directly on the shared node. A forced command limits SSH operations; it does not protect the node from vulnerabilities in the tools reading the disk. I would reject that trade here.

**D** can be justified later by specific functionality. A collector network adds reachable services and network policy; a package mirror adds connectivity and dependency-management concerns. Neither is necessary merely because the contributor is trusted.

**3. The smallest pilot is A, with modest output expectations.**

Build one pinned template, accept one immutable PR commit, attach a read-only ISO, run the deeper checks, collect bounded serial text and a small summary, then destroy the VM. Treat transport failure or an ambiguous result as a failed run.

Do not skip an externally enforced timeout and shutdown, credential exclusion, permission checks, bounded output parsing, safe log rendering, and cleanup after failure. Run one deliberate timeout/output-flood test before the real PR.

If the full suite cannot finish offline within the limits, report that gap explicitly. The pilot can establish the workflow, but a partial run must not be presented as completion of the required deeper checks.