-- ============================================================
-- Demonstração das ações referenciais (ON UPDATE CASCADE e
-- ON DELETE SET NULL). Rodar depois do schema e do seed, no psql:
--     psql -U postgres -d ilpi -f entregas_bd/etapa02/etapa02_demonstracao_acoes_referenciais.sql
-- Tudo acontece dentro de uma transação desfeita no final (ROLLBACK):
-- o banco volta exatamente ao estado anterior.
-- ============================================================
BEGIN;

-- ------------------------------------------------------------
-- 1) ON UPDATE CASCADE  (participacao.id_atividade -> atividade_lazer)
--    Renumeramos a atividade 6; as participações acompanham sozinhas.
-- ------------------------------------------------------------
SELECT 'antes' AS momento, id_atividade, count(*) AS participacoes
  FROM participacao WHERE id_atividade IN (6, 9006)
 GROUP BY id_atividade;

UPDATE atividade_lazer SET id_atividade = 9006 WHERE id_atividade = 6;

SELECT 'depois' AS momento, id_atividade, count(*) AS participacoes
  FROM participacao WHERE id_atividade IN (6, 9006)
 GROUP BY id_atividade;

-- O mesmo vale para vinculo_responsavel: renumerar um responsável sem
-- recados no mural leva junto os vínculos dele.
UPDATE responsavel SET id_responsavel = 9000 + id_responsavel
 WHERE id_responsavel = (SELECT min(r.id_responsavel) FROM responsavel r
                          WHERE NOT EXISTS (SELECT 1 FROM recado_mural m
                                             WHERE m.id_responsavel = r.id_responsavel))
RETURNING id_responsavel AS novo_id;

SELECT id_idoso, id_responsavel, parentesco
  FROM vinculo_responsavel WHERE id_responsavel > 9000;

-- ------------------------------------------------------------
-- 2) ON DELETE SET NULL  (registro_bem_estar.id_profissional -> profissional)
--    Um cuidador recém-cadastrado registra um check-in e depois tem o
--    cadastro removido: o check-in continua, só perde o autor.
-- ------------------------------------------------------------
INSERT INTO usuario (email, senha_hash, perfil)
VALUES ('cuidador.temporario@larpaz.com', 'x', 'profissional');

INSERT INTO profissional (id_ilpi, id_usuario, nome, funcao)
VALUES (1, currval('usuario_id_usuario_seq'), 'Cuidador Temporário', 'cuidador');

INSERT INTO registro_bem_estar (id_idoso, id_profissional, humor, conforto, dor, observacoes)
VALUES (3, currval('profissional_id_profissional_seq'), 4, 4, 1, 'Check-in de teste');

SELECT 'antes' AS momento, id_registro, id_profissional
  FROM registro_bem_estar WHERE observacoes = 'Check-in de teste';

DELETE FROM profissional WHERE nome = 'Cuidador Temporário';

SELECT 'depois' AS momento, id_registro, id_profissional  -- id_profissional agora é NULL
  FROM registro_bem_estar WHERE observacoes = 'Check-in de teste';

-- ------------------------------------------------------------
-- 3) ON DELETE SET NULL  (idoso.id_usuario -> usuario)
--    Terezinha (idoso 3) ganha uma conta de acesso; a conta é apagada,
--    a residente permanece cadastrada, apenas sem login.
-- ------------------------------------------------------------
INSERT INTO usuario (email, senha_hash, perfil)
VALUES ('terezinha.teste@email.com', 'x', 'idoso');
UPDATE idoso SET id_usuario = currval('usuario_id_usuario_seq') WHERE id_idoso = 3;

SELECT 'antes' AS momento, id_idoso, nome, id_usuario FROM idoso WHERE id_idoso = 3;
DELETE FROM usuario WHERE email = 'terezinha.teste@email.com';
SELECT 'depois' AS momento, id_idoso, nome, id_usuario FROM idoso WHERE id_idoso = 3;

-- ------------------------------------------------------------
-- 4) Contraste: sem ação referencial (NO ACTION, o padrão)
--    Apagar um idoso com histórico clínico é BLOQUEADO — de propósito.
--    (descomente para ver o erro de chave estrangeira)
-- ------------------------------------------------------------
-- DELETE FROM idoso WHERE id_idoso = 1;

ROLLBACK;
