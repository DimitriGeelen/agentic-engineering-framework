# Watchtower — Agentic Engineering Framework Web UI
# Swarm pattern: CPU-only, connects to GPU host for Ollama inference
FROM python:3.12-slim

LABEL maintainer="ring20" \
      app="watchtower" \
      description="Watchtower command center for Agentic Engineering Framework"

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (layer caching)
COPY web/requirements.txt web/requirements.txt
RUN pip install --no-cache-dir -r web/requirements.txt

# Copy framework files needed at runtime
COPY web/ web/
COPY agents/ agents/
COPY bin/ bin/
COPY lib/ lib/
COPY metrics.sh metrics.sh
COPY CLAUDE.md CLAUDE.md
COPY FRAMEWORK.md FRAMEWORK.md

# Create runtime directories
RUN mkdir -p /app/data /app/logs /app/.context/working

EXPOSE 5050

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:5050/health || exit 1

ENV PYTHONUNBUFFERED=1 \
    FW_PORT=5050 \
    FW_HOST=0.0.0.0

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5050", "--timeout", "120", "web.wsgi:application"]
