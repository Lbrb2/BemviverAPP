-- ============================================================
-- Bem Viver ILPI — SQL do dashboard estatístico (Etapa 06)
-- Arquivo GERADO a partir de api/dashboard.js: são exatamente os comandos
-- que a aba "📈 Dashboard" do gestor executa a cada filtro.
-- Parâmetros: $1 = período em dias (7, 30, 90, 180) e $2 = grau de
-- dependência ('todos', 'I', 'II', 'III'). Aqui: 30 dias e todos.
-- Rodando como superusuário, as funções que dependem do usuário logado
-- (fn_minha_ilpi_profissional) devolvem NULL; na aplicação, o RLS
-- recorta tudo para a ILPI do gestor.
-- ============================================================
SET TIME ZONE 'America/Recife';

-- ---------- indicadores ----------
PREPARE dash_1(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
),
bem_estar AS (
    SELECT r.id_idoso, r.humor, r.dor, r.data_hora
      FROM registro_bem_estar r
      JOIN residentes USING (id_idoso)
     WHERE r.data_hora >= now() - make_interval(days => 2 * $1::int)
),
intercorrencias AS (
    SELECT ic.data_hora
      FROM intercorrencia ic
      JOIN residentes USING (id_idoso)
     WHERE ic.data_hora >= now() - make_interval(days => 2 * $1::int)
)
SELECT
    (SELECT count(*) FROM residentes)                                        AS residentes,
    (SELECT count(*) FROM bem_estar
      WHERE data_hora >= now() - make_interval(days => $1::int))             AS checkins,
    (SELECT round(100.0 * count(DISTINCT id_idoso)
                  / NULLIF((SELECT count(*) FROM residentes), 0), 1)
       FROM bem_estar
      WHERE data_hora >= now() - make_interval(days => $1::int))             AS pct_residentes_com_checkin,
    (SELECT round(avg(humor), 2) FROM bem_estar
      WHERE data_hora >= now() - make_interval(days => $1::int))             AS humor_medio,
    (SELECT round(avg(humor), 2) FROM bem_estar
      WHERE data_hora <  now() - make_interval(days => $1::int))             AS humor_medio_anterior,
    (SELECT round(avg(dor), 2) FROM bem_estar
      WHERE data_hora >= now() - make_interval(days => $1::int))             AS dor_media,
    (SELECT round(avg(dor), 2) FROM bem_estar
      WHERE data_hora <  now() - make_interval(days => $1::int))             AS dor_media_anterior,
    (SELECT count(*) FROM intercorrencias
      WHERE data_hora >= now() - make_interval(days => $1::int))             AS intercorrencias,
    (SELECT count(*) FROM intercorrencias
      WHERE data_hora <  now() - make_interval(days => $1::int))             AS intercorrencias_anterior,
    (SELECT round(avg(rf.aceitacao), 1)
       FROM registro_refeicao rf
       JOIN residentes USING (id_idoso)
      WHERE rf.data_hora >= now() - make_interval(days => $1::int))          AS aceitacao_alimentar_media,
    fn_cuidadores_necessarios(fn_minha_ilpi_profissional())                  AS cuidadores_necessarios,
    (SELECT count(*) FROM profissional
      WHERE id_ilpi = fn_minha_ilpi_profissional()
        AND funcao = 'cuidador' AND ativo)                                   AS cuidadores_na_equipe;
EXECUTE dash_1(30, 'todos');

-- ---------- adesao ----------
PREPARE dash_2(text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($1::text = 'todos' OR grau_dependencia::text = $1::text)
),
previstas AS (
    SELECT p.id_prescricao, (d::date + h) AS horario
      FROM prescricao p
      JOIN residentes USING (id_idoso)
     CROSS JOIN LATERAL unnest(p.horarios) AS h
     CROSS JOIN generate_series(CURRENT_DATE - 7, CURRENT_DATE - 1, INTERVAL '1 day') AS d
     WHERE d::date BETWEEN p.inicio AND COALESCE(p.fim, CURRENT_DATE)
)
SELECT count(*)                                              AS doses_previstas,
       count(a.id_adm)                                       AS doses_dadas,
       round(100.0 * count(a.id_adm) / NULLIF(count(*), 0), 1) AS adesao_pct
  FROM previstas pr
  LEFT JOIN administracao_medicacao a
         ON a.id_prescricao = pr.id_prescricao
        AND a.horario_previsto = pr.horario;
