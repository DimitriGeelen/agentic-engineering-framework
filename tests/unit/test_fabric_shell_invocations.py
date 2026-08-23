r"""T-3123 — shell composes by INVOCATION, not only by sourcing.

`detect_bash_sources` modelled exactly one relationship: script A's TEXT becomes
part of script B (`source foo.sh`, `. foo.sh`). Shell also composes by running
the target as a subprocess (`bash foo.sh`, `./foo.sh`, `exec "$D/foo.sh"`). That
edge was not modelled at all, so a script whose only dependency is what it
EXECUTES got a card with zero edges.

Third instance of the same class: T-3121 hardcoded a `web|lib|agents|tools`
python prefix list, T-3122 hardcoded four $VAR names for sourcing. So the
fixture tree below is built from vocabulary this repo does not use anywhere —
`stack/`, `runner/`, `$STAGE_DIR`, `$pipeline_home`. A fixture written in the
repo's own idiom could pass against calibrated-to-one-tree code and guard
nothing. Per L-599 nothing here asserts against the live corpus or live edge
counts, both of which move under the test.
"""

import importlib.util
import os
import sys

import pytest

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_ENRICH_PATH = os.path.join(_REPO_ROOT, "agents", "fabric", "lib", "enrich.py")


def _load_enrich():
    spec = importlib.util.spec_from_file_location("fabric_enrich_inv_under_test", _ENRICH_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


enrich = _load_enrich()
detect = enrich.detect_bash_sources


# ---------------------------------------------------------------------------
# Fixture tree — deliberately alien vocabulary
# ---------------------------------------------------------------------------

FIXTURE_FILES = [
    "stack/entry.sh",           # the file under analysis
    "stack/sibling.sh",         # sibling of entry.sh
    "stack/runner/go.sh",       # nested target, reached many ways
    "stack/runner/deep/far.sh",
    "stack/lib/inner.sh",       # only reachable via the <dir>/lib candidate
    "stack/probe.py",           # a non-shell script that is still invoked
    "crate/other.sh",           # project-root-relative target
    "crate/nested/leaf.sh",
]

# Real files that exist on disk but can never be RUN. Existence-guarding alone
# would emit edges for all of them.
INERT_FILES = [
    "stack/notes.txt",
    "stack/runner/settings.json",
    ".profile",
]


@pytest.fixture
def tree(tmp_path):
    for rel in FIXTURE_FILES:
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("# fixture\n")
        p.chmod(0o755)
    for rel in INERT_FILES:
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("inert\n")
        p.chmod(0o644)
    return str(tmp_path)


def targets(content, source_location, root):
    return [t for t, _rel in detect(content, source_location, root)]


# ---------------------------------------------------------------------------
# The eight invocation forms named in the task
# ---------------------------------------------------------------------------

def test_dot_slash_relative_invocation(tree):
    """./path/to/foo.sh — the plainest invocation there is."""
    assert targets("./runner/go.sh\n", "stack/entry.sh", tree) == ["stack/runner/go.sh"]


def test_bash_with_relative_path(tree):
    """bash path/to/foo.sh — no leading ./, the interpreter supplies the context."""
    assert targets("bash runner/go.sh\n", "stack/entry.sh", tree) == ["stack/runner/go.sh"]


def test_sh_with_bare_filename(tree):
    """sh foo.sh — a bare name IS a script when an interpreter precedes it."""
    assert targets("sh sibling.sh\n", "stack/entry.sh", tree) == ["stack/sibling.sh"]


def test_interpreter_options_are_skipped(tree):
    """bash -e foo.sh, and bundled/long options too."""
    assert targets("bash -e runner/go.sh\n", "stack/entry.sh", tree) == ["stack/runner/go.sh"]
    assert targets("bash -euo pipefail runner/go.sh\n", "stack/entry.sh", tree) == \
        ["stack/runner/go.sh"]


def test_exec_with_variable_prefix(tree):
    """exec "$SOME_DIR/foo.sh" — the variable's NAME is never consulted."""
    content = 'exec "$STAGE_DIR/runner/go.sh"\n'
    assert targets(content, "stack/entry.sh", tree) == ["stack/runner/go.sh"]


def test_direct_variable_path_with_arguments(tree):
    """"$DIR/foo.sh" arg1 arg2 — command word is itself the script."""
    content = '"$pipeline_home/crate/nested/leaf.sh" --flag one two\n'
    assert targets(content, "stack/runner/deep/far.sh", tree) == ["crate/nested/leaf.sh"]


def test_dirname_zero_invocation(tree):
    """$(dirname "$0")/foo.sh — resolved against the invoking file's directory."""
    content = '$(dirname "$0")/runner/go.sh --once\n'
    assert targets(content, "stack/entry.sh", tree) == ["stack/runner/go.sh"]


def test_command_bash_invocation(tree):
    """command bash foo.sh — a builtin wrapper in front of the interpreter."""
    assert targets("command bash runner/go.sh\n", "stack/entry.sh", tree) == \
        ["stack/runner/go.sh"]


# ---------------------------------------------------------------------------
# Prefix words and command position
# ---------------------------------------------------------------------------

def test_env_prefixed_interpreter(tree):
    """/usr/bin/env bash foo.sh — matched by basename, absolute path and all."""
    assert targets("/usr/bin/env bash runner/go.sh\n", "stack/entry.sh", tree) == \
        ["stack/runner/go.sh"]


def test_variable_assignment_prefix_is_skipped(tree):
    """FOO=1 BAR=2 exec ./foo.sh — assignments stand in front of the command."""
    content = 'STAGE_MODE=1 VERBOSE=yes exec ./runner/go.sh\n'
    assert targets(content, "stack/entry.sh", tree) == ["stack/runner/go.sh"]


def test_invocation_inside_if_condition(tree):
    """`if ./foo.sh; then` — the keyword hands off to the real command."""
    content = 'if ./runner/go.sh; then\n  echo ok\nfi\n'
    assert targets(content, "stack/entry.sh", tree) == ["stack/runner/go.sh"]


def test_invocation_after_separators(tree):
    """&&, ;, | and $( ) are all command positions."""
    content = (
        'true && bash runner/go.sh\n'
        'false; ./sibling.sh\n'
        'echo x | bash crate/other.sh\n'
        'OUT=$(bash crate/nested/leaf.sh)\n'
    )
    assert sorted(targets(content, "stack/entry.sh", tree)) == [
        "crate/nested/leaf.sh",
        "crate/other.sh",
        "stack/runner/go.sh",
        "stack/sibling.sh",
    ]


def test_non_shell_interpreter_target_is_reached_as_command_word(tree):
    """A .py invoked by path is still a dependency of the invoking script."""
    content = 'exec "$STAGE_DIR/probe.py" --check\n'
    assert targets(content, "stack/entry.sh", tree) == ["stack/probe.py"]


# ---------------------------------------------------------------------------
# Resolution order matches the sourcing path
# ---------------------------------------------------------------------------

def test_project_root_relative_invocation(tree):
    """Nothing resolves locally; the literal tail is rooted at the project."""
    content = 'bash "$WHATEVER/crate/other.sh"\n'
    assert targets(content, "stack/runner/deep/far.sh", tree) == ["crate/other.sh"]


def test_lib_subdir_candidate_reachable_by_invocation(tree):
    """The <dir>/lib candidate the sourcing path uses applies here too."""
    content = 'bash "$ANY/inner.sh"\n'
    assert targets(content, "stack/entry.sh", tree) == ["stack/lib/inner.sh"]


# ---------------------------------------------------------------------------
# Guards — the forms that must NOT become edges
# ---------------------------------------------------------------------------

def test_bash_dash_c_argument_is_not_treated_as_a_path(tree):
    """`bash -c` takes a command STRING, so its argument is not a file path.

    The content below is the discriminating case: the string after `-c` would
    resolve cleanly if it were read as a path, so only the `-c` guard stops it.
    Conservative by choice — a `-c` string that happens to be exactly one bare
    script path is a real invocation this under-reports rather than guessing at.
    """
    content = 'bash -c "stack/runner/go.sh"\n'
    assert targets(content, "stack/entry.sh", tree) == []


def test_bare_command_name_is_not_an_edge(tree):
    """A word with no `/` is a PATH lookup, not a script in this tree."""
    content = 'grep -q x runner/go.sh\ncat crate/other.sh\n'
    assert targets(content, "stack/entry.sh", tree) == []


def test_file_test_is_not_an_invocation(tree):
    """`[ -f x ]` references the file but does not compose with it."""
    content = '[ -f "$STAGE_DIR/runner/go.sh" ] || exit 1\n'
    assert targets(content, "stack/entry.sh", tree) == []


def test_commented_out_invocation_is_not_an_edge(tree):
    """Usage banners and disabled calls are prose."""
    content = '# bash runner/go.sh --help\n#   ./sibling.sh\n'
    assert targets(content, "stack/entry.sh", tree) == []


def test_no_self_edge_from_invocation(tree):
    content = 'exec "$STAGE_DIR/stack/entry.sh" "$@"\n'
    assert targets(content, "stack/entry.sh", tree) == []


def test_duplicate_targets_collapse(tree):
    """Four spellings of one file, plus a source of it — one edge."""
    content = (
        './runner/go.sh\n'
        'bash runner/go.sh\n'
        'exec "$STAGE_DIR/runner/go.sh"\n'
        '"$other/stack/runner/go.sh" --flag\n'
        'source "$another/stack/runner/go.sh"\n'
    )
    assert targets(content, "stack/entry.sh", tree) == ["stack/runner/go.sh"]


def test_invocation_of_missing_file_is_not_an_edge(tree):
    assert targets('bash runner/absent.sh\n', "stack/entry.sh", tree) == []


def test_system_and_home_invocations_ignored(tree):
    """`.profile` exists at the fixture root, so only prefix rejection stops it."""
    content = (
        '/usr/local/bin/setup.sh\n'
        'bash "$HOME/.profile"\n'
        'sh ~/.profile\n'
    )
    assert targets(content, "stack/entry.sh", tree) == []


# ---------------------------------------------------------------------------
# No project vocabulary — the constraint the last two fixes broke on
# ---------------------------------------------------------------------------

def test_no_hardcoded_variable_names(tree):
    """Five unrelated variable names, one target. The name is never consulted."""
    seen = set()
    for var in ("$STAGE_DIR", "$pipeline_home", "${SOME_THING}", "$q", "$Z9_root"):
        content = 'exec "%s/crate/other.sh"\n' % var
        seen.update(targets(content, "stack/entry.sh", tree))
    assert seen == {"crate/other.sh"}


def test_sourcing_still_detected(tree):
    """The T-3122 path must not regress — same file, both relationships."""
    content = 'source "$ANY/stack/sibling.sh"\nbash "$ANY/crate/other.sh"\n'
    assert sorted(targets(content, "stack/entry.sh", tree)) == [
        "crate/other.sh",
        "stack/sibling.sh",
    ]


# ---------------------------------------------------------------------------
# Prose is not composition — quoted text, heredoc bodies, unrunnable files
# ---------------------------------------------------------------------------

def test_separator_inside_a_quoted_message_is_not_a_command_position(tree):
    """A `;` inside an echo message is text. `go.sh` is executable and would
    resolve — only quote-awareness stops it becoming an edge."""
    content = 'report warn "stale entry; rerun stack/runner/go.sh to refresh"\n'
    assert targets(content, "stack/entry.sh", tree) == []


def test_paths_inside_a_heredoc_body_are_not_edges(tree):
    """An embedded interpreter's source text is data to the shell."""
    content = (
        'python3 - <<\'PY\'\n'
        'print("run ./runner/go.sh")\n'
        'subprocess.run(["bash", "crate/other.sh"])\n'
        'PY\n'
    )
    assert targets(content, "stack/entry.sh", tree) == []


def test_heredoc_body_ends_at_its_delimiter(tree):
    """Masking stops at the delimiter — a real call after it is still seen."""
    content = (
        'cat <<EOF\n'
        'see ./runner/go.sh\n'
        'EOF\n'
        'bash crate/other.sh\n'
    )
    assert targets(content, "stack/entry.sh", tree) == ["crate/other.sh"]


def test_non_executable_file_is_not_a_direct_invocation(tree):
    """The shell will not run a file without the execute bit; nor will we."""
    content = '"$STAGE_DIR/notes.txt"\n./runner/settings.json\n'
    assert targets(content, "stack/entry.sh", tree) == []


def test_interpreter_ignores_the_execute_bit(tree):
    """`bash x.sh` runs x.sh whether or not it is chmod +x — so the execute-bit
    guard applies to the direct form only."""
    os.chmod(os.path.join(tree, "crate/other.sh"), 0o644)
    assert targets("bash crate/other.sh\n", "stack/entry.sh", tree) == ["crate/other.sh"]


def test_continuation_line_carries_arguments_not_commands(tree):
    """A `for f in \\` list names files; it does not run them."""
    content = (
        'for script in \\\n'
        '    stack/runner/go.sh \\\n'
        '    crate/other.sh; do\n'
        '    echo "$script"\n'
        'done\n'
    )
    assert targets(content, "stack/entry.sh", tree) == []


def test_continuation_does_not_hide_a_real_command(tree):
    """The command starts on the unwrapped line — continuation only suppresses
    the lines that CARRY arguments, not the command that owns them."""
    content = 'exec "$STAGE_DIR/runner/go.sh" \\\n    --flag one\n'
    assert targets(content, "stack/entry.sh", tree) == ["stack/runner/go.sh"]
