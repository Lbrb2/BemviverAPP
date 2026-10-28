// ============================================================
// IA do Buraco v3 — planeja canastras (não gulosa)
// A IA mantém "projetos": o melhor grupo por naipe (sequência) e por
// valor (trinca). Concentra curingas nos projetos mais maduros.
// Só baixa quando tem canastra OU quando já bateu o gatilho de baixar.
// Descarta o que não serve a nenhum projeto.
// ============================================================
import { validarJogo, ehCuringa, pontosCarta, ehCanastra } from "./motor.mjs";
const ORDEM = { A:1,"2":2,"3":3,"4":4,"5":5,"6":6,"7":7,"8":8,"9":9,"10":10,J:11,Q:12,K:13 };

// Identifica o melhor conjunto de grupos "naturais" (sem quebrar) da mão.
function projetos(mao) {
  const naturais = mao.filter((c) => !ehCuringa(c));
  const grupos = [];

  // trincas: por valor
  const porValor = {};
  for (const c of naturais) (porValor[c.v] = porValor[c.v] || []).push(c);
  for (const v in porValor) if (porValor[v].length >= 2) grupos.push({ tipo: "trinca", cartas: porValor[v], chave: "V" + v });

  // sequências: por naipe, maior corrida
  const porNaipe = {};
  for (const c of naturais) (porNaipe[c.n] = porNaipe[c.n] || []).push(c);
  for (const n in porNaipe) {
    const ord = [...new Map(porNaipe[n].map((c) => [c.v, c])).values()].sort((a, b) => ORDEM[a.v] - ORDEM[b.v]);
    let run = [];
    for (const c of ord) {
      if (run.length === 0 || ORDEM[c.v] === ORDEM[run[run.length-1].v] + 1) run.push(c);
      else { if (run.length >= 2) grupos.push({ tipo: "seq", cartas: [...run], chave: "N" + n + run[0].v }); run = [c]; }
    }
    if (run.length >= 2) grupos.push({ tipo: "seq", cartas: [...run], chave: "N" + n + run[0].v });
  }
  // ordenar por tamanho (mais maduros primeiro)
  return grupos.sort((a, b) => b.cartas.length - a.cartas.length);
}

export function turnoIA(estado, idx, opcoes = {}) {
  const mao = estado.maos[idx];
  // comprar sempre do monte (previsível, sem loop). Pegar o lixo virá numa versão futura.
  if (estado.monte.length > 0) mao.push(estado.monte.shift());

  // reavaliar projetos e alocar curingas nos mais maduros
  let curingas = mao.filter(ehCuringa);
  const grupos = projetos(mao);
  const temCanastra = estado.jogos[idx].some((j) => ehCanastra(j));
  const fechando = estado.monte.length < 20; // reta final: desafogar a mão

  const baixados = [];
  for (const g of grupos) {
    let cartas = [...g.cartas];
    // alimentar com curingas se está a 1-2 de virar canastra (>=5) ou de virar jogo válido (==2)
    while (curingas.length > 0 && ((cartas.length >= 5 && cartas.length < 7) || cartas.length === 2)) {
      // só adiciona curinga se o jogo continua válido
      const tentativa = [...cartas, curingas[0]];
      if (validarJogo(tentativa).valido) { cartas.push(curingas.shift()); }
      else break;
    }
    const valido = validarJogo(cartas).valido;
    const canastra = cartas.length >= 7;
    // baixar se: virou canastra, OU já temos canastra (aí baixa tudo válido), OU mão muito cheia
    if (valido && (canastra || temCanastra || mao.length > 14 || fechando)) {
      baixados.push(cartas);
    }
  }
  // aplicar baixadas (removendo da mão)
  for (const jogo of baixados) {
    const ids = new Set(jogo.map((c) => c.id));
    if ([...ids].some((id) => !estado.maos[idx].find((m) => m.id === id))) continue;
    estado.maos[idx] = estado.maos[idx].filter((c) => !ids.has(c.id));
    estado.jogos[idx].push(jogo);
  }

  // descartar: a carta que menos serve a qualquer projeto
  let maoAtual = estado.maos[idx];
  if (maoAtual.length > 0) {
    const gs = projetos(maoAtual);
    const emProjeto = new Set();
    for (const g of gs) if (g.cartas.length >= 2) g.cartas.forEach((c) => emProjeto.add(c.id));
    const foraProjeto = maoAtual.filter((c) => !ehCuringa(c) && !emProjeto.has(c.id));
    const candidatos = foraProjeto.length > 0 ? foraProjeto : maoAtual.filter((c) => !ehCuringa(c));
    const desc = (candidatos.length > 0 ? candidatos : maoAtual)
      .sort((a, b) => pontosCarta(b.v) - pontosCarta(a.v))[0]; // descarta a mais cara que não serve
    estado.maos[idx] = maoAtual.filter((c) => c.id !== desc.id);
    estado.descarte.push(desc);
  }

  // pegar morto
  if (estado.maos[idx].length === 0 && !estado.pegouMorto[idx] && estado.mortos[idx]) {
    estado.maos[idx] = estado.mortos[idx];
    estado.pegouMorto[idx] = true;
    estado.mortos[idx] = null;
  }
  return estado;
}

export function podeBater(estado, idx) {
  return estado.maos[idx].length === 0 && estado.pegouMorto[idx] &&
         estado.jogos[idx].some((j) => ehCanastra(j));
}
export { projetos };
