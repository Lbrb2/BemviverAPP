// ============================================================
// Consultas analíticas exibidas na tela "📊 Consultas" do gestor.
// Este arquivo é a FONTE ÚNICA: a API executa estes SQLs e o arquivo
// consultas_etapa03.sql é gerado a partir daqui (node gerar_sql_consultas.js),
// então o que o professor lê é exatamente o que a interface roda.
//
// Parâmetro: as consultas com "periodo" recebem $1 = nº de dias da janela
// (escolhido na tela entre as "opcoes"). A API passa o valor separado do
// SQL — c.query(sql, [dias]) —, nunca concatenado no texto.
//
// Executadas via comUsuario(): o RLS recorta tudo para a ILPI de quem
// está logado. Rodadas como superusuário no psql, mostram todas as ILPIs.
// ============================================================

// Grupos da tela, na ordem em que aparecem
export const GRUPOS = [
  ["bem_estar", "Bem-estar"],
  ["saude", "Saúde e medicação"],
  ["ocorrencias", "Ocorrências e comunicação"],
  ["rotina", "Rotina, convivência e plano de cuidado"],
];

export const CONSULTAS = [
  {
    id: 1,
    grupo: "bem_estar",
    titulo: "Bem-estar médio por residente",
    pergunta: "Como cada residente tem se sentido no período?",
    tecnicas: ["INNER JOIN", "GROUP BY", "AVG", "STDDEV_SAMP", "parâmetro $1"],
    periodo: { padrao: 30, opcoes: [7, 30, 90] },
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
   AND r.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY i.id_idoso, i.nome
 ORDER BY humor_medio DESC, i.nome`,
  },
  {
    id: 2,
    grupo: "bem_estar",
    titulo: "Residentes sem check-in há mais de 3 dias",
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
    grupo: "bem_estar",
    titulo: "Níveis de dor relatados",
    pergunta: "Com que frequência aparece cada nível de dor (0 a 10)?",
    tecnicas: ["generate_series", "LEFT JOIN", "função de janela SUM() OVER ()", "parâmetro $1"],
    periodo: { padrao: 30, opcoes: [7, 30, 90] },
    grafico: { tipo: "barras", x: "nivel_dor", y: ["frequencia"], rotulo: "Nº de registros por nível de dor" },
    sql: `SELECT n.nivel                         AS nivel_dor,
       count(r.id_registro)            AS frequencia,
       round(100.0 * count(r.id_registro)
             / NULLIF(sum(count(r.id_registro)) OVER (), 0), 1) AS percentual
  FROM generate_series(0, 10) AS n(nivel)
  LEFT JOIN registro_bem_estar r
         ON r.dor = n.nivel
        AND r.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY n.nivel
 ORDER BY n.nivel`,
  },
  {
    id: 4,
    grupo: "bem_estar",
    titulo: "Humor e dor nas últimas 8 semanas",
    pergunta: "A casa está melhorando ou piorando semana a semana?",
    tecnicas: ["CTE (WITH)", "generate_series de semanas", "LEFT JOIN por intervalo", "função de janela LAG()"],
    grafico: { tipo: "linhas", x: "semana", y: ["humor_medio", "dor_media"],
               rotulo: "Médias por semana (segunda a domingo) — * semana em andamento" },
    // Semanas inteiras, de segunda a domingo: a janela começa na segunda-feira
    // de 7 semanas atrás (e não "8 semanas antes de agora", que cortaria a
    // primeira semana no meio). Semanas sem registro aparecem vazias.
    sql: `WITH semanas AS (
    SELECT generate_series(date_trunc('week', now()) - INTERVAL '7 weeks',
                           date_trunc('week', now()),
                           INTERVAL '1 week') AS inicio
), medias AS (
    SELECT s.inicio,
           round(avg(r.humor), 2)      AS humor_medio,
           round(avg(r.dor), 2)        AS dor_media,
           count(r.id_registro)        AS registros
      FROM semanas s
      LEFT JOIN registro_bem_estar r
             ON r.data_hora >= s.inicio
            AND r.data_hora <  s.inicio + INTERVAL '1 week'
     GROUP BY s.inicio
)
SELECT to_char(inicio, 'DD/MM')
       || CASE WHEN inicio = date_trunc('week', now()) THEN '*' ELSE '' END AS semana,
       humor_medio,
       humor_medio - lag(humor_medio) OVER (ORDER BY inicio) AS variacao_humor,
       dor_media,
       dor_media - lag(dor_media) OVER (ORDER BY inicio)     AS variacao_dor,
       registros
  FROM medias
 ORDER BY inicio`,
  },
  {
    id: 5,
    grupo: "rotina",
    titulo: "Aceitação alimentar por grau de dependência",
    pergunta: "Residentes mais dependentes estão comendo menos?",
    tecnicas: ["INNER JOIN", "GROUP BY", "COUNT ... FILTER", "AVG", "parâmetro $1"],
    periodo: { padrao: 30, opcoes: [7, 30, 90] },
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
   AND rf.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY i.grau_dependencia
 ORDER BY i.grau_dependencia`,
  },
  {
    id: 6,
    grupo: "ocorrencias",
    titulo: "Intercorrências por tipo e gravidade",
    pergunta: "Que tipo de ocorrência mais acontece e quão grave ela é?",
    tecnicas: ["GROUP BY", "COUNT ... FILTER", "porcentagem com agregação", "parâmetro $1"],
    periodo: { padrao: 90, opcoes: [30, 90, 180] },
    grafico: { tipo: "barras", x: "tipo", y: ["total"], rotulo: "Nº de intercorrências" },
    sql: `SELECT ic.tipo::text                   AS tipo,
       count(*)                        AS total,
       count(*) FILTER (WHERE ic.gravidade = 'leve')     AS leves,
       count(*) FILTER (WHERE ic.gravidade = 'moderada') AS moderadas,
       count(*) FILTER (WHERE ic.gravidade = 'grave')    AS graves,
       round(100.0 * count(*) FILTER (WHERE ic.familia_avisada) / count(*), 0) AS pct_familia_avisada
  FROM intercorrencia ic
 WHERE ic.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY ic.tipo
 ORDER BY total DESC`,
  },
  {
    id: 7,
    grupo: "saude",
    titulo: "Adesão à medicação",
    pergunta: "Das doses que deveriam ter sido dadas, quantas foram registradas?",
    tecnicas: ["CTE (WITH)", "CROSS JOIN LATERAL unnest(array)", "generate_series", "LEFT JOIN", "parâmetro $1"],
    periodo: { padrao: 7, opcoes: [7, 30, 90] },
    grafico: { tipo: "barras", x: "residente", y: ["adesao_pct"], max: 100, rotulo: "Adesão (%)", alerta_abaixo: 90 },
    // Conta os dias completos (ontem para trás). A prescrição vale de
    // "inicio" até "fim": não se filtra por "ativo", senão encerrar uma
    // prescrição hoje apagaria as doses que eram devidas nos dias anteriores.
    sql: `WITH previstas AS (
    SELECT p.id_prescricao, p.id_idoso,
           (d::date + h)               AS horario
      FROM prescricao p
     CROSS JOIN LATERAL unnest(p.horarios) AS h
     CROSS JOIN generate_series(CURRENT_DATE - $1::int, CURRENT_DATE - 1, INTERVAL '1 day') AS d
     WHERE d::date BETWEEN p.inicio AND COALESCE(p.fim, CURRENT_DATE)
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
    grupo: "rotina",
    titulo: "Quem está mais ativo (check-ins, atividades e Xodó)",
    pergunta: "Quem está mais ativo — e quem está se isolando?",
    tecnicas: ["4 CTEs", "LEFT JOIN múltiplo", "funções de janela RANK(), PERCENT_RANK() e MAX() OVER ()", "parâmetro $1"],
    periodo: { padrao: 30, opcoes: [7, 30, 90] },
    grafico: { tipo: "barras", x: "residente", y: ["indice_engajamento"], max: 100,
               rotulo: "Índice de engajamento (0 a 100)", alerta_abaixo: 25 },
    // Índice = 40% check-ins + 40% atividades + 20% pontos do Xodó, cada um
    // dividido pelo maior valor da casa no período (0 a 1). Os pontos pesam
    // menos porque já nascem, em parte, dos próprios check-ins e atividades.
    // Quartil pela posição relativa (PERCENT_RANK): empatados ficam no mesmo
    // quartil; 1 = quarto da casa menos engajado.
    sql: `WITH pontos AS (
    SELECT pv.id_idoso, sum(e.pontos_ganhos) AS pontos
      FROM pet_virtual pv
      JOIN evento_pet e ON e.id_pet = pv.id_pet
     WHERE e.data_hora >= now() - make_interval(days => $1::int)
     GROUP BY pv.id_idoso
), lazer AS (
    SELECT p.id_idoso, count(*) AS atividades
      FROM participacao p
      JOIN atividade_lazer a ON a.id_atividade = p.id_atividade
     WHERE a.data_hora >= now() - make_interval(days => $1::int)
       AND a.data_hora <= now()
     GROUP BY p.id_idoso
), checkins AS (
    SELECT id_idoso, count(*) AS checkins
      FROM registro_bem_estar
     WHERE data_hora >= now() - make_interval(days => $1::int)
     GROUP BY id_idoso
), base AS (
    SELECT i.nome                      AS residente,
           pv.nome                     AS xodo,
           COALESCE(c.checkins, 0)     AS checkins,
           COALESCE(l.atividades, 0)   AS atividades,
           COALESCE(pt.pontos, 0)      AS pontos_xodo
      FROM idoso i
      LEFT JOIN pet_virtual pv ON pv.id_idoso = i.id_idoso
      LEFT JOIN pontos   pt ON pt.id_idoso = i.id_idoso
      LEFT JOIN lazer    l  ON l.id_idoso  = i.id_idoso
      LEFT JOIN checkins c  ON c.id_idoso  = i.id_idoso
     WHERE i.ativo
), indice AS (
    SELECT residente, xodo, checkins, atividades, pontos_xodo,
           round(100 * (
               0.4 * COALESCE(checkins    / NULLIF(max(checkins)    OVER (), 0)::numeric, 0)
             + 0.4 * COALESCE(atividades  / NULLIF(max(atividades)  OVER (), 0)::numeric, 0)
             + 0.2 * COALESCE(pontos_xodo / NULLIF(max(pontos_xodo) OVER (), 0)::numeric, 0)
           ), 1)                       AS indice_engajamento
      FROM base
)
SELECT rank() OVER (ORDER BY indice_engajamento DESC) AS posicao,
       residente,
       xodo,
       indice_engajamento,
       LEAST(4, 1 + floor(4 * percent_rank() OVER (ORDER BY indice_engajamento)))::int AS quartil,
       checkins,
       atividades,
       pontos_xodo
  FROM indice
 ORDER BY posicao, residente`,
  },
  {
    id: 9,
    grupo: "rotina",
    titulo: "Quem parou de jogar dominó com os colegas",
    pergunta: "Quem não sentou à mesa com nenhum colega no período — e com quem costumava jogar?",
    tecnicas: ["CTE com UNION ALL", "NOT EXISTS", "auto-junção (idoso × idoso)", "DISTINCT ON", "parâmetro $1"],
    periodo: { padrao: 14, opcoes: [7, 14, 30] },
    grafico: { tipo: "barras", x: "residente", y: ["dias_sem_jogar_a_dois"], sem_nulos: true,
               rotulo: "Dias desde a última partida com um colega (quem nunca jogou a dois está só na tabela)", alerta: 21 },
    // "duplas" vê cada partida entre dois idosos pelos dois lados, para que
    // jogador1 e jogador2 sejam tratados igualmente. O parceiro mais frequente
    // vem da junção de idoso com ele mesmo (o residente e o colega de mesa).
    // Primeiro vem quem tinha o hábito e parou (o sinal mais forte de
    // isolamento); depois, quem nunca jogou com um colega.
    sql: `WITH duplas AS (
    SELECT id_jogador1 AS id_idoso, id_jogador2 AS id_parceiro, data_hora
      FROM partida_domino WHERE id_jogador2 IS NOT NULL
    UNION ALL
    SELECT id_jogador2, id_jogador1, data_hora
      FROM partida_domino WHERE id_jogador2 IS NOT NULL
), parceiro_frequente AS (
    SELECT DISTINCT ON (eu.id_idoso)
           eu.id_idoso, colega.nome AS parceiro, count(*) AS partidas_juntos
      FROM duplas d
      JOIN idoso eu     ON eu.id_idoso     = d.id_idoso
      JOIN idoso colega ON colega.id_idoso = d.id_parceiro
     GROUP BY eu.id_idoso, colega.id_idoso, colega.nome
     ORDER BY eu.id_idoso, count(*) DESC, colega.nome
)
SELECT i.nome                          AS residente,
       CASE WHEN max(d.data_hora) IS NULL THEN 'nunca jogou a dois'
            ELSE 'parou de jogar a dois' END AS situacao,
       to_char(max(d.data_hora), 'DD/MM/YYYY') AS ultima_partida_a_dois,
       CURRENT_DATE - max(d.data_hora)::date  AS dias_sem_jogar_a_dois,
       pf.parceiro                     AS parceiro_mais_frequente,
       pf.partidas_juntos
  FROM idoso i
  LEFT JOIN duplas d              ON d.id_idoso  = i.id_idoso
  LEFT JOIN parceiro_frequente pf ON pf.id_idoso = i.id_idoso
 WHERE i.ativo
   AND NOT EXISTS (SELECT 1 FROM duplas recente
                    WHERE recente.id_idoso = i.id_idoso
                      AND recente.data_hora >= now() - make_interval(days => $1::int))
 GROUP BY i.id_idoso, i.nome, pf.parceiro, pf.partidas_juntos
 ORDER BY dias_sem_jogar_a_dois DESC NULLS LAST, residente`,
  },
  {
    id: 10,
    grupo: "ocorrencias",
    titulo: "Quedas recorrentes",
    pergunta: "Quem caiu duas vezes ou mais — e o plano de cuidado já trata da mobilidade?",
    tecnicas: ["INNER JOIN", "GROUP BY + HAVING", "subconsulta escalar", "EXISTS", "CASE", "parâmetro $1"],
    periodo: { padrao: 90, opcoes: [30, 90, 180] },
    grafico: { tipo: "barras", x: "residente", y: ["quedas"], rotulo: "Quedas no período", alerta: 3 },
    sql: `SELECT i.nome                          AS residente,
       'Grau ' || i.grau_dependencia   AS grau_dependencia,
       count(*)                        AS quedas,
       count(*) FILTER (WHERE ic.gravidade <> 'leve') AS moderadas_ou_graves,
       to_char(max(ic.data_hora), 'DD/MM/YYYY')       AS ultima_queda,
       string_agg(DISTINCT ic.local_evento, ', ')     AS locais,
       round(100.0 * count(*) / (SELECT count(*)
                                   FROM intercorrencia q
                                  WHERE q.tipo = 'queda'
                                    AND q.data_hora >= now() - make_interval(days => $1::int)), 1)
                                       AS pct_das_quedas_da_casa,
       CASE WHEN EXISTS (SELECT 1 FROM meta_cuidado m
                          WHERE m.id_idoso = i.id_idoso
                            AND m.categoria = 'mobilidade'
                            AND m.status = 'ativa')
            THEN 'sim' ELSE 'NÃO — revisar plano' END AS meta_de_mobilidade_ativa
  FROM intercorrencia ic
  JOIN idoso i ON i.id_idoso = ic.id_idoso
 WHERE ic.tipo = 'queda'
   AND ic.data_hora >= now() - make_interval(days => $1::int)
   AND i.ativo
 GROUP BY i.id_idoso, i.nome, i.grau_dependencia
HAVING count(*) >= 2
 ORDER BY quedas DESC, residente`,
  },
  // ------------------------------------------------------------------
  // ETAPA 04 — consultas avançadas (11 a 14) e as duas visões (15 e 16).
  // Mesma lógica de entregas_bd/etapa04/etapa04_consultas.sql, aqui com
  // período e filtro como parâmetros ($1, $2) escolhidos na tela.
  // "filtro" só aceita os valores listados em "opcoes" (a API confere).
  // ------------------------------------------------------------------
  {
    id: 11,
    grupo: "saude",
    etapa: 4,
    titulo: "Residentes sem aferição de sinais vitais",
    pergunta: "Quem está há dias sem ter pressão, saturação ou temperatura medidas?",
    tecnicas: ["ANTI JOIN (LEFT JOIN + IS NULL)", "filtro no ON", "parâmetros $1 e $2"],
    periodo: { padrao: 7, opcoes: [3, 7, 15], rotulo: "Sem aferição nos últimos" },
    filtro: { rotulo: "Grau de dependência", padrao: "todos",
              opcoes: [["todos", "Todos"], ["I", "Grau I"], ["II", "Grau II"], ["III", "Grau III"]] },
    grafico: { tipo: "pizza", contar: "grau_dependencia", rotulo: "Residentes sem aferição, por grau de dependência" },
    sql: `SELECT i.nome                   AS residente,
       'Grau ' || i.grau_dependencia AS grau_dependencia,
       to_char(i.data_admissao, 'DD/MM/YYYY') AS admitido_em
  FROM idoso i
  LEFT JOIN sinal_vital s
         ON s.id_idoso = i.id_idoso
        AND s.data_hora >= now() - make_interval(days => $1::int)
 WHERE i.ativo
   AND s.id_sinal IS NULL
   AND ($2::text = 'todos' OR i.grau_dependencia::text = $2::text)
 ORDER BY i.grau_dependencia DESC, i.nome`,
  },
  {
    id: 12,
    grupo: "ocorrencias",
    etapa: 4,
    titulo: "Intercorrências × recados de plantão",
    pergunta: "A passagem de plantão está acompanhando o que acontece com os residentes?",
    tecnicas: ["FULL OUTER JOIN", "CTE", "COALESCE", "CASE", "parâmetro $1"],
    periodo: { padrao: 30, opcoes: [30, 60, 90] },
    grafico: { tipo: "pizza", contar: "situacao", rotulo: "Residentes por situação do registro" },
    sql: `WITH intercorrencias AS (
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
 ORDER BY situacao, i.nome`,
  },
  {
    id: 13,
    grupo: "bem_estar",
    etapa: 4,
    titulo: "Dor acima da média da própria ILPI",
    pergunta: "Quem está relatando mais dor que os colegas da mesma casa?",
    tecnicas: ["subconsulta correlacionada no SELECT", "subconsulta no HAVING", "AVG", "parâmetro $1"],
    periodo: { padrao: 30, opcoes: [30, 60, 90] },
    grafico: { tipo: "barras", x: "residente", y: ["dor_media_residente"], max: 10, ref: "dor_media_ilpi",
               rotulo: "Dor média do residente (0 a 10) — a linha tracejada é a média da ILPI" },
    sql: `SELECT i.nome                   AS residente,
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
 ORDER BY dor_media_residente DESC, i.nome`,
  },
  {
    id: 14,
    grupo: "rotina",
    etapa: 4,
    titulo: "Agenda de revisão do plano de cuidado",
    pergunta: "Quais metas ativas precisam ser revisadas em breve, e quando tiveram evolução?",
    tecnicas: ["subconsultas escalares correlacionadas", "IN (subconsulta)", "índice parcial", "parâmetros $1 e $2"],
    periodo: { padrao: 15, opcoes: [7, 15, 30], rotulo: "Revisão nos próximos" },
    filtro: { rotulo: "Categoria da meta", padrao: "todas",
              opcoes: [["todas", "Todas"], ["saude", "Saúde"], ["mobilidade", "Mobilidade"], ["nutricao", "Nutrição"],
                       ["social", "Social"], ["cognitiva", "Cognitiva"], ["emocional", "Emocional"], ["autonomia", "Autonomia"]] },
    grafico: { tipo: "pizza", contar: "categoria", rotulo: "Metas a revisar, por categoria" },
    sql: `SELECT i.nome                                AS residente,
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
 ORDER BY m.data_revisao, i.nome`,
  },
  {
    id: 15,
    grupo: "saude",
    etapa: 4,
    visao: true,
    titulo: "Mapa de medicação da semana",
    pergunta: "Cada remédio em uso, quem prescreveu, a última dose e quantas doses foram dadas na semana.",
    tecnicas: ["VISÃO com 4 JOINs + LEFT JOIN", "FILTER", "parâmetro $1"],
    filtro: { rotulo: "Mostrar", padrao: "abaixo",
              opcoes: [["abaixo", "Só abaixo do previsto"], ["todas", "Todas as prescrições"]] },
    grafico: { tipo: "barras", x: "residente_medicamento", y: ["adesao_semana_pct"], max: 100, alerta_abaixo: 90,
               rotulo: "Doses dadas na semana, em % das previstas" },
    sql: `SELECT residente || ' · ' || medicamento AS residente_medicamento,
       dose,
       horarios,
       prescrito_por,
       to_char(ultima_dose, 'DD/MM HH24:MI') AS ultima_dose,
       doses_dadas_semana,
       doses_previstas_semana,
       round(100.0 * doses_dadas_semana / NULLIF(doses_previstas_semana, 0), 1) AS adesao_semana_pct
  FROM vw_mapa_medicacao
 WHERE $1::text = 'todas' OR doses_dadas_semana < doses_previstas_semana
 ORDER BY adesao_semana_pct NULLS LAST, residente, medicamento`,
  },
  {
    id: 16,
    grupo: "ocorrencias",
    etapa: 4,
    visao: true,
    titulo: "Intercorrências e quem avisar",
    pergunta: "O que aconteceu, se a família já sabe e para quem ligar.",
    tecnicas: ["VISÃO com 3 JOINs + 2 LEFT JOINs", "parâmetros $1 e $2"],
    periodo: { padrao: 30, opcoes: [7, 30, 90] },
    filtro: { rotulo: "Família", padrao: "nao_avisada",
              opcoes: [["nao_avisada", "Ainda não avisada"], ["todas", "Todas as intercorrências"]] },
    grafico: { tipo: "pizza", contar: "tipo", rotulo: "Intercorrências por tipo" },
    sql: `SELECT to_char(data_hora, 'DD/MM HH24:MI') AS quando,
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
 ORDER BY gravidade DESC, data_hora DESC`,
  },
];
