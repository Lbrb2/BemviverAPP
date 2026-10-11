-- ============================================================
-- Como adicionar novos usuários (para testes/desenvolvimento)
-- Rode no pgAdmin (Query Tool no banco "ilpi") ou no psql.
-- Toda conta = 1 linha em "usuario" + 1 linha no perfil dela.
-- A senha é gravada com hash (pgcrypto); troque 'senha123'.
-- ============================================================

-- ---------- Exemplo 1: um novo IDOSO ----------
-- Passo A: cria o login e captura o id gerado
WITH novo AS (
  INSERT INTO usuario (email, senha_hash, perfil)
  VALUES ('joao.idoso@email.com', crypt('senha123', gen_salt('bf', 10)), 'idoso')
  RETURNING id_usuario
)
-- Passo B: cria o cadastro do idoso ligado a esse login
INSERT INTO idoso (id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia)
SELECT 1, id_usuario, 'João Batista da Silva', '55566677788', '1945-05-20', CURRENT_DATE, 'I'
FROM novo;

-- Dar um pet ao novo idoso (opcional, mas simpático):
INSERT INTO pet_virtual (id_idoso, nome, especie)
SELECT id_idoso, 'Bento', 'cachorro' FROM idoso WHERE cpf = '55566677788';


-- ---------- Exemplo 2: um novo PROFISSIONAL (cuidador) ----------
WITH novo AS (
  INSERT INTO usuario (email, senha_hash, perfil)
  VALUES ('ana.cuidadora@larpaz.com', crypt('senha123', gen_salt('bf', 10)), 'profissional')
  RETURNING id_usuario
)
INSERT INTO profissional (id_ilpi, id_usuario, nome, funcao, registro_conselho)
SELECT 1, id_usuario, 'Ana Paula Lima', 'cuidador', NULL
FROM novo;
-- Funções possíveis: 'cuidador','tecnico_enfermagem','enfermeiro','medico',
--                    'psicologo','fisioterapeuta','nutricionista','assistente_social'


-- ---------- Exemplo 3: um novo RESPONSÁVEL e o vínculo ----------
WITH novo AS (
  INSERT INTO usuario (email, senha_hash, perfil)
  VALUES ('pedro.filho@email.com', crypt('senha123', gen_salt('bf', 10)), 'responsavel')
  RETURNING id_usuario
)
INSERT INTO responsavel (id_usuario, nome, telefone)
SELECT id_usuario, 'Pedro Henrique Silva', '81990001111'
FROM novo;

-- Ligar esse responsável a um idoso (ex.: o João criado acima).
-- responsavel_legal = TRUE indica o responsável legal (só pode haver um por idoso).
INSERT INTO vinculo_responsavel (id_idoso, id_responsavel, parentesco, responsavel_legal)
SELECT i.id_idoso, r.id_responsavel, 'filho', TRUE
FROM idoso i, responsavel r
WHERE i.cpf = '55566677788' AND r.telefone = '81990001111';


-- ---------- Conferir o que foi criado ----------
-- SELECT id_usuario, email, perfil FROM usuario ORDER BY id_usuario DESC LIMIT 5;
