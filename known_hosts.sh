#!/bin/bash
set -euo pipefail

BASE_PREFIX="10.38.94"
PORT=25372

for i in {1..254}; do
  IP="${BASE_PREFIX}.${i}"

  # Удаление записи для IP (стандартный порт 22)
  ssh-keygen -R "$IP" 2>/dev/null || true

  # Удаление записи для IP с портом 25372 (формат [ip]:port)
  ssh-keygen -R "[${IP}]:${PORT}" 2>/dev/null || true
done
