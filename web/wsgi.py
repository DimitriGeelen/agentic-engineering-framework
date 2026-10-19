"""WSGI entry point for Watchtower.

Usage:
    gunicorn -w 2 -b 0.0.0.0:5050 web.wsgi:application
"""

from web.app import create_app
from web.warmup import start_cache_warmup

application = create_app()
start_cache_warmup(application)  # T-4363: cold corpus caches built off the request thread
