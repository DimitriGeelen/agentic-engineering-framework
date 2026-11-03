# T-5009 — outside view (codex, subscription), 2026-11-03

Brief: design note + the operator's objection to disk-only I/O. Returned as the worker's final message (review dispatch rv-t5009-codex3). Stored verbatim below.

Verdict: The objection is right about observability and recovery, but it supports adding an automated, constrained diagnostic channel—not necessarily giving the VM a network.

Disk-only I/O is workable for unattended batch tests. Its weakness is that the controller learns too little while a run is alive: whether boot failed, dependency setup stalled, tests deadlocked, or output stopped because storage filled. Waiting for shutdown also delays feedback and makes interactive diagnosis difficult. A forced stop may lose buffered logs or leave the output filesystem inconsistent; missing `result.json` cannot distinguish an infrastructure failure from a test failure.

“Hard to get information out” is a real operational risk: ambiguous runs waste time, conceal infrastructure problems, and encourage manual workarounds that weaken isolation. Automation removes the coordination burden but does not itself solve these information gaps.

There is also an overlooked security boundary: **guest-written disks and logs are hostile input**. “Nothing is executed” is insufficient if the trusted controller mounts an attacker-controlled filesystem or renders unsafe terminal sequences. Result extraction needs isolation, bounded parsing, and safe display. Guest-reported probes are useful diagnostics, but cannot independently prove containment against malicious code.

Three alternatives fit the intended VM boundary:

1. **Keep disk input/artifacts; add serial-console log streaming.**  
   Capture boot messages, test progress, and diagnostics continuously through the hypervisor into a bounded collector. Retain logs after timeout or destruction; the controller independently records elapsed time, VM state, and its reason for termination. This requires no guest NIC or human session coordination. The isolation cost is a virtual-device interface and a hostile byte stream reaching a collector: cap volume, sanitize display, and keep the receiver minimal and separate from credential-bearing orchestration. It improves visibility but does not make guest messages trustworthy.

2. **Keep no NIC; add a narrow virtio-serial event/artifact channel.**  
   A fixed guest supervisor emits framed events such as test-start, test-end, and bounded artifact chunks. The receiver accepts only a small protocol, enforces sizes and timeouts, and chooses storage paths itself. This provides incremental results and can avoid mounting a guest filesystem altogether. It costs more protocol and receiver code than plain serial logging, and introduces another virtual-device surface. Treat every message as attacker-controlled; the protocol must never expose host commands, arbitrary paths, or orchestration credentials.

3. **Use a private network to a disposable, isolated collection VM.**  
   The test VM reaches only a credential-free collector in the same disposable test enclave, with no routing to the controller, hypervisor management, other guests, or operator estate. A narrow upload service provides familiar streaming and artifact transfer; the trusted side retrieves bounded results through a separately constrained mechanism. This adds network-stack, service, firewall, and retrieval complexity, so it is the highest-cost option here. It meets the stated floor only if that collector is explicitly part of the isolated test appliance; a direct link to the existing trusted controller does not satisfy the literal “no network path to other machines” requirement.

A bridge without an uplink is not sufficient evidence of isolation: host interfaces or other guests can still be attached. Likewise, controller-initiated SSH creates a bidirectional session; initiating it from the trusted side does not eliminate the guest-to-controller attack surface.

I recommend retaining the no-NIC VM and adding automatic serial-console capture first. Keep output disks for larger artifacts, but extract their contents inside a disposable, isolated reader rather than mounting them on the trusted controller. Make deadlines, partial-log retention, explicit timeout/infrastructure-error states, and destruction on every exit path controller responsibilities. If structured incremental results become necessary, add a minimal virtio-serial protocol; neither solution needs a self-hosted GitHub Actions runner or manual session coordination.