// ============================================================
// Dashboard estatístico do gestor (Etapa 06).
// Cada bloco do painel é UM comando SQL explícito, executado no banco a
// cada vez que o gestor abre o painel ou muda um filtro. Os cálculos
// estatísticos (média, mediana, moda, variância, desvio padrão,
// correlação, regressão) são feitos pelo próprio PostgreSQL.
//
// Parâmetros, sempre separados do SQL (nunca concatenados no texto):
//   $1  período em dias (7, 30, 90 ou 180)
//   $2  grau de dependência ('todos', 'I', 'II' ou 'III')
// A exceção é a MEDIDA (humor, conforto ou dor): é nome de coluna, e nome
// de coluna não pode ir como parâmetro. Por isso a API só aceita um dos
// três nomes da lista MEDIDAS e escolhe o SQL pronto de cada uma; nada
// digitado pelo usuário entra no texto do comando.
//
// Tudo roda com a identidade do gestor: o RLS limita os dados à ILPI dele.
// ============================================================

// Residentes ativos que entram no recorte (filtro de grau de dependência).
// Repetido no começo de cada consulta (CTE) para cada uma ser autossuficiente.
// (n = número do parâmetro do grau: $2 na maioria; $1 na adesão, que não usa período)
const residentesCte = (n) => `residentes AS (
    SELECT id_idoso, nome, grau_dependencia
      FROM idoso
     WHERE ativo
       AND ($${n}::text = 'todos' OR grau_dependencia::text = $${n}::text)
)`;
const RESIDENTES = residentesCte(2);

// Escala de cada medida do check-in de bem-estar
export const MEDIDAS = {
  humor:    { rotulo: "Humor",    min: 1, max: 5,  melhor: "maior" },
  conforto: { rotulo: "Conforto", min: 1, max: 5,  melhor: "maior" },
  dor:      { rotulo: "Dor",      min: 0, max: 10, melhor: "menor" },
};

