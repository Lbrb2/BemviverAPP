-- ============================================================
-- Migração 012: Escalas guiadas
-- As avaliações já existiam (tabela avaliacao + item_avaliacao),
-- mas a pontuação era digitada. Aqui guardamos as respostas item
-- a item e a interpretação. As perguntas ficam no app; o banco
-- guarda o resultado estruturado e a faixa interpretada.
-- ============================================================

BEGIN;

-- interpretação textual do resultado (ex.: "sugestivo de depressão leve")
ALTER TABLE avaliacao ADD COLUMN IF NOT EXISTS interpretacao VARCHAR(120);

COMMIT;
