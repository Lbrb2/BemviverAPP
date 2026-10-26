-- ============================================================
-- Bem Viver ILPI — Etapa 05: funções, procedimentos e triggers
-- Executar depois de schema_ilpi.sql, seed_ilpi.sql, rls_ilpi.sql e
-- da Etapa 04. Pode ser executado mais de uma vez.
-- Os testes de cada objeto estão em etapa05_demonstracao.sql.
--
-- Resumo:
--   Funções       fn_classificar_pressao      (estrutura condicional IF)
--                 fn_cuidadores_necessarios
--   Procedimentos sp_desligar_residente       (atualização de dados)
--                 sp_distribuir_cuidadores    (CURSOR)
--   Triggers      trg_alerta_sinal_vital      (gera recado no plantão)
--                 trg_log_grau_dependencia    (grava em tabela de log)
-- ============================================================

-- esconde os avisos do tipo "já existe, pulando" ao executar de novo
SET client_min_messages = warning;


-- ************************************************************
-- FUNÇÕES
-- ************************************************************

-- ------------------------------------------------------------
-- FUNÇÃO 1: fn_classificar_pressao(sistólica, diastólica)
-- ------------------------------------------------------------
-- Justificativa: a pressão arterial é o sinal vital mais aferido numa
-- ILPI, e a hipertensão é a doença crônica mais comum entre os idosos.
-- O número sozinho ("150/95") não diz à cuidadora o que fazer; a
-- classificação diz. A função aplica as faixas da Diretriz Brasileira de
-- Hipertensão Arterial (2020) e acrescenta a hipotensão, perigosa no
-- idoso por causa do risco de queda.
-- É usada pelo trigger trg_alerta_sinal_vital e pode ser usada em
-- qualquer consulta: SELECT fn_classificar_pressao(pressao_sis, pressao_dia) ...
-- Estrutura condicional: IF / ELSIF / ELSE. A ordem importa: as faixas
-- mais graves são testadas primeiro, e basta UM dos dois valores estar
-- na faixa para a pressão ser classificada nela ("e/ou" da diretriz).
CREATE OR REPLACE FUNCTION fn_classificar_pressao(p_sistolica int, p_diastolica int)
RETURNS varchar(30)
LANGUAGE plpgsql
IMMUTABLE        -- mesmo resultado para os mesmos valores: o banco pode reaproveitar
AS $$
BEGIN
    IF p_sistolica IS NULL OR p_diastolica IS NULL THEN
        RETURN NULL;                         -- pressão não foi aferida
    ELSIF p_sistolica >= 180 OR p_diastolica >= 110 THEN
        RETURN 'Hipertensão estágio 3';
    ELSIF p_sistolica >= 160 OR p_diastolica >= 100 THEN
        RETURN 'Hipertensão estágio 2';
    ELSIF p_sistolica >= 140 OR p_diastolica >= 90 THEN
        RETURN 'Hipertensão estágio 1';
    ELSIF p_sistolica >= 130 OR p_diastolica >= 85 THEN
        RETURN 'Pré-hipertensão';
    ELSIF p_sistolica < 90 OR p_diastolica < 60 THEN
        RETURN 'Hipotensão';
    ELSIF p_sistolica >= 120 OR p_diastolica >= 80 THEN
        RETURN 'Normal';
    ELSE
        RETURN 'Ótima';
    END IF;
END $$;

GRANT EXECUTE ON FUNCTION fn_classificar_pressao(int, int) TO app_user;


