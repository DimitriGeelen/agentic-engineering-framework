# Fixture project with its own Watchtower pages (T-5260, T-5261)

Copied into a temp dir by tests/web/test_t5260_project_pages.py and
tests/web/test_t5261_project_nav.py, which write the register
(`.framework-extensions.yaml`) there. Nothing here is loaded by the framework repo itself.

- `web_ext/hosts.py` — a page: blueprint `bp`, template, static file, helper module
- `web_ext/broken.py` — fails at import
- `web_ext/collide.py` — claims the framework route `/tasks`
- `web_ext/unregistered.py` — never registered, must never be served
- `web_ext/nav.yaml`, `nav_append.yaml`, `nav_missing.yaml` — menu entries (T-5261)
