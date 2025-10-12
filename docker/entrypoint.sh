#!/usr/bin/env bash
set -euo pipefail

# -----------------------
# System timezone (optional)
# -----------------------
if [[ -n "${TZ:-}" && -e "/usr/share/zoneinfo/$TZ" ]]; then
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
  echo "$TZ" > /etc/timezone
fi

PYFILE="/app/unifi_poe_control.py"

# ---- Required base envs (shared) ----
: "${CONTROLLER_HOST:?Set CONTROLLER_HOST}"
: "${SWITCH_MAC:?Set SWITCH_MAC}"

# ---- Optional defaults ----
PORT_INDEXES="${PORT_INDEXES:-}"        # required for run-once; per-job for cron
PORT="${PORT:-}"
SITE="${SITE:-}"
VERIFY_SSL="${VERIFY_SSL:-}"            # true|1 to enable verification
YES="${YES:-}"                          # true|1 to auto-confirm prompts
DEBUG="${DEBUG:-}"                      # true|1 for verbose

# Behavior controls
CRON_MODE="${CRON_MODE:-0}"             # 0=run-once, 1=cron scheduler
RUN_ONCE_MODE="${RUN_ONCE_MODE:-idle}"  # idle|skip-if-done|exit
STATE="${STATE:-}"                      # required for run-once (not needed in cron mode)

LOCK_DIR="/var/lock"
LOCK_FILE="${LOCK_DIR}/unifi-poe.lock"
MARKER="/var/run/unifi-poe.done"
LOGFILE="/var/log/cron.log"

mkdir -p "$LOCK_DIR" /var/run
touch "$LOGFILE"

# -----------------------
# Helpers
# -----------------------
build_common_args () {
  local args=()
  if [[ -n "$PORT" ]]; then args+=("--port" "$PORT"); fi
  if [[ -n "$SITE" ]]; then args+=("--site" "$SITE"); fi
  if [[ -n "$VERIFY_SSL" ]]; then
    if [[ "$VERIFY_SSL" == "true" || "$VERIFY_SSL" == "1" ]]; then args+=("--verify-ssl"); fi
  fi
  if [[ -n "$YES" ]]; then
    if [[ "$YES" == "true" || "$YES" == "1" ]]; then args+=("--yes"); fi
  fi
  if [[ -n "$DEBUG" ]]; then
    if [[ "$DEBUG" == "true" || "$DEBUG" == "1" ]]; then args+=("--debug"); fi
  fi
  printf '%s\n' "${args[@]}"
}

flock_cmd () {
  if command -v flock >/dev/null 2>&1; then
    echo "flock -n $LOCK_FILE"
  else
    echo ""  # no-op if util-linux not present
  fi
}

# Securely resolve the UniFi username (no leaking to env/cron/logs)
resolve_username () {
  # Priority:
  # 1) Docker secret at /run/secrets/unifi_username
  # 2) USERNAME_FILE (path to a mounted file)
  # 3) USERNAME (env)  <-- fallback only
  if [[ -f "/run/secrets/unifi_username" ]]; then
    cat /run/secrets/unifi_username
  elif [[ -n "${USERNAME_FILE:-}" && -f "$USERNAME_FILE" ]]; then
    cat "$USERNAME_FILE"
  elif [[ -n "${USERNAME:-}" ]]; then
    printf '%s' "$USERNAME"
  else
    echo "[entrypoint] ERROR: No UniFi username provided (Docker secret / USERNAME_FILE / USERNAME)" >&2
    exit 1
  fi
}

# Securely resolve the UniFi password (no leaking to env/cron/logs)
resolve_password () {
  # Priority:
  # 1) Docker secret at /run/secrets/unifi_password
  # 2) PASSWORD_FILE (path to a mounted file)
  # 3) PASSWORD (env)  <-- fallback only
  if [[ -f "/run/secrets/unifi_password" ]]; then
    cat /run/secrets/unifi_password
  elif [[ -n "${PASSWORD_FILE:-}" && -f "$PASSWORD_FILE" ]]; then
    cat "$PASSWORD_FILE"
  elif [[ -n "${PASSWORD:-}" ]]; then
    printf '%s' "$PASSWORD"
  else
    echo "[entrypoint] ERROR: No UniFi password provided (Docker secret / PASSWORD_FILE / PASSWORD)" >&2
    exit 1
  fi
}

