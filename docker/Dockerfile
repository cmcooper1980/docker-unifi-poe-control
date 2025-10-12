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
# Checks that cron is alive and the container is responsive.
# It passes if the cron log has been updated within the last 10 minutes.
HEALTHCHECK --interval=2m --timeout=30s --start-period=1m --retries=3 \
  CMD if [ -f /var/log/cron.log ] && \
         find /var/log/cron.log -mmin -10 | grep -q cron.log; then \
        echo "Cron log updated recently"; exit 0; \
      else \
        echo "Cron appears idle or not writing logs"; exit 1; \
      fi

# Entrypoint
COPY ./docker/entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["/app/entrypoint.sh"]
