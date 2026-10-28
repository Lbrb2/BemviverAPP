-- ============================================================
-- Migração 005: Gestor da ILPI
-- O gestor administra as contas da própria instituição.
-- Modelado como uma linha em "profissional" com função 'gestor',
-- o que reaproveita fn_minha_ilpi_profissional() no RLS.
-- ============================================================

BEGIN;

-- 'gestor' passa a ser uma função de profissional
ALTER TYPE funcao_profissional ADD VALUE IF NOT EXISTS 'gestor';

COMMIT;

BEGIN;

-- Auxiliar: o usuário logado é gestor?
CREATE OR REPLACE FUNCTION fn_sou_gestor() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT EXISTS (SELECT 1 FROM profissional
                   WHERE id_usuario = fn_usuario_atual() AND funcao = 'gestor') $$;

-- O gestor precisa inserir em usuario/idoso/profissional/responsavel.
-- Essas tabelas guardam identidade, não dado clínico; o controle de
-- QUEM pode inserir é feito na API (exige perfil gestor) + escopo de ILPI.
-- Habilitamos INSERT para app_user; as políticas de leitura sensível
-- continuam nas tabelas de registro, que é onde o sigilo importa.
GRANT INSERT ON usuario, idoso, profissional, responsavel, vinculo_responsavel, pet_virtual TO app_user;
GRANT USAGE ON SEQUENCE usuario_id_usuario_seq, idoso_id_idoso_seq,
  profissional_id_profissional_seq, responsavel_id_responsavel_seq,
  pet_virtual_id_pet_seq TO app_user;

COMMIT;

-- Políticas de INSERT do gestor (idoso e profissional têm RLS com FORCE):
BEGIN;
CREATE POLICY ins_idoso_gestor ON idoso FOR INSERT TO app_user
    WITH CHECK (fn_sou_gestor() AND id_ilpi = fn_minha_ilpi_profissional());
CREATE POLICY ins_prof_gestor ON profissional FOR INSERT TO app_user
    WITH CHECK (fn_sou_gestor() AND id_ilpi = fn_minha_ilpi_profissional());
COMMIT;