EXECUTE dash_2('todos');

-- ---------- estatisticas (humor) ----------
PREPARE dash_3(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
)
SELECT count(*)                                                AS n,
       round(avg(r.humor), 2)                                 AS media,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY r.humor)   AS mediana,
       mode() WITHIN GROUP (ORDER BY r.humor)                 AS moda,
       round(var_samp(r.humor), 2)                            AS variancia,
       round(stddev_samp(r.humor), 2)                         AS desvio_padrao,
       round(100 * stddev_samp(r.humor) / NULLIF(avg(r.humor), 0), 1) AS coef_variacao_pct,
       min(r.humor)                                           AS minimo,
       max(r.humor)                                           AS maximo
  FROM registro_bem_estar r
  JOIN residentes USING (id_idoso)
 WHERE r.data_hora >= now() - make_interval(days => $1::int);
EXECUTE dash_3(30, 'todos');

-- ---------- estatisticas (conforto) ----------
PREPARE dash_4(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
)
SELECT count(*)                                                AS n,
       round(avg(r.conforto), 2)                                 AS media,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY r.conforto)   AS mediana,
       mode() WITHIN GROUP (ORDER BY r.conforto)                 AS moda,
       round(var_samp(r.conforto), 2)                            AS variancia,
       round(stddev_samp(r.conforto), 2)                         AS desvio_padrao,
       round(100 * stddev_samp(r.conforto) / NULLIF(avg(r.conforto), 0), 1) AS coef_variacao_pct,
       min(r.conforto)                                           AS minimo,
       max(r.conforto)                                           AS maximo
  FROM registro_bem_estar r
  JOIN residentes USING (id_idoso)
 WHERE r.data_hora >= now() - make_interval(days => $1::int);
EXECUTE dash_4(30, 'todos');

-- ---------- estatisticas (dor) ----------
PREPARE dash_5(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
)
SELECT count(*)                                                AS n,
       round(avg(r.dor), 2)                                 AS media,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY r.dor)   AS mediana,
       mode() WITHIN GROUP (ORDER BY r.dor)                 AS moda,
       round(var_samp(r.dor), 2)                            AS variancia,
       round(stddev_samp(r.dor), 2)                         AS desvio_padrao,
       round(100 * stddev_samp(r.dor) / NULLIF(avg(r.dor), 0), 1) AS coef_variacao_pct,
       min(r.dor)                                           AS minimo,
       max(r.dor)                                           AS maximo
  FROM registro_bem_estar r
  JOIN residentes USING (id_idoso)
 WHERE r.data_hora >= now() - make_interval(days => $1::int);
EXECUTE dash_5(30, 'todos');

-- ---------- histograma (humor) ----------
PREPARE dash_6(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
),
registros AS (
    SELECT r.humor AS valor
      FROM registro_bem_estar r
      JOIN residentes USING (id_idoso)
     WHERE r.data_hora >= now() - make_interval(days => $1::int)
)
SELECT v.valor,
       count(rg.valor)                                                  AS frequencia,
       round(100.0 * count(rg.valor) / NULLIF((SELECT count(*) FROM registros), 0), 1) AS percentual
  FROM generate_series(1, 5) AS v(valor)
  LEFT JOIN registros rg ON rg.valor = v.valor
 GROUP BY v.valor
 ORDER BY v.valor;
EXECUTE dash_6(30, 'todos');

-- ---------- histograma (conforto) ----------
PREPARE dash_7(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
),
registros AS (
    SELECT r.conforto AS valor
      FROM registro_bem_estar r
      JOIN residentes USING (id_idoso)
     WHERE r.data_hora >= now() - make_interval(days => $1::int)
)
SELECT v.valor,
       count(rg.valor)                                                  AS frequencia,
       round(100.0 * count(rg.valor) / NULLIF((SELECT count(*) FROM registros), 0), 1) AS percentual
  FROM generate_series(1, 5) AS v(valor)
  LEFT JOIN registros rg ON rg.valor = v.valor
 GROUP BY v.valor
 ORDER BY v.valor;
