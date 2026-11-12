"""T-5094: a submitter's verdict line may come after the test details. The real replies to
#102, #103 and #104 (2026-11-11, verbatim) were refused by `confirm-close`."""
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
import issues  # noqa: E402

REAL = {
    102: 'Tested on v1.8.16-be.46 in a throwaway container: with `fw task classify-ac`, a French Human criterion\nstarting with `[OPERATOR]`, alone or after `[REVIEW]`, is classified `operator-marked` / `OPERATOR-ONLY`.\nThat solves it for us: we will mark such criteria explicitly. Thank you.\n\n',
    103: 'Tested on v1.8.16-be.46 in a throwaway container (no network, non-root), listening address read from\n/proc/net/tcp:\n\n- fresh start, no FW_HOST and no HOST: 127.0.0.1 only;\n- started with FW_HOST=127.0.0.2, then `restart` from a shell without FW_HOST: stays on 127.0.0.2, with\n  "Keeping the running address 127.0.0.2";\n- HOST 127.0.0.2 set with `fw config set`: kept on start and on restart.\n\nConfirmed fixed, thank you.\n\n',
    104: "Confirmed, thank you. On v1.8.15, under a non-root account:\n\n- reading the account's own `~/.local/bin` and `~/.claude` is allowed by the boundary gate;\n- a path outside the project is still blocked by default, and adding it to `BOUNDARY_EXTRA_READ_PATHS`\n  allows it, including when the command reads a file through a redirection (`< file`).\n\nWe have been running with this setting since October 29 without any issue. This can be closed.\n\n",
}


@pytest.mark.parametrize("n", sorted(REAL))
def test_real_replies_are_closable(n):
    assert issues.classify_reply(REAL[n], "MikeEchoVoid", "MikeEchoVoid") in issues.CLOSABLE_CLASSES


@pytest.mark.parametrize("text,want", [
    ("Tested on 1.8.16.\n\nConfirmed fixed, thank you.", "confirmed"),
    ("Confirmed, thank you.", "confirmed"),
    ("Confirmed.", "confirmed"),
    ("Tested it. That solves it for us.", "confirmed"),
    ("Tested it.\n\nThis can be closed.", "close-ok"),
    # the verdict paragraph's own counter-signal still keeps it open
    ("Tested it.\n\nConfirmed fixed, except on Windows.", "other"),
    ("Tested it.\n\nConfirmed fixed. However the log is odd.", "other"),
    # a strong negative anywhere still wins
    ("Case A still fails.\n\nConfirmed fixed, thank you.", "not-fixed"),
    # a verdict in a middle paragraph does not count
    ("Tested it.\n\nConfirmed fixed.\n\nOne more thing I could not check.", "other"),
    # "Confirmed" followed by more than thanks is not a bare verdict
    ("Confirmed the bug is there.", "other"),
    ("Can this be closed?", "other"),
])
def test_verdict_placement(text, want):
    assert issues.classify_reply(text, "a", "a") == want
