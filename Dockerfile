FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG GO_VERSION=1.24.1
ARG NODE_MAJOR=22
# UID/GID for the non-root developer user (override with --build-arg if needed)
ARG DEV_UID=1000
ARG DEV_GID=1000

ENV TZ=UTC
ENV DISPLAY=:1
ENV HOME=/home/developer
ENV GOROOT=/usr/local/go
ENV GOPATH=/home/developer/go
ENV PATH=/usr/local/go/bin:/home/developer/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ── Base system packages ──────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gpg \
    wget \
    git \
    unzip \
    xz-utils \
    # Web proxy
    nginx \
    # Process manager
    supervisor \
    # SSL cert (required by KasmVNC package)
    ssl-cert \
    # X11 / desktop
    x11-utils \
    x11-xserver-utils \
    xauth \
    dbus-x11 \
    xdg-utils \
    # Lightweight desktop
    xfce4 \
    xfce4-terminal \
    xfce4-notifyd \
    xfwm4 \
    # Electron / Antigravity runtime deps
    libgbm1 \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgtk-3-0 \
    libxss1 \
    libasound2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    # Python
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# ── Go ────────────────────────────────────────────────────────────────────────
RUN wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz

# ── Node.js + Yarn + Gemini CLI + OpenCode CLI + Claude Code CLI ──────────────
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g yarn @google/gemini-cli opencode-ai @anthropic-ai/claude-code

# Disable the auto-updater — containers should be rebuilt to update, not
# self-modify at runtime. Can be overridden with -e DISABLE_AUTOUPDATER=0.
ENV DISABLE_AUTOUPDATER=1

# ── Google Antigravity IDE ────────────────────────────────────────────────────
RUN curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg \
        | gpg --dearmor -o /usr/share/keyrings/google-antigravity.gpg \
    && printf \
        'Types: deb\nURIs: https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/\nSuites: antigravity-debian\nComponents: main\nSigned-By: /usr/share/keyrings/google-antigravity.gpg\n' \
        > /etc/apt/sources.list.d/google-antigravity.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends antigravity \
    && rm -rf /var/lib/apt/lists/*

# ── KasmVNC ───────────────────────────────────────────────────────────────────
# Replaces: Xvfb + x11vnc + websockify + noVNC
# Provides: virtual display (Xvnc), VNC server, WebSocket bridge, web client,
#           and built-in authentication — all in one package.
RUN apt-get update \
    && curl -fsSL -o /tmp/kasmvnc.deb \
        https://github.com/kasmtech/KasmVNC/releases/download/v1.3.4/kasmvncserver_jammy_1.3.4_amd64.deb \
    && apt-get install -y /tmp/kasmvnc.deb \
    && rm /tmp/kasmvnc.deb \
    && rm -rf /var/lib/apt/lists/*

# ── Non-root developer user ───────────────────────────────────────────────────
# All desktop programs (KasmVNC/Xvnc, XFCE, Antigravity) run as this user.
# Nginx and supervisord remain root for system management only.
RUN groupadd -g "${DEV_GID}" developer \
    && useradd -m -s /bin/bash -u "${DEV_UID}" -g developer developer \
    && usermod -aG ssl-cert developer \
    && mkdir -p /home/developer/go /workspace \
    && chown -R developer:developer /home/developer /workspace

# ── Nginx: replace default site ───────────────────────────────────────────────
RUN rm -f /etc/nginx/sites-enabled/default

# ── Config + scripts ──────────────────────────────────────────────────────────
COPY config/nginx.conf          /etc/nginx/sites-available/antigravity
COPY config/supervisord.conf    /etc/supervisor/conf.d/antigravity.conf
COPY config/kasmvnc.yaml        /etc/kasmvnc/kasmvnc.yaml
COPY scripts/entrypoint.sh      /usr/local/bin/entrypoint.sh
COPY scripts/start-kasmvnc.sh  /usr/local/bin/start-kasmvnc.sh
COPY scripts/start-desktop.sh  /usr/local/bin/start-desktop.sh

RUN chmod +x \
        /usr/local/bin/entrypoint.sh \
        /usr/local/bin/start-kasmvnc.sh \
        /usr/local/bin/start-desktop.sh \
    && ln -s /etc/nginx/sites-available/antigravity /etc/nginx/sites-enabled/antigravity

# ── Log dir (owned by root, supervisord writes here) ─────────────────────────
RUN mkdir -p /var/log/supervisor

# ── Volumes for persistence ───────────────────────────────────────────────────
# /workspace                                 - user code
# /home/developer/.config/google-antigravity - IDE settings, auth tokens
# /home/developer/.config/google-chrome      - Chrome profile (Google OAuth session)
VOLUME ["/workspace", "/home/developer/.config/google-antigravity", "/home/developer/.config/google-chrome"]

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
