// ============================================================
// MOTOR DO BURACO 1x1 — regras e pontuação (sem interface)
// Testável isoladamente. Depois vira a base do componente React.
// ============================================================

// Baralho: 2 baralhos completos = 108 cartas (52*2 + 4 coringas)
const NAIPES = ["♠", "♥", "♦", "♣"];
const VALORES = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];

// valor de pontos de cada carta (para somar jogos e contar mão)
export function pontosCarta(v) {
  if (v === "Joker") return 20;      // coringa
  if (v === "2") return 20;          // 2 é curinga também, vale 20
  if (v === "A") return 15;
  if (["8", "9", "10", "J", "Q", "K"].includes(v)) return 10;
  return 5;                          // 3,4,5,6,7
}

export function criarBaralho() {
  const cartas = [];
  for (let d = 0; d < 2; d++) {
    for (const n of NAIPES) for (const v of VALORES) cartas.push({ v, n, id: `${v}${n}_${d}` });
    cartas.push({ v: "Joker", n: "★", id: `Joker_a_${d}` });
    cartas.push({ v: "Joker", n: "★", id: `Joker_b_${d}` });
  }
  return cartas; // 108
}

export function embaralhar(a) {
  const b = [...a];
  for (let i = b.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [b[i], b[j]] = [b[j], b[i]]; }
  return b;
}

// Distribuição 1x1: 11 cartas para cada jogador, 2 mortos de 11, resto no monte
export function distribuir() {
  const baralho = embaralhar(criarBaralho());
  const mao1 = baralho.splice(0, 11);
  const mao2 = baralho.splice(0, 11);
  const morto1 = baralho.splice(0, 11);
  const morto2 = baralho.splice(0, 11);
  const descarte = [baralho.splice(0, 1)[0]]; // primeira carta vira o lixo
  return { maos: [mao1, mao2], mortos: [morto1, morto2], monte: baralho, descarte, pegouMorto: [false, false] };
}

// ---------- Validação de jogos ----------
// Curingas: Joker sempre; o "2" pode ser curinga OU carta natural na sequência de 2.
export const ehCuringa = (c) => c.v === "Joker" || c.v === "2";

// Sequência: mesmo naipe, valores consecutivos (A pode ser baixo A-2-3 ou alto Q-K-A)
const ORDEM = { A: 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10, J: 11, Q: 12, K: 13 };

// valida um conjunto como jogo válido (trinca ou sequência), retorna {valido, tipo, limpa}
export function validarJogo(cartas) {
  if (cartas.length < 3) return { valido: false };
  const curingas = cartas.filter(ehCuringa);
  const naturais = cartas.filter((c) => !ehCuringa(c));
  if (naturais.length === 0) return { valido: false };

  // TRINCA: todas as naturais com mesmo valor
  const mesmoValor = naturais.every((c) => c.v === naturais[0].v);
  if (mesmoValor && cartas.length >= 3) {
    // trinca válida se naturais + curingas >= 3 e no máx 1 curinga para ser "limpa"
    const limpa = curingas.length === 0;
    return { valido: true, tipo: "trinca", limpa, valor: naturais[0].v };
  }

  // SEQUÊNCIA: mesmo naipe, consecutivos (curingas preenchem buracos)
  const mesmoNaipe = naturais.every((c) => c.n === naturais[0].n);
  if (mesmoNaipe) {
    // tentar montar sequência: ordenar naturais, ver se curingas preenchem
    const posicoes = naturais.map((c) => ORDEM[c.v]).sort((a, b) => a - b);
    // sem valores repetidos nas naturais
    if (new Set(posicoes).size !== posicoes.length) return { valido: false };
    const min = posicoes[0], max = posicoes[posicoes.length - 1];
    const span = max - min + 1;
    const buracos = span - naturais.length;
    if (buracos <= curingas.length && span <= 13) {
      const curingasSobrando = curingas.length - buracos;
      // curingas que sobram estendem as pontas; ok se cabe em 13
      if (naturais.length + curingas.length <= 13) {
        const limpa = curingas.length === 0;
        return { valido: true, tipo: "sequencia", limpa, naipe: naturais[0].n };
      }
    }
  }
  return { valido: false };
}

// Canastra = jogo com 7+ cartas. Limpa (sem curinga) = 200, suja (com curinga) = 100
export function ehCanastra(cartas) {
  const val = validarJogo(cartas);
  if (!val.valido || cartas.length < 7) return null;
  return { limpa: val.limpa, pontos: val.limpa ? 200 : 100 };
}

// Pontuação de um jogo baixado (soma das cartas + bônus de canastra)
export function pontuarJogos(jogos) {
  let total = 0;
  for (const jogo of jogos) {
    for (const c of jogo) total += pontosCarta(c.v);
    const can = ehCanastra(jogo);
    if (can) total += can.pontos;
  }
  return total;
}

// Pontos negativos das cartas que sobraram na mão
export function pontuarMao(mao) {
  return mao.reduce((s, c) => s + pontosCarta(c.v), 0);
}
