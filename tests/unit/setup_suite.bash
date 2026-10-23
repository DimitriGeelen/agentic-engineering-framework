# setup_suite.bash — runs once per bats invocation whose first file is in this dir (T-4696)
# Refuses the run when its temp root is inside the framework checkout; see
# tests/tmpdir_outside_repo.bash for why.
_SUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
setup_suite() {
    source "$_SUITE_DIR/../tmpdir_outside_repo.bash"
    refuse_tmpdir_inside_repo "$_SUITE_DIR/../.."
}
