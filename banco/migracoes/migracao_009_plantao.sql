-- ============================================================
-- Migração 009: Passagem de plantão
-- Recados internos da equipe entre turnos. Podem ser gerais ou
-- sobre um idoso específico. Prioridade sinaliza urgência.
-- "Ciência" registra quem já leu (accountability de plantão).
-- Conteúdo clínico interno: visível só à equipe da ILPI.
-- ============================================================

BEGIN;

CREATE TYPE turno_plantao AS ENUM ('manha', 'tarde', 'noite');
CREATE TYPE prioridade_plantao AS ENUM ('rotina', 'atencao', 'urgente');

CREATE TABLE recado_plantao (
    id_recado       SERIAL PRIMARY KEY,
    id_ilpi         INT NOT NULL REFERENCES ilpi(id_ilpi),
    id_profissional INT NOT NULL REFERENCES profissional(id_profissional),
    id_idoso        INT REFERENCES idoso(id_idoso),   -- NULL = recado geral
    turno           turno_plantao NOT NULL,
    prioridade      prioridade_plantao NOT NULL DEFAULT 'rotina',
    texto           VARCHAR(1000) NOT NULL CHECK (length(trim(texto)) > 0),
    resolvido       BOOLEAN NOT NULL DEFAULT FALSE,
    data_hora       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ciencia_plantao (
    id_recado       INT NOT NULL REFERENCES recado_plantao(id_recado) ON DELETE CASCADE,
    id_profissional INT NOT NULL REFERENCES profissional(id_profissional),
    data_hora       TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id_recado, id_profissional)
);

CREATE INDEX ix_plantao_ilpi_data ON recado_plantao (id_ilpi, data_hora DESC);
CREATE INDEX ix_plantao_idoso     ON recado_plantao (id_idoso) WHERE id_idoso IS NOT NULL;

-- RLS: só a equipe da ILPI vê e escreve na passagem de plantão.
-- Nem responsáveis, nem idosos — é comunicação interna do cuidado.
ALTER TABLE recado_plantao ENABLE ROW LEVEL SECURITY;
ALTER TABLE recado_plantao FORCE ROW LEVEL SECURITY;
ALTER TABLE ciencia_plantao ENABLE ROW LEVEL SECURITY;
ALTER TABLE ciencia_plantao FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_plantao ON recado_plantao FOR SELECT TO app_user
    USING (id_ilpi = fn_minha_ilpi_profissional());

CREATE POLICY ins_plantao ON recado_plantao FOR INSERT TO app_user
    WITH CHECK (id_ilpi = fn_minha_ilpi_profissional()
                AND id_profissional = fn_meu_id_profissional());

CREATE POLICY upd_plantao ON recado_plantao FOR UPDATE TO app_user
    USING (id_ilpi = fn_minha_ilpi_profissional())
    WITH CHECK (id_ilpi = fn_minha_ilpi_profissional());

CREATE POLICY sel_ciencia ON ciencia_plantao FOR SELECT TO app_user
    USING (EXISTS (SELECT 1 FROM recado_plantao r
                    WHERE r.id_recado = ciencia_plantao.id_recado
                      AND r.id_ilpi = fn_minha_ilpi_profissional()));

CREATE POLICY ins_ciencia ON ciencia_plantao FOR INSERT TO app_user
    WITH CHECK (id_profissional = fn_meu_id_profissional());

GRANT SELECT, INSERT, UPDATE ON recado_plantao TO app_user;
GRANT SELECT, INSERT ON ciencia_plantao TO app_user;
GRANT USAGE ON SEQUENCE recado_plantao_id_recado_seq TO app_user;

CREATE TRIGGER trg_aud_plantao AFTER INSERT OR UPDATE OR DELETE ON recado_plantao
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_recado');

COMMIT;
