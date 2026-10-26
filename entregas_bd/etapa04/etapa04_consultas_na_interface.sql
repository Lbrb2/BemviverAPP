-- ============================================================
-- Bem Viver ILPI — Consultas da Etapa 04 como a interface executa
-- Arquivo GERADO a partir de api/consultas.js: são exatamente os SQLs
-- que a tela "📊 Consultas" do gestor executa.
--
-- Na aplicação, cada consulta roda dentro de uma transação com a
-- identidade do usuário (set_config('app.id_usuario', ...)), e o RLS
-- limita o resultado à ILPI do gestor. Rodando aqui como superusuário,
-- o resultado inclui todas as ILPIs.
-- Executar após a instalação completa (inclui etapa04_indices_e_visoes.sql).
-- A versão comentada, com as justificativas, é etapa04_consultas.sql.
--
-- Período e filtro como parâmetros: $1 = nº de dias e/ou o filtro escolhido
-- na tela. Na API, o valor vai separado do SQL — c.query(sql, [dias]) —; aqui
-- o mesmo SQL é preparado (PREPARE) e executado com o período padrão
-- (EXECUTE). Para outro período, basta trocar o número no EXECUTE.
-- ============================================================

-- Horários de medicação são hora local de Pernambuco (a API faz o mesmo).
SET TIME ZONE 'America/Recife';

-- ------------------------------------------------------------
-- 11) Residentes sem aferição de sinais vitais
--    Pergunta: Quem está há dias sem ter pressão, saturação ou temperatura medidas?
--    Técnicas: ANTI JOIN (LEFT JOIN + IS NULL), filtro no ON, parâmetros $1 e $2
--    Gráfico na interface: pizza com a contagem de linhas por grau_dependencia
--    Parâmetro $1: período em dias (na tela: 3, 7, 15; padrão 7)
--    Parâmetro $2: grau de dependência (na tela: todos, I, II, III; padrão todos)
-- ------------------------------------------------------------
PREPARE consulta_11(int, text) AS
SELECT i.nome                   AS residente,
       'Grau ' || i.grau_dependencia AS grau_dependencia,
       to_char(i.data_admissao, 'DD/MM/YYYY') AS admitido_em
  FROM idoso i
  LEFT JOIN sinal_vital s
         ON s.id_idoso = i.id_idoso
        AND s.data_hora >= now() - make_interval(days => $1::int)
 WHERE i.ativo
   AND s.id_sinal IS NULL
   AND ($2::text = 'todos' OR i.grau_dependencia::text = $2::text)
 ORDER BY i.grau_dependencia DESC, i.nome;
EXECUTE consulta_11(7, 'todos');

-- ------------------------------------------------------------
-- 12) Intercorrências × recados de plantão
--    Pergunta: A passagem de plantão está acompanhando o que acontece com os residentes?
--    Técnicas: FULL OUTER JOIN, CTE, COALESCE, CASE, parâmetro $1
--    Gráfico na interface: pizza com a contagem de linhas por situacao
--    Parâmetro $1: período em dias (na tela: 30, 60, 90; padrão 30)
-- ------------------------------------------------------------
PREPARE consulta_12(int) AS
WITH intercorrencias AS (
    SELECT id_idoso, count(*) AS qtd, max(data_hora) AS ultima
      FROM intercorrencia
     WHERE data_hora >= now() - make_interval(days => $1::int)
     GROUP BY id_idoso
), recados AS (
    SELECT id_idoso, count(*) AS qtd, max(data_hora) AS ultimo
      FROM recado_plantao
     WHERE id_idoso IS NOT NULL
       AND data_hora >= now() - make_interval(days => $1::int)
     GROUP BY id_idoso
)
SELECT i.nome                              AS residente,
       COALESCE(ic.qtd, 0)                 AS intercorrencias,
       COALESCE(rp.qtd, 0)                 AS recados_plantao,
       to_char(ic.ultima, 'DD/MM HH24:MI') AS ultima_intercorrencia,
       to_char(rp.ultimo, 'DD/MM HH24:MI') AS ultimo_recado,
       CASE
           WHEN rp.id_idoso IS NULL THEN 'Intercorrência sem recado no plantão'
           WHEN ic.id_idoso IS NULL THEN 'Recado sem intercorrência registrada'
           ELSE 'Registrado nos dois'
       END                                 AS situacao
  FROM intercorrencias ic
  FULL OUTER JOIN recados rp ON rp.id_idoso = ic.id_idoso
  JOIN idoso i ON i.id_idoso = COALESCE(ic.id_idoso, rp.id_idoso)
 ORDER BY situacao, i.nome;
EXECUTE consulta_12(30);

-- ------------------------------------------------------------
-- 13) Dor acima da média da própria ILPI
--    Pergunta: Quem está relatando mais dor que os colegas da mesma casa?
--    Técnicas: subconsulta correlacionada no SELECT, subconsulta no HAVING, AVG, parâmetro $1
--    Gráfico na interface: barras de dor_media_residente por residente
--    Parâmetro $1: período em dias (na tela: 30, 60, 90; padrão 30)
-- ------------------------------------------------------------
PREPARE consulta_13(int) AS
SELECT i.nome                   AS residente,
       count(*)                 AS checkins,
       round(avg(r.dor), 2)     AS dor_media_residente,
       (SELECT round(avg(r2.dor), 2)
          FROM registro_bem_estar r2
          JOIN idoso i2 ON i2.id_idoso = r2.id_idoso
         WHERE i2.id_ilpi = i.id_ilpi
           AND i2.ativo
           AND r2.data_hora >= now() - make_interval(days => $1::int)) AS dor_media_ilpi
  FROM idoso i
  JOIN registro_bem_estar r ON r.id_idoso = i.id_idoso
 WHERE i.ativo
   AND r.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY i.id_idoso, i.nome, i.id_ilpi
