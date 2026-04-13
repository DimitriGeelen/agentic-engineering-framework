#!/usr/bin/env bats
# Invariant: inception decision writer uses exact match on "## Decision"
# Origin: T-1202/T-1200 — startswith('## Decision') matched both ## Decisions and ## Decision

@test "inception.sh uses exact match for ## Decision section" {
    grep -q "== '## Decision'" lib/inception.sh
}

@test "inception.sh does not use startswith for Decision section" {
    ! grep -q "startswith('## Decision')" lib/inception.sh
}
