#!/usr/bin/env bash
set -euo pipefail

BANNER='
╔══════════════════════════════════════════════╗
║         Google Antigravity IDE               ║
║         Containerised Development Env        ║
╚══════════════════════════════════════════════╝
'
echo "$BANNER"

# ── Password setup ────────────────────────────────────────────────────────────
if [ -z "${PASSWORD:-}" ]; then
    # Generate a random 20-char alphanumeric password
    PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20 || true)
    echo "┌──────────────────────────────────────────────┐"
    echo "│  No PASSWORD env var set — generated one:    │"
    echo "│                                              │"
    printf  "│  PASSWORD: %-34s│\n" "$PASSWORD"
    echo "│                                              │"
    echo "│  Set PASSWORD env var to use a fixed value.  │"
    echo "└──────────────────────────────────────────────┘"
else
    echo "[auth] Using PASSWORD from environment variable."
fi

AUTH_USER="${AUTH_USER:-admin}"

# Write KasmVNC credentials (runs as developer so the file lands in ~/.kasmpasswd)
VNC_PASS="${PASSWORD}" VNC_USER="${AUTH_USER}" \
    HOME=/home/developer runuser -u developer -- bash -c \
    'printf "%s\n%s\n" "${VNC_PASS}" "${VNC_PASS}" | vncpasswd -u "${VNC_USER}" -w -r'
echo "[auth] KasmVNC credentials set for user: ${AUTH_USER}"

# ── XFCE display resolution ───────────────────────────────────────────────────
DISPLAY_WIDTH="${DISPLAY_WIDTH:-1920}"
DISPLAY_HEIGHT="${DISPLAY_HEIGHT:-1080}"

# Write a small env file that the supervisord programs can source
cat > /etc/antigravity-env.sh <<EOF
export DISPLAY_WIDTH=${DISPLAY_WIDTH}
export DISPLAY_HEIGHT=${DISPLAY_HEIGHT}
export DISPLAY=:1
export HOME=/home/developer
EOF

# Ensure the developer user owns the workspace and their config dirs
chown -R developer:developer /workspace 2>/dev/null || true
chown developer:developer /home/developer/.config \
    /home/developer/.config/google-antigravity \
    /home/developer/.config/google-chrome 2>/dev/null || true

mkdir -p /run/dbus
# Xvnc (KasmVNC) requires /tmp/.X11-unix to exist with sticky-bit permissions.
# It can't create it when running as non-root, so we do it here as root.
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
echo "[display] Resolution set to ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
echo "[startup] Handing off to supervisord..."

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/antigravity.conf
