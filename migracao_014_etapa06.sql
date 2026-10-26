-- ============================================================
-- Migração 014 (Etapa 06): exclusão em atividade_lazer e recado_plantao
-- Completa o CRUD dessas duas tabelas na interface (criar, ler, editar
-- e excluir). Executar depois de rls_ilpi.sql. Pode rodar mais de uma vez.
-- ============================================================
SET client_min_messages = warning;

-- Atividade da agenda: a equipe da própria ILPI pode excluir.
-- (A API só deixa excluir atividade sem presenças confirmadas: presença
-- já deu pontos ao Xodó e faz parte do histórico do residente.)
GRANT DELETE ON atividade_lazer TO app_user;
DROP POLICY IF EXISTS del_atividade_equipe ON atividade_lazer;
CREATE POLICY del_atividade_equipe ON atividade_lazer FOR DELETE TO app_user
    USING (id_ilpi = fn_minha_ilpi_profissional());

-- Recado da passagem de plantão: só quem escreveu, ou o gestor da ILPI,
-- pode excluir. As ciências ("li") do recado saem junto (ON DELETE CASCADE).
GRANT DELETE ON recado_plantao TO app_user;
DROP POLICY IF EXISTS del_plantao ON recado_plantao;
CREATE POLICY del_plantao ON recado_plantao FOR DELETE TO app_user
    USING (id_ilpi = fn_minha_ilpi_profissional()
           AND (id_profissional = fn_meu_id_profissional() OR fn_sou_gestor()));
