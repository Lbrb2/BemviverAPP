-- ============================================================
-- Plataforma de Acompanhamento de Idosos em ILPIs (Pernambuco)
-- Script DDL - PostgreSQL 15+
-- Padrões de referência: WHO ICOPE, interRAI LTCF, RDC 502/2021, LGPD
-- ============================================================

BEGIN;

-- ---------- Tipos enumerados ----------
CREATE TYPE perfil_usuario AS ENUM ('idoso', 'responsavel', 'profissional', 'gestor');
CREATE TYPE grau_dependencia AS ENUM ('I', 'II', 'III'); -- RDC 502/2021 (ANVISA)
CREATE TYPE funcao_profissional AS ENUM ('cuidador', 'tecnico_enfermagem', 'enfermeiro', 'medico', 'psicologo', 'fisioterapeuta', 'nutricionista', 'assistente_social', 'gestor');
CREATE TYPE instrumento_avaliacao AS ENUM ('KATZ', 'LAWTON', 'GDS15', 'WHOQOL_OLD', 'ICOPE');
CREATE TYPE tipo_registro_saude AS ENUM ('sinais_vitais', 'intercorrencia', 'consulta', 'medicacao');
CREATE TYPE categoria_atividade AS ENUM ('fisica', 'social', 'cognitiva', 'artistica', 'espiritual');
CREATE TYPE origem_evento_pet AS ENUM ('checkin_bem_estar', 'participacao_atividade', 'avaliacao_concluida', 'interacao_pet', 'partida_domino', 'partida_jogo');
CREATE TYPE acao_auditoria AS ENUM ('leitura', 'criacao', 'edicao', 'exclusao');
CREATE TYPE tipo_intercorrencia AS ENUM ('queda', 'lesao', 'mal_estar', 'comportamento', 'fuga', 'obito', 'outro');
CREATE TYPE gravidade_evento AS ENUM ('leve', 'moderada', 'grave');
CREATE TYPE refeicao_tipo AS ENUM ('cafe', 'almoco', 'lanche', 'jantar', 'ceia');
CREATE TYPE status_meta AS ENUM ('ativa', 'atingida', 'suspensa');
CREATE TYPE categoria_meta AS ENUM ('saude', 'mobilidade', 'nutricao', 'social', 'cognitiva', 'emocional', 'autonomia');
CREATE TYPE turno_plantao AS ENUM ('manha', 'tarde', 'noite');
CREATE TYPE prioridade_plantao AS ENUM ('rotina', 'atencao', 'urgente');

-- ---------- Validação de documentos (usadas nos CHECK de ilpi e idoso) ----------
-- IMMUTABLE: o resultado depende só do texto recebido, o que o PostgreSQL
-- exige de uma função chamada dentro de uma restrição CHECK.
-- Recusa tamanho errado, letras e sequências repetidas (111.111.111-11),
-- que passam no cálculo do dígito mas não são documentos reais.
CREATE FUNCTION fn_cpf_valido(p text) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE AS $$
DECLARE s int; d1 int; d2 int; i int;
BEGIN
    IF p !~ '^[0-9]{11}$' OR p ~ '^(.)\1{10}$' THEN RETURN false; END IF;
    s := 0; FOR i IN 1..9 LOOP s := s + substr(p, i, 1)::int * (11 - i); END LOOP;
    d1 := CASE WHEN s % 11 < 2 THEN 0 ELSE 11 - s % 11 END;
    s := 0; FOR i IN 1..10 LOOP s := s + substr(p, i, 1)::int * (12 - i); END LOOP;
    d2 := CASE WHEN s % 11 < 2 THEN 0 ELSE 11 - s % 11 END;
    RETURN d1 = substr(p, 10, 1)::int AND d2 = substr(p, 11, 1)::int;
END $$;

CREATE FUNCTION fn_cnpj_valido(p text) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE AS $$
DECLARE pesos1 int[] := '{5,4,3,2,9,8,7,6,5,4,3,2}';
        pesos2 int[] := '{6,5,4,3,2,9,8,7,6,5,4,3,2}';
        s int; d1 int; d2 int; i int;
