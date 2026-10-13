@echo off
setlocal
REM ============================================================
REM  Bem Viver ILPI - Abre o app (telas) - Windows
REM  De um duplo clique DEPOIS de ligar a API (iniciar_api_windows.bat).
REM  O navegador abre sozinho em http://localhost:5173
REM  Deixe esta janela aberta; para desligar o app, feche-a.
REM ============================================================

echo.
echo  === Bem Viver ILPI - App ===
echo.

if not exist "%~dp0bemviver\package.json" (
    echo  ERRO: nao encontrei a pasta "bemviver" ao lado deste arquivo.
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

cd /d "%~dp0bemviver"

if not exist node_modules (
    echo  Instalando as dependencias... isso acontece so na primeira vez.
    call npm install
    if errorlevel 1 (
        echo  ERRO: a instalacao das dependencias falhou. Veja a mensagem acima.
        pause
        exit /b 1
    )
)

echo.
echo  Abrindo o app em http://localhost:5173
echo  A API precisa estar ligada na outra janela (iniciar_api_windows.bat).
echo  Deixe esta janela aberta. Feche-a para desligar o app.
echo.
call npm run dev
echo.
echo  O app foi encerrado. Se foi um erro, a mensagem esta acima.
pause
