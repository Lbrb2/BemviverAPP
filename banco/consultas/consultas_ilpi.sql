-- ============================================================
-- Consultas analíticas e de alerta
-- Plataforma de Acompanhamento de Idosos em ILPIs (PE)
-- Executar após schema_ilpi.sql e seed_ilpi.sql
-- ============================================================

-- 1) PAINEL GERAL: visão consolidada de todos os idosos ativos
SELECT * FROM vw_painel_idoso ORDER BY ilpi, nome;


-- 2) ALERTA: idosos sem check-in de bem-estar há mais de 3 dias
--    (inclui quem nunca registrou — caso do Manoel)
SELECT
    i.nome,
    il.nome AS ilpi,
    max(r.data_hora) AS ultimo_checkin,
    COALESCE(
        extract(day FROM now() - max(r.data_hora))::int,
        extract(day FROM now() - i.data_admissao)::int
    ) AS dias_sem_checkin
FROM idoso i
JOIN ilpi il USING (id_ilpi)
LEFT JOIN registro_bem_estar r USING (id_idoso)
WHERE i.ativo
GROUP BY i.id_idoso, i.nome, il.nome, i.data_admissao
HAVING max(r.data_hora) IS NULL
    OR max(r.data_hora) < now() - INTERVAL '3 days'
ORDER BY dias_sem_checkin DESC;


-- 3) EVOLUÇÃO DO HUMOR: média semanal por idoso (base para gráfico de linha)
SELECT
    i.nome,
    date_trunc('week', r.data_hora)::date AS semana,
    round(avg(r.humor), 2)    AS humor_medio,
    round(avg(r.conforto), 2) AS conforto_medio,
    round(avg(r.dor), 2)      AS dor_media,
    count(*)                  AS registros
FROM registro_bem_estar r
JOIN idoso i USING (id_idoso)
GROUP BY i.nome, semana
ORDER BY i.nome, semana;


-- 4) TRAJETÓRIA CLÍNICA: comparar a pontuação da mesma escala ao longo do tempo
--    (window function: diferença em relação à avaliação anterior)
SELECT
    i.nome,
    a.instrumento,
    a.data_hora::date AS data,
    a.pontuacao_total,
    a.pontuacao_total - lag(a.pontuacao_total) OVER (
        PARTITION BY a.id_idoso, a.instrumento ORDER BY a.data_hora
    ) AS variacao
FROM avaliacao a
JOIN idoso i USING (id_idoso)
WHERE a.pontuacao_total IS NOT NULL
ORDER BY i.nome, a.instrumento, a.data_hora;


-- 5) ENGAJAMENTO EM LAZER: participação por categoria nos últimos 30 dias
SELECT
    il.nome AS ilpi,
    a.categoria,
    count(p.id_idoso)                     AS participacoes,
    round(avg(p.nivel_engajamento), 2)    AS engajamento_medio
FROM atividade_lazer a
JOIN ilpi il USING (id_ilpi)
LEFT JOIN participacao p USING (id_atividade)
WHERE a.data_hora BETWEEN now() - INTERVAL '30 days' AND now()
GROUP BY il.nome, a.categoria
ORDER BY il.nome, participacoes DESC;


-- 6) SINAL INDIRETO VIA GAMIFICAÇÃO: queda de eventos do pet
--    Compara pontos da última semana com a semana anterior;
--    queda acentuada pode indicar desengajamento do idoso.
SELECT
    i.nome AS idoso,
    pv.nome AS pet,
    sum(e.pontos_ganhos) FILTER (
        WHERE e.data_hora >= now() - INTERVAL '7 days'
    ) AS pontos_ultimos_7d,
    sum(e.pontos_ganhos) FILTER (
        WHERE e.data_hora >= now() - INTERVAL '14 days'
          AND e.data_hora <  now() - INTERVAL '7 days'
    ) AS pontos_7d_anteriores
FROM pet_virtual pv
JOIN idoso i USING (id_idoso)
LEFT JOIN evento_pet e USING (id_pet)
GROUP BY i.nome, pv.nome
ORDER BY pontos_ultimos_7d NULLS FIRST;


-- 7) VISÃO DO RESPONSÁVEL: tudo que a filha da Dona Severina vê ao abrir o app
SELECT
    p.nome, p.idade, p.grau_dependencia, p.ilpi,
    p.ultimo_humor, p.ultimo_conforto, p.ultima_dor, p.ultimo_checkin,
    p.ultima_avaliacao, p.ultima_pontuacao,
    p.pet, p.nivel_pet, p.atividades_30d
FROM vw_painel_idoso p
JOIN vinculo_responsavel v USING (id_idoso)
WHERE v.id_responsavel = 1; -- Mariana, filha e responsável legal


-- 8) LGPD: consentimentos ativos e histórico de acesso a dados de um idoso
SELECT finalidade, data_concessao, data_revogacao
FROM consentimento_lgpd
WHERE id_idoso = 1 AND data_revogacao IS NULL;

SELECT u.email, l.acao, l.tabela_afetada, l.data_hora
FROM log_auditoria l
JOIN usuario u USING (id_usuario)
ORDER BY l.data_hora DESC
LIMIT 20;