export const DASHBOARD = {
  // ---------- Indicadores resumidos (com o período anterior, para a tendência) ----------
  indicadores: `WITH ${RESIDENTES},
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
        AND funcao = 'cuidador' AND ativo)                                   AS cuidadores_na_equipe`,

  // ---------- Adesão à medicação nos últimos 7 dias completos ----------
  // Janela fixa de 7 dias: doses previstas = horários de cada prescrição
  // válida em cada dia; dadas = as que têm registro de administração.
  // Parâmetro único: $1 = grau.
  adesao: `WITH ${residentesCte(1)},
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
        AND a.horario_previsto = pr.horario`,

  // ---------- Medidas de tendência central e de dispersão ----------
  // Uma versão por medida (o nome da coluna não pode ser parâmetro).
  estatisticas: Object.fromEntries(Object.keys(MEDIDAS).map((col) => [col, `WITH ${RESIDENTES}
SELECT count(*)                                                AS n,
       round(avg(r.${col}), 2)                                 AS media,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY r.${col})   AS mediana,
       mode() WITHIN GROUP (ORDER BY r.${col})                 AS moda,
       round(var_samp(r.${col}), 2)                            AS variancia,
       round(stddev_samp(r.${col}), 2)                         AS desvio_padrao,
       round(100 * stddev_samp(r.${col}) / NULLIF(avg(r.${col}), 0), 1) AS coef_variacao_pct,
       min(r.${col})                                           AS minimo,
       max(r.${col})                                           AS maximo
  FROM registro_bem_estar r
  JOIN residentes USING (id_idoso)
 WHERE r.data_hora >= now() - make_interval(days => $1::int)`])),

  // ---------- Distribuição de frequência (histograma) ----------
  // generate_series cria todos os valores da escala, para aparecer também
  // o valor que ninguém marcou (frequência zero).
  histograma: Object.fromEntries(Object.entries(MEDIDAS).map(([col, m]) => [col, `WITH ${RESIDENTES},
registros AS (
    SELECT r.${col} AS valor
      FROM registro_bem_estar r
      JOIN residentes USING (id_idoso)
     WHERE r.data_hora >= now() - make_interval(days => $1::int)
)
SELECT v.valor,
       count(rg.valor)                                                  AS frequencia,
       round(100.0 * count(rg.valor) / NULLIF((SELECT count(*) FROM registros), 0), 1) AS percentual
  FROM generate_series(${m.min}, ${m.max}) AS v(valor)
  LEFT JOIN registros rg ON rg.valor = v.valor
 GROUP BY v.valor
 ORDER BY v.valor`])),

  // ---------- Tendência temporal ----------
  // Por dia até 30 dias; por semana nos períodos maiores.
  tendencia: `WITH ${RESIDENTES}
SELECT to_char(date_trunc(CASE WHEN $1::int <= 30 THEN 'day' ELSE 'week' END, r.data_hora), 'DD/MM') AS periodo,
       round(avg(r.humor), 2)    AS humor_medio,
       round(avg(r.conforto), 2) AS conforto_medio,
       round(avg(r.dor), 2)      AS dor_media,
       count(*)                  AS registros
  FROM registro_bem_estar r
  JOIN residentes USING (id_idoso)
 WHERE r.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY date_trunc(CASE WHEN $1::int <= 30 THEN 'day' ELSE 'week' END, r.data_hora)
 ORDER BY date_trunc(CASE WHEN $1::int <= 30 THEN 'day' ELSE 'week' END, r.data_hora)`,

  // Reta de tendência (mínimos quadrados) de cada medida ao longo do tempo:
  // regr_slope = quanto a medida muda por dia; × 7 = por semana.
  regressao: `WITH ${RESIDENTES},
pontos AS (
    SELECT extract(epoch FROM r.data_hora) / 86400 AS dia, r.humor, r.conforto, r.dor
      FROM registro_bem_estar r
      JOIN residentes USING (id_idoso)
     WHERE r.data_hora >= now() - make_interval(days => $1::int)
)
SELECT round((7 * regr_slope(humor, dia))::numeric, 3)    AS humor_por_semana,
       round((7 * regr_slope(conforto, dia))::numeric, 3) AS conforto_por_semana,
       round((7 * regr_slope(dor, dia))::numeric, 3)      AS dor_por_semana
  FROM pontos`,

  // ---------- Frequência: intercorrências por tipo ----------
  intercorrencias_tipo: `WITH ${RESIDENTES}
SELECT ic.tipo::text AS categoria,
       count(*)      AS total,
       count(*) FILTER (WHERE ic.gravidade = 'grave') AS graves
  FROM intercorrencia ic
  JOIN residentes USING (id_idoso)
 WHERE ic.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY ic.tipo
 ORDER BY total DESC`,

  // ---------- Residentes por grau de dependência ----------
  // Sem o filtro de grau: o gráfico é justamente o seletor do filtro.
  residentes_grau: `SELECT grau_dependencia::text AS categoria,
       count(*)                AS total
  FROM idoso
 WHERE ativo
 GROUP BY grau_dependencia
 ORDER BY grau_dependencia`,

  // ---------- Radar: participação por categoria de atividade ----------
  // % dos residentes do recorte que foram a pelo menos uma atividade de cada
  // categoria, no período atual e no anterior (mesmo tamanho).
  radar_atividades: `WITH ${RESIDENTES},
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
 ORDER BY c.categoria`,

  // ---------- Dispersão: atividades × humor, por residente ----------
  dispersao: `WITH ${RESIDENTES}
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
 ORDER BY r.nome`,

  // Coeficiente de correlação de Pearson (corr) e a reta y = a + b·x
  correlacao: `WITH ${RESIDENTES},
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
 WHERE humor_medio IS NOT NULL`,

  // ---------- Comparativo: aceitação alimentar por refeição ----------
  refeicoes: `WITH ${RESIDENTES}
SELECT rf.tipo::text                   AS refeicao,
       count(*)                        AS registros,
       round(avg(rf.aceitacao), 1)     AS aceitacao_media,
       round(stddev_samp(rf.aceitacao), 1) AS desvio_padrao,
       round(avg(rf.hidratacao_ml))    AS hidratacao_media_ml
  FROM registro_refeicao rf
  JOIN residentes USING (id_idoso)
 WHERE rf.data_hora >= now() - make_interval(days => $1::int)
 GROUP BY rf.tipo
 ORDER BY rf.tipo`,

  // ---------- Pressão arterial: frequência por classe (usa a FUNÇÃO da Etapa 05) ----------
  pressao: `WITH ${RESIDENTES}
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
                         fn_classificar_pressao(s.pressao_sis, s.pressao_dia))`,
};
