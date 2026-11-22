#!/usr/bin/env bash
set -euo pipefail
image="$1"
build_number="$2"
container="expenso-image-test-${build_number}"
port=18082
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT
docker run -d --name "$container" -p "127.0.0.1:${port}:80" "$image"
deadline=$((SECONDS + 30))
while (( SECONDS < deadline )); do
  if curl --fail --silent "http://host.docker.internal:${port}/" -o /tmp/expenso-image-test.html 2>/dev/null && grep -Eiq '<html|<!doctype' /tmp/expenso-image-test.html; then
    echo "Image smoke test passed on port ${port}."
    exit 0
  fi
  sleep 2
done
echo "Image did not serve the expected HTML on port ${port} within 30 seconds." >&2
exit 1
