#!/usr/bin/env bash
# End-to-end run: Dendrite on WSA -> local MNN OpenAI-compatible server on the host.
#
# Steps: launch WSA, connect adb, derive the host gateway as seen from WSA, patch
# the cleartext allow-list to that IP, ensure the MNN server is up, then run the
# Flutter integration_test on the WSA device pointed at the server.
#
# Usage:
#   tool/wsa/run_e2e.sh
#   MODEL_DIR=D:/mnn-models/Qwen2.5-0.5B-Instruct-MNN PORT=8080 tool/wsa/run_e2e.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

export PATH="$PATH:/d/adb:/d/flutter/bin"
DEV="${DEV:-127.0.0.1:58526}"
PORT="${PORT:-8080}"
# Recommended local tier (Qwen3 ~2B). Override with MODEL_DIR=... for 0.8B/4B etc.
MODEL_DIR="${MODEL_DIR:-D:/mnn-models/Qwen3-1.7B-MNN}"
MODEL_NAME="$(basename "$MODEL_DIR")"
# Which integration test to run (mnn_e2e_test.dart | ingest_e2e_test.dart).
TEST="${TEST:-integration_test/mnn_e2e_test.dart}"
GH_TOKEN="${DENDRITE_GITHUB_TOKEN:-}"
NSC="android/app/src/main/res/xml/network_security_config.xml"

echo "==> Launching WSA + connecting adb"
explorer.exe "shell:appsFolder\\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App" >/dev/null 2>&1 || true
adb start-server >/dev/null 2>&1 || true
for i in $(seq 1 30); do
  if adb connect "$DEV" 2>/dev/null | grep -qE "connected|already"; then break; fi
  sleep 2
done
for i in $(seq 1 30); do
  [ "$(adb -s "$DEV" get-state 2>/dev/null | tr -d '\r')" = "device" ] && break
  sleep 2
done

echo "==> Deriving host gateway as seen from WSA"
GW="$(adb -s "$DEV" shell ip route show default 2>/dev/null | awk '/default/{print $3; exit}' | tr -d '\r')"
if [ -z "${GW:-}" ]; then
  # No default route printed -> compute network+1 from the on-link kernel route.
  NET="$(adb -s "$DEV" shell ip route 2>/dev/null | awk '/eth0 proto kernel/{print $1; exit}' | tr -d '\r')"
  GW="$(echo "${NET%/*}" | sed 's/\.0$/.1/')"
fi
[ -n "$GW" ] || { echo "could not determine WSA gateway"; exit 1; }
BASE_URL="http://${GW}:${PORT}/v1"
echo "    host gateway = $GW   base URL = $BASE_URL"

echo "==> Patching cleartext allow-list ($NSC) to $GW"
sed -i -E "s#<domain includeSubdomains=\"false\">[0-9.]+</domain> <!-- WSA_HOST -->#<domain includeSubdomains=\"false\">${GW}</domain> <!-- WSA_HOST -->#" "$NSC"

echo "==> Opening firewall for TCP $PORT (best-effort)"
powershell.exe -NoProfile -Command "New-NetFirewallRule -DisplayName 'MNN E2E $PORT' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $PORT -ErrorAction SilentlyContinue | Out-Null" 2>/dev/null || true

echo "==> Ensuring MNN server is up on the host"
if curl -s "http://127.0.0.1:${PORT}/health" | grep -q '"status": "ok"'; then
  echo "    server already running"
else
  echo "    starting server (background) -> tool/mnn/server.log"
  ( python tool/mnn/server.py --host 0.0.0.0 --port "$PORT" \
      --model "${MODEL_DIR}/config.json" --max-tokens 220 --verbose \
      >tool/mnn/server.log 2>&1 & )
  for i in $(seq 1 30); do
    curl -s "http://127.0.0.1:${PORT}/health" | grep -q '"status": "ok"' && break
    sleep 2
  done
fi
# Confirm WSA can actually reach it.
adb -s "$DEV" shell "toybox nc -w 3 $GW $PORT < /dev/null" >/dev/null 2>&1 \
  && echo "    WSA -> host:$PORT reachable" \
  || echo "    WARNING: WSA could not reach host:$PORT (firewall?)"

echo "==> flutter pub get"
flutter pub get >/dev/null

echo "==> Running $TEST on WSA (model: $MODEL_NAME)"
flutter test "$TEST" \
  -d "$DEV" \
  --dart-define=DENDRITE_E2E=true \
  --dart-define=DENDRITE_BASE_URL="$BASE_URL" \
  --dart-define=DENDRITE_MODEL="$MODEL_NAME" \
  --dart-define=DENDRITE_GITHUB_TOKEN="$GH_TOKEN"