-- ------------------------------------------------------------
-- FUNÇÃO 2: fn_cuidadores_necessarios(id_ilpi)
-- ------------------------------------------------------------
-- Justificativa: a RDC 502/2021 da Anvisa (que manteve as proporções da
-- RDC 283/2005) define quantos cuidadores a ILPI precisa pelo grau de
-- dependência dos residentes:
--   grau I   (independente)          1 cuidador para cada 20 residentes ou fração
--   grau II  (dependência parcial)   1 cuidador para cada 10 residentes ou fração
--   grau III (dependência total)     1 cuidador para cada  6 residentes ou fração
-- "Ou fração" quer dizer arredondar para cima: 7 residentes de grau III
-- já exigem 2 cuidadores. A função conta os residentes ATIVOS de cada
-- grau e devolve quantos cuidadores a casa precisa por turno. O gestor
-- compara esse número com a equipe que tem, e é isso que a vigilância
-- sanitária confere na fiscalização.
-- É usada pelo trigger trg_log_grau_dependencia (o log guarda como a
-- necessidade de cuidadores ficou depois de cada mudança de grau).
CREATE OR REPLACE FUNCTION fn_cuidadores_necessarios(p_id_ilpi int)
RETURNS int
LANGUAGE plpgsql
STABLE           -- só lê dados; não altera nada
AS $$
DECLARE
    v_grau_1 int;
    v_grau_2 int;
    v_grau_3 int;
BEGIN
    SELECT count(*) FILTER (WHERE grau_dependencia = 'I'),
           count(*) FILTER (WHERE grau_dependencia = 'II'),
           count(*) FILTER (WHERE grau_dependencia = 'III')
      INTO v_grau_1, v_grau_2, v_grau_3
      FROM idoso
     WHERE id_ilpi = p_id_ilpi
       AND ativo;

    -- ceil = arredonda para cima ("ou fração"); 20.0 evita a divisão inteira
    RETURN ceil(v_grau_1 / 20.0)::int
         + ceil(v_grau_2 / 10.0)::int
         + ceil(v_grau_3 /  6.0)::int;
END $$;

GRANT EXECUTE ON FUNCTION fn_cuidadores_necessarios(int) TO app_user;


-- ************************************************************
-- PROCEDIMENTOS
-- ************************************************************

-- Ajuste no modelo usado pelos procedimentos: cuidador de referência do
-- residente (um profissional da equipe; fica NULL até a distribuição).
ALTER TABLE idoso
    ADD COLUMN IF NOT EXISTS id_cuidador_referencia INT
        REFERENCES profissional(id_profissional) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS ix_fk_idoso_cuidador_ref
    ON idoso (id_cuidador_referencia)
    WHERE id_cuidador_referencia IS NOT NULL;

