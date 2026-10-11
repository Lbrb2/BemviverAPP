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
--
-- Período como parâmetro: as consultas com janela de tempo usam $1 (nº de
-- dias). Na API, o valor vai separado do SQL — c.query(sql, [dias]) —; aqui
-- o mesmo SQL é preparado (PREPARE) e executado com o período padrão
-- (EXECUTE). Para outro período, basta trocar o número no EXECUTE.
-- ============================================================

-- Horários de medicação são hora local de Pernambuco (a API faz o mesmo).
SET TIME ZONE 'America/Recife';

-- ------------------------------------------------------------
-- 1) Bem-estar médio por residente
--    Pergunta: Como cada residente tem se sentido no período?
--    Técnicas: INNER JOIN, GROUP BY, AVG, STDDEV_SAMP, parâmetro $1
--    Gráfico na interface: barras de humor_medio por residente
--    Parâmetro $1: período em dias (na tela: 7, 30, 90; padrão 30)
-- ------------------------------------------------------------
PREPARE consulta_1(int) AS
SELECT i.nome                          AS residente,
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
 ORDER BY humor_medio DESC, i.nome;
EXECUTE consulta_1(30);

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
--    Técnicas: generate_series, LEFT JOIN, função de janela SUM() OVER (), parâmetro $1
--    Gráfico na interface: barras de frequencia por nivel_dor
--    Parâmetro $1: período em dias (na tela: 7, 30, 90; padrão 30)
-- ------------------------------------------------------------
PREPARE consulta_3(int) AS
SELECT n.nivel                         AS nivel_dor,
       count(r.id_registro)            AS frequencia,
       round(100.0 * count(r.id_registro)
             / NULLIF(sum(count(r.id_registro)) OVER (), 0), 1) AS percentual
  FROM generate_series(0, 10) AS n(nivel)
  LEFT JOIN registro_bem_estar r
         ON r.dor = n.nivel
        AND r.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY n.nivel
 ORDER BY n.nivel;
EXECUTE consulta_3(30);

-- ------------------------------------------------------------
-- 4) Evolução semanal do humor e da dor (8 semanas)
--    Pergunta: A casa está melhorando ou piorando semana a semana?
--    Técnicas: CTE (WITH), generate_series de semanas, LEFT JOIN por intervalo, função de janela LAG()
--    Gráfico na interface: linhas de humor_medio e dor_media por semana
-- ------------------------------------------------------------
WITH semanas AS (
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
 ORDER BY inicio;

-- ------------------------------------------------------------
-- 5) Aceitação alimentar por grau de dependência
--    Pergunta: Residentes mais dependentes estão comendo menos?
--    Técnicas: INNER JOIN, GROUP BY, COUNT ... FILTER, AVG, parâmetro $1
--    Gráfico na interface: barras de aceitacao_media por grau_dependencia
--    Parâmetro $1: período em dias (na tela: 7, 30, 90; padrão 30)
-- ------------------------------------------------------------
PREPARE consulta_5(int) AS
SELECT 'Grau ' || i.grau_dependencia   AS grau_dependencia,
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
 ORDER BY i.grau_dependencia;
EXECUTE consulta_5(30);

-- ------------------------------------------------------------
-- 6) Intercorrências por tipo e gravidade
--    Pergunta: Que tipo de ocorrência mais acontece e quão grave ela é?
--    Técnicas: GROUP BY, COUNT ... FILTER, porcentagem com agregação, parâmetro $1
--    Gráfico na interface: barras de total por tipo
--    Parâmetro $1: período em dias (na tela: 30, 90, 180; padrão 90)
-- ------------------------------------------------------------
PREPARE consulta_6(int) AS
SELECT ic.tipo::text                   AS tipo,
       count(*)                        AS total,
       count(*) FILTER (WHERE ic.gravidade = 'leve')     AS leves,
       count(*) FILTER (WHERE ic.gravidade = 'moderada') AS moderadas,
       count(*) FILTER (WHERE ic.gravidade = 'grave')    AS graves,
       round(100.0 * count(*) FILTER (WHERE ic.familia_avisada) / count(*), 0) AS pct_familia_avisada
  FROM intercorrencia ic
 WHERE ic.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY ic.tipo
 ORDER BY total DESC;
EXECUTE consulta_6(90);

-- ------------------------------------------------------------
-- 7) Adesão à medicação (dias completos)
--    Pergunta: Das doses que deveriam ter sido dadas, quantas foram registradas?
--    Técnicas: CTE (WITH), CROSS JOIN LATERAL unnest(array), generate_series, LEFT JOIN, parâmetro $1
--    Gráfico na interface: barras de adesao_pct por residente
--    Parâmetro $1: período em dias (na tela: 7, 30, 90; padrão 7)
-- ------------------------------------------------------------
PREPARE consulta_7(int) AS
WITH previstas AS (
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
 ORDER BY adesao_pct, residente;
EXECUTE consulta_7(7);

-- ------------------------------------------------------------
-- 8) Ranking de engajamento (check-ins, lazer e Xodó)
--    Pergunta: Quem está mais ativo — e quem está se isolando?
--    Técnicas: 4 CTEs, LEFT JOIN múltiplo, funções de janela RANK(), PERCENT_RANK() e MAX() OVER (), parâmetro $1
--    Gráfico na interface: barras de indice_engajamento por residente
--    Parâmetro $1: período em dias (na tela: 7, 30, 90; padrão 30)
-- ------------------------------------------------------------
PREPARE consulta_8(int) AS
WITH pontos AS (
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
    SELECT *,
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
 ORDER BY posicao, residente;
EXECUTE consulta_8(30);

-- ------------------------------------------------------------
-- 9) Isolamento: quem não joga dominó com outro idoso
--    Pergunta: Quem não sentou à mesa com nenhum colega no período — e com quem costumava jogar?
--    Técnicas: CTE com UNION ALL, NOT EXISTS, auto-junção (idoso × idoso), DISTINCT ON, parâmetro $1
--    Gráfico na interface: barras de dias_sem_jogar_a_dois por residente
--    Parâmetro $1: período em dias (na tela: 7, 14, 30; padrão 14)
-- ------------------------------------------------------------
PREPARE consulta_9(int) AS
WITH duplas AS (
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
 ORDER BY dias_sem_jogar_a_dois DESC NULLS LAST, residente;
EXECUTE consulta_9(14);

-- ------------------------------------------------------------
-- 10) Quedas recorrentes
--    Pergunta: Quem caiu duas vezes ou mais — e o plano de cuidado já trata da mobilidade?
--    Técnicas: INNER JOIN, GROUP BY + HAVING, subconsulta escalar, EXISTS, CASE, parâmetro $1
--    Gráfico na interface: barras de quedas por residente
--    Parâmetro $1: período em dias (na tela: 30, 90, 180; padrão 90)
-- ------------------------------------------------------------
PREPARE consulta_10(int) AS
SELECT i.nome                          AS residente,
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
 ORDER BY quedas DESC, residente;
EXECUTE consulta_10(90);