BEGIN
    IF p !~ '^[0-9]{14}$' OR p ~ '^(.)\1{13}$' THEN RETURN false; END IF;
    s := 0; FOR i IN 1..12 LOOP s := s + substr(p, i, 1)::int * pesos1[i]; END LOOP;
    d1 := CASE WHEN s % 11 < 2 THEN 0 ELSE 11 - s % 11 END;
    s := 0; FOR i IN 1..13 LOOP s := s + substr(p, i, 1)::int * pesos2[i]; END LOOP;
    d2 := CASE WHEN s % 11 < 2 THEN 0 ELSE 11 - s % 11 END;
    RETURN d1 = substr(p, 13, 1)::int AND d2 = substr(p, 14, 1)::int;
END $$;

-- ---------- Instituições ----------
CREATE TABLE ilpi (
    id_ilpi         SERIAL PRIMARY KEY,
    cnpj            CHAR(14) NOT NULL UNIQUE,
    nome            VARCHAR(150) NOT NULL,
    municipio       VARCHAR(100) NOT NULL,
    uf              CHAR(2) NOT NULL DEFAULT 'PE',
    licenca_anvisa  VARCHAR(30),
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_ilpi_cnpj CHECK (fn_cnpj_valido(cnpj)),
    CONSTRAINT ck_ilpi_uf CHECK (uf IN ('AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA',
                                        'PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'))
);

-- ---------- Autenticação e perfis ----------
CREATE TABLE usuario (
    id_usuario   SERIAL PRIMARY KEY,
    email        VARCHAR(150) NOT NULL UNIQUE,
    senha_hash   VARCHAR(255) NOT NULL,
    perfil       perfil_usuario NOT NULL,
    ativo        BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em    TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- e-mail guardado sempre em minúsculas: o UNIQUE passa a valer sem
    -- diferenciar maiúsculas ("Ana@x.com" e "ana@x.com" seriam duas contas)
    CONSTRAINT ck_email_formato CHECK (email ~ '^[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}$')
);

CREATE TABLE idoso (
    id_idoso          SERIAL PRIMARY KEY,
    id_ilpi           INT NOT NULL REFERENCES ilpi(id_ilpi),
    id_usuario        INT UNIQUE REFERENCES usuario(id_usuario)
                          ON DELETE SET NULL, -- opcional: nem todo idoso usa o app;
                                              -- se a conta de acesso for apagada, o residente permanece
    nome              VARCHAR(150) NOT NULL,
    cpf               CHAR(11) NOT NULL UNIQUE,
    data_nascimento   DATE NOT NULL,
    data_admissao     DATE NOT NULL DEFAULT CURRENT_DATE,
    grau_dependencia  grau_dependencia NOT NULL,
    ativo             BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_idoso_60mais CHECK (data_nascimento <= CURRENT_DATE - INTERVAL '60 years'),
    CONSTRAINT ck_admissao_valida CHECK (data_admissao >= data_nascimento),
    CONSTRAINT ck_idoso_cpf CHECK (fn_cpf_valido(cpf))
);

CREATE TABLE responsavel (
    id_responsavel  SERIAL PRIMARY KEY,
    id_usuario      INT NOT NULL UNIQUE REFERENCES usuario(id_usuario),
    nome            VARCHAR(150) NOT NULL,
    telefone        VARCHAR(11) NOT NULL,
    -- só dígitos, com DDD: 10 (fixo) ou 11 (celular)
    CONSTRAINT ck_telefone CHECK (telefone ~ '^[1-9][0-9][2-9][0-9]{7,8}$')
);

CREATE TABLE vinculo_responsavel (
    -- ON UPDATE CASCADE: se o identificador de um idoso ou responsável for
    -- renumerado (ex.: fusão de cadastros duplicados), o vínculo acompanha.
    id_idoso          INT NOT NULL REFERENCES idoso(id_idoso) ON UPDATE CASCADE,
    id_responsavel    INT NOT NULL REFERENCES responsavel(id_responsavel) ON UPDATE CASCADE,
    parentesco        VARCHAR(50) NOT NULL,
    responsavel_legal BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id_idoso, id_responsavel)
);

-- No máximo um responsável legal por idoso
CREATE UNIQUE INDEX ux_um_resp_legal
    ON vinculo_responsavel (id_idoso)
    WHERE responsavel_legal = TRUE;

