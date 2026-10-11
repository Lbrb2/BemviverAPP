// ============================================================
// Consultas analíticas exibidas na tela "📊 Consultas" do gestor.
// Este arquivo é a FONTE ÚNICA: a API executa estes SQLs e o arquivo
// consultas_etapa03.sql é gerado a partir daqui (node gerar_sql_consultas.js),
// então o que o professor lê é exatamente o que a interface roda.
//
// Executadas via comUsuario(): o RLS recorta tudo para a ILPI de quem
// está logado. Rodadas como superusuário no psql, mostram todas as ILPIs.
// ============================================================

export const CONSULTAS = [
  {
    id: 1,
    titulo: "Bem-estar médio por residente (30 dias)",
    pergunta: "Como cada residente tem se sentido no último mês?",
    tecnicas: ["INNER JOIN", "GROUP BY", "AVG", "STDDEV_SAMP"],
    grafico: { tipo: "barras", x: "residente", y: ["humor_medio"], max: 5, rotulo: "Humor médio (1 a 5)" },
    sql: `SELECT i.nome                          AS residente,
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
 ORDER BY humor_medio DESC, i.nome`,
  },
  {
    id: 2,
    titulo: "Alerta: residentes sem check-in há mais de 3 dias",
    pergunta: "Quem a equipe precisa procurar hoje?",
    tecnicas: ["LEFT JOIN", "HAVING", "COALESCE", "MAX"],
    grafico: { tipo: "barras", x: "residente", y: ["dias_sem_checkin"], rotulo: "Dias sem check-in", alerta: 7 },
    sql: `SELECT i.nome                          AS residente,
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
 ORDER BY dias_sem_checkin DESC`,
  },
  {
    id: 3,
    titulo: "Distribuição da dor relatada (histograma)",
    pergunta: "Com que frequência aparece cada nível de dor (0 a 10)?",
    tecnicas: ["generate_series", "LEFT JOIN", "função de janela SUM() OVER ()"],
    grafico: { tipo: "barras", x: "nivel_dor", y: ["frequencia"], rotulo: "Nº de registros por nível de dor" },
    sql: `SELECT n.nivel                         AS nivel_dor,
       count(r.id_registro)            AS frequencia,
       round(100.0 * count(r.id_registro)
             / NULLIF(sum(count(r.id_registro)) OVER (), 0), 1) AS percentual
  FROM generate_series(0, 10) AS n(nivel)
  LEFT JOIN registro_bem_estar r
         ON r.dor = n.nivel
        AND r.data_hora >= now() - INTERVAL '30 days'
 GROUP BY n.nivel
 ORDER BY n.nivel`,
  },
  {
    id: 4,
    titulo: "Evolução semanal do humor e da dor",
    pergunta: "A casa está melhorando ou piorando semana a semana?",
    tecnicas: ["date_trunc", "GROUP BY por período", "AVG"],
    grafico: { tipo: "linhas", x: "semana", y: ["humor_medio", "dor_media"], rotulo: "Médias semanais" },
    sql: `SELECT to_char(date_trunc('week', r.data_hora), 'DD/MM') AS semana,
       round(avg(r.humor), 2)          AS humor_medio,
       round(avg(r.dor), 2)            AS dor_media,
       count(*)                        AS registros
  FROM registro_bem_estar r
 WHERE r.data_hora >= now() - INTERVAL '8 weeks'
 GROUP BY date_trunc('week', r.data_hora)
 ORDER BY date_trunc('week', r.data_hora)`,
  },
  {
    id: 5,
    titulo: "Aceitação alimentar por grau de dependência",
    pergunta: "Residentes mais dependentes estão comendo menos?",
    tecnicas: ["INNER JOIN", "GROUP BY", "COUNT ... FILTER", "AVG"],
    grafico: { tipo: "barras", x: "grau_dependencia", y: ["aceitacao_media"], max: 100, rotulo: "Aceitação média (%)" },
    sql: `SELECT 'Grau ' || i.grau_dependencia   AS grau_dependencia,
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
 ORDER BY i.grau_dependencia`,
  },
  {
    id: 6,
    titulo: "Intercorrências por tipo e gravidade (90 dias)",
    pergunta: "Que tipo de ocorrência mais acontece e quão grave ela é?",
    tecnicas: ["GROUP BY", "COUNT ... FILTER", "porcentagem com agregação"],
    grafico: { tipo: "barras", x: "tipo", y: ["total"], rotulo: "Nº de intercorrências" },
    sql: `SELECT ic.tipo::text                   AS tipo,
       count(*)                        AS total,
       count(*) FILTER (WHERE ic.gravidade = 'leve')     AS leves,
       count(*) FILTER (WHERE ic.gravidade = 'moderada') AS moderadas,
       count(*) FILTER (WHERE ic.gravidade = 'grave')    AS graves,
       round(100.0 * count(*) FILTER (WHERE ic.familia_avisada) / count(*), 0) AS pct_familia_avisada
  FROM intercorrencia ic
 WHERE ic.data_hora >= now() - INTERVAL '90 days'
 GROUP BY ic.tipo
 ORDER BY total DESC`,
  },
  {
    id: 7,
    titulo: "Adesão à medicação (7 últimos dias completos)",
    pergunta: "Das doses que deveriam ter sido dadas, quantas foram registradas?",
    tecnicas: ["CTE (WITH)", "CROSS JOIN LATERAL unnest(array)", "generate_series", "LEFT JOIN"],
    grafico: { tipo: "barras", x: "residente", y: ["adesao_pct"], max: 100, rotulo: "Adesão (%)", alerta_abaixo: 90 },
    sql: `WITH previstas AS (
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
 ORDER BY adesao_pct, residente`,
  },
  {
    id: 8,
    titulo: "Ranking de engajamento (Xodó, lazer e check-ins)",
    pergunta: "Quem está mais ativo — e quem está se isolando?",
    tecnicas: ["3 CTEs", "LEFT JOIN múltiplo", "função de janela RANK()"],
    grafico: { tipo: "barras", x: "residente", y: ["pontos_xodo_30d"], rotulo: "Pontos do Xodó em 30 dias" },
    sql: `WITH pontos AS (
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
 ORDER BY posicao, residente`,
  },
];
