// Gera, a partir dos SQLs que a API executa (fonte única):
//   ../consultas_etapa03.sql                                (consultas 1 a 10)
//   ../entregas_bd/etapa04/etapa04_consultas_na_interface.sql (11 a 16)
//   ../entregas_bd/etapa06/etapa06_sql_dashboard.sql        (dashboard)
// Uso: node gerar_sql_consultas.js
import { writeFileSync } from "node:fs";
import { CONSULTAS } from "./consultas.js";
import { DASHBOARD } from "./dashboard.js";

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
--
-- Período como parâmetro: as consultas com janela de tempo usam $1 (nº de
-- dias). Na API, o valor vai separado do SQL — c.query(sql, [dias]) —; aqui
-- o mesmo SQL é preparado (PREPARE) e executado com o período padrão
-- (EXECUTE). Para outro período, basta trocar o número no EXECUTE.
-- ============================================================

-- Horários de medicação são hora local de Pernambuco (a API faz o mesmo).
SET TIME ZONE 'America/Recife';
`;
// Descrição do gráfico para o comentário
const descGrafico = (g) => g.tipo === "pizza"
  ? `pizza com a contagem de linhas por ${g.contar}`
  : `${g.tipo} de ${g.y.join(" e ")} por ${g.x}`;

// Parâmetros na ordem: período ($1) e/ou filtro (texto)
function bloco(c) {
  const tipos = [], valores = [], linhasParam = [];
  if (c.periodo) {
    tipos.push("int"); valores.push(c.periodo.padrao);
    linhasParam.push(`--    Parâmetro $${tipos.length}: período em dias (na tela: ${c.periodo.opcoes.join(", ")}; padrão ${c.periodo.padrao})\n`);
  }
  if (c.filtro) {
    tipos.push("text"); valores.push(`'${c.filtro.padrao}'`);
    linhasParam.push(`--    Parâmetro $${tipos.length}: ${c.filtro.rotulo.toLowerCase()} (na tela: ${c.filtro.opcoes.map(([v]) => v).join(", ")}; padrão ${c.filtro.padrao})\n`);
  }
  return `\n-- ------------------------------------------------------------\n` +
    `-- ${c.id}) ${c.titulo}\n` +
    `--    Pergunta: ${c.pergunta}\n` +
    `--    Técnicas: ${c.tecnicas.join(", ")}\n` +
    `--    Gráfico na interface: ${descGrafico(c.grafico)}\n` +
    linhasParam.join("") +
    `-- ------------------------------------------------------------\n` +
    (tipos.length
      ? `PREPARE consulta_${c.id}(${tipos.join(", ")}) AS\n${c.sql};\nEXECUTE consulta_${c.id}(${valores.join(", ")});\n`
      : c.sql + ";\n");
}

// Etapa 03: consultas 1 a 10 (arquivo na raiz, como foi entregue)
const etapa3 = CONSULTAS.filter((c) => (c.etapa || 3) === 3);
writeFileSync(new URL("../consultas_etapa03.sql", import.meta.url), cab + etapa3.map(bloco).join(""));
console.log(`consultas_etapa03.sql gerado com ${etapa3.length} consultas.`);

// Etapa 04: consultas 11 a 14 e as visões (15 e 16), como a interface executa
const cab4 = cab
  .replace("Consultas implementadas na interface (Etapa 03)", "Consultas da Etapa 04 como a interface executa")
  .replace("Executar após schema_ilpi.sql e seed_ilpi.sql.",
           "Executar após a instalação completa (inclui etapa04_indices_e_visoes.sql).\n" +
           "-- A versão comentada, com as justificativas, é etapa04_consultas.sql.")
  .replace("Período como parâmetro: as consultas com janela de tempo usam $1 (nº de\n-- dias).",
           "Período e filtro como parâmetros: $1 = nº de dias e/ou o filtro escolhido\n-- na tela.");
const etapa4 = CONSULTAS.filter((c) => c.etapa === 4);
writeFileSync(new URL("../entregas_bd/etapa04/etapa04_consultas_na_interface.sql", import.meta.url), cab4 + etapa4.map(bloco).join(""));
console.log(`etapa04_consultas_na_interface.sql gerado com ${etapa4.length} consultas.`);

// Etapa 06: os SQLs do dashboard (api/dashboard.js), na ordem do painel
const cab6 = `-- ============================================================
-- Bem Viver ILPI — SQL do dashboard estatístico (Etapa 06)
-- Arquivo GERADO a partir de api/dashboard.js: são exatamente os comandos
-- que a aba "📈 Dashboard" do gestor executa a cada filtro.
-- Parâmetros: $1 = período em dias (7, 30, 90, 180) e $2 = grau de
-- dependência ('todos', 'I', 'II', 'III'). Aqui: 30 dias e todos.
-- Rodando como superusuário, as funções que dependem do usuário logado
-- (fn_minha_ilpi_profissional) devolvem NULL; na aplicação, o RLS
-- recorta tudo para a ILPI do gestor.
-- ============================================================
SET TIME ZONE 'America/Recife';
`;
let n6 = 0;
const prep = (nome, sql, tipos, valores) => {
  n6++;
  return `\n-- ---------- ${nome} ----------\nPREPARE dash_${n6}${tipos.length ? `(${tipos.join(", ")})` : ""} AS\n${sql};\nEXECUTE dash_${n6}${valores.length ? `(${valores.join(", ")})` : ""};\n`;
};
const P = [["int", "text"], ["30", "'todos'"]];
let corpo6 = "";
for (const [nome, sql] of Object.entries(DASHBOARD)) {
  if (typeof sql === "object") {
    for (const [medida, q] of Object.entries(sql)) corpo6 += prep(`${nome} (${medida})`, q, ...P);
  } else if (nome === "adesao") corpo6 += prep(nome, sql, ["text"], ["'todos'"]);
  else if (nome === "residentes_grau") corpo6 += prep(nome, sql, [], []);
  else corpo6 += prep(nome, sql, ...P);
}
writeFileSync(new URL("../entregas_bd/etapa06/etapa06_sql_dashboard.sql", import.meta.url), cab6 + corpo6);
console.log(`etapa06_sql_dashboard.sql gerado com ${n6} comandos.`);
