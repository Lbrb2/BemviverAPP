-- ============================================================
-- Row-Level Security (RLS)
-- Plataforma de Acompanhamento de Idosos em ILPIs (PE)
-- Executar após schema_ilpi.sql (e seed_ilpi.sql para testar)
--
-- Modelo de conexão:
--   A aplicação conecta como o papel APP_USER e, a cada requisição,
--   informa quem é o usuário logado via variável de sessão:
--       SET app.id_usuario = '<id do usuário autenticado>';
--   As políticas abaixo decidem, linha a linha, o que esse usuário
--   pode ver ou gravar.
-- ============================================================

BEGIN;

-- ---------- Papel de conexão da aplicação ----------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
        CREATE ROLE app_user NOLOGIN; -- em produção: LOGIN PASSWORD '...'
    END IF;
END $$;

GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- A view do painel deve respeitar o RLS de quem consulta,
-- e não os privilégios de quem a criou (PostgreSQL 15+):
ALTER VIEW vw_painel_idoso SET (security_invoker = true);

-- ---------- Funções auxiliares ----------
-- SECURITY DEFINER: executam com privilégios do dono (bypass de RLS
-- interno) para evitar recursão de políticas; STABLE para o planner
-- poder cachear o resultado dentro da mesma consulta.

CREATE OR REPLACE FUNCTION fn_usuario_atual() RETURNS int
LANGUAGE sql STABLE AS
$$ SELECT NULLIF(current_setting('app.id_usuario', true), '')::int $$;

CREATE OR REPLACE FUNCTION fn_meu_id_profissional() RETURNS int
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT id_profissional FROM profissional WHERE id_usuario = fn_usuario_atual() $$;

CREATE OR REPLACE FUNCTION fn_minha_ilpi_profissional() RETURNS int
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT id_ilpi FROM profissional WHERE id_usuario = fn_usuario_atual() $$;

CREATE OR REPLACE FUNCTION fn_sou_psicologo() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT EXISTS (SELECT 1 FROM profissional
                   WHERE id_usuario = fn_usuario_atual()
                     AND funcao = 'psicologo') $$;

-- Idosos vinculados a mim como responsável
CREATE OR REPLACE FUNCTION fn_idosos_sob_minha_responsabilidade() RETURNS SETOF int
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT v.id_idoso
     FROM vinculo_responsavel v
     JOIN responsavel r USING (id_responsavel)
    WHERE r.id_usuario = fn_usuario_atual() $$;

-- Meu próprio cadastro de idoso (se eu for um idoso com acesso ao app)
CREATE OR REPLACE FUNCTION fn_meu_id_idoso() RETURNS int
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT id_idoso FROM idoso WHERE id_usuario = fn_usuario_atual() $$;

-- ILPI de um idoso (usada nas políticas das tabelas de registro)
CREATE OR REPLACE FUNCTION fn_ilpi_do_idoso(p_id_idoso int) RETURNS int
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT id_ilpi FROM idoso WHERE id_idoso = p_id_idoso $$;

-- ============================================================
-- POLÍTICAS
-- Políticas do mesmo tipo (ex.: SELECT) são combinadas com OR:
-- basta uma permitir para a linha aparecer.
-- ============================================================

-- ---------- IDOSO ----------
ALTER TABLE idoso ENABLE ROW LEVEL SECURITY;
ALTER TABLE idoso FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_idoso_equipe ON idoso FOR SELECT TO app_user
    USING (id_ilpi = fn_minha_ilpi_profissional());

CREATE POLICY sel_idoso_responsavel ON idoso FOR SELECT TO app_user
    USING (id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade()));

CREATE POLICY sel_idoso_self ON idoso FOR SELECT TO app_user
    USING (id_usuario = fn_usuario_atual());

-- ---------- REGISTRO_BEM_ESTAR ----------
ALTER TABLE registro_bem_estar ENABLE ROW LEVEL SECURITY;
ALTER TABLE registro_bem_estar FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_bem_estar ON registro_bem_estar FOR SELECT TO app_user
    USING (
        fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR id_idoso = fn_meu_id_idoso()
    );

