# T-5009 review round 3 — brief: are we over-protecting the PR test host?

You are an outside reviewer. Answer in plain language, at most about 700 words. No host names or
addresses appear here on purpose; do not ask for them.

## The job

An open-source governance framework (shell + Python, ~1,400 bats/pytest test files) is starting to
accept pull requests from outside contributors. The first is a pilot with one trusted collaborator,
but the design must treat PR code as untrusted in principle. Before the maintainer merges a PR that
changes code, the framework's own checks must run on that PR's code somewhere that cannot hurt the
maintainer's estate. GitHub's own CI already runs the fast checks; this host is for the deeper ones.

## What has been decided

- A throwaway **VM** per run (not a container), cloned from a template, destroyed afterwards.
- **No network card** in the VM; the template carries every dependency.
- Limits: 2 vCPU, 8 GB RAM, 40 GB disk, 60 minutes, one run at a time.
- The hypervisor is a Proxmox node in a home-lab cluster. It also runs a container holding CI
  registry push credentials and an object-storage node; the maintainer accepted that a VM escape could
  reach those, until a dedicated standalone host (an old laptop running KVM) is ready.
- The controller (the maintainer's main machine, which holds his GitHub login and all his projects)
  drives runs through the Proxmox API with a token limited to one resource pool.
- Everything the guest produces is treated as hostile input: capped, sanitised, schema-checked,
  never executed, never mounted on the controller.

## The open question

How do code go in and results come out? Options on the table:

A. **Read-only CD image in, serial console out.** The controller builds an ISO (git bundle of the PR
   + a run script from the framework's released version) and uploads it; the guest streams its log on
   the serial console and ends with a framed, capped result file (64 KB); the controller reads the
   serial stream through the Proxmox API (termproxy websocket). No output disk. The token needs, besides
   the pool, upload rights on one storage and allocation rights on another.
B. **As originally designed:** input disk + output disk + live serial log; the output disk is read
   inside a second throwaway "reader VM" that reports over its own serial line.
C. **Node-side helper:** a small fixed script on the Proxmox node, reached through a forced-command
   SSH key from the controller, attaches and reads disks directly.
D. **Something less strict** that you think is reasonable: for example a host-only network to a
   collector VM, an allow-listed package mirror, or running PRs from the trusted pilot contributor
   with fewer controls.

## What the maintainer asks

He feels "we are maybe being overprotective and with that are cutting ourselves off from
functionality. It needs to be workable." Please answer:

1. Is the current set of controls proportionate for this stage (one trusted pilot contributor,
   a home-lab estate), or over-engineered? Name what you would drop or relax, and the risk that buys.
2. Which of A–D (or your own variant) is the most workable design that still keeps untrusted code
   away from credentials and from the rest of the estate? Say what breaks or becomes painful in
   practice with each (debugging a failed run, large logs, test parallelism, maintenance).
3. What is the smallest version that could run the pilot's first code PR within days, and what must
   not be skipped even then?
