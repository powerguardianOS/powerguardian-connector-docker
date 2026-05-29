#!/bin/sh
set -e

NUT_DEFAULTS=/app/nut-defaults
NUT_DIR=/etc/nut

# Fix ownership of /etc/nut
chown -R root:nut "$NUT_DIR" 2>/dev/null || true
chmod 750 "$NUT_DIR" 2>/dev/null || true

# Seed /etc/nut from image defaults — only if not already present (allows volume overrides)
for f in nut.conf ups.conf upsd.conf upsd.users upsmon.conf; do
  if [ ! -f "$NUT_DIR/$f" ]; then
    cp "$NUT_DEFAULTS/$f" "$NUT_DIR/$f"
    chown root:nut "$NUT_DIR/$f" 2>/dev/null || true
  fi
done
chmod 640 "$NUT_DIR/upsd.users" "$NUT_DIR/upsmon.conf" 2>/dev/null || true

# Clean up stale PID files from previous container runs
rm -f /var/run/nut/*.pid 2>/dev/null || true

# Start NUT driver (soft failure — UPS may not be connected yet)
echo "[pg] Starting NUT driver..."
upsdrvctl start 2>&1 | sed 's/^/[pg-nut] /' || echo "[pg] Warning: upsdrvctl failed (no UPS connected yet)"

# Start NUT data server — let it daemonize normally
echo "[pg] Starting upsd..."
upsd 2>&1 && echo "[pg] upsd started" || echo "[pg] Warning: upsd failed to start"
sleep 2

# Start upsmon
echo "[pg] Starting upsmon..."
upsmon 2>&1 | sed 's/^/[pg-upsmon] /' || echo "[pg] Warning: upsmon failed (no UPS connected yet)"

echo "[pg] Starting PowerGuardian Connector..."
exec ./pg-connector
