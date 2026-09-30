# T-3585: render review (rung 1, parent session, not the producer)

**VERDICT: GREEN.** The only render change is one new row on /config. Checked live: `FW_RELEASE_TAG_PATTERN | v[0-9]* | v[0-9]* | default | Glob for release tags read by fw release status; prefixed semver (designer-vX.Y.Z) is tried when nothing matches, else no matching tag and UNKNOWN commits, never 0; T-3585`. It has the same shape as its neighbour FW_RELEASE_BRANCH, the value and the default are shown, and the description stands alone. Impact is low (one config row), so rung 1 is proportionate (IW-7).
