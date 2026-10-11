-- ============================================================
-- Bem Viver ILPI — Consultas implementadas na interface (Etapa 03)
-- Arquivo GERADO a partir de api/consultas.js: são exatamente os SQLs
-- que a tela "📊 Consultas" do gestor executa.
--
-- Na aplicação, cada consulta roda dentro de uma transação com a
-- identidade do usuário (set_config('app.id_usuario', ...)), e o RLS
-- limita o resultado à ILPI do gestor. Rodando aqui como superusuário,
-- o resultado inclui todas as ILPIs.
-- Executar após schema_ilpi.sql e seed_ilpi.sql.
-- ============================================================

-- Horários de medicação são hora local de Pernambuco (a API faz o mesmo).
SET TIME ZONE 'America/Recife';

-- ------------------------------------------------------------
-- 1) Bem-estar médio por residente (30 dias)
--    Pergunta: Como cada residente tem se sentido no último mês?
--    Técnicas: INNER JOIN, GROUP BY, AVG, STDDEV_SAMP
--    Gráfico na interface: barras de humor_medio por residente
-- ------------------------------------------------------------
SELECT i.nome                          AS residente,
       count(r.id_registro)            AS registros,
       round(avg(r.humor), 2)          AS humor_medio,
       round(avg(r.conforto), 2)       AS conforto_medio,
       round(avg(r.dor), 2)            AS dor_media,
       round(stddev_samp(r.dor), 2)    AS desvio_padrao_dor
  FROM idoso i
  JOIN registro_bem_estar r ON r.id_idoso = i.id_idoso
 WHERE i.ativo
   AND r.data_hora >= now() - INTERVAL '30 days'
 GROUP BY i.id_idoso, i.nome
 ORDER BY humor_medio DESC, i.nome;

-- ------------------------------------------------------------
-- 2) Alerta: residentes sem check-in há mais de 3 dias
--    Pergunta: Quem a equipe precisa procurar hoje?
--    Técnicas: LEFT JOIN, HAVING, COALESCE, MAX
--    Gráfico na interface: barras de dias_sem_checkin por residente
-- ------------------------------------------------------------
SELECT i.nome                          AS residente,
       il.nome                         AS ilpi,
       to_char(max(r.data_hora), 'DD/MM HH24:MI') AS ultimo_checkin,
       COALESCE(
           extract(day FROM now() - max(r.data_hora))::int,
           (CURRENT_DATE - i.data_admissao)
       )                               AS dias_sem_checkin
  FROM idoso i
  JOIN ilpi il ON il.id_ilpi = i.id_ilpi
  LEFT JOIN registro_bem_estar r ON r.id_idoso = i.id_idoso
 WHERE i.ativo
 GROUP BY i.id_idoso, i.nome, il.nome, i.data_admissao
HAVING max(r.data_hora) IS NULL
    OR max(r.data_hora) < now() - INTERVAL '3 days'
 ORDER BY dias_sem_checkin DESC;

-- ------------------------------------------------------------
-- 3) Distribuição da dor relatada (histograma)
--    Pergunta: Com que frequência aparece cada nível de dor (0 a 10)?
--    Técnicas: generate_series, LEFT JOIN, função de janela SUM() OVER ()
--    Gráfico na interface: barras de frequencia por nivel_dor
-- ------------------------------------------------------------
SELECT n.nivel                         AS nivel_dor,
       count(r.id_registro)            AS frequencia,
       round(100.0 * count(r.id_registro)
             / NULLIF(sum(count(r.id_registro)) OVER (), 0), 1) AS percentual
  FROM generate_series(0, 10) AS n(nivel)
  LEFT JOIN registro_bem_estar r
         ON r.dor = n.nivel
        AND r.data_hora >= now() - INTERVAL '30 days'
 GROUP BY n.nivel
 ORDER BY n.nivel;

-- ------------------------------------------------------------
-- 4) Evolução semanal do humor e da dor
--    Pergunta: A casa está melhorando ou piorando semana a semana?
--    Técnicas: date_trunc, GROUP BY por período, AVG
--    Gráfico na interface: linhas de humor_medio e dor_media por semana
-- ------------------------------------------------------------
SELECT to_char(date_trunc('week', r.data_hora), 'DD/MM') AS semana,
       round(avg(r.humor), 2)          AS humor_medio,
       round(avg(r.dor), 2)            AS dor_media,
       count(*)                        AS registros
  FROM registro_bem_estar r
 WHERE r.data_hora >= now() - INTERVAL '8 weeks'
 GROUP BY date_trunc('week', r.data_hora)
 ORDER BY date_trunc('week', r.data_hora);

