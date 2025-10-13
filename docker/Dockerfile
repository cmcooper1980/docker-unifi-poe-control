FROM python:3.12-slim

# Prevent tzdata from prompting during install
ENV DEBIAN_FRONTEND=noninteractive
# Optional: set a default TZ (entrypoint can override at runtime via .env)
ENV TZ=UTC

# Install cron + essentials (flock is in util-linux)
RUN apt-get update && apt-get install -y --no-install-recommends \
    cron ca-certificates bash tzdata util-linux procps \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy repo (make sure you have a .dockerignore to exclude .env, .git, etc.)
COPY ../requirements.txt /app/
COPY ../unifi_poe_control.py /app/

# Keep pip current, then install deps
RUN python -m pip install --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

# --- Health check ---
# Passes if cron daemon is running and cron jobs file exists
HEALTHCHECK --interval=2m --timeout=20s --start-period=1m --retries=3 \
  CMD pgrep -x cron >/dev/null && [ -s /etc/cron.d/unifi-poe ] || exit 1

# Entrypoint
COPY ./docker/entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["/app/entrypoint.sh"]
