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
    PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
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
chown -R developer:developer /workspace /home/developer 2>/dev/null || true

echo "[display] Resolution set to ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
echo "[startup] Handing off to supervisord..."

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/antigravity.conf
