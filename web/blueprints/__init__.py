# Flask blueprints for the Agentic Engineering Framework web UI
#
# Centralizes blueprint registration (T-431/A2).
# Adding a new blueprint: import it here and append to _BLUEPRINTS.


def register_blueprints(app):
    """Import and register all Watchtower blueprints on the given Flask app."""
    from web.blueprints.core import bp as core_bp
    from web.blueprints.tasks import bp as tasks_bp
    from web.blueprints.timeline import bp as timeline_bp
    from web.blueprints.discovery import bp as discovery_bp
    from web.blueprints.quality import bp as quality_bp
    from web.blueprints.session import bp as session_bp
    from web.blueprints.metrics import bp as metrics_bp
    from web.blueprints.cockpit import bp as cockpit_bp
    from web.blueprints.inception import bp as inception_bp
    from web.blueprints.enforcement import bp as enforcement_bp
    from web.blueprints.risks import bp as risks_bp
    from web.blueprints.fabric import bp as fabric_bp
    from web.blueprints.discoveries import bp as discoveries_bp
    from web.blueprints.docs import bp as docs_bp
    from web.blueprints.settings import bp as settings_bp
    from web.blueprints.cron import bp as cron_bp
    from web.blueprints.api import bp as api_bp

    for bp in (
        core_bp, tasks_bp, timeline_bp, discovery_bp, quality_bp,
        session_bp, metrics_bp, cockpit_bp, inception_bp, enforcement_bp,
        risks_bp, fabric_bp, discoveries_bp, docs_bp, settings_bp, cron_bp, api_bp,
    ):
        app.register_blueprint(bp)
