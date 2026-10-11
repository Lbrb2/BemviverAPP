-- ============================================================
-- Migração 010: Sinais vitais
-- Registro estruturado (não texto livre) para permitir gráficos
-- e alertas de faixa. Hoje o schema tinha só registro_saude em
-- texto; aqui damos estrutura ao que é medido e acompanhado.
-- ============================================================

BEGIN;

CREATE TABLE sinal_vital (
    id_sinal         SERIAL PRIMARY KEY,
    id_idoso         INT NOT NULL REFERENCES idoso(id_idoso),
    id_profissional  INT NOT NULL REFERENCES profissional(id_profissional),
    data_hora        TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- todos opcionais: registra-se o que foi aferido naquele momento
    pressao_sis      SMALLINT CHECK (pressao_sis BETWEEN 50 AND 300),   -- sistólica
    pressao_dia      SMALLINT CHECK (pressao_dia BETWEEN 30 AND 200),   -- diastólica
    freq_cardiaca    SMALLINT CHECK (freq_cardiaca BETWEEN 20 AND 250),
    temperatura      NUMERIC(3,1) CHECK (temperatura BETWEEN 30 AND 45),
    peso_kg          NUMERIC(4,1) CHECK (peso_kg BETWEEN 20 AND 300),
    glicemia         SMALLINT CHECK (glicemia BETWEEN 20 AND 600),      -- mg/dL
    saturacao        SMALLINT CHECK (saturacao BETWEEN 50 AND 100),     -- SpO2 %
    observacoes      TEXT,
    -- ao menos uma medida por registro:
    CONSTRAINT ck_tem_medida CHECK (
        num_nonnulls(pressao_sis, freq_cardiaca, temperatura, peso_kg, glicemia, saturacao) >= 1
    )
);

CREATE INDEX ix_sinal_idoso_data ON sinal_vital (id_idoso, data_hora DESC);

ALTER TABLE sinal_vital ENABLE ROW LEVEL SECURITY;
ALTER TABLE sinal_vital FORCE ROW LEVEL SECURITY;

-- Mesma visibilidade dos demais registros de saúde:
CREATE POLICY sel_sinal ON sinal_vital FOR SELECT TO app_user
    USING (
        fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR id_idoso = fn_meu_id_idoso()
    );

CREATE POLICY ins_sinal_equipe ON sinal_vital FOR INSERT TO app_user
    WITH CHECK (
        id_profissional = fn_meu_id_profissional()
        AND fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
    );

GRANT SELECT, INSERT ON sinal_vital TO app_user;
GRANT USAGE ON SEQUENCE sinal_vital_id_sinal_seq TO app_user;

CREATE TRIGGER trg_aud_sinal AFTER INSERT OR UPDATE OR DELETE ON sinal_vital
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_sinal');

COMMIT;
