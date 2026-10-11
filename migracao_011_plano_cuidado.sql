-- ============================================================
-- Migração 011: Plano de cuidado individual
-- Metas de cuidado por idoso (PDI/PII — plano individual de
-- atendimento, previsto na RDC 502). Cada meta tem categoria,
-- descrição, status e data de revisão.
-- ============================================================

BEGIN;

CREATE TYPE status_meta AS ENUM ('ativa', 'atingida', 'suspensa');
CREATE TYPE categoria_meta AS ENUM ('saude', 'mobilidade', 'nutricao', 'social', 'cognitiva', 'emocional', 'autonomia');

CREATE TABLE meta_cuidado (
    id_meta          SERIAL PRIMARY KEY,
    id_idoso         INT NOT NULL REFERENCES idoso(id_idoso),
    id_profissional  INT NOT NULL REFERENCES profissional(id_profissional),
    categoria        categoria_meta NOT NULL,
    descricao        VARCHAR(300) NOT NULL CHECK (length(trim(descricao)) > 0),
    status           status_meta NOT NULL DEFAULT 'ativa',
    data_criacao     DATE NOT NULL DEFAULT CURRENT_DATE,
    data_revisao     DATE,               -- quando reavaliar
    data_conclusao   DATE
);

CREATE TABLE evolucao_meta (
    id_evolucao   SERIAL PRIMARY KEY,
    id_meta       INT NOT NULL REFERENCES meta_cuidado(id_meta) ON DELETE CASCADE,
    id_profissional INT NOT NULL REFERENCES profissional(id_profissional),
    nota          VARCHAR(500) NOT NULL,
    data_hora     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_meta_idoso ON meta_cuidado (id_idoso, status);

ALTER TABLE meta_cuidado ENABLE ROW LEVEL SECURITY;
ALTER TABLE meta_cuidado FORCE ROW LEVEL SECURITY;
ALTER TABLE evolucao_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE evolucao_meta FORCE ROW LEVEL SECURITY;

-- Metas: equipe da ILPI e responsável/idoso podem ver; equipe edita.
CREATE POLICY sel_meta ON meta_cuidado FOR SELECT TO app_user
    USING (
        fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR id_idoso = fn_meu_id_idoso()
    );
CREATE POLICY ins_meta ON meta_cuidado FOR INSERT TO app_user
    WITH CHECK (id_profissional = fn_meu_id_profissional()
                AND fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());
CREATE POLICY upd_meta ON meta_cuidado FOR UPDATE TO app_user
    USING (fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional())
    WITH CHECK (fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());

CREATE POLICY sel_evol_meta ON evolucao_meta FOR SELECT TO app_user
    USING (EXISTS (SELECT 1 FROM meta_cuidado m WHERE m.id_meta = evolucao_meta.id_meta
                    AND (fn_ilpi_do_idoso(m.id_idoso) = fn_minha_ilpi_profissional()
                         OR m.id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
                         OR m.id_idoso = fn_meu_id_idoso())));
CREATE POLICY ins_evol_meta ON evolucao_meta FOR INSERT TO app_user
    WITH CHECK (id_profissional = fn_meu_id_profissional()
                AND EXISTS (SELECT 1 FROM meta_cuidado m WHERE m.id_meta = evolucao_meta.id_meta
                             AND fn_ilpi_do_idoso(m.id_idoso) = fn_minha_ilpi_profissional()));

GRANT SELECT, INSERT, UPDATE ON meta_cuidado TO app_user;
GRANT SELECT, INSERT ON evolucao_meta TO app_user;
GRANT USAGE ON SEQUENCE meta_cuidado_id_meta_seq, evolucao_meta_id_evolucao_seq TO app_user;

CREATE TRIGGER trg_aud_meta AFTER INSERT OR UPDATE OR DELETE ON meta_cuidado
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_meta');

COMMIT;