-- Autorregistro: o idoso grava o próprio check-in, sem profissional
CREATE POLICY ins_bem_estar_self ON registro_bem_estar FOR INSERT TO app_user
    WITH CHECK (id_idoso = fn_meu_id_idoso() AND id_profissional IS NULL);

-- Equipe: registra em nome de idosos da própria ILPI
CREATE POLICY ins_bem_estar_equipe ON registro_bem_estar FOR INSERT TO app_user
    WITH CHECK (
        id_profissional = fn_meu_id_profissional()
        AND fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
    );

-- ---------- REGISTRO_SAUDE ----------
ALTER TABLE registro_saude ENABLE ROW LEVEL SECURITY;
ALTER TABLE registro_saude FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_saude ON registro_saude FOR SELECT TO app_user
    USING (
        fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR id_idoso = fn_meu_id_idoso()
    );

CREATE POLICY ins_saude_equipe ON registro_saude FOR INSERT TO app_user
    WITH CHECK (
        id_profissional = fn_meu_id_profissional()
        AND fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
    );

-- ---------- AVALIACAO ----------
ALTER TABLE avaliacao ENABLE ROW LEVEL SECURITY;
ALTER TABLE avaliacao FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_avaliacao ON avaliacao FOR SELECT TO app_user
    USING (
        fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR id_idoso = fn_meu_id_idoso()
    );

CREATE POLICY ins_avaliacao_equipe ON avaliacao FOR INSERT TO app_user
    WITH CHECK (
        id_profissional = fn_meu_id_profissional()
        AND fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
    );

-- ---------- ATENDIMENTO_PSICOLOGICO (a mais restrita) ----------
-- Somente psicólogos da ILPI do idoso. Nem gestor, nem enfermagem,
-- nem responsável leem a evolução clínica (sigilo profissional,
-- Resolução CFP 01/2009 sobre registro documental em psicologia).
ALTER TABLE atendimento_psicologico ENABLE ROW LEVEL SECURITY;
ALTER TABLE atendimento_psicologico FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_psico ON atendimento_psicologico FOR SELECT TO app_user
    USING (
        fn_sou_psicologo()
        AND fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
    );

CREATE POLICY ins_psico ON atendimento_psicologico FOR INSERT TO app_user
    WITH CHECK (
        fn_sou_psicologo()
        AND id_profissional = fn_meu_id_profissional()
        AND fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
    );


-- ---------- Medicação, Mural e Auditoria ----------
CREATE OR REPLACE FUNCTION fn_minha_funcao() RETURNS funcao_profissional
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT funcao FROM profissional WHERE id_usuario = fn_usuario_atual() $$;

CREATE OR REPLACE FUNCTION fn_meu_id_responsavel() RETURNS int
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT id_responsavel FROM responsavel WHERE id_usuario = fn_usuario_atual() $$;

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


-- ---------- Consentimento LGPD ----------
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


-- ---------- Gestor da ILPI ----------
CREATE OR REPLACE FUNCTION fn_sou_gestor() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT EXISTS (SELECT 1 FROM profissional
                   WHERE id_usuario = fn_usuario_atual() AND funcao = 'gestor') $$;

GRANT INSERT ON usuario, idoso, profissional, responsavel, vinculo_responsavel, pet_virtual TO app_user;
GRANT USAGE ON SEQUENCE usuario_id_usuario_seq, idoso_id_idoso_seq,
  profissional_id_profissional_seq, responsavel_id_responsavel_seq,
  pet_virtual_id_pet_seq TO app_user;

CREATE POLICY ins_idoso_gestor ON idoso FOR INSERT TO app_user
    WITH CHECK (fn_sou_gestor() AND id_ilpi = fn_minha_ilpi_profissional());
CREATE POLICY ins_prof_gestor ON profissional FOR INSERT TO app_user
    WITH CHECK (fn_sou_gestor() AND id_ilpi = fn_minha_ilpi_profissional());
