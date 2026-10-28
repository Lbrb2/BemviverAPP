-- ============================================================
-- Migração 013: Intercorrências/quedas e Controle nutricional
-- ============================================================

BEGIN;

-- ---------- Intercorrências e quedas ----------
CREATE TYPE tipo_intercorrencia AS ENUM ('queda', 'lesao', 'mal_estar', 'comportamento', 'fuga', 'obito', 'outro');
CREATE TYPE gravidade_evento AS ENUM ('leve', 'moderada', 'grave');

CREATE TABLE intercorrencia (
    id_intercorrencia SERIAL PRIMARY KEY,
    id_idoso          INT NOT NULL REFERENCES idoso(id_idoso),
    id_profissional   INT NOT NULL REFERENCES profissional(id_profissional),
    tipo              tipo_intercorrencia NOT NULL,
    gravidade         gravidade_evento NOT NULL DEFAULT 'leve',
    local_evento      VARCHAR(80),
    descricao         VARCHAR(500) NOT NULL CHECK (length(trim(descricao)) > 0),
    conduta           VARCHAR(500),        -- o que foi feito
    familia_avisada   BOOLEAN NOT NULL DEFAULT FALSE,
    data_hora         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_interc_idoso ON intercorrencia (id_idoso, data_hora DESC);

-- ---------- Controle nutricional ----------
CREATE TYPE refeicao_tipo AS ENUM ('cafe', 'almoco', 'lanche', 'jantar', 'ceia');

-- restrições alimentares por idoso (uma linha por restrição)
CREATE TABLE restricao_alimentar (
    id_restricao  SERIAL PRIMARY KEY,
    id_idoso      INT NOT NULL REFERENCES idoso(id_idoso),
    descricao     VARCHAR(120) NOT NULL,     -- "diabético", "sem sal", "pastoso"
    UNIQUE (id_idoso, descricao)
);

-- registro de aceitação de cada refeição (0-100%)
CREATE TABLE registro_refeicao (
    id_refeicao      SERIAL PRIMARY KEY,
    id_idoso         INT NOT NULL REFERENCES idoso(id_idoso),
    id_profissional  INT NOT NULL REFERENCES profissional(id_profissional),
    tipo             refeicao_tipo NOT NULL,
    aceitacao        SMALLINT NOT NULL CHECK (aceitacao BETWEEN 0 AND 100),
    hidratacao_ml    SMALLINT CHECK (hidratacao_ml >= 0),
    observacoes      VARCHAR(300),
    data_hora        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_refeicao_idoso ON registro_refeicao (id_idoso, data_hora DESC);

-- RLS: mesma visibilidade dos registros de saúde
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY['intercorrencia','restricao_alimentar','registro_refeicao']) LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

-- SELECT: equipe da ILPI, responsável do idoso, ou o próprio idoso
CREATE POLICY sel_interc ON intercorrencia FOR SELECT TO app_user
    USING (fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR id_idoso = fn_meu_id_idoso());
CREATE POLICY ins_interc ON intercorrencia FOR INSERT TO app_user
    WITH CHECK (id_profissional = fn_meu_id_profissional()
        AND fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());

CREATE POLICY sel_restr ON restricao_alimentar FOR SELECT TO app_user
    USING (fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR id_idoso = fn_meu_id_idoso());
CREATE POLICY ins_restr ON restricao_alimentar FOR INSERT TO app_user
    WITH CHECK (fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());
CREATE POLICY del_restr ON restricao_alimentar FOR DELETE TO app_user
    USING (fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());

CREATE POLICY sel_refeicao ON registro_refeicao FOR SELECT TO app_user
    USING (fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR id_idoso = fn_meu_id_idoso());
CREATE POLICY ins_refeicao ON registro_refeicao FOR INSERT TO app_user
    WITH CHECK (id_profissional = fn_meu_id_profissional()
        AND fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());

GRANT SELECT, INSERT ON intercorrencia, registro_refeicao TO app_user;
GRANT SELECT, INSERT, DELETE ON restricao_alimentar TO app_user;
GRANT USAGE ON SEQUENCE intercorrencia_id_intercorrencia_seq, restricao_alimentar_id_restricao_seq, registro_refeicao_id_refeicao_seq TO app_user;

CREATE TRIGGER trg_aud_interc AFTER INSERT OR UPDATE OR DELETE ON intercorrencia
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_intercorrencia');
CREATE TRIGGER trg_aud_refeicao AFTER INSERT OR UPDATE OR DELETE ON registro_refeicao
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_refeicao');

COMMIT;
