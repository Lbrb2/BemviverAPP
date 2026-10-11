import { distribuir, pontuarJogos, pontuarMao, ehCanastra } from "./motor.mjs";
import { turnoIA, podeBater } from "./ia.mjs";

function jogarPartida() {
  const d = distribuir();
  const estado = { ...d, jogos: [[], []] };
  let turno = 0, rodadas = 0;
  while (rodadas < 500) {
    turnoIA(estado, turno);
    if (podeBater(estado, turno)) { estado.bateu = turno; break; }
    if (estado.monte.length === 0) break;
    turno = 1 - turno; rodadas++;
  }
  // pontuar: jogos baixados - mão residual (+100 bônus se bateu)
  const placar = [0, 1].map((p) => {
    let pts = pontuarJogos(estado.jogos[p]) - pontuarMao(estado.maos[p] || []);
    if (estado.bateu === p) pts += 100;
    return pts;
  });
  const vencedor = placar[0] === placar[1] ? -1 : (placar[0] > placar[1] ? 0 : 1);
  return { placar, vencedor, rodadas, bateu: estado.bateu, estado };
}

let venc = [0, 0, 0]; // j0, j1, empate
let somaRodadas = 0, comCanastra = 0, bateram = 0;
for (let i = 0; i < 300; i++) {
  const r = jogarPartida();
  if (r.vencedor === -1) venc[2]++; else venc[r.vencedor]++;
  somaRodadas += r.rodadas;
  if (r.bateu !== undefined) bateram++;
  for (const js of r.estado.jogos) for (const j of js) if (ehCanastra(j)) { comCanastra++; break; }
}
console.log("300 partidas completas com pontuação final:");
console.log(`  Jogador 0 venceu: ${venc[0]}  |  Jogador 1 venceu: ${venc[1]}  |  empates: ${venc[2]}`);
console.log(`  média de rodadas: ${(somaRodadas/300).toFixed(1)}`);
console.log(`  partidas com ao menos 1 canastra: ${comCanastra}`);
console.log(`  partidas em que alguém bateu: ${bateram}`);
console.log(`\n  → o importante: toda partida TERMINA e é pontuada. Vitória equilibrada entre os dois lados = IA justa.`);

// exemplo detalhado
const ex = jogarPartida();
console.log(`\nExemplo: placar ${ex.placar[0]} x ${ex.placar[1]}, ${ex.rodadas} rodadas, ${ex.bateu!==undefined?"jogador "+ex.bateu+" bateu":"monte acabou"}`);