CREATE POLICY upd_idoso_gestor ON idoso FOR UPDATE TO app_user
    USING (fn_sou_gestor() AND id_ilpi = fn_minha_ilpi_profissional())
    WITH CHECK (fn_sou_gestor() AND id_ilpi = fn_minha_ilpi_profissional());
CREATE POLICY upd_prof_gestor ON profissional FOR UPDATE TO app_user
    USING (fn_sou_gestor() AND id_ilpi = fn_minha_ilpi_profissional())
    WITH CHECK (fn_sou_gestor() AND id_ilpi = fn_minha_ilpi_profissional());
GRANT UPDATE ON idoso, profissional, usuario, responsavel TO app_user;


-- ---------- Pet virtual (personalização pelo dono) ----------
ALTER TABLE pet_virtual ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_virtual FORCE ROW LEVEL SECURITY;
CREATE POLICY sel_pet ON pet_virtual FOR SELECT TO app_user
    USING (id_idoso = fn_meu_id_idoso()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());
CREATE POLICY upd_pet_dono ON pet_virtual FOR UPDATE TO app_user
    USING (id_idoso = fn_meu_id_idoso()) WITH CHECK (id_idoso = fn_meu_id_idoso());
CREATE POLICY ins_pet_gestor ON pet_virtual FOR INSERT TO app_user
    WITH CHECK (fn_sou_gestor() OR id_idoso = fn_meu_id_idoso());
GRANT UPDATE (nome, especie, acessorio, cor) ON pet_virtual TO app_user;
CREATE OR REPLACE VIEW vw_pet_completo AS
SELECT pv.*, CASE WHEN pv.nivel <= 2 THEN 'filhote' WHEN pv.nivel <= 4 THEN 'jovem'
                  WHEN pv.nivel <= 6 THEN 'adulto' ELSE 'sabio' END AS fase
FROM pet_virtual pv;
ALTER VIEW vw_pet_completo SET (security_invoker = true);
GRANT SELECT ON vw_pet_completo TO app_user;


-- ---------- Agenda de atividades ----------
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

-- Reconfirmar presença (ON CONFLICT ... DO UPDATE) atualiza o engajamento:
-- sem estas políticas a segunda confirmação era recusada pelo RLS.
CREATE POLICY upd_participacao ON participacao FOR UPDATE TO app_user
    USING (id_idoso = fn_meu_id_idoso() OR fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional())
    WITH CHECK (id_idoso = fn_meu_id_idoso() OR fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());

GRANT SELECT, INSERT, UPDATE ON atividade_lazer TO app_user;
GRANT SELECT, INSERT ON participacao TO app_user;
GRANT UPDATE (nivel_engajamento) ON participacao TO app_user;
GRANT USAGE ON SEQUENCE atividade_lazer_id_atividade_seq TO app_user;

CREATE TRIGGER trg_aud_atividade AFTER INSERT OR UPDATE OR DELETE ON atividade_lazer
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_atividade');


-- ---------- Passagem de plantão (políticas) ----------
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


-- ---------- Sinais vitais (políticas) ----------
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


-- ---------- Plano de cuidado (políticas) ----------
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


-- ---------- Intercorrências e nutrição (políticas) ----------
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

-- ---------- CRUD completo em duas tabelas (exceções deliberadas ao "sem DELETE") ----------
-- O sistema não apaga histórico clínico (soft-delete via coluna ativo).
-- Duas tabelas, porém, guardam conteúdo que pode e deve ser corrigido ou removido:
--  * recado_mural: o texto é do familiar que escreveu (LGPD: direito de corrigir
--    e eliminar o próprio conteúdo). Só o AUTOR edita ou apaga.
--  * restricao_alimentar: é configuração do cuidado, não registro de evento.
--    A equipe da ILPI do idoso edita e remove.
-- Toda edição/remoção fica na trilha de auditoria pelos triggers abaixo.
CREATE POLICY upd_recado_autor ON recado_mural FOR UPDATE TO app_user
    USING (id_responsavel = fn_meu_id_responsavel())
    WITH CHECK (id_responsavel = fn_meu_id_responsavel()
        AND id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade()));
