# T-5009 — three architectures (opencode, subscription), 2026-11-03

Brief: design note + codex review + operator request for three architectures weighed on functionality vs security and scored on D1-D4. Returned as the worker's final message (review dispatch rv-t5009-opencode). Stored verbatim below.

## What is actually open

The draft (sections 2–4) is sound on the input side; open question Q-2 concerns only the *output/observability* channel. The operator's objection is legitimate, but it is about information flow, not about needing a network. One under-weighted point, which the codex review rightly raises: **the output disk itself is attacker-written data** — in every architecture below it must be read inside a disposable reader, never mounted on the credential-bearing controller.

### 1. Hardened disk-only (most isolated)

**How it works.** As in the draft: linked clone, input disk with the git bundle, output disk, no NIC, destroy after read. Two additions: the run script writes an append-only progress log with a forced fsync every few seconds (phase markers: unpack, install, per-test start/end), and the controller tracks liveness from the hypervisor API alone (VM state, CPU and I/O counters) — no guest cooperation needed. Timeout, boot failure and missing `result.json` become explicit infrastructure-error states. Output disks are extracted inside a second disposable reader VM, not on the controller.

**Functionality.** No live progress; diagnosis is post-mortem but usually sufficient — the phase markers say where a run stopped. Artifacts up to disk size; re-runs are whole-VM. Slowest feedback loop, cheapest to reason about.

**Security trade-off.** Zero new guest-facing surface; the only additions are guest-side write discipline and host-side metrics the hypervisor already exposes. Mitigation is the design itself: destroy everything, parse nothing trusted.

- D1 Antifragility: 3 — probe PR and parity runs turn failures into learning, but stalls remain ambiguous.
- D2 Reliability: 4 — deterministic and auditable; boot/deadlock failures are inferred, not observed.
- D3 Usability: 2 — post-mortem only; this is the architecture the operator called clunky.
- D4 Portability: 5 — disks and hypervisor APIs are universal; no bespoke protocol.

### 2. Disk-only plus serial-console capture (middle)

**How it works.** Identical to (1), plus the hypervisor captures the serial console — a device every VM has anyway — into a bounded, sanitized collector on the controller. The run script prints progress to the console as well as the disk, so boot messages, stalls and panics stream out continuously with no guest network and no session for anyone to coordinate. The collector caps bytes, strips terminal control sequences, and runs under a separate identity holding no hypervisor token. Bulk artifacts still travel on the output disk.

**Functionality.** Live tail of any run (`fw testhost watch --pr N`); boot failures and deadlocks visible as they happen; logs survive a forced kill because the console stream lives outside the guest. Re-runs still whole-VM. Marginal cost over (1) is one pipe and a small parser.

**Security trade-off.** Adds one virtual device and an attacker-controlled byte stream reaching trusted infrastructure — the same class of risk as the output disk, treated the same way. Mitigation: minimal receiver, hard caps, sanitized display, isolation from the orchestration credential.

- D1 Antifragility: 4 — failures are legible in real time; probe/parity story unchanged.
- D2 Reliability: 5 — every exit path leaves evidence; timeout and infra-error states are recorded by the controller, not claimed by the guest.
- D3 Usability: 4 — directly answers "hard to get the right information out"; not yet structured or interactive.
- D4 Portability: 4 — serial capture is standard on every hypervisor; the sanitizer is small custom code.

### 3. Private enclave with a disposable collector VM (most convenient)

**How it works.** The test VM gets a NIC on an isolated bridge with exactly one peer: a second throwaway collector VM in the same pool — no uplink, no route to the hypervisor, controller or estate. The guest pushes framed events and artifacts to a dumb upload endpoint on the collector using familiar tools (curl, tar). The controller retrieves the spool only after both VMs are destroyed. Both VMs die at the end of every run, pool empty.

**Functionality.** Incremental, structured results; selective re-runs of single tests within a live session; richest diagnosis and fastest feedback. The collector can render a progress view for the operator and agents.

**Security trade-off.** The largest addition: a guest network stack, a listening service, and firewall rules the threat modeler must own; the collector is attacker-reachable and must be assumed compromised. Mitigation: one-way push, deny-by-default bridge, no credentials on the collector, destruction with the run.

- D1 Antifragility: 4 — rich failure data, but more moving parts create new failure classes.
- D2 Reliability: 3 — good observability; more services that can silently misbehave, and the audit story must include the collector.
- D3 Usability: 5 — the experience the operator is asking for.
- D4 Portability: 3 — bespoke service and network rules; portable in principle, none of it standard.

## Recommendation

I agree with codex's verdict and would adopt architecture **2**: it resolves the operator's actual complaint — information extraction — with no guest network, keeping the R-53 floor and the no-self-hosted-runner constraint intact. Architecture 1 is an acceptable fallback if the operator wants zero new surface, but it leaves exactly the diagnosis gap that prompted the objection. Architecture 3 should be documented as a future step, taken only if structured incremental results prove necessary, because it moves the isolation floor to a place the threat modeler has not yet signed off. In all three: read guest-written disks in a disposable reader, and make deadlines, partial-log retention, and destruction-on-every-exit controller duties, never guest duties.
