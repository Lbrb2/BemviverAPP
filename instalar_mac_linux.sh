#!/usr/bin/env bash
# ============================================================
#  Bem Viver ILPI — Instalador (Mac/Linux)
#  Uso: abra o Terminal na pasta do projeto e rode
#       bash instalar_mac_linux.sh
# ============================================================
set -e
cd "$(dirname "$0")"
export PGCLIENTENCODING=UTF8

echo ""
echo " === Bem Viver ILPI — Instalação do banco de dados ==="
echo ""

if ! command -v psql > /dev/null; then
  echo " ERRO: não encontrei o PostgreSQL (psql)."
  echo " Mac: brew install postgresql@16 && brew services start postgresql@16"
  echo " Linux: sudo apt install postgresql"
  exit 1
fi

read -s -p " Digite a senha do usuário 'postgres' (Enter se não houver senha): " PGPASSWORD
export PGPASSWORD
echo ""

echo " [1/6] Criando o banco 'ilpi'..."
createdb -h localhost -U postgres ilpi 2>/dev/null || echo "       (o banco já existia — tudo bem, seguindo em frente)"

echo " [2/6] Criando as tabelas (schema_ilpi.sql)..."
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f schema_ilpi.sql

echo " [3/6] Inserindo os dados de exemplo (seed_ilpi.sql)..."
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f seed_ilpi.sql

echo " [4/6] Aplicando a segurança por linha (rls_ilpi.sql)..."
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f rls_ilpi.sql

echo " [5/6] Preparando a API (api/setup_api.sql)..."
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f api/setup_api.sql

echo " [6/6] Índices, visões, funções, procedimentos e triggers (Etapas 04 e 05)..."
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f entregas_bd/etapa04/etapa04_indices_e_visoes.sql
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f entregas_bd/etapa05/etapa05_funcoes_procedimentos_triggers.sql

echo ""
echo " === Tudo pronto! ==="
echo " Agora rode:  bash iniciar_api_mac_linux.sh"
echo " e, em outro terminal:  bash iniciar_app_mac_linux.sh"
echo ""