CREATE POLICY del_recado_autor ON recado_mural FOR DELETE TO app_user
    USING (id_responsavel = fn_meu_id_responsavel());
GRANT UPDATE (texto, editado_em), DELETE ON recado_mural TO app_user;

CREATE POLICY upd_restr ON restricao_alimentar FOR UPDATE TO app_user
    USING (fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional())
    WITH CHECK (fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());
GRANT UPDATE (descricao) ON restricao_alimentar TO app_user;

CREATE TRIGGER trg_aud_restricao AFTER INSERT OR UPDATE OR DELETE ON restricao_alimentar
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_restricao');

-- ============================================================
-- PONTOS DO XODÓ: uma única porta de entrada
-- Antes, cada rota inseria em evento_pet e fazia UPDATE em pet_virtual.
-- Como só o dono pode alterar o próprio pet (upd_pet_dono), os pontos
-- de check-ins feitos pela equipe e do adversário no dominó se perdiam
-- em silêncio — e o nível nunca subia. Agora tudo passa por esta função:
-- ela confere quem pode pontuar, grava o evento e atualiza pontos e
-- nível (1 nível a cada 100 pontos) na mesma transação.
-- ============================================================
CREATE OR REPLACE FUNCTION fn_pontuar_pet(p_id_idoso int, p_origem origem_evento_pet, p_pontos int)
RETURNS TABLE (pet text, pontos int, nivel int, subiu_nivel boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_pet   pet_virtual%ROWTYPE;
    v_ilpi  int := fn_ilpi_do_idoso(p_id_idoso);
    v_eu    int := fn_meu_id_idoso();
    v_nivel int;
BEGIN
    IF p_pontos IS NULL OR p_pontos <= 0 OR p_pontos > 100 THEN
        RAISE EXCEPTION 'Quantidade de pontos inválida: %', p_pontos;
    END IF;
    -- pode pontuar: o próprio idoso, a equipe da ILPI dele, ou o adversário
    -- que acabou de registrar uma partida de dominó com ele
    -- COALESCE: para quem não é profissional, fn_minha_ilpi_profissional() é
    -- NULL, e "NOT (NULL)" não dispararia a exceção
    IF NOT COALESCE(p_id_idoso = v_eu
            OR v_ilpi = fn_minha_ilpi_profissional()
            OR (p_origem = 'partida_domino' AND EXISTS (
                    SELECT 1 FROM partida_domino pd
                     WHERE pd.id_jogador1 = v_eu AND pd.id_jogador2 = p_id_idoso
                       AND pd.data_hora >= now() - INTERVAL '1 minute')), false) THEN
        RAISE EXCEPTION 'Sem permissão para pontuar o pet deste idoso.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_pet FROM pet_virtual WHERE id_idoso = p_id_idoso FOR UPDATE;
    IF NOT FOUND THEN RETURN; END IF;   -- idoso sem pet: nada a fazer

    INSERT INTO evento_pet (id_pet, origem, pontos_ganhos) VALUES (v_pet.id_pet, p_origem, p_pontos);
    v_nivel := GREATEST(v_pet.nivel, 1 + (v_pet.pontos + p_pontos) / 100);
    UPDATE pet_virtual SET pontos = v_pet.pontos + p_pontos, nivel = v_nivel WHERE id_pet = v_pet.id_pet;

    RETURN QUERY SELECT v_pet.nome::text, v_pet.pontos + p_pontos, v_nivel, v_nivel > v_pet.nivel;
END $$;
REVOKE ALL ON FUNCTION fn_pontuar_pet(int, origem_evento_pet, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_pontuar_pet(int, origem_evento_pet, int) TO app_user;

-- pontos e nível só mudam pela função; o dono personaliza nome, espécie, acessório e cor
REVOKE UPDATE ON pet_virtual FROM app_user;
GRANT UPDATE (nome, especie, acessorio, cor) ON pet_virtual TO app_user;

-- ============================================================
-- RLS NAS TABELAS QUE AINDA NÃO TINHAM
-- ============================================================

-- ILPIs que eu enxergo: a minha (equipe), a do meu cadastro (idoso)
-- e as dos idosos que acompanho (responsável)
CREATE OR REPLACE FUNCTION fn_ilpis_visiveis() RETURNS SETOF int
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT fn_minha_ilpi_profissional() WHERE fn_minha_ilpi_profissional() IS NOT NULL
    UNION
    SELECT fn_ilpi_do_idoso(fn_meu_id_idoso()) WHERE fn_meu_id_idoso() IS NOT NULL
    UNION
    SELECT i.id_ilpi FROM idoso i WHERE i.id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
$$;

-- Conta de acesso visível: a minha; ou, para o gestor, as contas das
-- pessoas da ILPI dele (e contas recém-criadas, ainda sem dono, para o
-- INSERT ... RETURNING do cadastro funcionar)
CREATE OR REPLACE FUNCTION fn_usuario_visivel(p_id_usuario int) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT p_id_usuario = fn_usuario_atual()
        OR (fn_sou_gestor() AND (
               EXISTS (SELECT 1 FROM idoso i WHERE i.id_usuario = p_id_usuario
                          AND i.id_ilpi = fn_minha_ilpi_profissional())
            OR EXISTS (SELECT 1 FROM profissional p WHERE p.id_usuario = p_id_usuario
                          AND p.id_ilpi = fn_minha_ilpi_profissional())
            OR EXISTS (SELECT 1 FROM responsavel r JOIN vinculo_responsavel v USING (id_responsavel)
                        WHERE r.id_usuario = p_id_usuario
                          AND fn_ilpi_do_idoso(v.id_idoso) = fn_minha_ilpi_profissional())
            OR NOT EXISTS (SELECT 1 FROM idoso WHERE id_usuario = p_id_usuario
                           UNION ALL SELECT 1 FROM profissional WHERE id_usuario = p_id_usuario
                           UNION ALL SELECT 1 FROM responsavel WHERE id_usuario = p_id_usuario)))
$$;

-- Responsável visível: ligado a um idoso que eu enxergo (equipe, o próprio
-- idoso ou outro familiar do mesmo idoso); ou recém-cadastrado pelo gestor
CREATE OR REPLACE FUNCTION fn_responsavel_visivel(p_id_responsavel int) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT EXISTS (
        SELECT 1 FROM vinculo_responsavel v
         WHERE v.id_responsavel = p_id_responsavel
           AND (fn_ilpi_do_idoso(v.id_idoso) = fn_minha_ilpi_profissional()
                OR v.id_idoso = fn_meu_id_idoso()
                OR v.id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())))
        OR (fn_sou_gestor() AND NOT EXISTS (
                SELECT 1 FROM vinculo_responsavel v WHERE v.id_responsavel = p_id_responsavel))
$$;

-- ---------- ILPI ----------
ALTER TABLE ilpi ENABLE ROW LEVEL SECURITY;
ALTER TABLE ilpi FORCE ROW LEVEL SECURITY;
CREATE POLICY sel_ilpi ON ilpi FOR SELECT TO app_user
    USING (id_ilpi IN (SELECT fn_ilpis_visiveis()));
REVOKE INSERT, UPDATE ON ilpi FROM app_user;   -- cadastro de ILPI é administrativo

-- ---------- USUARIO ----------
-- O hash da senha deixa de ser legível pela aplicação: o login é feito
-- pela função fn_autenticar (api/setup_api.sql), que roda como dono.
ALTER TABLE usuario ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuario FORCE ROW LEVEL SECURITY;
REVOKE SELECT, UPDATE ON usuario FROM app_user;
GRANT SELECT (id_usuario, email, perfil, ativo, criado_em) ON usuario TO app_user;
GRANT UPDATE (ativo) ON usuario TO app_user;
CREATE POLICY sel_usuario ON usuario FOR SELECT TO app_user
    USING (fn_usuario_visivel(id_usuario));
CREATE POLICY ins_usuario_gestor ON usuario FOR INSERT TO app_user
    WITH CHECK (fn_sou_gestor() AND perfil <> 'gestor');
CREATE POLICY upd_usuario_gestor ON usuario FOR UPDATE TO app_user
    USING (fn_sou_gestor() AND fn_usuario_visivel(id_usuario) AND id_usuario <> fn_usuario_atual())
    WITH CHECK (fn_sou_gestor());

-- ---------- PROFISSIONAL ----------
-- (as políticas de INSERT/UPDATE do gestor já existiam; faltava ligar o RLS)
ALTER TABLE profissional ENABLE ROW LEVEL SECURITY;
ALTER TABLE profissional FORCE ROW LEVEL SECURITY;
CREATE POLICY sel_profissional ON profissional FOR SELECT TO app_user
    USING (id_ilpi IN (SELECT fn_ilpis_visiveis()));

-- ---------- RESPONSAVEL ----------
ALTER TABLE responsavel ENABLE ROW LEVEL SECURITY;
ALTER TABLE responsavel FORCE ROW LEVEL SECURITY;
CREATE POLICY sel_responsavel ON responsavel FOR SELECT TO app_user
    USING (id_usuario = fn_usuario_atual() OR fn_responsavel_visivel(id_responsavel));
CREATE POLICY ins_responsavel_gestor ON responsavel FOR INSERT TO app_user
    WITH CHECK (fn_sou_gestor());
CREATE POLICY upd_responsavel ON responsavel FOR UPDATE TO app_user
    USING (id_usuario = fn_usuario_atual() OR (fn_sou_gestor() AND fn_responsavel_visivel(id_responsavel)))
    WITH CHECK (id_usuario = fn_usuario_atual() OR fn_sou_gestor());

-- ---------- VINCULO_RESPONSAVEL ----------
ALTER TABLE vinculo_responsavel ENABLE ROW LEVEL SECURITY;
ALTER TABLE vinculo_responsavel FORCE ROW LEVEL SECURITY;
CREATE POLICY sel_vinculo ON vinculo_responsavel FOR SELECT TO app_user
    USING (fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
        OR id_idoso = fn_meu_id_idoso()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade()));
