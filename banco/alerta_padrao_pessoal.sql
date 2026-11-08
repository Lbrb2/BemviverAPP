-- ============================================================
-- Bem Viver ILPI — Alerta pelo padrão pessoal de cada residente
-- Executar depois da Etapa 05 (usa fn_classificar_pressao).
-- Pode ser executado mais de uma vez.
-- A demonstração está em banco/exemplos/alerta_padrao_pessoal_demonstracao.sql.
--
-- A ideia: o trigger da Etapa 05 (trg_alerta_sinal_vital) usa faixas fixas,
-- iguais para todos. Mas o "normal" muda de pessoa para pessoa: 150 de
-- sistólica é rotina para um hipertenso controlado e é um salto para quem
-- vive com 115. Este arquivo compara cada nova aferição com o histórico do
-- PRÓPRIO residente e avisa quando ela foge muito do padrão dele, mesmo
-- dentro da faixa geral.
--
-- Como "foge muito" é decidido (detecção de anomalia por escore z):
--   padrão     média e desvio padrão das últimas 10 aferições daquela medida,
--              nos 120 dias anteriores (mínimo de 4 aferições)
--   escore z   (valor − média) / desvio: quantos desvios o valor está da média
--   alerta     |z| >= 2,5  E  diferença absoluta >= um mínimo clínico
-- As duas condições juntas evitam alarme falso: só o z dispararia para quem
-- tem medidas muito estáveis (desvio quase zero), e só a diferença ignoraria
-- quem varia muito naturalmente. O desvio também tem um piso, pelo mesmo motivo.
--
--   medida          piso do desvio   diferença mínima
--   pressao_sis       6 mmHg           20 mmHg
--   pressao_dia       4 mmHg           12 mmHg
--   freq_cardiaca     5 bpm            20 bpm
--   temperatura       0,3 °C           0,8 °C
--   glicemia         10 mg/dL          50 mg/dL
--   saturacao         1 ponto           4 pontos
--
-- Não é diagnóstico: é um aviso para a equipe olhar com mais atenção.
-- ============================================================

SET client_min_messages = warning;


-- ------------------------------------------------------------
-- 1. O padrão de um residente para uma medida
-- ------------------------------------------------------------
-- Devolve a média, o desvio padrão amostral e quantas aferições entraram:
-- as últimas 10 daquela medida, nos 120 dias anteriores a p_antes (assim a
-- aferição nova não entra no próprio padrão). SECURITY INVOKER (o padrão):
-- pela aplicação, o RLS garante que só a equipe da ILPI do residente vê os dados.
CREATE OR REPLACE FUNCTION fn_padrao_pessoal(
    p_id_idoso int,
    p_medida   text,
    p_antes    timestamptz DEFAULT now())
RETURNS TABLE (media numeric, desvio numeric, n int)
LANGUAGE sql
STABLE
AS $$
    SELECT round(avg(v), 1), round(stddev_samp(v), 2), count(v)::int
      FROM (SELECT v
              FROM (SELECT s.data_hora,
                           CASE p_medida
                               WHEN 'pressao_sis'   THEN s.pressao_sis::numeric
                               WHEN 'pressao_dia'   THEN s.pressao_dia::numeric
                               WHEN 'freq_cardiaca' THEN s.freq_cardiaca::numeric
                               WHEN 'temperatura'   THEN s.temperatura
                               WHEN 'glicemia'      THEN s.glicemia::numeric
                               WHEN 'saturacao'     THEN s.saturacao::numeric
                           END AS v
                      FROM sinal_vital s
                     WHERE s.id_idoso = p_id_idoso
                       AND s.data_hora <  p_antes
                       AND s.data_hora >= p_antes - INTERVAL '120 days') t
             WHERE v IS NOT NULL
             ORDER BY data_hora DESC
             LIMIT 10) ultimas
$$;


-- ------------------------------------------------------------
-- 2. Um valor está fora do padrão do residente?
-- ------------------------------------------------------------
-- Estrutura condicional (CASE) para os limites de cada medida e para a decisão.
CREATE OR REPLACE FUNCTION fn_fora_do_padrao(
    p_id_idoso int,
    p_medida   text,
    p_valor    numeric,
    p_quando   timestamptz DEFAULT now())
