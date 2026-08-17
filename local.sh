#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"
env_file=".env.local"
compose=(docker compose --env-file "$env_file" -f compose.yml -f compose.local.yml)

require_env() {
  [[ -f "$env_file" ]] || { echo "Missing $env_file; copy .env.local.example first." >&2; exit 1; }
}

load_env() {
  require_env
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

wait_for_db() {
  local attempt
  for attempt in {1..60}; do
    if "${compose[@]}" exec -T -e MYSQL_PWD="$DATABASE_ROOT_PASSWORD" db mysqladmin -uroot ping -h 127.0.0.1 --silent; then
      return
    fi
    sleep 2
  done
  echo "MySQL did not become ready in time." >&2
  exit 1
}

sync_from_production() {
  load_env
  : "${PRODUCTION_SSH:?Set PRODUCTION_SSH in .env.local}"
  : "${PRODUCTION_PROJECT_DIR:?Set PRODUCTION_PROJECT_DIR in .env.local}"
  if [[ "${1:-}" != "--yes" ]]; then
    read -r -p "This replaces ALL local Ghost uploads and database with production data. Continue? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || exit 0
  fi

  "${compose[@]}" down
  remote_upload_path="$(ssh "$PRODUCTION_SSH" "cd '$PRODUCTION_PROJECT_DIR' && ./ghost.sh content-path")"
  [[ "$remote_upload_path" = /* ]] || { echo "Production returned an invalid upload path." >&2; exit 1; }
  mkdir -p "${UPLOAD_LOCATION}" "${MYSQL_DATA_LOCATION}"
  rsync -az --delete "${PRODUCTION_SSH}:${remote_upload_path}/" "${UPLOAD_LOCATION}/"
  "${compose[@]}" up -d db
  wait_for_db
  "${compose[@]}" exec -T -e MYSQL_PWD="$DATABASE_ROOT_PASSWORD" db mysql -uroot -e 'DROP DATABASE IF EXISTS ghost;'
  ssh "$PRODUCTION_SSH" "cd '$PRODUCTION_PROJECT_DIR' && ./ghost.sh export-db" | "${compose[@]}" exec -T -e MYSQL_PWD="$DATABASE_ROOT_PASSWORD" db mysql -uroot
  "${compose[@]}" up -d ghost
  echo "Local Ghost now matches production. It remains local-only."
}

require_env
case "${1:-}" in
  up) "${compose[@]}" up -d ;;
  down) "${compose[@]}" down ;;
  restart) "${compose[@]}" restart ;;
  logs) "${compose[@]}" logs -f "${2:-ghost}" ;;
  status|ps) "${compose[@]}" ps ;;
  pull) "${compose[@]}" pull ;;
  sync) sync_from_production "${2:-}" ;;
  *) echo "Usage: $0 {up|down|restart|logs [service]|status|pull|sync [--yes]}" >&2; exit 64 ;;
esac
