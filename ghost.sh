#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"
env_file=".env"
compose=(docker compose --env-file "$env_file" -f compose.yml -f compose.production.yml)
backup_dir="/home/ubuntu/sergej/websites/cosmonauta.dev/backup"

usage() {
  printf '%s\n' \
    'Uso: ./ghost.sh <comando>' \
    '' \
    '  up                 Avvia Ghost e MySQL in produzione.' \
    '  down               Ferma i container senza eliminare i dati.' \
    '  restart            Riavvia i servizi in produzione.' \
    '  logs [servizio]    Mostra i log (Ghost se il servizio non è indicato).' \
    '  status             Mostra lo stato dei container.' \
    '  pull               Scarica le immagini configurate, senza riavviare.' \
    '  update             Scarica le immagini e ricrea i servizi.' \
    '  backup             Crea un backup completo e applica retention di 30 giorni.' \
    '  export-db          Esporta il database su standard output; usato da local.sh sync.' \
    '  content-path       Stampa il percorso assoluto degli upload; usato da local.sh sync.' \
    '  help               Mostra questa guida.'
}

require_env() {
  [[ -f "$env_file" ]] || { echo "Missing $env_file; copy .env.production.example first." >&2; exit 1; }
}

env_value() {
  "${compose[@]}" config --environment | awk -v prefix="$1=" 'index($0, prefix) == 1 && !found { print substr($0, length(prefix) + 1); found = 1 }'
}

load_env() {
  require_env
  DATABASE_ROOT_PASSWORD="$(env_value DATABASE_ROOT_PASSWORD)"
  UPLOAD_LOCATION="$(env_value UPLOAD_LOCATION)"
  : "${DATABASE_ROOT_PASSWORD:?Set DATABASE_ROOT_PASSWORD in $env_file}"
  : "${UPLOAD_LOCATION:?Set UPLOAD_LOCATION in $env_file}"
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
  exec "${compose[@]}" exec -T -e MYSQL_PWD="$DATABASE_ROOT_PASSWORD" cosmonauta_dev_db \
    mysqldump --single-transaction --routines --triggers --databases ghost -uroot
}

backup() {
  load_env
  local command content_dir timestamp work_dir db_file uploads_file final_file final_tmp
  for command in bzip2 tar find mktemp; do
    command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; return 1; }
  done

  if [[ "$UPLOAD_LOCATION" = /* ]]; then
    content_dir="$UPLOAD_LOCATION"
  else
    content_dir="$root_dir/${UPLOAD_LOCATION#./}"
  fi
  [[ -d "$content_dir" ]] || { echo "Ghost content directory not found: $content_dir" >&2; return 1; }

  mkdir -p -- "$backup_dir"
  timestamp="$(date -u +%Y%m%d_%H%M%S)"
  work_dir="$(mktemp -d "$backup_dir/.backup.XXXXXX")"
  db_file="$work_dir/db.sql"
  uploads_file="$work_dir/upload.tar.bz2"
  final_file="$backup_dir/backup_${timestamp}.tar.bz2"
  final_tmp="$backup_dir/.backup_${timestamp}.tar.bz2"
  trap 'rm -rf -- "$work_dir" "$final_tmp"' EXIT

  echo "Creating database dump..."
  "${compose[@]}" exec -T -e MYSQL_PWD="$DATABASE_ROOT_PASSWORD" cosmonauta_dev_db \
    mysqldump --single-transaction --quick --no-tablespaces --routines --triggers --events --hex-blob --add-drop-table --databases ghost -uroot \
    > "$db_file"
  bzip2 -9 -c "$db_file" > "$work_dir/db.sql.bz2"
  rm -f -- "$db_file"
  bzip2 -t "$work_dir/db.sql.bz2"

  echo "Archiving Ghost content..."
  # Ghost regenerates responsive image derivatives below images/size; originals remain included.
  tar -cjf "$uploads_file" \
    --exclude='images/size' \
    --exclude='images/size/**' \
    -C "$content_dir" .
  tar -tjf "$uploads_file" >/dev/null

  tar -cjf "$final_tmp" -C "$work_dir" db.sql.bz2 upload.tar.bz2
  tar -tjf "$final_tmp" >/dev/null
  mv -- "$final_tmp" "$final_file"

  # Keep exactly the rolling 30-day window; only final backup archives are eligible.
  find "$backup_dir" -maxdepth 1 -type f -name 'backup_*.tar.bz2' -mtime +29 -delete
  trap - EXIT
  rm -rf -- "$work_dir"
  echo "Backup created: $final_file"
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
      update) "${compose[@]}" pull && "${compose[@]}" up -d ;;
      backup) backup ;;
      export-db) export_db ;;
      content-path) content_path ;;
      *) usage >&2; exit 64 ;;
    esac
    ;;
esac
