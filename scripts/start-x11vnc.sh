#!/usr/bin/env bash
# Waits for the virtual display to be ready, then starts x11vnc.
set -euo pipefail

export DISPLAY=:1
export HOME=/home/developer

echo "[x11vnc] Waiting for Xvfb on :1 ..."
for i in $(seq 1 60); do
    if xdpyinfo -display :1 >/dev/null 2>&1; then
        echo "[x11vnc] Xvfb is ready — starting x11vnc."
        break
    fi
    sleep 0.5
done

# -nopw   : no VNC password (nginx basic-auth is the security layer)
# -localhost : only accept connections from loopback (nginx)
exec x11vnc \
    -display :1 \
    -forever \
    -shared \
    -nopw \
    -rfbport 5900 \
    -localhost \
    -wait 50 \
    -noipv6
