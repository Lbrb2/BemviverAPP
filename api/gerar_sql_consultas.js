// Gera ../consultas_etapa03.sql a partir de consultas.js (fonte única).
// Uso: node gerar_sql_consultas.js
import { writeFileSync } from "node:fs";
import { CONSULTAS } from "./consultas.js";

const cab = `-- ============================================================
-- Bem Viver ILPI — Consultas implementadas na interface (Etapa 03)
-- Arquivo GERADO a partir de api/consultas.js: são exatamente os SQLs
-- que a tela "📊 Consultas" do gestor executa.
--
-- Na aplicação, cada consulta roda dentro de uma transação com a
-- identidade do usuário (set_config('app.id_usuario', ...)), e o RLS
-- limita o resultado à ILPI do gestor. Rodando aqui como superusuário,
-- o resultado inclui todas as ILPIs.
-- Executar após schema_ilpi.sql e seed_ilpi.sql.
-- ============================================================

-- Horários de medicação são hora local de Pernambuco (a API faz o mesmo).
SET TIME ZONE 'America/Recife';
`;
const corpo = CONSULTAS.map((c) =>
  `\n-- ------------------------------------------------------------\n` +
  `-- ${c.id}) ${c.titulo}\n` +
  `--    Pergunta: ${c.pergunta}\n` +
  `--    Técnicas: ${c.tecnicas.join(", ")}\n` +
  `--    Gráfico na interface: ${c.grafico.tipo} de ${c.grafico.y.join(" e ")} por ${c.grafico.x}\n` +
  `-- ------------------------------------------------------------\n` +
  c.sql + ";\n").join("");
writeFileSync(new URL("../consultas_etapa03.sql", import.meta.url), cab + corpo);
console.log(`consultas_etapa03.sql gerado com ${CONSULTAS.length} consultas.`);