CREATE POLICY ins_vinculo_gestor ON vinculo_responsavel FOR INSERT TO app_user
    WITH CHECK (fn_sou_gestor() AND fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());
REVOKE UPDATE ON vinculo_responsavel FROM app_user;

-- ---------- ITEM_AVALIACAO ----------
-- Herda o recorte da avaliação: o EXISTS abaixo já passa pelo RLS de avaliacao.
ALTER TABLE item_avaliacao ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_avaliacao FORCE ROW LEVEL SECURITY;
CREATE POLICY sel_item_avaliacao ON item_avaliacao FOR SELECT TO app_user
    USING (EXISTS (SELECT 1 FROM avaliacao a WHERE a.id_avaliacao = item_avaliacao.id_avaliacao));
CREATE POLICY ins_item_avaliacao ON item_avaliacao FOR INSERT TO app_user
    WITH CHECK (EXISTS (SELECT 1 FROM avaliacao a
                         WHERE a.id_avaliacao = item_avaliacao.id_avaliacao
                           AND a.id_profissional = fn_meu_id_profissional()));
REVOKE UPDATE ON item_avaliacao FROM app_user;

-- ---------- EVENTO_PET ----------
-- Leitura herda o recorte do pet; escrita só pela fn_pontuar_pet.
ALTER TABLE evento_pet ENABLE ROW LEVEL SECURITY;
ALTER TABLE evento_pet FORCE ROW LEVEL SECURITY;
CREATE POLICY sel_evento_pet ON evento_pet FOR SELECT TO app_user
    USING (EXISTS (SELECT 1 FROM pet_virtual p WHERE p.id_pet = evento_pet.id_pet));
