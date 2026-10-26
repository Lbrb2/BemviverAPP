-- ============================================================
-- Bem Viver ILPI — Etapa 05: demonstração
-- Executar depois de etapa05_funcoes_procedimentos_triggers.sql.
--
-- Cada teste que altera dados roda entre BEGIN e ROLLBACK: mostra o
-- antes, executa, mostra o depois e desfaz tudo no final. Assim o
-- arquivo pode ser executado quantas vezes quiser sem mudar o banco.
-- No psql, as mensagens dos procedimentos (RAISE NOTICE) aparecem como
-- "NOTICE: ..."; no pgAdmin, na aba "Messages".
-- ============================================================

SET TIME ZONE 'America/Recife';


-- ************************************************************
-- FUNÇÃO 1: fn_classificar_pressao
-- ************************************************************

-- Uma pressão de cada faixa
SELECT sistolica || '/' || diastolica                 AS pressao,
       fn_classificar_pressao(sistolica, diastolica) AS classificacao
  FROM (VALUES (110, 70), (125, 82), (135, 80), (150, 85),
               (145, 102), (190, 100), (85, 55)) AS t(sistolica, diastolica);

-- Usada numa consulta: classificação das 10 últimas aferições de pressão
SELECT to_char(s.data_hora, 'DD/MM HH24:MI')                AS aferida_em,
       i.nome                                               AS residente,
       s.pressao_sis || '/' || s.pressao_dia                AS pressao,
       fn_classificar_pressao(s.pressao_sis, s.pressao_dia) AS classificacao
  FROM sinal_vital s
  JOIN idoso i ON i.id_idoso = s.id_idoso
 WHERE s.pressao_sis IS NOT NULL
 ORDER BY s.data_hora DESC
 LIMIT 10;


-- ************************************************************
-- FUNÇÃO 2: fn_cuidadores_necessarios
-- ************************************************************

-- Para cada ILPI: residentes por grau, cuidadores exigidos pela RDC 502
-- e cuidadores ativos na equipe
SELECT il.nome                                                 AS ilpi,
       count(i.id_idoso) FILTER (WHERE i.grau_dependencia = 'I')   AS grau_i,
       count(i.id_idoso) FILTER (WHERE i.grau_dependencia = 'II')  AS grau_ii,
       count(i.id_idoso) FILTER (WHERE i.grau_dependencia = 'III') AS grau_iii,
       fn_cuidadores_necessarios(il.id_ilpi)                   AS cuidadores_necessarios,
       (SELECT count(*) FROM profissional p
         WHERE p.id_ilpi = il.id_ilpi AND p.funcao = 'cuidador' AND p.ativo)
                                                               AS cuidadores_na_equipe
  FROM ilpi il
  JOIN idoso i ON i.id_ilpi = il.id_ilpi AND i.ativo
 GROUP BY il.id_ilpi, il.nome
 ORDER BY il.id_ilpi;


-- ************************************************************
-- PROCEDIMENTO 1: sp_desligar_residente (atualização)
-- ************************************************************
BEGIN;

-- ANTES: Severina (id 1) ativa, com prescrições e meta ativas
SELECT i.nome, i.ativo AS residente_ativo, u.ativo AS conta_ativa
  FROM idoso i LEFT JOIN usuario u ON u.id_usuario = i.id_usuario
 WHERE i.id_idoso = 1;
SELECT medicamento, ativo, inicio, fim FROM prescricao WHERE id_idoso = 1 ORDER BY medicamento;
SELECT descricao, status FROM meta_cuidado WHERE id_idoso = 1 ORDER BY id_meta;

CALL sp_desligar_residente(1);

-- DEPOIS: residente e conta inativos, prescrições encerradas hoje, metas suspensas
SELECT i.nome, i.ativo AS residente_ativo, u.ativo AS conta_ativa
  FROM idoso i LEFT JOIN usuario u ON u.id_usuario = i.id_usuario
 WHERE i.id_idoso = 1;
SELECT medicamento, ativo, inicio, fim FROM prescricao WHERE id_idoso = 1 ORDER BY medicamento;
SELECT descricao, status FROM meta_cuidado WHERE id_idoso = 1 ORDER BY id_meta;

ROLLBACK;

-- Erro esperado: residente que não existe
-- CALL sp_desligar_residente(9999);
-- ERROR:  Residente 9999 não encontrado.


-- ************************************************************
-- PROCEDIMENTO 2: sp_distribuir_cuidadores (cursor)
-- ************************************************************
BEGIN;

-- Primeiro, o que daria UM UPDATE só, sem cursor: a carga de cada
-- cuidador é calculada uma vez, antes de começar, então TODOS os
-- residentes vão para o mesmo cuidador (o que estava com menos carga).
UPDATE idoso i
   SET id_cuidador_referencia = (
        SELECT p.id_profissional
          FROM profissional p
          LEFT JOIN idoso x ON x.id_cuidador_referencia = p.id_profissional AND x.ativo
         WHERE p.id_ilpi = i.id_ilpi AND p.funcao = 'cuidador' AND p.ativo
         GROUP BY p.id_profissional
         ORDER BY COALESCE(sum(CASE x.grau_dependencia WHEN 'I' THEN 3 WHEN 'II' THEN 6 WHEN 'III' THEN 10 END), 0),
                  count(x.id_idoso), p.id_profissional
         LIMIT 1)
 WHERE i.id_ilpi = 1 AND i.ativo;

SELECT 'UPDATE único' AS metodo, p.nome AS cuidador, count(i.id_idoso) AS residentes
  FROM profissional p
  LEFT JOIN idoso i ON i.id_cuidador_referencia = p.id_profissional AND i.ativo
 WHERE p.id_ilpi = 1 AND p.funcao = 'cuidador' AND p.ativo
 GROUP BY p.id_profissional, p.nome
 ORDER BY p.nome;

