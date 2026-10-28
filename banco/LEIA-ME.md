# banco/ — scripts que criam o banco do Bem Viver

O instalador (`instalar_windows.bat` ou `instalar_mac_linux.sh`) roda estes arquivos nesta ordem, num banco vazio chamado `ilpi`:

1. `schema_ilpi.sql` — tabelas, tipos, restrições e índices
2. `seed_ilpi.sql` — dados de exemplo
3. `rls_ilpi.sql` — papel `app_user`, segurança por linha e auditoria
4. `../api/setup_api.sql` — senhas e funções de login usadas pela API
5. `etapa04_indices_e_visoes.sql` — índices e visões
6. `etapa05_funcoes_procedimentos_triggers.sql` — funções, procedimentos e triggers
7. `etapa06_exclusao_crud.sql` — permissões de exclusão usadas pelo CRUD

Pastas:

- `consultas/` — consultas avulsas para rodar no psql ou no pgAdmin (`consultas_etapa03.sql` é gerado a partir de `api/consultas.js`).
- `exemplos/` — como cadastrar novos usuários direto pelo SQL.
- `migracoes/` — histórico. Cada migração atualizava um banco já existente para a versão seguinte; tudo isso já está incorporado no `schema_ilpi.sql`, então não é preciso rodá-las numa instalação nova.