RETURNS TABLE (media numeric, desvio numeric, n int, z numeric, fora boolean)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_piso  numeric;   -- menor desvio aceito
    v_dif   numeric;   -- menor diferença clinicamente relevante
BEGIN
    v_piso := CASE p_medida
                  WHEN 'pressao_sis'   THEN 6   WHEN 'pressao_dia' THEN 4
                  WHEN 'freq_cardiaca' THEN 5   WHEN 'temperatura' THEN 0.3
                  WHEN 'glicemia'      THEN 10  WHEN 'saturacao'   THEN 1
              END;
    v_dif  := CASE p_medida
                  WHEN 'pressao_sis'   THEN 20  WHEN 'pressao_dia' THEN 12
                  WHEN 'freq_cardiaca' THEN 20  WHEN 'temperatura' THEN 0.8
                  WHEN 'glicemia'      THEN 50  WHEN 'saturacao'   THEN 4
              END;
    IF v_piso IS NULL THEN
        RAISE EXCEPTION 'Medida desconhecida: %', p_medida;
    END IF;

    SELECT p.media, p.desvio, p.n INTO media, desvio, n
      FROM fn_padrao_pessoal(p_id_idoso, p_medida, p_quando) p;

    -- sem histórico suficiente, não há padrão para comparar
    IF p_valor IS NULL OR n < 4 THEN
        z := NULL; fora := false;
        RETURN NEXT; RETURN;
    END IF;

    z := round((p_valor - media) / greatest(coalesce(desvio, 0), v_piso), 1);
    fora := abs(z) >= 2.5 AND abs(p_valor - media) >= v_dif;
    RETURN NEXT;
END $$;

GRANT EXECUTE ON FUNCTION fn_padrao_pessoal(int, text, timestamptz)         TO app_user;
GRANT EXECUTE ON FUNCTION fn_fora_do_padrao(int, text, numeric, timestamptz) TO app_user;


-- ------------------------------------------------------------
-- 3. Trigger: aferição fora do padrão pessoal vira recado de atenção
-- ------------------------------------------------------------
-- Roda ao lado do trg_alerta_sinal_vital da Etapa 05, sem substituí-lo.
-- Para não avisar duas vezes, ignora as medidas que já estão fora da faixa
-- GERAL (essas o trigger da Etapa 05 já transformou em recado). O que sobra
-- é justamente o caso que as faixas fixas não pegam: um valor "normal" para
-- a população, mas incomum para esta pessoa.
-- SECURITY DEFINER pelo mesmo motivo do trigger da Etapa 05: o recado é
-- criado pelo sistema, mesmo que quem aferiu não escreva no plantão.
CREATE OR REPLACE FUNCTION fn_trg_alerta_padrao_pessoal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_classe   varchar(30) := fn_classificar_pressao(NEW.pressao_sis, NEW.pressao_dia);
    v_medidas  text[]    := ARRAY['pressao_sis','pressao_dia','freq_cardiaca','temperatura','glicemia','saturacao'];
    v_nomes    text[]    := ARRAY['PA sistólica','PA diastólica','frequência cardíaca','temperatura','glicemia','saturação'];
    v_unid     text[]    := ARRAY[' mmHg',' mmHg',' bpm',' °C',' mg/dL','%'];
    v_valores  numeric[] := ARRAY[NEW.pressao_sis, NEW.pressao_dia, NEW.freq_cardiaca,
                                  NEW.temperatura, NEW.glicemia, NEW.saturacao];
    v_geral    boolean[];
    v_achados  text[] := '{}';
    r          record;
    v_hora     int;
    v_turno    turno_plantao;
    v_nome     varchar;
    v_id_ilpi  int;
