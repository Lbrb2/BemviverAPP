-- ============================================================
-- Migração 007: Xodó com personalidade e fases de crescimento
-- - o idoso escolhe espécie e nome do bichinho (personalização)
-- - o pet cresce por FASES visuais conforme o nível
-- - acessórios/casinha são desbloqueados por nível (cosmético)
-- Nada aqui pressiona o idoso: o pet nunca regride nem adoece.
-- ============================================================

BEGIN;

-- personalização e conquista de acessórios
ALTER TABLE pet_virtual ADD COLUMN IF NOT EXISTS acessorio VARCHAR(30);      -- ex.: chapeu, laco, oculos
ALTER TABLE pet_virtual ADD COLUMN IF NOT EXISTS cor VARCHAR(20);            -- cor escolhida pelo idoso

-- A fase é derivada do nível (não precisa coluna): 1-2 filhote,
-- 3-4 jovem, 5-6 adulto, 7+ sábio. Deixamos uma view de conveniência.
CREATE OR REPLACE VIEW vw_pet_completo AS
SELECT
    pv.*,
    CASE
        WHEN pv.nivel <= 2 THEN 'filhote'
        WHEN pv.nivel <= 4 THEN 'jovem'
        WHEN pv.nivel <= 6 THEN 'adulto'
        ELSE 'sabio'
    END AS fase
FROM pet_virtual pv;

GRANT SELECT ON vw_pet_completo TO app_user;
GRANT UPDATE (nome, especie, acessorio, cor) ON pet_virtual TO app_user;

-- O idoso pode personalizar o PRÓPRIO pet:
ALTER TABLE pet_virtual ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_virtual FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_pet ON pet_virtual FOR SELECT TO app_user
    USING (
        id_idoso = fn_meu_id_idoso()
        OR id_idoso IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR fn_ilpi_do_idoso(id_idoso) = fn_minha_ilpi_profissional()
    );

CREATE POLICY upd_pet_dono ON pet_virtual FOR UPDATE TO app_user
    USING (id_idoso = fn_meu_id_idoso())
    WITH CHECK (id_idoso = fn_meu_id_idoso());

-- gestor cria pet ao cadastrar idoso (política de INSERT):
CREATE POLICY ins_pet_gestor ON pet_virtual FOR INSERT TO app_user
    WITH CHECK (fn_sou_gestor() OR id_idoso = fn_meu_id_idoso());

COMMIT;
