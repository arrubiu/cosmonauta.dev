#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"
env_file=".env.local"
compose=(docker compose --env-file "$env_file" -f compose.yml -f compose.local.yml)
production_repository_dir="/home/ubuntu/sergej/websites/cosmonauta.dev/ghost"
production_backup_dir="/home/ubuntu/sergej/websites/cosmonauta.dev/backup"

usage() {
  printf '%s\n' \
    'Uso: ./local.sh <comando>' \
    '' \
    '  up                 Avvia Ghost e MySQL locali su http://localhost:2368.' \
    '  down               Ferma i container locali senza eliminare i dati.' \
    '  restart            Riavvia i servizi locali.' \
    '  logs [servizio]    Mostra i log (Ghost se il servizio non è indicato).' \
    '  status             Mostra lo stato dei container locali.' \
    '  pull               Scarica le immagini configurate, senza riavviare.' \
    '  sync [--yes]       Sostituisce dati e upload locali con quelli di produzione.' \
    '  help               Mostra questa guida.'
}

require_env() {
  [[ -f "$env_file" ]] || { echo "Missing $env_file; copy .env.local.example first." >&2; exit 1; }
}

env_value() {
  "${compose[@]}" config --environment | awk -v prefix="$1=" 'index($0, prefix) == 1 && !found { print substr($0, length(prefix) + 1); found = 1 }'
}

load_env() {
  require_env
  DATABASE_ROOT_PASSWORD="$(env_value DATABASE_ROOT_PASSWORD)"
  UPLOAD_LOCATION="$(env_value UPLOAD_LOCATION)"
  MYSQL_DATA_LOCATION="$(env_value MYSQL_DATA_LOCATION)"
  PRODUCTION_SSH="$(env_value PRODUCTION_SSH)"
  : "${DATABASE_ROOT_PASSWORD:?Set DATABASE_ROOT_PASSWORD in $env_file}"
  : "${UPLOAD_LOCATION:?Set UPLOAD_LOCATION in $env_file}"
  : "${MYSQL_DATA_LOCATION:?Set MYSQL_DATA_LOCATION in $env_file}"
}

wait_for_db() {
  for _ in {1..60}; do
    if "${compose[@]}" exec -T -e MYSQL_PWD="$DATABASE_ROOT_PASSWORD" cosmonauta_dev_db mysqladmin -uroot ping -h 127.0.0.1 --silent; then
      return
    fi
    sleep 2
  done
  echo "MySQL did not become ready in time." >&2
  exit 1
}

remote_ghost() {
  local subcommand remote_command
  subcommand="$1"
  printf -v remote_command 'cd %q && ./ghost.sh %q' "$production_repository_dir" "$subcommand"
  # shellcheck disable=SC2029 # The fully quoted remote command is intentionally built on this host.
  ssh "$PRODUCTION_SSH" "$remote_command"
}

sync_from_production() {
  load_env
  : "${PRODUCTION_SSH:?Set PRODUCTION_SSH in .env.local}"
  if [[ "${1:-}" != "--yes" ]]; then
    read -r -p "This replaces ALL local Ghost uploads and database with production data. Continue? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || exit 0
  fi

  "${compose[@]}" down
  echo "Synchronizing from ${PRODUCTION_SSH}:${production_repository_dir} (backups: ${production_backup_dir})."
  remote_upload_path="$(remote_ghost content-path)"
  [[ "$remote_upload_path" = /* ]] || { echo "Production returned an invalid upload path." >&2; exit 1; }
  mkdir -p "${UPLOAD_LOCATION}" "${MYSQL_DATA_LOCATION}"
  rsync -az --delete "${PRODUCTION_SSH}:${remote_upload_path}/" "${UPLOAD_LOCATION}/"
  "${compose[@]}" up -d cosmonauta_dev_db
  wait_for_db
  "${compose[@]}" exec -T -e MYSQL_PWD="$DATABASE_ROOT_PASSWORD" cosmonauta_dev_db mysql -uroot -e 'DROP DATABASE IF EXISTS ghost;'
  remote_ghost export-db | "${compose[@]}" exec -T -e MYSQL_PWD="$DATABASE_ROOT_PASSWORD" cosmonauta_dev_db mysql -uroot
  "${compose[@]}" up -d cosmonauta_dev_ghost
  echo "Local Ghost now matches production. It remains local-only."
}

case "${1:-}" in
  ""|help|-h|--help) usage ;;
  *)
    require_env
    case "$1" in
      up) "${compose[@]}" up -d ;;
      down) "${compose[@]}" down ;;
      restart) "${compose[@]}" restart ;;
      logs) "${compose[@]}" logs -f "${2:-cosmonauta_dev_ghost}" ;;
      status|ps) "${compose[@]}" ps ;;
      pull) "${compose[@]}" pull ;;
      sync) sync_from_production "${2:-}" ;;
      *) usage >&2; exit 64 ;;
    esac
    ;;
esac
