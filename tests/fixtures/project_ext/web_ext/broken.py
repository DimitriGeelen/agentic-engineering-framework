"""Fixture: a project page that fails at import (T-5260)."""
import module_that_does_not_exist_t5260  # noqa: F401

bp = None
