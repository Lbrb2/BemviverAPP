-- ============================================================
-- Bem Viver ILPI — Etapa 04: consultas avançadas
-- Executar depois de etapa04_indices_e_visoes.sql.
-- A numeração continua a da Etapa 03 (consultas 1 a 10).
--
-- Rodando como superusuário (psql/pgAdmin), o resultado traz todas as
-- ILPIs. Na aplicação, o RLS recorta para a ILPI de quem está logado.
-- ============================================================

SET TIME ZONE 'America/Recife';


-- ------------------------------------------------------------
-- 11) ANTI JOIN — residentes sem aferição de sinais vitais em 7 dias
-- ------------------------------------------------------------
-- Pergunta: quem está há uma semana sem ter pressão, saturação ou
-- temperatura medidas? A rotina de aferição é o que permite perceber
-- cedo uma piora, principalmente nos residentes de grau III.
-- Técnica: LEFT JOIN + WHERE <lado direito> IS NULL (anti join à
-- esquerda). O LEFT JOIN tenta achar uma aferição recente para cada
-- residente; quem não tem nenhuma fica com as colunas de sinal_vital
-- nulas, e o WHERE mantém exatamente esses.
-- Atenção: o filtro de data fica no ON, não no WHERE. Se ficasse no
-- WHERE, o LEFT JOIN viraria um INNER JOIN e a consulta não acharia ninguém.
SELECT i.nome              AS residente,
       il.nome             AS ilpi,
       i.grau_dependencia,
       i.data_admissao
  FROM idoso i
  JOIN ilpi il ON il.id_ilpi = i.id_ilpi
  LEFT JOIN sinal_vital s
         ON s.id_idoso = i.id_idoso
        AND s.data_hora >= now() - INTERVAL '7 days'
 WHERE i.ativo
   AND s.id_sinal IS NULL
 ORDER BY i.grau_dependencia DESC, il.nome, i.nome;


-- ------------------------------------------------------------
-- 12) FULL OUTER JOIN — intercorrências x recados de plantão (30 dias)
-- ------------------------------------------------------------
-- Pergunta: a comunicação entre os turnos está acompanhando o que
-- acontece com os residentes? Toda intercorrência (queda, mal-estar...)
-- deveria virar um recado na passagem de plantão, e um recado sobre um
-- residente costuma indicar algo que talvez devesse estar registrado
-- como intercorrência.
-- Técnica: FULL OUTER JOIN entre dois resumos por residente. Ele traz os
-- residentes que aparecem nos DOIS lados e também os que aparecem em só
-- um deles, que são justamente as falhas de comunicação:
--   - intercorrência sem nenhum recado no plantão;
--   - recado no plantão sem intercorrência registrada.
-- Como o residente pode faltar de um dos lados, o código dele vem do
-- COALESCE dos dois.
-- Índice usado: ix_intercorrencia_data (filtro só por data).
WITH intercorrencias AS (
    SELECT id_idoso,
           count(*)       AS qtd,
           max(data_hora) AS ultima
      FROM intercorrencia
     WHERE data_hora >= now() - INTERVAL '30 days'
     GROUP BY id_idoso
), recados AS (
    SELECT id_idoso,
           count(*)       AS qtd,
           max(data_hora) AS ultimo
      FROM recado_plantao
     WHERE id_idoso IS NOT NULL
       AND data_hora >= now() - INTERVAL '30 days'
     GROUP BY id_idoso
)
SELECT i.nome                                       AS residente,
       COALESCE(ic.qtd, 0)                          AS intercorrencias,
       COALESCE(rp.qtd, 0)                          AS recados_plantao,
       to_char(ic.ultima, 'DD/MM HH24:MI')          AS ultima_intercorrencia,
       to_char(rp.ultimo, 'DD/MM HH24:MI')          AS ultimo_recado,
       CASE
           WHEN rp.id_idoso IS NULL THEN 'Intercorrência sem recado no plantão'
           WHEN ic.id_idoso IS NULL THEN 'Recado sem intercorrência registrada'
           ELSE 'Registrado nos dois'
       END                                          AS situacao
  FROM intercorrencias ic
  FULL OUTER JOIN recados rp ON rp.id_idoso = ic.id_idoso
  JOIN idoso i ON i.id_idoso = COALESCE(ic.id_idoso, rp.id_idoso)
 ORDER BY situacao, i.nome;


-- ------------------------------------------------------------
-- 13) SUBCONSULTA — residentes com dor acima da média da própria ILPI
-- ------------------------------------------------------------
-- Pergunta: quem está relatando mais dor que os colegas da mesma casa
-- nos últimos 30 dias? Comparar com a média da própria ILPI (e não com
-- um número fixo) evita que uma casa com perfil mais dependente pareça
-- "pior" só por isso. É a lista para a reavaliação médica e de
-- fisioterapia.
-- Técnica: subconsulta CORRELACIONADA. Ela aparece duas vezes: no
-- SELECT, para mostrar a média da ILPI ao lado, e no HAVING, para manter
-- só quem está acima dela. É correlacionada porque usa i.id_ilpi da
-- consulta de fora: é recalculada para a ILPI de cada residente.
SELECT i.nome                         AS residente,
       il.nome                        AS ilpi,
       count(*)                       AS checkins,
       round(avg(r.dor), 2)           AS dor_media_residente,
       (SELECT round(avg(r2.dor), 2)
          FROM registro_bem_estar r2
          JOIN idoso i2 ON i2.id_idoso = r2.id_idoso
         WHERE i2.id_ilpi = i.id_ilpi
           AND i2.ativo
           AND r2.data_hora >= now() - INTERVAL '30 days')
                                      AS dor_media_ilpi
  FROM idoso i
  JOIN ilpi il               ON il.id_ilpi = i.id_ilpi
  JOIN registro_bem_estar r  ON r.id_idoso = i.id_idoso
 WHERE i.ativo
   AND r.data_hora >= now() - INTERVAL '30 days'
 GROUP BY i.id_idoso, i.nome, il.nome, i.id_ilpi