-- ------------------------------------------------------------
-- 5) Aceitação alimentar por grau de dependência
--    Pergunta: Residentes mais dependentes estão comendo menos?
--    Técnicas: INNER JOIN, GROUP BY, COUNT ... FILTER, AVG
--    Gráfico na interface: barras de aceitacao_media por grau_dependencia
-- ------------------------------------------------------------
SELECT 'Grau ' || i.grau_dependencia   AS grau_dependencia,
       count(DISTINCT i.id_idoso)      AS residentes,
       count(*)                        AS refeicoes,
       round(avg(rf.aceitacao), 1)     AS aceitacao_media,
       count(*) FILTER (WHERE rf.aceitacao < 50) AS refeicoes_baixa_aceitacao,
       round(avg(rf.hidratacao_ml))    AS hidratacao_media_ml
  FROM registro_refeicao rf
  JOIN idoso i ON i.id_idoso = rf.id_idoso
 WHERE i.ativo
   AND rf.data_hora >= now() - INTERVAL '30 days'
 GROUP BY i.grau_dependencia
 ORDER BY i.grau_dependencia;

-- ------------------------------------------------------------
-- 6) Intercorrências por tipo e gravidade (90 dias)
--    Pergunta: Que tipo de ocorrência mais acontece e quão grave ela é?
--    Técnicas: GROUP BY, COUNT ... FILTER, porcentagem com agregação
--    Gráfico na interface: barras de total por tipo
-- ------------------------------------------------------------
SELECT ic.tipo::text                   AS tipo,
       count(*)                        AS total,
       count(*) FILTER (WHERE ic.gravidade = 'leve')     AS leves,
       count(*) FILTER (WHERE ic.gravidade = 'moderada') AS moderadas,
       count(*) FILTER (WHERE ic.gravidade = 'grave')    AS graves,
       round(100.0 * count(*) FILTER (WHERE ic.familia_avisada) / count(*), 0) AS pct_familia_avisada
  FROM intercorrencia ic
 WHERE ic.data_hora >= now() - INTERVAL '90 days'
 GROUP BY ic.tipo
 ORDER BY total DESC;

-- ------------------------------------------------------------
-- 7) Adesão à medicação (7 últimos dias completos)
--    Pergunta: Das doses que deveriam ter sido dadas, quantas foram registradas?
--    Técnicas: CTE (WITH), CROSS JOIN LATERAL unnest(array), generate_series, LEFT JOIN
--    Gráfico na interface: barras de adesao_pct por residente
-- ------------------------------------------------------------
WITH previstas AS (
    SELECT p.id_prescricao, p.id_idoso,
           (d::date + h)               AS horario
      FROM prescricao p
     CROSS JOIN LATERAL unnest(p.horarios) AS h
     CROSS JOIN generate_series(CURRENT_DATE - 7, CURRENT_DATE - 1, INTERVAL '1 day') AS d
     WHERE p.ativo
       AND d::date BETWEEN p.inicio AND COALESCE(p.fim, CURRENT_DATE)
)
SELECT i.nome                          AS residente,
       count(*)                        AS doses_previstas,
       count(a.id_adm)                 AS doses_registradas,
       round(100.0 * count(a.id_adm) / count(*), 1) AS adesao_pct
  FROM previstas pr
  JOIN idoso i ON i.id_idoso = pr.id_idoso
  LEFT JOIN administracao_medicacao a
         ON a.id_prescricao = pr.id_prescricao
        AND a.horario_previsto = pr.horario
 GROUP BY i.id_idoso, i.nome
 ORDER BY adesao_pct, residente;

-- ------------------------------------------------------------
-- 8) Ranking de engajamento (Xodó, lazer e check-ins)
--    Pergunta: Quem está mais ativo — e quem está se isolando?
--    Técnicas: 3 CTEs, LEFT JOIN múltiplo, função de janela RANK()
--    Gráfico na interface: barras de pontos_xodo_30d por residente
-- ------------------------------------------------------------
WITH pontos AS (
    SELECT pv.id_idoso, sum(e.pontos_ganhos) AS pontos
      FROM pet_virtual pv
      JOIN evento_pet e ON e.id_pet = pv.id_pet
     WHERE e.data_hora >= now() - INTERVAL '30 days'
     GROUP BY pv.id_idoso
), lazer AS (
    SELECT p.id_idoso, count(*) AS atividades
      FROM participacao p
      JOIN atividade_lazer a ON a.id_atividade = p.id_atividade
     WHERE a.data_hora >= now() - INTERVAL '30 days'
     GROUP BY p.id_idoso
), checkins AS (
    SELECT id_idoso, count(*) AS checkins
      FROM registro_bem_estar
     WHERE data_hora >= now() - INTERVAL '30 days'
     GROUP BY id_idoso
)
SELECT rank() OVER (ORDER BY COALESCE(pt.pontos, 0) DESC) AS posicao,
       i.nome                          AS residente,
       pv.nome                         AS xodo,
       COALESCE(pt.pontos, 0)          AS pontos_xodo_30d,
       COALESCE(l.atividades, 0)       AS atividades_30d,
       COALESCE(c.checkins, 0)         AS checkins_30d
  FROM idoso i
  LEFT JOIN pet_virtual pv ON pv.id_idoso = i.id_idoso
  LEFT JOIN pontos   pt ON pt.id_idoso = i.id_idoso
  LEFT JOIN lazer    l  ON l.id_idoso  = i.id_idoso
  LEFT JOIN checkins c  ON c.id_idoso  = i.id_idoso
 WHERE i.ativo
 ORDER BY posicao, residente;
