-- ============================================================
-- Bem Viver ILPI — Etapa 04: índices e visões
-- Executar depois de schema_ilpi.sql, seed_ilpi.sql e rls_ilpi.sql.
-- Pode ser executado mais de uma vez (IF NOT EXISTS / OR REPLACE).
-- As 4 consultas novas estão em etapa04_consultas.sql.
-- ============================================================

-- esconde os avisos do tipo "já existe, pulando" ao executar de novo
SET client_min_messages = warning;


-- ------------------------------------------------------------
-- ÍNDICE 1: intercorrências por data
-- ------------------------------------------------------------
-- O índice que já existia em intercorrencia é (id_idoso, data_hora), útil
-- para o prontuário de UM residente. Mas a enfermagem e o gestor perguntam
-- "o que aconteceu na casa nos últimos N dias?", sem filtrar por residente.
-- Nesse caso o índice antigo não serve (a primeira coluna dele é id_idoso)
-- e o banco leria a tabela inteira, que cresce todo dia e nunca é apagada
-- (registro de intercorrência é documento do prontuário).
-- Usado por: consulta 12 (FULL OUTER JOIN) e visão vw_intercorrencia_contato.
CREATE INDEX IF NOT EXISTS ix_intercorrencia_data
    ON intercorrencia (data_hora DESC);


-- ------------------------------------------------------------
-- ÍNDICE 2: metas de cuidado ATIVAS por data de revisão (índice parcial)
-- ------------------------------------------------------------
-- A equipe técnica precisa revisar cada meta do plano de cuidado na data
-- combinada. A pergunta do dia a dia é "quais metas ativas vencem até tal
-- data?". Metas atingidas ou suspensas nunca entram nessa pergunta e só
-- se acumulam com o tempo, por isso o índice é PARCIAL (WHERE status =
-- 'ativa'): guarda só as linhas que interessam e fica pequeno.
-- Usado por: consulta 14 (subconsultas).
CREATE INDEX IF NOT EXISTS ix_meta_ativa_revisao
    ON meta_cuidado (data_revisao)
    WHERE status = 'ativa';


-- ------------------------------------------------------------
-- VISÃO 1: vw_mapa_medicacao — mapa de medicação das prescrições ativas
-- ------------------------------------------------------------
-- Justificativa: antes de cada ronda de medicação, a enfermagem confere a
-- prescrição de cada residente. A informação está espalhada em 5 tabelas:
-- a prescrição, o residente (nome, grau de dependência), a ILPI, o
-- profissional que prescreveu e o histórico de administrações. A visão
-- junta tudo em uma linha por prescrição ativa e acrescenta quando foi a
-- última dose dada e quantas doses foram registradas na última semana,
-- comparando com quantas eram previstas (nº de horários × dias).
-- Joins: prescricao ⋈ idoso ⋈ ilpi ⋈ profissional ⟕ administracao_medicacao
CREATE OR REPLACE VIEW vw_mapa_medicacao AS
SELECT p.id_prescricao,
       i.id_idoso,
       i.nome                                   AS residente,
       i.grau_dependencia,
       il.nome                                  AS ilpi,
       p.medicamento,
       p.dose,
       array_to_string(p.horarios, ', ')        AS horarios,
       pr.nome                                  AS prescrito_por,
       pr.funcao                                AS funcao_prescritor,
       p.inicio,
       p.fim,
       max(a.administrado_em)                   AS ultima_dose,
       -- semana = os 7 dias completos até ontem (hoje ainda está em curso),
       -- pela data local de Pernambuco
       count(a.id_adm) FILTER (
           WHERE a.administrado_em IS NOT NULL
             AND (a.horario_previsto AT TIME ZONE 'America/Recife')::date
                 BETWEEN (now() AT TIME ZONE 'America/Recife')::date - 7
                     AND (now() AT TIME ZONE 'America/Recife')::date - 1
       )                                        AS doses_dadas_semana,
       -- previstas = nº de horários × dias da semana em que a prescrição
       -- já valia (se começou há menos de 7 dias, conta só os dias dela)
       array_length(p.horarios, 1)
         * GREATEST(0, (now() AT TIME ZONE 'America/Recife')::date
                       - GREATEST(p.inicio, (now() AT TIME ZONE 'America/Recife')::date - 7))
                                                AS doses_previstas_semana
  FROM prescricao p
  JOIN idoso i         ON i.id_idoso = p.id_idoso
  JOIN ilpi il         ON il.id_ilpi = i.id_ilpi
  JOIN profissional pr ON pr.id_profissional = p.id_profissional
  LEFT JOIN administracao_medicacao a ON a.id_prescricao = p.id_prescricao
 WHERE p.ativo
   AND i.ativo
 GROUP BY p.id_prescricao, i.id_idoso, i.nome, i.grau_dependencia, il.nome,
          p.medicamento, p.dose, p.horarios, pr.nome, pr.funcao, p.inicio, p.fim;

-- security_invoker: a visão respeita o RLS de quem consulta (cada
-- profissional só vê os residentes da própria ILPI), como as demais.
ALTER VIEW vw_mapa_medicacao SET (security_invoker = true);
GRANT SELECT ON vw_mapa_medicacao TO app_user;


-- ------------------------------------------------------------
-- VISÃO 2: vw_intercorrencia_contato — intercorrências e quem avisar
-- ------------------------------------------------------------
-- Justificativa: quando acontece uma queda ou outra intercorrência, a ILPI
-- deve comunicar a família (Estatuto da Pessoa Idosa e RDC 502/2021). Quem
-- está de plantão precisa ver, numa tela só, o que houve, quem registrou,
-- se a família já foi avisada e PARA QUEM ligar: o responsável legal do
-- residente e o telefone dele. São 6 tabelas. O LEFT JOIN no responsável
-- mantém na lista o residente que ainda não tem responsável legal
-- cadastrado (justamente o caso que mais precisa de atenção).
-- Joins: intercorrencia ⋈ idoso ⋈ ilpi ⋈ profissional
--        ⟕ vinculo_responsavel (só o legal) ⟕ responsavel
CREATE OR REPLACE VIEW vw_intercorrencia_contato AS
SELECT ic.id_intercorrencia,
       ic.data_hora,
       il.nome                     AS ilpi,
       i.id_idoso,
       i.nome                      AS residente,
       ic.tipo,
       ic.gravidade,
       ic.local_evento,
       ic.descricao,
       ic.conduta,
       pr.nome                     AS registrado_por,
       ic.familia_avisada,
       r.nome                      AS responsavel_legal,
       v.parentesco,
       r.telefone                  AS telefone_responsavel
  FROM intercorrencia ic
  JOIN idoso i         ON i.id_idoso = ic.id_idoso
  JOIN ilpi il         ON il.id_ilpi = i.id_ilpi
  JOIN profissional pr ON pr.id_profissional = ic.id_profissional
  LEFT JOIN vinculo_responsavel v ON v.id_idoso = i.id_idoso
                                 AND v.responsavel_legal
  LEFT JOIN responsavel r ON r.id_responsavel = v.id_responsavel;

ALTER VIEW vw_intercorrencia_contato SET (security_invoker = true);
GRANT SELECT ON vw_intercorrencia_contato TO app_user;
