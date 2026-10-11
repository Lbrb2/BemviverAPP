#!/usr/bin/env bash
# ============================================================
#  Bem Viver ILPI — Inicia a API (Mac/Linux)
#  Uso: bash iniciar_api_mac_linux.sh
#  Deixe o Terminal aberto enquanto usa o jogo (Ctrl+C desliga).
# ============================================================
set -e
cd "$(dirname "$0")/api"

if ! command -v node > /dev/null; then
  echo " ERRO: Node.js não encontrado. Instale em https://nodejs.org"
  exit 1
fi

if [ ! -d node_modules ]; then
  echo " Instalando as dependências (só na primeira vez)..."
  npm install
fi

export PGDATABASE=ilpi
echo ""
echo " Subindo a API em http://localhost:3000  (Ctrl+C para desligar)"
echo ""
npm start
