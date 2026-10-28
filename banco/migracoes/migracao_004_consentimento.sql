-- ============================================================
-- Migração 004: Consentimento LGPD com RLS
-- Quem concede/revoga é o responsável legal; idoso, responsáveis
-- e equipe da ILPI podem consultar o status.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_sou_responsavel_legal(p_id_idoso int) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT EXISTS (
     SELECT 1 FROM vinculo_responsavel v
     JOIN responsavel r USING (id_responsavel)
    WHERE r.id_usuario = fn_usuario_atual()
      AND v.id_idoso = p_id_idoso
      AND v.responsavel_legal) $$;

ALTER TABLE consentimento_lgpd ENABLE ROW LEVEL SECURITY;
ALTER TABLE consentimento_lgpd FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_consentimento ON consentimento_lgpd FOR SELECT TO app_user
    USING (
        id_idoso = fn_meu_id_idoso()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
    );

CREATE POLICY ins_consentimento ON consentimento_lgpd FOR INSERT TO app_user
    WITH CHECK (fn_sou_responsavel_legal(id_idoso));

-- Revogar = atualizar data_revogacao; só o responsável legal
CREATE POLICY upd_consentimento ON consentimento_lgpd FOR UPDATE TO app_user
    USING (fn_sou_responsavel_legal(id_idoso))
    WITH CHECK (fn_sou_responsavel_legal(id_idoso));

CREATE TRIGGER trg_aud_consentimento AFTER INSERT OR UPDATE OR DELETE ON consentimento_lgpd
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_consentimento');

COMMIT;
