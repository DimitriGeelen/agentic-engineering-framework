# Buildspec Scrubbing Research: `.onedev-buildspec.yml`

## 1. Actual Risk Assessment

### GitHub Username (`DimitriGeelen`, line 108)
**Risk: NONE.** The username is already public — it's the owner of the public GitHub repo
`DimitriGeelen/agentic-engineering-framework`. Anyone visiting the repo sees this name.
The `remoteUrl` on line 107 also contains it. This is not sensitive data.

### passwordSecret (`github-push-token`, line 109)
**Risk: NONE.** This is OneDev's secure pattern working exactly as designed. The `passwordSecret`
field stores only the **name** of the secret, not the secret value itself. The actual GitHub PAT
is stored in OneDev's project-level job secrets (Settings > Job Secrets) and injected at runtime.
The string `github-push-token` is an opaque label — knowing it gives an attacker nothing without
access to the OneDev server. This is equivalent to seeing `$GITHUB_TOKEN` in a GitHub Actions
workflow — it's the reference, not the credential.

### Internal IP Addresses (`192.168.10.170`, `192.168.10.107`)
**Risk: LOW (Information/Reconnaissance only).** Per PortSwigger's classification, private IP
disclosure is rated **"Information"** severity (CWE-200). RFC 1918 addresses are non-routable
on the public internet — an attacker cannot reach `192.168.10.170` from outside the network.
The IPs provide minor reconnaissance value (network topology hints) but require prior network
access to exploit. For a home/small-office lab environment, the practical risk is negligible.

**However:** The IPs appear in both comments (lines 5-19) AND functional code (line 38, 68, 76).
Removing them from comments is cosmetic. Removing them from code requires a variable approach.

### Internal Hostname (`onedev.docker.ring20.geelenandcompany.com`)
**Risk: LOW.** Only appears in comments (line 17 as `<onedev-host>` placeholder). The hostname
reveals internal DNS naming convention but is not directly exploitable.

### Summary: Nothing in this file is actually a credential.
The file is already following security best practices — `passwordSecret` references a secret
by name, not by value. The username is public. The IPs are reconnaissance-grade information only.

## 2. OneDev Variable Substitution

### What OneDev Supports
OneDev supports `@variable@` substitution in buildspec fields:
- `@param:name@` — Job parameters
- `@property:name@` — Job properties (defined in project build settings)
- `@secret:name@` — Job secrets
- `@tag@`, `@branch@`, `@commit_hash@` — Git references
- `@build_number@`, `@project_name@` — Build metadata

### Can `userName` Use Variables?
**NO — not currently.** Per OneDev issue [OD-2447](https://code.onedev.io/onedev/server/~issues/2447),
a user attempted `@property:Mirrors_Repositories_username@` for the `userName` field in a
PushRepository step and it was treated as a literal string (not resolved). OneDev maintainer
Robin Shen confirmed this is a known limitation and said it would be "addressed via OD-2450."

As of the most recent information, `remoteUrl` CAN use `@property:...@` substitution, but
`userName` cannot. So even if we wanted to parameterize the username, OneDev doesn't support it
in PushRepository steps yet.

### Can `LXC_HOST` Be Parameterized?
Yes — in CommandStep shells, you can use `@property:lxc-host@` or `@secret:lxc-host@` since
those are just shell variable assignments inside a script. However, given the low risk of the IP
and that it would add operational complexity (another setting to manage), this is optional.

## 3. Comment Scrubbing: What Would Change

### Comments Only (Low-Effort, Low-Value)
Remove or genericize the architecture comments (lines 1-22). Replace specific IPs with
placeholders like `<lxc-host>` and `<ollama-host>`. This removes the only human-readable
topology documentation from the buildspec.

**Trade-off:** The comments serve as operational documentation. Removing them hurts maintainability
for zero meaningful security gain. Anyone needing to modify the pipeline loses context.

### Code + Comments (Higher-Effort)
Replace `LXC_HOST=192.168.10.170` with a job property reference and genericize comments.
This requires:
1. Define property `lxc-host` in OneDev project settings
2. Change line 38 to `LXC_HOST=@property:lxc-host@`
3. Change health check URL similarly

**Trade-off:** Adds indirection for minimal security benefit. If someone compromises the OneDev
server enough to read job properties, the IP is the least of your problems.

## 4. OneDev Secrets: How `passwordSecret` Works

`passwordSecret` is OneDev's built-in secure credential mechanism for repository operations:

1. **Definition:** Admin creates a job secret in Project Settings > Build > Job Secrets
2. **Storage:** The actual token value is encrypted in OneDev's database, never in files
3. **Reference:** The buildspec only contains the secret's **name** (e.g., `github-push-token`)
4. **Injection:** At build runtime, OneDev resolves the name to the encrypted value
5. **Masking:** Secret values are masked in build logs (shown as `***`)

**This is already the correct and secure pattern.** It's equivalent to GitHub Actions'
`secrets.GITHUB_TOKEN` or GitLab CI's masked variables. The buildspec is doing exactly
what OneDev's security model intends.

## 5. Recommendation

### Do Nothing (Recommended)

The file contains:
- **Zero credentials** — `passwordSecret` is a reference, not a value
- **Public information** — The GitHub username is already visible to anyone
- **Low-value reconnaissance** — Internal IPs rated "Information" severity
- **Valuable documentation** — The comments explain the deployment architecture

Scrubbing the file would remove useful documentation for negligible security improvement.
If the repo goes public, nothing in this file enables an attack that the attacker couldn't
already perform.

### If You Still Want to Scrub (Minimal Approach)

1. **Replace comment IPs with placeholders** — Change `192.168.10.170` to `<lxc-host>` in
   comments only (lines 5-6, 17-19). Keep the code IPs as-is.
2. **Leave `userName` as-is** — It's public info and OneDev doesn't support variable substitution
   for this field anyway.
3. **Leave `passwordSecret` as-is** — It's already the secure pattern.
4. **Don't add `.onedev-buildspec.yml` to `.gitignore`** — The file needs to be in the repo
   for OneDev CI/CD to work.

### What NOT to Do

- Don't move the file to `.gitignore` — OneDev reads it from the repo
- Don't try to parameterize `userName` — OneDev doesn't support it ([OD-2447](https://code.onedev.io/onedev/server/~issues/2447))
- Don't create a separate secrets file — `passwordSecret` already handles this correctly
- Don't over-engineer a solution for a non-problem

## Sources

- [OneDev Job Secrets Tutorial](https://docs.onedev.io/tutorials/cicd/job-secrets)
- [OneDev Job Variables Reference](https://docs.onedev.io/appendix/job-variables)
- [OD-2447: Decouple credentials from buildspec](https://code.onedev.io/onedev/server/~issues/2447)
- [PortSwigger: Private IP Address Disclosure (CWE-200)](https://portswigger.net/kb/issues/00600300_private-ip-addresses-disclosed)
- [RFC 1918: Address Allocation for Private Internets](https://datatracker.ietf.org/doc/html/rfc1918)
