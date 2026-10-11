<!-- External consult (google/gemini-2.5-pro via OpenRouter, paid, approved proposal RP-b1e8caaa), 2026-10-11. Brief: docs/reports/T-4017-O5-consult-brief.md + operator facts (phone, no hardware key, TOTP). Usage: {"prompt_tokens": 1296, "completion_tokens": 4244, "total_tokens": 5540, "cost": 0.04406, "is_byok": false, "prompt_tokens_details": {"cached_tokens": 0, "cache_write_tokens": 0, "audio_tokens": 0, "video_tokens": 0}, "cost_details": {"upstream_inference_cost": 0.04406, "upstream_inference_prompt_cost": 0.00162, "upstream_inference_completions_cost": 0.04244}, "completion_tokens_details": {"reasoning_tokens": 2434, "image_tokens": 0, "audio_tokens": 0}} -->

To: Dimitri (Operator)
From: Independent Security Architecture Consultant (Z.ai/opencode)
Date: 2026-10-12
Subject: T-4017 / arc-001 — Analysis of signing options for deciding records

This document provides an independent evaluation of options for signing deciding records, as requested. The analysis considers the specific threat model: an agent with root access on your primary workstation (.107) must be unable to forge your approval for a record.

### A Note on TOTP (Authenticator Apps)

You asked if a Time-based One-Time Password (TOTP), like a 6-digit code from an authenticator app, could be used.

**TOTP is not suitable for this purpose.** It is an authentication mechanism, not a signing mechanism. It proves you *are you* at a moment in time, but it does not create a lasting, verifiable link between you and a specific piece of data.

To verify a TOTP code, the verifier needs a shared secret. Since that verifier would live on the Proxmox estate and be accessible from your workstation, a root agent on .107 could steal the secret and generate its own valid codes. This completely fails requirement R-34. We need asymmetric cryptography (a public/private key pair) where the private key is never exposed to the agent.

---

### Option 1: FIDO2 Hardware Key

This involves using a key like a YubiKey with a standard like `ssh-keygen -Y sign` to sign the hash of a record. The key requires a physical touch for each signature.

*   **Steelman (The strongest case):** This is the gold standard for cryptographic hardware security. The private key is generated on the device and can never be extracted. Using it with the OpenSSH signing standard is fully open, non-proprietary, and extremely robust. An agent on .107 can request a signature, but it cannot produce one without you physically touching the key. This directly and elegantly satisfies the core requirement.
*   **Strawman (How it fails):** The primary failure is the "sign the wrong thing" risk. The agent on .107 controls your terminal screen. It can show you one record, but in the background, pass the hash of a different, malicious record to the `ssh-keygen` command. You see a prompt asking for a key touch, you touch it, and you have just unknowingly signed the malicious record. Your only defense is to manually hash the record and compare it, which is tedious and error-prone, destroying usability. Loss or theft requires a pre-planned recovery process, which can be complex to manage for a single operator.
*   **Scores (0–5):**
    *   **D1 Antifragility:** 3/5. Excellent security, but recovery from loss is entirely dependent on having a backup key stored securely.
    *   **D2 Reliability:** 5/5. The cryptography is unimpeachable. It reliably produces valid signatures that an agent cannot forge.
    *   **D3 Usability:** 3/5. Requires buying and carrying extra hardware. The "sign the wrong thing" risk adds a burden of verification that undermines daily joy of use.
    *   **D4 Portability:** 5/5. Based entirely on open standards (FIDO2, OpenSSH). You can switch key vendors at will.
*   **Enrolment and Recovery:** You generate a key pair on the device and copy the public key to a trusted list used by your verification service. For recovery, you would need to have pre-enrolled a second, backup hardware key (stored in a safe place). To replace a lost key's public key on the trusted list, you must have a secure administrative path that is not accessible to the agent on .107.
*   **"Sign the wrong thing" risk:** High. You are trusting the compromised host (.107) to show you the correct data. The key itself has no screen and cannot show you what you are signing.

---

### Option 2: Phone-held Key

This uses an application on your smartphone that holds a signing key within the phone's secure hardware (e.g., Secure Enclave on iOS, StrongBox Keystore on Android). Approvals happen via push notification or by scanning a QR code.

*   **Steelman (The strongest case):** This model can solve the "sign the wrong thing" problem perfectly. A well-designed signing app would not just ask "Approve/Deny?". It would receive the *full record* from the agent, display it clearly on the phone's trusted screen, and only sign the hash of that record after you approve it. You verify the content on a separate device from the one the agent controls. This aligns with your preference, uses hardware you already have, and can be highly usable.
*   **Strawman (How it fails):** This approach lives or dies by the quality of the app. Many push-approval systems are proprietary, creating vendor lock-in (violates D4). A poorly designed app that only shows a generic "Approve sign request?" message is just as vulnerable to the "sign the wrong thing" attack as the hardware key. Phone loss is common, and recovery depends entirely on the app's specific backup mechanism (e.g., cloud backup, recovery phrase), which may be insecure or cumbersome.
*   **Scores (0–5):**
    *   **D1 Antifragility:** 3/5. Phone loss is a real risk; recovery depends on the app's quality and your foresight in storing its recovery phrase.
    *   **D2 Reliability:** 4/5. When implemented correctly (with on-device display of the record), it is very reliable. The score is not 5/5 because it relies on a more complex software stack than the hardware key.
    *   **D3 Usability:** 5/5. The push notification or QR scan flow is modern, fast, and intuitive.
    *   **D4 Portability:** 2/5. This is the weakest point. You risk being locked into a specific app or provider. A truly open, standard-based implementation for signing arbitrary data is less common than FIDO2.
*   **Enrolment and Recovery:** Typically, you enrol by scanning a QR code to pair the app with your account. Recovery from phone loss requires using a recovery phrase you previously stored offline, or a pre-enrolled backup method.
*   **"Sign the wrong thing" risk:** Low, *provided the app you choose displays the full content of the record you are signing.* This is the single most important feature to look for.

---

### Recommendation

I recommend a hybrid approach, using the **Phone-held Key as your primary signing method**, with a **FIDO2 Hardware Key as an offline backup**.

1.  **Primary (Daily Use): Phone-held Key.** The critical condition is selecting an application that displays the full JSON record on your phone screen before you approve the signature. This is the only method discussed that effectively mitigates the "sign the wrong thing" attack.
2.  **Backup (Recovery): FIDO2 Hardware Key.** Purchase a single FIDO2 key. Enrol it as a valid signer for your records alongside your phone, and then store it securely in a different physical location (e.g., a safe at home, a safety deposit box). This key is your recovery mechanism if you lose your phone. It directly addresses the antifragility directive (D1).

**Two Strongest Reasons for this Recommendation:**

1.  **Solves the core threat:** By displaying the record on a separate, trusted screen (your phone), this approach directly counters the most likely attack: an agent tricking you into signing a malicious record. Security that relies on perfect, repeated human vigilance is brittle; this makes verification easy and reliable.
2.  **Balances Security with Usability:** It provides best-in-class usability for daily operations (D3) by using your phone, while incorporating the raw cryptographic strength and portability of a standards-based hardware key for recovery (D1, D4).

**Main Residual Risk:**

Your security posture will be highly dependent on the quality and integrity of the chosen phone signing application. You must vet it carefully to ensure it's from a reputable source, it genuinely uses the phone's secure hardware, and, most importantly, it correctly displays the full record before signing.
