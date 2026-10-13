#!/usr/bin/env bash
# Bem Viver ILPI - abre o app (telas) em http://localhost:5173
# Rode DEPOIS de ligar a API (bash iniciar_api_mac_linux.sh, em outro terminal).
set -e
cd "$(dirname "$0")/bemviver"
command -v node > /dev/null || { echo "ERRO: Node.js não encontrado (https://nodejs.org)."; exit 1; }
[ -d node_modules ] || { echo "Instalando as dependências (só na primeira vez)..."; npm install; }
echo "Abrindo o app em http://localhost:5173 — deixe este terminal aberto."
npm run dev
