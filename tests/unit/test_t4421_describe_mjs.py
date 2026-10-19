r"""T-4421 — JS-family files the fabric deriver must read like `.js`.

Reported by 832: an ES-module script (`#!/usr/bin/env node`, then a `//`
header) was refused as "describes itself nowhere". Two gaps: `.mjs`/`.cjs`
were not mapped to the block-comment reader, and the reader stopped at the
shebang line before reaching the header.

Fixtures live in tmp_path; nothing here reads the live `.fabric/` corpus.
The refusal cases matter as much as the success cases: skipping a shebang
must not turn code-before-comment into a description.
"""

import importlib.util
import os
import sys
import textwrap

import pytest

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_DESCRIBE_PATH = os.path.join(_REPO_ROOT, "agents", "fabric", "lib", "describe.py")


def _load():
    spec = importlib.util.spec_from_file_location("fabric_describe_t4421", _DESCRIBE_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


describe = _load()


def _write(root, rel, content):
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(content).lstrip("\n"))
    return path


def test_mjs_with_shebang_and_slash_header_is_described(tmp_path):
    path = _write(tmp_path, "bin/sync.mjs", """
        #!/usr/bin/env node
        // Mirror the release manifest into the consumer cache.
        // Runs from cron; exits non-zero on a checksum mismatch.
        import fs from "node:fs";
    """)
    got = describe.derive_purpose_from_header(str(path))
    assert got is not None
    text, source = got
    assert "Mirror the release manifest" in text
    assert source == "header-comment"


def test_cjs_without_shebang_is_described(tmp_path):
    path = _write(tmp_path, "lib/loader.cjs", """
        // Load plugin descriptors from the vendored directory.
        const fs = require("fs");
    """)
    got = describe.derive_purpose_from_header(str(path))
    assert got is not None
    assert "Load plugin descriptors" in got[0]


def test_shebang_then_block_banner_is_described(tmp_path):
    path = _write(tmp_path, "bin/tool.js", """
        #!/usr/bin/env node
        /* Render the dispatch ledger as a terminal table. */
        console.log("x");
    """)
    got = describe.derive_purpose_from_header(str(path))
    assert got is not None
    assert "Render the dispatch ledger" in got[0]


@pytest.mark.parametrize("ext", [".mjs", ".cjs", ".mts", ".cts"])
def test_js_family_extensions_use_the_block_comment_reader(tmp_path, ext):
    path = _write(tmp_path, "src/mod" + ext, """
        // Parse the routing table into lookup entries.
        export const x = 1;
    """)
    got = describe.derive_purpose_from_header(str(path))
    assert got is not None
    assert "Parse the routing table" in got[0]


def test_js_comment_after_code_is_still_refused(tmp_path):
    path = _write(tmp_path, "lib/late.js", """
        const x = 1;
        // Parse the routing table into lookup entries.
    """)
    assert describe.derive_purpose_from_header(str(path)) is None


def test_shebang_only_file_is_still_refused(tmp_path):
    path = _write(tmp_path, "bin/bare.mjs", """
        #!/usr/bin/env node
        import fs from "node:fs";
    """)
    assert describe.derive_purpose_from_header(str(path)) is None
