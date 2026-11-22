#!/usr/bin/env bash
set -Eeuo pipefail
image="$1"
name="$2"
port="$3"
build_number="$4"
backup="${name}-rollback-${build_number}"
old_moved=0
new_started=0
rollback() {
  status=$?
  if (( status != 0 )); then
    echo "Deployment failed; attempting rollback." >&2
    if (( new_started )); then docker rm -f "$name" >/dev/null 2>&1 || true; fi
    if (( old_moved )) && docker container inspect "$backup" >/dev/null 2>&1; then
      if docker rename "$backup" "$name" && docker start "$name"; then
        echo "Previous container restored as ${name}." >&2
      else
        echo "Rollback needs attention: previous container remains ${backup}." >&2
      fi
    fi
  fi
  exit "$status"
}
trap rollback EXIT
if docker container inspect "$backup" >/dev/null 2>&1; then
  echo "Rollback container ${backup} already exists; refusing to remove it." >&2
  exit 1
fi
if docker container inspect "$name" >/dev/null 2>&1; then
  docker stop "$name"
  docker rename "$name" "$backup"
  old_moved=1
fi
docker run -d --restart unless-stopped --name "$name" -p "${port}:80" "$image"
new_started=1
deadline=$((SECONDS + 30))
while (( SECONDS < deadline )); do
  if curl --fail --silent "http://host.docker.internal:${port}/" -o /tmp/expenso-deploy.html 2>/dev/null && grep -Eiq '<html|<!doctype' /tmp/expenso-deploy.html; then
    echo "New deployment is healthy on port ${port}."
    if (( old_moved )); then docker rm "$backup" || echo "Warning: could not remove old container ${backup}." >&2; fi
    trap - EXIT
    exit 0
  fi
  sleep 2
done
echo "New deployment did not return the expected HTML on port ${port} within 30 seconds." >&2
exit 1