EXECUTE dash_7(30, 'todos');

-- ---------- histograma (dor) ----------
PREPARE dash_8(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
),
registros AS (
    SELECT r.dor AS valor
      FROM registro_bem_estar r
      JOIN residentes USING (id_idoso)
     WHERE r.data_hora >= now() - make_interval(days => $1::int)
)
SELECT v.valor,
       count(rg.valor)                                                  AS frequencia,
       round(100.0 * count(rg.valor) / NULLIF((SELECT count(*) FROM registros), 0), 1) AS percentual
  FROM generate_series(0, 10) AS v(valor)
  LEFT JOIN registros rg ON rg.valor = v.valor
 GROUP BY v.valor
 ORDER BY v.valor;
EXECUTE dash_8(30, 'todos');

-- ---------- tendencia ----------
PREPARE dash_9(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
)
SELECT to_char(date_trunc(CASE WHEN $1::int <= 30 THEN 'day' ELSE 'week' END, r.data_hora), 'DD/MM') AS periodo,
       round(avg(r.humor), 2)    AS humor_medio,
       round(avg(r.conforto), 2) AS conforto_medio,
       round(avg(r.dor), 2)      AS dor_media,
       count(*)                  AS registros
  FROM registro_bem_estar r
  JOIN residentes USING (id_idoso)
 WHERE r.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY date_trunc(CASE WHEN $1::int <= 30 THEN 'day' ELSE 'week' END, r.data_hora)
 ORDER BY date_trunc(CASE WHEN $1::int <= 30 THEN 'day' ELSE 'week' END, r.data_hora);
EXECUTE dash_9(30, 'todos');

-- ---------- regressao ----------
PREPARE dash_10(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
),
pontos AS (
    SELECT extract(epoch FROM r.data_hora) / 86400 AS dia, r.humor, r.conforto, r.dor
      FROM registro_bem_estar r
      JOIN residentes USING (id_idoso)
     WHERE r.data_hora >= now() - make_interval(days => $1::int)
)
SELECT round((7 * regr_slope(humor, dia))::numeric, 3)    AS humor_por_semana,
       round((7 * regr_slope(conforto, dia))::numeric, 3) AS conforto_por_semana,
       round((7 * regr_slope(dor, dia))::numeric, 3)      AS dor_por_semana
  FROM pontos;
EXECUTE dash_10(30, 'todos');

-- ---------- intercorrencias_tipo ----------
PREPARE dash_11(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
)
SELECT ic.tipo::text AS categoria,
       count(*)      AS total,
       count(*) FILTER (WHERE ic.gravidade = 'grave') AS graves
  FROM intercorrencia ic
  JOIN residentes USING (id_idoso)
 WHERE ic.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY ic.tipo
 ORDER BY total DESC;
EXECUTE dash_11(30, 'todos');

-- ---------- residentes_grau ----------
PREPARE dash_12 AS
SELECT grau_dependencia::text AS categoria,
       count(*)                AS total
  FROM idoso
 WHERE ativo
 GROUP BY grau_dependencia
 ORDER BY grau_dependencia;
EXECUTE dash_12;

-- ---------- radar_atividades ----------
PREPARE dash_13(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
),
participacoes AS (
    SELECT p.id_idoso, a.categoria, a.data_hora, p.nivel_engajamento
      FROM participacao p
      JOIN atividade_lazer a USING (id_atividade)
      JOIN residentes USING (id_idoso)
     WHERE a.data_hora >= now() - make_interval(days => 2 * $1::int)
       AND a.data_hora <= now()
)
SELECT c.categoria::text AS categoria,
       round(100.0 * count(DISTINCT pt.id_idoso) FILTER (WHERE pt.data_hora >= now() - make_interval(days => $1::int))
             / NULLIF((SELECT count(*) FROM residentes), 0), 1) AS pct_atual,
       round(100.0 * count(DISTINCT pt.id_idoso) FILTER (WHERE pt.data_hora <  now() - make_interval(days => $1::int))
             / NULLIF((SELECT count(*) FROM residentes), 0), 1) AS pct_anterior,
       round(avg(pt.nivel_engajamento) FILTER (WHERE pt.data_hora >= now() - make_interval(days => $1::int)), 2)
                                                                AS engajamento_medio
  FROM unnest(enum_range(NULL::categoria_atividade)) AS c(categoria)
  LEFT JOIN participacoes pt ON pt.categoria = c.categoria
 GROUP BY c.categoria
 ORDER BY c.categoria;