HAVING avg(r.dor) > (SELECT avg(r2.dor)
                       FROM registro_bem_estar r2
                       JOIN idoso i2 ON i2.id_idoso = r2.id_idoso
                      WHERE i2.id_ilpi = i.id_ilpi
                        AND i2.ativo
                        AND r2.data_hora >= now() - INTERVAL '30 days')
 ORDER BY dor_media_residente DESC, i.nome;


-- ------------------------------------------------------------
-- 14) SUBCONSULTAS — agenda de revisão do plano de cuidado (15 dias)
-- ------------------------------------------------------------
-- Pergunta: quais metas ativas do plano de cuidado precisam ser
-- revisadas até daqui a 15 dias (ou já passaram da data), e quando foi
-- a última vez que alguém registrou evolução nelas? Uma meta perto da
-- revisão e sem evolução recente é sinal de que o plano ficou parado.
-- Técnica: duas subconsultas ESCALARES correlacionadas no SELECT (cada
-- uma devolve um único valor por meta: a data da última evolução e o
-- número de evoluções) e uma subconsulta com IN no WHERE, que mantém só
-- as metas cujo responsável ainda está na equipe.
-- Índice usado: ix_meta_ativa_revisao (status = 'ativa' + data_revisao).
SELECT i.nome                                  AS residente,
       m.categoria,
       m.descricao                             AS meta,
       pr.nome                                 AS responsavel_meta,
       to_char(m.data_revisao, 'DD/MM/YYYY')   AS data_revisao,
       m.data_revisao - CURRENT_DATE           AS dias_para_revisao,
       (SELECT to_char(max(e.data_hora), 'DD/MM/YYYY')
          FROM evolucao_meta e
         WHERE e.id_meta = m.id_meta)          AS ultima_evolucao,
       (SELECT count(*)
          FROM evolucao_meta e
         WHERE e.id_meta = m.id_meta)          AS qtd_evolucoes
  FROM meta_cuidado m
  JOIN idoso i         ON i.id_idoso = m.id_idoso
  JOIN profissional pr ON pr.id_profissional = m.id_profissional
 WHERE m.status = 'ativa'
   AND m.data_revisao <= CURRENT_DATE + 15
   AND m.id_profissional IN (SELECT id_profissional
                               FROM profissional
                              WHERE ativo)
   AND i.ativo
 ORDER BY m.data_revisao, i.nome;


-- ------------------------------------------------------------
-- Usando as visões
-- ------------------------------------------------------------

-- Visão 1: prescrições ativas com doses abaixo do previsto na semana
SELECT residente, medicamento, dose, horarios, prescrito_por,
       to_char(ultima_dose, 'DD/MM HH24:MI') AS ultima_dose,
       doses_dadas_semana, doses_previstas_semana
  FROM vw_mapa_medicacao
 WHERE doses_dadas_semana < doses_previstas_semana
 ORDER BY ilpi, residente, medicamento;

-- Visão 2: intercorrências dos últimos 30 dias em que a família ainda
-- não foi avisada, com o contato do responsável legal
SELECT to_char(data_hora, 'DD/MM HH24:MI') AS quando,
       residente, tipo, gravidade, registrado_por,
       responsavel_legal, parentesco, telefone_responsavel
  FROM vw_intercorrencia_contato
 WHERE NOT familia_avisada
   AND data_hora >= now() - INTERVAL '30 days'
 ORDER BY gravidade DESC, data_hora DESC;


-- ------------------------------------------------------------
-- Conferindo que os índices novos são usados (EXPLAIN)
-- ------------------------------------------------------------
-- Com os dados de exemplo (poucas dezenas de linhas), ler a tabela
-- inteira é mais barato que usar qualquer índice, e o PostgreSQL faz
-- isso. Para ver o plano que ele usaria com a tabela cheia, desligamos a
-- leitura sequencial só nesta sessão.
SET enable_seqscan = off;

-- Deve aparecer "Index Scan using ix_intercorrencia_data"
EXPLAIN
SELECT id_idoso, count(*)
  FROM intercorrencia
 WHERE data_hora >= now() - INTERVAL '30 days'
 GROUP BY id_idoso;

-- Deve aparecer "Index Scan using ix_meta_ativa_revisao"
EXPLAIN
SELECT id_meta, data_revisao
  FROM meta_cuidado
 WHERE status = 'ativa'
   AND data_revisao <= CURRENT_DATE + 15;

RESET enable_seqscan;