REVOKE INSERT, UPDATE ON evento_pet FROM app_user;

-- ---------- PARTIDA_DOMINO ----------
ALTER TABLE partida_domino ENABLE ROW LEVEL SECURITY;
ALTER TABLE partida_domino FORCE ROW LEVEL SECURITY;
CREATE POLICY sel_partida ON partida_domino FOR SELECT TO app_user
    USING (id_ilpi = fn_minha_ilpi_profissional()
        OR fn_meu_id_idoso() IN (id_jogador1, id_jogador2)
        OR id_jogador1 IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR id_jogador2 IN (SELECT fn_idosos_sob_minha_responsabilidade()));
CREATE POLICY ins_partida ON partida_domino FOR INSERT TO app_user
    WITH CHECK (id_jogador1 = fn_meu_id_idoso()
        AND id_ilpi = fn_ilpi_do_idoso(id_jogador1)
        AND (id_jogador2 IS NULL OR fn_ilpi_do_idoso(id_jogador2) = id_ilpi));
REVOKE UPDATE ON partida_domino FROM app_user;

-- ---------- PARTIDA_JOGO (Memória, Buraco, Paciência, Cuidar do Xodó) ----------
ALTER TABLE partida_jogo ENABLE ROW LEVEL SECURITY;
ALTER TABLE partida_jogo FORCE ROW LEVEL SECURITY;
CREATE POLICY sel_partida_jogo ON partida_jogo FOR SELECT TO app_user
    USING (id_idoso = fn_meu_id_idoso()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());
