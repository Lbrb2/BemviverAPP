@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
set PGCLIENTENCODING=UTF8
REM ============================================================
REM  Bem Viver ILPI - Instalador (Windows)
REM  De um duplo clique neste arquivo. Ele cria o banco "ilpi"
REM  e roda os quatro scripts SQL na ordem certa.
REM ============================================================

echo.
echo  === Bem Viver ILPI - Instalacao do banco de dados ===
echo.

REM Procura o PostgreSQL caso nao esteja no PATH
where psql >nul 2>nul
if errorlevel 1 (
    for /d %%G in ("C:\Program Files\PostgreSQL\*") do set "PGBIN=%%G\bin"
    if defined PGBIN (
        set "PATH=!PGBIN!;!PATH!"
        echo  PostgreSQL encontrado em: !PGBIN!
    ) else (
        echo  ERRO: nao encontrei o PostgreSQL instalado.
        echo  Instale em https://www.postgresql.org/download/windows/
        echo  e rode este arquivo de novo.
        pause
        exit /b 1
    )
)

set /p PGPASSWORD= Digite a senha do usuario "postgres" - a que voce definiu ao instalar: 

echo.
echo  [1/6] Criando o banco "ilpi"...
createdb -h localhost -U postgres ilpi 2>nul
if errorlevel 1 echo        O banco ja existia - tudo bem, seguindo em frente.

echo  [2/6] Criando as tabelas (schema_ilpi.sql)...
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f schema_ilpi.sql
if errorlevel 1 goto erro

echo  [3/6] Inserindo os dados de exemplo (seed_ilpi.sql)...
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f seed_ilpi.sql
if errorlevel 1 goto erro

echo  [4/6] Aplicando a seguranca por linha (rls_ilpi.sql)...
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f rls_ilpi.sql
if errorlevel 1 goto erro

echo  [5/6] Preparando a API (api\setup_api.sql)...
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f api\setup_api.sql
if errorlevel 1 goto erro

echo  [6/6] Indices, visoes, funcoes, procedimentos e triggers (Etapas 04 a 06)...
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f entregas_bd\etapa04\etapa04_indices_e_visoes.sql
if errorlevel 1 goto erro
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f entregas_bd\etapa05\etapa05_funcoes_procedimentos_triggers.sql
if errorlevel 1 goto erro
psql -h localhost -U postgres -d ilpi -v ON_ERROR_STOP=1 -q -f migracao_014_etapa06.sql
if errorlevel 1 goto erro

echo.
echo  === Tudo pronto! ===
echo  Agora de um duplo clique em "iniciar_api_windows.bat" para subir a API
echo  e, com ela aberta, em "iniciar_app_windows.bat" para abrir o app.
echo.
pause
exit /b 0

:erro
echo.
echo  ERRO: um dos scripts falhou. A mensagem acima diz qual foi.
echo  Dica: se ja tinha rodado a instalacao antes, apague o banco
echo  no pgAdmin - botao direito no banco ilpi, Delete - e tente de novo.
echo.
pause
exit /b 1
