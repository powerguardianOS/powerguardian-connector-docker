#!/bin/sh
set -e

# Fix ownership of /etc/nut if mounted from host (e.g., root:root 755)
if [ -d /etc/nut ]; then
  chown -R root:nut /etc/nut 2>/dev/null || true
  chmod 750 /etc/nut 2>/dev/null || true
fi

# Create /etc/nut/nut.conf if missing
if [ ! -f /etc/nut/nut.conf ]; then
  echo "MODE=standalone" > /etc/nut/nut.conf
fi

# Create /etc/nut/upsd.conf if missing (listen loopback only — never exposed)
if [ ! -f /etc/nut/upsd.conf ]; then
  echo "LISTEN 127.0.0.1 3493" > /etc/nut/upsd.conf
fi

# Create /etc/nut/upsd.users if missing
# upsmon user: monitors the UPS (used by upsmon daemon)
# admin user: used by pg-connector TCP client for INSTCMD/SET
if [ ! -f /etc/nut/upsd.users ]; then
  cat > /etc/nut/upsd.users <<'EOF'
[upsmon]
    password = pgmonitor
    upsmon primary

[admin]
    password = pgconnector
    actions = SET
    instcmds = ALL
EOF
  chmod 640 /etc/nut/upsd.users
  chown root:nut /etc/nut/upsd.users 2>/dev/null || true
fi

exec ./pg-connector
