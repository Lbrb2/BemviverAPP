-- ============================================================
-- Migração 001: Dominó do Lar
-- Adiciona o dominó como fonte de pontos do pet e cria a
-- tabela de partidas (dados de interação social e cognitiva).
-- Executar em bancos que já rodaram schema_ilpi.sql.
-- ============================================================

-- Novo valor de enum (fora de transação por segurança em versões antigas)
ALTER TYPE origem_evento_pet ADD VALUE IF NOT EXISTS 'partida_domino';

BEGIN;

-- ---------- Partidas de dominó ----------
-- jogador2 NULL = partida contra o computador ("Seu Biu").
-- Partidas entre dois idosos são dado de interação social —
-- domínio que o ICOPE e o WHOQOL-OLD mandam acompanhar.
CREATE TABLE partida_domino (
    id_partida  SERIAL PRIMARY KEY,
    id_ilpi     INT NOT NULL REFERENCES ilpi(id_ilpi),
    id_jogador1 INT NOT NULL REFERENCES idoso(id_idoso),
    id_jogador2 INT REFERENCES idoso(id_idoso),
    vencedor    SMALLINT CHECK (vencedor IN (1, 2)), -- NULL = partida abandonada
    motivo      VARCHAR(20) NOT NULL CHECK (motivo IN ('bateu', 'fechado', 'abandono')),
    data_hora   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_jogadores_diferentes CHECK (id_jogador2 IS NULL OR id_jogador1 <> id_jogador2)
);

CREATE INDEX ix_partida_j1_data ON partida_domino (id_jogador1, data_hora DESC);
CREATE INDEX ix_partida_j2_data ON partida_domino (id_jogador2, data_hora DESC)
    WHERE id_jogador2 IS NOT NULL;

-- ---------- RLS (mesmo padrão das demais tabelas) ----------
ALTER TABLE partida_domino ENABLE ROW LEVEL SECURITY;
ALTER TABLE partida_domino FORCE ROW LEVEL SECURITY;

CREATE POLICY sel_partida ON partida_domino FOR SELECT TO app_user
    USING (
        id_ilpi = fn_minha_ilpi_profissional()
        OR id_jogador1 IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR id_jogador2 IN (SELECT fn_idosos_sob_minha_responsabilidade())
        OR id_jogador1 = fn_meu_id_idoso()
        OR id_jogador2 = fn_meu_id_idoso()
    );

CREATE POLICY ins_partida_self ON partida_domino FOR INSERT TO app_user
    WITH CHECK (
        id_jogador1 = fn_meu_id_idoso()
        AND id_ilpi = fn_ilpi_do_idoso(id_jogador1)
    );

CREATE POLICY ins_partida_equipe ON partida_domino FOR INSERT TO app_user
    WITH CHECK (
        id_ilpi = fn_minha_ilpi_profissional()
        AND id_ilpi = fn_ilpi_do_idoso(id_jogador1)
    );

GRANT SELECT, INSERT ON partida_domino TO app_user;
GRANT USAGE ON SEQUENCE partida_domino_id_partida_seq TO app_user;

COMMIT;

-- ---------- Consulta bônus: rede social do dominó ----------
-- Quem joga com quem nos últimos 30 dias (pares mais frequentes)
-- SELECT i1.nome AS jogador1, i2.nome AS jogador2, count(*) AS partidas
--   FROM partida_domino p
--   JOIN idoso i1 ON i1.id_idoso = p.id_jogador1
--   JOIN idoso i2 ON i2.id_idoso = p.id_jogador2
--  WHERE p.data_hora >= now() - INTERVAL '30 days'
--  GROUP BY i1.nome, i2.nome
--  ORDER BY partidas DESC;
