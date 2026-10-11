// ============================================================
// PACIÊNCIA (Klondike) — motor
// 7 colunas (tableau), 4 fundações (por naipe, A→K), monte, descarte.
// ============================================================
const NAIPES = ["♠", "♥", "♦", "♣"];
const VERMELHO = new Set(["♥", "♦"]);
const VALORES = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];
const ORDEM = { A:1,"2":2,"3":3,"4":4,"5":5,"6":6,"7":7,"8":8,"9":9,"10":10,J:11,Q:12,K:13 };

export function criarBaralho() {
  const c = [];
  for (const n of NAIPES) for (const v of VALORES) c.push({ v, n, id: `${v}${n}`, virada: false });
  return c;
}
export function embaralhar(a) {
  const b = [...a];
  for (let i = b.length - 1; i > 0; i--) { const j = Math.floor(Math.random()*(i+1)); [b[i],b[j]]=[b[j],b[i]]; }
  return b;
}

// Distribuição Klondike: coluna i recebe i+1 cartas, só a última virada
export function distribuir() {
  const baralho = embaralhar(criarBaralho());
  const colunas = [[], [], [], [], [], [], []];
  for (let i = 0; i < 7; i++) {
    for (let j = 0; j <= i; j++) {
      const carta = baralho.pop();
      carta.virada = (j === i); // última da coluna vem virada
      colunas[i].push(carta);
    }
  }
  return {
    colunas,
    fundacoes: { "♠": [], "♥": [], "♦": [], "♣": [] },
    monte: baralho.map((c) => ({ ...c, virada: false })),
    descarte: [],
  };
}

const ehVermelho = (c) => VERMELHO.has(c.n);
const corAlterna = (a, b) => ehVermelho(a) !== ehVermelho(b);

// Pode colocar carta na fundação? (mesmo naipe, valor seguinte)
export function podeNaFundacao(fund, carta) {
  const pilha = fund[carta.n];
  if (pilha.length === 0) return carta.v === "A";
  return ORDEM[carta.v] === ORDEM[pilha[pilha.length - 1].v] + 1;
}

// Pode colocar carta(s) numa coluna do tableau? (cor alternada, valor decrescente)
export function podeNaColuna(coluna, carta) {
  if (coluna.length === 0) return carta.v === "K"; // só rei em coluna vazia
  const topo = coluna[coluna.length - 1];
  if (!topo.virada) return false;
  return corAlterna(topo, carta) && ORDEM[topo.v] === ORDEM[carta.v] + 1;
}

// Vitória: todas as 52 nas fundações
export function venceu(estado) {
  return Object.values(estado.fundacoes).reduce((s, p) => s + p.length, 0) === 52;
}
