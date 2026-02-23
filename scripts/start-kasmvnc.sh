#!/usr/bin/env bash
# Launched by supervisord as the developer user.
# vncserver forks Xvnc and exits; we read the PID file and wait so supervisord
# can track the lifetime and restart Xvnc if it crashes.
# -noxstartup: don't start a desktop from here; the supervisord `desktop`
#              program runs start-desktop.sh separately.
set -euo pipefail

[ -f /etc/antigravity-env.sh ] && source /etc/antigravity-env.sh

export HOME=/home/developer

# Ensure the VNC home dir exists
mkdir -p "${HOME}/.vnc"

# Clean up stale display lock and socket files from previous runs
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

echo "[kasmvnc] Starting KasmVNC on display :1 (web UI on port 6080)..."

vncserver :1 \
    -select-de xfce \
    -geometry "${DISPLAY_WIDTH:-1920}x${DISPLAY_HEIGHT:-1080}" \
    -depth 24 \
    -noxstartup

# Wait for the PID file vncserver writes
PID_FILE="${HOME}/.vnc/$(hostname):1.pid"
for i in $(seq 1 20); do
    [ -s "$PID_FILE" ] && break
    sleep 0.5
done

XVNC_PID=$(cat "$PID_FILE" 2>/dev/null || true)
if [ -z "$XVNC_PID" ]; then
    echo "[kasmvnc] ERROR: Xvnc PID file not found at ${PID_FILE}" >&2
    exit 1
fi

echo "[kasmvnc] Xvnc running with PID ${XVNC_PID}"

# Forward SIGTERM/SIGINT to Xvnc so supervisord can cleanly shut it down
trap 'echo "[kasmvnc] Stopping Xvnc (PID ${XVNC_PID})..."; kill "$XVNC_PID" 2>/dev/null; exit 0' TERM INT

# Stay alive as long as Xvnc is running
while kill -0 "$XVNC_PID" 2>/dev/null; do
    sleep 2
done

echo "[kasmvnc] Xvnc (PID ${XVNC_PID}) exited."
