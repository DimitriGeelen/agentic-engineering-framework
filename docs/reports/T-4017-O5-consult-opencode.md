<!-- External consult (opencode / Z.ai), 2026-10-11, dispatch t4017-o5-opencode-041c035e6ddf. Printed as its final output (the reviewer seat cannot write files). Brief: docs/reports/T-4017-O5-consult-brief.md -->

Plan mode is active (read-only), so I can't create `docs/reports/T-4017-O5-consult-opencode.md`. Per the dispatch fallback, here is the full Markdown answer:

````markdown
# T-4017 / arc-001 O-5 — consult answer (opencode / Z.ai)

Takes R-34, OD-13 and the four directives as given in the brief.

## Option 1 — FIDO2 hardware key (`ssh-keygen -Y sign`, ed25519-sk)

**Steelman.** The private key is non-exportable and never exists on .107, so an agent running as root there cannot reach it — OD-13 is satisfied by construction. Every signature needs a physical touch, so an agent invoking the operator's own command still produces nothing (AC-34.2 falls out naturally). `ssh-keygen -Y sign/verify` is stock OpenSSH on Linux Mint, works offline, and any FIDO2 vendor's key fits (YubiKey, Nitrokey, Solo) — standards over products. Verification is over the record's hash, so later alteration invalidates (AC-34.3) and unsigned records fail the allowed-signers check and are logged (AC-34.1).

**Strawman.** One plastic thing on a keyring: lost, in another coat, PIN-blocked after retries — and approvals stop. Touch fatigue: an agent can raise signature prompts until a distracted operator taps. The terminal asking for the signature sits on .107, inside the adversary's reach — it can show record A while signing the hash of record B. The pinned public key also lives on .107; root can swap it for an agent key unless the swap is detectable.

**Scores.** D1 4 — recovery = buy and pre-enrol a backup key; cheap, testable. D2 4 — offline and deterministic, no silent failure (no touch → no record); minus one for the on-host public-key swap. D3 4 — plug and touch, a few times a week. D4 5 — FIDO2 + OpenSSH, multi-vendor, no accounts.

**Enrolment / recovery.** Generate the -sk key, put the public key in the verifier's allowed-signers file, and record the key fingerprint off host (paper, phone) so swapping the anchor is caught by re-deriving it. Enrol two keys from day one. On loss: sign with the backup, re-pin a new backup, drop the old fingerprint; the off-host fingerprint list is the revocation mechanism.

**Wrong thing.** What the operator sees before touching is .107's terminal — untrusted. Read the actual record, compare the short hash shown in the prompt; residual risk remains (below).

## Option 2 — phone-held key

**Steelman.** The phone is a second computer with its own screen and OS that the agent on .107 does not control; it is the only option where "what you see" and "what you sign" can sit on one trusted surface. Nothing extra to carry, keys live in the secure enclave, and occasional approvals fit a push/QR flow naturally.

**Strawman.** Phones are the most-lost, most-drained, most-randomly-updated device an operator owns; a push that silently never arrives is exactly directive 2's silent failure, discovered at approval time. A push/QR flow is bespoke software (relay + app — vendor lock-in), and if the relay runs on .107 the channel is agent-controlled again. Swipe fatigue beats touch fatigue, and the phone is also the most stealable object carried daily.

**Scores.** D1 3 — re-enrolment recovers, but the device itself is high-risk. D2 3 — battery/network/app dependencies; silent failure realistic. D3 4 — least extra carrying; approvals happen where the operator already is. D4 3 — fine if kept to WebAuthn/CTAP2; bespoke-app territory otherwise.

**Enrolment / recovery.** Enrol the enclave key and pin its public key as above. On loss/theft: re-enrol the replacement and replace the pinned key (same off-host fingerprint ritual). Old signatures stay valid — they are public data anyway — but the stolen key must leave allowed-signers promptly.

**Wrong thing.** Best of the three if the record is rendered on the phone from data the phone received directly (QR the operator scans, a fetch not relayed via .107). If the phone merely echoes what .107 sent, it inherits the same display problem with extra false confidence.

## Option 3 — separate signing host / offline GPG smartcard

**Steelman.** A drawer laptop, or a locked-down VM on ring20, holding a GPG or ssh key used only for approvals: no vendor at all, keys backupable (encrypted export) or on a multi-vendor OpenPGP card, fully auditable locally — and the operator can carry the record hash to it manually, sidestepping .107's display entirely.

**Strawman.** It only works while it stays out of the agent's reach: the moment it accepts connections from .107 it is a remote keyholder the root agent can drive. Console-only means walking to it, and a powered-off laptop is always dead when the approval arrives. GPG's UX is a tax and its failure modes (agent daemons, expired subkeys) stay silent until needed.

**Scores.** D1 3 — classic key management, straightforward backups, but another machine to keep alive. D2 3 — deterministic when running; reachability discipline and GPG footguns cost a star. D3 2 — boot/walk-to friction at unpredictable times. D4 4 — OpenPGP/SSH standards, multi-vendor cards.

**Enrolment / recovery.** Standard: generate on the host or card, export an encrypted backup, pin the fingerprint off host. Loss of host = restore backup to new media; loss of card = use its backup twin.

**Wrong thing.** Potentially the strongest: the operator reads the hash on the signing host's own console and it signs its local file — but only if the record travelled a path the operator controls (typed hash, QR), never the network from .107.

## Recommendation

**Primary: FIDO2 hardware key via `ssh-keygen -Y sign` (ed25519-sk, touch per signature), with a second key of a different make enrolled from day one as backup.** Keep the phone as a possible later second factor, not the primary.

Two strongest reasons: (1) it meets the requirement by physics and standards rather than discipline — the key cannot leave the device and the touch cannot be scripted, so AC-34.2 holds even when the agent has the operator's exact command, and hash-bound signatures give AC-34.1/34.3 for free; (2) it is the most boring, lock-in-free path: OpenSSH plus any FIDO2 key, offline, no accounts — directives 3 and 4 at once.

Main residual risk: **signing the wrong thing.** .107's screen is enemy territory, so the displayed record can differ from the signed hash. Live with it consciously — read the record, check the short hash in the prompt, and keep the allowed-signers fingerprint on paper so the trust anchor itself cannot be silently swapped. Every option whose display lives on .107 shares this risk; the phone or signing host reduce it, none removes it.