HAVING avg(r.dor) > (SELECT avg(r2.dor)
                       FROM registro_bem_estar r2
                       JOIN idoso i2 ON i2.id_idoso = r2.id_idoso
                      WHERE i2.id_ilpi = i.id_ilpi
                        AND i2.ativo
                        AND r2.data_hora >= now() - make_interval(days => $1::int))
 ORDER BY dor_media_residente DESC, i.nome;
EXECUTE consulta_13(30);

-- ------------------------------------------------------------
-- 14) Agenda de revisão do plano de cuidado
--    Pergunta: Quais metas ativas precisam ser revisadas em breve, e quando tiveram evolução?
--    Técnicas: subconsultas escalares correlacionadas, IN (subconsulta), índice parcial, parâmetros $1 e $2
--    Gráfico na interface: pizza com a contagem de linhas por categoria
--    Parâmetro $1: período em dias (na tela: 7, 15, 30; padrão 15)
--    Parâmetro $2: categoria da meta (na tela: todas, saude, mobilidade, nutricao, social, cognitiva, emocional, autonomia; padrão todas)
-- ------------------------------------------------------------
PREPARE consulta_14(int, text) AS
SELECT i.nome                                AS residente,
       m.categoria,
       m.descricao                           AS meta,
       pr.nome                               AS responsavel_meta,
       to_char(m.data_revisao, 'DD/MM/YYYY') AS data_revisao,
       m.data_revisao - CURRENT_DATE         AS dias_para_revisao,
       (SELECT to_char(max(e.data_hora), 'DD/MM/YYYY')
          FROM evolucao_meta e
         WHERE e.id_meta = m.id_meta)        AS ultima_evolucao,
       (SELECT count(*)
          FROM evolucao_meta e
         WHERE e.id_meta = m.id_meta)        AS qtd_evolucoes
  FROM meta_cuidado m
  JOIN idoso i         ON i.id_idoso = m.id_idoso
  JOIN profissional pr ON pr.id_profissional = m.id_profissional
 WHERE m.status = 'ativa'
   AND m.data_revisao <= CURRENT_DATE + $1::int
   AND m.id_profissional IN (SELECT id_profissional FROM profissional WHERE ativo)
   AND i.ativo
   AND ($2::text = 'todas' OR m.categoria::text = $2::text)
 ORDER BY m.data_revisao, i.nome;
EXECUTE consulta_14(15, 'todas');

-- ------------------------------------------------------------
-- 15) Visão: mapa de medicação
--    Pergunta: Cada prescrição ativa, quem prescreveu, a última dose e as doses da semana (vw_mapa_medicacao).
--    Técnicas: VISÃO com 4 JOINs + LEFT JOIN, FILTER, parâmetro $1
--    Gráfico na interface: barras de adesao_semana_pct por residente_medicamento
--    Parâmetro $1: mostrar (na tela: abaixo, todas; padrão abaixo)
-- ------------------------------------------------------------
PREPARE consulta_15(text) AS
SELECT residente || ' · ' || medicamento AS residente_medicamento,
       dose,
       horarios,
       prescrito_por,
       to_char(ultima_dose, 'DD/MM HH24:MI') AS ultima_dose,
       doses_dadas_semana,
       doses_previstas_semana,
       round(100.0 * doses_dadas_semana / NULLIF(doses_previstas_semana, 0), 1) AS adesao_semana_pct
  FROM vw_mapa_medicacao
 WHERE $1::text = 'todas' OR doses_dadas_semana < doses_previstas_semana
 ORDER BY adesao_semana_pct NULLS LAST, residente, medicamento;
EXECUTE consulta_15('abaixo');

-- ------------------------------------------------------------
-- 16) Visão: intercorrências e quem avisar
--    Pergunta: O que aconteceu, se a família já sabe e para quem ligar (vw_intercorrencia_contato).
--    Técnicas: VISÃO com 3 JOINs + 2 LEFT JOINs, parâmetros $1 e $2
--    Gráfico na interface: pizza com a contagem de linhas por tipo
--    Parâmetro $1: período em dias (na tela: 7, 30, 90; padrão 30)
--    Parâmetro $2: família (na tela: nao_avisada, todas; padrão nao_avisada)
-- ------------------------------------------------------------
PREPARE consulta_16(int, text) AS
SELECT to_char(data_hora, 'DD/MM HH24:MI') AS quando,
       residente,
       tipo,
       gravidade,
       registrado_por,
       CASE WHEN familia_avisada THEN 'sim' ELSE 'não' END AS familia_avisada,
       responsavel_legal,
       parentesco,
       telefone_responsavel
  FROM vw_intercorrencia_contato
 WHERE data_hora >= now() - make_interval(days => $1::int)
   AND ($2::text = 'todas' OR NOT familia_avisada)
 ORDER BY gravidade DESC, data_hora DESC;
EXECUTE consulta_16(30, 'nao_avisada');
