"""WSGI entry point for Watchtower.

Usage:
    gunicorn -w 2 -b 0.0.0.0:5050 web.wsgi:application
"""

from web.app import create_app

application = create_app()
