-- ============================================================
-- Migração 006: edição e desativação de usuários pelo gestor
-- Desativar NUNCA apaga — preserva histórico (LGPD). Um usuário
-- inativo não loga e some das listas operacionais.
-- ============================================================

BEGIN;

-- profissional ganha "ativo" (idoso já tinha); default TRUE
ALTER TABLE profissional ADD COLUMN IF NOT EXISTS ativo BOOLEAN NOT NULL DEFAULT TRUE;

-- Políticas de UPDATE para o gestor, na própria ILPI
CREATE POLICY upd_idoso_gestor ON idoso FOR UPDATE TO app_user
    USING (fn_sou_gestor() AND id_ilpi = fn_minha_ilpi_profissional())
    WITH CHECK (fn_sou_gestor() AND id_ilpi = fn_minha_ilpi_profissional());

CREATE POLICY upd_prof_gestor ON profissional FOR UPDATE TO app_user
    USING (fn_sou_gestor() AND id_ilpi = fn_minha_ilpi_profissional())
    WITH CHECK (fn_sou_gestor() AND id_ilpi = fn_minha_ilpi_profissional());

GRANT UPDATE ON idoso, profissional, usuario, responsavel TO app_user;

COMMIT;
