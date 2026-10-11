-- ============================================================
-- Migração 003: Medicação, Mural da Família e Auditoria por Trigger
-- Para bancos existentes. Instalações novas: schema + rls já incluem.
-- ============================================================

BEGIN;

-- ---------- Novos auxiliares de RLS ----------
CREATE OR REPLACE FUNCTION fn_minha_funcao() RETURNS funcao_profissional
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT funcao FROM profissional WHERE id_usuario = fn_usuario_atual() $$;

CREATE OR REPLACE FUNCTION fn_meu_id_responsavel() RETURNS int
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT id_responsavel FROM responsavel WHERE id_usuario = fn_usuario_atual() $$;

-- ---------- Controle de medicação (RDC 502: registro obrigatório) ----------
CREATE TABLE prescricao (
    id_prescricao   SERIAL PRIMARY KEY,
    id_idoso        INT NOT NULL REFERENCES idoso(id_idoso),
    id_profissional INT NOT NULL REFERENCES profissional(id_profissional),
    medicamento     VARCHAR(150) NOT NULL,
    dose            VARCHAR(60) NOT NULL,           -- "50 mg", "10 gotas"
    horarios        TIME[] NOT NULL,                -- ex.: {08:00, 20:00}
    inicio          DATE NOT NULL DEFAULT CURRENT_DATE,
    fim             DATE,                           -- NULL = uso contínuo
    ativo           BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_periodo CHECK (fim IS NULL OR fim >= inicio),
    CONSTRAINT ck_tem_horario CHECK (array_length(horarios, 1) >= 1)
);

CREATE TABLE administracao_medicacao (
    id_adm           SERIAL PRIMARY KEY,
    id_prescricao    INT NOT NULL REFERENCES prescricao(id_prescricao),
    id_profissional  INT NOT NULL REFERENCES profissional(id_profissional),
    horario_previsto TIMESTAMPTZ NOT NULL,
    administrado_em  TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- A mesma dose não pode ser registrada duas vezes:
    CONSTRAINT ux_dose_unica UNIQUE (id_prescricao, horario_previsto)
);

CREATE INDEX ix_prescricao_idoso ON prescricao (id_idoso) WHERE ativo;
CREATE INDEX ix_adm_prescricao   ON administracao_medicacao (id_prescricao, horario_previsto DESC);

ALTER TABLE prescricao ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescricao FORCE ROW LEVEL SECURITY;
ALTER TABLE administracao_medicacao ENABLE ROW LEVEL SECURITY;
ALTER TABLE administracao_medicacao FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_prescricao ON prescricao FOR SELECT TO app_user
    USING (
        fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR id_idoso = fn_meu_id_idoso()
    );

-- Prescrever é ato de médico ou enfermeiro:
CREATE POLICY ins_prescricao ON prescricao FOR INSERT TO app_user
    WITH CHECK (
        fn_minha_funcao() IN ('medico', 'enfermeiro')
        AND id_profissional = fn_meu_id_profissional()
        AND fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
    );

CREATE POLICY sel_adm ON administracao_medicacao FOR SELECT TO app_user
    USING (EXISTS (SELECT 1 FROM prescricao p WHERE p.id_prescricao = administracao_medicacao.id_prescricao));

-- Administrar (dar a dose) pode qualquer profissional da ILPI:
CREATE POLICY ins_adm ON administracao_medicacao FOR INSERT TO app_user
    WITH CHECK (
        id_profissional = fn_meu_id_profissional()
        AND EXISTS (SELECT 1 FROM prescricao p
                     WHERE p.id_prescricao = administracao_medicacao.id_prescricao
                       AND fn_ilpi_do_idoso(p.id_idoso) = fn_minha_ilpi_profissional())
    );

-- ---------- Mural da Família ----------
CREATE TABLE recado_mural (
    id_recado      SERIAL PRIMARY KEY,
    id_idoso       INT NOT NULL REFERENCES idoso(id_idoso),
    id_responsavel INT NOT NULL REFERENCES responsavel(id_responsavel),
    texto          VARCHAR(500) NOT NULL CHECK (length(trim(texto)) > 0),
    data_hora      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_recado_idoso ON recado_mural (id_idoso, data_hora DESC);

ALTER TABLE recado_mural ENABLE ROW LEVEL SECURITY;
ALTER TABLE recado_mural FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_recado ON recado_mural FOR SELECT TO app_user
    USING (
        id_idoso = fn_meu_id_idoso()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
    );

-- Só responsáveis vinculados àquele idoso escrevem no mural dele:
CREATE POLICY ins_recado ON recado_mural FOR INSERT TO app_user
    WITH CHECK (
        id_responsavel = fn_meu_id_responsavel()
        AND id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
    );

-- ---------- Auditoria por trigger ----------
-- A trilha deixa de depender da API: qualquer escrita nas tabelas
-- sensíveis é registrada pelo próprio banco, seja qual for o caminho.
CREATE OR REPLACE FUNCTION fn_trigger_auditoria() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    uid int := NULLIF(current_setting('app.id_usuario', true), '')::int;
BEGIN
    IF uid IS NOT NULL THEN
        INSERT INTO log_auditoria (id_usuario, acao, tabela_afetada, id_registro)
        VALUES (
            uid,
            CASE TG_OP WHEN 'INSERT' THEN 'criacao'
                       WHEN 'UPDATE' THEN 'edicao'
                       ELSE 'exclusao' END::acao_auditoria,
            TG_TABLE_NAME,
            (to_jsonb(COALESCE(NEW, OLD)) ->> TG_ARGV[0])::int
        );
    END IF;
    RETURN COALESCE(NEW, OLD);
END $$;

CREATE TRIGGER trg_aud_bem_estar  AFTER INSERT OR UPDATE OR DELETE ON registro_bem_estar
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_registro');
CREATE TRIGGER trg_aud_saude      AFTER INSERT OR UPDATE OR DELETE ON registro_saude
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_registro');
CREATE TRIGGER trg_aud_avaliacao  AFTER INSERT OR UPDATE OR DELETE ON avaliacao
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_avaliacao');
CREATE TRIGGER trg_aud_psico      AFTER INSERT OR UPDATE OR DELETE ON atendimento_psicologico
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_atendimento');
CREATE TRIGGER trg_aud_partida    AFTER INSERT OR UPDATE OR DELETE ON partida_domino
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_partida');
CREATE TRIGGER trg_aud_prescricao AFTER INSERT OR UPDATE OR DELETE ON prescricao
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_prescricao');
CREATE TRIGGER trg_aud_adm        AFTER INSERT OR UPDATE OR DELETE ON administracao_medicacao
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_adm');
CREATE TRIGGER trg_aud_recado     AFTER INSERT OR UPDATE OR DELETE ON recado_mural
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_recado');

GRANT SELECT, INSERT ON prescricao, administracao_medicacao, recado_mural TO app_user;
GRANT USAGE ON SEQUENCE prescricao_id_prescricao_seq, administracao_medicacao_id_adm_seq, recado_mural_id_recado_seq TO app_user;

COMMIT;