EXECUTE dash_13(30, 'todos');

-- ---------- dispersao ----------
PREPARE dash_14(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
)
SELECT r.nome,
       (SELECT count(*)
          FROM participacao p
          JOIN atividade_lazer a USING (id_atividade)
         WHERE p.id_idoso = r.id_idoso
           AND a.data_hora >= now() - make_interval(days => $1::int)
           AND a.data_hora <= now())                       AS atividades,
       (SELECT round(avg(b.humor), 2)
          FROM registro_bem_estar b
         WHERE b.id_idoso = r.id_idoso
           AND b.data_hora >= now() - make_interval(days => $1::int)) AS humor_medio
  FROM residentes r
 ORDER BY r.nome;
EXECUTE dash_14(30, 'todos');

-- ---------- correlacao ----------
PREPARE dash_15(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
),
por_residente AS (
    SELECT (SELECT count(*)
              FROM participacao p
              JOIN atividade_lazer a USING (id_atividade)
             WHERE p.id_idoso = r.id_idoso
               AND a.data_hora >= now() - make_interval(days => $1::int)
               AND a.data_hora <= now())                   AS atividades,
           (SELECT avg(b.humor)
              FROM registro_bem_estar b
             WHERE b.id_idoso = r.id_idoso
               AND b.data_hora >= now() - make_interval(days => $1::int)) AS humor_medio
      FROM residentes r
)
SELECT count(*)                                                   AS n,
       round(corr(humor_medio, atividades)::numeric, 3)           AS r_pearson,
       round(regr_r2(humor_medio, atividades)::numeric, 3)        AS r2,
       round(regr_slope(humor_medio, atividades)::numeric, 4)     AS inclinacao,
       round(regr_intercept(humor_medio, atividades)::numeric, 4) AS intercepto
  FROM por_residente
 WHERE humor_medio IS NOT NULL;
EXECUTE dash_15(30, 'todos');

-- ---------- refeicoes ----------
PREPARE dash_16(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
)
SELECT rf.tipo::text                   AS refeicao,
       count(*)                        AS registros,
       round(avg(rf.aceitacao), 1)     AS aceitacao_media,
       round(stddev_samp(rf.aceitacao), 1) AS desvio_padrao,
       round(avg(rf.hidratacao_ml))    AS hidratacao_media_ml
  FROM registro_refeicao rf
  JOIN residentes USING (id_idoso)
 WHERE rf.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY rf.tipo
 ORDER BY rf.tipo;
EXECUTE dash_16(30, 'todos');

-- ---------- pressao ----------
PREPARE dash_17(int, text) AS
WITH residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($2::text = 'todos' OR grau_dependencia::text = $2::text)
)
SELECT fn_classificar_pressao(s.pressao_sis, s.pressao_dia) AS classe,
       count(*)                                             AS afericoes
  FROM sinal_vital s
  JOIN residentes USING (id_idoso)
 WHERE s.pressao_sis IS NOT NULL
   AND s.pressao_dia IS NOT NULL
   AND s.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY 1
 ORDER BY array_position(ARRAY['Hipotensão', 'Ótima', 'Normal', 'Pré-hipertensão',
                               'Hipertensão estágio 1', 'Hipertensão estágio 2',
                               'Hipertensão estágio 3']::varchar[],
                         fn_classificar_pressao(s.pressao_sis, s.pressao_dia));
EXECUTE dash_17(30, 'todos');