CREATE TABLE profissional (
    id_profissional   SERIAL PRIMARY KEY,
    id_ilpi           INT NOT NULL REFERENCES ilpi(id_ilpi),
    id_usuario        INT NOT NULL UNIQUE REFERENCES usuario(id_usuario),
    nome              VARCHAR(150) NOT NULL,
    funcao            funcao_profissional NOT NULL,
    registro_conselho VARCHAR(30), -- COREN, CRM, CRP etc.
    ativo             BOOLEAN NOT NULL DEFAULT TRUE
);

-- ---------- Avaliações padronizadas (ICOPE, Katz, Lawton...) ----------
CREATE TABLE avaliacao (
    id_avaliacao    SERIAL PRIMARY KEY,
    id_idoso        INT NOT NULL REFERENCES idoso(id_idoso),
    id_profissional INT NOT NULL REFERENCES profissional(id_profissional),
    instrumento     instrumento_avaliacao NOT NULL,
    data_hora       TIMESTAMPTZ NOT NULL DEFAULT now(),
    pontuacao_total INT,
    interpretacao   VARCHAR(120),           -- ex.: "Dependência parcial" (Katz)
    observacoes     TEXT
);

CREATE TABLE item_avaliacao (
    id_item      SERIAL PRIMARY KEY,
    id_avaliacao INT NOT NULL REFERENCES avaliacao(id_avaliacao) ON DELETE CASCADE,
    dominio      VARCHAR(60) NOT NULL, -- ex.: mobilidade, cognicao, humor, nutricao
    resposta     VARCHAR(200) NOT NULL,
    pontuacao    INT NOT NULL
);

-- ---------- Registros do dia a dia ----------
CREATE TABLE registro_bem_estar (
    id_registro     SERIAL PRIMARY KEY,
    id_idoso        INT NOT NULL REFERENCES idoso(id_idoso),
    id_profissional INT REFERENCES profissional(id_profissional)
                        ON DELETE SET NULL, -- NULL = autorregistro (ou profissional removido)
    data_hora       TIMESTAMPTZ NOT NULL DEFAULT now(),
    humor           SMALLINT NOT NULL CHECK (humor BETWEEN 1 AND 5),
    conforto        SMALLINT NOT NULL CHECK (conforto BETWEEN 1 AND 5),
    dor             SMALLINT NOT NULL CHECK (dor BETWEEN 0 AND 10),
    observacoes     TEXT
);

CREATE TABLE registro_saude (
    id_registro     SERIAL PRIMARY KEY,
    id_idoso        INT NOT NULL REFERENCES idoso(id_idoso),
    id_profissional INT NOT NULL REFERENCES profissional(id_profissional),
    tipo            tipo_registro_saude NOT NULL,
    data_hora       TIMESTAMPTZ NOT NULL DEFAULT now(),
    descricao       TEXT NOT NULL
);

-- Acesso à evolução deve ser restrito ao psicólogo (aplicar em nível de aplicação/RLS)
CREATE TABLE atendimento_psicologico (
    id_atendimento  SERIAL PRIMARY KEY,
    id_idoso        INT NOT NULL REFERENCES idoso(id_idoso),
    id_profissional INT NOT NULL REFERENCES profissional(id_profissional),
    data_hora       TIMESTAMPTZ NOT NULL DEFAULT now(),
    evolucao        TEXT NOT NULL
);

-- ---------- Lazer ----------
CREATE TABLE atividade_lazer (
    id_atividade SERIAL PRIMARY KEY,
    id_ilpi      INT NOT NULL REFERENCES ilpi(id_ilpi),
    nome         VARCHAR(120) NOT NULL,
    categoria    categoria_atividade NOT NULL,
    data_hora    TIMESTAMPTZ NOT NULL
);

CREATE TABLE participacao (
    id_idoso          INT NOT NULL REFERENCES idoso(id_idoso) ON UPDATE CASCADE,
    id_atividade      INT NOT NULL REFERENCES atividade_lazer(id_atividade) ON UPDATE CASCADE,
    nivel_engajamento SMALLINT NOT NULL CHECK (nivel_engajamento BETWEEN 1 AND 5),
    PRIMARY KEY (id_idoso, id_atividade)
);

