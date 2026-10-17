#!/usr/bin/env bats
# T-4232: fw upgrade step [1/10] must never silently delete consumer-added text
# inside the CLAUDE.md governance section.
#
# Origin: 1409 upgraded 1.8.3 -> 1.8.10 and lost its zero-subagent, review-route and
# runme rules (889 -> 865 lines). Step 1 rebuilds everything from "## Core Principle"
# onward from the template, and the only detector ran after the overwrite.
#
# Contract under test (lib/upgrade.sh, _fw_governance_at_risk + step 1 guard):
#   - a consumer line in the governance section that the template lacks, and that is
#     not inside a project-owned region, REFUSES the rewrite (rc 1, file untouched)
#   - a STOCK copy (governance == vendored shipped template) still upgrades, and
#     stale framework text the template dropped is removed without refusal
#   - consumer lines moved into a project-owned region survive verbatim

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    export REAL_HOME="$HOME"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"

    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.agentic-framework/lib/templates"
    printf 'project_name: proj\nversion: 1.5.0\n' > "$PROJ/.framework.yaml"
    # Vendored copy = the shipped template the project was last upgraded from.
    # Stock here means: identical to the framework's current template.
    cp "$FRAMEWORK_ROOT/lib/templates/claude-project.md" "$PROJ/.agentic-framework/lib/templates/claude-project.md"
    TEMPLATE_GOV=$(sed -n '/^## Core Principle$/,$ p' "$FRAMEWORK_ROOT/lib/templates/claude-project.md")
}

teardown() {
    export HOME="$REAL_HOME"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Write CLAUDE.md = a project header + the given governance text.
write_consumer_claude() {
    {
        printf '# CLAUDE.md\n\n## Project Overview\n\n**Project:** proj\n\n'
        printf '%s\n' "$1"
    } > "$PROJ/CLAUDE.md"
}

@test "T-4232: consumer line inside governance section refuses the rewrite and keeps the file" {
    # Consumer adds a rule inside the governance section (not a project-owned region).
    local edited
    edited=$(printf '%s\n' "$TEMPLATE_GOV" | sed 's/^## Authority Model$/CONSUMER-RULE: zero-subagent sessions for trivial edits.\n\n## Authority Model/')
    write_consumer_claude "$edited"
    cp "$PROJ/CLAUDE.md" "$TEST_TEMP_DIR/before.md"

    run do_upgrade "$PROJ" --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"CONSUMER-RULE: zero-subagent sessions"* ]]
    [[ "$output" == *"project-owned: begin"* ]]
    [[ "$output" != *"WOULD UPDATE"* ]]
    cmp "$PROJ/CLAUDE.md" "$TEST_TEMP_DIR/before.md"
}

@test "T-4232: real run refuses too, writes no backup and leaves the consumer line in place" {
    local edited
    edited=$(printf '%s\n' "$TEMPLATE_GOV" | sed 's/^## Authority Model$/CONSUMER-RULE: run runme.sh for operator commands.\n\n## Authority Model/')
    write_consumer_claude "$edited"
    cp "$PROJ/CLAUDE.md" "$TEST_TEMP_DIR/before.md"

    run do_upgrade "$PROJ"
    [ "$status" -eq 1 ]
    [[ "$output" == *"CONSUMER-RULE: run runme.sh"* ]]
    cmp "$PROJ/CLAUDE.md" "$TEST_TEMP_DIR/before.md"
    [ ! -e "$PROJ/CLAUDE.md.bak" ]
}

@test "T-4232: stock copy of the shipped template still upgrades without refusal" {
    # Consumer governance == vendored shipped template, but the framework has since
    # dropped one line. That is stale framework text, not a consumer edit: no refusal.
    local shipped="$PROJ/.agentic-framework/lib/templates/claude-project.md"
    write_consumer_claude "$TEMPLATE_GOV"
    # Make the vendored (shipped) copy carry a line the current template no longer has.
    sed -i 's/^## Authority Model$/RETIRED-FRAMEWORK-LINE\n\n## Authority Model/' "$shipped"
    local shipped_gov
    shipped_gov=$(sed -n '/^## Core Principle$/,$ p' "$shipped")
    write_consumer_claude "$shipped_gov"

    run do_upgrade "$PROJ" --dry-run
    [[ "$output" != *"REFUSED"* ]]
    [[ "$output" == *"WOULD UPDATE"* ]]
}

@test "T-4232: consumer line moved into a project-owned region survives the upgrade verbatim" {
    local edited region
    region='<!-- project-owned: begin -->
CONSUMER-RULE: run runme.sh for operator commands.
<!-- project-owned: end -->'
    edited=$(printf '%s\n%s\n' "$TEMPLATE_GOV" "$region")
    write_consumer_claude "$edited"

    run do_upgrade "$PROJ"
    [ "$status" -eq 0 ]
    [[ "$output" != *"REFUSED"* ]]
    grep -qF "CONSUMER-RULE: run runme.sh for operator commands." "$PROJ/CLAUDE.md"
    grep -qF "<!-- project-owned: begin -->" "$PROJ/CLAUDE.md"
}

@test "T-4232: _fw_governance_at_risk lists only governance lines the new tail lacks" {
    local f="$TEST_TEMP_DIR/c.md"
    printf '# head\n## Core Principle\nkeep me\nCONSUMER-ONLY\n\n<!-- project-owned: begin -->\nOWNED\n<!-- project-owned: end -->\n' > "$f"
    local tail
    tail=$(printf '## Core Principle\nkeep me\n<!-- project-owned: begin -->\nOWNED\n<!-- project-owned: end -->')
    run _fw_governance_at_risk "$f" "$tail"
    [ "$status" -eq 0 ]
    [ "$output" = "CONSUMER-ONLY" ]
}
