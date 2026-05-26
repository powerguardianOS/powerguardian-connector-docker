#!/bin/sh
set -e

# Fix ownership of /etc/nut if mounted from host
if [ -d /etc/nut ]; then
  chown -R root:nut /etc/nut 2>/dev/null || true
  chmod 750 /etc/nut 2>/dev/null || true
fi

if [ ! -f /etc/nut/nut.conf ]; then
  echo "MODE=standalone" > /etc/nut/nut.conf
fi

if [ ! -f /etc/nut/upsd.conf ]; then
  echo "LISTEN 127.0.0.1 3493" > /etc/nut/upsd.conf
fi

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

# Start UPS drivers if ups.conf exists with driver entries
if [ -f /etc/nut/ups.conf ]; then
  if grep -q '^driver' /etc/nut/ups.conf 2>/dev/null; then
    upsdrvctl start || true
  fi
fi

# Start upsd — allow failure before adoption (no ups.conf yet)
upsd || true

exec ./pg-connector
