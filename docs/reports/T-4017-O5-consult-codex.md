<!-- External consult (codex / OpenAI), 2026-10-11, dispatch t4017-o5-codex-881f436e35a0. Recovered from the run log: the reviewer seat runs in a read-only export, so the file it wrote there was discarded. Brief: docs/reports/T-4017-O5-consult-brief.md -->

# Independent consult: arc-001 operator signatures

**Recommendation:** a phone signer with an independent record display, plus a separately stored hardware recovery key used from a trusted separate computer. This best combines informed approval with recoverability at a few approvals per week. Scores below evaluate the specified implementations, not products.

## Prerequisite: protect the decision boundary

OD-13 correctly excludes secrets on .107. But public keys need integrity: root can replace a local trust list, patch verification, suppress logs, or bypass enforcement. No signing device alone satisfies R-34 against that adversary if .107 is the sole authority. Put authoritative verification, trust administration, and acceptance logging beyond .107's control. A ring20 service qualifies only if .107 agents cannot administer it, including through inherited credentials. Local checks remain useful but are not the security boundary.

Define one unambiguous record encoding. Sign a domain-separated envelope containing its hash, record type, project, unique decision ID, and applicable version. Verify the exact consumed record; reject stale/replayed approvals and unsigned changes. Preserve record and signature together. Missing, invalid, revoked, or altered approvals fail closed and produce an external rejection log. Exercise AC-34.1–34.3 using an agent invoking the actual operator command/endpoint, plus trust-list substitution and verifier-bypass attempts.

## 1. FIDO2 hardware key

**Steelman:** inexpensive operational model, private key stays in hardware, explicit presence for each signature, and mature tooling. OpenSSH supports security-key signing, signature namespaces, allowed signers, and revocation files. Use a dedicated approval namespace and require presence; disable no-touch arrangements. [OpenSSH manual](https://man.openbsd.org/cgi-bin/man.cgi/OpenBSD-current/man1/ssh-keygen)

**Strawman / wrong thing:** a key attached to .107 is a blind signing button. Watchtower can display record A while root requests a signature for B; touch proves presence, not informed agreement. Loss stops work without a backup; theft is worse without operator verification. Repeated prompts encourage reflex touches.

WebAuthn is viable, but its assertion signs structured authentication data, not a bare record hash. Bind the challenge to the approval envelope and validate the complete assertion, including origin, relying-party identity, challenge, signature, and required presence/verification flags. It still does not provide a trusted transaction display. [W3C specification](https://www.w3.org/TR/webauthn-3/)

- **D1 4/5:** independent spare and rehearsed revocation make loss recoverable.
- **D2 3/5:** strong provenance and tamper detection; blind approval remains vulnerable.
- **D3 4/5:** quick touch, occasional retrieval and PIN friction.
- **D4 5/5:** standard protocols and multiple suppliers; check algorithm support before purchase.

**Enrolment/recovery:** generate two independent keys on trusted equipment; register their public keys through the external trust authority. Keep the spare separately. Authorize replacement and revoke the lost key using the recovery procedure below. Display the record on a trusted separate computer before signing to remove the .107 substitution problem.

## 2. Phone-held key with trusted display

**Steelman:** the phone receives the complete record, computes its hash itself, displays all deciding fields and context, and signs those same bytes after explicit biometric/PIN approval. A QR transfer avoids dependence on a push provider. Hardware-backed keystores support protected keys and authentication controls, but device support must be verified. [Android documentation](https://source.android.com/docs/security/features/keystore)

**Strawman / wrong thing:** a push saying “Approve?” or a QR containing only an opaque hash recreates blind signing. A summary supplied by .107 can lie. The app must render the parsed record itself, reject ambiguous input, and expose every field affecting the decision. Compromised phone software, misleading proposals, and inattentive approval remain risks. App abandonment, battery failure, and proprietary cloud recovery cause usability decay or lock-in.

- **D1 4/5:** independent recovery key handles loss; practise replacement rather than assuming key export.
- **D2 4/5:** independent display binds intent to bytes; custom application correctness needs scrutiny.
- **D3 4/5:** scan, inspect, approve is reasonable at this volume.
- **D4 3/5:** portable signature format helps, but keystore APIs and app maintenance remain platform-specific.

**Enrolment/recovery:** generate the key on-phone, independently confirm its public-key fingerprint at the trust authority, and enroll the offline recovery key. Revoke a lost phone and authorize a new phone key; do not depend on restoring its non-exportable private key.

## 3. Separate offline signing computer

**Steelman:** a small dedicated computer displays complete records and signs locally with standard tooling, optionally using a smartcard. No cloud or daily-phone dependency.

**Strawman / wrong thing:** booting and transferring files invites shortcuts; stale software and malicious inputs remain hazards. Blindly signing an imported hash defeats the independent screen.

- **D1 4/5:** spare key and rebuild instructions support recovery.
- **D2 4/5:** independently calculated hashes and display strengthen approval.
- **D3 2/5:** most cumbersome option.
- **D4 5/5:** standard files and signatures permit replacement hardware.

**Enrolment/recovery:** enroll primary and separate recovery keys through the external authority. Keep rebuild instructions; test restoration.

## Recovery and final judgment

For all options, pin an offline recovery public key at the external authority. Require its signed, versioned authorization for trust changes; prevent rollback to old trust state. Never accept .107 file edits as enrolment. If every authorized key is lost, stop approvals and physically rebootstrap the authority with an auditable ceremony. Record incidents and rehearse recovery afterward.

The phone wins on **seeing exactly what is signed** and **sustainable weekly friction**. The main residual risk is approving harmful content despite an accurate display; cryptography cannot supply operator judgment.
