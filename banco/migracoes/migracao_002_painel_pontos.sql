-- ============================================================
-- Migração 002: pontos do pet no painel
-- O Dominó do Lar sincroniza o placar do bichinho ao entrar;
-- a view passa a expor pv.pontos (coluna nova ao final, como
-- exige o CREATE OR REPLACE VIEW).
-- ============================================================

BEGIN;

CREATE OR REPLACE VIEW vw_painel_idoso AS
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

-- Garantias que precisam ser reafirmadas após o REPLACE:
ALTER VIEW vw_painel_idoso SET (security_invoker = true);
GRANT SELECT ON vw_painel_idoso TO app_user;

COMMIT;