build_cmd () {
  local state="$1"
  local ports="$2"
  local FLOCK
  FLOCK="$(flock_cmd)"

  # Resolve credentials securely at runtime
  local USER_VALUE PASS_VALUE
  USER_VALUE="$(resolve_username)"
  PASS_VALUE="$(resolve_password)"

  # Build as an array to avoid word-splitting; then print shell-safe
  local CMD=(python "$PYFILE"
    "$CONTROLLER_HOST" "$USER_VALUE" "$PASS_VALUE" "$SWITCH_MAC" "$ports"
    --state "$state" $(build_common_args)
  )

  if [[ -n "$FLOCK" ]]; then
    echo "$FLOCK $(printf '%q ' "${CMD[@]}")"
  else
    echo "$(printf '%q ' "${CMD[@]}")"
  fi
}

install_cron_jobs () {
  local CRON_FILE="/etc/cron.d/unifi-poe"
  : > "$CRON_FILE"

  echo 'SHELL=/bin/bash' >> "$CRON_FILE"
  echo 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' >> "$CRON_FILE"

  # Cron TZ (prefer CRON_TZ else TZ)
  if [[ -n "${CRON_TZ:-}" ]]; then
    echo "CRON_TZ=${CRON_TZ}" >> "$CRON_FILE"
  elif [[ -n "${TZ:-}" ]]; then
    echo "CRON_TZ=${TZ}" >> "$CRON_FILE"
  fi

  # Optional: heartbeat every minute (avoid % in cron by using ISO format)
  if [[ "${DIAG_CRON:-0}" == "1" ]]; then
    echo "* * * * * root date -Is 2>&1 | tee -a $LOGFILE >/dev/null" >> "$CRON_FILE"
  fi

  # Simple ON/OFF jobs (append to file; console mirroring is handled by tail -F)
  if [[ -n "${ON_CRON:-}" && -n "${ON_PORT_INDEXES:-}" ]]; then
    echo "$ON_CRON root $(build_cmd "${ON_STATE:-on}" "$ON_PORT_INDEXES") 2>&1 | tee -a $LOGFILE >/dev/null" >> "$CRON_FILE"
  fi
  if [[ -n "${OFF_CRON:-}" && -n "${OFF_PORT_INDEXES:-}" ]]; then
    echo "$OFF_CRON root $(build_cmd "${OFF_STATE:-off}" "$OFF_PORT_INDEXES") 2>&1 | tee -a $LOGFILE >/dev/null" >> "$CRON_FILE"
  fi

  # Advanced: JOB1_*, JOB2_* ... JOB10_*
  for i in $(seq 1 10); do
    local cron_var="JOB${i}_CRON"
    local state_var="JOB${i}_STATE"
    local ports_var="JOB${i}_PORT_INDEXES"
    if [[ -n "${!cron_var:-}" && -n "${!state_var:-}" && -n "${!ports_var:-}" ]]; then
      echo "${!cron_var} root $(build_cmd "${!state_var}" "${!ports_var}") 2>&1 | tee -a $LOGFILE >/dev/null" >> "$CRON_FILE"
    fi
  done

  # Permissions & trailing newline matter
  echo "" >> "$CRON_FILE"
  chmod 0644 "$CRON_FILE"
  chown root:root "$CRON_FILE"

  # Immediate marker so logs show something right away
  echo "[entrypoint] cron jobs installed at $(date -Is) (TZ=${TZ:-unset} CRON_TZ=${CRON_TZ:-unset})" >> "$LOGFILE"
}

# -----------------------
# Main
# -----------------------
if [[ "$CRON_MODE" == "1" ]]; then
  # Install jobs and start cron as a daemon
  install_cron_jobs
  /usr/sbin/cron -L 0

  # Mirror the cron log to container stdout as PID 1 so `docker logs` shows job output
  exec tail -F "$LOGFILE"

else
  # Run-once mode
  : "${PORT_INDEXES:?Set PORT_INDEXES for run-once}"
  : "${STATE:?Set STATE=on|off|enable|disable for run-once}"

  if [[ "$RUN_ONCE_MODE" == "skip-if-done" && -f "$MARKER" ]]; then
    echo "Run-once already completed earlier (marker found). Idling."
    exec tail -f /dev/null
  fi

  # Execute exactly once (prints directly to console since entrypoint is PID 1 here)
  eval "$(build_cmd "$STATE" "$PORT_INDEXES")"

  # Mark completion (used by skip-if-done)
  touch "$MARKER"

  case "$RUN_ONCE_MODE" in
    exit)
      exit 0
      ;;
    idle|skip-if-done|*)
      exec tail -f /dev/null
      ;;
  esac
fi
