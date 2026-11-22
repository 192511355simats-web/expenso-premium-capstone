#!/usr/bin/env bash
set -euo pipefail
port="$1"
curl --fail --silent --show-error "http://host.docker.internal:${port}/" -o /tmp/expenso-live.html
grep -Eiq '<html|<!doctype' /tmp/expenso-live.html
echo "Deployment verified at http://localhost:${port}/."
