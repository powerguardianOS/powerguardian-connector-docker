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

if [ ! -f /etc/nut/ups.conf ]; then
  cat > /etc/nut/ups.conf <<'EOF'
[ups]
    driver = usbhid-ups
    port = auto
    desc = "UPS via USB"
EOF
fi

if [ ! -f /etc/nut/upsmon.conf ]; then
  cat > /etc/nut/upsmon.conf <<'EOF'
MONITOR ups@localhost 1 upsmon pgmonitor primary
SHUTDOWNCMD "/sbin/shutdown -h +0"
POWERDOWNFLAG /etc/killpower
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
MINSUPPLIES 1
EOF
  chmod 640 /etc/nut/upsmon.conf
  chown root:nut /etc/nut/upsmon.conf 2>/dev/null || true
fi

# Clean up stale PID files from previous container runs
rm -f /var/run/nut/*.pid 2>/dev/null || true

# Start UPS driver (only if ups.conf has a driver entry)
if [ -f /etc/nut/ups.conf ] && grep -q '^driver' /etc/nut/ups.conf 2>/dev/null; then
  echo "[pg] Starting NUT driver..."
  upsdrvctl start 2>&1 | sed 's/^/[pg-nut] /' || echo "[pg] Warning: upsdrvctl failed (no UPS connected yet)"
fi

# Start upsd — allow failure before adoption (no ups.conf yet)
echo "[pg] Starting upsd..."
upsd 2>&1 | sed 's/^/[pg-upsd] /' || echo "[pg] Warning: upsd failed to start"

sleep 1

# Start upsmon (notifies on status changes, runs shutdown script)
echo "[pg] Starting upsmon..."
upsmon 2>&1 | sed 's/^/[pg-upsmon] /' || echo "[pg] Warning: upsmon failed (no UPS connected yet)"

echo "[pg] Starting PowerGuardian Connector..."

exec ./pg-connector
