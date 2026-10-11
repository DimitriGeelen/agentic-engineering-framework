# T-4017 / arc-001 O-5 — external consult brief: how the operator signs deciding records

**Asked by:** the operator (Dimitri), 2026-10-11: "Can we get an external consult on this, against the framework directives, steelman and strawman?"
**Consultants:** two independent models (codex / OpenAI, opencode / Z.ai). Work alone; do not assume the other's answer.

## The decision

arc-001 (a retrieval-stack refresh for the Agentic Engineering Framework, AEF) needs **signed deciding records**: model switches, benchmark freezes, threshold and parameter approvals, manual rollbacks. Requirement R-34 (verbatim):

> Manifest changes …, Gate 2 confirmations, benchmark freezes, placement decisions, parameter approvals, licence exceptions, manual rollbacks and model removals MUST carry operator provenance that an agent session cannot produce (for example a credential or confirmation step the agent cannot read or supply), bound to the exact record by its hash, so that altering the record invalidates it. Using the same command or endpoint as the operator MUST NOT be enough. Agents MAY only propose. … Impossible: an agent session creating or altering such a record. Adversary: a compromised or confused agent session.

Acceptance: AC-34.1 an agent-written record without operator provenance is rejected and logged; AC-34.2 an agent running the operator's own approval command or Watchtower endpoint still produces a rejected record; AC-34.3 a valid record altered afterwards is rejected.

Operator decision OD-13 (2026-10-09): approvals use a second factor only the operator holds, **off host .107**, because AI agents run as root on .107 and so no secret on that host can separate operator from agent. Only the public key lives on .107; verifiers check the signature over the record's hash, never the channel it came through.

## Context that matters

- One operator (Dimitri), one Linux workstation (.107, Linux Mint) where many AI agent sessions run as root; a Proxmox estate (ring20) nearby; the operator also uses a phone. Approvals today happen in Watchtower (a local web UI) or a terminal.
- Volume is low: a handful of deciding records per week, not per minute. Records are small JSON documents; a hash is signed.
- The operator values: no lock-in, standards over vendor products (directive 4), joy of use (directive 3), no silent failure (directive 2), recovery from loss (directive 1).

## Options to evaluate (add others if you think one is missing)

1. **FIDO2 hardware key** (e.g. a YubiKey) used through a standard that yields a verifiable signature over arbitrary data — e.g. `ssh-keygen -Y sign` with an `ed25519-sk` / `ecdsa-sk` key (needs a physical touch per signature), or WebAuthn assertions over the record hash in the browser.
2. **Phone-held key** — a signing key in the phone's secure enclave / keystore (e.g. an app, or SSH-agent-style signer on the phone), approving via a push or QR flow.
3. **Any other option you judge credible** (e.g. offline GPG smartcard, a separate signing host).

## What to produce

For EACH option:
- **Steelman** — the strongest honest case for it in this setting.
- **Strawman** — the weakest version / how it fails in practice here (loss, theft, the agent tricking the operator into signing the wrong thing, usability decay, vendor lock-in).
- **Score 0–5 against each directive**, with one line of reasoning each: D1 Antifragility (recovery from loss, compromise; learns from failure), D2 Reliability (predictable, auditable, no silent failure; meets AC-34.1–34.3), D3 Usability (daily friction for one operator), D4 Portability (standards, no vendor/provider lock-in).
- **Enrolment and recovery**: how the key is enrolled, and what happens when it is lost (backup key? revocation list? how the public key on .107 is replaced without letting an agent replace it).
- **The "sign the wrong thing" risk**: what the operator actually sees before touching/approving, and whether an agent could get a different hash signed.

Then: **a recommendation** (one option, or a combination such as primary + backup), with the two strongest reasons and the main residual risk. Keep it under ~900 words. Plain language; the reader is the operator, not a cryptographer.

Write your answer to the file named in your dispatch prompt (Markdown). Do not edit any other file.
