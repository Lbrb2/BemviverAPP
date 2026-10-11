@echo off
setlocal
REM ============================================================
REM  Bem Viver ILPI - Inicia a API - Windows
REM  De um duplo clique. Deixe esta janela aberta enquanto usa
REM  o app; para desligar a API, basta fechar a janela.
REM ============================================================

echo.
echo  === Bem Viver ILPI - API ===
echo.

if not exist "%~dp0api\package.json" (
    echo  ERRO: nao encontrei a pasta "api" ao lado deste arquivo.
    echo  Extraia o ZIP inteiro antes de rodar - nao execute de dentro do ZIP.
    pause
    exit /b 1
)

where node >nul 2>nul
if errorlevel 1 (
    echo  ERRO: Node.js nao encontrado.
    echo  Instale em https://nodejs.org e rode este arquivo de novo.
    pause
    exit /b 1
)

cd /d "%~dp0api"

if not exist node_modules (
    echo  Instalando as dependencias... isso acontece so na primeira vez.
    call npm install
    if errorlevel 1 (
        echo  ERRO: a instalacao das dependencias falhou. Veja a mensagem acima.
        pause
        exit /b 1
    )
)

set PGDATABASE=ilpi
echo.
echo  Subindo a API em http://localhost:3000
echo  Deixe esta janela aberta. Feche-a para desligar a API.
echo.
call npm start
echo.
echo  A API foi encerrada. Se foi um erro, a mensagem esta acima.
pause
