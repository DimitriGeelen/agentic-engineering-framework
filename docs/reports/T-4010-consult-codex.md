1. **Choose A**, with a committed manifest covering every policy input, including the dispatcher and backend registry. Read it from the reviewed commit and fail closed on missing or mismatched pins. B remains a simple supported alternative; C defeats the stated protection. An improvement is retaining bundles addressed by their content hashes, so historical revisions remain reviewable after upgrades.

2. **Yes, for the narrow “uncommitted edits cannot change accepted declarations” property.** Editing the working `.framework.yaml` must have no effect: load its blob from the same resolved commit as the review. Hash the actual file bytes and parse those verified bytes. Assuming SHA-256 collision resistance, this provides B-equivalent content binding. It does **not** provide equivalent archival availability: B retains the content; A alone retains only its digest. Neither establishes reviewer independence against a malicious same-user agent able to commit changes, alter enforcement code, or access signing keys. Git records changes; it does not itself establish human approval or trustworthy attribution.

3. **Failure modes to address:**

   - **Uncommitted/partial upgrades:** reject mismatches; validate the complete manifest as one snapshot before accepting seats. Never fall back to unpinned files.
   - **Check/use races:** read once, hash and parse the same bytes. If execution integrity is intended, also bind the executed dispatcher and its relevant dependencies.
   - **Symlinks:** `_HERE.parent.resolve()` can classify a symlinked vendor directory as external, enabling the framework-HEAD fallback. Define this boundary explicitly; do not let path resolution bypass consumer pins.
   - **Worktrees/moving refs:** resolve the reviewed revision once to a commit ID in the correct consumer repository; use it for every lookup.
   - **Historical reviews:** preserve pinned bundles or report unavailable content clearly.
   - **Malformed manifests:** reject duplicate keys, unsafe paths, unsupported hash algorithms, and incomplete pin sets.