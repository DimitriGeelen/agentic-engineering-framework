#!/usr/bin/env bats
# T-3882: fw upgrade adds framework cron jobs to the registry (step 3b) but the
# "run 'fw cron install' to deploy" hint was one mid-run line; 832 counted a
# dry run as the install. The closing next steps now name the jobs that are
# not running yet.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # Nothing here runs a cron install (the text only names the command), but
    # tests/lint/bats-cron-env-lint.bats keys on that text — and a real install
    # without this would write into /etc/cron.d.
    export FW_CRON_INSTALL_DIR="$TEST_TEMP_DIR/cron.d"
    U="${BATS_TEST_DIRNAME}/../../lib/upgrade.sh"
    eval "$(awk '/^_t3882_cron_next_step\(\) \{/{p=1} p{print} p&&/^\}/{exit}' "$U")"
}

@test "t3882: jobs added → the next step names them and the install command" {
    run _t3882_cron_next_step /opt/c "index-reindex-hourly unit-suite-nightly"
    [ "$output" = "  4. 2 new cron job(s) (index-reindex-hourly unit-suite-nightly) are NOT running yet — deploy: cd /opt/c && fw cron install" ]
}

@test "t3882: nothing added → no line at all" {
    run _t3882_cron_next_step /opt/c ""
    [ -z "$output" ]
}

@test "t3882: wiring — real-run ADDED appends the id, dry run does not, summary prints it" {
    # the append sits in the non-dry-run branch of the ADDED case
    run awk '/ADDED\\ \*\)/{p=1} p{print} p&&/;;/{exit}' "$U"
    [[ "$output" == *'WOULD ADD'*'else'*'_cron_added_ids='* ]]
    grep -q '_t3882_cron_next_step "$target_dir" "$_cron_added_ids"' "$U"
    grep -q 'local _cron_added_ids=""' "$U"
}