CREATE POLICY ins_partida_jogo ON partida_jogo FOR INSERT TO app_user
    WITH CHECK (id_idoso = fn_meu_id_idoso());
REVOKE UPDATE ON partida_jogo FROM app_user;
CREATE TRIGGER trg_aud_partida_jogo AFTER INSERT OR UPDATE OR DELETE ON partida_jogo
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria('id_partida_jogo');

-- ---------- LOG_AUDITORIA ----------
-- Gravado só pelo trigger (SECURITY DEFINER). Cada um vê o próprio rastro;
-- o gestor vê o das pessoas da ILPI dele.
ALTER TABLE log_auditoria ENABLE ROW LEVEL SECURITY;
ALTER TABLE log_auditoria FORCE ROW LEVEL SECURITY;
CREATE POLICY sel_auditoria ON log_auditoria FOR SELECT TO app_user
    USING (id_usuario = fn_usuario_atual() OR (fn_sou_gestor() AND fn_usuario_visivel(id_usuario)));
REVOKE INSERT, UPDATE ON log_auditoria FROM app_user;


COMMIT;

-- ============================================================
-- ROTEIRO DE TESTE (rodar manualmente, um bloco por vez)
-- ============================================================
-- 1) Como a enfermeira Patrícia (usuário 6) - NÃO deve ver atendimentos:
--    SET ROLE app_user; SET app.id_usuario = '6';
--    SELECT count(*) FROM atendimento_psicologico;  -- esperado: 0
--    SELECT count(*) FROM registro_saude;           -- esperado: 23 (só a ILPI dela)
--
-- 2) Como o psicólogo Rodrigo (usuário 7) - deve ver os 2 atendimentos:
--    SET app.id_usuario = '7';
--    SELECT count(*) FROM atendimento_psicologico;  -- esperado: 22 (os da ILPI 1)
--
-- 3) Como a responsável Mariana (usuário 3) - só enxerga Dona Severina:
--    SET app.id_usuario = '3';
--    SELECT nome FROM idoso;                        -- esperado: 1 linha
--    SELECT count(*) FROM atendimento_psicologico;  -- esperado: 0
--
-- 4) Como a enfermeira da OUTRA ILPI (usuária 9, Caruaru):
--    SET app.id_usuario = '9';
--    SELECT nome FROM idoso;                        -- esperado: só os 8 de Caruaru
--
-- RESET ROLE;  -- volta ao papel administrador