BEGIN
    -- quais medidas já estão fora da faixa geral (mesmas regras da Etapa 05)
    v_geral := ARRAY[
        v_classe IN ('Hipertensão estágio 2','Hipertensão estágio 3','Hipotensão'),
        v_classe IN ('Hipertensão estágio 2','Hipertensão estágio 3','Hipotensão'),
        coalesce(NEW.freq_cardiaca < 50 OR NEW.freq_cardiaca > 120, false),
        coalesce(NEW.temperatura >= 37.8, false),
        coalesce(NEW.glicemia < 70 OR NEW.glicemia > 250, false),
        coalesce(NEW.saturacao < 92, false)];

    FOR i IN 1 .. array_length(v_medidas, 1) LOOP
        CONTINUE WHEN v_valores[i] IS NULL OR v_geral[i];
        SELECT * INTO r FROM fn_fora_do_padrao(NEW.id_idoso, v_medidas[i], v_valores[i], NEW.data_hora);
        IF r.fora THEN
            -- números com vírgula decimal, como se escreve no Brasil
            v_achados := v_achados || format('%s %s%s (o habitual é %s ± %s, em %s aferições)',
                v_nomes[i], replace(v_valores[i]::text, '.', ','), v_unid[i],
                replace(to_char(r.media, 'FM999990.0'), '.', ','),
                replace(to_char(r.desvio, 'FM999990.0'), '.', ','), r.n);
        END IF;
    END LOOP;

    IF cardinality(v_achados) = 0 THEN
        RETURN NEW;
    END IF;

    v_hora := extract(hour FROM NEW.data_hora AT TIME ZONE 'America/Recife');
    v_turno := CASE WHEN v_hora >= 7  AND v_hora < 13 THEN 'manha'
                    WHEN v_hora >= 13 AND v_hora < 19 THEN 'tarde'
                    ELSE 'noite' END;

    SELECT nome, id_ilpi INTO v_nome, v_id_ilpi FROM idoso WHERE id_idoso = NEW.id_idoso;

    INSERT INTO recado_plantao (id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, data_hora)
    VALUES (v_id_ilpi, NEW.id_profissional, NEW.id_idoso, v_turno, 'atencao',
            format('[Alerta automático] Fora do padrão de %s: %s. Está dentro da faixa geral, mas é incomum para essa pessoa. Reavaliar.',
                   v_nome, array_to_string(v_achados, '; ')),
            NEW.data_hora);
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_alerta_padrao_pessoal ON sinal_vital;
CREATE TRIGGER trg_alerta_padrao_pessoal
AFTER INSERT ON sinal_vital
FOR EACH ROW
EXECUTE FUNCTION fn_trg_alerta_padrao_pessoal();


-- ------------------------------------------------------------
-- 4. Visão: aferições dos últimos 30 dias fora do padrão pessoal
-- ------------------------------------------------------------
-- Uma linha por medida fora do padrão, com o valor, o padrão e o escore z.
-- security_invoker: respeita o RLS de quem consulta (cada equipe vê a sua ILPI).
CREATE OR REPLACE VIEW vw_sinal_fora_do_padrao
WITH (security_invoker = true) AS
SELECT s.id_sinal, s.id_idoso, i.nome AS residente, s.data_hora,
       m.medida, m.valor, f.media, f.desvio, f.n AS afericoes_no_padrao, f.z
  FROM sinal_vital s
  JOIN idoso i ON i.id_idoso = s.id_idoso
 CROSS JOIN LATERAL (VALUES
        ('pressao_sis',   s.pressao_sis::numeric),
        ('pressao_dia',   s.pressao_dia::numeric),
        ('freq_cardiaca', s.freq_cardiaca::numeric),
        ('temperatura',   s.temperatura),
        ('glicemia',      s.glicemia::numeric),
        ('saturacao',     s.saturacao::numeric)) AS m(medida, valor)
 CROSS JOIN LATERAL fn_fora_do_padrao(s.id_idoso, m.medida, m.valor, s.data_hora) f
 WHERE m.valor IS NOT NULL
   AND s.data_hora >= now() - INTERVAL '30 days'
   AND f.fora;

GRANT SELECT ON vw_sinal_fora_do_padrao TO app_user;
