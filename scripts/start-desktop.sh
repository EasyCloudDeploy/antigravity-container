#!/usr/bin/env bash
# Launched by supervisord after Xvfb is up.
# Starts the XFCE4 desktop session and auto-launches Antigravity.
set -euo pipefail

# Source the env written by entrypoint
# shellcheck disable=SC1091
[ -f /etc/antigravity-env.sh ] && source /etc/antigravity-env.sh

export DISPLAY=:1
export HOME=/home/developer

# ── Wait for Xvfb ────────────────────────────────────────────────────────────
echo "[desktop] Waiting for Xvfb on :1 ..."
for i in $(seq 1 60); do
    if xdpyinfo -display :1 >/dev/null 2>&1; then
        echo "[desktop] Xvfb is ready."
        break
    fi
    sleep 0.5
done

# ── dbus session ──────────────────────────────────────────────────────────────
if ! pgrep -x dbus-daemon >/dev/null 2>&1; then
    dbus-daemon --system --fork 2>/dev/null || true
fi
eval "$(dbus-launch --sh-syntax --exit-with-session 2>/dev/null)" || true

# ── XFCE autostart for Antigravity ───────────────────────────────────────────
mkdir -p /home/developer/.config/autostart
cat > /home/developer/.config/autostart/antigravity.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Antigravity IDE
Comment=Google Antigravity AI-powered IDE
Exec=antigravity --no-sandbox /workspace
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
DESKTOP

# ── Disable XFCE screensaver / power management (annoys remote users) ─────────
mkdir -p /home/developer/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /home/developer/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="saver" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
</channel>
XML

# ── Launch XFCE (foreground — supervisord tracks this PID) ────────────────────
echo "[desktop] Starting XFCE4 session..."
exec startxfce4
