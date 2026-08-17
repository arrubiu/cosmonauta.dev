#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"
env_file=".env"
compose=(docker compose --env-file "$env_file" -f compose.yml -f compose.production.yml)

require_env() {
  [[ -f "$env_file" ]] || { echo "Missing $env_file; copy .env.production.example first." >&2; exit 1; }
}

load_env() {
  require_env
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

content_path() {
  load_env
  if [[ "$UPLOAD_LOCATION" = /* ]]; then
    printf '%s\n' "$UPLOAD_LOCATION"
  else
    printf '%s/%s\n' "$root_dir" "${UPLOAD_LOCATION#./}"
  fi
}

export_db() {
  load_env
  exec "${compose[@]}" exec -T -e MYSQL_PWD="$DATABASE_ROOT_PASSWORD" db \
    mysqldump --single-transaction --routines --triggers --databases ghost -uroot
}

require_env
case "${1:-}" in
  up) "${compose[@]}" up -d ;;
  down) "${compose[@]}" down ;;
  restart) "${compose[@]}" restart ;;
  logs) "${compose[@]}" logs -f "${2:-ghost}" ;;
  status|ps) "${compose[@]}" ps ;;
  pull) "${compose[@]}" pull ;;
  update) "${compose[@]}" pull && "${compose[@]}" up -d ;;
  export-db) export_db ;;
  content-path) content_path ;;
  *) echo "Usage: $0 {up|down|restart|logs [service]|status|pull|update|export-db|content-path}" >&2; exit 64 ;;
esac
