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

exec ./pg-connector
