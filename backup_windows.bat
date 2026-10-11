@echo off
setlocal enabledelayedexpansion
REM  Bem Viver ILPI - Backup do banco - Windows
REM  Gera um arquivo em .\backups com data e hora no nome.

where pg_dump >nul 2>nul
if errorlevel 1 (
    for /d %%G in ("C:\Program Files\PostgreSQL\*") do set "PGBIN=%%G\bin"
    if defined PGBIN set "PATH=!PGBIN!;!PATH!"
)
where pg_dump >nul 2>nul
if errorlevel 1 (
    echo  ERRO: nao encontrei o pg_dump do PostgreSQL.
    pause
    exit /b 1
)

set /p PGPASSWORD= Senha do usuario postgres: 
if not exist "%~dp0backups" mkdir "%~dp0backups"
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HHmm"') do set STAMP=%%I

pg_dump -h localhost -U postgres -F c -f "%~dp0backups\ilpi_%STAMP%.backup" ilpi
if errorlevel 1 (
    echo  ERRO ao gerar o backup. Veja a mensagem acima.
) else (
    echo  Backup criado: backups\ilpi_%STAMP%.backup
    echo  Para restaurar: pg_restore -h localhost -U postgres -d ilpi --clean "arquivo.backup"
)
pause