-- ---------- Gamificação: pet virtual ----------
CREATE TABLE pet_virtual (
    id_pet   SERIAL PRIMARY KEY,
    id_idoso INT NOT NULL UNIQUE REFERENCES idoso(id_idoso),
    nome     VARCHAR(60) NOT NULL,
    especie  VARCHAR(40) NOT NULL,
    pontos   INT NOT NULL DEFAULT 0 CHECK (pontos >= 0),
    -- nível derivado dos pontos (1 nível a cada 100): coluna gerada, nunca
    -- fica em desacordo com os pontos e não pode ser gravada diretamente
    nivel    INT NOT NULL GENERATED ALWAYS AS (1 + pontos / 100) STORED,
    acessorio VARCHAR(30),
    cor       VARCHAR(20)
);

CREATE TABLE evento_pet (
    id_evento     SERIAL PRIMARY KEY,
    id_pet        INT NOT NULL REFERENCES pet_virtual(id_pet) ON DELETE CASCADE,
    origem        origem_evento_pet NOT NULL,
    pontos_ganhos INT NOT NULL CHECK (pontos_ganhos > 0),
    data_hora     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Dominó do Lar ----------
-- jogador2 NULL = partida contra o computador ("Seu Biu").
-- Partidas entre idosos são dado de interação social (ICOPE/WHOQOL-OLD).
CREATE TABLE partida_domino (
    id_partida  SERIAL PRIMARY KEY,
    id_ilpi     INT NOT NULL REFERENCES ilpi(id_ilpi),
    id_jogador1 INT NOT NULL REFERENCES idoso(id_idoso),
    id_jogador2 INT REFERENCES idoso(id_idoso),
    vencedor    SMALLINT CHECK (vencedor IN (1, 2)), -- NULL = partida abandonada
    motivo      VARCHAR(20) NOT NULL CHECK (motivo IN ('bateu', 'fechado', 'abandono')),
    data_hora   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_jogadores_diferentes CHECK (id_jogador2 IS NULL OR id_jogador1 <> id_jogador2)
);

-- ---------- Outros jogos (individuais, contra o computador) ----------
-- Memória, Buraco, Paciência e Cuidar do Xodó. O dominó fica na tabela
-- própria porque pode ter dois idosos jogando juntos.
CREATE TABLE partida_jogo (
    id_partida_jogo SERIAL PRIMARY KEY,
    id_idoso        INT NOT NULL REFERENCES idoso(id_idoso),
    jogo            VARCHAR(20) NOT NULL
                    CHECK (jogo IN ('memoria', 'buraco', 'paciencia', 'cuidar_xodo')),
    resultado       VARCHAR(12) NOT NULL
                    CHECK (resultado IN ('vitoria', 'derrota', 'concluido', 'abandono')),
    pontuacao       INT CHECK (pontuacao >= 0),   -- placar do jogo, quando houver (ex.: buraco)
    jogadas         INT CHECK (jogadas >= 0),     -- tentativas ou movimentos
    data_hora       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_partida_jogo_idoso ON partida_jogo (id_idoso, data_hora DESC);

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
    CONSTRAINT ck_tem_horario CHECK (array_length(horarios, 1) >= 1),
    -- suspender uma prescrição = registrar a data de fim: assim o histórico
    -- (ex.: consulta de adesão de semanas passadas) continua sabendo até
    -- quando as doses eram devidas
    CONSTRAINT ck_inativa_tem_fim CHECK (ativo OR fim IS NOT NULL)
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

CREATE INDEX ix_prescricao_idoso ON prescricao (id_idoso, ativo);
CREATE INDEX ix_adm_prescricao   ON administracao_medicacao (id_prescricao, horario_previsto DESC);

-- ---------- Mural da Família ----------
CREATE TABLE recado_mural (
    id_recado      SERIAL PRIMARY KEY,
    id_idoso       INT NOT NULL REFERENCES idoso(id_idoso),
    id_responsavel INT NOT NULL REFERENCES responsavel(id_responsavel),
    texto          VARCHAR(500) NOT NULL CHECK (length(trim(texto)) > 0),
    data_hora      TIMESTAMPTZ NOT NULL DEFAULT now(),
    editado_em     TIMESTAMPTZ,                   -- preenchido quando o autor edita
    CONSTRAINT ck_edicao_posterior CHECK (editado_em IS NULL OR editado_em >= data_hora)
);

CREATE INDEX ix_recado_idoso ON recado_mural (id_idoso, data_hora DESC);

-- ---------- Passagem de plantão ----------
CREATE TABLE recado_plantao (
    id_recado       SERIAL PRIMARY KEY,
    id_ilpi         INT NOT NULL REFERENCES ilpi(id_ilpi),
    id_profissional INT NOT NULL REFERENCES profissional(id_profissional),
    id_idoso        INT REFERENCES idoso(id_idoso)
                        ON DELETE SET NULL, -- NULL = recado geral da equipe
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

-- ---------- Sinais vitais ----------
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

-- ---------- Plano de cuidado ----------
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

-- ---------- Intercorrências e nutrição ----------
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

CREATE TABLE restricao_alimentar (
    id_restricao  SERIAL PRIMARY KEY,
    id_idoso      INT NOT NULL REFERENCES idoso(id_idoso),
    descricao     VARCHAR(120) NOT NULL,     -- "diabético", "sem sal", "pastoso"
    UNIQUE (id_idoso, descricao)
);

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

CREATE INDEX ix_interc_idoso ON intercorrencia (id_idoso, data_hora DESC);
CREATE INDEX ix_refeicao_idoso ON registro_refeicao (id_idoso, data_hora DESC);

-- ---------- LGPD ----------
CREATE TABLE consentimento_lgpd (
    id_consentimento SERIAL PRIMARY KEY,
    id_idoso         INT NOT NULL REFERENCES idoso(id_idoso),
    -- 'dados_saude' é o que libera os registros clínicos para a família (ver RLS)
    categoria        VARCHAR(20) NOT NULL DEFAULT 'dados_saude'
                     CHECK (categoria IN ('dados_saude', 'imagem', 'outros')),
    finalidade       VARCHAR(200) NOT NULL,
    data_concessao   TIMESTAMPTZ NOT NULL DEFAULT now(),
    data_revogacao   TIMESTAMPTZ,
    CONSTRAINT ck_revogacao CHECK (data_revogacao IS NULL OR data_revogacao >= data_concessao)
);

-- Um consentimento vigente por idoso e categoria; o histórico (revogados) fica
CREATE UNIQUE INDEX ux_consentimento_vigente
    ON consentimento_lgpd (id_idoso, categoria)
    WHERE data_revogacao IS NULL;

CREATE TABLE log_auditoria (
    id_log         BIGSERIAL PRIMARY KEY,
    id_usuario     INT NOT NULL REFERENCES usuario(id_usuario),
    acao           acao_auditoria NOT NULL,
    tabela_afetada VARCHAR(60) NOT NULL,
    id_registro    INT,
    data_hora      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Índices de consulta frequente ----------
CREATE INDEX ix_idoso_ilpi            ON idoso (id_ilpi, ativo);
CREATE INDEX ix_avaliacao_idoso_data  ON avaliacao (id_idoso, data_hora DESC);
CREATE INDEX ix_bem_estar_idoso_data  ON registro_bem_estar (id_idoso, data_hora DESC);
CREATE INDEX ix_saude_idoso_data      ON registro_saude (id_idoso, data_hora DESC);
CREATE INDEX ix_psico_idoso_data      ON atendimento_psicologico (id_idoso, data_hora DESC);
CREATE INDEX ix_atividade_ilpi_data   ON atividade_lazer (id_ilpi, data_hora);
CREATE INDEX ix_evento_pet_data       ON evento_pet (id_pet, data_hora DESC);
CREATE INDEX ix_auditoria_usuario     ON log_auditoria (id_usuario, data_hora DESC);
CREATE INDEX ix_partida_j1_data       ON partida_domino (id_jogador1, data_hora DESC);
CREATE INDEX ix_partida_j2_data       ON partida_domino (id_jogador2, data_hora DESC) WHERE id_jogador2 IS NOT NULL;

-- ---------- Índices nas chaves estrangeiras ----------
-- O PostgreSQL indexa a PK e o UNIQUE, mas não a coluna que referencia.
-- Sem índice, apagar ou renumerar a linha referenciada (ON UPDATE CASCADE,
-- ON DELETE SET NULL) varre a tabela filha inteira, e os JOINs pela FK
-- também. As FKs já cobertas por um índice acima (ou por ser a 1ª coluna
-- de uma PK) não se repetem aqui. Índices parciais só valem para isso
-- quando o filtro é "coluna IS NOT NULL" (a busca da FK é por igualdade);
-- por isso idoso(id_ilpi) e prescricao(id_idoso) usam índice completo.
CREATE INDEX ix_fk_profissional_ilpi     ON profissional (id_ilpi);
CREATE INDEX ix_fk_vinculo_responsavel   ON vinculo_responsavel (id_responsavel);
CREATE INDEX ix_fk_avaliacao_prof        ON avaliacao (id_profissional);
CREATE INDEX ix_fk_item_avaliacao        ON item_avaliacao (id_avaliacao);
CREATE INDEX ix_fk_bem_estar_prof        ON registro_bem_estar (id_profissional) WHERE id_profissional IS NOT NULL;
CREATE INDEX ix_fk_saude_prof            ON registro_saude (id_profissional);
CREATE INDEX ix_fk_psico_prof            ON atendimento_psicologico (id_profissional);
CREATE INDEX ix_fk_participacao_ativ     ON participacao (id_atividade);
CREATE INDEX ix_fk_partida_ilpi          ON partida_domino (id_ilpi);
CREATE INDEX ix_fk_prescricao_prof       ON prescricao (id_profissional);
CREATE INDEX ix_fk_adm_prof              ON administracao_medicacao (id_profissional);
CREATE INDEX ix_fk_mural_responsavel     ON recado_mural (id_responsavel);
CREATE INDEX ix_fk_plantao_prof          ON recado_plantao (id_profissional);
CREATE INDEX ix_fk_ciencia_prof          ON ciencia_plantao (id_profissional);
CREATE INDEX ix_fk_sinal_idoso_data      ON sinal_vital (id_idoso, data_hora DESC);
CREATE INDEX ix_fk_sinal_prof            ON sinal_vital (id_profissional);
CREATE INDEX ix_fk_meta_idoso            ON meta_cuidado (id_idoso);
CREATE INDEX ix_fk_meta_prof             ON meta_cuidado (id_profissional);
CREATE INDEX ix_fk_evol_meta             ON evolucao_meta (id_meta, data_hora DESC);
CREATE INDEX ix_fk_evol_meta_prof        ON evolucao_meta (id_profissional);
CREATE INDEX ix_fk_interc_prof           ON intercorrencia (id_profissional);
CREATE INDEX ix_fk_refeicao_prof         ON registro_refeicao (id_profissional);
CREATE INDEX ix_fk_consentimento_idoso   ON consentimento_lgpd (id_idoso);

-- ---------- View: Painel do Idoso ----------
-- Visão consolidada para a tela inicial do responsável e da equipe
CREATE VIEW vw_painel_idoso AS
SELECT
    i.id_idoso,
    i.nome,
    i.grau_dependencia,
    il.nome                                   AS ilpi,
    date_part('year', age(i.data_nascimento)) AS idade,
    be.humor                                  AS ultimo_humor,
    be.conforto                               AS ultimo_conforto,
    be.dor                                    AS ultima_dor,
    be.data_hora                              AS ultimo_checkin,
    av.instrumento                            AS ultima_avaliacao,
    av.pontuacao_total                        AS ultima_pontuacao,
    av.data_hora                              AS data_ultima_avaliacao,
    pv.nome                                   AS pet,
    pv.nivel                                  AS nivel_pet,
    (SELECT count(*)
       FROM participacao p
       JOIN atividade_lazer a USING (id_atividade)
      WHERE p.id_idoso = i.id_idoso
        AND a.data_hora >= now() - INTERVAL '30 days') AS atividades_30d,
    pv.pontos                                 AS pontos_pet
FROM idoso i
JOIN ilpi il USING (id_ilpi)
LEFT JOIN LATERAL (
    SELECT humor, conforto, dor, data_hora
      FROM registro_bem_estar r
     WHERE r.id_idoso = i.id_idoso
     ORDER BY data_hora DESC LIMIT 1
) be ON TRUE
LEFT JOIN LATERAL (
    SELECT instrumento, pontuacao_total, data_hora
      FROM avaliacao a
     WHERE a.id_idoso = i.id_idoso
     ORDER BY data_hora DESC LIMIT 1
) av ON TRUE
LEFT JOIN pet_virtual pv ON pv.id_idoso = i.id_idoso
WHERE i.ativo;

COMMIT;
