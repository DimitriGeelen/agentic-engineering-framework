"""Fixture helper module, imported by hosts.py from the project folder."""


def host_rows():
    return [
        {"name": "alpha", "role": "hypervisor", "state": "up"},
        {"name": "bravo", "role": "storage", "state": "up"},
        {"name": "charlie", "role": "backup", "state": "maintenance"},
    ]
