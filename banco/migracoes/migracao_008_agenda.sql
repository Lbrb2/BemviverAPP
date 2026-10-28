-- ============================================================
-- Migração 008: Agenda de atividades
-- Ativa as tabelas atividade_lazer e participacao com RLS,
-- e permite a equipe criar eventos e o idoso confirmar presença.
-- ============================================================

BEGIN;

-- RLS nas atividades (todos da ILPI veem; equipe cria)
ALTER TABLE atividade_lazer ENABLE ROW LEVEL SECURITY;
ALTER TABLE atividade_lazer FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_atividade ON atividade_lazer FOR SELECT TO app_user
    USING (
        id_ilpi = fn_minha_ilpi_profissional()
        OR id_ilpi = fn_ilpi_do_idoso(fn_meu_id_idoso())
        OR id_ilpi IN (SELECT DISTINCT fn_ilpi_do_idoso(id_idoso)
                         FROM (SELECT fn_idosos_sob_minha_responsabilidade() AS id_idoso) t)
    );

CREATE POLICY ins_atividade_equipe ON atividade_lazer FOR INSERT TO app_user
    WITH CHECK (id_ilpi = fn_minha_ilpi_profissional());

CREATE POLICY upd_atividade_equipe ON atividade_lazer FOR UPDATE TO app_user
    USING (id_ilpi = fn_minha_ilpi_profissional())
    WITH CHECK (id_ilpi = fn_minha_ilpi_profissional());

-- RLS na participação (o idoso confirma a sua; equipe vê/registra da ILPI)
ALTER TABLE participacao ENABLE ROW LEVEL SECURITY;
ALTER TABLE participacao FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_participacao ON participacao FOR SELECT TO app_user
    USING (
        id_idoso = fn_meu_id_idoso()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
    );

CREATE POLICY ins_participacao_self ON participacao FOR INSERT TO app_user
    WITH CHECK (id_idoso = fn_meu_id_idoso());

CREATE POLICY ins_participacao_equipe ON participacao FOR INSERT TO app_user
    WITH CHECK (fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());

GRANT SELECT, INSERT, UPDATE ON atividade_lazer TO app_user;
GRANT SELECT, INSERT ON participacao TO app_user;
GRANT USAGE ON SEQUENCE atividade_lazer_id_atividade_seq TO app_user;

CREATE TRIGGER trg_aud_atividade AFTER INSERT OR UPDATE OR DELETE ON atividade_lazer
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_atividade');

COMMIT;
