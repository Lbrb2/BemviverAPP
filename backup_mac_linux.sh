#!/usr/bin/env bash
#  Bem Viver ILPI — Backup do banco (Mac/Linux)
set -e
cd "$(dirname "$0")"
mkdir -p backups
read -s -p " Senha do usuário postgres (Enter se não houver): " PGPASSWORD; export PGPASSWORD; echo ""
ARQ="backups/ilpi_$(date +%F_%H%M).backup"
pg_dump -h localhost -U postgres -F c -f "$ARQ" ilpi
echo " Backup criado: $ARQ"
echo " Para restaurar: pg_restore -h localhost -U postgres -d ilpi --clean \"$ARQ\""
echo " Dica: agende no cron para rodar todo dia (ex.: 0 2 * * *)."
