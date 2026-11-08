-- ============================================================
-- Bem Viver ILPI — Demonstração do alerta pelo padrão pessoal
-- Rodar depois de banco/alerta_padrao_pessoal.sql, como postgres.
-- Tudo acontece dentro de uma transação que termina em ROLLBACK:
-- a base volta exatamente ao que era.
-- ============================================================

BEGIN;

-- 1. O padrão de duas residentes. Zuleide tem a pressão baixa e estável,
--    Terezinha é hipertensa e varia bastante.
SELECT i.nome, p.media, p.desvio, p.n AS afericoes
  FROM idoso i
 CROSS JOIN LATERAL fn_padrao_pessoal(i.id_idoso, 'pressao_sis') p
 WHERE i.nome IN ('Zuleide de Oliveira Tavares', 'Terezinha Alves Barbosa');

-- 2. A mesma medida para as duas: 152 por 88.
--    Pela faixa geral é "Hipertensão estágio 1", então o trigger da Etapa 05
--    não gera recado (ele só avisa a partir do estágio 2).
SELECT fn_classificar_pressao(152, 88) AS classificacao_geral;

-- 3. Mas, comparada ao padrão de cada uma, a história muda:
SELECT i.nome, f.media, f.desvio, f.z, f.fora AS fora_do_padrao
  FROM idoso i
 CROSS JOIN LATERAL fn_fora_do_padrao(i.id_idoso, 'pressao_sis', 152) f
 WHERE i.nome IN ('Zuleide de Oliveira Tavares', 'Terezinha Alves Barbosa');

-- 4. Registrando as duas aferições de verdade (como a enfermagem faria no app)
INSERT INTO sinal_vital (id_idoso, id_profissional, pressao_sis, pressao_dia)
SELECT i.id_idoso,
       (SELECT min(id_profissional) FROM profissional p WHERE p.id_ilpi = i.id_ilpi),
       152, 88
  FROM idoso i
 WHERE i.nome IN ('Zuleide de Oliveira Tavares', 'Terezinha Alves Barbosa');

-- 5. O trigger trg_alerta_padrao_pessoal criou um recado de atenção só para a Zuleide.
SELECT prioridade, texto
  FROM recado_plantao
 WHERE texto LIKE '[Alerta automático] Fora do padrão%'
   AND data_hora >= now() - INTERVAL '1 minute';

-- 6. E a visão mostra as aferições dos últimos 30 dias fora do padrão pessoal.
SELECT residente, data_hora::date AS dia, medida, valor, media, desvio, z
  FROM vw_sinal_fora_do_padrao
 ORDER BY data_hora DESC
 LIMIT 5;

ROLLBACK;