-- ------------------------------------------------------------
-- PROCEDIMENTO 1 (atualização de dados): sp_desligar_residente(id_idoso)
-- ------------------------------------------------------------
-- Justificativa: quando um residente sai da ILPI (alta, transferência ou
-- óbito), não basta marcar "inativo". Várias tabelas precisam mudar
-- JUNTAS, senão sobram pendências falsas nas telas da equipe:
--   1. idoso: ativo = false e sem cuidador de referência;
--   2. usuario: a conta de acesso do residente (se houver) é bloqueada;
--   3. prescricao: as prescrições ativas são encerradas na data de hoje
--      (senão continuariam aparecendo na ronda de medicação);
--   4. meta_cuidado: as metas ativas do plano de cuidado são suspensas.
-- Nada é apagado: o prontuário é documento e precisa ser guardado.
-- Como um procedimento roda inteiro dentro de uma transação, ou tudo
-- isso acontece, ou nada acontece.
--
-- SECURITY DEFINER: a equipe não tem permissão de alterar prescrições
-- diretamente; o procedimento roda com a permissão do dono e por isso
-- confere ele mesmo, logo no começo, se quem chamou é gestor da ILPI do
-- residente. (Chamado pelo administrador no psql, sem usuário da
-- aplicação, a conferência não se aplica.)
CREATE OR REPLACE PROCEDURE sp_desligar_residente(p_id_idoso int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_nome        varchar;
    v_ativo       boolean;
    v_id_usuario  int;
    v_prescricoes int;
    v_metas       int;
BEGIN
    SELECT nome, ativo, id_usuario
      INTO v_nome, v_ativo, v_id_usuario
      FROM idoso
     WHERE id_idoso = p_id_idoso;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Residente % não encontrado.', p_id_idoso;
    END IF;
    IF NOT v_ativo THEN
        RAISE EXCEPTION 'O residente % já está desligado.', v_nome;
    END IF;

    -- chamado pela aplicação: só o gestor da ILPI do residente
    IF fn_usuario_atual() IS NOT NULL
       AND NOT (fn_sou_gestor() AND fn_ilpi_do_idoso(p_id_idoso) = fn_minha_ilpi_profissional()) THEN
        RAISE EXCEPTION 'Só o gestor da ILPI pode desligar este residente.';
    END IF;

    -- 1. residente
    UPDATE idoso
       SET ativo = false,
           id_cuidador_referencia = NULL
     WHERE id_idoso = p_id_idoso;

    -- 2. conta de acesso
    UPDATE usuario
       SET ativo = false
     WHERE id_usuario = v_id_usuario;

    -- 3. prescrições ativas: encerradas hoje (GREATEST protege a regra
    --    fim >= inicio, caso alguma prescrição comece no futuro)
    UPDATE prescricao
       SET ativo = false,
           fim   = GREATEST(CURRENT_DATE, inicio)
     WHERE id_idoso = p_id_idoso
       AND ativo;
    GET DIAGNOSTICS v_prescricoes = ROW_COUNT;   -- quantas linhas o UPDATE mudou

    -- 4. metas ativas do plano de cuidado
    UPDATE meta_cuidado
       SET status = 'suspensa'
     WHERE id_idoso = p_id_idoso
       AND status = 'ativa';
    GET DIAGNOSTICS v_metas = ROW_COUNT;

    RAISE NOTICE 'Residente % desligado: % prescrição(ões) encerrada(s) e % meta(s) suspensa(s).',
                 v_nome, v_prescricoes, v_metas;
END $$;

REVOKE ALL ON PROCEDURE sp_desligar_residente(int) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE sp_desligar_residente(int) TO app_user;


-- ------------------------------------------------------------
-- PROCEDIMENTO 2 (com CURSOR): sp_distribuir_cuidadores(id_ilpi, refazer)
-- ------------------------------------------------------------
-- Justificativa: cada residente tem um CUIDADOR DE REFERÊNCIA, quem
-- conhece a rotina dele e é o primeiro contato da família. A divisão
-- precisa ser equilibrada, e equilíbrio não é "o mesmo número de
-- residentes": um residente de grau III dá muito mais trabalho que um de
-- grau I. Usando as proporções da RDC 502 (1 cuidador para 20, 10 ou 6),
-- cada residente vale pontos de carga proporcionais: grau I = 3,
-- grau II = 6, grau III = 10 (60/20, 60/10, 60/6).
--
-- O procedimento percorre os residentes sem cuidador de referência,
-- começando pelos de grau III, e entrega cada um ao cuidador ativo da
-- ILPI que estiver com MENOS carga NAQUELE MOMENTO.
--
-- Por que precisa de cursor (e um UPDATE só não resolve): a escolha de
-- cada residente depende das escolhas anteriores. Depois que o 1º
-- residente vai para a cuidadora A, a carga dela aumenta, e isso muda
-- quem recebe o 2º. Um UPDATE único calcula a carga de todos os
-- cuidadores uma vez só, antes de começar, e mandaria todos os
-- residentes para o mesmo cuidador (o que estava com menos carga no
-- início). O cursor processa um residente por vez, e a cada volta a
-- carga é recalculada já com as atribuições feitas.
--
-- p_refazer = true apaga a distribuição atual e refaz do zero (útil
-- quando entra um cuidador novo). Com false, só atribui quem está sem
-- referência (por exemplo, residente recém-admitido ou cuidador desligado).
--
-- SECURITY INVOKER (padrão): roda com a permissão de quem chamou, e o
-- RLS só deixa o gestor alterar residentes da própria ILPI.
CREATE OR REPLACE PROCEDURE sp_distribuir_cuidadores(p_id_ilpi int, p_refazer boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_idoso     int;
    v_nome         varchar;
    v_grau         grau_dependencia;
    v_cuidador     int;
    v_nome_cuid    varchar;
    v_atribuidos   int := 0;

    -- Cursor: residentes ativos da ILPI que precisam de cuidador de
    -- referência (sem nenhum, ou com um que não está mais ativo como
    -- cuidador). Grau III primeiro: são os que mais pesam na divisão.
    c_residentes CURSOR FOR
        SELECT i.id_idoso, i.nome, i.grau_dependencia
          FROM idoso i
          LEFT JOIN profissional p
                 ON p.id_profissional = i.id_cuidador_referencia
                AND p.ativo
                AND p.funcao = 'cuidador'
         WHERE i.id_ilpi = p_id_ilpi
           AND i.ativo
           AND p.id_profissional IS NULL
         ORDER BY i.grau_dependencia DESC, i.nome;
BEGIN
    -- chamado pela aplicação: só o gestor da própria ILPI
    IF fn_usuario_atual() IS NOT NULL
       AND NOT (fn_sou_gestor() AND fn_minha_ilpi_profissional() = p_id_ilpi) THEN
        RAISE EXCEPTION 'Só o gestor desta ILPI pode distribuir os cuidadores de referência.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM profissional
                    WHERE id_ilpi = p_id_ilpi AND funcao = 'cuidador' AND ativo) THEN
        RAISE EXCEPTION 'A ILPI % não tem nenhum cuidador ativo.', p_id_ilpi;
    END IF;

    IF p_refazer THEN
        UPDATE idoso SET id_cuidador_referencia = NULL
         WHERE id_ilpi = p_id_ilpi AND ativo;
    END IF;

    OPEN c_residentes;
    LOOP
        FETCH c_residentes INTO v_id_idoso, v_nome, v_grau;
        EXIT WHEN NOT FOUND;               -- acabaram os residentes

        -- Cuidador com menor carga AGORA (já contando as atribuições
        -- feitas nas voltas anteriores). Empate: quem tem menos
        -- residentes; depois, o de menor código.
        SELECT p.id_profissional, p.nome
          INTO v_cuidador, v_nome_cuid
          FROM profissional p
          LEFT JOIN idoso i
                 ON i.id_cuidador_referencia = p.id_profissional
                AND i.ativo
         WHERE p.id_ilpi = p_id_ilpi
           AND p.funcao = 'cuidador'
           AND p.ativo
         GROUP BY p.id_profissional, p.nome
         ORDER BY COALESCE(sum(CASE i.grau_dependencia
                                   WHEN 'I'   THEN 3
                                   WHEN 'II'  THEN 6
                                   WHEN 'III' THEN 10
                               END), 0),
                  count(i.id_idoso),
                  p.id_profissional
         LIMIT 1;

        UPDATE idoso
           SET id_cuidador_referencia = v_cuidador
         WHERE id_idoso = v_id_idoso;

        v_atribuidos := v_atribuidos + 1;
        RAISE NOTICE 'Grau % — % → %', v_grau, v_nome, v_nome_cuid;
    END LOOP;
    CLOSE c_residentes;

    RAISE NOTICE '% residente(s) receberam cuidador de referência.', v_atribuidos;
END $$;

REVOKE ALL ON PROCEDURE sp_distribuir_cuidadores(int, boolean) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE sp_distribuir_cuidadores(int, boolean) TO app_user;


-- ************************************************************
-- TRIGGERS
-- ************************************************************

-- ------------------------------------------------------------
-- TRIGGER 1: trg_alerta_sinal_vital (sinal_vital → recado_plantao)
-- ------------------------------------------------------------
-- Justificativa: quem afere a pressão nem sempre é quem decide a conduta.
-- Uma saturação de 88% anotada às 3h da manhã não pode depender de a
-- cuidadora lembrar de avisar a enfermeira. Logo depois de cada aferição
-- (AFTER INSERT), o trigger confere os valores e, se algum estiver fora
-- da faixa segura, cria sozinho um recado na passagem de plantão daquele
-- turno, com prioridade "urgente" ou "atenção". Assim o alerta chega à
-- tela do plantão e o próximo turno recebe a informação.
--
-- Faixas usadas (valores de referência para idosos):
--   pressão         fn_classificar_pressao: estágio 2 (atenção), estágio 3 e hipotensão (urgente)
--   saturação O2    < 92% atenção, < 90% urgente
--   temperatura     >= 37,8 °C febre (atenção), >= 39 °C urgente
--   glicemia        < 70 mg/dL hipoglicemia (urgente), > 250 mg/dL atenção
--   freq. cardíaca  < 50 ou > 120 bpm atenção
--
-- SECURITY DEFINER: o recado é criado pelo sistema, mesmo que o
-- profissional que aferiu não tenha permissão de escrever no plantão.
-- O recado sai no nome de quem aferiu.
CREATE OR REPLACE FUNCTION fn_trg_alerta_sinal_vital()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_alertas    text[] := '{}';            -- lista de problemas encontrados
    v_urgente    boolean := false;
    v_pressao    varchar(30);
    v_hora       int;
    v_turno      turno_plantao;
    v_nome       varchar;
    v_id_ilpi    int;
BEGIN
    -- pressão arterial (usa a FUNÇÃO 1)
    v_pressao := fn_classificar_pressao(NEW.pressao_sis, NEW.pressao_dia);
    IF v_pressao IN ('Hipertensão estágio 3', 'Hipotensão') THEN
        v_alertas := v_alertas || format('PA %s/%s (%s)', NEW.pressao_sis, NEW.pressao_dia, v_pressao);
        v_urgente := true;
    ELSIF v_pressao = 'Hipertensão estágio 2' THEN
        v_alertas := v_alertas || format('PA %s/%s (%s)', NEW.pressao_sis, NEW.pressao_dia, v_pressao);
    END IF;

    -- saturação de oxigênio
    IF NEW.saturacao < 90 THEN
        v_alertas := v_alertas || format('saturação %s%%', NEW.saturacao);
        v_urgente := true;
    ELSIF NEW.saturacao < 92 THEN
        v_alertas := v_alertas || format('saturação %s%%', NEW.saturacao);
    END IF;

    -- temperatura
    IF NEW.temperatura >= 39 THEN
        v_alertas := v_alertas || format('febre alta %s °C', NEW.temperatura);
        v_urgente := true;
    ELSIF NEW.temperatura >= 37.8 THEN
        v_alertas := v_alertas || format('febre %s °C', NEW.temperatura);
    END IF;

    -- glicemia
    IF NEW.glicemia < 70 THEN
        v_alertas := v_alertas || format('hipoglicemia %s mg/dL', NEW.glicemia);
        v_urgente := true;
    ELSIF NEW.glicemia > 250 THEN
        v_alertas := v_alertas || format('glicemia alta %s mg/dL', NEW.glicemia);
    END IF;

    -- frequência cardíaca
    IF NEW.freq_cardiaca < 50 OR NEW.freq_cardiaca > 120 THEN
        v_alertas := v_alertas || format('FC %s bpm', NEW.freq_cardiaca);
    END IF;

    -- tudo dentro da faixa: nada a fazer
    -- (cardinality = tamanho do vetor; comparações com NULL dão NULL e
    --  não entram nos IFs, então medida não aferida não gera alerta)
    IF cardinality(v_alertas) = 0 THEN
        RETURN NEW;
    END IF;

    -- turno pela hora local da aferição
    v_hora := extract(hour FROM NEW.data_hora AT TIME ZONE 'America/Recife');
    v_turno := CASE WHEN v_hora >= 7  AND v_hora < 13 THEN 'manha'
                    WHEN v_hora >= 13 AND v_hora < 19 THEN 'tarde'
                    ELSE 'noite' END;

    SELECT nome, id_ilpi INTO v_nome, v_id_ilpi
      FROM idoso WHERE id_idoso = NEW.id_idoso;

    INSERT INTO recado_plantao (id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, data_hora)
    VALUES (v_id_ilpi,
            NEW.id_profissional,
            NEW.id_idoso,
            v_turno,
            CASE WHEN v_urgente THEN 'urgente' ELSE 'atencao' END::prioridade_plantao,
            format('[Alerta automático] Sinais vitais de %s fora da faixa: %s. Reavaliar e comunicar a enfermagem.',
                   v_nome, array_to_string(v_alertas, '; ')),
            NEW.data_hora);

    RETURN NEW;      -- em trigger AFTER o retorno é ignorado, mas é obrigatório
END $$;

DROP TRIGGER IF EXISTS trg_alerta_sinal_vital ON sinal_vital;
CREATE TRIGGER trg_alerta_sinal_vital
AFTER INSERT ON sinal_vital
FOR EACH ROW
EXECUTE FUNCTION fn_trg_alerta_sinal_vital();


-- ------------------------------------------------------------
-- TRIGGER 2 (tabela de log): trg_log_grau_dependencia (idoso → log_grau_dependencia)
-- ------------------------------------------------------------
-- Justificativa: o grau de dependência (I, II ou III) é a informação que
-- mais pesa na operação da ILPI: define quantos cuidadores a casa precisa
-- (FUNÇÃO 2), o valor da mensalidade e o plano de cuidado. A vigilância
-- sanitária pode pedir o histórico, e a família pode questionar uma
-- reclassificação. A tabela log_auditoria geral só registra "edição em
-- idoso", sem dizer o que mudou. Este trigger guarda, a cada mudança de
-- grau: o grau anterior, o novo, quem mudou, quando, e como ficou a
-- necessidade de cuidadores da ILPI depois da mudança.
-- O trigger só dispara quando a coluna grau_dependencia está no UPDATE
-- (UPDATE OF) e o valor de fato mudou (WHEN ... IS DISTINCT FROM); editar
-- só o nome do residente não gera log.

CREATE TABLE IF NOT EXISTS log_grau_dependencia (
    id_log                   SERIAL PRIMARY KEY,
    id_idoso                 INT NOT NULL REFERENCES idoso(id_idoso),
    grau_anterior            grau_dependencia NOT NULL,
    grau_novo                grau_dependencia NOT NULL,
    cuidadores_necessarios   INT NOT NULL,     -- da ILPI, já com o grau novo
    id_usuario               INT REFERENCES usuario(id_usuario)
                                 ON DELETE SET NULL,   -- quem alterou (NULL = administrador do banco)
    data_hora                TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (grau_anterior <> grau_novo)
);
CREATE INDEX IF NOT EXISTS ix_log_grau_idoso ON log_grau_dependencia (id_idoso, data_hora DESC);

-- quem pode ler o log: a equipe da ILPI do residente
ALTER TABLE log_grau_dependencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE log_grau_dependencia FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sel_log_grau ON log_grau_dependencia;
CREATE POLICY sel_log_grau ON log_grau_dependencia FOR SELECT TO app_user
    USING (fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional());
-- só leitura: quem grava é o trigger. Ninguém da aplicação altera ou apaga o log.
REVOKE ALL ON log_grau_dependencia FROM app_user;
GRANT SELECT ON log_grau_dependencia TO app_user;

CREATE OR REPLACE FUNCTION fn_trg_log_grau_dependencia()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO log_grau_dependencia
        (id_idoso, grau_anterior, grau_novo, cuidadores_necessarios, id_usuario)
    VALUES
        (NEW.id_idoso,
         OLD.grau_dependencia,                     -- OLD = linha antes do UPDATE
         NEW.grau_dependencia,                     -- NEW = linha depois
         fn_cuidadores_necessarios(NEW.id_ilpi),   -- usa a FUNÇÃO 2
         fn_usuario_atual());                      -- usuário logado na aplicação
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_log_grau_dependencia ON idoso;
CREATE TRIGGER trg_log_grau_dependencia
AFTER UPDATE OF grau_dependencia ON idoso
FOR EACH ROW
WHEN (OLD.grau_dependencia IS DISTINCT FROM NEW.grau_dependencia)
EXECUTE FUNCTION fn_trg_log_grau_dependencia();
