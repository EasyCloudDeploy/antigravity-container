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

# Write the htpasswd file used by nginx
htpasswd -cb /etc/nginx/.htpasswd "$AUTH_USER" "$PASSWORD"
echo "[auth] Nginx basic-auth configured for user: $AUTH_USER"

# Write the x11vnc password file (same password — VNC auth for the WebSocket path)
x11vnc -storepasswd "$PASSWORD" /etc/x11vnc.passwd
chmod 600 /etc/x11vnc.passwd
echo "[auth] x11vnc password file written."

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

# Ensure the developer user owns the workspace and their config dir
chown -R developer:developer /workspace 2>/dev/null || true
chown developer:developer /home/developer/.config \
    /home/developer/.config/google-antigravity \
    /home/developer/.config/google-chrome 2>/dev/null || true

mkdir -p /run/dbus

# Generate a noVNC landing page that auto-connects with the VNC password pre-filled.
# The WebSocket path (/websockify) has basic-auth disabled in nginx (browsers can't
# send Authorization headers for programmatic WebSocket connections), so VNC password
# is the security layer for the VNC session itself.
cat > /usr/share/novnc/index.html <<NOVNC_HTML
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url=/vnc_lite.html?autoconnect=true&password=${PASSWORD}&resize=scale">
  <title>Antigravity IDE — Loading...</title>
</head>
<body style="background:#1a1a2e;color:#eee;font-family:monospace;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
  <p>Loading Antigravity IDE…</p>
</body>
</html>
NOVNC_HTML
echo "[novnc] Landing page generated."

echo "[display] Resolution set to ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
echo "[startup] Handing off to supervisord..."

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/antigravity.conf
