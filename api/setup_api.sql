-- ============================================================
-- Preparação do banco para a API
-- 1) pgcrypto para hash de senha DENTRO do banco (crypt/bcrypt)
-- 2) senhas de demonstração: todo usuário do seed usa 'demo123'
-- 3) papel app_user passa a poder conectar (LOGIN)
-- Executar como superusuário, após schema + seed + rls + migração.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Em produção, cada usuário definiria a própria senha no cadastro.
UPDATE usuario SET senha_hash = crypt('demo123', gen_salt('bf', 10));

-- A API conecta com este papel; o RLS faz o resto.
ALTER ROLE app_user WITH LOGIN PASSWORD 'app_secret_dev';

-- Conferência: autenticação feita pelo próprio PostgreSQL
-- SELECT id_usuario, perfil FROM usuario
--  WHERE email = 'mariana.filha@email.com'
--    AND senha_hash = crypt('demo123', senha_hash);

-- Login pelo banco: a aplicação não lê mais o hash da senha (sem SELECT
-- na coluna senha_hash). Esta função roda como dono e devolve só quem é
-- o usuário, se e-mail e senha conferirem e a conta estiver ativa.
CREATE OR REPLACE FUNCTION fn_autenticar(p_email text, p_senha text)
RETURNS TABLE (id_usuario int, perfil perfil_usuario, funcao funcao_profissional)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT u.id_usuario, u.perfil, p.funcao
      FROM usuario u
      LEFT JOIN profissional p ON p.id_usuario = u.id_usuario
     WHERE u.email = p_email
       AND u.ativo
       AND u.senha_hash = crypt(p_senha, u.senha_hash)
       AND (p.id_profissional IS NULL OR p.ativo)
$$;
REVOKE ALL ON FUNCTION fn_autenticar(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_autenticar(text, text) TO app_user;