-- Agora com o procedimento: refazer = true apaga a divisão acima e
-- distribui de novo, um residente por vez (as mensagens NOTICE mostram
-- para quem foi cada um)
CALL sp_distribuir_cuidadores(1, true);

-- DEPOIS: carga equilibrada (pontos: grau I = 3, II = 6, III = 10)
SELECT p.nome                                                              AS cuidador,
       count(i.id_idoso)                                                   AS residentes,
       count(i.id_idoso) FILTER (WHERE i.grau_dependencia = 'III')         AS grau_iii,
       COALESCE(sum(CASE i.grau_dependencia WHEN 'I' THEN 3 WHEN 'II' THEN 6 WHEN 'III' THEN 10 END), 0)
                                                                           AS pontos_de_carga
  FROM profissional p
  LEFT JOIN idoso i ON i.id_cuidador_referencia = p.id_profissional AND i.ativo
 WHERE p.id_ilpi = 1 AND p.funcao = 'cuidador' AND p.ativo
 GROUP BY p.id_profissional, p.nome
 ORDER BY pontos_de_carga DESC, p.nome;

-- Um cuidador sai da equipe: os residentes dele ficam sem referência
-- válida. Rodando de novo com refazer = false, SÓ esses são redistribuídos.
UPDATE profissional SET ativo = false WHERE id_profissional = 3;   -- Marcos Vinícius
CALL sp_distribuir_cuidadores(1);

SELECT p.nome AS cuidador, count(i.id_idoso) AS residentes,
       COALESCE(sum(CASE i.grau_dependencia WHEN 'I' THEN 3 WHEN 'II' THEN 6 WHEN 'III' THEN 10 END), 0)
                AS pontos_de_carga
  FROM profissional p
  LEFT JOIN idoso i ON i.id_cuidador_referencia = p.id_profissional AND i.ativo
 WHERE p.id_ilpi = 1 AND p.funcao = 'cuidador' AND p.ativo
 GROUP BY p.id_profissional, p.nome
 ORDER BY pontos_de_carga DESC, p.nome;

ROLLBACK;


-- ************************************************************
-- TRIGGER 1: trg_alerta_sinal_vital
-- ************************************************************
BEGIN;

SELECT count(*) AS recados_automaticos_antes
  FROM recado_plantao WHERE texto LIKE '[Alerta automático]%';

-- Aferição normal: o trigger roda, mas não cria recado
INSERT INTO sinal_vital (id_idoso, id_profissional, pressao_sis, pressao_dia, saturacao, temperatura)
VALUES (3, 3, 122, 78, 97, 36.4);

-- Febre: recado de ATENÇÃO
INSERT INTO sinal_vital (id_idoso, id_profissional, temperatura, freq_cardiaca)
VALUES (3, 3, 38.1, 96);

-- Pressão muito alta e saturação baixa: recado URGENTE
INSERT INTO sinal_vital (id_idoso, id_profissional, pressao_sis, pressao_dia, saturacao, freq_cardiaca)
VALUES (2, 3, 186, 112, 88, 124);

-- Os recados que o trigger criou sozinho
SELECT r.prioridade, r.turno, i.nome AS residente, p.nome AS aferido_por, r.texto
  FROM recado_plantao r
  JOIN idoso i        ON i.id_idoso = r.id_idoso
  JOIN profissional p ON p.id_profissional = r.id_profissional
 WHERE r.texto LIKE '[Alerta automático]%'
 ORDER BY r.id_recado;

ROLLBACK;


-- ************************************************************
-- TRIGGER 2: trg_log_grau_dependencia (tabela de log)
-- ************************************************************
BEGIN;

-- A aplicação informa ao banco quem está logado (como a API faz em toda
-- requisição). Aqui simulamos o gestor do Lar Recanto da Paz; o "true"
-- faz o valor valer só até o fim desta transação.
SELECT set_config('app.id_usuario',
                  (SELECT id_usuario::text FROM usuario WHERE email = 'gestor@larpaz.com'),
                  true);

SELECT nome, grau_dependencia FROM idoso WHERE id_idoso = 2;
SELECT fn_cuidadores_necessarios(1) AS cuidadores_necessarios_antes;

-- Expedito passou a precisar de ajuda: grau I → II. O trigger grava no log.
-- (Com isso o Lar passa a ter 11 residentes de grau II, e a RDC exige
-- mais um cuidador: 3 → 4.)
UPDATE idoso SET grau_dependencia = 'II' WHERE id_idoso = 2;

-- Editar só o nome NÃO gera log (a coluna grau não está no UPDATE)
UPDATE idoso SET nome = 'Expedito José dos Santos' WHERE id_idoso = 2;

-- "Mudar" para o mesmo grau também não gera log (WHEN ... IS DISTINCT FROM)
UPDATE idoso SET grau_dependencia = 'II' WHERE id_idoso = 2;

-- O log: uma linha só, com o grau anterior, o novo, a nova necessidade
-- de cuidadores da ILPI e quem fez a alteração
SELECT l.id_log, i.nome AS residente, l.grau_anterior, l.grau_novo,
       l.cuidadores_necessarios, u.email AS alterado_por,
       to_char(l.data_hora, 'DD/MM/YYYY HH24:MI') AS quando
  FROM log_grau_dependencia l
  JOIN idoso i        ON i.id_idoso = l.id_idoso
  LEFT JOIN usuario u ON u.id_usuario = l.id_usuario
 ORDER BY l.id_log;

ROLLBACK;
