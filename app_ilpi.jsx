import { useState, useEffect } from "react";

// ============================================================
// Bem Viver ILPI — app multi-perfil
// Um login, três experiências:
//   idoso        → check-in diário de bem-estar (alimenta o pet)
//   responsavel  → painel dos seus idosos + evolução do humor
//   profissional → alertas de inatividade + residentes + lançamento
// Mesma linguagem visual do Dominó do Lar. O recorte de dados é
// decidido pelo RLS no banco: o app chama os MESMOS endpoints
// para todos os perfis.
// ============================================================

// Em produção, defina VITE_API_URL no ambiente da Vercel/Netlify apontando
// para a URL pública da API (ex.: https://bemviver-api.onrender.com).
// Em desenvolvimento, cai no localhost:3000 automaticamente.
const API_URL = (typeof import.meta !== "undefined" && import.meta.env && import.meta.env.VITE_API_URL) || "http://localhost:3000";

const CORES = {
  papel: "#FBF6EB", tinta: "#26201A", anil: "#27418F", verde: "#2E7D46",
  destaque: "#F5C64F", cinza: "#8C8375", cartao: "#FFFDF4", nota: "#5E564A",
  aviso: "#FFF3D6", alerta: "#B3402A", alertaFundo: "#FBEAE5", verdeFundo: "#E8F4EC",
};

async function api(caminho, { metodo = "GET", corpo, token } = {}) {
  const resp = await fetch(`${API_URL}${caminho}`, {
    method: metodo,
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: corpo ? JSON.stringify(corpo) : undefined,
  });
  if (!resp.ok) {
    const d = await resp.json().catch(() => ({}));
    throw new Error(d.erro || `HTTP ${resp.status}`);
  }
  return resp.json();
}

// ---------- Armazém local + fila offline ----------
// Usa localStorage quando disponível (app real/PWA); na pré-visualização
// do Claude.ai ele não existe, então cai para memória sem quebrar.
const armazem = (() => {
  const mem = {};
  let ok = false;
  try { const k = "__bv_t"; window.localStorage.setItem(k, "1"); window.localStorage.removeItem(k); ok = true; } catch {}
  return {
    get(k) { try { return ok ? JSON.parse(window.localStorage.getItem(k) || "null") : (mem[k] ?? null); } catch { return mem[k] ?? null; } },
    set(k, v) { try { if (ok) window.localStorage.setItem(k, JSON.stringify(v)); else mem[k] = v; } catch { mem[k] = v; } },
  };
})();
const ehErroDeRede = (e) => e && (e.name === "TypeError" || /fetch|network/i.test(String(e.message)));
function enfileirar(caminho, corpo) {
  const fila = armazem.get("bv_fila") || [];
  fila.push({ caminho, corpo });
  armazem.set("bv_fila", fila);
}
async function sincronizarFila(token) {
  const fila = armazem.get("bv_fila") || [];
  if (!fila.length || !token) return 0;
  const resto = [];
  for (const item of fila) {
    try { await api(item.caminho, { metodo: "POST", token, corpo: item.corpo }); }
    catch (e) { if (ehErroDeRede(e)) resto.push(item); } // 4xx/5xx: descarta p/ não travar a fila
  }
  armazem.set("bv_fila", resto);
  return fila.length - resto.length;
}

// ---------- Partidas dos jogos individuais (Memória, Buraco, Paciência, Cuidar do Xodó) ----------
// Grava a partida e dá pontos ao Xodó. Sem internet, entra na fila offline.
async function registrarJogo(token, demo, corpo) {
  if (demo || !token) return { demo: true };
  try { return await api("/jogos", { metodo: "POST", token, corpo }); }
  catch (e) {
    if (ehErroDeRede(e)) { enfileirar("/jogos", corpo); return { naFila: true }; }
    return { erro: e.message };
  }
}
function PontosDoJogo({ r, nomePet }) {
  if (!r) return <p style={{ fontSize: 16, color: CORES.nota, margin: "0 0 14px" }}>Guardando a partida…</p>;
  let txt = null;
  if (r.ganho) {
    txt = `⭐ +${r.ganho.pontos_ganhos} pontos para o ${r.ganho.pet}!`;
    if (r.ganho.subiu_nivel) txt += ` Ele subiu para o nível ${r.ganho.nivel}! 🎉`;
  } else if (r.naFila) txt = `Sem internet agora: os pontos do ${nomePet} chegam quando a conexão voltar.`;
  else if (r.demo) txt = `Na versão conectada, o ${nomePet} ganha pontos aqui.`;
  else if (r.erro) txt = `Não consegui guardar os pontos (${r.erro}).`;
  if (!txt) return null;
  return <p role="status" style={{ fontSize: 18, fontWeight: 700, color: r.erro ? CORES.alerta : CORES.verde, margin: "0 0 14px" }}>{txt}</p>;
}

// ---------- Leitura em voz alta (Web Speech API) ----------
// Complemento para quem enxerga pouco mas não usa leitor de tela.
// Não substitui NVDA/TalkBack/VoiceOver — soma-se a eles.
const Voz = { ativa: false };
function falar(texto) {
  if (!Voz.ativa || typeof window === "undefined" || !window.speechSynthesis) return;
  try {
    window.speechSynthesis.cancel(); // não empilha falas antigas
    const u = new SpeechSynthesisUtterance(texto);
    u.lang = "pt-BR";
    u.rate = 0.95; // um pouco mais devagar, para maior idade
    window.speechSynthesis.speak(u);
  } catch {}
}
function falarSempre(texto) {
  const antes = Voz.ativa;
  Voz.ativa = true;
  falar(texto);
  Voz.ativa = antes;
}

// ---------- Dados de demonstração (para ver o app sem a API) ----------
const DEMO = {
  painel: [
    { id_idoso: 1, nome: "Severina Maria da Conceição", idade: 84, grau_dependencia: "II", ilpi: "Lar Recanto da Paz", ultimo_humor: 4, ultimo_conforto: 5, ultima_dor: 1, ultimo_checkin: new Date(Date.now() - 864e5).toISOString(), ultima_avaliacao: "GDS15", ultima_pontuacao: 6, pet: "Xodó", nivel_pet: 4, pontos_pet: 320, atividades_30d: 2 },
    { id_idoso: 3, nome: "Terezinha Alves Barbosa", idade: 87, grau_dependencia: "III", ilpi: "Lar Recanto da Paz", ultimo_humor: 3, ultimo_conforto: 3, ultima_dor: 5, ultimo_checkin: new Date(Date.now() - 8 * 864e5).toISOString(), ultima_avaliacao: "ICOPE", ultima_pontuacao: null, pet: null, nivel_pet: null, pontos_pet: null, atividades_30d: 0 },
  ],
  alertas: [
    { nome: "Manoel Ferreira Lima", ultimo_checkin: null, dias_sem_checkin: 695, responsavel: "Carlos Eduardo Santos", telefone_responsavel: "81977776666" },
    { nome: "Terezinha Alves Barbosa", ultimo_checkin: new Date(Date.now() - 8 * 864e5).toISOString(), dias_sem_checkin: 8, responsavel: "Joana Barbosa Freire", telefone_responsavel: "81966665555" },
  ],
  historico: [
    { data_hora: new Date(Date.now() - 6 * 864e5).toISOString(), humor: 2, conforto: 3, dor: 4 },
    { data_hora: new Date(Date.now() - 4 * 864e5).toISOString(), humor: 3, conforto: 4, dor: 2 },
    { data_hora: new Date(Date.now() - 2 * 864e5).toISOString(), humor: 4, conforto: 4, dor: 1 },
    { data_hora: new Date(Date.now() - 1 * 864e5).toISOString(), humor: 4, conforto: 5, dor: 1 },
  ],
};
DEMO.recados = [
  { id_recado: 1, de: "Mariana Conceição Silva", texto: "Mainha, domingo levo as crianças pra te ver. Te amo!", data_hora: new Date().toISOString() },
];
DEMO.plantao = [
  { id_recado: 1, turno: "tarde", prioridade: "urgente", texto: "Dona Terezinha com febre 38.2, médico comunicado. Observar à noite.", idoso: "Terezinha Alves Barbosa", autor: "Patrícia Andrade", data_hora: new Date().toISOString(), ciencias: 1, eu_ciente: false, resolvido: false },
  { id_recado: 2, turno: "manha", prioridade: "atencao", texto: "Seu Expedito recusou o almoço. Tentar reforço à tarde.", idoso: "Expedito José dos Santos", autor: "Marcos Vinícius", data_hora: new Date().toISOString(), ciencias: 2, eu_ciente: true, resolvido: false },
  { id_recado: 3, turno: "tarde", prioridade: "rotina", texto: "Estoque de fraldas G reposto.", idoso: null, autor: "Patrícia Andrade", data_hora: new Date().toISOString(), ciencias: 0, eu_ciente: false, resolvido: false },
];
DEMO.agenda = [
  { id_atividade: 1, nome: "Forró da tarde", categoria: "social", data_hora: new Date(Date.now() + 3*36e5).toISOString(), confirmados: 4, eu_confirmei: false },
  { id_atividade: 2, nome: "Alongamento matinal", categoria: "fisica", data_hora: new Date(Date.now() + 20*36e5).toISOString(), confirmados: 2, eu_confirmei: true },
  { id_atividade: 3, nome: "Oficina de memória", categoria: "cognitiva", data_hora: new Date(Date.now() + 28*36e5).toISOString(), confirmados: 3, eu_confirmei: false },
];
DEMO.doses = [
  { id_prescricao: 1, idoso: "Severina Maria da Conceição", medicamento: "Losartana", dose: "50 mg", horario_previsto: new Date(new Date().setHours(8, 0, 0, 0)).toISOString(), administrado_em: new Date().toISOString(), quem_deu: "Patrícia Andrade" },
  { id_prescricao: 1, idoso: "Severina Maria da Conceição", medicamento: "Losartana", dose: "50 mg", horario_previsto: new Date(new Date().setHours(20, 0, 0, 0)).toISOString(), administrado_em: null, quem_deu: null },
];

const CONTAS_DEMO = [
  { rotulo: "Sou o idoso", email: "dona.severina@email.com" },
  { rotulo: "Sou responsável", email: "mariana.filha@email.com" },
  { rotulo: "Sou da equipe", email: "enf.patricia@larpaz.com" },
  { rotulo: "Sou gestor(a)", email: "gestor@larpaz.com" },
];

// ---------- Componentes de base ----------
function BotaoGrande({ children, onClick, cor = CORES.anil, disabled }) {
  return (
    <button onClick={onClick} disabled={disabled} style={{
      minHeight: 60, padding: "14px 22px", fontSize: 20, fontWeight: 700,
      fontFamily: "'Atkinson Hyperlegible', sans-serif", color: "#fff",
      background: disabled ? CORES.cinza : cor, border: "none", borderRadius: 14,
      cursor: disabled ? "default" : "pointer",
      boxShadow: disabled ? "none" : "0 4px 0 rgba(0,0,0,0.25)", width: "100%",
    }}>{children}</button>
  );
}

function Cartao({ children, borda }) {
  return (
    <div style={{
      background: CORES.cartao, border: `2px solid ${borda || "#E4DCC9"}`,
      borderRadius: 16, padding: 16, marginBottom: 14,
    }}>{children}</div>
  );
}

// Escala de botões grandes (humor, conforto, dor)
function Escala({ rotulo, opcoes, valor, aoEscolher }) {
  return (
    <div style={{ marginBottom: 18 }}>
      <p style={{ fontSize: 19, fontWeight: 700, margin: "0 0 8px" }}>{rotulo}</p>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
        {opcoes.map((o) => (
          <button key={o.v} onClick={() => { aoEscolher(o.v); falar(o.aria || String(o.v)); }} aria-label={o.aria || String(o.v)}
            aria-pressed={valor === o.v} style={{
            minWidth: 52, minHeight: 52, fontSize: o.emoji ? 26 : 20, fontWeight: 700, borderRadius: 12,
            fontFamily: "'Atkinson Hyperlegible', sans-serif",
            border: valor === o.v ? `4px solid ${CORES.anil}` : "2px solid #D8CFBC",
            background: valor === o.v ? "#E7ECF8" : CORES.cartao, cursor: "pointer",
            color: o.cor || CORES.tinta,
          }}>{o.emoji || o.v}</button>
        ))}
      </div>
    </div>
  );
}

const OP_HUMOR = [
  { v: 1, emoji: "😞", aria: "muito triste" }, { v: 2, emoji: "🙁", aria: "triste" },
  { v: 3, emoji: "😐", aria: "mais ou menos" }, { v: 4, emoji: "🙂", aria: "bem" },
  { v: 5, emoji: "😄", aria: "muito bem" },
];
const OP_CONFORTO = [1, 2, 3, 4, 5].map((v) => ({ v }));
const corDor = (n) => (n === 0 ? CORES.verde : n <= 3 ? "#55702A" : n <= 6 ? "#8F5F0D" : CORES.alerta);
const OP_DOR = Array.from({ length: 11 }, (_, v) => ({ v, cor: corDor(v) }));

const dataCurta = (iso) =>
  iso ? new Date(iso).toLocaleDateString("pt-BR", { day: "2-digit", month: "2-digit" }) : "—";

// ---------- Gráfico de barras do humor (sem bibliotecas) ----------
function GraficoHumor({ registros }) {
  if (!registros.length) return <p style={{ fontSize: 17, color: CORES.nota }}>Ainda não há registros.</p>;
  return (
    <div>
      <p style={{ position: "absolute", width: 1, height: 1, overflow: "hidden", clip: "rect(0 0 0 0)" }}>
        Gráfico com {registros.length} registros de humor. O mais recente: humor {registros[registros.length - 1].humor} de 5,
        dor {registros[registros.length - 1].dor} de 10.
      </p>
      <div aria-hidden="true" style={{ display: "flex", alignItems: "flex-end", gap: 8, height: 110, marginTop: 8 }}>
        {registros.map((r, i) => (
          <div key={i} style={{ textAlign: "center", flex: 1, maxWidth: 54 }}>
            <div title={`humor ${r.humor}, dor ${r.dor}`} style={{
              height: r.humor * 18, background: r.humor >= 4 ? CORES.verde : r.humor === 3 ? CORES.destaque : CORES.alerta,
              borderRadius: "6px 6px 0 0",
            }} />
            <div style={{ fontSize: 13, color: CORES.nota, marginTop: 4 }}>{dataCurta(r.data_hora)}</div>
            <div style={{ fontSize: 13, fontWeight: 700, color: corDor(r.dor) }}>dor {r.dor}</div>
          </div>
        ))}
      </div>
      <p style={{ fontSize: 15, color: CORES.nota, margin: "10px 0 0" }}>
        Barras: humor de 1 a 5 (verde = bem). Abaixo, a dor relatada de 0 a 10.
      </p>
    </div>
  );
}

// ============================================================
// DOMINÓ DO LAR — agora um módulo dentro do app
// ============================================================
const PIPS = { 0: [], 1: [5], 2: [1, 9], 3: [1, 5, 9], 4: [1, 3, 7, 9], 5: [1, 3, 5, 7, 9], 6: [1, 3, 4, 6, 7, 9] };

function Metade({ valor, tam }) {
  const celulas = [];
  for (let c = 1; c <= 9; c++)
    celulas.push(
      <div key={c} style={{ display: "flex", alignItems: "center", justifyContent: "center" }}>
        {PIPS[valor].includes(c) && (
          <div style={{ width: tam * 0.16, height: tam * 0.16, borderRadius: "50%", background: "#1F1A14" }} />
        )}
      </div>
    );
  return (
    <div style={{
      width: tam, height: tam, display: "grid", gridTemplateColumns: "1fr 1fr 1fr",
      gridTemplateRows: "1fr 1fr 1fr", padding: tam * 0.1, boxSizing: "border-box",
    }}>{celulas}</div>
  );
}

function Pedra({ a, b, vertical, tam = 52, selecionada, jogavel, onClick, ariaLabel }) {
  const borda = selecionada ? `4px solid ${CORES.anil}` : jogavel ? `3px solid ${CORES.verde}` : "2px solid #D8CFBC";
  return (
    <button onClick={onClick} disabled={!onClick} aria-label={ariaLabel || `Pedra ${a} e ${b}`} style={{
      display: "flex", flexDirection: vertical ? "column" : "row", background: "#FFFDF4",
      border: borda, borderRadius: 10, boxShadow: "0 3px 6px rgba(38,32,26,0.35)", padding: 0,
      cursor: onClick ? "pointer" : "default", flexShrink: 0, transition: "transform 0.15s ease",
      transform: selecionada ? "translateY(-8px)" : "none", position: "relative",
    }}>
      {jogavel && (
        <span aria-hidden="true" style={{
          position: "absolute", top: -9, right: -9, width: 22, height: 22, borderRadius: "50%",
          background: CORES.verde, color: "#fff", fontSize: 14, fontWeight: 700,
          display: "flex", alignItems: "center", justifyContent: "center",
          border: "2px solid #FFFDF4",
        }}>✓</span>
      )}
      <Metade valor={a} tam={tam} />
      <div style={{ background: "#C9BFA8", alignSelf: "stretch", width: vertical ? "auto" : 2, height: vertical ? 2 : "auto" }} />
      <Metade valor={b} tam={tam} />
    </button>
  );
}

function baralhoNovo() {
  const pedras = [];
  for (let i = 0; i <= 6; i++) for (let j = i; j <= 6; j++) pedras.push([i, j]);
  for (let k = pedras.length - 1; k > 0; k--) {
    const r = Math.floor(Math.random() * (k + 1));
    [pedras[k], pedras[r]] = [pedras[r], pedras[k]];
  }
  return pedras;
}
const somaPips = (m) => m.reduce((s, [a, b]) => s + a + b, 0);
const encaixa = ([a, b], p) => a === p || b === p;

// ============================================================
// MOTOR DO BURACO (portado, testado em 300 partidas)
// ============================================================
// ============================================================
// MOTOR DO BURACO 1x1 — regras e pontuação (sem interface)
// Testável isoladamente. Depois vira a base do componente React.
// ============================================================

// Baralho: 2 baralhos completos = 108 cartas (52*2 + 4 coringas)
const NAIPES = ["♠", "♥", "♦", "♣"];
const VALORES = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];

// valor de pontos de cada carta (para somar jogos e contar mão)
function pontosCarta(v) {
  if (v === "Joker") return 20;      // coringa
  if (v === "2") return 20;          // 2 é curinga também, vale 20
  if (v === "A") return 15;
  if (["8", "9", "10", "J", "Q", "K"].includes(v)) return 10;
  return 5;                          // 3,4,5,6,7
}

function criarBaralho() {
  const cartas = [];
  for (let d = 0; d < 2; d++) {
    for (const n of NAIPES) for (const v of VALORES) cartas.push({ v, n, id: `${v}${n}_${d}` });
    cartas.push({ v: "Joker", n: "★", id: `Joker_a_${d}` });
    cartas.push({ v: "Joker", n: "★", id: `Joker_b_${d}` });
  }
  return cartas; // 108
}

function embaralhar(a) {
  const b = [...a];
  for (let i = b.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [b[i], b[j]] = [b[j], b[i]]; }
  return b;
}

// Distribuição 1x1: 11 cartas para cada jogador, 2 mortos de 11, resto no monte
function distribuir() {
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
const ehCuringa = (c) => c.v === "Joker" || c.v === "2";

// Sequência: mesmo naipe, valores consecutivos (A pode ser baixo A-2-3 ou alto Q-K-A)
const ORDEM = { A: 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10, J: 11, Q: 12, K: 13 };

// valida um conjunto como jogo válido (trinca ou sequência), retorna {valido, tipo, limpa}
function validarJogo(cartas) {
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
function ehCanastra(cartas) {
  const val = validarJogo(cartas);
  if (!val.valido || cartas.length < 7) return null;
  return { limpa: val.limpa, pontos: val.limpa ? 200 : 100 };
}

// Pontuação de um jogo baixado (soma das cartas + bônus de canastra)
function pontuarJogos(jogos) {
  let total = 0;
  for (const jogo of jogos) {
    for (const c of jogo) total += pontosCarta(c.v);
    const can = ehCanastra(jogo);
    if (can) total += can.pontos;
  }
  return total;
}

// Pontos negativos das cartas que sobraram na mão
function pontuarMao(mao) {
  return mao.reduce((s, c) => s + pontosCarta(c.v), 0);
}

// ============================================================
// IA do Buraco v3 — planeja canastras (não gulosa)
// A IA mantém "projetos": o melhor grupo por naipe (sequência) e por
// valor (trinca). Concentra curingas nos projetos mais maduros.
// Só baixa quando tem canastra OU quando já bateu o gatilho de baixar.
// Descarta o que não serve a nenhum projeto.
// ============================================================


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

function turnoIA(estado, idx, opcoes = {}) {
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

function podeBater(estado, idx) {
  return estado.maos[idx].length === 0 && estado.pegouMorto[idx] &&
         estado.jogos[idx].some((j) => ehCanastra(j));
}


// ============================================================
// MOTOR DO PACIÊNCIA (Klondike, 18 testes)
// ============================================================
// ============================================================
// PACIÊNCIA (Klondike) — motor
// 7 colunas (tableau), 4 fundações (por naipe, A→K), monte, descarte.
// ============================================================
const NAIPESPac = ["♠", "♥", "♦", "♣"];
const VERMELHO = new Set(["♥", "♦"]);
const VALORESPac = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];
const ORDEMPac = { A:1,"2":2,"3":3,"4":4,"5":5,"6":6,"7":7,"8":8,"9":9,"10":10,J:11,Q:12,K:13 };

function criarBaralhoPac() {
  const c = [];
  for (const n of NAIPESPac) for (const v of VALORESPac) c.push({ v, n, id: `${v}${n}`, virada: false });
  return c;
}
function embaralharPac(a) {
  const b = [...a];
  for (let i = b.length - 1; i > 0; i--) { const j = Math.floor(Math.random()*(i+1)); [b[i],b[j]]=[b[j],b[i]]; }
  return b;
}

// Distribuição Klondike: coluna i recebe i+1 cartas, só a última virada
function distribuirPac() {
  const baralho = embaralharPac(criarBaralhoPac());
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
function podeNaFundacao(fund, carta) {
  const pilha = fund[carta.n];
  if (pilha.length === 0) return carta.v === "A";
  return ORDEMPac[carta.v] === ORDEMPac[pilha[pilha.length - 1].v] + 1;
}

// Pode colocar carta(s) numa coluna do tableau? (cor alternada, valor decrescente)
function podeNaColuna(coluna, carta) {
  if (coluna.length === 0) return carta.v === "K"; // só rei em coluna vazia
  const topo = coluna[coluna.length - 1];
  if (!topo.virada) return false;
  return corAlterna(topo, carta) && ORDEMPac[topo.v] === ORDEMPac[carta.v] + 1;
}

// Vitória: todas as 52 nas fundações
function venceuPac(estado) {
  return Object.values(estado.fundacoes).reduce((s, p) => s + p.length, 0) === 52;
}

// ============================================================
// PACIÊNCIA — interface (toque origem, toque destino)
// ============================================================
function CartaPac({ carta, selecionada, onClick, sobreposta }) {
  if (!carta.virada) {
    return <div onClick={onClick} style={{
      width: 46, height: 66, borderRadius: 7, border: "2px solid #26201A",
      background: "repeating-linear-gradient(45deg,#4A6B8A,#4A6B8A 4px,#3A5A78 4px,#3A5A78 8px)",
      marginTop: sobreposta ? -48 : 0, cursor: onClick ? "pointer" : "default", flexShrink: 0,
    }} />;
  }
  const vermelho = carta.n === "♥" || carta.n === "♦";
  return (
    <button onClick={onClick} aria-label={`${carta.v} de ${carta.n}`} aria-pressed={selecionada} style={{
      width: 46, height: 66, borderRadius: 7, cursor: onClick ? "pointer" : "default", flexShrink: 0,
      border: selecionada ? "3px solid #F5C64F" : "2px solid #26201A",
      background: "#FFFDF4", color: vermelho ? "#B3402A" : "#26201A",
      marginTop: sobreposta ? -48 : 0, padding: "3px 0 0",
      display: "flex", flexDirection: "column", alignItems: "center",
      fontFamily: "'Atkinson Hyperlegible', sans-serif", fontWeight: 700,
      boxShadow: selecionada ? "0 0 0 2px #F5C64F" : "0 1px 2px rgba(0,0,0,0.15)",
    }}>
      <span style={{ fontSize: 15, lineHeight: 1 }}>{carta.v}</span>
      <span style={{ fontSize: 18, lineHeight: 1 }}>{carta.n}</span>
    </button>
  );
}

function Paciencia({ token, demo, eu }) {
  const [jogo, setJogo] = useState(null);
  const [sel, setSel] = useState(null); // { tipo: "coluna"|"descarte"|"fundacao", col?, idx? }
  const [msg, setMsg] = useState("");
  const [venc, setVenc] = useState(false);
  const [movimentos, setMovimentos] = useState(0);
  const [registro, setRegistro] = useState(null);

  // ao vencer, grava a partida uma vez só
  useEffect(() => {
    if (!venc) return;
    let vivo = true;
    registrarJogo(token, demo, { jogo: "paciencia", resultado: "vitoria", jogadas: movimentos })
      .then((r) => { if (vivo) setRegistro(r); });
    return () => { vivo = false; };
  }, [venc]); // eslint-disable-line

  function iniciar() {
    setJogo(distribuirPac()); setSel(null); setVenc(false); setMovimentos(0); setRegistro(null);
    setMsg("Monte as fundações do Ás ao Rei, por naipe. Toque numa carta e depois no destino.");
    falar("Paciência! Monte as quatro pilhas do ás ao rei.");
  }
  useEffect(() => { iniciar(); }, []); // eslint-disable-line

  if (!jogo) return <Cartao>Embaralhando…</Cartao>;
  if (venc) {
    return (
      <div style={{ textAlign: "center", padding: 10 }}>
        <div style={{ fontSize: 60 }}>🎉</div>
        <h2 style={{ fontSize: 28, margin: "6px 0" }}>Você venceu!</h2>
        <p style={{ fontSize: 19, marginBottom: 12 }}>Completou o paciência em {movimentos} jogadas. Que cabeça boa!</p>
        <PontosDoJogo r={registro} nomePet={eu.pet || "Xodó"} />
        <BotaoGrande onClick={iniciar}>Jogar de novo</BotaoGrande>
      </div>
    );
  }

  function comprar() {
    setJogo((j) => {
      const nj = JSON.parse(JSON.stringify(j));
      if (nj.monte.length === 0) {
        // vira o descarte de volta ao monte
        nj.monte = nj.descarte.reverse().map((c) => ({ ...c, virada: false }));
        nj.descarte = [];
      } else {
        const c = nj.monte.pop(); c.virada = true; nj.descarte.push(c);
      }
      return nj;
    });
    setSel(null);
  }

  function mover(destino) {
    setJogo((j) => {
      const nj = JSON.parse(JSON.stringify(j));
      let cartasMover = [];
      // origem
      if (sel.tipo === "descarte") {
        cartasMover = [nj.descarte[nj.descarte.length - 1]];
      } else if (sel.tipo === "coluna") {
        cartasMover = nj.colunas[sel.col].slice(sel.idx);
      } else if (sel.tipo === "fundacao") {
        cartasMover = [nj.fundacoes[sel.naipe][nj.fundacoes[sel.naipe].length - 1]];
      }
      if (cartasMover.length === 0) return j;
      const carta = cartasMover[0];

      let moveu = false;
      if (destino.tipo === "fundacao" && cartasMover.length === 1 && podeNaFundacao(nj.fundacoes, carta)) {
        nj.fundacoes[carta.n].push(carta); moveu = true;
      } else if (destino.tipo === "coluna" && podeNaColuna(nj.colunas[destino.col], carta)) {
        nj.colunas[destino.col].push(...cartasMover); moveu = true;
      }
      if (!moveu) { setMsg("Esse movimento não vale. Tente outro destino."); return j; }

      // remover da origem
      if (sel.tipo === "descarte") nj.descarte.pop();
      else if (sel.tipo === "coluna") {
        nj.colunas[sel.col] = nj.colunas[sel.col].slice(0, sel.idx);
        // virar a nova última carta se estiver virada p/ baixo
        const col = nj.colunas[sel.col];
        if (col.length > 0 && !col[col.length - 1].virada) col[col.length - 1].virada = true;
      } else if (sel.tipo === "fundacao") nj.fundacoes[sel.naipe].pop();

      setMovimentos((m) => m + 1);
      setMsg("");
      if (venceuPac(nj)) setTimeout(() => setVenc(true), 300);
      return nj;
    });
    setSel(null);
  }

  function tocarColuna(col, idx) {
    const coluna = jogo.colunas[col];
    if (sel) {
      if (sel.tipo === "coluna" && sel.col === col) { setSel(null); return; }
      mover({ tipo: "coluna", col });
    } else {
      if (coluna.length === 0) return;
      if (idx === undefined) idx = coluna.length - 1;
      if (!coluna[idx].virada) return;
      setSel({ tipo: "coluna", col, idx });
    }
  }
  function tocarDescarte() {
    if (jogo.descarte.length === 0) return;
    if (sel && sel.tipo === "descarte") { setSel(null); return; }
    if (sel) { mover({ tipo: "descarte" }); return; }
    setSel({ tipo: "descarte" });
  }
  function tocarFundacao(naipe) {
    if (sel) mover({ tipo: "fundacao", naipe });
    else if (jogo.fundacoes[naipe].length > 0) setSel({ tipo: "fundacao", naipe });
  }

  const topoDescarte = jogo.descarte[jogo.descarte.length - 1];

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
        <span style={{ fontSize: 16, fontWeight: 700 }}>♠️ Paciência</span>
        <button onClick={iniciar} style={{ fontSize: 14, fontWeight: 700, padding: "6px 12px", borderRadius: 10, border: `2px solid ${CORES.cinza}`, background: CORES.cartao, cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif" }}>Novo jogo</button>
      </div>
      <Aviso msg={msg} />

      {/* topo: monte, descarte, fundações */}
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 14, gap: 6 }}>
        <div style={{ display: "flex", gap: 6 }}>
          <div onClick={comprar} style={{
            width: 46, height: 66, borderRadius: 7, border: "2px solid #26201A", cursor: "pointer", flexShrink: 0,
            background: jogo.monte.length ? "repeating-linear-gradient(45deg,#4A6B8A,#4A6B8A 4px,#3A5A78 4px,#3A5A78 8px)" : "#EDE8DA",
            display: "flex", alignItems: "center", justifyContent: "center", color: "#fff", fontSize: 22,
          }}>{jogo.monte.length ? "" : "↻"}</div>
          {topoDescarte ? <CartaPac carta={topoDescarte} selecionada={sel?.tipo === "descarte"} onClick={tocarDescarte} />
            : <div style={{ width: 46, height: 66, borderRadius: 7, border: "2px dashed #C9BFA8" }} />}
        </div>
        <div style={{ display: "flex", gap: 4 }}>
          {["♠", "♥", "♦", "♣"].map((n) => {
            const pilha = jogo.fundacoes[n];
            const topo = pilha[pilha.length - 1];
            const verm = n === "♥" || n === "♦";
            return topo
              ? <CartaPac key={n} carta={topo} selecionada={sel?.tipo === "fundacao" && sel.naipe === n} onClick={() => tocarFundacao(n)} />
              : <div key={n} onClick={() => tocarFundacao(n)} style={{ width: 46, height: 66, borderRadius: 7, border: "2px dashed #C9BFA8", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 22, color: verm ? "#D8A0A0" : "#A0A0A0", cursor: "pointer", flexShrink: 0 }}>{n}</div>;
          })}
        </div>
      </div>

      {/* colunas do tableau */}
      <div style={{ display: "flex", gap: 5, justifyContent: "space-between" }}>
        {jogo.colunas.map((col, ci) => (
          <div key={ci} onClick={() => col.length === 0 && sel ? tocarColuna(ci) : null} style={{ display: "flex", flexDirection: "column", minHeight: 70, minWidth: 46, background: col.length === 0 ? "#EDE8DA" : "transparent", borderRadius: 7 }}>
            {col.length === 0
              ? <div style={{ width: 46, height: 66, borderRadius: 7, border: "2px dashed #C9BFA8" }} />
              : col.map((carta, ri) => (
                  <CartaPac key={carta.id} carta={carta} sobreposta={ri > 0}
                    selecionada={sel?.tipo === "coluna" && sel.col === ci && ri >= sel.idx}
                    onClick={() => tocarColuna(ci, ri)} />
                ))}
          </div>
        ))}
      </div>

      <p style={{ fontSize: 13, color: CORES.nota, textAlign: "center", marginTop: 12 }}>
        Toque numa carta e depois onde quer colocá-la. Nas fundações, do Ás ao Rei por naipe. Nas colunas, cores alternadas em ordem decrescente.
      </p>
    </div>
  );
}

// ============================================================
// CUIDAR DO XODÓ — jogo afetivo de atender o bichinho
// ============================================================
const PEDIDOS_XODO = [
  { acao: "comida", emoji: "🍎", pede: "Estou com fominha!", botao: "Dar comida", feito: "Nham nham! Obrigado!" },
  { acao: "agua", emoji: "💧", pede: "Que sede…", botao: "Dar água", feito: "Ahhh, que refrescante!" },
  { acao: "carinho", emoji: "💛", pede: "Quero um carinho!", botao: "Fazer carinho", feito: "Que delícia de carinho!" },
  { acao: "soneca", emoji: "😴", pede: "Estou com soninho…", botao: "Ninar", feito: "Zzz… que soneca boa!" },
  { acao: "brincar", emoji: "🎾", pede: "Vamos brincar?", botao: "Brincar", feito: "Eba! Que divertido!" },
  { acao: "banho", emoji: "🛁", pede: "Preciso de um banho!", botao: "Dar banho", feito: "Agora estou cheiroso!" },
];

function CuidarXodo({ token, demo, eu }) {
  const [pet, setPet] = useState(null);
  const [pedido, setPedido] = useState(null);
  const [opcoes, setOpcoes] = useState([]);
  const [acertos, setAcertos] = useState(0);
  const [rodada, setRodada] = useState(0);
  const [feito, setFeito] = useState(false);
  const [registro, setRegistro] = useState(null);
  const [estadoPet, setEstadoPet] = useState("feliz"); // feliz | pedindo | agradecido
  const TOTAL = 6;

  useEffect(() => {
    if (demo || !token) setPet({ especie: "passarinho", cor: "amarelo", acessorio: "laco", fase: "jovem", nome: eu.pet || "Xodó" });
    else api("/meu-pet", { token }).then((p) => setPet({ ...p, nome: p.nome || eu.pet || "Xodó" })).catch(() => setPet({ especie: "passarinho", cor: "amarelo", fase: "adulto", nome: "Xodó" }));
    proximoPedido(0);
  }, []); // eslint-disable-line

  function proximoPedido(r) {
    if (r >= TOTAL) return;
    const p = PEDIDOS_XODO[Math.floor(Math.random() * PEDIDOS_XODO.length)];
    // montar 3 opções: a certa + 2 erradas
    const outras = PEDIDOS_XODO.filter((x) => x.acao !== p.acao).sort(() => Math.random() - 0.5).slice(0, 2);
    const ops = [p, ...outras].sort(() => Math.random() - 0.5);
    setPedido(p); setOpcoes(ops); setEstadoPet("pedindo");
    falar(p.pede);
  }

  function escolher(op) {
    if (estadoPet !== "pedindo") return;
    if (op.acao === pedido.acao) {
      setAcertos((a) => a + 1);
      setEstadoPet("agradecido");
      falar(pedido.feito);
      setTimeout(() => {
        const prox = rodada + 1;
        setRodada(prox);
        if (prox >= TOTAL) concluir();
        else proximoPedido(prox);
      }, 1400);
    } else {
      falar("Ops, não era isso que eu queria. Tenta de novo!");
      setEstadoPet("pedindo"); // deixa tentar de novo
    }
  }

  async function concluir() {
    setFeito(true);
    falar(`Você cuidou tão bem de mim! Muito obrigado!`);
    setRegistro(null);
    setRegistro(await registrarJogo(token, demo, { jogo: "cuidar_xodo", resultado: "concluido", jogadas: TOTAL }));
  }

  function reiniciar() { setAcertos(0); setRodada(0); setFeito(false); setRegistro(null); proximoPedido(0); }

  if (!pet) return <Cartao>Chamando o bichinho…</Cartao>;

  if (feito) {
    return (
      <div style={{ textAlign: "center", padding: 10 }}>
        <PetSVG especie={pet.especie} cor={pet.cor} acessorio={pet.acessorio} fase={pet.fase || "adulto"} tam={180} />
        <h2 style={{ fontSize: 26, margin: "6px 0" }}>Que cuidado lindo! 💛</h2>
        <p style={{ fontSize: 19, margin: "0 0 6px" }}>Você atendeu {acertos} pedidos do {pet.nome}.</p>
        <p style={{ fontSize: 17, color: CORES.verde, fontWeight: 700, marginBottom: 16 }}>
          O {pet.nome} está muito feliz e agradecido!
        </p>
        <PontosDoJogo r={registro} nomePet={pet.nome} />
        <BotaoGrande onClick={reiniciar}>Cuidar de novo</BotaoGrande>
      </div>
    );
  }

  return (
    <div style={{ textAlign: "center" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
        <span style={{ fontSize: 16, fontWeight: 700 }}>💝 Cuidar do {pet.nome}</span>
        <span style={{ fontSize: 15, color: CORES.nota }}>Pedido {rodada + 1} de {TOTAL}</span>
      </div>

      {/* o bichinho */}
      <div style={{ position: "relative", display: "inline-block", margin: "6px 0" }}>
        <PetSVG especie={pet.especie} cor={pet.cor} acessorio={pet.acessorio} fase={pet.fase || "adulto"} tam={170} />
        {estadoPet === "agradecido" && <div style={{ position: "absolute", top: 0, right: -10, fontSize: 40 }}>💕</div>}
      </div>

      {/* balão de fala */}
      <div style={{
        background: CORES.cartao, border: `3px solid ${CORES.anil}`, borderRadius: 16, padding: "14px 18px",
        maxWidth: 380, margin: "0 auto 18px", position: "relative",
      }}>
        <span style={{ fontSize: 40 }}>{estadoPet === "agradecido" ? "😊" : pedido?.emoji}</span>
        <p style={{ fontSize: 22, fontWeight: 700, margin: "6px 0 0" }}>
          {estadoPet === "agradecido" ? pedido.feito : pedido?.pede}
        </p>
      </div>

      {/* opções de cuidado */}
      {estadoPet === "pedindo" && (
        <div style={{ display: "flex", flexDirection: "column", gap: 10, maxWidth: 380, margin: "0 auto" }}>
          {opcoes.map((op) => (
            <button key={op.acao} onClick={() => escolher(op)} style={{
              display: "flex", alignItems: "center", gap: 14, padding: "16px 18px", borderRadius: 14, cursor: "pointer",
              border: `3px solid ${CORES.anil}`, background: CORES.cartao, textAlign: "left",
              fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>
              <span style={{ fontSize: 38 }}>{op.emoji}</span>
              <span style={{ fontSize: 20, fontWeight: 700, color: CORES.anil }}>{op.botao}</span>
            </button>
          ))}
        </div>
      )}
      <p style={{ fontSize: 15, color: CORES.nota, marginTop: 14 }}>
        Escute o que o {pet.nome} pede e escolha o que ele precisa. Sem pressa!
      </p>
    </div>
  );
}

// ============================================================
// MENU DE JOGOS — o idoso escolhe qual jogar
// ============================================================
function MenuJogos({ token, demo, eu }) {
  const [jogo, setJogo] = useState(null); // null | "domino" | "memoria"

  if (jogo === "domino")
    return <div><VoltarJogos onClick={() => setJogo(null)} /><Domino token={token} demo={demo} eu={eu} /></div>;
  if (jogo === "memoria")
    return <div><VoltarJogos onClick={() => setJogo(null)} /><JogoMemoria token={token} demo={demo} eu={eu} /></div>;
  if (jogo === "buraco")
    return <div><VoltarJogos onClick={() => setJogo(null)} /><Buraco token={token} demo={demo} eu={eu} /></div>;
  if (jogo === "cuidar")
    return <div><VoltarJogos onClick={() => setJogo(null)} /><CuidarXodo token={token} demo={demo} eu={eu} /></div>;
  if (jogo === "paciencia")
    return <div><VoltarJogos onClick={() => setJogo(null)} /><Paciencia token={token} demo={demo} eu={eu} /></div>;

  const cartao = (emoji, titulo, desc, onClick, cor) => (
    <button onClick={onClick} style={{
      width: "100%", textAlign: "left", display: "flex", alignItems: "center", gap: 16,
      padding: 18, marginBottom: 14, borderRadius: 16, cursor: "pointer",
      border: `3px solid ${cor}`, background: CORES.cartao,
      fontFamily: "'Atkinson Hyperlegible', sans-serif",
    }}>
      <span style={{ fontSize: 46 }}>{emoji}</span>
      <span>
        <span style={{ display: "block", fontSize: 22, fontWeight: 700, color: cor }}>{titulo}</span>
        <span style={{ display: "block", fontSize: 16, color: CORES.nota }}>{desc}</span>
      </span>
    </button>
  );

  return (
    <div>
      <h2 style={{ fontSize: 26, margin: "0 0 4px" }}>Qual jogo você quer?</h2>
      <p style={{ fontSize: 17, color: CORES.nota, margin: "0 0 18px" }}>Jogar deixa o {eu.pet || "seu bichinho"} feliz e a cabeça espertinha!</p>
      {cartao("🁫", "Dominó do Lar", "Jogue com o Seu Biu ou com um amigo", () => setJogo("domino"), CORES.anil)}
      {cartao("🧠", "Jogo da Memória", "Ache os pares iguais. Sem pressa!", () => setJogo("memoria"), "#2E7D46")}
      {cartao("🃏", "Buraco", "O jogo de cartas, contra o computador", () => setJogo("buraco"), "#B3402A")}
      {cartao("💝", `Cuidar do ${eu.pet || "Xodó"}`, "Dê carinho, comida e soneca ao bichinho", () => setJogo("cuidar"), "#C77DA0")}
      {cartao("♠️", "Paciência", "O solitário clássico das cartas", () => setJogo("paciencia"), "#3A6B4A")}
    </div>
  );
}

function VoltarJogos({ onClick }) {
  return (
    <button onClick={onClick} style={{
      fontSize: 16, fontWeight: 700, padding: "10px 16px", borderRadius: 12, minHeight: 48, marginBottom: 12,
      border: `2px solid ${CORES.cinza}`, background: CORES.cartao, color: CORES.tinta, cursor: "pointer",
      fontFamily: "'Atkinson Hyperlegible', sans-serif",
    }}>← Voltar aos jogos</button>
  );
}

// ============================================================
// BURACO — interface (usa o motor portado acima)
// ============================================================
const NAIPE_COR = { "♥": "#B3402A", "♦": "#B3402A", "♠": "#26201A", "♣": "#26201A", "★": "#8A6D1A" };

function CartaBuraco({ carta, selecionada, onClick, pequena }) {
  const cor = NAIPE_COR[carta.n] || "#26201A";
  const label = carta.v === "Joker" ? "Coringa" : `${carta.v} de ${carta.n}`;
  const w = pequena ? 38 : 52, h = pequena ? 54 : 74;
  return (
    <button onClick={onClick} aria-label={label} aria-pressed={selecionada} style={{
      width: w, height: h, borderRadius: 8, cursor: onClick ? "pointer" : "default",
      border: selecionada ? `3px solid ${CORES.anil}` : "2px solid #C9BFA8",
      background: "#FFFDF4", color: cor, flexShrink: 0,
      transform: selecionada ? "translateY(-8px)" : "none", transition: "transform 0.1s",
      display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
      fontFamily: "'Atkinson Hyperlegible', sans-serif", fontWeight: 700, padding: 0,
    }}>
      <span style={{ fontSize: pequena ? 15 : 20, lineHeight: 1 }}>{carta.v === "Joker" ? "★" : carta.v}</span>
      <span style={{ fontSize: pequena ? 15 : 22, lineHeight: 1 }}>{carta.n}</span>
    </button>
  );
}

function Buraco({ token, demo, eu }) {
  const [estado, setEstado] = useState(null);
  const [selecao, setSelecao] = useState([]);     // ids de cartas selecionadas na mão
  const [msg, setMsg] = useState("");
  const [vez, setVez] = useState("jogador");      // jogador | maquina
  const [comprou, setComprou] = useState(false);  // já comprou nesta rodada?
  const [fim, setFim] = useState(null);
  const [registro, setRegistro] = useState(null);

  // ao terminar, grava a partida uma vez só (vitória ou derrota, com o placar)
  useEffect(() => {
    if (!fim || !estado) return;
    const meu = pontuarJogos(estado.jogos[0]) - pontuarMao(estado.maos[0]);
    const dela = pontuarJogos(estado.jogos[1]) - pontuarMao(estado.maos[1]);
    let vivo = true;
    registrarJogo(token, demo, { jogo: "buraco", resultado: meu >= dela ? "vitoria" : "derrota", pontuacao: Math.max(meu, 0) })
      .then((r) => { if (vivo) setRegistro(r); });
    return () => { vivo = false; };
  }, [fim]); // eslint-disable-line

  function iniciar() {
    const d = distribuir();
    setEstado({ ...d, jogos: [[], []] });
    setSelecao([]); setVez("jogador"); setComprou(false); setFim(null); setRegistro(null);
    setMsg("Sua vez! Comece comprando uma carta do monte.");
    falar("Buraco! Sua vez. Compre uma carta do monte para começar.");
  }
  useEffect(() => { iniciar(); }, []); // eslint-disable-line

  if (!estado) return <Cartao>Preparando a mesa…</Cartao>;
  if (fim) {
    const meu = pontuarJogos(estado.jogos[0]) - pontuarMao(estado.maos[0]);
    const dela = pontuarJogos(estado.jogos[1]) - pontuarMao(estado.maos[1]);
    const ganhou = meu >= dela;
    return (
      <div style={{ textAlign: "center", padding: 10 }}>
        <div style={{ fontSize: 60 }}>{ganhou ? "🎉" : "🌟"}</div>
        <h2 style={{ fontSize: 26, margin: "6px 0" }}>{ganhou ? "Você venceu!" : "Bom jogo!"}</h2>
        <p style={{ fontSize: 19 }}>Você: <b>{meu}</b> pontos · Computador: <b>{dela}</b> pontos</p>
        <p style={{ fontSize: 17, color: CORES.verde, fontWeight: 700, margin: "8px 0 8px" }}>
          {eu.pet || "Seu bichinho"} adorou jogar com você! 💛
        </p>
        <PontosDoJogo r={registro} nomePet={eu.pet || "Xodó"} />
        <BotaoGrande onClick={iniciar}>Jogar de novo</BotaoGrande>
      </div>
    );
  }

  const mao = estado.maos[0];
  const meusJogos = estado.jogos[0];
  const jogosMaquina = estado.jogos[1];
  const topoLixo = estado.descarte[estado.descarte.length - 1];

  function toggleCarta(id) {
    if (vez !== "jogador") return;
    setSelecao((s) => s.includes(id) ? s.filter((x) => x !== id) : [...s, id]);
  }

  function comprarMonte() {
    if (vez !== "jogador" || comprou) return;
    if (estado.monte.length === 0) return terminar();
    const carta = estado.monte[0];
    setEstado((e) => ({ ...e, monte: e.monte.slice(1), maos: [[...e.maos[0], carta], e.maos[1]] }));
    setComprou(true);
    setMsg("Agora baixe jogos (se tiver) e descarte uma carta para passar a vez.");
    falar(`Você comprou ${carta.v === "Joker" ? "um coringa" : carta.v}.`);
  }

  function baixarJogo() {
    if (vez !== "jogador" || !comprou) { setMsg("Compre uma carta primeiro."); return; }
    const cartas = mao.filter((c) => selecao.includes(c.id));
    if (cartas.length < 3) { setMsg("Escolha ao menos 3 cartas para formar um jogo."); return; }
    const val = validarJogo(cartas);
    if (!val.valido) { setMsg("Essas cartas não formam um jogo válido (trinca ou sequência do mesmo naipe)."); falar("Esse jogo não vale. Tente uma trinca ou uma sequência do mesmo naipe."); return; }
    const ids = new Set(selecao);
    setEstado((e) => ({ ...e, maos: [e.maos[0].filter((c) => !ids.has(c.id)), e.maos[1]], jogos: [[...e.jogos[0], cartas], e.jogos[1]] }));
    setSelecao([]);
    const can = ehCanastra(cartas);
    setMsg(can ? `Canastra ${can.limpa ? "limpa" : "suja"}! ${can.pontos} pontos! 🎉` : "Jogo baixado! Pode baixar mais ou descartar.");
    falar(can ? `Canastra ${can.limpa ? "limpa" : "suja"}! Muito bem!` : "Jogo baixado!");
  }

  function descartar() {
    if (vez !== "jogador" || !comprou) { setMsg("Compre uma carta antes de descartar."); return; }
    if (selecao.length !== 1) { setMsg("Escolha exatamente 1 carta para descartar."); return; }
    const carta = mao.find((c) => c.id === selecao[0]);
    setEstado((e) => {
      const novaMao = e.maos[0].filter((c) => c.id !== carta.id);
      const ne = { ...e, maos: [novaMao, e.maos[1]], descarte: [...e.descarte, carta] };
      // pegar morto se esvaziou
      if (novaMao.length === 0 && !ne.pegouMorto[0] && ne.mortos[0]) {
        ne.maos = [ne.mortos[0], ne.maos[1]];
        ne.pegouMorto = [true, ne.pegouMorto[1]];
        ne.mortos = [null, ne.mortos[1]];
        falar("Você pegou o morto!");
      }
      return ne;
    });
    setSelecao([]); setComprou(false); setVez("maquina");
    setMsg("Vez do computador…");
    setTimeout(jogarMaquina, 1200);
  }

  function jogarMaquina() {
    setEstado((e) => {
      const copia = JSON.parse(JSON.stringify(e));
      turnoIA(copia, 1);
      // fim se o monte acabou
      if (copia.monte.length === 0) { setTimeout(() => terminarCom(copia), 400); }
      return copia;
    });
    setVez("jogador"); setComprou(false);
    setMsg("Sua vez! Compre uma carta do monte.");
    falar("Sua vez.");
  }

  function terminar() { setFim(true); }
  function terminarCom(e) { setEstado(e); setFim(true); }

  const podeBaixar = comprou && selecao.length >= 3;
  const podeDescartar = comprou && selecao.length === 1;

  return (
    <div>
      {/* placar e monte */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
        <span style={{ fontSize: 16, fontWeight: 700 }}>🃏 Buraco</span>
        <span style={{ fontSize: 15, color: CORES.nota }}>Monte: {estado.monte.length} cartas</span>
      </div>

      <Aviso msg={msg} />

      {/* jogos da máquina */}
      {jogosMaquina.length > 0 && (
        <div style={{ marginBottom: 10 }}>
          <p style={{ fontSize: 14, color: CORES.nota, margin: "0 0 4px" }}>Jogos do computador:</p>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
            {jogosMaquina.map((j, i) => (
              <div key={i} style={{ display: "flex", gap: 2, background: "#F0EEE7", padding: 4, borderRadius: 8 }}>
                {j.map((c, k) => <CartaBuraco key={k} carta={c} pequena />)}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* mesa: monte + lixo */}
      <div style={{ display: "flex", gap: 16, justifyContent: "center", alignItems: "center", margin: "14px 0", padding: 12, background: "#EDE8DA", borderRadius: 14 }}>
        <div style={{ textAlign: "center" }}>
          <button onClick={comprarMonte} disabled={vez !== "jogador" || comprou} aria-label="Comprar do monte" style={{
            width: 52, height: 74, borderRadius: 8, cursor: (vez === "jogador" && !comprou) ? "pointer" : "default",
            border: "2px solid #26201A", background: (vez === "jogador" && !comprou) ? CORES.anil : "#B8AE98", color: "#fff",
            fontSize: 24, fontWeight: 700,
          }}>🂠</button>
          <div style={{ fontSize: 13, color: CORES.nota, marginTop: 2 }}>Comprar</div>
        </div>
        <div style={{ textAlign: "center" }}>
          {topoLixo ? <CartaBuraco carta={topoLixo} /> : <div style={{ width: 52, height: 74, borderRadius: 8, border: "2px dashed #C9BFA8" }} />}
          <div style={{ fontSize: 13, color: CORES.nota, marginTop: 2 }}>Lixo</div>
        </div>
      </div>

      {/* meus jogos baixados */}
      {meusJogos.length > 0 && (
        <div style={{ marginBottom: 10 }}>
          <p style={{ fontSize: 14, color: CORES.nota, margin: "0 0 4px" }}>Seus jogos:</p>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
            {meusJogos.map((j, i) => {
              const can = ehCanastra(j);
              return (
                <div key={i} style={{ display: "flex", gap: 2, background: can ? CORES.verdeFundo : "#F0EEE7", padding: 4, borderRadius: 8, border: can ? `2px solid ${CORES.verde}` : "none" }}>
                  {j.map((c, k) => <CartaBuraco key={k} carta={c} pequena />)}
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* minha mão */}
      <p style={{ fontSize: 15, fontWeight: 700, margin: "10px 0 4px" }}>Suas cartas ({mao.length}):</p>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 12 }}>
        {mao.map((c) => (
          <CartaBuraco key={c.id} carta={c} selecionada={selecao.includes(c.id)} onClick={() => toggleCarta(c.id)} />
        ))}
      </div>

      {/* ações */}
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
        <button onClick={baixarJogo} disabled={!podeBaixar} style={{
          flex: "1 1 45%", minHeight: 52, fontSize: 17, fontWeight: 700, borderRadius: 12,
          border: "none", background: podeBaixar ? CORES.verde : "#B8C4B8", color: "#fff", cursor: podeBaixar ? "pointer" : "default",
          fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>Baixar jogo ({selecao.length})</button>
        <button onClick={descartar} disabled={!podeDescartar} style={{
          flex: "1 1 45%", minHeight: 52, fontSize: 17, fontWeight: 700, borderRadius: 12,
          border: "none", background: podeDescartar ? CORES.anil : "#AEB6C4", color: "#fff", cursor: podeDescartar ? "pointer" : "default",
          fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>Descartar 1 carta</button>
      </div>
      <p style={{ fontSize: 14, color: CORES.nota, textAlign: "center", marginTop: 10 }}>
        Compre → forme trincas (3+ iguais) ou sequências (mesmo naipe em ordem) → descarte 1 para passar a vez.
      </p>
    </div>
  );
}

// ============================================================
// JOGO DA MEMÓRIA — pares de figuras grandes
// ============================================================
const FIGURAS_MEMORIA = [
  { e: "🍎", n: "maçã" }, { e: "🍌", n: "banana" }, { e: "🍊", n: "laranja" }, { e: "🍇", n: "uva" },
  { e: "🐦", n: "passarinho" }, { e: "🐱", n: "gato" }, { e: "🐶", n: "cachorro" }, { e: "🐢", n: "tartaruga" },
  { e: "🌻", n: "girassol" }, { e: "🌹", n: "rosa" }, { e: "⭐", n: "estrela" }, { e: "🌙", n: "lua" },
];
const NIVEIS_MEMORIA = [
  { r: "Fácil", pares: 4, cols: 4 },
  { r: "Médio", pares: 6, cols: 4 },
  { r: "Difícil", pares: 8, cols: 4 },
];


function JogoMemoria({ token, demo, eu }) {
  const [nivel, setNivel] = useState(null);
  const [cartas, setCartas] = useState([]);
  const [viradas, setViradas] = useState([]);     // índices virados no momento
  const [achadas, setAchadas] = useState([]);     // índices já encontrados
  const [jogadas, setJogadas] = useState(0);
  const [bloqueio, setBloqueio] = useState(false);
  const [fim, setFim] = useState(false);
  const [registro, setRegistro] = useState(null);

  function iniciar(n) {
    const fig = embaralhar(FIGURAS_MEMORIA).slice(0, n.pares);
    const baralho = embaralhar([...fig, ...fig].map((f, i) => ({ ...f, id: i })));
    setNivel(n); setCartas(baralho); setViradas([]); setAchadas([]); setJogadas(0); setFim(false);
    falar(`Jogo da memória, nível ${n.r}. Ache os pares iguais!`);
  }

  function virar(i) {
    if (bloqueio || viradas.includes(i) || achadas.includes(i)) return;
    const novas = [...viradas, i];
    setViradas(novas);
    falar(cartas[i].n);
    if (novas.length === 2) {
      setJogadas(jogadas + 1);
      setBloqueio(true);
      const [a, b] = novas;
      if (cartas[a].e === cartas[b].e) {
        setTimeout(() => {
          const ach = [...achadas, a, b];
          setAchadas(ach); setViradas([]); setBloqueio(false);
          if (ach.length === cartas.length) concluir();
        }, 600);
      } else {
        setTimeout(() => { setViradas([]); setBloqueio(false); }, 1100);
      }
    }
  }

  async function concluir() {
    setFim(true);
    falar("Muito bem! Você achou todos os pares!");
    setRegistro(null);
    setRegistro(await registrarJogo(token, demo, { jogo: "memoria", resultado: "concluido", jogadas: jogadas + 1 }));
  }

  // ----- escolha de nível -----
  if (!nivel) {
    return (
      <div>
        <h2 style={{ fontSize: 24, margin: "0 0 4px" }}>🧠 Jogo da Memória</h2>
        <p style={{ fontSize: 17, color: CORES.nota, margin: "0 0 16px" }}>Escolha o tamanho do jogo. Comece pelo fácil se quiser!</p>
        {NIVEIS_MEMORIA.map((n) => (
          <button key={n.r} onClick={() => iniciar(n)} style={{
            width: "100%", fontSize: 20, fontWeight: 700, padding: 16, marginBottom: 12, borderRadius: 14,
            border: `3px solid ${CORES.anil}`, background: CORES.cartao, color: CORES.anil, cursor: "pointer",
            fontFamily: "'Atkinson Hyperlegible', sans-serif",
          }}>{n.r} · {n.pares} pares</button>
        ))}
      </div>
    );
  }

  // ----- tela de vitória -----
  if (fim) {
    return (
      <div style={{ textAlign: "center", padding: 10 }}>
        <div style={{ fontSize: 60 }}>🎉</div>
        <h2 style={{ fontSize: 28, margin: "6px 0" }}>Você conseguiu!</h2>
        <p style={{ fontSize: 19, margin: "0 0 6px" }}>Achou todos os {nivel.pares} pares em {jogadas} tentativas.</p>
        <p style={{ fontSize: 18, fontWeight: 700, color: CORES.verde, marginBottom: 8 }}>
          {eu.pet || "Seu bichinho"} ficou feliz! 💛
        </p>
        <PontosDoJogo r={registro} nomePet={eu.pet || "Xodó"} />
        <div style={{ display: "flex", gap: 10, justifyContent: "center" }}>
          <BotaoGrande onClick={() => iniciar(nivel)}>Jogar de novo</BotaoGrande>
          <BotaoGrande onClick={() => setNivel(null)} cor={CORES.cinza}>Trocar nível</BotaoGrande>
        </div>
      </div>
    );
  }

  // ----- tabuleiro -----
  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
        <span style={{ fontSize: 17, fontWeight: 700 }}>Pares: {achadas.length / 2} de {nivel.pares}</span>
        <button onClick={() => setNivel(null)} style={{
          fontSize: 15, fontWeight: 700, padding: "8px 12px", borderRadius: 10,
          border: `2px solid ${CORES.cinza}`, background: CORES.cartao, color: CORES.tinta, cursor: "pointer",
          fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>Recomeçar</button>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: `repeat(${nivel.cols}, 1fr)`, gap: 10 }}>
        {cartas.map((c, i) => {
          const aberta = viradas.includes(i) || achadas.includes(i);
          const feita = achadas.includes(i);
          return (
            <button key={i} onClick={() => virar(i)} aria-label={aberta ? c.n : "carta virada"} disabled={feita}
              style={{
                aspectRatio: "1", fontSize: 44, borderRadius: 14, cursor: feita ? "default" : "pointer",
                border: `3px solid ${feita ? CORES.verde : CORES.anil}`,
                background: aberta ? (feita ? CORES.verdeFundo : "#FFFDF4") : CORES.anil,
                display: "flex", alignItems: "center", justifyContent: "center",
                transition: "background 0.2s", fontFamily: "'Atkinson Hyperlegible', sans-serif",
              }}>
              {aberta ? c.e : ""}
            </button>
          );
        })}
      </div>
      <p style={{ fontSize: 15, color: CORES.nota, textAlign: "center", marginTop: 12 }}>
        Toque em duas cartas para achar o par igual. Sem pressa — pode pensar à vontade!
      </p>
    </div>
  );
}

function Domino({ token, demo, eu }) {
  const petEmoji = eu.pet === "Xodó" ? "🐦" : "🐾";
  const primeiroNome = eu.nome ? eu.nome.split(" ")[0] : "Você";
  const JOG = {
    biu: [{ nome: primeiroNome, pet: eu.pet ? { chave: "p1", nome: eu.pet, emoji: petEmoji } : null }, { nome: "Seu Biu", pet: null }],
    duo: [
      { nome: primeiroNome, pet: eu.pet ? { chave: "p1", nome: eu.pet, emoji: petEmoji } : null },
      { nome: "Seu Expedito", pet: { chave: "p2", nome: "Fubá", emoji: "🐈" } },
    ],
  };
  const [tela, setTela] = useState("inicio");
  const [modo, setModo] = useState("biu");
  const [maos, setMaos] = useState([[], []]);
  const [dorme, setDorme] = useState([]);
  const [cadeia, setCadeia] = useState([]);
  const [vez, setVez] = useState(0);
  const [selecionada, setSelecionada] = useState(null);
  const [escolhendoLado, setEscolhendoLado] = useState(false);
  const [mensagem, setMensagem] = useState("");
  const [passes, setPasses] = useState(0);
  const [resultado, setResultado] = useState(null);
  const [pontos, setPontos] = useState({ p1: eu.pontos_pet ?? 0, p2: 0 });
  const [travado, setTravado] = useState(false);

  const jog = JOG[modo];
  const pontaEsq = cadeia.length ? cadeia[0][0] : null;
  const pontaDir = cadeia.length ? cadeia[cadeia.length - 1][1] : null;
  const jogaveisDe = (m) =>
    cadeia.length === 0 ? m.map((_, i) => i)
      : m.map((p, i) => (encaixa(p, pontaEsq) || encaixa(p, pontaDir) ? i : -1)).filter((i) => i >= 0);

  function novoJogo(m) {
    const b = baralhoNovo();
    setModo(m); setMaos([b.slice(0, 7), b.slice(7, 14)]); setDorme(b.slice(14));
    setCadeia([]); setVez(0); setSelecionada(null); setEscolhendoLado(false);
    setPasses(0); setResultado(null); setTravado(false);
    setMensagem("Sua vez! Toque numa pedra com a borda verde.");
    setTela("jogo");
  }

  function colocar(pedra, lado) {
    setCadeia((c) => {
      if (c.length === 0) return [pedra];
      if (lado === "esq") return [pedra[1] === c[0][0] ? pedra : [pedra[1], pedra[0]], ...c];
      const fim = c[c.length - 1][1];
      return [...c, pedra[0] === fim ? pedra : [pedra[1], pedra[0]]];
    });
  }

  async function encerrar(idxVencedor, motivo) {
    if (travado) return;
    setTravado(true);
    const ganhos = {};
    jog.forEach((j, i) => { if (j.pet) ganhos[j.pet.chave] = i === idxVencedor ? 40 : 10; });
    let sincronizada = false;
    let naFila = false;
    const corpoPartida = { id_jogador2: modo === "duo" ? 2 : null, vencedor: idxVencedor + 1, motivo };
    if (token && !demo) {
      try {
        const r = await api("/partidas", { metodo: "POST", token, corpo: corpoPartida });
        for (const g of r.ganhos) {
          const dono = jog.find((j) => j.pet && j.pet.nome === g.pet);
          if (dono) ganhos[dono.pet.chave] = g.pontos;
        }
        sincronizada = true;
      } catch (e) {
        if (ehErroDeRede(e)) { enfileirar("/partidas", corpoPartida); naFila = true; }
      }
    }
    setPontos((p) => {
      const n = { ...p };
      for (const k in ganhos) n[k] += ganhos[k];
      return n;
    });
    setResultado({ idxVencedor, motivo, ganhos, sincronizada, naFila });
    setTela("fim");
    falar(`${jog[idxVencedor].nome} ${motivo === "bateu" ? "bateu! " : "levou no fechamento! "}` +
      Object.entries(ganhos).map(([k, v]) => {
        const d = jog.find((j) => j.pet && j.pet.chave === k);
        return d ? `${d.pet.nome} ganhou ${v} pontos.` : "";
      }).join(" "));
  }

  function proximaVez(n) {
    setVez(n);
    if (modo === "duo") setTela("cortina");
    else setMensagem(n === 1 ? "Seu Biu está pensando..." : "Sua vez!");
  }

  function jogarPedra(idx, lado) {
    const pedra = maos[vez][idx];
    colocar(pedra, lado);
    const nova = maos[vez].filter((_, i) => i !== idx);
    setMaos(maos.map((m, i) => (i === vez ? nova : m)));
    setSelecionada(null); setEscolhendoLado(false); setPasses(0);
    if (nova.length === 0) return encerrar(vez, "bateu");
    proximaVez(vez === 0 ? 1 : 0);
  }

  function tocarPedra(idx) {
    if (tela !== "jogo" || travado) return;
    if (modo === "biu" && vez !== 0) return;
    if (!jogaveisDe(maos[vez]).includes(idx))
      return setMensagem("Essa pedra não encaixa nas pontas. Procure a borda verde.");
    const pedra = maos[vez][idx];
    setSelecionada(idx);
    if (cadeia.length === 0) return jogarPedra(idx, "dir");
    const cE = encaixa(pedra, pontaEsq), cD = encaixa(pedra, pontaDir);
    if (cE && cD && pontaEsq !== pontaDir) {
      setEscolhendoLado(true);
      setMensagem("Essa pedra cabe nos dois lados. Escolha a ponta:");
    } else jogarPedra(idx, cD ? "dir" : "esq");
  }

  function comprar() {
    if (!dorme.length) return;
    const [nova, ...resto] = dorme;
    setDorme(resto);
    setMaos((ms) => ms.map((m, i) => (i === vez ? [...m, nova] : m)));
    setMensagem(encaixa(nova, pontaEsq) || encaixa(nova, pontaDir) ? "Boa! A pedra que veio encaixa." : "Essa não encaixou. Compre outra.");
  }

  function passar() {
    const total = passes + 1;
    if (total >= 2) return encerrar(somaPips(maos[0]) <= somaPips(maos[1]) ? 0 : 1, "fechado");
    setPasses(total);
    proximaVez(vez === 0 ? 1 : 0);
    if (modo === "biu") setMensagem("Você passou a vez. Seu Biu está pensando...");
  }

  useEffect(() => {
    if (modo !== "biu" || vez !== 1 || tela !== "jogo" || travado) return;
    const t = setTimeout(() => {
      let maoB = [...maos[1]], dormeB = [...dorme];
      const acha = () => maoB.findIndex((p) => cadeia.length === 0 || encaixa(p, pontaEsq) || encaixa(p, pontaDir));
      let idx = acha();
      while (idx === -1 && dormeB.length) { maoB.push(dormeB.shift()); idx = acha(); }
      setDorme(dormeB);
      if (idx === -1) {
        setMaos((ms) => [ms[0], maoB]);
        const total = passes + 1;
        if (total >= 2) return encerrar(somaPips(maos[0]) <= somaPips(maoB) ? 0 : 1, "fechado");
        setPasses(total); setVez(0);
        return setMensagem("Seu Biu passou a vez. Agora é você!");
      }
      const opc = maoB.map((p, i) => ({ p, i }))
        .filter(({ p }) => cadeia.length === 0 || encaixa(p, pontaEsq) || encaixa(p, pontaDir))
        .sort((x, y) => y.p[0] + y.p[1] - (x.p[0] + x.p[1]));
      const { p, i } = opc[0];
      colocar(p, cadeia.length === 0 || encaixa(p, pontaDir) ? "dir" : "esq");
      maoB = maoB.filter((_, k) => k !== i);
      setMaos((ms) => [ms[0], maoB]);
      setPasses(0);
      if (!maoB.length) return encerrar(1, "bateu");
      setVez(0); setMensagem("Seu Biu jogou. Sua vez!");
    }, 1100);
    return () => clearTimeout(t);
  }, [vez, tela, modo]); // eslint-disable-line

  useEffect(() => { if (tela === "jogo" && mensagem) falar(mensagem); }, [mensagem, tela]); // eslint-disable-line

  const maoAtual = maos[vez] || [];
  const idxJog = jogaveisDe(maoAtual);
  const minhaVez = tela === "jogo" && (modo === "duo" || vez === 0);
  const semJogada = minhaVez && idxJog.length === 0 && !travado;
  const outro = vez === 0 ? 1 : 0;

  if (tela === "inicio")
    return (
      <div style={{ textAlign: "center" }}>
        {eu.pet && (
          <p style={{
            display: "inline-block", fontSize: 18, fontWeight: 700, background: CORES.cartao,
            border: `2px solid ${CORES.tinta}`, borderRadius: 14, padding: "8px 14px", margin: "4px 0 14px",
          }}>{petEmoji} {eu.pet} · {pontos.p1} pts</p>
        )}
        <p style={{ fontSize: 19, margin: "0 0 18px" }}>
          Jogando, você alimenta o seu bichinho — e a mesa a dois vale como visita!
        </p>
        <div style={{ display: "flex", justifyContent: "center", gap: 10, marginBottom: 22 }}>
          <Pedra a={6} b={6} tam={52} /><Pedra a={4} b={5} tam={52} />
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <BotaoGrande onClick={() => novoJogo("biu")}>🧔 Jogar com o Seu Biu</BotaoGrande>
          <BotaoGrande onClick={() => novoJogo("duo")} cor={CORES.verde}>👥 Mesa a dois: com Seu Expedito</BotaoGrande>
        </div>
        <p style={{ fontSize: 16, color: CORES.nota, marginTop: 14 }}>Sem pressa: aqui não existe relógio.</p>
      </div>
    );

  if (tela === "cortina")
    return (
      <div style={{ textAlign: "center" }}>
        <div style={{ fontSize: 60, margin: "18px 0 8px" }}>🤝</div>
        <h3 style={{ fontSize: 26, margin: "0 0 8px" }}>Passe o aparelho para {jog[vez].nome}</h3>
        <p style={{ fontSize: 18, color: CORES.nota, margin: "0 0 20px" }}>
          As pedras de {jog[outro].nome} ficam escondidas, igualzinho na mesa do quintal.
        </p>
        <BotaoGrande onClick={() => { setTela("jogo"); setMensagem(`Sua vez, ${jog[vez].nome}!`); }}>
          Sou {jog[vez].nome} — pode mostrar minhas pedras
        </BotaoGrande>
      </div>
    );

  if (tela === "fim" && resultado)
    return (
      <div style={{ textAlign: "center" }}>
        <div style={{ fontSize: 60, margin: "8px 0" }}>🏆</div>
        <h3 style={{ fontSize: 28, color: CORES.anil, margin: "0 0 8px" }}>
          {jog[resultado.idxVencedor].nome} {resultado.motivo === "bateu" ? "bateu!" : "levou no fechamento!"}
        </h3>
        <p style={{ fontSize: 16, fontWeight: 700, margin: "0 0 14px", color: resultado.sincronizada ? CORES.verde : "#77560C" }}>
          {resultado.sincronizada ? "✓ Partida registrada no Lar" : resultado.naFila ? "Partida guardada — envio sozinho quando a conexão voltar." : "Partida guardada só neste aparelho."}
        </p>
        {Object.entries(resultado.ganhos).map(([chave, pts]) => {
          const dono = jog.find((j) => j.pet && j.pet.chave === chave);
          return (
            <p key={chave} style={{
              fontSize: 19, fontWeight: 700, color: CORES.verde, background: CORES.verdeFundo,
              border: `2px solid ${CORES.verde}`, borderRadius: 12, padding: "8px 14px",
              display: "inline-block", margin: "0 6px 10px",
            }}>{dono.pet.emoji} {dono.pet.nome} +{pts} pts</p>
          );
        })}
        <div style={{ display: "flex", flexDirection: "column", gap: 12, marginTop: 12 }}>
          <BotaoGrande onClick={() => novoJogo(modo)}>🎲 Jogar outra partida</BotaoGrande>
          <BotaoGrande onClick={() => setTela("inicio")} cor={CORES.cinza}>Voltar</BotaoGrande>
        </div>
      </div>
    );

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", fontSize: 17, marginBottom: 10 }}>
        <span>{modo === "biu" ? "🧔" : "👤"} {jog[modo === "biu" ? 1 : outro].nome}: <b>{maos[modo === "biu" ? 1 : outro].length}</b> pedras</span>
        <span>Dorme: <b>{dorme.length}</b></span>
      </div>
      <div role="status" aria-live="polite" style={{
        background: CORES.aviso, border: `2px solid ${CORES.destaque}`, borderRadius: 12,
        padding: "10px 14px", fontSize: 19, fontWeight: 700, marginBottom: 12, minHeight: 50,
      }}>{mensagem}</div>
      <div style={{
        background: "linear-gradient(180deg, #7A4E2D, #5C3A21)", borderRadius: 18,
        border: `4px solid ${CORES.tinta}`, padding: 14, minHeight: 130, display: "flex",
        flexWrap: "wrap", alignItems: "center", justifyContent: "center", gap: 4, marginBottom: 14,
      }}>
        {cadeia.length === 0
          ? <span style={{ color: "#F3E7CF", fontSize: 18 }}>A mesa está vazia. Jogue a primeira pedra!</span>
          : cadeia.map(([a, b], i) => <Pedra key={i} a={a} b={b} tam={30} />)}
      </div>
      {escolhendoLado && selecionada !== null && (
        <div style={{ display: "flex", gap: 10, marginBottom: 12 }}>
          <BotaoGrande onClick={() => jogarPedra(selecionada, "esq")}>⬅ Esquerda ({pontaEsq})</BotaoGrande>
          <BotaoGrande onClick={() => jogarPedra(selecionada, "dir")}>Direita ({pontaDir}) ➡</BotaoGrande>
        </div>
      )}
      <p style={{ margin: "0 0 8px", fontSize: 17 }}>
        <b>Pedras de {jog[vez].nome}</b> — as de borda <span style={{ color: CORES.verde, fontWeight: 700 }}>verde</span> encaixam:
      </p>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 10, marginBottom: 14 }}>
        {minhaVez
          ? maoAtual.map(([a, b], i) => (
              <Pedra key={`${a}-${b}-${i}`} a={a} b={b} vertical tam={42}
                selecionada={selecionada === i} jogavel={idxJog.includes(i)}
                onClick={() => tocarPedra(i)}
                ariaLabel={`Pedra ${a} e ${b}${idxJog.includes(i) ? ", encaixa na mesa" : ""}`} />
            ))
          : <span style={{ fontSize: 17, color: CORES.nota }}>Aguarde a vez do Seu Biu…</span>}
      </div>
      {semJogada && (dorme.length > 0
        ? <BotaoGrande onClick={comprar} cor={CORES.verde}>🖐 Comprar pedra do dorme ({dorme.length})</BotaoGrande>
        : <BotaoGrande onClick={passar} cor={CORES.cinza}>Passar a vez (o dorme acabou)</BotaoGrande>)}
    </div>
  );
}

// ============================================================
// PET VISUAL — desenhado em SVG, cresce por fase
// ============================================================
const CORES_PET = {
  amarelo: "#F5C64F", laranja: "#E8873C", verde: "#7FB069",
  azul: "#6B9BD1", rosa: "#E58BA8", roxo: "#9B7EBD", marrom: "#B07D56",
};
const NOMES_COR = { amarelo: "Amarelo", laranja: "Laranja", verde: "Verde", azul: "Azul", rosa: "Rosa", roxo: "Roxo", marrom: "Marrom" };
const ESPECIES_PET = [
  { v: "passarinho", emoji: "🐦", r: "Passarinho" },
  { v: "gato", emoji: "🐈", r: "Gato" },
  { v: "cachorro", emoji: "🐕", r: "Cachorro" },
  { v: "coelho", emoji: "🐇", r: "Coelho" },
  { v: "tartaruga", emoji: "🐢", r: "Tartaruga" },
  { v: "peixe", emoji: "🐠", r: "Peixinho" },
];
const ACESSORIOS_PET = [
  { v: null, r: "Nenhum", emoji: "—" }, { v: "chapeu", r: "Chapéu", emoji: "🎩" },
  { v: "laco", r: "Laço", emoji: "🎀" }, { v: "oculos", r: "Óculos", emoji: "👓" },
  { v: "gravata", r: "Gravata", emoji: "👔" }, { v: "flor", r: "Florzinha", emoji: "🌸" },
];
const FASE_INFO = {
  filhote: { r: "Filhote", nota: "Está começando a crescer!" },
  jovem: { r: "Jovem", nota: "Cheio de energia!" },
  adulto: { r: "Adulto", nota: "Firme e forte!" },
  sabio: { r: "Sábio", nota: "Um bichinho de respeito!" },
};

// Tamanho do corpo cresce com a fase
function escalaFase(fase) {
  return { filhote: 0.68, jovem: 0.86, adulto: 1.0, sabio: 1.05 }[fase] || 1;
}

// ---------- Xodó desenhado: 6 espécies × 4 fases, com personalidade ----------
const _ESC = "#26201A", _BICO = "#E8873C";
function _ovo(cx, cy, r) {
  return <path key="ovo" d={`M${cx-r} ${cy+r*0.3} q0 ${r*0.9} ${r} ${r*0.9} q${r} 0 ${r} ${-r*0.9} l${-r*0.35} ${r*0.18} l${-r*0.3} ${-r*0.2} l${-r*0.35} ${r*0.2} l${-r*0.35} ${-r*0.2} l${-r*0.3} ${r*0.2} z`} fill="#FBF3DD" stroke={_ESC} strokeWidth="3" />;
}
function _olhosFilhote(cx, cy, r) {
  return (<g key="of">
    <circle cx={cx-r*0.32} cy={cy-r*0.05} r={r*0.2} fill="#fff" stroke={_ESC} strokeWidth="2" />
    <circle cx={cx+r*0.32} cy={cy-r*0.05} r={r*0.2} fill="#fff" stroke={_ESC} strokeWidth="2" />
    <circle cx={cx-r*0.28} cy={cy} r={r*0.11} fill={_ESC} /><circle cx={cx+r*0.36} cy={cy} r={r*0.11} fill={_ESC} />
    <circle cx={cx-r*0.25} cy={cy-r*0.03} r={r*0.04} fill="#fff" /><circle cx={cx+r*0.39} cy={cy-r*0.03} r={r*0.04} fill="#fff" />
  </g>);
}
function _olhos(cx, cy, r, dy) {
  dy = dy || -0.1;
  return (<g key="on">
    <circle cx={cx-r*0.3} cy={cy+r*dy} r={r*0.12} fill={_ESC} /><circle cx={cx+r*0.3} cy={cy+r*dy} r={r*0.12} fill={_ESC} />
    <circle cx={cx-r*0.26} cy={cy+r*dy-r*0.04} r={r*0.045} fill="#fff" /><circle cx={cx+r*0.34} cy={cy+r*dy-r*0.04} r={r*0.045} fill="#fff" />
  </g>);
}
function _oculosSabio(cx, cy, r) {
  return (<g key="os">
    <g fill="none" stroke={_ESC} strokeWidth="2.5"><circle cx={cx-r*0.3} cy={cy-r*0.08} r={r*0.22} /><circle cx={cx+r*0.3} cy={cy-r*0.08} r={r*0.22} /><line x1={cx-r*0.08} y1={cy-r*0.08} x2={cx+r*0.08} y2={cy-r*0.08} /></g>
    <circle cx={cx-r*0.3} cy={cy-r*0.08} r={r*0.08} fill={_ESC} /><circle cx={cx+r*0.3} cy={cy-r*0.08} r={r*0.08} fill={_ESC} />
  </g>);
}
function _sobrancelhas(cx, cy, r) {
  return (<g key="ss" stroke="#B8B8B8" strokeWidth="3" strokeLinecap="round" fill="none">
    <path d={`M${cx-r*0.48} ${cy-r*0.42} q${r*0.18} ${-r*0.12} ${r*0.36} ${-r*0.02}`} />
    <path d={`M${cx+r*0.12} ${cy-r*0.44} q${r*0.18} ${-r*0.1} ${r*0.36} ${r*0.02}`} />
  </g>);
}
function _sorriso(cx, cy, r, larg, alt) {
  larg = larg || 0.32; alt = alt || 0.16;
  return <path key="sor" d={`M${cx-r*larg/2} ${cy+r*0.3} q${r*larg/2} ${r*alt} ${r*larg} 0`} fill="none" stroke={_ESC} strokeWidth="2.5" strokeLinecap="round" />;
}

const _DESENHISTAS = {
  passarinho({ cor, fase, cx, cy, r }) {
    const p = [];
    if (fase === "filhote") {
      p.push(_ovo(cx, cy, r));
      p.push(<circle key="c" cx={cx} cy={cy} r={r} fill={cor} stroke={_ESC} strokeWidth="3.5" />);
      p.push(<g key="tufo" stroke={_ESC} strokeWidth="2.5" fill="none"><path d={`M${cx} ${cy-r} q-6 ${-r*0.5} -2 ${-r*0.7}`} /><path d={`M${cx} ${cy-r} q0 ${-r*0.6} 0 ${-r*0.8}`} /><path d={`M${cx} ${cy-r} q6 ${-r*0.5} 2 ${-r*0.7}`} /></g>);
      p.push(_olhosFilhote(cx, cy, r));
      p.push(<path key="b" d={`M${cx} ${cy+r*0.28} l${-r*0.14} ${r*0.14} l${r*0.28} 0 z`} fill={_BICO} stroke={_ESC} strokeWidth="1.5" />);
    } else if (fase === "jovem") {
      p.push(<ellipse key="c" cx={cx} cy={cy} rx={r*0.92} ry={r*1.08} fill={cor} stroke={_ESC} strokeWidth="3.5" />);
      p.push(<path key="cr" d={`M${cx-r*0.15} ${cy-r} q${r*0.2} ${-r*0.4} ${r*0.42} ${-r*0.15} q${-r*0.1} ${r*0.15} ${-r*0.2} ${r*0.2}`} fill={cor} stroke={_ESC} strokeWidth="2.5" />);
      p.push(<path key="a" d={`M${cx+r*0.5} ${cy} q${r*0.6} ${-r*0.5} ${r*0.4} ${r*0.3} q${-r*0.2} ${r*0.1} ${-r*0.5} ${-r*0.1}`} fill={cor} stroke={_ESC} strokeWidth="2.5" />);
      p.push(_olhos(cx, cy, r)); p.push(_sorriso(cx, cy, r));
      p.push(<path key="b" d={`M${cx-r*0.05} ${cy+r*0.02} l${-r*0.35} ${r*0.1} l${r*0.35} ${r*0.12} z`} fill={_BICO} stroke={_ESC} strokeWidth="1.5" />);
    } else if (fase === "adulto") {
      p.push(<ellipse key="c" cx={cx} cy={cy} rx={r} ry={r*1.05} fill={cor} stroke={_ESC} strokeWidth="3.5" />);
      p.push(<ellipse key="pe" cx={cx} cy={cy+r*0.25} rx={r*0.5} ry={r*0.6} fill="#fff" opacity="0.35" />);
      p.push(<path key="a" d={`M${cx-r*0.85} ${cy-r*0.1} q${-r*0.3} ${r*0.4} ${r*0.1} ${r*0.7} q${r*0.2} ${-r*0.1} ${r*0.25} ${-r*0.4}`} fill={cor} stroke={_ESC} strokeWidth="2.5" />);
      p.push(_olhos(cx, cy, r, -0.12));
      p.push(<path key="b" d={`M${cx} ${cy-r*0.02} l${-r*0.38} ${r*0.12} l${r*0.38} ${r*0.14} z`} fill={_BICO} stroke={_ESC} strokeWidth="1.5" />);
      p.push(_sorriso(cx, cy, r, 0.36, 0.18));
      p.push(<circle key="b1" cx={cx-r*0.55} cy={cy+r*0.15} r={r*0.12} fill="#E58BA8" opacity="0.4" />);
      p.push(<circle key="b2" cx={cx+r*0.55} cy={cy+r*0.15} r={r*0.12} fill="#E58BA8" opacity="0.4" />);
    } else {
      p.push(<path key="ca" d={`M${cx+r*0.7} ${cy+r*0.3} q${r*0.8} ${r*0.1} ${r*1.0} ${-r*0.3} q${-r*0.3} ${r*0.5} ${-r*0.9} ${r*0.5}`} fill={cor} stroke={_ESC} strokeWidth="2.5" />);
      p.push(<ellipse key="c" cx={cx} cy={cy} rx={r} ry={r*1.05} fill={cor} stroke={_ESC} strokeWidth="3.5" />);
      p.push(<ellipse key="pe" cx={cx} cy={cy+r*0.25} rx={r*0.5} ry={r*0.6} fill="#fff" opacity="0.4" />);
      p.push(_oculosSabio(cx, cy, r)); p.push(_sobrancelhas(cx, cy, r));
      p.push(<path key="b" d={`M${cx} ${cy+r*0.05} l${-r*0.36} ${r*0.12} l${r*0.36} ${r*0.14} z`} fill={_BICO} stroke={_ESC} strokeWidth="1.5" />);
      p.push(_sorriso(cx, cy, r));
    }
    return p;
  },
  gato({ cor, fase, cx, cy, r }) {
    const p = [];
    const orelhas = (<g key="or"><path d={`M${cx-r*0.7} ${cy-r*0.55} l${-r*0.15} ${-r*0.7} l${r*0.6} ${r*0.35} z`} fill={cor} stroke={_ESC} strokeWidth="3" /><path d={`M${cx+r*0.7} ${cy-r*0.55} l${r*0.15} ${-r*0.7} l${-r*0.6} ${r*0.35} z`} fill={cor} stroke={_ESC} strokeWidth="3" /></g>);
    if (fase === "filhote") {
      p.push(_ovo(cx, cy, r)); p.push(orelhas);
      p.push(<circle key="c" cx={cx} cy={cy} r={r} fill={cor} stroke={_ESC} strokeWidth="3.5" />);
      p.push(_olhosFilhote(cx, cy, r));
      p.push(<path key="n" d={`M${cx} ${cy+r*0.18} l${-r*0.1} ${r*0.1} l${r*0.2} 0 z`} fill="#E58BA8" stroke={_ESC} strokeWidth="1.5" />);
    } else {
      p.push(orelhas);
      p.push(<circle key="c" cx={cx} cy={cy} r={r} fill={cor} stroke={_ESC} strokeWidth="3.5" />);
      if (fase === "sabio") { p.push(_oculosSabio(cx, cy, r)); p.push(_sobrancelhas(cx, cy, r)); } else p.push(_olhos(cx, cy, r, fase==="adulto"?-0.12:-0.1));
      p.push(<path key="n" d={`M${cx} ${cy+r*0.15} l${-r*0.1} ${r*0.1} l${r*0.2} 0 z`} fill="#E58BA8" stroke={_ESC} strokeWidth="1.5" />);
      p.push(<g key="big" stroke={_ESC} strokeWidth="1.5" strokeLinecap="round"><line x1={cx-r*0.2} y1={cy+r*0.15} x2={cx-r*0.7} y2={cy+r*0.05} /><line x1={cx-r*0.2} y1={cy+r*0.22} x2={cx-r*0.7} y2={cy+r*0.25} /><line x1={cx+r*0.2} y1={cy+r*0.15} x2={cx+r*0.7} y2={cy+r*0.05} /><line x1={cx+r*0.2} y1={cy+r*0.22} x2={cx+r*0.7} y2={cy+r*0.25} /></g>);
      if (fase === "jovem") p.push(<path key="rabo" d={`M${cx+r*0.9} ${cy+r*0.6} q${r*0.6} ${-r*0.2} ${r*0.4} ${-r*0.8}`} fill="none" stroke={cor} strokeWidth={r*0.35} strokeLinecap="round" />);
    }
    return p;
  },
  cachorro({ cor, fase, cx, cy, r }) {
    const p = [];
    const orelhas = (<g key="or"><ellipse cx={cx-r*0.85} cy={cy-r*0.1} rx={r*0.25} ry={r*0.55} fill={cor} stroke={_ESC} strokeWidth="3" transform={`rotate(-20 ${cx-r*0.85} ${cy-r*0.1})`} /><ellipse cx={cx+r*0.85} cy={cy-r*0.1} rx={r*0.25} ry={r*0.55} fill={cor} stroke={_ESC} strokeWidth="3" transform={`rotate(20 ${cx+r*0.85} ${cy-r*0.1})`} /></g>);
    p.push(orelhas);
    p.push(<circle key="c" cx={cx} cy={cy} r={r} fill={cor} stroke={_ESC} strokeWidth="3.5" />);
    p.push(<ellipse key="fo" cx={cx} cy={cy+r*0.35} rx={r*0.4} ry={r*0.32} fill="#fff" opacity="0.35" />);
    if (fase === "filhote") { p.push(_olhosFilhote(cx, cy, r)); }
    else if (fase === "sabio") { p.push(_oculosSabio(cx, cy, r)); p.push(_sobrancelhas(cx, cy, r)); }
    else p.push(_olhos(cx, cy, r, fase==="adulto"?-0.15:-0.12));
    p.push(<ellipse key="n" cx={cx} cy={cy+r*0.2} rx={r*0.15} ry={r*0.11} fill={_ESC} />);
    if (fase !== "filhote") p.push(<path key="li" d={`M${cx} ${cy+r*0.3} l0 ${r*0.15}`} stroke={_ESC} strokeWidth="2" />);
    if (fase === "jovem") p.push(<path key="lin" d={`M${cx+r*0.05} ${cy+r*0.42} q${r*0.15} ${r*0.15} ${r*0.3} 0`} fill="#E58BA8" stroke={_ESC} strokeWidth="1.5" />);
    return p;
  },
  coelho({ cor, fase, cx, cy, r }) {
    const p = [];
    const h = fase === "filhote" ? 0.7 : (fase === "jovem" ? 1.1 : 1.0);
    p.push(<g key="or"><ellipse cx={cx-r*0.35} cy={cy-r*1.0*h} rx={r*0.18} ry={r*0.6*h} fill={cor} stroke={_ESC} strokeWidth="3" /><ellipse cx={cx+r*0.35} cy={cy-r*1.0*h} rx={r*0.18} ry={r*0.6*h} fill={cor} stroke={_ESC} strokeWidth="3" /><ellipse cx={cx-r*0.35} cy={cy-r*1.0*h} rx={r*0.08} ry={r*0.4*h} fill="#E58BA8" opacity="0.5" /><ellipse cx={cx+r*0.35} cy={cy-r*1.0*h} rx={r*0.08} ry={r*0.4*h} fill="#E58BA8" opacity="0.5" /></g>);
    p.push(<circle key="c" cx={cx} cy={cy} r={r} fill={cor} stroke={_ESC} strokeWidth="3.5" />);
    if (fase === "filhote") p.push(_olhosFilhote(cx, cy, r));
    else if (fase === "sabio") { p.push(_oculosSabio(cx, cy, r)); p.push(_sobrancelhas(cx, cy, r)); }
    else p.push(_olhos(cx, cy, r, fase==="adulto"?-0.12:-0.1));
    p.push(<path key="n" d={`M${cx} ${cy+r*0.13} l${-r*0.08} ${r*0.08} l${r*0.16} 0 z`} fill="#E58BA8" stroke={_ESC} strokeWidth="1.5" />);
    if (fase !== "filhote") p.push(<g key="di" fill="#fff" stroke={_ESC} strokeWidth="1"><rect x={cx-r*0.09} y={cy+r*0.24} width={r*0.08} height={r*0.14} /><rect x={cx+r*0.01} y={cy+r*0.24} width={r*0.08} height={r*0.14} /></g>);
    return p;
  },
  tartaruga({ cor, fase, cx, cy, r }) {
    const p = [], pele = "#8FB86B";
    if (fase === "filhote") {
      p.push(<circle key="cab" cx={cx} cy={cy-r*0.55} r={r*0.42} fill={pele} stroke={_ESC} strokeWidth="3" />);
      p.push(_olhosFilhote(cx, cy-r*0.55, r*0.55));
      p.push(<ellipse key="casco" cx={cx} cy={cy+r*0.15} rx={r*0.95} ry={r*0.7} fill={cor} stroke={_ESC} strokeWidth="3.5" />);
      p.push(<path key="det" d={`M${cx-r*0.5} ${cy+r*0.15} h${r} M${cx} ${cy-r*0.5} v${r*1.2}`} stroke={_ESC} strokeWidth="1.5" fill="none" opacity="0.5" />);
    } else {
      p.push(<ellipse key="cab" cx={cx} cy={cy-r*0.7} rx={r*0.42} ry={r*0.45} fill={pele} stroke={_ESC} strokeWidth="3" />);
      if (fase === "sabio") { p.push(_oculosSabio(cx, cy-r*0.7, r*0.55)); p.push(_sobrancelhas(cx, cy-r*0.7, r*0.5)); } else p.push(_olhos(cx, cy-r*0.7, r*0.55, -0.05));
      p.push(_sorriso(cx, cy-r*0.6, r*0.5));
      p.push(<ellipse key="casco" cx={cx} cy={cy+r*0.2} rx={r*1.05} ry={r*0.8} fill={cor} stroke={_ESC} strokeWidth="3.5" />);
      p.push(<path key="hex" d={`M${cx} ${cy-r*0.55} l${r*0.35} ${r*0.2} l0 ${r*0.4} l${-r*0.35} ${r*0.2} l${-r*0.35} ${-r*0.2} l0 ${-r*0.4} z`} stroke={_ESC} strokeWidth="1.5" fill="none" opacity="0.5" />);
      if (fase === "jovem") p.push(<path key="perna" d={`M${cx-r*0.85} ${cy+r*0.4} l${-r*0.25} ${r*0.2}`} stroke={pele} strokeWidth={r*0.25} strokeLinecap="round" />);
    }
    return p;
  },
  peixe({ cor, fase, cx, cy, r }) {
    const p = [];
    if (fase === "filhote") {
      p.push(<circle key="c" cx={cx} cy={cy} r={r*0.85} fill={cor} stroke={_ESC} strokeWidth="3.5" />);
      p.push(<path key="ca" d={`M${cx+r*0.7} ${cy} l${r*0.5} ${-r*0.35} l0 ${r*0.7} z`} fill={cor} stroke={_ESC} strokeWidth="3" />);
      p.push(_olhosFilhote(cx-r*0.1, cy-r*0.05, r*0.8));
      p.push(<path key="bo" d={`M${cx-r*0.5} ${cy+r*0.15} q${r*0.1} ${r*0.15} ${r*0.25} 0`} fill="none" stroke={_ESC} strokeWidth="2" strokeLinecap="round" />);
    } else {
      p.push(<path key="ca" d={`M${cx+r*0.75} ${cy} l${r*0.6} ${-r*0.45} l0 ${r*0.9} z`} fill={cor} stroke={_ESC} strokeWidth="3" />);
      p.push(<ellipse key="c" cx={cx} cy={cy} rx={r} ry={r*0.8} fill={cor} stroke={_ESC} strokeWidth="3.5" />);
      p.push(<path key="fin" d={`M${cx} ${cy-r*0.75} q${r*0.3} ${-r*0.3} ${r*0.5} 0`} fill={cor} stroke={_ESC} strokeWidth="2.5" />);
      if (fase === "sabio") p.push(_oculosSabio(cx-r*0.15, cy-r*0.05, r*0.7)); else p.push(_olhos(cx-r*0.15, cy-r*0.05, r*0.8, -0.05));
      p.push(<path key="bo" d={`M${cx-r*0.6} ${cy+r*0.15} q${r*0.12} ${r*0.18} ${r*0.28} 0`} fill="none" stroke={_ESC} strokeWidth="2.5" strokeLinecap="round" />);
      if (fase !== "jovem") p.push(<g key="esc" stroke={_ESC} strokeWidth="1" fill="none" opacity="0.4"><path d={`M${cx} ${cy-r*0.2} q${r*0.15} ${r*0.2} 0 ${r*0.4}`} /><path d={`M${cx+r*0.3} ${cy-r*0.2} q${r*0.15} ${r*0.2} 0 ${r*0.4}`} /></g>);
    }
    return p;
  },
};

function PetSVG({ especie = "passarinho", cor = "amarelo", acessorio, fase = "adulto", tam = 200 }) {
  const c = CORES_PET[cor] || CORES_PET.amarelo;
  const escuro = _ESC;
  const cx = tam / 2, cy = tam / 2 + 6;
  const r = tam * 0.26 * escalaFase(fase);
  const D = _DESENHISTAS[especie] || _DESENHISTAS.passarinho;
  const partes = D({ cor: c, fase, cx, cy, r });
  const comPatas = !["peixe", "tartaruga"].includes(especie) && fase !== "filhote";

  // acessórios: posicionados a partir do TOPO real da cabeça (cy - r).
  // Coelho tem orelhas altas, então o chapéu sobe um pouco mais para não cobri-las.
  const acess = [];
  const topo = cy - r;                                  // topo da cabeça
  const chapeuY = especie === "coelho" ? topo - r * 0.95 : topo - r * 0.15;
  if (acessorio === "chapeu") acess.push(<g key="ch">
    <rect x={cx - r * 0.55} y={chapeuY} width={r * 1.1} height={r * 0.16} rx={r*0.05} fill={escuro} />
    <rect x={cx - r * 0.34} y={chapeuY - r * 0.5} width={r * 0.68} height={r * 0.55} rx={r*0.04} fill={escuro} />
  </g>);
  if (acessorio === "laco") acess.push(<g key="la">
    <path d={`M${cx},${topo + r*0.05} l${-r*0.38},${-r*0.22} l0,${r*0.45} z`} fill="#E58BA8" stroke={escuro} strokeWidth="2"/>
    <path d={`M${cx},${topo + r*0.05} l${r*0.38},${-r*0.22} l0,${r*0.45} z`} fill="#E58BA8" stroke={escuro} strokeWidth="2"/>
    <circle cx={cx} cy={topo + r*0.05} r={r*0.1} fill="#C96B8A" stroke={escuro} strokeWidth="1.5"/>
  </g>);
  if (acessorio === "oculos" && fase !== "sabio") acess.push(<g key="oc" fill="none" stroke={escuro} strokeWidth="3"><circle cx={cx-r*0.35} cy={cy-r*0.1} r={r*0.26}/><circle cx={cx+r*0.35} cy={cy-r*0.1} r={r*0.26}/><line x1={cx-r*0.09} y1={cy-r*0.1} x2={cx+r*0.09} y2={cy-r*0.1}/></g>);
  if (acessorio === "gravata") acess.push(<path key="gr" d={`M${cx},${cy+r*0.7} l-${r*0.2},${r*0.4} l${r*0.2},${r*0.3} l${r*0.2},-${r*0.3} z`} fill="#B3402A" stroke={escuro} strokeWidth="2"/>);
  if (acessorio === "flor") acess.push(<g key="fl">
    <circle cx={cx+r*0.6} cy={topo + r*0.1} r={r*0.16} fill="#E58BA8"/>
    <circle cx={cx+r*0.6} cy={topo + r*0.1} r={r*0.06} fill="#F5C64F"/>
  </g>);

  return (
    <svg width={tam} height={tam} viewBox={`0 0 ${tam} ${tam}`} role="img" aria-label={`Bichinho ${especie}, fase ${fase}`}>
      {comPatas && <g stroke={_BICO} strokeWidth="3" strokeLinecap="round">
        <line x1={cx-r*0.25} y1={cy+r*1.0} x2={cx-r*0.25} y2={cy+r*1.2} />
        <line x1={cx+r*0.25} y1={cy+r*1.0} x2={cx+r*0.25} y2={cy+r*1.2} />
      </g>}
      {partes}
      {acess}
    </svg>
  );
}

// ============================================================
// ABA DO PET — o cantinho do bichinho
// ============================================================
const ORIGEM_PET = {
  checkin_bem_estar: { rot: "Você contou como estava", emoji: "✅" },
  participacao_atividade: { rot: "Você participou de uma atividade", emoji: "🎉" },
  avaliacao_concluida: { rot: "Você completou uma avaliação", emoji: "📋" },
  partida_domino: { rot: "Vocês jogaram dominó", emoji: "🁫" },
  interacao_pet: { rot: "Você fez carinho no bichinho", emoji: "💛" },
};
const CAT_ATIV = {
  fisica: { r: "Física", emoji: "🤸" }, social: { r: "Social", emoji: "🎉" },
  cognitiva: { r: "Cognitiva", emoji: "🧠" }, artistica: { r: "Artística", emoji: "🎨" },
  espiritual: { r: "Espiritual", emoji: "🙏" },
};
const CAT_META = {
  saude: { r: "Saúde", emoji: "🩺" }, mobilidade: { r: "Mobilidade", emoji: "🚶" },
  nutricao: { r: "Nutrição", emoji: "🍎" }, social: { r: "Social", emoji: "🎉" },
  cognitiva: { r: "Cognitiva", emoji: "🧠" }, emocional: { r: "Emocional", emoji: "💛" },
  autonomia: { r: "Autonomia", emoji: "✋" },
};
const STATUS_META = {
  ativa: { r: "Em andamento", cor: "#27418F", fundo: "#E7ECF8" },
  atingida: { r: "Atingida ✓", cor: "#2E7D46", fundo: "#E8F4EC" },
  suspensa: { r: "Suspensa", cor: "#8C8375", fundo: "#F0EEE7" },
};
const PRIO_PLANTAO = {
  urgente: { r: "Urgente", cor: "#B3402A", fundo: "#FBEAE5", emoji: "🔴" },
  atencao: { r: "Atenção", cor: "#8A6D1A", fundo: "#FFF3D6", emoji: "🟡" },
  rotina: { r: "Rotina", cor: "#2E7D46", fundo: "#E8F4EC", emoji: "🟢" },
};
const TURNOS_PLANTAO = [{ v: "manha", r: "☀️ Manhã" }, { v: "tarde", r: "🌇 Tarde" }, { v: "noite", r: "🌙 Noite" }];
const horaData = (iso) => new Date(iso).toLocaleString("pt-BR", { weekday: "short", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });

const EMOJI_ESPECIE = { passarinho: "🐦", gato: "🐈", cachorro: "🐕", peixe: "🐠" };

const DEMO_PET = {
  nome: "Xodó", especie: "passarinho", nivel: 4, pontos: 320, fase: "jovem", cor: "amarelo", acessorio: "laco",
  eventos: [
    { origem: "partida_domino", pontos_ganhos: 40, data_hora: new Date(Date.now() - 864e5).toISOString() },
    { origem: "checkin_bem_estar", pontos_ganhos: 10, data_hora: new Date(Date.now() - 864e5).toISOString() },
    { origem: "participacao_atividade", pontos_ganhos: 30, data_hora: new Date(Date.now() - 2 * 864e5).toISOString() },
    { origem: "checkin_bem_estar", pontos_ganhos: 10, data_hora: new Date(Date.now() - 2 * 864e5).toISOString() },
  ],
};

function VisaoPet({ token, demo, nomePet }) {
  const [pet, setPet] = useState(null);
  const [erro, setErro] = useState("");
  const [editando, setEditando] = useState(false);
  const [rascunho, setRascunho] = useState(null);
  const [msg, setMsg] = useState("");

  async function carregar() {
    if (demo || !token) return setPet(DEMO_PET);
    try { setPet(await api("/meu-pet", { token })); } catch (e) { setErro(e.message); }
  }
  useEffect(() => { carregar(); }, []); // eslint-disable-line

  if (erro) return <Cartao>Não consegui encontrar o seu bichinho ({erro}). Peça ajuda à equipe do lar.</Cartao>;
  if (!pet) return <Cartao>Carregando o bichinho…</Cartao>;

  const fase = pet.fase || "adulto";
  const cor = pet.cor || "amarelo";
  const progresso = pet.pontos % 100;

  async function salvar() {
    if (demo) { setMsg("✓ (demonstração) Bichinho personalizado!"); setEditando(false); setPet({ ...pet, ...rascunho }); return; }
    try {
      await api("/meu-pet", { metodo: "PATCH", token, corpo: rascunho });
      setPet({ ...pet, ...rascunho });
      setEditando(false);
      setMsg("✓ Prontinho! Seu bichinho está com a nova roupa.");
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }

  // ----- modo personalizar -----
  if (editando) {
    const r = rascunho;
    return (
      <div>
        <div style={{ textAlign: "center", marginBottom: 12 }}>
          <PetSVG especie={r.especie} cor={r.cor} acessorio={r.acessorio} fase={fase} tam={180} />
        </div>
        <Aviso msg={msg} />
        <label style={rotuloG}>Nome do bichinho</label>
        <input style={campoG} value={r.nome} maxLength={30} onChange={(e) => setRascunho({ ...r, nome: e.target.value })} />

        <label style={rotuloG}>Que bichinho é?</label>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 14 }}>
          {ESPECIES_PET.map((o) => (
            <button key={o.v} onClick={() => setRascunho({ ...r, especie: o.v })} aria-pressed={r.especie === o.v} style={{
              fontSize: 16, fontWeight: 700, padding: "10px 12px", borderRadius: 12,
              border: r.especie === o.v ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
              background: r.especie === o.v ? "#E7ECF8" : CORES.cartao, cursor: "pointer",
              fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>{o.emoji} {o.r}</button>
          ))}
        </div>

        <label style={rotuloG}>Cor</label>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 10, marginBottom: 14 }}>
          {Object.keys(CORES_PET).map((k) => (
            <button key={k} onClick={() => setRascunho({ ...r, cor: k })} aria-label={NOMES_COR[k]} aria-pressed={r.cor === k} style={{
              width: 52, height: 52, borderRadius: "50%", background: CORES_PET[k], cursor: "pointer",
              border: r.cor === k ? `4px solid ${CORES.anil}` : "2px solid #D8CFBC",
            }} />
          ))}
        </div>

        <label style={rotuloG}>Enfeite</label>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 16 }}>
          {ACESSORIOS_PET.map((o) => (
            <button key={String(o.v)} onClick={() => setRascunho({ ...r, acessorio: o.v })} aria-pressed={r.acessorio === o.v} style={{
              fontSize: 16, fontWeight: 700, padding: "10px 12px", borderRadius: 12,
              border: r.acessorio === o.v ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
              background: r.acessorio === o.v ? "#E7ECF8" : CORES.cartao, cursor: "pointer",
              fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>{o.emoji} {o.r}</button>
          ))}
        </div>

        <div style={{ display: "flex", gap: 10 }}>
          <BotaoGrande onClick={salvar}>Salvar meu bichinho</BotaoGrande>
          <BotaoGrande onClick={() => { setEditando(false); setMsg(""); }} cor={CORES.cinza}>Cancelar</BotaoGrande>
        </div>
      </div>
    );
  }

  // ----- modo visualização -----
  return (
    <div>
      <Cartao>
        <div style={{ textAlign: "center" }}>
          <PetSVG especie={pet.especie} cor={cor} acessorio={pet.acessorio} fase={fase} tam={200} />
          <h2 style={{ fontSize: 30, margin: "6px 0 2px" }}>{pet.nome}</h2>
          <p style={{ fontSize: 18, color: CORES.nota, margin: "0 0 6px" }}>
            {FASE_INFO[fase].r} · nível {pet.nivel} · {pet.pontos} pontos
          </p>
          <p style={{ fontSize: 17, fontWeight: 700, color: CORES.verde, margin: "0 0 14px" }}>
            {FASE_INFO[fase].nota}
          </p>
          <div role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={progresso}
            aria-label={`Progresso para o próximo nível: ${progresso} de 100 pontos`} style={{
            background: "#EDE5D2", borderRadius: 12, height: 26, overflow: "hidden", border: "2px solid #D8CFBC",
          }}>
            <div style={{ width: `${progresso}%`, height: "100%", background: CORES.verde, borderRadius: 10, transition: "width 0.4s ease" }} />
          </div>
          <p style={{ fontSize: 17, margin: "8px 0 12px" }}>
            Faltam <b>{100 - progresso} pontos</b> para o {pet.nome} chegar ao nível {pet.nivel + 1}!
          </p>
          <button onClick={() => { setRascunho({ nome: pet.nome, especie: pet.especie, cor, acessorio: pet.acessorio || null }); setEditando(true); setMsg(""); }} style={{
            fontSize: 18, fontWeight: 700, padding: "12px 18px", borderRadius: 12, minHeight: 52,
            border: `2px solid ${CORES.anil}`, background: "#E7ECF8", color: CORES.anil, cursor: "pointer",
            fontFamily: "'Atkinson Hyperlegible', sans-serif",
          }}>🎨 Cuidar da aparência do {pet.nome}</button>
        </div>
      </Cartao>

      {/* trilha das fases */}
      <h3 style={{ fontSize: 20, margin: "18px 0 10px" }}>Como o {pet.nome} vai crescer</h3>
      <Cartao>
        <div style={{ display: "flex", justifyContent: "space-around", alignItems: "flex-end", gap: 6 }}>
          {["filhote", "jovem", "adulto", "sabio"].map((f) => {
            const atual = f === fase;
            return (
              <div key={f} style={{ textAlign: "center", opacity: atual ? 1 : 0.5 }}>
                <PetSVG especie={pet.especie} cor={cor} acessorio={atual ? pet.acessorio : null} fase={f} tam={atual ? 78 : 64} />
                <div style={{ fontSize: 14, fontWeight: atual ? 700 : 400, color: atual ? CORES.anil : CORES.nota }}>
                  {FASE_INFO[f].r}{atual && " ✓"}
                </div>
              </div>
            );
          })}
        </div>
        <p style={{ fontSize: 15, color: CORES.nota, textAlign: "center", margin: "10px 0 0" }}>
          A cada nível, o {pet.nome} cresce mais um pouquinho. É só continuar se cuidando!
        </p>
      </Cartao>

      <h3 style={{ fontSize: 21, margin: "18px 0 10px" }}>De onde vieram os pontos</h3>
      {pet.eventos && pet.eventos.length === 0 && (
        <Cartao>O {pet.nome} ainda não ganhou pontos. Que tal um check-in ou uma partida de dominó?</Cartao>
      )}
      {pet.eventos && pet.eventos.map((e, i) => {
        const o = ORIGEM_PET[e.origem] || { rot: e.origem, emoji: "⭐" };
        return (
          <div key={i} style={{
            display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10,
            background: CORES.cartao, border: "2px solid #E4DCC9", borderRadius: 12, padding: "10px 14px", marginBottom: 8,
          }}>
            <span style={{ fontSize: 17 }}>{o.emoji} {o.rot} <small style={{ color: CORES.nota }}>({dataCurta(e.data_hora)})</small></span>
            <b style={{ color: CORES.verde, fontSize: 18, whiteSpace: "nowrap" }}>+{e.pontos_ganhos}</b>
          </div>
        );
      })}
      <p style={{ fontSize: 16, color: CORES.nota, marginTop: 12 }}>
        O {pet.nome} cresce quando você cuida de você: contando seu dia, participando das atividades e jogando com os amigos. Ele nunca fica triste — só fica com saudade. 💛
      </p>
    </div>
  );
}

// ============================================================
// ÁREA DO GESTOR — cadastro de pessoas da ILPI
// ============================================================
const FUNCOES_PROF = [
  { v: "cuidador", r: "Cuidador(a)" }, { v: "tecnico_enfermagem", r: "Téc. Enfermagem" },
  { v: "enfermeiro", r: "Enfermeiro(a)" }, { v: "medico", r: "Médico(a)" },
  { v: "psicologo", r: "Psicólogo(a)" }, { v: "fisioterapeuta", r: "Fisioterapeuta" },
  { v: "nutricionista", r: "Nutricionista" }, { v: "assistente_social", r: "Assist. Social" },
];

function VisaoGestor({ token, demo }) {
  const [aba, setAba] = useState("dashboard");
  const [pessoas, setPessoas] = useState(null);

  async function carregar() {
    if (demo) return setPessoas({
      idosos: [{ id_idoso: 1, nome: "Severina Maria da Conceição", grau_dependencia: "II", email: "dona.severina@email.com" }],
      equipe: [{ id_profissional: 1, nome: "Patrícia Andrade", funcao: "enfermeiro", email: "enf.patricia@larpaz.com" }],
    });
    try { setPessoas(await api("/gestao/pessoas", { token })); } catch { setPessoas({ idosos: [], equipe: [] }); }
  }
  useEffect(() => { carregar(); }, []); // eslint-disable-line

  const Abas = (
    <div role="tablist" style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 18 }}>
      {[["dashboard", "📈 Dashboard"], ["consultas", "📊 Consultas"], ["pessoas", "👥 Pessoas"], ["cuidadores", "🤝 Cuidadores"],
        ["idoso", "➕ Idoso"], ["prof", "➕ Profissional"], ["resp", "➕ Responsável"]].map(([id, rot]) => (
        <button key={id} role="tab" aria-selected={aba === id} onClick={() => setAba(id)} style={{
          flex: aba === "dashboard" ? "1 1 140px" : "1 1 40%", fontSize: 16, fontWeight: 700, padding: "12px 6px", borderRadius: 12,
          border: aba === id ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
          background: aba === id ? "#E7ECF8" : CORES.cartao, cursor: "pointer",
          fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>{rot}</button>
      ))}
    </div>
  );

  return (
    <main style={{ maxWidth: aba === "dashboard" ? 1180 : 620, margin: "0 auto", padding: 22 }}>
      <h2 style={{ fontSize: 24, margin: "0 0 4px" }}>Gestão da ILPI</h2>
      <p style={{ fontSize: 16, color: CORES.nota, margin: "0 0 16px" }}>
        Indicadores da casa, consultas, cadastros e a equipe da sua instituição.
      </p>
      {Abas}
      {aba === "dashboard" && <PainelDashboard token={token} demo={demo} />}
      {aba === "cuidadores" && <PainelCuidadores token={token} demo={demo} />}
      {aba === "pessoas" && <ListaPessoas pessoas={pessoas} token={token} demo={demo} aoMudar={carregar} />}
      {aba === "consultas" && <PainelConsultas token={token} demo={demo} />}
      {aba === "idoso" && <FormIdoso token={token} demo={demo} aoSalvar={carregar} />}
      {aba === "prof" && <FormProfissional token={token} demo={demo} aoSalvar={carregar} />}
      {aba === "resp" && <FormResponsavel token={token} demo={demo} idosos={pessoas ? pessoas.idosos : []} aoSalvar={carregar} />}
    </main>
  );
}

// ============================================================
// CONSULTAS ANALÍTICAS (gestor) — os SQLs ficam em api/consultas.js
// e rodam no banco com o RLS da ILPI de quem está logado.
// ============================================================
const num = (v) => (v === null || v === undefined || v === "" ? null : Number(v));
// primeiro nome + último sobrenome ("Maria das Dores Bezerra Rêgo" -> "Maria Rêgo")
const nomeCurto = (t) => { const p = String(t).trim().split(/\s+/); return p.length > 2 ? `${p[0]} ${p[p.length - 1]}` : String(t); };
const ROTULO_COL = (c) => c.replace(/_/g, " ").replace(/\bpct\b/, "%").replace(/\bml\b/, "(ml)");

function GraficoBarrasH({ linhas, x, y, max, alerta, alerta_abaixo, rotulo, linhaRef, nomeInteiro }) {
  const vals = linhas.map((l) => num(l[y]) ?? 0);
  const teto = max || Math.max(1, ...vals);
  // linha de referência (ex.: média da ILPI), tracejada sobre as barras
  const vRef = linhaRef && linhas.length ? num(linhas[0][linhaRef]) : null;
  return (
    <figure style={{ margin: "0 0 14px" }} aria-label={rotulo}>
      <figcaption style={{ fontSize: 14, color: CORES.nota, marginBottom: 6 }}>{rotulo}</figcaption>
      {linhas.map((l, k) => {
        const v = vals[k];
        const ruim = (alerta != null && v >= alerta) || (alerta_abaixo != null && v < alerta_abaixo);
        return (
          <div key={k} style={{ display: "grid", gridTemplateColumns: "minmax(90px, 38%) 1fr 52px", alignItems: "center", gap: 8, marginBottom: 4 }}>
            <span style={{ fontSize: 14, textAlign: "right", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }} title={String(l[x])}>{nomeInteiro ? String(l[x]) : nomeCurto(l[x])}</span>
            <div style={{ background: "#EFE8D8", borderRadius: 6, height: 18, position: "relative" }}>
              <div style={{ width: `${Math.max(1.5, (100 * v) / teto)}%`, height: "100%", borderRadius: 6, background: ruim ? CORES.alerta : CORES.anil }} />
              {vRef !== null && (
                <div title={`${ROTULO_COL(linhaRef)}: ${vRef}`} style={{
                  position: "absolute", top: -3, bottom: -3, left: `${(100 * vRef) / teto}%`, borderLeft: `3px dashed ${CORES.destaque}`,
                }} />
              )}
            </div>
            <span style={{ fontSize: 14, fontWeight: 700, color: ruim ? CORES.alerta : CORES.tinta }}>{v}{ruim ? " ⚠" : ""}</span>
          </div>
        );
      })}
    </figure>
  );
}

function GraficoLinhas({ linhas, x, ys, rotulo }) {
  const W = 320, H = 170, esq = 28, dir = 20, topo = 10, base = 28;
  // null = semana sem registro: a linha é interrompida ali, em vez de despencar para zero
  const series = ys.map((c) => linhas.map((l) => num(l[c])));
  const maxV = Math.ceil(Math.max(1, ...series.flat().filter((v) => v !== null)));
  const trechos = (vs) => vs.reduce((acc, v, k) => {
    if (v === null) acc.push([]); else acc[acc.length - 1].push(`${px(k)},${py(v)}`);
    return acc;
  }, [[]]).filter((t) => t.length);
  const px = (k) => esq + (linhas.length === 1 ? (W - esq - dir) / 2 : (k * (W - esq - dir)) / (linhas.length - 1));
  const py = (v) => topo + (H - topo - base) * (1 - v / maxV);
  const estilos = [{ cor: CORES.anil, traco: "" }, { cor: CORES.alerta, traco: "6 4" }, { cor: CORES.verde, traco: "2 3" }];
  return (
    <figure style={{ margin: "0 0 14px" }} aria-label={rotulo}>
      <figcaption style={{ fontSize: 14, color: CORES.nota, marginBottom: 6 }}>{rotulo}</figcaption>
      <svg viewBox={`0 0 ${W} ${H}`} style={{ width: "100%", maxWidth: 520, background: CORES.cartao, borderRadius: 10 }} role="img">
        {[0, 0.5, 1].map((f) => (
          <g key={f}>
            <line x1={esq} x2={W - dir} y1={py(maxV * f)} y2={py(maxV * f)} stroke="#E4DCC9" />
            <text x={esq - 4} y={py(maxV * f) + 4} fontSize="10" textAnchor="end" fill={CORES.nota}>{+(maxV * f).toFixed(1)}</text>
          </g>
        ))}
        {linhas.map((l, k, todas) => (k % Math.ceil(todas.length / 8) === 0 ||
            (k === todas.length - 1 && k % Math.ceil(todas.length / 8) >= Math.ceil(todas.length / 8) / 2))
          ? <text key={k} x={px(k)} y={H - 10} fontSize="10" textAnchor="middle" fill={CORES.nota}>{l[x]}</text> : null)}
        {series.map((vs, si) => (
          <g key={si}>
            {trechos(vs).map((t, ti) => (
              <polyline key={ti} fill="none" stroke={estilos[si].cor} strokeWidth="2.5" strokeDasharray={estilos[si].traco} points={t.join(" ")} />
            ))}
            {vs.map((v, k) => v === null ? null : <circle key={k} cx={px(k)} cy={py(v)} r="3.5" fill={estilos[si].cor}><title>{`${ROTULO_COL(ys[si])}: ${v}`}</title></circle>)}
          </g>
        ))}
      </svg>
      <div style={{ display: "flex", gap: 14, flexWrap: "wrap", marginTop: 4 }}>
        {ys.map((c, si) => (
          <span key={c} style={{ fontSize: 14, display: "inline-flex", alignItems: "center", gap: 6 }}>
            <svg width="26" height="8"><line x1="0" x2="26" y1="4" y2="4" stroke={estilos[si].cor} strokeWidth="3" strokeDasharray={estilos[si].traco} /></svg>
            {ROTULO_COL(c)}
          </span>
        ))}
      </div>
    </figure>
  );
}

// ---------- Gráficos do dashboard (SVG puro, sem biblioteca) ----------
const PALETA = ["#27418F", "#2E7D46", "#C2701F", "#B3402A", "#6E4C9E", "#1F7F86", "#8A6D1A", "#A34E7C"];
const fmt = (v, casas = 1) => (v === null || v === undefined || Number.isNaN(Number(v)) ? "—" : Number(v).toLocaleString("pt-BR", { maximumFractionDigits: casas }));

// Pizza ou rosca. Com aoClicar, cada fatia (e o item da legenda) vira um filtro.
function GraficoPizza({ dados, rotulo, rosca, selecionado, aoClicar }) {
  const total = dados.reduce((t, d) => t + d.valor, 0);
  if (!total) return <p style={{ fontSize: 15, color: CORES.nota }}>Sem registros no período.</p>;
  const R = 80, r = rosca ? 46 : 0, C = 90;
  let ang = -Math.PI / 2;
  const ponto = (a, raio) => `${C + raio * Math.cos(a)},${C + raio * Math.sin(a)}`;
  const fatias = dados.map((d, k) => {
    const a0 = ang, a1 = ang + (2 * Math.PI * d.valor) / total;
    ang = a1;
    const grande = a1 - a0 > Math.PI ? 1 : 0;
    const caminho = d.valor === total
      ? `M ${C} ${C - R} A ${R} ${R} 0 1 1 ${C - 0.01} ${C - R} Z`
      : `M ${ponto(a0, R)} A ${R} ${R} 0 ${grande} 1 ${ponto(a1, R)} L ${r ? ponto(a1, r) : `${C},${C}`} ${r ? `A ${r} ${r} 0 ${grande} 0 ${ponto(a0, r)}` : ""} Z`;
    return { ...d, caminho, cor: d.cor || PALETA[k % PALETA.length] };
  });
  return (
    <figure style={{ margin: 0 }} aria-label={rotulo}>
      {rotulo && <figcaption style={{ fontSize: 14, color: CORES.nota, marginBottom: 6 }}>{rotulo}</figcaption>}
      <div style={{ display: "flex", alignItems: "center", gap: 14, flexWrap: "wrap" }}>
        <svg viewBox="0 0 180 180" style={{ width: 170, maxWidth: "45%", flexShrink: 0 }} role="img">
          {fatias.map((f) => (
            <path key={f.rotulo} d={f.caminho} fill={f.cor} stroke={CORES.cartao} strokeWidth="2"
              opacity={selecionado && selecionado !== f.chave ? 0.35 : 1}
              style={{ cursor: aoClicar ? "pointer" : "default" }} onClick={aoClicar ? () => aoClicar(f.chave) : undefined}>
              <title>{`${f.rotulo}: ${f.valor} (${fmt((100 * f.valor) / total)}%)`}</title>
            </path>
          ))}
          {rosca && <circle cx={C} cy={C} r={r} fill={CORES.cartao} />}
          {rosca && <text x={C} y={C + 6} textAnchor="middle" fontSize="20" fontWeight="700" fill={CORES.tinta}>{total}</text>}
        </svg>
        <ul style={{ listStyle: "none", padding: 0, margin: 0, flex: 1, minWidth: 140 }}>
          {fatias.map((f) => {
            const conteudo = (
              <>
                <span style={{ width: 12, height: 12, borderRadius: 3, background: f.cor, display: "inline-block", flexShrink: 0 }} />
                <span style={{ flex: 1 }}>{f.rotulo}</span>
                <b>{f.valor}</b><span style={{ color: CORES.nota, minWidth: 44, textAlign: "right" }}>{fmt((100 * f.valor) / total)}%</span>
              </>
            );
            const estilo = { display: "flex", alignItems: "center", gap: 8, fontSize: 14, padding: "3px 4px", width: "100%" };
            return (
              <li key={f.rotulo}>
                {aoClicar ? (
                  <button onClick={() => aoClicar(f.chave)} aria-pressed={selecionado === f.chave} style={{
                    ...estilo, border: selecionado === f.chave ? `2px solid ${CORES.anil}` : "2px solid transparent",
                    borderRadius: 8, background: selecionado === f.chave ? "#E7ECF8" : "transparent", cursor: "pointer",
                    fontFamily: "'Atkinson Hyperlegible', sans-serif", textAlign: "left", color: CORES.tinta,
                  }}>{conteudo}</button>
                ) : <div style={estilo}>{conteudo}</div>}
              </li>
            );
          })}
        </ul>
      </div>
    </figure>
  );
}

// Colunas verticais (histograma). "marcas" desenha linhas verticais em
// valores da escala (ex.: média e mediana).
function GraficoColunas({ dados, rotulo, marcas = [], cor = CORES.anil, sufixo = "" }) {
  const W = 340, H = 190, esq = 30, dir = 10, topo = 26, base = 26;
  const maxV = Math.max(1, ...dados.map((d) => d.valor));
  const n = dados.length, larg = (W - esq - dir) / n;
  const px = (k) => esq + larg * k + larg / 2;
  const py = (v) => topo + (H - topo - base) * (1 - v / maxV);
  // posição de um valor contínuo da escala (os rótulos são numéricos)
  const pxValor = (v) => {
    const xs = dados.map((d) => Number(d.rotulo));
    if (xs.some(Number.isNaN) || n < 2) return null;
    return px(0) + ((v - xs[0]) / (xs[n - 1] - xs[0])) * (px(n - 1) - px(0));
  };
  return (
    <figure style={{ margin: 0 }} aria-label={rotulo}>
      {rotulo && <figcaption style={{ fontSize: 14, color: CORES.nota, marginBottom: 6 }}>{rotulo}</figcaption>}
      <svg viewBox={`0 0 ${W} ${H}`} style={{ width: "100%", background: CORES.cartao, borderRadius: 10 }} role="img">
        {[0, 0.5, 1].map((f) => (
          <g key={f}>
            <line x1={esq} x2={W - dir} y1={py(maxV * f)} y2={py(maxV * f)} stroke="#E4DCC9" />
            <text x={esq - 4} y={py(maxV * f) + 4} fontSize="10" textAnchor="end" fill={CORES.nota}>{fmt(maxV * f, 0)}</text>
          </g>
        ))}
        {dados.map((d, k) => (
          <g key={d.rotulo}>
            <rect x={px(k) - larg * 0.38} y={py(d.valor)} width={larg * 0.76} height={H - base - py(d.valor)} rx="3" fill={d.cor || cor}>
              <title>{`${d.rotulo}: ${d.valor}${sufixo}${d.extra ? " · " + d.extra : ""}`}</title>
            </rect>
            {d.valor > 0 && (H - base - py(d.valor) > 18
              ? <text x={px(k)} y={py(d.valor) + 13} fontSize="10.5" fontWeight="700" textAnchor="middle" fill="#fff">{d.valor}</text>
              : <text x={px(k)} y={py(d.valor) - 3} fontSize="10" textAnchor="middle" fill={CORES.tinta}>{d.valor}</text>)}
            <text x={px(k)} y={H - 10} fontSize="10.5" textAnchor="middle" fill={CORES.nota}>{d.rotuloCurto || d.rotulo}</text>
          </g>
        ))}
        {marcas.map((m, i) => {
          const x = pxValor(m.valor);
          if (x === null || m.valor === null || m.valor === undefined) return null;
          // rótulos alternam lado (esquerda/direita da linha) para não se sobreporem
          return (
            <g key={m.nome}>
              <line x1={x} x2={x} y1={topo - 6} y2={H - base} stroke={m.cor} strokeWidth="2.5" strokeDasharray={m.traco || ""} />
              <text x={i % 2 ? x + 4 : x - 4} y={topo - 4} fontSize="10" fill={m.cor} fontWeight="700"
                textAnchor={i % 2 ? "start" : "end"}>{m.nome} {fmt(m.valor, 2)}</text>
            </g>
          );
        })}
      </svg>
    </figure>
  );
}

// Radar: um eixo por categoria, valores de 0 a "max"; várias séries sobrepostas.
function GraficoRadar({ eixos, series, max = 100, rotulo, sufixo = "%" }) {
  const C = 120, R = 82, n = eixos.length;
  const ang = (k) => -Math.PI / 2 + (2 * Math.PI * k) / n;
  const pt = (k, v) => [C + R * (v / max) * Math.cos(ang(k)), C + R * (v / max) * Math.sin(ang(k))];
  return (
    <figure style={{ margin: 0 }} aria-label={rotulo}>
      {rotulo && <figcaption style={{ fontSize: 14, color: CORES.nota, marginBottom: 6 }}>{rotulo}</figcaption>}
      <svg viewBox="0 0 240 240" style={{ width: "100%", maxWidth: 320, display: "block", margin: "0 auto" }} role="img">
        {[0.25, 0.5, 0.75, 1].map((f) => (
          <polygon key={f} points={eixos.map((_, k) => pt(k, max * f).join(",")).join(" ")} fill="none" stroke="#E4DCC9" />
        ))}
        {eixos.map((e, k) => {
          const [x, y] = pt(k, max * 1.2);
          return (
            <g key={e}>
              <line x1={C} y1={C} x2={pt(k, max)[0]} y2={pt(k, max)[1]} stroke="#E4DCC9" />
              <text x={x} y={y + 4} fontSize="11" textAnchor="middle" fill={CORES.tinta}>{e}</text>
            </g>
          );
        })}
        <text x={C + 3} y={C - R * 0.5 + 3} fontSize="9" fill={CORES.nota}>{fmt(max * 0.5, 0)}{sufixo}</text>
        {series.map((s) => (
          <g key={s.nome}>
            <polygon points={s.valores.map((v, k) => pt(k, v || 0).join(",")).join(" ")}
              fill={s.cor} fillOpacity="0.18" stroke={s.cor} strokeWidth="2.5" strokeDasharray={s.traco || ""} />
            {s.valores.map((v, k) => (
              <circle key={k} cx={pt(k, v || 0)[0]} cy={pt(k, v || 0)[1]} r="3.5" fill={s.cor}>
                <title>{`${s.nome} — ${eixos[k]}: ${fmt(v)}${sufixo}`}</title>
              </circle>
            ))}
          </g>
        ))}
      </svg>
      <div style={{ display: "flex", gap: 14, justifyContent: "center", flexWrap: "wrap", marginTop: 4 }}>
        {series.map((s) => (
          <span key={s.nome} style={{ fontSize: 14, display: "inline-flex", alignItems: "center", gap: 6 }}>
            <svg width="26" height="8"><line x1="0" x2="26" y1="4" y2="4" stroke={s.cor} strokeWidth="3" strokeDasharray={s.traco || ""} /></svg>
            {s.nome}
          </span>
        ))}
      </div>
    </figure>
  );
}

// Dispersão com a reta de regressão y = a + b·x calculada no banco.
function GraficoDispersao({ pontos, reta, rotuloX, rotuloY, rotulo, yMin = 1, yMax = 5 }) {
  const W = 340, H = 220, esq = 34, dir = 12, topo = 12, base = 34;
  const xMax = Math.max(1, ...pontos.map((p) => p.x));
  const px = (v) => esq + ((W - esq - dir) * v) / xMax;
  const py = (v) => topo + (H - topo - base) * (1 - (v - yMin) / (yMax - yMin));
  const passo = Math.max(1, Math.ceil(xMax / 6));
  return (
    <figure style={{ margin: 0 }} aria-label={rotulo}>
      {rotulo && <figcaption style={{ fontSize: 14, color: CORES.nota, marginBottom: 6 }}>{rotulo}</figcaption>}
      <svg viewBox={`0 0 ${W} ${H}`} style={{ width: "100%", background: CORES.cartao, borderRadius: 10 }} role="img">
        {[yMin, (yMin + yMax) / 2, yMax].map((v) => (
          <g key={v}>
            <line x1={esq} x2={W - dir} y1={py(v)} y2={py(v)} stroke="#E4DCC9" />
            <text x={esq - 4} y={py(v) + 4} fontSize="10" textAnchor="end" fill={CORES.nota}>{v}</text>
          </g>
        ))}
        {Array.from({ length: Math.floor(xMax / passo) + 1 }, (_, k) => k * passo).map((v) => (
          <text key={v} x={px(v)} y={H - 20} fontSize="10" textAnchor="middle" fill={CORES.nota}>{v}</text>
        ))}
        <text x={(W + esq) / 2} y={H - 4} fontSize="10.5" textAnchor="middle" fill={CORES.tinta}>{rotuloX}</text>
        <text x={10} y={(H - base) / 2} fontSize="10.5" textAnchor="middle" fill={CORES.tinta} transform={`rotate(-90 10 ${(H - base) / 2})`}>{rotuloY}</text>
        {reta && reta.b !== null && reta.a !== null && (
          <line x1={px(0)} y1={py(Math.min(yMax, Math.max(yMin, reta.a)))} x2={px(xMax)}
            y2={py(Math.min(yMax, Math.max(yMin, reta.a + reta.b * xMax)))} stroke={CORES.alerta} strokeWidth="2" strokeDasharray="6 4" />
        )}
        {pontos.map((p, k) => (
          <circle key={k} cx={px(p.x)} cy={py(p.y)} r="5" fill={CORES.anil} fillOpacity="0.7" stroke="#fff">
            <title>{`${p.rotulo}: ${p.x} atividade(s), humor médio ${fmt(p.y, 2)}`}</title>
          </circle>
        ))}
      </svg>
    </figure>
  );
}

function baixarCsv(res) {
  const esc = (v) => { const t = v === null || v === undefined ? "" : String(v); return /[;"\n]/.test(t) ? `"${t.replace(/"/g, '""')}"` : t; };
  const txt = [res.colunas.join(";"), ...res.linhas.map((l) => res.colunas.map((c) => esc(l[c])).join(";"))].join("\n");
  const url = URL.createObjectURL(new Blob(["﻿" + txt], { type: "text/csv;charset=utf-8" }));
  const a = document.createElement("a");
  a.href = url; a.download = `consulta_${res.id}.csv`; a.click();
  URL.revokeObjectURL(url);
}

function PainelConsultas({ token, demo }) {
  const [lista, setLista] = useState(null);
  const [res, setRes] = useState(null);
  const [carregando, setCarregando] = useState(null);
  const [verSql, setVerSql] = useState(false);
  const [erro, setErro] = useState("");

  useEffect(() => {
    if (demo) return setLista([]);
    api("/consultas", { token }).then(setLista).catch((e) => { setErro(e.message); setLista([]); });
  }, []); // eslint-disable-line

  // dias e filtro vão como parâmetros na URL; a API confere se o valor é
  // uma das opções da consulta e o repassa ao SQL como $1/$2
  async function abrir(c, dias, filtro) {
    setErro(""); setVerSql(false); setCarregando(c.id);
    const q = new URLSearchParams();
    if (dias) q.set("dias", dias);
    if (filtro) q.set("filtro", filtro);
    try { setRes(await api(`/consultas/${c.id}${q.toString() ? `?${q}` : ""}`, { token })); }
    catch (e) { setErro(`Não consegui rodar a consulta (${e.message}).`); setRes(null); }
    finally { setCarregando(null); }
  }
  const botaoOpcao = (ativo, rotulo, onClick) => (
    <button key={rotulo} onClick={onClick} aria-pressed={ativo} style={{
      fontSize: 15, fontWeight: 700, padding: "6px 12px", borderRadius: 10, minHeight: 40, cursor: "pointer",
      border: `2px solid ${CORES.anil}`, background: ativo ? CORES.anil : CORES.cartao,
      color: ativo ? "#fff" : CORES.anil, fontFamily: "'Atkinson Hyperlegible', sans-serif",
    }}>{rotulo}</button>
  );

  if (demo) return (
    <Cartao><p style={{ fontSize: 17, margin: 0 }}>
      As consultas rodam direto no banco de dados. Entre com uma conta de gestor e a API ligada para vê-las.
    </p></Cartao>
  );
  if (!lista) return <p style={{ fontSize: 16, color: CORES.nota }}>Carregando…</p>;
  const g = res && res.grafico;
  return (
    <div>
      <p style={{ fontSize: 16, color: CORES.nota, margin: "0 0 12px" }}>
        Cada pergunta abaixo é uma consulta SQL executada agora no banco. O resultado já vem limitado à sua ILPI.
      </p>
      {erro && <Aviso msg={erro} />}
      <div style={{ display: "grid", gap: 8, marginBottom: 16 }}>
        {lista.map((c, k) => (
          <div key={c.id} style={{ display: "contents" }}>
          {(k === 0 || lista[k - 1].etapa !== c.etapa) && (
            <h3 style={{ fontSize: 17, margin: k === 0 ? "0 0 2px" : "10px 0 2px", color: CORES.nota }}>
              {c.etapa === 4 ? "Etapa 04 — consultas avançadas e visões" : "Etapa 03 — consultas da primeira versão"}
            </h3>
          )}
          <button onClick={() => abrir(c)} aria-pressed={res && res.id === c.id} style={{
            textAlign: "left", padding: "12px 14px", borderRadius: 12, cursor: "pointer",
            border: res && res.id === c.id ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
            background: res && res.id === c.id ? "#E7ECF8" : CORES.cartao, fontFamily: "'Atkinson Hyperlegible', sans-serif",
          }}>
            <div style={{ fontSize: 16, fontWeight: 700 }}>{c.id}. {c.titulo}{carregando === c.id ? " …" : ""}</div>
            <div style={{ fontSize: 14, color: CORES.nota }}>{c.pergunta}</div>
          </button>
          </div>
        ))}
      </div>

      {res && (
        <Cartao>
          <h3 style={{ fontSize: 19, margin: "0 0 10px" }}>{res.titulo}</h3>
          {res.periodo && (
            <div role="group" aria-label="Período da consulta" style={{ display: "flex", alignItems: "center", gap: 6, flexWrap: "wrap", marginBottom: 10 }}>
              <span style={{ fontSize: 15, color: CORES.nota }}>{res.periodo.rotulo || "Últimos"}</span>
              {res.periodo.opcoes.map((d) => botaoOpcao(res.periodo.dias === d, `${d} dias`,
                () => abrir(res, d, res.filtro && res.filtro.valor)))}
            </div>
          )}
          {res.filtro && (
            <div role="group" aria-label={res.filtro.rotulo} style={{ display: "flex", alignItems: "center", gap: 6, flexWrap: "wrap", marginBottom: 12 }}>
              <span style={{ fontSize: 15, color: CORES.nota }}>{res.filtro.rotulo}:</span>
              {res.filtro.opcoes.map(([v, r]) => botaoOpcao(res.filtro.valor === v, r,
                () => abrir(res, res.periodo && res.periodo.dias, v)))}
            </div>
          )}
          {res.visao && (
            <p style={{ fontSize: 14, color: CORES.nota, margin: "0 0 10px" }}>
              Esta tela lê uma <b>visão</b> do banco: o SQL abaixo consulta a visão como se fosse uma tabela.
            </p>
          )}
          {res.linhas.length === 0 ? (
            <p style={{ fontSize: 16 }}>Nenhuma linha retornada — nada a alertar por aqui.</p>
          ) : g.tipo === "pizza" ? (
            <div style={{ marginBottom: 14 }}>
              <GraficoPizza rotulo={g.rotulo} dados={Object.entries(res.linhas.reduce((acc, l) => {
                const k = l[g.contar] ?? "—"; acc[k] = (acc[k] || 0) + 1; return acc;
              }, {})).sort((a, b) => b[1] - a[1]).map(([k, v]) => ({ rotulo: String(k).replace(/_/g, " "), chave: k, valor: v }))} />
              <p style={{ fontSize: 15, margin: "8px 0 0" }}><b>{res.linhas.length}</b> linha(s) no resultado.</p>
            </div>
          ) : g.tipo === "linhas" ? (
            <GraficoLinhas linhas={res.linhas} x={g.x} ys={g.y} rotulo={g.rotulo} />
          ) : (
            <GraficoBarrasH linhas={(g.sem_nulos ? res.linhas.filter((l) => l[g.y[0]] !== null) : res.linhas).slice(0, 15)} x={g.x} y={g.y[0]} max={g.max} alerta={g.alerta} alerta_abaixo={g.alerta_abaixo} linhaRef={g.ref}
              rotulo={g.rotulo + (res.linhas.length > 15 ? ` — 15 primeiros de ${res.linhas.length}` : "")} />
          )}

          {res.linhas.length > 0 && (
            <div style={{ overflowX: "auto", border: "1px solid #E4DCC9", borderRadius: 10, marginBottom: 12, maxHeight: 320 }}>
              <table style={{ borderCollapse: "collapse", width: "100%", fontSize: 14 }}>
                <thead>
                  <tr>{res.colunas.map((c) => (
                    <th key={c} scope="col" style={{ textAlign: "left", padding: "8px 10px", background: "#F3EEE0", position: "sticky", top: 0, whiteSpace: "nowrap" }}>{ROTULO_COL(c)}</th>
                  ))}</tr>
                </thead>
                <tbody>
                  {res.linhas.map((l, k) => (
                    <tr key={k} style={{ borderTop: "1px solid #EFE8D8" }}>
                      {res.colunas.map((c) => <td key={c} style={{ padding: "6px 10px", whiteSpace: "nowrap" }}>{l[c] === null ? "—" : String(l[c])}</td>)}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
            <button onClick={() => setVerSql(!verSql)} style={{
              fontSize: 15, fontWeight: 700, padding: "8px 14px", borderRadius: 10, cursor: "pointer",
              border: `2px solid ${CORES.anil}`, background: verSql ? "#E7ECF8" : CORES.cartao, color: CORES.anil,
              fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>{verSql ? "Esconder SQL" : "🧾 Ver o SQL"}</button>
            {res.linhas.length > 0 && <button onClick={() => baixarCsv(res)} style={{
              fontSize: 15, fontWeight: 700, padding: "8px 14px", borderRadius: 10, cursor: "pointer",
              border: `2px solid ${CORES.verde}`, background: CORES.cartao, color: CORES.verde,
              fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>⬇ Baixar CSV</button>}
          </div>
          {verSql && (
            <pre style={{ fontSize: 12.5, background: "#26201A", color: "#F3EEE0", padding: 12, borderRadius: 10, overflowX: "auto", marginTop: 10, lineHeight: 1.45 }}>{res.sql}</pre>
          )}
        </Cartao>
      )}
    </div>
  );
}

// ============================================================
// DASHBOARD ESTATÍSTICO (gestor) — os SQLs ficam em api/dashboard.js.
// Cada número e gráfico é calculado agora no banco, com o RLS da ILPI.
// Filtros: período, grau de dependência (também clicando na rosca) e a
// medida de bem-estar analisada (humor, conforto ou dor).
// ============================================================
const ROTULO_CAT = {
  fisica: "Física", social: "Social", cognitiva: "Cognitiva", artistica: "Artística", espiritual: "Espiritual",
  queda: "Queda", lesao: "Lesão", mal_estar: "Mal-estar", comportamento: "Comportamento", fuga: "Fuga", obito: "Óbito", outro: "Outro",
  cafe: "Café", almoco: "Almoço", lanche: "Lanche", jantar: "Jantar", ceia: "Ceia",
};
function forcaCorrelacao(r) {
  if (r === null || r === undefined) return "sem dados suficientes";
  const a = Math.abs(r), sentido = r > 0 ? "positiva" : "negativa";
  if (a < 0.1) return "praticamente nenhuma relação";
  if (a < 0.3) return `correlação ${sentido} fraca`;
  if (a < 0.7) return `correlação ${sentido} moderada`;
  return `correlação ${sentido} forte`;
}

function CartaoGrafico({ titulo, sobre, sql, children }) {
  const [verSql, setVerSql] = useState(false);
  return (
    <section style={{ background: CORES.cartao, border: "2px solid #E4DCC9", borderRadius: 16, padding: 14, minWidth: 0 }}>
      <h3 style={{ fontSize: 18, margin: "0 0 2px" }}>{titulo}</h3>
      {sobre && <p style={{ fontSize: 14, color: CORES.nota, margin: "0 0 10px" }}>{sobre}</p>}
      {children}
      {sql && (
        <>
          <button onClick={() => setVerSql(!verSql)} style={{
            marginTop: 10, fontSize: 14, fontWeight: 700, padding: "6px 10px", borderRadius: 8, cursor: "pointer",
            border: `2px solid ${CORES.anil}`, background: verSql ? "#E7ECF8" : CORES.cartao, color: CORES.anil,
            fontFamily: "'Atkinson Hyperlegible', sans-serif",
          }}>{verSql ? "Esconder SQL" : "🧾 SQL"}</button>
          {verSql && <pre style={{ fontSize: 12, background: "#26201A", color: "#F3EEE0", padding: 10, borderRadius: 10, overflowX: "auto", marginTop: 8, lineHeight: 1.4 }}>{sql}</pre>}
        </>
      )}
    </section>
  );
}

function Indicador({ rotulo, valor, detalhe, variacao, melhor = "maior", alerta }) {
  // variacao: diferença em relação ao período anterior (null = sem comparação)
  let seta = null;
  if (variacao !== null && variacao !== undefined && !Number.isNaN(variacao)) {
    const bom = variacao === 0 ? null : (variacao > 0) === (melhor === "maior");
    seta = (
      <span style={{ fontSize: 14, fontWeight: 700, color: bom === null ? CORES.nota : bom ? CORES.verde : CORES.alerta }}>
        {variacao > 0 ? "▲" : variacao < 0 ? "▼" : "="} {fmt(Math.abs(variacao), 2)} vs. período anterior
      </span>
    );
  }
  return (
    <div style={{
      background: alerta ? CORES.alertaFundo : CORES.cartao, border: `2px solid ${alerta ? CORES.alerta : "#E4DCC9"}`,
      borderRadius: 14, padding: "12px 14px", minWidth: 0,
    }}>
      <div style={{ fontSize: 14, color: CORES.nota }}>{rotulo}</div>
      <div style={{ fontSize: 30, fontWeight: 700, color: alerta ? CORES.alerta : CORES.tinta, lineHeight: 1.15 }}>{valor}</div>
      {detalhe && <div style={{ fontSize: 14, color: CORES.nota }}>{detalhe}</div>}
      {seta}
    </div>
  );
}

function PainelDashboard({ token, demo }) {
  const [filtros, setFiltros] = useState({ dias: 30, grau: "todos", medida: "humor" });
  const [d, setD] = useState(null);
  const [erro, setErro] = useState("");
  const [carregando, setCarregando] = useState(false);

  useEffect(() => {
    if (demo) return;
    setCarregando(true); setErro("");
    api(`/dashboard?dias=${filtros.dias}&grau=${filtros.grau}&medida=${filtros.medida}`, { token })
      .then(setD).catch((e) => setErro(`Não consegui montar o dashboard (${e.message}).`))
      .finally(() => setCarregando(false));
  }, [filtros.dias, filtros.grau, filtros.medida]); // eslint-disable-line

  if (demo) return (
    <Cartao><p style={{ fontSize: 17, margin: 0 }}>
      O dashboard é calculado direto no banco de dados. Entre com a conta de gestor e a API ligada para vê-lo.
    </p></Cartao>
  );
  if (erro) return <Aviso msg={erro} />;
  if (!d) return <p style={{ fontSize: 16, color: CORES.nota }}>Calculando no banco…</p>;

  const k = d.indicadores, e = d.estatisticas, M = d.filtros.medidas[filtros.medida];
  const n = (v) => num(v);
  const dif = (a, b) => (n(a) === null || n(b) === null ? null : +(n(a) - n(b)).toFixed(2));
  const chip = (ativo, rotulo, onClick, titulo) => (
    <button key={rotulo} onClick={onClick} aria-pressed={ativo} title={titulo} style={{
      fontSize: 15, fontWeight: 700, padding: "7px 12px", borderRadius: 10, minHeight: 42, cursor: "pointer",
      border: `2px solid ${CORES.anil}`, background: ativo ? CORES.anil : CORES.cartao,
      color: ativo ? "#fff" : CORES.anil, fontFamily: "'Atkinson Hyperlegible', sans-serif",
    }}>{rotulo}</button>
  );
  const grupo = (rotulo, conteudo) => (
    <div role="group" aria-label={rotulo} style={{ display: "flex", alignItems: "center", gap: 6, flexWrap: "wrap" }}>
      <span style={{ fontSize: 15, color: CORES.nota, minWidth: 70 }}>{rotulo}</span>{conteudo}
    </div>
  );
  const nomeGrau = filtros.grau === "todos" ? "todos os residentes" : `residentes de grau ${filtros.grau}`;
  const reg = d.regressao || {}, cor = d.correlacao || {};
  const tendMedida = n(reg[`${filtros.medida}_por_semana`]);
  const deficit = n(k.cuidadores_necessarios) > n(k.cuidadores_na_equipe);

  return (
    <div>
      {/* ---------- Filtros ---------- */}
      <div style={{ background: "#F3EEE0", borderRadius: 14, padding: 12, display: "grid", gap: 8, marginBottom: 14 }}>
        {grupo("Período", d.filtros.opcoes_dias.map((x) => chip(filtros.dias === x, `${x} dias`, () => setFiltros({ ...filtros, dias: x }))))}
        {grupo("Grau", [["todos", "Todos"], ["I", "Grau I"], ["II", "Grau II"], ["III", "Grau III"]].map(([v, r]) =>
          chip(filtros.grau === v, r, () => setFiltros({ ...filtros, grau: v }))))}
        {grupo("Medida", Object.entries(d.filtros.medidas).map(([v, m]) =>
          chip(filtros.medida === v, m.rotulo, () => setFiltros({ ...filtros, medida: v }), `Analisar ${m.rotulo.toLowerCase()} no histograma e nas estatísticas`)))}
        <span style={{ fontSize: 14, color: CORES.nota }} aria-live="polite">
          {carregando ? "Recalculando no banco…" : `Mostrando ${nomeGrau}, últimos ${filtros.dias} dias.`}
        </span>
      </div>

      {/* ---------- Indicadores resumidos ---------- */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))", gap: 10, marginBottom: 14 }}>
        <Indicador rotulo="Residentes no recorte" valor={k.residentes} detalhe={`${fmt(k.pct_residentes_com_checkin)}% fizeram check-in`} />
        <Indicador rotulo="Check-ins de bem-estar" valor={k.checkins}
          detalhe={n(k.residentes) ? `${fmt(n(k.checkins) / n(k.residentes) / filtros.dias, 2)} por residente/dia` : null} />
        <Indicador rotulo="Humor médio (1 a 5)" valor={fmt(k.humor_medio, 2)} variacao={dif(k.humor_medio, k.humor_medio_anterior)} />
        <Indicador rotulo="Dor média (0 a 10)" valor={fmt(k.dor_media, 2)} variacao={dif(k.dor_media, k.dor_media_anterior)} melhor="menor" />
        <Indicador rotulo="Intercorrências" valor={k.intercorrencias} variacao={dif(k.intercorrencias, k.intercorrencias_anterior)} melhor="menor" />
        <Indicador rotulo="Adesão à medicação (7 dias)" valor={`${fmt(k.adesao_pct)}%`} detalhe={`${k.doses_dadas} de ${k.doses_previstas} doses`}
          alerta={n(k.adesao_pct) !== null && n(k.adesao_pct) < 90} />
        <Indicador rotulo="Aceitação alimentar média" valor={k.aceitacao_alimentar_media === null ? "—" : `${fmt(k.aceitacao_alimentar_media)}%`} />
        <Indicador rotulo="Cuidadores por turno (RDC 502)" valor={`${k.cuidadores_na_equipe} / ${k.cuidadores_necessarios}`}
          detalhe={deficit ? "equipe abaixo do mínimo" : "na equipe / exigidos"} alerta={deficit} />
      </div>

      {/* ---------- Gráficos ---------- */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(330px, 1fr))", gap: 12 }}>
        <CartaoGrafico titulo={`1. Distribuição: ${M.rotulo.toLowerCase()} (${M.min} a ${M.max})`}
          sobre="Frequência de cada valor marcado nos check-ins, com as medidas de tendência central e de dispersão."
          sql={d.sql.histograma + ";\n\n" + d.sql.estatisticas}>
          <GraficoColunas dados={d.histograma.map((h) => ({ rotulo: String(h.valor), valor: n(h.frequencia), extra: `${fmt(h.percentual)}% dos registros` }))}
            marcas={[{ nome: "média", valor: n(e.media), cor: CORES.alerta }, { nome: "mediana", valor: n(e.mediana), cor: CORES.verde, traco: "5 3" }]} />
          <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 6, marginTop: 10 }}>
            {[["n", e.n, 0], ["Média", e.media, 2], ["Mediana", e.mediana, 2], ["Moda", e.moda, 0], ["Variância", e.variancia, 2],
              ["Desvio padrão", e.desvio_padrao, 2], ["Coef. de variação", e.coef_variacao_pct === null ? null : `${fmt(e.coef_variacao_pct)}%`, null],
              ["Mínimo", e.minimo, 0], ["Máximo", e.maximo, 0]].map(([r, v, c]) => (
              <div key={r} style={{ background: "#F3EEE0", borderRadius: 8, padding: "6px 8px" }}>
                <div style={{ fontSize: 12.5, color: CORES.nota }}>{r}</div>
                <div style={{ fontSize: 17, fontWeight: 700 }}>{c === null ? (v ?? "—") : fmt(v, c)}</div>
              </div>
            ))}
          </div>
        </CartaoGrafico>

        <CartaoGrafico titulo="2. Tendência no tempo"
          sobre={`Média ${filtros.dias <= 30 ? "diária" : "semanal"} de humor, conforto e dor. A reta de tendência (mínimos quadrados) é calculada no banco com regr_slope.`}
          sql={d.sql.tendencia + ";\n\n" + d.sql.regressao}>
          {d.tendencia.length ? <GraficoLinhas linhas={d.tendencia} x="periodo" ys={["humor_medio", "conforto_medio", "dor_media"]} rotulo="" /> :
            <p style={{ fontSize: 15, color: CORES.nota }}>Sem check-ins no período.</p>}
          <p style={{ fontSize: 15, margin: "6px 0 0" }}>
            Tendência de <b>{M.rotulo.toLowerCase()}</b>: {tendMedida === null ? "—" : (
              <b style={{ color: Math.abs(tendMedida) < 0.02 ? CORES.nota : (tendMedida > 0) === (M.melhor === "maior") ? CORES.verde : CORES.alerta }}>
                {tendMedida > 0 ? "+" : ""}{fmt(tendMedida, 3)} ponto(s) por semana
              </b>
            )}
          </p>
        </CartaoGrafico>

        <CartaoGrafico titulo="3. Residentes por grau de dependência"
          sobre="Toque numa fatia (ou na legenda) para filtrar o dashboard inteiro por aquele grau. Toque de novo para voltar a todos."
          sql={d.sql.residentes_grau}>
          <GraficoPizza rosca selecionado={filtros.grau === "todos" ? null : filtros.grau}
            aoClicar={(g) => setFiltros({ ...filtros, grau: filtros.grau === g ? "todos" : g })}
            dados={d.residentes_grau.map((g, i) => ({ rotulo: `Grau ${g.categoria}`, chave: g.categoria, valor: n(g.total), cor: [CORES.verde, "#C2701F", CORES.alerta][i] }))} />
        </CartaoGrafico>

        <CartaoGrafico titulo="4. Intercorrências por tipo"
          sobre="Frequência de cada tipo de ocorrência no período (passe o dedo ou o mouse para ver o percentual)."
          sql={d.sql.intercorrencias_tipo}>
          <GraficoPizza dados={d.intercorrencias_tipo.map((t) => ({ rotulo: `${ROTULO_CAT[t.categoria] || t.categoria}${n(t.graves) ? ` (${t.graves} grave)` : ""}`, chave: t.categoria, valor: n(t.total) }))} />
        </CartaoGrafico>

        <CartaoGrafico titulo="5. Participação nas atividades"
          sobre="% dos residentes que foram a pelo menos uma atividade de cada tipo: período atual comparado ao anterior."
          sql={d.sql.radar_atividades}>
          <GraficoRadar eixos={d.radar_atividades.map((r) => ROTULO_CAT[r.categoria] || r.categoria)}
            series={[
              { nome: `Últimos ${filtros.dias} dias`, cor: CORES.anil, valores: d.radar_atividades.map((r) => n(r.pct_atual)) },
              { nome: "Período anterior", cor: "#C2701F", traco: "5 4", valores: d.radar_atividades.map((r) => n(r.pct_anterior)) },
            ]} />
        </CartaoGrafico>

        <CartaoGrafico titulo="6. Correlação: atividades × humor"
          sobre="Cada ponto é um residente. Quem participa de mais atividades está de melhor humor? O coeficiente de Pearson (corr) e a reta (regr_slope, regr_intercept) vêm do banco."
          sql={d.sql.dispersao + ";\n\n" + d.sql.correlacao}>
          <GraficoDispersao rotuloX="atividades no período" rotuloY="humor médio"
            pontos={d.dispersao.filter((p) => p.humor_medio !== null).map((p) => ({ x: n(p.atividades), y: n(p.humor_medio), rotulo: p.nome }))}
            reta={{ a: n(cor.intercepto), b: n(cor.inclinacao) }} />
          <p style={{ fontSize: 15, margin: "6px 0 0" }}>
            r = <b>{fmt(cor.r_pearson, 3)}</b> · r² = {fmt(cor.r2, 3)} · n = {cor.n} → {forcaCorrelacao(n(cor.r_pearson))}.
          </p>
        </CartaoGrafico>

        <CartaoGrafico titulo="7. Aceitação alimentar por refeição"
          sobre="Média do quanto foi aceito em cada refeição (0 a 100%), com o desvio padrão."
          sql={d.sql.refeicoes}>
          {d.refeicoes.length ? (
            <GraficoColunas sufixo="%" cor={CORES.verde}
              dados={d.refeicoes.map((r) => ({ rotulo: ROTULO_CAT[r.refeicao] || r.refeicao, valor: n(r.aceitacao_media),
                extra: `desvio padrão ${fmt(r.desvio_padrao)} · ${r.registros} registros · ${r.hidratacao_media_ml} ml de líquido` }))} />
          ) : <p style={{ fontSize: 15, color: CORES.nota }}>Sem refeições registradas no período.</p>}
        </CartaoGrafico>

        <CartaoGrafico titulo="8. Pressão arterial por classificação"
          sobre="Aferições do período classificadas pela função fn_classificar_pressao (Etapa 05), segundo a Diretriz Brasileira de Hipertensão."
          sql={d.sql.pressao}>
          {d.pressao.length ? (
            <GraficoBarrasH linhas={d.pressao.map((p) => ({ classe: p.classe, afericoes: n(p.afericoes) }))} x="classe" y="afericoes" rotulo="Nº de aferições" nomeInteiro />
          ) : <p style={{ fontSize: 15, color: CORES.nota }}>Sem aferições de pressão no período.</p>}
        </CartaoGrafico>
      </div>
    </div>
  );
}

// ============================================================
// CUIDADORES DE REFERÊNCIA — executa o procedimento com cursor
// sp_distribuir_cuidadores (Etapa 05) e mostra o resultado
// ============================================================
function PainelCuidadores({ token, demo }) {
  const [d, setD] = useState(null);
  const [log, setLog] = useState([]);
  const [msg, setMsg] = useState("");

  async function carregar() {
    if (demo) return setD({ cuidadores: [], sem_referencia: [], necessarios: 0 });
    try { setD(await api("/gestao/cuidadores", { token })); } catch (e) { setMsg(e.message); }
  }
  useEffect(() => { carregar(); }, []); // eslint-disable-line

  async function distribuir(refazer) {
    if (demo) return setMsg("A distribuição funciona com a API conectada.");
    setMsg("");
    try {
      const r = await api("/gestao/cuidadores/distribuir", { metodo: "POST", token, corpo: { refazer } });
      setLog(r.mensagens);
      carregar();
    } catch (e) { setMsg(e.message); }
  }

  if (!d) return <Cartao>Carregando…</Cartao>;
  return (
    <div>
      <Cartao>
        <p style={{ fontSize: 16, margin: "0 0 8px" }}>
          Cada residente tem um <b>cuidador de referência</b>. A divisão equilibra a carga de trabalho, não só o número de
          residentes: grau I vale 3 pontos, grau II vale 6 e grau III vale 10 (proporção da RDC 502).
        </p>
        <p style={{ fontSize: 15, color: CORES.nota, margin: "0 0 12px" }}>
          Os botões executam no banco o procedimento <code>sp_distribuir_cuidadores</code>. Ele usa um <b>cursor</b> e trata um
          residente por vez, sempre para o cuidador com menos carga naquele momento.
        </p>
        <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
          <BotaoGrande cor={CORES.verde} onClick={() => distribuir(false)} disabled={d.sem_referencia.length === 0}>
            {d.sem_referencia.length ? `Distribuir quem está sem referência (${d.sem_referencia.length})` : "Todos já têm referência ✓"}
          </BotaoGrande>
          <BotaoGrande onClick={() => distribuir(true)}>Refazer a divisão toda</BotaoGrande>
        </div>
        <Aviso msg={msg} />
      </Cartao>

      {log.length > 0 && (
        <Cartao borda={CORES.verde}>
          <p style={{ fontSize: 17, fontWeight: 700, margin: "0 0 6px" }}>O que o procedimento fez</p>
          <ol style={{ fontSize: 15, margin: 0, paddingLeft: 22, maxHeight: 220, overflowY: "auto" }}>
            {log.map((m, i) => <li key={i}>{m}</li>)}
          </ol>
        </Cartao>
      )}

      <Cartao>
        <p style={{ fontSize: 17, fontWeight: 700, margin: "0 0 4px" }}>
          Carga por cuidador · {d.cuidadores.length} na equipe, {d.necessarios} exigido(s) por turno (fn_cuidadores_necessarios)
        </p>
        {d.cuidadores.length === 0 ? <p style={{ fontSize: 15, color: CORES.nota }}>Nenhum cuidador ativo.</p> : (
          <>
            <GraficoBarrasH linhas={d.cuidadores} x="nome" y="pontos_de_carga" rotulo="Pontos de carga" />
            {d.cuidadores.map((c) => (
              <p key={c.id_profissional} style={{ fontSize: 14, margin: "4px 0" }}>
                <b>{nomeCurto(c.nome)}</b> ({c.residentes}): <span style={{ color: CORES.nota }}>{c.lista || "nenhum residente"}</span>
              </p>
            ))}
          </>
        )}
        {d.sem_referencia.length > 0 && (
          <p style={{ fontSize: 15, color: CORES.alerta, margin: "10px 0 0" }}>
            Sem referência: {d.sem_referencia.map((i) => `${nomeCurto(i.nome)} (${i.grau_dependencia})`).join(", ")}
          </p>
        )}
      </Cartao>
    </div>
  );
}

function ListaPessoas({ pessoas, token, demo, aoMudar }) {
  const [editando, setEditando] = useState(null); // {tipo, dados}
  const [msg, setMsg] = useState("");
  const [desligar, setDesligar] = useState(null);   // residente aguardando confirmação
  const [historico, setHistorico] = useState(null); // log do grau de dependência (trigger)

  async function toggle(tipo, id, ativoAtual) {
    if (demo) return setMsg("A ativação funciona com a API conectada.");
    try {
      const r = await api(`/gestao/${tipo}/${id}/ativo`, { metodo: "POST", token, corpo: { ativo: !ativoAtual } });
      // mensagens dos procedimentos do banco (desligamento / redistribuição de cuidadores)
      setMsg(r.mensagens && r.mensagens.length ? "✓ " + r.mensagens.join(" · ") : "");
      aoMudar();
    } catch (e) { setMsg(e.message); }
  }
  async function abrirEdicaoIdoso(i) {
    setEditando({ tipo: "idosos", dados: { id: i.id_idoso, nome: i.nome, grau_dependencia: i.grau_dependencia } });
    setHistorico(null);
    if (demo) return setHistorico([]);
    try { setHistorico(await api(`/gestao/idosos/${i.id_idoso}/historico-grau`, { token })); } catch { setHistorico([]); }
  }
  async function salvarEdicao() {
    const { tipo, dados } = editando;
    if (demo) { setEditando(null); return setMsg("A edição funciona com a API conectada."); }
    try {
      const corpo = tipo === "idosos"
        ? { nome: dados.nome, grau_dependencia: dados.grau_dependencia }
        : { nome: dados.nome, funcao: dados.funcao, registro_conselho: dados.registro_conselho };
      await api(`/gestao/${tipo}/${dados.id}`, { metodo: "PATCH", token, corpo });
      setEditando(null); aoMudar();
    } catch (e) { setMsg(e.message); }
  }

  if (!pessoas) return <Cartao>Carregando…</Cartao>;

  const linha = (nome, sub, ativo, onEdit, onToggle) => (
    <Cartao borda={ativo ? undefined : CORES.cinza}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 8 }}>
        <div style={{ opacity: ativo ? 1 : 0.55 }}>
          <b style={{ fontSize: 18 }}>{nome}</b>{!ativo && <span style={{ fontSize: 14, color: CORES.cinza, fontWeight: 700 }}> · INATIVO</span>}
          <div style={{ fontSize: 15, color: CORES.nota }}>{sub}</div>
        </div>
        <div style={{ display: "flex", gap: 6, flexShrink: 0 }}>
          <button onClick={onEdit} aria-label="Editar" style={{
            minHeight: 44, padding: "8px 12px", fontSize: 15, fontWeight: 700, borderRadius: 10,
            border: `2px solid ${CORES.anil}`, background: CORES.cartao, color: CORES.anil, cursor: "pointer",
            fontFamily: "'Atkinson Hyperlegible', sans-serif",
          }}>✏️</button>
          <button onClick={onToggle} style={{
            minHeight: 44, padding: "8px 12px", fontSize: 15, fontWeight: 700, borderRadius: 10, cursor: "pointer",
            border: `2px solid ${ativo ? CORES.alerta : CORES.verde}`, background: CORES.cartao,
            color: ativo ? CORES.alerta : CORES.verde, fontFamily: "'Atkinson Hyperlegible', sans-serif",
          }}>{ativo ? "Desativar" : "Reativar"}</button>
        </div>
      </div>
    </Cartao>
  );

  return (
    <div>
      <Aviso msg={msg} />
      <h3 style={{ fontSize: 20, margin: "0 0 8px" }}>Residentes ({pessoas.idosos.filter((i) => i.ativo).length} ativos)</h3>
      {pessoas.idosos.map((i) => linha(
        i.nome,
        `grau ${i.grau_dependencia} · ${i.email || "sem login próprio"}` +
          (i.ativo ? ` · cuidador de referência: ${i.cuidador_referencia ? nomeCurto(i.cuidador_referencia) : "não definido"}` : ""),
        i.ativo,
        () => abrirEdicaoIdoso(i),
        () => (i.ativo ? setDesligar(i) : toggle("idosos", i.id_idoso, i.ativo))
      ))}
      <h3 style={{ fontSize: 20, margin: "18px 0 8px" }}>Equipe ({pessoas.equipe.filter((p) => p.ativo).length} ativos)</h3>
      {pessoas.equipe.map((p) => linha(
        p.nome, `${p.funcao} · ${p.email}`, p.ativo,
        () => setEditando({ tipo: "profissionais", dados: { id: p.id_profissional, nome: p.nome, funcao: p.funcao, registro_conselho: p.registro_conselho || "" } }),
        () => toggle("profissionais", p.id_profissional, p.ativo)
      ))}

      {desligar && (
        <div role="dialog" aria-modal="true" aria-label="Confirmar desligamento" style={{
          position: "fixed", inset: 0, background: "rgba(38,32,26,0.5)", display: "flex",
          alignItems: "center", justifyContent: "center", padding: 16, zIndex: 50,
        }}>
          <div style={{ background: CORES.papel, borderRadius: 16, padding: 20, maxWidth: 460, width: "100%" }}>
            <h3 style={{ fontSize: 22, margin: "0 0 10px" }}>Desligar {desligar.nome}?</h3>
            <p style={{ fontSize: 16, margin: "0 0 8px" }}>
              Use em caso de alta, transferência ou óbito. O banco executa o procedimento
              <code> sp_desligar_residente</code>, que faz tudo de uma vez:
            </p>
            <ul style={{ fontSize: 16, margin: "0 0 12px", paddingLeft: 22 }}>
              <li>marca o residente e a conta dele como inativos;</li>
              <li>encerra hoje as prescrições ativas;</li>
              <li>suspende as metas ativas do plano de cuidado.</li>
            </ul>
            <p style={{ fontSize: 15, color: CORES.nota, margin: "0 0 14px" }}>Nada é apagado: o prontuário continua guardado.</p>
            <div style={{ display: "flex", gap: 10 }}>
              <BotaoGrande cor={CORES.alerta} onClick={() => { const i = desligar; setDesligar(null); toggle("idosos", i.id_idoso, true); }}>Desligar</BotaoGrande>
              <BotaoGrande cor={CORES.cinza} onClick={() => setDesligar(null)}>Cancelar</BotaoGrande>
            </div>
          </div>
        </div>
      )}

      {editando && (
        <div role="dialog" aria-modal="true" style={{
          position: "fixed", inset: 0, background: "rgba(38,32,26,0.5)", display: "flex",
          alignItems: "center", justifyContent: "center", padding: 16, zIndex: 50,
        }}>
          <div style={{ background: CORES.papel, borderRadius: 16, padding: 20, maxWidth: 460, width: "100%", maxHeight: "90vh", overflowY: "auto" }}>
            <h3 style={{ fontSize: 22, margin: "0 0 14px" }}>Editar {editando.tipo === "idosos" ? "residente" : "profissional"}</h3>
            <label style={rotuloG}>Nome</label>
            <input style={campoG} value={editando.dados.nome}
              onChange={(e) => setEditando({ ...editando, dados: { ...editando.dados, nome: e.target.value } })} />
            {editando.tipo === "idosos" ? (
              <>
                <label style={rotuloG}>Grau de dependência</label>
                <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
                  {["I", "II", "III"].map((g) => (
                    <button key={g} onClick={() => setEditando({ ...editando, dados: { ...editando.dados, grau_dependencia: g } })}
                      aria-pressed={editando.dados.grau_dependencia === g} style={{
                flex: 1, minHeight: 48, fontSize: 18, fontWeight: 700, borderRadius: 12,
                        border: editando.dados.grau_dependencia === g ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
                        background: editando.dados.grau_dependencia === g ? "#E7ECF8" : "#FFFDF4", cursor: "pointer",
                        fontFamily: "'Atkinson Hyperlegible', sans-serif",
                      }}>{g}</button>
                  ))}
                </div>
                {/* Histórico gravado pelo TRIGGER trg_log_grau_dependencia (tabela log_grau_dependencia) */}
                <div style={{ background: "#F3EEE0", borderRadius: 12, padding: "10px 12px", marginBottom: 12 }}>
                  <b style={{ fontSize: 15 }}>📜 Histórico do grau de dependência</b>
                  {!historico && <p style={{ fontSize: 14, margin: "6px 0 0", color: CORES.nota }}>Carregando…</p>}
                  {historico && historico.length === 0 && (
                    <p style={{ fontSize: 14, margin: "6px 0 0", color: CORES.nota }}>
                      Nenhuma mudança registrada. Ao salvar um grau diferente, o banco grava aqui (trigger).
                    </p>
                  )}
                  {historico && historico.map((h) => (
                    <p key={h.id_log} style={{ fontSize: 14, margin: "6px 0 0" }}>
                      {horaData(h.data_hora)} · <b>{h.grau_anterior} → {h.grau_novo}</b> por {h.alterado_por}
                      <span style={{ color: CORES.nota }}> · a ILPI passou a precisar de {h.cuidadores_necessarios} cuidador(es) por turno</span>
                    </p>
                  ))}
                </div>
              </>
            ) : (
              <>
                <label style={rotuloG}>Função</label>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 12 }}>
                  {FUNCOES_PROF.map((o) => (
                    <button key={o.v} onClick={() => setEditando({ ...editando, dados: { ...editando.dados, funcao: o.v } })}
                      aria-pressed={editando.dados.funcao === o.v} style={{
                        fontSize: 15, fontWeight: 700, padding: "8px 10px", borderRadius: 10,
                        border: editando.dados.funcao === o.v ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
                        background: editando.dados.funcao === o.v ? "#E7ECF8" : "#FFFDF4", cursor: "pointer",
                        fontFamily: "'Atkinson Hyperlegible', sans-serif",
                      }}>{o.r}</button>
                  ))}
                </div>
                <label style={rotuloG}>Registro no conselho</label>
                <input style={campoG} value={editando.dados.registro_conselho}
                  onChange={(e) => setEditando({ ...editando, dados: { ...editando.dados, registro_conselho: e.target.value } })} />
              </>
            )}
            <div style={{ display: "flex", gap: 10, marginTop: 8 }}>
              <BotaoGrande onClick={salvarEdicao}>Salvar</BotaoGrande>
              <BotaoGrande onClick={() => setEditando(null)} cor={CORES.cinza}>Cancelar</BotaoGrande>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ---------- Meus recados no mural: editar e apagar (só o autor; o RLS garante) ----------
function MeusRecados({ id_idoso, token, demo, versao }) {
  const [lista, setLista] = useState(null);
  const [editando, setEditando] = useState(null);     // { id, texto }
  const [confirmando, setConfirmando] = useState(null); // id do recado a apagar
  const [msg, setMsg] = useState("");

  async function carregar() {
    if (demo) {
      if (lista === null) setLista([{ id_recado: 1, texto: "Domingo levo as crianças pra te ver!", data_hora: new Date().toISOString(), editado_em: null, meu: true }]);
      return;
    }
    try { const todos = await api(`/idosos/${id_idoso}/recados`, { token }); setLista(todos.filter((r) => r.meu)); }
    catch { setLista([]); }
  }
  useEffect(() => { carregar(); }, [versao]); // eslint-disable-line

  async function salvar() {
    if (!editando.texto.trim()) return setMsg("O recado não pode ficar vazio.");
    if (demo) {
      setLista(lista.map((r) => r.id_recado === editando.id ? { ...r, texto: editando.texto, editado_em: new Date().toISOString() } : r));
      setEditando(null); return setMsg("✓ (demonstração) Recado atualizado.");
    }
    try {
      await api(`/recados/${editando.id}`, { metodo: "PATCH", token, corpo: { texto: editando.texto } });
      setEditando(null); setMsg("✓ Recado atualizado."); carregar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }
  async function apagar(id) {
    setConfirmando(null);
    if (demo) { setLista(lista.filter((r) => r.id_recado !== id)); return setMsg("✓ (demonstração) Recado apagado."); }
    try { await api(`/recados/${id}`, { metodo: "DELETE", token }); setMsg("✓ Recado apagado do mural."); carregar(); }
    catch (e) { setMsg(`Não deu (${e.message}).`); }
  }

  if (!lista || lista.length === 0) return msg ? <div style={{ marginTop: 10 }}><Aviso msg={msg} /></div> : null;
  const botao = (cor) => ({
    fontSize: 15, fontWeight: 700, padding: "6px 12px", borderRadius: 10, cursor: "pointer",
    border: `2px solid ${cor}`, background: CORES.cartao, color: cor, fontFamily: "'Atkinson Hyperlegible', sans-serif",
  });
  return (
    <div style={{ marginTop: 14 }}>
      <b style={{ fontSize: 16 }}>Recados que você enviou</b>
      {msg && <div style={{ marginTop: 6 }}><Aviso msg={msg} /></div>}
      {lista.slice(0, 5).map((r) => (
        <div key={r.id_recado} style={{ borderBottom: "1px solid #E4DCC9", padding: "8px 0" }}>
          {editando && editando.id === r.id_recado ? (
            <>
              <textarea aria-label="Editar recado" value={editando.texto} maxLength={500} rows={2}
                onChange={(e) => setEditando({ ...editando, texto: e.target.value })}
                style={{ ...campoG, marginBottom: 6, resize: "vertical" }} />
              <div style={{ display: "flex", gap: 8 }}>
                <button onClick={salvar} style={botao(CORES.verde)}>Salvar</button>
                <button onClick={() => setEditando(null)} style={botao(CORES.nota)}>Cancelar</button>
              </div>
            </>
          ) : (
            <>
              <div style={{ fontSize: 16 }}>{r.texto}</div>
              <div style={{ fontSize: 13, color: CORES.nota, margin: "2px 0 6px" }}>
                {dataCurta(r.data_hora)}{r.editado_em ? " · editado" : ""}
              </div>
              {confirmando === r.id_recado ? (
                <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap" }}>
                  <span style={{ fontSize: 15, fontWeight: 700 }}>Apagar este recado?</span>
                  <button onClick={() => apagar(r.id_recado)} style={botao(CORES.alerta)}>Sim, apagar</button>
                  <button onClick={() => setConfirmando(null)} style={botao(CORES.nota)}>Não</button>
                </div>
              ) : (
                <div style={{ display: "flex", gap: 8 }}>
                  <button onClick={() => { setMsg(""); setEditando({ id: r.id_recado, texto: r.texto }); }} style={botao(CORES.anil)}>✏️ Editar</button>
                  <button onClick={() => { setMsg(""); setConfirmando(r.id_recado); }} style={botao(CORES.alerta)}>🗑️ Apagar</button>
                </div>
              )}
            </>
          )}
        </div>
      ))}
    </div>
  );
}

const campoG = {
  width: "100%", boxSizing: "border-box", fontSize: 17, padding: 12,
  border: "2px solid #26201A", borderRadius: 12, marginBottom: 12,
  fontFamily: "'Atkinson Hyperlegible', sans-serif", background: "#FFFDF4",
};
const rotuloG = { display: "block", fontSize: 17, fontWeight: 700, marginBottom: 6 };

function Aviso({ msg }) {
  if (!msg) return null;
  return (
    <p role="status" style={{
      fontSize: 17, fontWeight: 700, borderRadius: 12, padding: "10px 14px", marginBottom: 12,
      background: msg.startsWith("✓") ? CORES.verdeFundo : CORES.aviso,
      border: `2px solid ${msg.startsWith("✓") ? CORES.verde : CORES.destaque}`,
    }}>{msg}</p>
  );
}

function FormIdoso({ token, demo, aoSalvar }) {
  const [f, setF] = useState({ nome: "", cpf: "", data_nascimento: "", grau_dependencia: "I", email: "", senha: "", petNome: "" });
  const [msg, setMsg] = useState("");
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });
  async function salvar() {
    if (!f.nome || !f.cpf || !f.data_nascimento) return setMsg("Preencha nome, CPF e data de nascimento.");
    if (demo) return setMsg("✓ (demonstração) Idoso cadastrado.");
    try {
      await api("/gestao/idosos", { metodo: "POST", token, corpo: {
        nome: f.nome, cpf: f.cpf, data_nascimento: f.data_nascimento, grau_dependencia: f.grau_dependencia,
        email: f.email || undefined, senha: f.senha || undefined,
        pet: f.petNome ? { nome: f.petNome } : undefined,
      }});
      setMsg("✓ Idoso cadastrado!");
      setF({ nome: "", cpf: "", data_nascimento: "", grau_dependencia: "I", email: "", senha: "", petNome: "" });
      aoSalvar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }
  return (
    <Cartao>
      <Aviso msg={msg} />
      <label style={rotuloG}>Nome completo</label>
      <input style={campoG} value={f.nome} onChange={set("nome")} />
      <label style={rotuloG}>CPF (só números)</label>
      <input style={campoG} value={f.cpf} onChange={set("cpf")} inputMode="numeric" />
      <label style={rotuloG}>Data de nascimento</label>
      <input style={campoG} type="date" value={f.data_nascimento} onChange={set("data_nascimento")} />
      <label style={rotuloG}>Grau de dependência (RDC 502)</label>
      <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
        {["I", "II", "III"].map((g) => (
          <button key={g} onClick={() => setF({ ...f, grau_dependencia: g })} aria-pressed={f.grau_dependencia === g} style={{
            flex: 1, minHeight: 48, fontSize: 18, fontWeight: 700, borderRadius: 12,
            border: f.grau_dependencia === g ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
            background: f.grau_dependencia === g ? "#E7ECF8" : "#FFFDF4", cursor: "pointer",
            fontFamily: "'Atkinson Hyperlegible', sans-serif",
          }}>{g}</button>
        ))}
      </div>
      <p style={{ fontSize: 15, color: CORES.nota, margin: "6px 0 10px" }}>
        Login é opcional — preencha se o idoso for usar o app sozinho.
      </p>
      <label style={rotuloG}>Email (opcional)</label>
      <input style={campoG} type="email" value={f.email} onChange={set("email")} />
      <label style={rotuloG}>Senha provisória (opcional)</label>
      <input style={campoG} value={f.senha} onChange={set("senha")} />
      <label style={rotuloG}>Nome do bichinho (opcional)</label>
      <input style={campoG} value={f.petNome} onChange={set("petNome")} placeholder="Ex.: Xodó" />
      <BotaoGrande onClick={salvar}>Cadastrar residente</BotaoGrande>
    </Cartao>
  );
}

function FormProfissional({ token, demo, aoSalvar }) {
  const [f, setF] = useState({ nome: "", funcao: "cuidador", email: "", senha: "", registro: "" });
  const [msg, setMsg] = useState("");
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });
  async function salvar() {
    if (!f.nome || !f.email || !f.senha) return setMsg("Preencha nome, email e senha.");
    if (demo) return setMsg("✓ (demonstração) Profissional cadastrado.");
    try {
      await api("/gestao/profissionais", { metodo: "POST", token, corpo: {
        nome: f.nome, funcao: f.funcao, email: f.email, senha: f.senha, registro_conselho: f.registro || undefined,
      }});
      setMsg("✓ Profissional cadastrado!");
      setF({ nome: "", funcao: "cuidador", email: "", senha: "", registro: "" });
      aoSalvar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }
  return (
    <Cartao>
      <Aviso msg={msg} />
      <label style={rotuloG}>Nome completo</label>
      <input style={campoG} value={f.nome} onChange={set("nome")} />
      <label style={rotuloG}>Função</label>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 12 }}>
        {FUNCOES_PROF.map((o) => (
          <button key={o.v} onClick={() => setF({ ...f, funcao: o.v })} aria-pressed={f.funcao === o.v} style={{
            fontSize: 15, fontWeight: 700, padding: "10px 12px", borderRadius: 12,
            border: f.funcao === o.v ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
            background: f.funcao === o.v ? "#E7ECF8" : "#FFFDF4", cursor: "pointer",
            fontFamily: "'Atkinson Hyperlegible', sans-serif",
          }}>{o.r}</button>
        ))}
      </div>
      <label style={rotuloG}>Registro no conselho (opcional — COREN, CRM, CRP…)</label>
      <input style={campoG} value={f.registro} onChange={set("registro")} />
      <label style={rotuloG}>Email</label>
      <input style={campoG} type="email" value={f.email} onChange={set("email")} />
      <label style={rotuloG}>Senha provisória</label>
      <input style={campoG} value={f.senha} onChange={set("senha")} />
      <BotaoGrande onClick={salvar}>Cadastrar profissional</BotaoGrande>
    </Cartao>
  );
}

function FormResponsavel({ token, demo, idosos, aoSalvar }) {
  const [f, setF] = useState({ nome: "", telefone: "", email: "", senha: "", id_idoso: null, parentesco: "", legal: false });
  const [msg, setMsg] = useState("");
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });
  async function salvar() {
    if (!f.nome || !f.telefone || !f.email || !f.senha || !f.id_idoso || !f.parentesco)
      return setMsg("Preencha todos os campos e escolha o residente.");
    if (demo) return setMsg("✓ (demonstração) Responsável cadastrado e vinculado.");
    try {
      await api("/gestao/responsaveis", { metodo: "POST", token, corpo: {
        nome: f.nome, telefone: f.telefone, email: f.email, senha: f.senha,
        id_idoso: Number(f.id_idoso), parentesco: f.parentesco, responsavel_legal: f.legal,
      }});
      setMsg("✓ Responsável cadastrado e vinculado!");
      setF({ nome: "", telefone: "", email: "", senha: "", id_idoso: null, parentesco: "", legal: false });
      aoSalvar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }
  return (
    <Cartao>
      <Aviso msg={msg} />
      <label style={rotuloG}>Residente a acompanhar</label>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 12 }}>
        {(idosos || []).map((i) => (
          <button key={i.id_idoso} onClick={() => setF({ ...f, id_idoso: i.id_idoso })} aria-pressed={f.id_idoso === i.id_idoso} style={{
            fontSize: 15, fontWeight: 700, padding: "10px 12px", borderRadius: 12,
            border: f.id_idoso === i.id_idoso ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
            background: f.id_idoso === i.id_idoso ? "#E7ECF8" : "#FFFDF4", cursor: "pointer",
            fontFamily: "'Atkinson Hyperlegible', sans-serif",
          }}>{i.nome.split(" ")[0]}</button>
        ))}
      </div>
      <label style={rotuloG}>Nome do responsável</label>
      <input style={campoG} value={f.nome} onChange={set("nome")} />
      <label style={rotuloG}>Parentesco</label>
      <input style={campoG} value={f.parentesco} onChange={set("parentesco")} placeholder="Ex.: filho, neta, sobrinho" />
      <label style={rotuloG}>Telefone (com DDD)</label>
      <input style={campoG} value={f.telefone} onChange={set("telefone")} inputMode="numeric" />
      <label style={{ display: "flex", alignItems: "center", gap: 10, fontSize: 17, fontWeight: 700, marginBottom: 12, cursor: "pointer" }}>
        <input type="checkbox" checked={f.legal} onChange={(e) => setF({ ...f, legal: e.target.checked })} style={{ width: 24, height: 24 }} />
        É o responsável legal
      </label>
      <label style={rotuloG}>Email</label>
      <input style={campoG} type="email" value={f.email} onChange={set("email")} />
      <label style={rotuloG}>Senha provisória</label>
      <input style={campoG} value={f.senha} onChange={set("senha")} />
      <BotaoGrande onClick={salvar}>Cadastrar responsável</BotaoGrande>
    </Cartao>
  );
}

// ============================================================
export default function BemViverILPI() {
  const [fator, setFator] = useState(1); // controle de tamanho das letras (A− / A+)
  const [voz, setVoz] = useState(false); // leitura em voz alta
  useEffect(() => { document.documentElement.lang = "pt-BR"; }, []);
  const [token, setToken] = useState(null);
  const [perfil, setPerfil] = useState(null);
  const [funcao, setFuncao] = useState(null);
  const [ehGestor, setEhGestor] = useState(false);
  const [demo, setDemo] = useState(false);
  const [email, setEmail] = useState("dona.severina@email.com");
  const [senha, setSenha] = useState("demo123");
  const [aviso, setAviso] = useState("");
  const [painel, setPainel] = useState([]);
  const [alertas, setAlertas] = useState([]);
  const [historicos, setHistoricos] = useState({}); // id_idoso -> registros

  useEffect(() => {
    if (!token || demo) return;
    sincronizarFila(token);
    const t = setInterval(() => sincronizarFila(token), 30_000);
    return () => clearInterval(t);
  }, [token, demo]); // eslint-disable-line

  async function entrar(perfilDemo) {
    if (perfilDemo === "demonstracao") {
      setDemo(true);
      setPerfil("responsavel");
      setPainel(DEMO.painel);
      setAlertas(DEMO.alertas);
      setHistoricos({ 1: DEMO.historico });
      return;
    }
    setAviso("Entrando…");
    try {
      const r = await api("/auth/login", { metodo: "POST", corpo: { email, senha } });
      const p = await api("/painel", { token: r.token });
      setToken(r.token);
      setPerfil(r.perfil);
      setFuncao(r.funcao || null);
      setPainel(p);
      if (r.funcao === "gestor") { setEhGestor(true); }
      if (r.perfil === "profissional") setAlertas(await api("/alertas/checkins", { token: r.token }));
      setAviso("");
    } catch (e) {
      setAviso(`Não consegui entrar (${e.message}). Confira a senha, ou veja a demonstração.`);
      falar("Não consegui entrar. Confira a senha, ou veja a demonstração.");
    }
  }

  async function carregarHistorico(id_idoso) {
    if (historicos[id_idoso]) return;
    if (demo) return setHistoricos((h) => ({ ...h, [id_idoso]: DEMO.historico }));
    try {
      const r = await api(`/idosos/${id_idoso}/bem-estar`, { token });
      setHistoricos((h) => ({ ...h, [id_idoso]: r }));
    } catch {}
  }

  async function enviarCheckin(dados) {
    if (demo) return { pontos_pet: 10 };
    try {
      return await api("/checkins", { metodo: "POST", token, corpo: dados });
    } catch (e) {
      if (ehErroDeRede(e)) { enfileirar("/checkins", dados); return { offline: true }; }
      throw e;
    }
  }

  function sair() {
    setToken(null); setPerfil(null); setFuncao(null); setEhGestor(false); setDemo(false);
    setPainel([]); setAlertas([]); setHistoricos({});
  }

  return (
    <div style={{
      minHeight: "100vh", background: CORES.papel, color: CORES.tinta,
      fontFamily: "'Atkinson Hyperlegible', sans-serif", fontSize: 19, lineHeight: 1.45,
      zoom: fator,
    }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:wght@400;700&family=Alfa+Slab+One&display=swap');
        * { -webkit-tap-highlight-color: transparent; }
        button:focus-visible, input:focus-visible, textarea:focus-visible {
          outline: 4px solid #27418F; outline-offset: 2px;
        }
        @media (prefers-reduced-motion: reduce) { * { transition: none !important; animation: none !important; } }
      `}</style>

      <header style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "14px 18px", borderBottom: `3px solid ${CORES.tinta}`, background: CORES.cartao,
      }}>
        <div>
          <div style={{ fontFamily: "'Alfa Slab One', serif", fontSize: 24, color: CORES.anil }}>Bem Viver ILPI</div>
          {perfil && (
            <div style={{ fontSize: 15, color: CORES.nota }}>
              {demo ? "demonstração" : ehGestor ? "gestão da ILPI" : { idoso: "área do idoso", responsavel: "área do responsável", profissional: "área da equipe" }[perfil]}
            </div>
          )}
        </div>
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          <button aria-pressed={voz} aria-label={voz ? "Desligar a leitura em voz alta" : "Ligar a leitura em voz alta"}
            onClick={() => {
              const nova = !voz;
              setVoz(nova);
              Voz.ativa = nova;
              if (nova) falar("Leitura em voz alta ligada. Vou ler as mensagens para você.");
              else if (window.speechSynthesis) window.speechSynthesis.cancel();
            }} style={{
              minWidth: 48, minHeight: 48, fontSize: 21, borderRadius: 12,
              border: voz ? `3px solid ${CORES.anil}` : `2px solid ${CORES.tinta}`,
              background: voz ? "#E7ECF8" : CORES.papel, cursor: "pointer",
              fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>{voz ? "🔊" : "🔈"}</button>
          <button aria-label="Diminuir o tamanho das letras"
            onClick={() => setFator((f) => Math.max(0.9, +(f - 0.15).toFixed(2)))} style={{
              minWidth: 48, minHeight: 48, fontSize: 17, fontWeight: 700, borderRadius: 12,
              border: `2px solid ${CORES.tinta}`, background: CORES.papel, cursor: "pointer",
              fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>A−</button>
          <button aria-label="Aumentar o tamanho das letras"
            onClick={() => setFator((f) => Math.min(1.45, +(f + 0.15).toFixed(2)))} style={{
              minWidth: 48, minHeight: 48, fontSize: 21, fontWeight: 700, borderRadius: 12,
              border: `2px solid ${CORES.tinta}`, background: CORES.papel, cursor: "pointer",
              fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>A+</button>
          {perfil && (
            <button onClick={sair} style={{
              fontSize: 17, fontWeight: 700, padding: "10px 16px", borderRadius: 12, minHeight: 48,
              border: `2px solid ${CORES.tinta}`, background: CORES.papel, cursor: "pointer",
              fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>Sair</button>
          )}
        </div>
      </header>

      {/* ---------- LOGIN ---------- */}
      {!perfil && (
        <main style={{ maxWidth: 480, margin: "0 auto", padding: 22 }}>
          <p style={{ fontSize: 20, textAlign: "center", margin: "10px 0 18px" }}>
            Acompanhamento de bem-estar nos lares de Pernambuco.
          </p>
          <div style={{ display: "flex", gap: 8, marginBottom: 18 }}>
            {CONTAS_DEMO.map((c) => (
              <button key={c.email} onClick={() => { setEmail(c.email); setSenha("demo123"); }} aria-pressed={email === c.email} style={{
                flex: 1, fontSize: 15, fontWeight: 700, padding: "10px 6px", borderRadius: 12,
                border: email === c.email ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
                background: email === c.email ? "#E7ECF8" : CORES.cartao, cursor: "pointer",
                fontFamily: "'Atkinson Hyperlegible', sans-serif",
              }}>{c.rotulo}</button>
            ))}
          </div>
          <label style={{ display: "block", fontSize: 18, fontWeight: 700, marginBottom: 6 }} htmlFor="campo-email">Seu email</label>
          <input id="campo-email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} style={{
            width: "100%", boxSizing: "border-box", fontSize: 19, padding: 14,
            border: `2px solid ${CORES.tinta}`, borderRadius: 12, marginBottom: 14,
            fontFamily: "'Atkinson Hyperlegible', sans-serif", background: CORES.cartao,
          }} />
          <label style={{ display: "block", fontSize: 18, fontWeight: 700, marginBottom: 6 }} htmlFor="campo-senha">Sua senha</label>
          <input id="campo-senha" type="password" value={senha} onChange={(e) => setSenha(e.target.value)} style={{
            width: "100%", boxSizing: "border-box", fontSize: 19, padding: 14,
            border: `2px solid ${CORES.tinta}`, borderRadius: 12, marginBottom: 16,
            fontFamily: "'Atkinson Hyperlegible', sans-serif", background: CORES.cartao,
          }} />
          {aviso && (
            <p role="alert" style={{
              fontSize: 18, fontWeight: 700, background: CORES.aviso,
              border: `2px solid ${CORES.destaque}`, borderRadius: 12, padding: "10px 14px",
            }}>{aviso}</p>
          )}
          <div style={{ display: "flex", flexDirection: "column", gap: 12, marginTop: 8 }}>
            <BotaoGrande onClick={() => entrar()}>Entrar</BotaoGrande>
            <BotaoGrande onClick={() => entrar("demonstracao")} cor={CORES.cinza}>Ver demonstração (sem conexão)</BotaoGrande>
          </div>
        </main>
      )}

      {perfil === "idoso" && <VisaoIdoso painel={painel} enviar={enviarCheckin} token={token} demo={demo} />}
      {perfil === "responsavel" && (
        <VisaoResponsavel painel={painel} historicos={historicos} carregar={carregarHistorico} token={token} demo={demo} />
      )}
      {perfil === "profissional" && ehGestor && (
        <VisaoGestor token={token} demo={demo} />
      )}
      {perfil === "profissional" && !ehGestor && (
        <VisaoEquipe painel={painel} alertas={alertas} historicos={historicos}
          carregar={carregarHistorico} enviar={enviarCheckin} token={token} demo={demo} funcao={funcao} />
      )}
    </div>
  );
}

// ============================================================
// ÁREA DO IDOSO — check-in diário
// ============================================================
function VisaoIdoso({ painel, enviar, token, demo }) {
  const eu = painel[0] || {};
  const [aba, setAba] = useState("dia"); // dia | domino
  const [humor, setHumor] = useState(null);
  const [conforto, setConforto] = useState(null);
  const [dor, setDor] = useState(null);
  const [obs, setObs] = useState("");
  const [feito, setFeito] = useState(null);
  const [erro, setErro] = useState("");

  async function confirmar() {
    if (humor == null || conforto == null || dor == null)
      return setErro("Falta responder alguma pergunta acima.");
    setErro("");
    try {
      const r = await enviar({ id_idoso: eu.id_idoso, humor, conforto, dor, observacoes: obs || undefined });
      setFeito(r);
      falar(r.offline
        ? "Guardei o seu registro! Envio sozinho assim que a conexão voltar."
        : `Obrigado por contar como você está!${r.pontos_pet ? ` ${eu.pet || "Seu bichinho"} ganhou ${r.pontos_pet} pontos!` : ""}`);
    } catch (e) {
      setErro(`Não consegui enviar (${e.message}). Tente de novo daqui a pouco.`);
    }
  }

  const Abas = (
    <div role="tablist" aria-label="Áreas do aplicativo" style={{ display: "flex", gap: 8, marginBottom: 18 }}>
      {[["dia", "✅ Dia"], ["agenda", "📅 Agenda"], ["domino", "🁫 Jogo"], ["pet", `🐾 ${(eu.pet || "Pet")}`], ["recados", "💌 Recados"]].map(([id, rot]) => (
        <button key={id} role="tab" aria-selected={aba === id} onClick={() => { setAba(id); falar(rot.replace(/[^\wÀ-ÿ ]/g, "").trim()); }} style={{
          flex: 1, fontSize: 18, fontWeight: 700, padding: "12px 6px", borderRadius: 12,
          border: aba === id ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
          background: aba === id ? "#E7ECF8" : CORES.cartao, cursor: "pointer",
          fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>{rot}</button>
      ))}
    </div>
  );

  if (aba === "agenda")
    return (
      <main style={{ maxWidth: 560, margin: "0 auto", padding: 22 }}>
        {Abas}
        <AgendaIdoso token={token} demo={demo} />
      </main>
    );

  if (aba === "recados")
    return (
      <main style={{ maxWidth: 560, margin: "0 auto", padding: 22 }}>
        {Abas}
        <VisaoRecados token={token} demo={demo} eu={eu} />
      </main>
    );

  if (aba === "pet")
    return (
      <main style={{ maxWidth: 560, margin: "0 auto", padding: 22 }}>
        {Abas}
        <VisaoPet token={token} demo={demo} nomePet={eu.pet} />
      </main>
    );

  if (aba === "domino")
    return (
      <main style={{ maxWidth: 560, margin: "0 auto", padding: 22 }}>
        {Abas}
        <MenuJogos token={token} demo={demo} eu={eu} />
      </main>
    );

  if (feito)
    return (
      <main style={{ maxWidth: 520, margin: "0 auto", padding: 22, textAlign: "center" }}>
        <div style={{ textAlign: "left" }}>{Abas}</div>
        <div style={{ fontSize: 64, margin: "20px 0 8px" }}>🐦</div>
        <h2 style={{ fontSize: 28, margin: "0 0 8px" }}>{feito.offline ? "Guardei o seu registro!" : "Obrigado por contar como você está!"}</h2>
        {feito.offline && (
          <p style={{ fontSize: 19, color: "#77560C", fontWeight: 700 }}>
            Sem internet agora — envio sozinho assim que a conexão voltar. 💛
          </p>
        )}
        {!feito.offline && feito.pontos_pet > 0 && (
          <p style={{
            fontSize: 21, fontWeight: 700, color: CORES.verde, background: CORES.verdeFundo,
            border: `2px solid ${CORES.verde}`, borderRadius: 12, padding: "10px 16px", display: "inline-block",
          }}>
            {eu.pet || "Seu bichinho"} ganhou +{feito.pontos_pet} pontos!
          </p>
        )}
        <p style={{ fontSize: 19, color: CORES.nota, marginTop: 14 }}>Até amanhã! Volte sempre que quiser conversar sobre o seu dia.</p>
      </main>
    );

  return (
    <main style={{ maxWidth: 520, margin: "0 auto", padding: 22 }}>
      {Abas}
      <h2 style={{ fontSize: 26, margin: "6px 0 4px" }}>Como você está hoje{eu.nome ? `, ${eu.nome.split(" ")[0]}` : ""}?</h2>
      <p style={{ fontSize: 18, color: CORES.nota, margin: "0 0 20px" }}>
        São só três toques. {eu.pet ? `O ${eu.pet} ganha pontos quando você responde.` : ""}
      </p>
      <Escala rotulo="Como está o seu ânimo?" opcoes={OP_HUMOR} valor={humor} aoEscolher={setHumor} />
      <Escala rotulo="E o conforto? (1 = ruim, 5 = ótimo)" opcoes={OP_CONFORTO} valor={conforto} aoEscolher={setConforto} />
      <Escala rotulo="Sente alguma dor? (0 = nenhuma, 10 = muito forte)" opcoes={OP_DOR} valor={dor} aoEscolher={setDor} />
      <label htmlFor="campo-obs-dia" style={{ display: "block", fontSize: 19, fontWeight: 700, marginBottom: 6 }}>
        Quer contar mais alguma coisa? (não precisa)
      </label>
      <textarea id="campo-obs-dia" value={obs} onChange={(e) => setObs(e.target.value)} rows={3} style={{
        width: "100%", boxSizing: "border-box", fontSize: 19, padding: 12,
        border: `2px solid ${CORES.tinta}`, borderRadius: 12, marginBottom: 14,
        fontFamily: "'Atkinson Hyperlegible', sans-serif", background: CORES.cartao, resize: "vertical",
      }} />
      {erro && (
        <p role="alert" style={{
          fontSize: 18, fontWeight: 700, background: CORES.aviso,
          border: `2px solid ${CORES.destaque}`, borderRadius: 12, padding: "10px 14px",
        }}>{erro}</p>
      )}
      <BotaoGrande onClick={confirmar}>Enviar o meu dia</BotaoGrande>
    </main>
  );
}

// ============================================================
// AGENDA — lado do idoso
// ============================================================
function AgendaIdoso({ token, demo }) {
  const [lista, setLista] = useState(null);
  const [msg, setMsg] = useState("");

  async function carregar() {
    if (demo || !token) return setLista(DEMO.agenda);
    try { setLista(await api("/atividades", { token })); } catch { setLista([]); }
  }
  useEffect(() => { carregar(); }, []); // eslint-disable-line

  async function confirmar(a) {
    if (demo) { setMsg(`✓ Presença confirmada no ${a.nome}! Xodó +30`); return; }
    try {
      const r = await api(`/atividades/${a.id_atividade}/confirmar`, { metodo: "POST", token, corpo: { nivel_engajamento: 5 } });
      setMsg(`✓ Presença confirmada! ${r.pontos_pet ? "Seu bichinho ganhou +" + r.pontos_pet + " pontos." : ""}`);
      falar(`Presença confirmada no ${a.nome}!`);
      carregar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }

  if (!lista) return <Cartao>Abrindo a agenda…</Cartao>;
  return (
    <div>
      <h2 style={{ fontSize: 24, margin: "0 0 4px" }}>📅 O que vai ter</h2>
      <p style={{ fontSize: 17, color: CORES.nota, margin: "0 0 14px" }}>
        Confirme presença nas atividades que quiser. Participar deixa o seu bichinho feliz!
      </p>
      <Aviso msg={msg} />
      {lista.length === 0 && <Cartao>Nenhuma atividade marcada por enquanto.</Cartao>}
      {lista.map((a) => {
        const cat = CAT_ATIV[a.categoria] || { r: a.categoria, emoji: "•" };
        return (
          <Cartao key={a.id_atividade} borda={a.eu_confirmei ? CORES.verde : undefined}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 10 }}>
              <div>
                <b style={{ fontSize: 20 }}>{cat.emoji} {a.nome}</b>
                <div style={{ fontSize: 16, color: CORES.nota }}>{cat.r} · {horaData(a.data_hora)}</div>
                <div style={{ fontSize: 15, color: CORES.nota, marginTop: 2 }}>{a.confirmados} confirmado(s)</div>
              </div>
              {a.eu_confirmei ? (
                <span style={{ fontSize: 16, fontWeight: 700, color: CORES.verde, background: CORES.verdeFundo, border: `2px solid ${CORES.verde}`, borderRadius: 10, padding: "8px 12px", whiteSpace: "nowrap" }}>
                  ✓ Vou!
                </span>
              ) : (
                <button onClick={() => confirmar(a)} style={{
                  fontSize: 16, fontWeight: 700, padding: "12px 16px", borderRadius: 12, minHeight: 52,
                  border: "none", background: CORES.anil, color: "#fff", cursor: "pointer",
                  fontFamily: "'Atkinson Hyperlegible', sans-serif", whiteSpace: "nowrap",
                }}>Vou participar</button>
              )}
            </div>
          </Cartao>
        );
      })}
    </div>
  );
}

// ============================================================
// MURAL DA FAMÍLIA — lado do idoso
// ============================================================
function VisaoRecados({ token, demo, eu }) {
  const [recados, setRecados] = useState(null);
  useEffect(() => {
    if (demo || !token || !eu.id_idoso) return setRecados(DEMO.recados);
    api(`/idosos/${eu.id_idoso}/recados`, { token }).then(setRecados).catch(() => setRecados([]));
  }, []); // eslint-disable-line

  if (!recados) return <Cartao>Abrindo o mural…</Cartao>;
  return (
    <div>
      <h2 style={{ fontSize: 24, margin: "0 0 4px" }}>💌 Recados da família</h2>
      <p style={{ fontSize: 17, color: CORES.nota, margin: "0 0 16px" }}>
        Toque em "Ouvir" para o recado ser lido em voz alta.
      </p>
      {recados.length === 0 && (
        <Cartao>Ainda não chegaram recados. Eles aparecem aqui assim que a família escrever.</Cartao>
      )}
      {recados.map((r) => (
        <Cartao key={r.id_recado}>
          <div style={{ display: "flex", justifyContent: "space-between", gap: 8, marginBottom: 6 }}>
            <b style={{ fontSize: 18 }}>De {r.de}</b>
            <span style={{ fontSize: 15, color: CORES.nota, whiteSpace: "nowrap" }}>{dataCurta(r.data_hora)}</span>
          </div>
          <p style={{ fontSize: 20, margin: "0 0 12px", lineHeight: 1.5 }}>{r.texto}</p>
          <button onClick={() => falarSempre(`Recado de ${r.de}: ${r.texto}`)} style={{
            fontSize: 18, fontWeight: 700, padding: "12px 18px", borderRadius: 12, minHeight: 52,
            border: `2px solid ${CORES.anil}`, background: "#E7ECF8", color: CORES.anil,
            cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif",
          }}>🔊 Ouvir</button>
        </Cartao>
      ))}
    </div>
  );
}

// ---------- Prontuário unificado ----------
const EVENTO_PRONT = {
  bem_estar: { emoji: "😊", cor: "#27418F", rot: "Bem-estar" },
  sinal_vital: { emoji: "❤️", cor: "#B3402A", rot: "Sinais vitais" },
  intercorrencia: { emoji: "🤕", cor: "#B3402A", rot: "Intercorrência" },
  refeicao: { emoji: "🍎", cor: "#2E7D46", rot: "Refeição" },
  avaliacao: { emoji: "📋", cor: "#8A6D1A", rot: "Escala" },
  medicacao: { emoji: "💊", cor: "#27418F", rot: "Medicação" },
  meta: { emoji: "🎯", cor: "#6B5B95", rot: "Meta" },
};

// ---------- Escalas clínicas (perguntas) ----------
// GDS-15: resposta entre parênteses é a que pontua 1 (indício de depressão)
const GDS15_PERGUNTAS = [
  { q: "Está satisfeita com sua vida?", pontua: "Não" },
  { q: "Abandonou muitos de seus interesses e atividades?", pontua: "Sim" },
  { q: "Acha que sua vida está vazia?", pontua: "Sim" },
  { q: "Sente-se aborrecida com frequência?", pontua: "Sim" },
  { q: "Está de bom humor na maior parte do tempo?", pontua: "Não" },
  { q: "Tem medo que algo ruim lhe aconteça?", pontua: "Sim" },
  { q: "Sente-se feliz na maior parte do tempo?", pontua: "Não" },
  { q: "Sente-se desamparada com frequência?", pontua: "Sim" },
  { q: "Prefere ficar em casa a sair e fazer coisas novas?", pontua: "Sim" },
  { q: "Acha que tem mais problemas de memória que outras pessoas?", pontua: "Sim" },
  { q: "Acha que é maravilhoso estar viva agora?", pontua: "Não" },
  { q: "Sente-se inútil do jeito que está?", pontua: "Sim" },
  { q: "Sente-se cheia de energia?", pontua: "Não" },
  { q: "Acha que sua situação não tem esperança?", pontua: "Sim" },
  { q: "Acha que a maioria das pessoas está melhor que a senhora?", pontua: "Sim" },
];
const KATZ_PERGUNTAS = [
  { q: "Toma banho sozinha?", dominio: "Banho" },
  { q: "Veste-se sozinha?", dominio: "Vestir-se" },
  { q: "Usa o banheiro sozinha?", dominio: "Higiene" },
  { q: "Levanta e senta sozinha (transferência)?", dominio: "Transferência" },
  { q: "Controla urina e fezes?", dominio: "Continência" },
  { q: "Alimenta-se sozinha?", dominio: "Alimentação" },
];

// ---------- Escala guiada (pergunta a pergunta) ----------
function EscalaGuiada({ id_idoso, instrumento, token, demo, aoConcluir }) {
  const perguntas = instrumento === "GDS15" ? GDS15_PERGUNTAS : KATZ_PERGUNTAS;
  const [i, setI] = useState(0);
  const [respostas, setRespostas] = useState([]);
  const [resultado, setResultado] = useState(null);
  const [msg, setMsg] = useState("");

  function responder(valor) {
    let pontuacao, resposta, dominio;
    if (instrumento === "GDS15") {
      resposta = valor; dominio = perguntas[i].q.slice(0, 60);
      pontuacao = valor === perguntas[i].pontua ? 1 : 0;
    } else {
      resposta = valor ? "Independente" : "Dependente"; dominio = perguntas[i].dominio;
      pontuacao = valor ? 1 : 0;
    }
    const novas = [...respostas, { dominio, resposta, pontuacao }];
    setRespostas(novas);
    if (i + 1 < perguntas.length) setI(i + 1);
    else enviar(novas);
  }

  async function enviar(itens) {
    const total = itens.reduce((s, it) => s + it.pontuacao, 0);
    if (demo) {
      const interp = instrumento === "GDS15"
        ? (total <= 4 ? "Normal" : total <= 9 ? "Sugestivo de depressão leve" : "Sugestivo de depressão grave")
        : (total >= 5 ? "Independente" : total >= 3 ? "Dependência parcial" : "Dependência importante");
      setResultado({ pontuacao_total: total, interpretacao: interp });
      return;
    }
    try {
      const r = await api("/escalas", { metodo: "POST", token, corpo: { id_idoso, instrumento, itens } });
      setResultado(r);
      if (aoConcluir) aoConcluir();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }

  if (resultado) {
    const bom = /Normal|Independente/.test(resultado.interpretacao);
    return (
      <div style={{ textAlign: "center", padding: 10 }}>
        <div style={{ fontSize: 44 }}>{bom ? "🟢" : "🟡"}</div>
        <h3 style={{ fontSize: 22, margin: "6px 0" }}>{instrumento === "GDS15" ? "Escala de Depressão (GDS-15)" : "Índice de Katz"}</h3>
        <p style={{ fontSize: 20, fontWeight: 700, color: bom ? CORES.verde : "#8A6D1A" }}>
          {resultado.pontuacao_total} pontos · {resultado.interpretacao}
        </p>
        <p style={{ fontSize: 15, color: CORES.nota, margin: "8px 0 0" }}>
          Resultado registrado no histórico. Não substitui avaliação clínica.
        </p>
      </div>
    );
  }

  const p = perguntas[i];
  return (
    <div>
      <div role="progressbar" aria-valuemin={0} aria-valuemax={perguntas.length} aria-valuenow={i}
        style={{ background: "#EDE5D2", borderRadius: 10, height: 12, overflow: "hidden", marginBottom: 12 }}>
        <div style={{ width: `${(i / perguntas.length) * 100}%`, height: "100%", background: CORES.anil }} />
      </div>
      <p style={{ fontSize: 15, color: CORES.nota, margin: "0 0 4px" }}>Pergunta {i + 1} de {perguntas.length}</p>
      <p style={{ fontSize: 22, fontWeight: 700, margin: "0 0 18px", minHeight: 66 }}>{p.q}</p>
      {msg && <Aviso msg={msg} />}
      {instrumento === "GDS15" ? (
        <div style={{ display: "flex", gap: 12 }}>
          <BotaoGrande onClick={() => responder("Sim")}>Sim</BotaoGrande>
          <BotaoGrande onClick={() => responder("Não")} cor={CORES.cinza}>Não</BotaoGrande>
        </div>
      ) : (
        <div style={{ display: "flex", gap: 12 }}>
          <BotaoGrande onClick={() => responder(true)}>Sozinha</BotaoGrande>
          <BotaoGrande onClick={() => responder(false)} cor={CORES.cinza}>Com ajuda</BotaoGrande>
        </div>
      )}
    </div>
  );
}

// ---------- Plano de cuidado individual ----------
function PlanoCuidado({ id_idoso, token, demo, podeEditar }) {
  const [metas, setMetas] = useState(null);
  const [nova, setNova] = useState(false);
  const [f, setF] = useState({ categoria: "saude", descricao: "", data_revisao: "" });
  const [msg, setMsg] = useState("");

  const DEMO_METAS = [
    { id_meta: 1, categoria: "nutricao", descricao: "Estimular hidratação: oferecer água a cada 2 horas", status: "ativa", autor: "Patrícia Andrade", evolucoes: 1, data_revisao: new Date(Date.now()+30*864e5).toISOString() },
    { id_meta: 2, categoria: "emocional", descricao: "Participar de ao menos 2 atividades sociais por semana", status: "ativa", autor: "Rodrigo Cavalcanti", evolucoes: 0, data_revisao: new Date(Date.now()+15*864e5).toISOString() },
    { id_meta: 3, categoria: "mobilidade", descricao: "Caminhar 10 minutos no jardim pela manhã", status: "atingida", autor: "Patrícia Andrade", evolucoes: 2, data_revisao: null },
  ];

  async function carregar() {
    if (demo) return setMetas(DEMO_METAS);
    try { setMetas(await api(`/idosos/${id_idoso}/metas`, { token })); } catch { setMetas([]); }
  }
  useEffect(() => { carregar(); }, []); // eslint-disable-line

  async function criar() {
    if (!f.descricao.trim()) return setMsg("Descreva a meta.");
    if (demo) { setMsg("✓ (demonstração) Meta criada."); setNova(false); return; }
    try {
      await api("/metas", { metodo: "POST", token, corpo: { id_idoso, categoria: f.categoria, descricao: f.descricao, data_revisao: f.data_revisao || undefined } });
      setMsg("✓ Meta adicionada ao plano."); setNova(false);
      setF({ categoria: "saude", descricao: "", data_revisao: "" }); carregar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }
  async function mudarStatus(id, status) {
    if (demo) return carregar();
    try { await api(`/metas/${id}/status`, { metodo: "POST", token, corpo: { status } }); carregar(); } catch {}
  }

  if (!metas) return <p style={{ fontSize: 15, color: CORES.nota }}>Carregando o plano…</p>;
  return (
    <div style={{ marginTop: 10 }}>
      {podeEditar && (
        <button onClick={() => { setNova(!nova); setMsg(""); }} style={{
          fontSize: 15, fontWeight: 700, padding: "8px 12px", borderRadius: 10, minHeight: 44, marginBottom: 10,
          border: "none", background: CORES.anil, color: "#fff", cursor: "pointer",
          fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>{nova ? "Fechar" : "+ Nova meta"}</button>
      )}
      {msg && <Aviso msg={msg} />}
      {nova && (
        <div style={{ background: "#F3EEE0", borderRadius: 12, padding: 12, marginBottom: 12 }}>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 8 }}>
            {Object.entries(CAT_META).map(([v, o]) => (
              <button key={v} onClick={() => setF({ ...f, categoria: v })} aria-pressed={f.categoria === v} style={{
                fontSize: 14, fontWeight: 700, padding: "8px 10px", borderRadius: 10, cursor: "pointer",
                border: f.categoria === v ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
                background: f.categoria === v ? "#E7ECF8" : "#FFFDF4", fontFamily: "'Atkinson Hyperlegible', sans-serif",
              }}>{o.emoji} {o.r}</button>
            ))}
          </div>
          <textarea value={f.descricao} onChange={(e) => setF({ ...f, descricao: e.target.value })} rows={2}
            placeholder="Ex.: Estimular hidratação ao longo do dia" style={{ ...campoG, marginBottom: 8 }} />
          <label style={{ fontSize: 14, fontWeight: 700, display: "block", marginBottom: 4 }}>Revisar em (opcional)</label>
          <input type="date" value={f.data_revisao} onChange={(e) => setF({ ...f, data_revisao: e.target.value })} style={{ ...campoG, marginBottom: 8 }} />
          <BotaoGrande onClick={criar}>Adicionar meta</BotaoGrande>
        </div>
      )}
      {metas.length === 0 && <p style={{ fontSize: 15, color: CORES.nota }}>Nenhuma meta no plano ainda.</p>}
      {metas.map((m) => {
        const cat = CAT_META[m.categoria] || { r: m.categoria, emoji: "•" };
        const st = STATUS_META[m.status] || STATUS_META.ativa;
        return (
          <div key={m.id_meta} style={{ background: st.fundo, border: `2px solid ${st.cor}`, borderRadius: 12, padding: "10px 12px", marginBottom: 8 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 8 }}>
              <b style={{ fontSize: 15, color: st.cor }}>{cat.emoji} {cat.r}</b>
              <span style={{ fontSize: 13, fontWeight: 700, color: st.cor }}>{st.r}</span>
            </div>
            <p style={{ fontSize: 16, margin: "4px 0 6px" }}>{m.descricao}</p>
            <div style={{ fontSize: 13, color: CORES.nota }}>
              {m.autor ? `por ${m.autor.split(" ")[0]}` : ""}
              {m.data_revisao && m.status === "ativa" ? ` · revisar em ${dataCurta(m.data_revisao)}` : ""}
            </div>
            {podeEditar && m.status === "ativa" && (
              <div style={{ display: "flex", gap: 6, marginTop: 8 }}>
                <button onClick={() => mudarStatus(m.id_meta, "atingida")} style={{
                  fontSize: 14, fontWeight: 700, padding: "6px 10px", borderRadius: 8, cursor: "pointer",
                  border: `2px solid ${CORES.verde}`, background: "#FFFDF4", color: CORES.verde,
                  fontFamily: "'Atkinson Hyperlegible', sans-serif",
                }}>✓ Atingida</button>
                <button onClick={() => mudarStatus(m.id_meta, "suspensa")} style={{
                  fontSize: 14, fontWeight: 700, padding: "6px 10px", borderRadius: 8, cursor: "pointer",
                  border: `2px solid ${CORES.cinza}`, background: "#FFFDF4", color: CORES.cinza,
                  fontFamily: "'Atkinson Hyperlegible', sans-serif",
                }}>Suspender</button>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ---------- Prontuário unificado (linha do tempo) ----------
function Prontuario({ id_idoso, token, demo }) {
  const [dados, setDados] = useState(null);
  const [filtro, setFiltro] = useState("todos");

  useEffect(() => {
    if (demo) return setDados({
      idoso: { nome: "Severina Maria da Conceição", idade: 84, grau_dependencia: "II" },
      eventos: [
        { tipo: "refeicao", data_hora: new Date().toISOString(), titulo: "Refeição: almoço", detalhe: "Aceitação 80% · 200ml" },
        { tipo: "intercorrencia", data_hora: new Date(Date.now()-2*36e5).toISOString(), titulo: "Intercorrência: queda (leve)", detalhe: "Escorregou ao sair do banho, sem ferimentos." },
        { tipo: "sinal_vital", data_hora: new Date(Date.now()-5*36e5).toISOString(), titulo: "Sinais vitais", detalhe: "PA 132/85 · FC 74 · 66.8kg" },
        { tipo: "bem_estar", data_hora: new Date(Date.now()-8*36e5).toISOString(), titulo: "Check-in de bem-estar", detalhe: "Humor 4/5 · conforto 4/5" },
        { tipo: "avaliacao", data_hora: new Date(Date.now()-30*36e5).toISOString(), titulo: "Escala: GDS15", detalhe: "3 pontos — Normal" },
      ],
    });
    api(`/idosos/${id_idoso}/prontuario`, { token }).then(setDados).catch(() => setDados({ idoso: null, eventos: [] }));
  }, []); // eslint-disable-line

  if (!dados) return <Cartao>Montando o prontuário…</Cartao>;
  const tipos = ["todos", ...Object.keys(EVENTO_PRONT)];
  const eventos = filtro === "todos" ? dados.eventos : dados.eventos.filter((e) => e.tipo === filtro);

  // agrupar por dia
  const porDia = {};
  for (const e of eventos) {
    const dia = new Date(e.data_hora).toLocaleDateString("pt-BR", { day: "2-digit", month: "long", year: "numeric" });
    (porDia[dia] = porDia[dia] || []).push(e);
  }

  return (
    <div>
      {dados.idoso && (
        <Cartao borda={CORES.anil}>
          <b style={{ fontSize: 20 }}>{dados.idoso.nome}</b>
          <div style={{ fontSize: 16, color: CORES.nota }}>{dados.idoso.idade} anos · grau de dependência {dados.idoso.grau_dependencia}</div>
        </Cartao>
      )}

      {/* filtros por tipo */}
      <div style={{ display: "flex", flexWrap: "wrap", gap: 6, margin: "12px 0" }}>
        {tipos.map((t) => {
          const info = EVENTO_PRONT[t];
          const ativo = filtro === t;
          return (
            <button key={t} onClick={() => setFiltro(t)} aria-pressed={ativo} style={{
              fontSize: 14, fontWeight: 700, padding: "6px 10px", borderRadius: 10, cursor: "pointer",
              border: ativo ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
              background: ativo ? "#E7ECF8" : "#FFFDF4", fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>{info ? `${info.emoji} ${info.rot}` : "Tudo"}</button>
          );
        })}
      </div>

      {eventos.length === 0 && <Cartao>Nenhum registro neste filtro.</Cartao>}

      {Object.entries(porDia).map(([dia, evs]) => (
        <div key={dia} style={{ marginBottom: 16 }}>
          <p style={{ fontSize: 15, fontWeight: 700, color: CORES.nota, margin: "0 0 8px", textTransform: "capitalize" }}>{dia}</p>
          <div style={{ borderLeft: `3px solid #E4DCC9`, paddingLeft: 14, marginLeft: 6 }}>
            {evs.map((e, i) => {
              const info = EVENTO_PRONT[e.tipo] || { emoji: "•", cor: CORES.nota };
              return (
                <div key={i} style={{ position: "relative", marginBottom: 12 }}>
                  <div style={{ position: "absolute", left: -22, top: 2, width: 14, height: 14, borderRadius: "50%", background: info.cor, border: "2px solid #FBF6EB" }} />
                  <div style={{ fontSize: 13, color: CORES.nota }}>
                    {new Date(e.data_hora).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })}
                  </div>
                  <b style={{ fontSize: 16, color: info.cor }}>{info.emoji} {e.titulo}</b>
                  {e.detalhe && <div style={{ fontSize: 15, color: CORES.tinta }}>{e.detalhe}</div>}
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}

// ---------- Intercorrências (equipe registra, família vê) ----------
const TIPO_INTERC = {
  queda: { r: "Queda", emoji: "🤕" }, lesao: { r: "Lesão", emoji: "🩹" },
  mal_estar: { r: "Mal-estar", emoji: "😣" }, comportamento: { r: "Comportamento", emoji: "😔" },
  fuga: { r: "Evasão", emoji: "🚪" }, obito: { r: "Óbito", emoji: "🕊️" }, outro: { r: "Outro", emoji: "📋" },
};
const GRAV_INTERC = {
  leve: { r: "Leve", cor: "#2E7D46", fundo: "#E8F4EC" },
  moderada: { r: "Moderada", cor: "#8A6D1A", fundo: "#FFF3D6" },
  grave: { r: "Grave", cor: "#B3402A", fundo: "#FBEAE5" },
};

function Intercorrencias({ id_idoso, token, demo, podeEditar }) {
  const [lista, setLista] = useState(null);
  const [nova, setNova] = useState(false);
  const [f, setF] = useState({ tipo: "queda", gravidade: "leve", local_evento: "", descricao: "", conduta: "", familia_avisada: false });
  const [msg, setMsg] = useState("");
  const DEMO_IC = [{ id_intercorrencia: 1, tipo: "queda", gravidade: "leve", local_evento: "Banheiro", descricao: "Escorregou ao sair do banho, sem ferimentos.", conduta: "Avaliada, sem lesões. Tapete antiderrapante colocado.", familia_avisada: true, data_hora: new Date().toISOString(), autor: "Patrícia Andrade" }];

  async function carregar() {
    if (demo) return setLista(DEMO_IC);
    try { setLista(await api(`/idosos/${id_idoso}/intercorrencias`, { token })); } catch { setLista([]); }
  }
  useEffect(() => { carregar(); }, []); // eslint-disable-line

  async function salvar() {
    if (!f.descricao.trim()) return setMsg("Descreva o que aconteceu.");
    if (demo) { setMsg("✓ (demonstração) Intercorrência registrada."); setNova(false); return; }
    try {
      await api("/intercorrencias", { metodo: "POST", token, corpo: { id_idoso, ...f } });
      setMsg("✓ Intercorrência registrada."); setNova(false);
      setF({ tipo: "queda", gravidade: "leve", local_evento: "", descricao: "", conduta: "", familia_avisada: false });
      carregar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }

  if (!lista) return <p style={{ fontSize: 15, color: CORES.nota }}>Carregando…</p>;
  return (
    <div style={{ marginTop: 10 }}>
      {podeEditar && (
        <button onClick={() => { setNova(!nova); setMsg(""); }} style={{
          fontSize: 15, fontWeight: 700, padding: "8px 12px", borderRadius: 10, minHeight: 44, marginBottom: 10,
          border: "none", background: CORES.alerta, color: "#fff", cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>{nova ? "Fechar" : "+ Registrar ocorrência"}</button>
      )}
      {msg && <Aviso msg={msg} />}
      {nova && (
        <div style={{ background: "#F3EEE0", borderRadius: 12, padding: 12, marginBottom: 12 }}>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 8 }}>
            {Object.entries(TIPO_INTERC).map(([v, o]) => (
              <button key={v} onClick={() => setF({ ...f, tipo: v })} aria-pressed={f.tipo === v} style={{
                fontSize: 14, fontWeight: 700, padding: "8px 10px", borderRadius: 10, cursor: "pointer",
                border: f.tipo === v ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
                background: f.tipo === v ? "#E7ECF8" : "#FFFDF4", fontFamily: "'Atkinson Hyperlegible', sans-serif",
              }}>{o.emoji} {o.r}</button>
            ))}
          </div>
          <div style={{ display: "flex", gap: 6, marginBottom: 8 }}>
            {Object.entries(GRAV_INTERC).map(([v, o]) => (
              <button key={v} onClick={() => setF({ ...f, gravidade: v })} aria-pressed={f.gravidade === v} style={{
                flex: 1, fontSize: 14, fontWeight: 700, padding: "8px 10px", borderRadius: 10, cursor: "pointer",
                border: f.gravidade === v ? `3px solid ${o.cor}` : "2px solid #D8CFBC",
                background: f.gravidade === v ? o.fundo : "#FFFDF4", color: o.cor, fontFamily: "'Atkinson Hyperlegible', sans-serif",
              }}>{o.r}</button>
            ))}
          </div>
          <input style={campoG} placeholder="Local (ex.: Quarto, Refeitório)" value={f.local_evento} onChange={(e) => setF({ ...f, local_evento: e.target.value })} />
          <textarea style={{ ...campoG }} rows={2} placeholder="O que aconteceu?" value={f.descricao} onChange={(e) => setF({ ...f, descricao: e.target.value })} />
          <textarea style={{ ...campoG }} rows={2} placeholder="Conduta tomada" value={f.conduta} onChange={(e) => setF({ ...f, conduta: e.target.value })} />
          <label style={{ display: "flex", alignItems: "center", gap: 10, fontSize: 16, fontWeight: 700, marginBottom: 10, cursor: "pointer" }}>
            <input type="checkbox" checked={f.familia_avisada} onChange={(e) => setF({ ...f, familia_avisada: e.target.checked })} style={{ width: 22, height: 22 }} />
            Família avisada
          </label>
          <BotaoGrande onClick={salvar}>Registrar</BotaoGrande>
        </div>
      )}
      {lista.length === 0 && <p style={{ fontSize: 15, color: CORES.nota }}>Nenhuma intercorrência registrada. 🌿</p>}
      {lista.map((ic) => {
        const t = TIPO_INTERC[ic.tipo] || TIPO_INTERC.outro, g = GRAV_INTERC[ic.gravidade] || GRAV_INTERC.leve;
        return (
          <div key={ic.id_intercorrencia} style={{ background: g.fundo, border: `2px solid ${g.cor}`, borderRadius: 12, padding: "10px 12px", marginBottom: 8 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 8 }}>
              <b style={{ fontSize: 16, color: g.cor }}>{t.emoji} {t.r} · {g.r}</b>
              <span style={{ fontSize: 13, color: CORES.nota, whiteSpace: "nowrap" }}>{dataCurta(ic.data_hora)}</span>
            </div>
            <p style={{ fontSize: 16, margin: "4px 0" }}>{ic.descricao}</p>
            {ic.conduta && <p style={{ fontSize: 15, color: CORES.nota, margin: "2px 0" }}><b>Conduta:</b> {ic.conduta}</p>}
            <div style={{ fontSize: 13, color: CORES.nota, marginTop: 4 }}>
              {ic.local_evento ? `${ic.local_evento} · ` : ""}{ic.autor ? `por ${ic.autor.split(" ")[0]}` : ""}
              {ic.familia_avisada ? " · ✓ família avisada" : " · família não avisada"}
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ---------- Nutrição (refeições e restrições) ----------
const REFEICAO_TIPO = { cafe: "☕ Café", almoco: "🍽️ Almoço", lanche: "🍎 Lanche", jantar: "🌙 Jantar", ceia: "🥛 Ceia" };

function Nutricao({ id_idoso, token, demo, podeEditar }) {
  const [dados, setDados] = useState(null);
  const [restr, setRestr] = useState(null);
  const [f, setF] = useState({ tipo: "almoco", aceitacao: 100, hidratacao_ml: "" });
  const [novaR, setNovaR] = useState("");
  const [editR, setEditR] = useState(null); // { id, texto }
  const [msg, setMsg] = useState("");

  async function carregar() {
    if (demo) { if (restr) return; setDados({ registros: [{ id_refeicao:1, tipo:"almoco", aceitacao:80, hidratacao_ml:200, data_hora:new Date().toISOString() }], resumo: { media_aceitacao_7d: 80, hidratacao_hoje: 350 } }); setRestr([{ id_restricao:1, descricao:"Diabética" }, { id_restricao:2, descricao:"Sem sal" }]); return; }
    try { setDados(await api(`/idosos/${id_idoso}/refeicoes`, { token })); setRestr(await api(`/idosos/${id_idoso}/restricoes`, { token })); } catch { setDados({ registros: [], resumo: {} }); setRestr([]); }
  }
  useEffect(() => { carregar(); }, []); // eslint-disable-line

  async function registrar() {
    if (demo) return setMsg("✓ (demonstração) Refeição registrada.");
    try {
      await api("/refeicoes", { metodo: "POST", token, corpo: { id_idoso, tipo: f.tipo, aceitacao: Number(f.aceitacao), hidratacao_ml: f.hidratacao_ml ? Number(f.hidratacao_ml) : undefined } });
      setMsg("✓ Refeição registrada."); setF({ tipo: "almoco", aceitacao: 100, hidratacao_ml: "" }); carregar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }
  async function addRestricao() {
    if (!novaR.trim()) return;
    if (demo) { setRestr([...(restr || []), { id_restricao: Date.now(), descricao: novaR.trim() }]); setNovaR(""); return setMsg("✓ (demonstração) Restrição adicionada."); }
    try { await api("/restricoes", { metodo: "POST", token, corpo: { id_idoso, descricao: novaR } }); setNovaR(""); carregar(); } catch (e) { setMsg(e.message); }
  }
  async function removerRestricao(id) {
    if (demo) { setRestr(restr.filter((r) => r.id_restricao !== id)); return setMsg("✓ (demonstração) Restrição removida."); }
    try { await api(`/restricoes/${id}`, { metodo: "DELETE", token }); setMsg("✓ Restrição removida."); carregar(); } catch (e) { setMsg(e.message); }
  }
  async function salvarRestricao() {
    if (!editR.texto.trim()) return setMsg("A restrição não pode ficar vazia.");
    if (demo) { setRestr(restr.map((r) => r.id_restricao === editR.id ? { ...r, descricao: editR.texto } : r)); setEditR(null); return setMsg("✓ (demonstração) Restrição atualizada."); }
    try { await api(`/restricoes/${editR.id}`, { metodo: "PATCH", token, corpo: { descricao: editR.texto } }); setEditR(null); setMsg("✓ Restrição atualizada."); carregar(); }
    catch (e) { setMsg(e.message); }
  }

  if (!dados) return <p style={{ fontSize: 15, color: CORES.nota }}>Carregando…</p>;
  return (
    <div style={{ marginTop: 10 }}>
      {/* restrições */}
      <div style={{ marginBottom: 12 }}>
        <b style={{ fontSize: 16 }}>🥗 Restrições alimentares</b>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginTop: 6 }}>
          {(restr || []).map((r) => editR && editR.id === r.id_restricao ? (
            <span key={r.id_restricao} style={{ display: "inline-flex", gap: 6, alignItems: "center" }}>
              <input aria-label="Editar restrição" value={editR.texto} maxLength={120} autoFocus
                onChange={(e) => setEditR({ ...editR, texto: e.target.value })}
                onKeyDown={(e) => { if (e.key === "Enter") salvarRestricao(); if (e.key === "Escape") setEditR(null); }}
                style={{ ...campoG, marginBottom: 0, width: 190, padding: "6px 10px", fontSize: 15 }} />
              <button onClick={salvarRestricao} aria-label="Salvar restrição" style={{ border: `2px solid ${CORES.verde}`, background: CORES.cartao, color: CORES.verde, borderRadius: 10, fontWeight: 700, fontSize: 15, padding: "6px 10px", cursor: "pointer" }}>✓</button>
              <button onClick={() => setEditR(null)} aria-label="Cancelar edição" style={{ border: "2px solid #D8CFBC", background: CORES.cartao, borderRadius: 10, fontSize: 15, padding: "6px 10px", cursor: "pointer" }}>↩</button>
            </span>
          ) : (
            <span key={r.id_restricao} style={{ fontSize: 15, fontWeight: 700, background: "#FFF3D6", border: "2px solid #E5C463", borderRadius: 10, padding: "4px 10px", display: "inline-flex", alignItems: "center", gap: 6 }}>
              {r.descricao}
              {podeEditar && <button onClick={() => { setMsg(""); setEditR({ id: r.id_restricao, texto: r.descricao }); }} aria-label={`Editar ${r.descricao}`} style={{ border: "none", background: "none", cursor: "pointer", fontSize: 14, padding: 0 }}>✏️</button>}
              {podeEditar && <button onClick={() => removerRestricao(r.id_restricao)} aria-label={`Remover ${r.descricao}`} style={{ border: "none", background: "none", cursor: "pointer", fontSize: 16, color: CORES.alerta, padding: 0 }}>×</button>}
            </span>
          ))}
          {(restr || []).length === 0 && <span style={{ fontSize: 15, color: CORES.nota }}>Nenhuma.</span>}
        </div>
        {podeEditar && (
          <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
            <input style={{ ...campoG, marginBottom: 0 }} placeholder="Nova restrição (ex.: Pastoso)" value={novaR} onChange={(e) => setNovaR(e.target.value)} />
            <button onClick={addRestricao} aria-label="Adicionar restrição" style={{ fontSize: 15, fontWeight: 700, padding: "0 16px", borderRadius: 10, border: `2px solid ${CORES.anil}`, background: "#E7ECF8", color: CORES.anil, cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif" }}>+</button>
          </div>
        )}
        {msg && /restri/i.test(msg) && <div style={{ marginTop: 8 }}><Aviso msg={msg} /></div>}
      </div>

      {/* resumo */}
      <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
        <div style={{ flex: 1, textAlign: "center", background: "#F3EEE0", borderRadius: 12, padding: "10px 6px" }}>
          <div style={{ fontSize: 26, fontWeight: 700, color: (dados.resumo.media_aceitacao_7d ?? 100) < 60 ? CORES.alerta : CORES.verde }}>{dados.resumo.media_aceitacao_7d ?? "—"}%</div>
          <div style={{ fontSize: 13, color: CORES.nota }}>aceitação (7 dias)</div>
        </div>
        <div style={{ flex: 1, textAlign: "center", background: "#F3EEE0", borderRadius: 12, padding: "10px 6px" }}>
          <div style={{ fontSize: 26, fontWeight: 700, color: CORES.anil }}>{dados.resumo.hidratacao_hoje ?? 0}<span style={{ fontSize: 15 }}>ml</span></div>
          <div style={{ fontSize: 13, color: CORES.nota }}>hidratação hoje</div>
        </div>
      </div>

      {podeEditar && (
        <div style={{ background: "#F3EEE0", borderRadius: 12, padding: 12, marginBottom: 12 }}>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 8 }}>
            {Object.entries(REFEICAO_TIPO).map(([v, r]) => (
              <button key={v} onClick={() => setF({ ...f, tipo: v })} aria-pressed={f.tipo === v} style={{
                fontSize: 14, fontWeight: 700, padding: "8px 10px", borderRadius: 10, cursor: "pointer",
                border: f.tipo === v ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
                background: f.tipo === v ? "#E7ECF8" : "#FFFDF4", fontFamily: "'Atkinson Hyperlegible', sans-serif",
              }}>{r}</button>
            ))}
          </div>
          <label style={{ fontSize: 15, fontWeight: 700, display: "block", marginBottom: 4 }}>Quanto aceitou: {f.aceitacao}%</label>
          <input type="range" min="0" max="100" step="10" value={f.aceitacao} onChange={(e) => setF({ ...f, aceitacao: e.target.value })} style={{ width: "100%", marginBottom: 10 }} />
          <input style={campoG} inputMode="numeric" placeholder="Hidratação (ml) — opcional" value={f.hidratacao_ml} onChange={(e) => setF({ ...f, hidratacao_ml: e.target.value })} />
          {msg && !/restri/i.test(msg) && <Aviso msg={msg} />}
          <BotaoGrande onClick={registrar}>Registrar refeição</BotaoGrande>
        </div>
      )}

      {dados.registros.slice(0, 6).map((r) => (
        <div key={r.id_refeicao} style={{ display: "flex", justifyContent: "space-between", gap: 8, padding: "8px 0", borderBottom: "1px solid #E4DCC9" }}>
          <span style={{ fontSize: 15 }}>{REFEICAO_TIPO[r.tipo] || r.tipo}</span>
          <span style={{ fontSize: 15, fontWeight: 700, color: r.aceitacao < 60 ? CORES.alerta : CORES.verde }}>{r.aceitacao}%{r.hidratacao_ml ? ` · ${r.hidratacao_ml}ml` : ""}</span>
        </div>
      ))}
    </div>
  );
}

// ---------- Mini-gráfico de linha para sinais vitais ----------
function LinhaVital({ pontos, faixa, unidade, titulo, cor = "#27418F" }) {
  const vals = pontos.filter((p) => p.v != null);
  if (vals.length === 0) return null;
  const W = 300, H = 90, pad = 6;
  const ys = vals.map((p) => p.v);
  let min = Math.min(...ys, faixa ? faixa[0] : Infinity);
  let max = Math.max(...ys, faixa ? faixa[1] : -Infinity);
  if (min === max) { min -= 1; max += 1; }
  const rango = max - min || 1;
  const x = (i) => pad + (i * (W - 2 * pad)) / Math.max(1, vals.length - 1);
  const y = (v) => H - pad - ((v - min) / rango) * (H - 2 * pad);
  const linha = vals.map((p, i) => `${x(i)},${y(p.v)}`).join(" ");
  const foraFaixa = (v) => faixa && (v < faixa[0] || v > faixa[1]);
  return (
    <div style={{ marginBottom: 12 }}>
      <div style={{ display: "flex", justifyContent: "space-between", fontSize: 15 }}>
        <b>{titulo}</b>
        <span style={{ color: foraFaixa(vals.at(-1).v) ? CORES.alerta : CORES.verde, fontWeight: 700 }}>
          {vals.at(-1).v}{unidade} {foraFaixa(vals.at(-1).v) ? "⚠" : "✓"}
        </span>
      </div>
      <svg width="100%" viewBox={`0 0 ${W} ${H}`} style={{ display: "block" }} role="img"
        aria-label={`${titulo}: último valor ${vals.at(-1).v}${unidade}`}>
        {faixa && (
          <rect x={pad} y={y(faixa[1])} width={W - 2 * pad} height={Math.max(0, y(faixa[0]) - y(faixa[1]))}
            fill="#2E7D46" opacity="0.08" />
        )}
        <polyline points={linha} fill="none" stroke={cor} strokeWidth="2.5" strokeLinejoin="round" />
        {vals.map((p, i) => (
          <circle key={i} cx={x(i)} cy={y(p.v)} r="3.5" fill={foraFaixa(p.v) ? CORES.alerta : cor} />
        ))}
      </svg>
    </div>
  );
}

function SinaisVitais({ id_idoso, token, demo }) {
  const [dados, setDados] = useState(null);
  useEffect(() => {
    if (demo) return setDados({
      faixas: { pressao_sis: [90,140], pressao_dia: [60,90], freq_cardiaca: [50,100], temperatura: [35.5,37.5], glicemia: [70,140], saturacao: [94,100] },
      registros: [
        { data_hora: new Date(Date.now()-25*864e5).toISOString(), pressao_sis:145, pressao_dia:92, freq_cardiaca:78, peso_kg:68.0, glicemia:110 },
        { data_hora: new Date(Date.now()-18*864e5).toISOString(), pressao_sis:150, pressao_dia:95, freq_cardiaca:82, peso_kg:67.5, glicemia:128 },
        { data_hora: new Date(Date.now()-11*864e5).toISOString(), pressao_sis:138, pressao_dia:88, freq_cardiaca:76, peso_kg:67.0, glicemia:105 },
        { data_hora: new Date(Date.now()-4*864e5).toISOString(), pressao_sis:132, pressao_dia:85, freq_cardiaca:74, peso_kg:66.8, glicemia:98, classificacao_pa: "Pré-hipertensão" },
      ],
    });
    else api(`/idosos/${id_idoso}/sinais`, { token }).then(setDados).catch(() => setDados({ registros: [], faixas: {} }));
  }, []); // eslint-disable-line
  if (!dados) return <p style={{ fontSize: 15, color: CORES.nota }}>Carregando sinais…</p>;
  if (!dados.registros.length) return <p style={{ fontSize: 15, color: CORES.nota }}>Nenhum sinal vital registrado ainda.</p>;
  const R = dados.registros, F = dados.faixas;
  const serie = (k) => R.map((r) => ({ v: r[k] != null ? Number(r[k]) : null }));
  // Última pressão aferida e a classificação calculada no banco pela
  // função fn_classificar_pressao (Etapa 05)
  const ultPa = [...R].reverse().find((r) => r.pressao_sis != null && r.pressao_dia != null);
  const classePa = ultPa && (ultPa.classificacao_pa || null);
  const paAlerta = classePa && /estágio|Hipotensão/.test(classePa);
  return (
    <div style={{ marginTop: 10 }}>
      {ultPa && (
        <div style={{
          display: "flex", justifyContent: "space-between", alignItems: "center", gap: 8, flexWrap: "wrap",
          background: paAlerta ? CORES.alertaFundo : CORES.verdeFundo, borderRadius: 10, padding: "8px 12px", marginBottom: 10,
        }}>
          <span style={{ fontSize: 16 }}>Última pressão: <b>{ultPa.pressao_sis}/{ultPa.pressao_dia}</b></span>
          {classePa && <b style={{ fontSize: 16, color: paAlerta ? CORES.alerta : CORES.verde }}>{classePa}</b>}
        </div>
      )}
      <LinhaVital titulo="Pressão sistólica" unidade="" pontos={serie("pressao_sis")} faixa={F.pressao_sis} cor="#B3402A" />
      <LinhaVital titulo="Freq. cardíaca" unidade=" bpm" pontos={serie("freq_cardiaca")} faixa={F.freq_cardiaca} cor="#27418F" />
      <LinhaVital titulo="Peso" unidade=" kg" pontos={serie("peso_kg")} cor="#2E7D46" />
      <LinhaVital titulo="Glicemia" unidade=" mg/dL" pontos={serie("glicemia")} faixa={F.glicemia} cor="#8A6D1A" />
      <p style={{ fontSize: 13, color: CORES.nota, margin: "4px 0 0" }}>
        A faixa verde é o intervalo de referência. Pontos vermelhos estão fora dela — sinal para a equipe conferir.
        A classificação da pressão segue a Diretriz Brasileira de Hipertensão. Valores muito fora da faixa geram um alerta automático na passagem de plantão.
      </p>
    </div>
  );
}

// ============================================================
// ÁREA DO RESPONSÁVEL — painel dos seus idosos
// ============================================================
function CartaoIdoso({ i, historicos, carregar, filhos, token, demo, podeRecado, podeRelatorio }) {
  const [aberto, setAberto] = useState(false);
  const [verSinais, setVerSinais] = useState(false);
  const [verPlano, setVerPlano] = useState(false);
  const [verInterc, setVerInterc] = useState(false);
  const [verNutri, setVerNutri] = useState(false);
  const [verPront, setVerPront] = useState(false);
  const [recado, setRecado] = useState("");
  const [msgRec, setMsgRec] = useState("");
  const [versaoMural, setVersaoMural] = useState(0);
  const [priv, setPriv] = useState(null);
  const [msgPriv, setMsgPriv] = useState("");
  useEffect(() => {
    if (!podeRecado) return;
    if (demo) return setPriv({ ativo: true, desde: new Date().toISOString() });
    api(`/idosos/${i.id_idoso}/consentimentos`, { token })
      .then((l) => {
        // o que libera o prontuário para a família é o consentimento de dados de saúde
        const a = l.find((x) => !x.data_revogacao && (x.categoria || "dados_saude") === "dados_saude");
        setPriv(a ? { ativo: true, id: a.id_consentimento, desde: a.data_concessao } : { ativo: false });
      })
      .catch(() => setPriv({ ativo: false }));
  }, []); // eslint-disable-line

  async function conceder() {
    if (demo) return setMsgPriv("✓ (demonstração) Consentimento registrado.");
    try {
      const r = await api("/consentimentos", {
        metodo: "POST", token,
        corpo: { id_idoso: i.id_idoso, categoria: "dados_saude", finalidade: "Registro e compartilhamento de dados de saúde e bem-estar com responsável legal e equipe da ILPI" },
      });
      setPriv({ ativo: true, id: r.id_consentimento, desde: r.data_concessao });
      setMsgPriv("✓ Consentimento registrado com data e hora. Os dados de saúde voltam a aparecer na próxima vez que você entrar.");
    } catch (e) { setMsgPriv(`Não deu (${e.message}).`); }
  }
  async function revogar() {
    if (demo) return setMsgPriv("✓ (demonstração) Consentimento revogado.");
    try {
      await api(`/consentimentos/${priv.id}/revogar`, { metodo: "POST", token });
      setPriv({ ativo: false });
      setMsgPriv("✓ Revogado. A partir de agora a família não vê os dados de saúde (o Xodó e o mural continuam). O registro histórico fica guardado, como manda a LGPD.");
    } catch (e) { setMsgPriv(`Não deu (${e.message}).`); }
  }
  async function baixarPdf() {
    if (demo) return setMsgPriv("O PDF precisa da API conectada — na demonstração ele fica de fora.");
    try {
      const resp = await fetch(`${API_URL}/idosos/${i.id_idoso}/relatorio`, { headers: { Authorization: `Bearer ${token}` } });
      if (!resp.ok) throw new Error("HTTP " + resp.status);
      const url = URL.createObjectURL(await resp.blob());
      const a = document.createElement("a");
      a.href = url; a.download = `relatorio_${i.nome.split(" ")[0].toLowerCase()}.pdf`; a.click();
      URL.revokeObjectURL(url);
    } catch (e) { setMsgPriv(`Não consegui gerar o PDF (${e.message}).`); }
  }

  async function mandarRecado() {
    if (!recado.trim()) return setMsgRec("Escreva o recado antes de enviar.");
    if (demo) { setMsgRec("✓ (demonstração) Recado no mural!"); setRecado(""); return; }
    try {
      await api("/recados", { metodo: "POST", token, corpo: { id_idoso: i.id_idoso, texto: recado } });
      setMsgRec(`✓ Recado no mural! ${i.nome.split(" ")[0]} vai poder ler e ouvir.`);
      setRecado("");
      setVersaoMural((v) => v + 1);
    } catch (e) { setMsgRec(`Não consegui enviar (${e.message}).`); }
  }
  const humorEmoji = i.ultimo_humor ? OP_HUMOR.find((o) => o.v === i.ultimo_humor)?.emoji : "—";
  return (
    <Cartao>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 8 }}>
        <h3 style={{ fontSize: 21, margin: 0 }}>{i.nome}</h3>
        <span style={{ fontSize: 15, color: CORES.nota, whiteSpace: "nowrap" }}>{i.idade} anos · grau {i.grau_dependencia}</span>
      </div>
      <p style={{ fontSize: 16, color: CORES.nota, margin: "2px 0 12px" }}>{i.ilpi}</p>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 10 }}>
        <span style={{ background: CORES.papel, border: "2px solid #E4DCC9", borderRadius: 10, padding: "6px 10px", fontSize: 17 }}>
          {humorEmoji} humor {i.ultimo_humor ?? "—"} <small style={{ color: CORES.nota }}>({dataCurta(i.ultimo_checkin)})</small>
        </span>
        <span style={{ background: CORES.papel, border: "2px solid #E4DCC9", borderRadius: 10, padding: "6px 10px", fontSize: 17 }}>
          conforto {i.ultimo_conforto ?? "—"}
        </span>
        <span style={{
          background: CORES.papel, borderRadius: 10, padding: "6px 10px", fontSize: 17,
          border: `2px solid ${i.ultima_dor > 3 ? CORES.alerta : "#E4DCC9"}`,
          color: i.ultima_dor > 3 ? CORES.alerta : CORES.tinta, fontWeight: i.ultima_dor > 3 ? 700 : 400,
        }}>
          dor {i.ultima_dor ?? "—"}
        </span>
        {i.pet && (
          <span style={{ background: CORES.papel, border: "2px solid #E4DCC9", borderRadius: 10, padding: "6px 10px", fontSize: 17 }}>
            🐾 {i.pet} nv {i.nivel_pet}
          </span>
        )}
      </div>
      <p style={{ fontSize: 16, color: CORES.nota, margin: "0 0 12px" }}>
        Última avaliação: {i.ultima_avaliacao ? `${i.ultima_avaliacao} (${i.ultima_pontuacao ?? "s/ pontuação"})` : "—"} ·
        Atividades no mês: {i.atividades_30d}
      </p>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
        <button onClick={() => { setAberto(!aberto); carregar(i.id_idoso); }} style={{
          fontSize: 16, fontWeight: 700, padding: "10px 14px", borderRadius: 12,
          border: `2px solid ${CORES.anil}`, background: aberto ? "#E7ECF8" : CORES.cartao,
          color: CORES.anil, cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>{aberto ? "Esconder humor" : "📈 Humor"}</button>
        <button onClick={() => setVerSinais(!verSinais)} style={{
          fontSize: 16, fontWeight: 700, padding: "10px 14px", borderRadius: 12,
          border: `2px solid ${CORES.anil}`, background: verSinais ? "#E7ECF8" : CORES.cartao,
          color: CORES.anil, cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>{verSinais ? "Esconder sinais" : "❤️ Sinais vitais"}</button>
        <button onClick={() => setVerPlano(!verPlano)} style={{
          fontSize: 16, fontWeight: 700, padding: "10px 14px", borderRadius: 12,
          border: `2px solid ${CORES.anil}`, background: verPlano ? "#E7ECF8" : CORES.cartao,
          color: CORES.anil, cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>{verPlano ? "Esconder plano" : "🎯 Plano de cuidado"}</button>
        <button onClick={() => setVerInterc(!verInterc)} style={{
          fontSize: 16, fontWeight: 700, padding: "10px 14px", borderRadius: 12,
          border: `2px solid ${CORES.anil}`, background: verInterc ? "#E7ECF8" : CORES.cartao,
          color: CORES.anil, cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>{verInterc ? "Esconder ocorrências" : "🤕 Intercorrências"}</button>
        <button onClick={() => setVerNutri(!verNutri)} style={{
          fontSize: 16, fontWeight: 700, padding: "10px 14px", borderRadius: 12,
          border: `2px solid ${CORES.anil}`, background: verNutri ? "#E7ECF8" : CORES.cartao,
          color: CORES.anil, cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>{verNutri ? "Esconder nutrição" : "🍎 Nutrição"}</button>
        <button onClick={() => setVerPront(!verPront)} style={{
          fontSize: 16, fontWeight: 700, padding: "10px 14px", borderRadius: 12,
          border: `2px solid ${CORES.destaque}`, background: verPront ? "#FBF0D8" : CORES.cartao,
          color: "#8A6D1A", cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>{verPront ? "Esconder prontuário" : "📖 Prontuário completo"}</button>
      </div>
      {aberto && <GraficoHumor registros={historicos[i.id_idoso] || []} />}
      {verSinais && <SinaisVitais id_idoso={i.id_idoso} token={token} demo={demo} />}
      {verPlano && <PlanoCuidado id_idoso={i.id_idoso} token={token} demo={demo} podeEditar={podeRelatorio} />}
      {verInterc && <Intercorrencias id_idoso={i.id_idoso} token={token} demo={demo} podeEditar={podeRelatorio} />}
      {verNutri && <Nutricao id_idoso={i.id_idoso} token={token} demo={demo} podeEditar={podeRelatorio} />}
      {verPront && <Prontuario id_idoso={i.id_idoso} token={token} demo={demo} />}
      {podeRelatorio && (
        <button onClick={async () => {
          if (demo) return alert("O relatório em PDF funciona com a API conectada.");
          try {
            const resp = await fetch(`${API_URL}/idosos/${i.id_idoso}/relatorio`, { headers: { Authorization: `Bearer ${token}` } });
            if (!resp.ok) throw new Error("HTTP " + resp.status);
            const url = URL.createObjectURL(await resp.blob());
            const a = document.createElement("a");
            a.href = url; a.download = `relatorio_${i.nome.split(" ")[0].toLowerCase()}.pdf`; a.click();
            URL.revokeObjectURL(url);
          } catch (e) { alert("Não consegui gerar o PDF: " + e.message); }
        }} style={{
          marginTop: 10, fontSize: 16, fontWeight: 700, padding: "10px 14px", borderRadius: 12, minHeight: 48,
          border: `2px solid ${CORES.anil}`, background: "#E7ECF8", color: CORES.anil, cursor: "pointer",
          fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>📄 Relatório do mês (PDF)</button>
      )}
      {podeRecado && (
        <div style={{ marginTop: 14, borderTop: "2px solid #E4DCC9", paddingTop: 12 }}>
          <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: 8, marginBottom: 8 }}>
            <b style={{ fontSize: 17 }}>🔒 Privacidade</b>
            {priv === null && <span style={{ fontSize: 15, color: CORES.nota }}>verificando…</span>}
            {priv && priv.ativo && (
              <span style={{ fontSize: 15, fontWeight: 700, color: CORES.verde, background: CORES.verdeFundo, border: `2px solid ${CORES.verde}`, borderRadius: 10, padding: "4px 10px" }}>
                Consentimento ativo desde {dataCurta(priv.desde)}
              </span>
            )}
            {priv && !priv.ativo && (
              <span style={{ fontSize: 15, fontWeight: 700, color: "#77560C", background: CORES.aviso, border: `2px solid ${CORES.destaque}`, borderRadius: 10, padding: "4px 10px" }}>
                Sem consentimento ativo — dados de saúde ocultos para a família
              </span>
            )}
            {priv && (
              <button onClick={priv.ativo ? revogar : conceder} style={{
                fontSize: 15, fontWeight: 700, padding: "8px 12px", borderRadius: 10, minHeight: 44,
                border: `2px solid ${CORES.anil}`, background: CORES.cartao, color: CORES.anil,
                cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif",
              }}>{priv.ativo ? "Revogar" : "Conceder"}</button>
            )}
            <button onClick={baixarPdf} style={{
              fontSize: 15, fontWeight: 700, padding: "8px 12px", borderRadius: 10, minHeight: 44,
              border: `2px solid ${CORES.anil}`, background: "#E7ECF8", color: CORES.anil,
              cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>📄 Relatório do mês</button>
          </div>
          {msgPriv && (
            <p role="status" style={{
              fontSize: 15, fontWeight: 700, borderRadius: 10, padding: "8px 12px",
              background: msgPriv.startsWith("✓") ? CORES.verdeFundo : CORES.aviso,
              border: `2px solid ${msgPriv.startsWith("✓") ? CORES.verde : CORES.destaque}`,
            }}>{msgPriv}</p>
          )}
          <label htmlFor={`recado-${i.id_idoso}`} style={{ display: "block", fontSize: 17, fontWeight: 700, marginBottom: 6 }}>
            💌 Mandar um recado para o mural
          </label>
          <textarea id={`recado-${i.id_idoso}`} value={recado} onChange={(e) => setRecado(e.target.value)}
            rows={2} maxLength={500} placeholder="Ex.: Domingo levo as crianças pra te ver!" style={{
              width: "100%", boxSizing: "border-box", fontSize: 17, padding: 10,
              border: `2px solid ${CORES.tinta}`, borderRadius: 12, marginBottom: 8,
              fontFamily: "'Atkinson Hyperlegible', sans-serif", background: CORES.cartao, resize: "vertical",
            }} />
          {msgRec && (
            <p role="status" style={{
              fontSize: 16, fontWeight: 700, borderRadius: 10, padding: "8px 12px",
              background: msgRec.startsWith("✓") ? CORES.verdeFundo : CORES.aviso,
              border: `2px solid ${msgRec.startsWith("✓") ? CORES.verde : CORES.destaque}`,
            }}>{msgRec}</p>
          )}
          <button onClick={mandarRecado} style={{
            fontSize: 17, fontWeight: 700, padding: "10px 16px", borderRadius: 12, minHeight: 48,
            border: "none", background: CORES.anil, color: "#fff", cursor: "pointer",
            fontFamily: "'Atkinson Hyperlegible', sans-serif",
          }}>Enviar recado</button>
          <MeusRecados id_idoso={i.id_idoso} token={token} demo={demo} versao={versaoMural} />
        </div>
      )}
      {filhos}
    </Cartao>
  );
}

function VisaoResponsavel({ painel, historicos, carregar, token, demo }) {
  return (
    <main style={{ maxWidth: 560, margin: "0 auto", padding: 22 }}>
      <h2 style={{ fontSize: 24, margin: "6px 0 4px" }}>Quem você acompanha</h2>
      <p style={{ fontSize: 17, color: CORES.nota, margin: "0 0 16px" }}>
        Só você e a equipe do lar veem estas informações.
      </p>
      {painel.length === 0 && <Cartao>Nenhum idoso vinculado a você ainda.</Cartao>}
      {painel.map((i) => (
        <CartaoIdoso key={i.id_idoso} i={i} historicos={historicos} carregar={carregar}
          token={token} demo={demo} podeRecado />
      ))}
    </main>
  );
}

// ============================================================
// ÁREA DA EQUIPE — alertas + residentes + lançamento
// ============================================================
function SeletorResidente({ painel, selecionado, aoEscolher }) {
  return (
    <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 16 }}>
      {painel.map((i) => (
        <button key={i.id_idoso} onClick={() => aoEscolher(i.id_idoso)} aria-pressed={selecionado === i.id_idoso} style={{
          fontSize: 17, fontWeight: 700, padding: "10px 14px", borderRadius: 12,
          border: selecionado === i.id_idoso ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
          background: selecionado === i.id_idoso ? "#E7ECF8" : CORES.cartao, cursor: "pointer",
          fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>{i.nome.split(" ")[0]}</button>
      ))}
    </div>
  );
}

const INSTRUMENTOS = [
  { v: "KATZ", rot: "Katz (AVDs)" }, { v: "LAWTON", rot: "Lawton (AIVDs)" },
  { v: "GDS15", rot: "GDS-15 (humor)" }, { v: "WHOQOL_OLD", rot: "WHOQOL-OLD" },
  { v: "ICOPE", rot: "ICOPE (triagem)" },
];

function LancarAvaliacao({ painel, token, demo }) {
  const [idoso, setIdoso] = useState(null);
  const [instrumento, setInstrumento] = useState(null);
  const [pontuacao, setPontuacao] = useState("");
  const [obs, setObs] = useState("");
  const [msg, setMsg] = useState("");

  async function lancar() {
    if (!idoso || !instrumento) return setMsg("Escolha o residente e o instrumento.");
    if (demo) return setMsg("✓ (demonstração) Avaliação registrada.");
    try {
      await api("/avaliacoes", {
        metodo: "POST", token,
        corpo: {
          id_idoso: idoso, instrumento,
          pontuacao_total: pontuacao === "" ? undefined : Number(pontuacao),
          observacoes: obs || undefined,
        },
      });
      setMsg("✓ Avaliação registrada.");
      setInstrumento(null); setPontuacao(""); setObs("");
    } catch (e) { setMsg(`Não consegui registrar (${e.message}).`); }
  }

  return (
    <Cartao>
      <p style={{ fontSize: 18, fontWeight: 700, margin: "0 0 8px" }}>Residente</p>
      <SeletorResidente painel={painel} selecionado={idoso} aoEscolher={setIdoso} />
      <p style={{ fontSize: 18, fontWeight: 700, margin: "0 0 8px" }}>Instrumento</p>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 16 }}>
        {INSTRUMENTOS.map((o) => (
          <button key={o.v} onClick={() => setInstrumento(o.v)} aria-pressed={instrumento === o.v} style={{
            fontSize: 16, fontWeight: 700, padding: "10px 12px", borderRadius: 12,
            border: instrumento === o.v ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
            background: instrumento === o.v ? "#E7ECF8" : CORES.cartao, cursor: "pointer",
            fontFamily: "'Atkinson Hyperlegible', sans-serif",
          }}>{o.rot}</button>
        ))}
      </div>
      <label htmlFor="campo-pontuacao" style={{ display: "block", fontSize: 18, fontWeight: 700, marginBottom: 6 }}>
        Pontuação total (se o instrumento tiver)
      </label>
      <input id="campo-pontuacao" type="number" value={pontuacao} onChange={(e) => setPontuacao(e.target.value)} style={{
        width: 140, fontSize: 19, padding: 12, border: `2px solid ${CORES.tinta}`, borderRadius: 12,
        marginBottom: 14, fontFamily: "'Atkinson Hyperlegible', sans-serif", background: CORES.cartao,
      }} />
      <label style={{ display: "block", fontSize: 18, fontWeight: 700, marginBottom: 6 }} htmlFor="campo-obs-aval">Observações</label>
      <textarea id="campo-obs-aval" value={obs} onChange={(e) => setObs(e.target.value)} rows={2} style={{
        width: "100%", boxSizing: "border-box", fontSize: 18, padding: 12,
        border: `2px solid ${CORES.tinta}`, borderRadius: 12, marginBottom: 14,
        fontFamily: "'Atkinson Hyperlegible', sans-serif", background: CORES.cartao, resize: "vertical",
      }} />
      {msg && (
        <p role="status" style={{
          fontSize: 18, fontWeight: 700, borderRadius: 12, padding: "10px 14px",
          background: msg.startsWith("✓") ? CORES.verdeFundo : CORES.aviso,
          border: `2px solid ${msg.startsWith("✓") ? CORES.verde : CORES.destaque}`,
        }}>{msg}</p>
      )}
      <BotaoGrande onClick={lancar}>Registrar avaliação</BotaoGrande>
    </Cartao>
  );
}

// Visível apenas para psicólogos: o RLS no banco garante que ninguém
// mais lê estes registros, mesmo que tente pela API diretamente.
function EvolucaoPsico({ painel, token, demo }) {
  const [idoso, setIdoso] = useState(null);
  const [lista, setLista] = useState([]);
  const [texto, setTexto] = useState("");
  const [msg, setMsg] = useState("");

  async function escolher(id) {
    setIdoso(id); setMsg("");
    if (demo) return setLista([]);
    try { setLista(await api(`/idosos/${id}/atendimentos-psicologicos`, { token })); }
    catch { setLista([]); }
  }

  async function gravar() {
    if (!idoso || !texto.trim()) return setMsg("Escolha o residente e escreva a evolução.");
    if (demo) return setMsg("✓ (demonstração) Evolução registrada.");
    try {
      await api("/atendimentos-psicologicos", { metodo: "POST", token, corpo: { id_idoso: idoso, evolucao: texto } });
      setMsg("✓ Evolução registrada com sigilo.");
      setTexto("");
      escolher(idoso);
    } catch (e) { setMsg(`Não consegui registrar (${e.message}).`); }
  }

  return (
    <Cartao borda={CORES.anil}>
      <p style={{ fontSize: 16, color: CORES.nota, margin: "0 0 12px" }}>
        🔒 Registro de acesso restrito a psicólogos (Resolução CFP 01/2009). Nem a gestão da ILPI lê este conteúdo.
      </p>
      <p style={{ fontSize: 18, fontWeight: 700, margin: "0 0 8px" }}>Residente</p>
      <SeletorResidente painel={painel} selecionado={idoso} aoEscolher={escolher} />
      {idoso && (
        <div style={{ marginBottom: 14 }}>
          {lista.length === 0 && <p style={{ fontSize: 17, color: CORES.nota }}>Sem registros anteriores.</p>}
          {lista.map((a) => (
            <div key={a.id_atendimento} style={{
              background: CORES.papel, border: "2px solid #E4DCC9", borderRadius: 12,
              padding: "10px 12px", marginBottom: 8,
            }}>
              <div style={{ fontSize: 15, color: CORES.nota }}>{dataCurta(a.data_hora)}</div>
              <div style={{ fontSize: 17 }}>{a.evolucao}</div>
            </div>
          ))}
        </div>
      )}
      <label style={{ display: "block", fontSize: 18, fontWeight: 700, marginBottom: 6 }} htmlFor="campo-evolucao">Nova evolução</label>
      <textarea id="campo-evolucao" value={texto} onChange={(e) => setTexto(e.target.value)} rows={3} style={{
        width: "100%", boxSizing: "border-box", fontSize: 18, padding: 12,
        border: `2px solid ${CORES.tinta}`, borderRadius: 12, marginBottom: 14,
        fontFamily: "'Atkinson Hyperlegible', sans-serif", background: CORES.cartao, resize: "vertical",
      }} />
      {msg && (
        <p role="status" style={{
          fontSize: 18, fontWeight: 700, borderRadius: 12, padding: "10px 14px",
          background: msg.startsWith("✓") ? CORES.verdeFundo : CORES.aviso,
          border: `2px solid ${msg.startsWith("✓") ? CORES.verde : CORES.destaque}`,
        }}>{msg}</p>
      )}
      <BotaoGrande onClick={gravar}>Registrar evolução</BotaoGrande>
    </Cartao>
  );
}

const horaCurta = (iso) => new Date(iso).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });

function Medicacao({ painel, token, demo, funcao }) {
  const [doses, setDoses] = useState(null);
  const [msg, setMsg] = useState("");
  const [idoso, setIdoso] = useState(null);
  const [medicamento, setMedicamento] = useState("");
  const [doseTxt, setDoseTxt] = useState("");
  const [horarios, setHorarios] = useState("");

  async function carregar() {
    if (demo || !token) return setDoses(DEMO.doses);
    try { setDoses(await api("/medicacoes/hoje", { token })); } catch { setDoses([]); }
  }
  useEffect(() => { carregar(); }, []); // eslint-disable-line

  async function dar(d) {
    if (demo) return setMsg("✓ (demonstração) Dose registrada.");
    try {
      await api("/medicacoes/administrar", {
        metodo: "POST", token,
        corpo: { id_prescricao: d.id_prescricao, horario_previsto: d.horario_previsto },
      });
      setMsg(`✓ Dose das ${horaCurta(d.horario_previsto)} registrada.`);
      carregar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }

  async function prescrever() {
    const hs = horarios.split(",").map((h) => h.trim()).filter(Boolean);
    if (!idoso || !medicamento.trim() || !doseTxt.trim() || !hs.length)
      return setMsg("Preencha residente, medicamento, dose e horários (ex.: 08:00, 20:00).");
    if (demo) return setMsg("✓ (demonstração) Prescrição criada.");
    try {
      await api("/prescricoes", { metodo: "POST", token, corpo: { id_idoso: idoso, medicamento, dose: doseTxt, horarios: hs } });
      setMsg("✓ Prescrição criada.");
      setMedicamento(""); setDoseTxt(""); setHorarios("");
      carregar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }

  const atrasada = (d) => !d.administrado_em && new Date(d.horario_previsto) < new Date();
  const podePrescrever = demo || ["medico", "enfermeiro"].includes(funcao);
  const campo = {
    width: "100%", boxSizing: "border-box", fontSize: 17, padding: 10,
    border: `2px solid ${CORES.tinta}`, borderRadius: 12, marginBottom: 10,
    fontFamily: "'Atkinson Hyperlegible', sans-serif", background: CORES.cartao,
  };

  return (
    <Cartao>
      {!doses && <p>Carregando as doses…</p>}
      {doses && doses.length === 0 && <p style={{ fontSize: 17 }}>Nenhuma prescrição ativa hoje.</p>}
      {doses && doses.map((d, k) => (
        <div key={k} style={{
          display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10,
          background: CORES.papel, borderRadius: 12, padding: "10px 14px", marginBottom: 8,
          border: `2px solid ${atrasada(d) ? CORES.alerta : "#E4DCC9"}`,
        }}>
          <span style={{ fontSize: 16.5 }}>
            <b>{horaCurta(d.horario_previsto)}</b> · {d.idoso.split(" ")[0]} · {d.medicamento} {d.dose}
            {atrasada(d) && <b style={{ color: CORES.alerta }}> · atrasada</b>}
          </span>
          {d.administrado_em
            ? <span style={{ fontSize: 15, fontWeight: 700, color: CORES.verde, whiteSpace: "nowrap" }}>✓ {horaCurta(d.administrado_em)}{d.quem_deu ? ` (${d.quem_deu.split(" ")[0]})` : ""}</span>
            : <button onClick={() => dar(d)} style={{
                fontSize: 16, fontWeight: 700, padding: "10px 14px", borderRadius: 12, minHeight: 48,
                border: "none", background: CORES.verde, color: "#fff", cursor: "pointer",
                fontFamily: "'Atkinson Hyperlegible', sans-serif", whiteSpace: "nowrap",
              }}>Dar ✓</button>}
        </div>
      ))}
      {msg && (
        <p role="status" style={{
          fontSize: 17, fontWeight: 700, borderRadius: 12, padding: "10px 14px",
          background: msg.startsWith("✓") ? CORES.verdeFundo : CORES.aviso,
          border: `2px solid ${msg.startsWith("✓") ? CORES.verde : CORES.destaque}`,
        }}>{msg}</p>
      )}
      {podePrescrever && (
        <div style={{ marginTop: 14, borderTop: "2px solid #E4DCC9", paddingTop: 12 }}>
          <p style={{ fontSize: 18, fontWeight: 700, margin: "0 0 8px" }}>Nova prescrição (médico/enfermeiro)</p>
          <SeletorResidente painel={painel} selecionado={idoso} aoEscolher={setIdoso} />
          <input aria-label="Medicamento" placeholder="Medicamento (ex.: Losartana)" value={medicamento}
            onChange={(e) => setMedicamento(e.target.value)} style={campo} />
          <input aria-label="Dose" placeholder="Dose (ex.: 50 mg)" value={doseTxt}
            onChange={(e) => setDoseTxt(e.target.value)} style={campo} />
          <input aria-label="Horários" placeholder="Horários (ex.: 08:00, 20:00)" value={horarios}
            onChange={(e) => setHorarios(e.target.value)} style={campo} />
          <BotaoGrande onClick={prescrever}>Criar prescrição</BotaoGrande>
        </div>
      )}
    </Cartao>
  );
}

function PlantaoEquipe({ token, demo, painel }) {
  const [lista, setLista] = useState(null);
  const [novo, setNovo] = useState(false);
  const [f, setF] = useState({ turno: "tarde", prioridade: "rotina", texto: "", id_idoso: null });
  const [msg, setMsg] = useState("");

  async function carregar() {
    if (demo || !token) return setLista(DEMO.plantao);
    try { setLista(await api("/plantao", { token })); } catch { setLista([]); }
  }
  useEffect(() => { carregar(); }, []); // eslint-disable-line

  async function criar() {
    if (!f.texto.trim()) return setMsg("Escreva o recado.");
    if (demo) { setMsg("✓ (demonstração) Recado registrado."); setNovo(false); return; }
    try {
      await api("/plantao", { metodo: "POST", token, corpo: {
        turno: f.turno, prioridade: f.prioridade, texto: f.texto, id_idoso: f.id_idoso || undefined,
      }});
      setMsg("✓ Recado passado para a equipe."); setNovo(false);
      setF({ turno: "tarde", prioridade: "rotina", texto: "", id_idoso: null });
      carregar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }
  async function ciencia(id) {
    if (demo) return carregar();
    try { await api(`/plantao/${id}/ciencia`, { metodo: "POST", token }); carregar(); } catch {}
  }
  async function resolver(id, r) {
    if (demo) return carregar();
    try { await api(`/plantao/${id}/resolvido`, { metodo: "POST", token, corpo: { resolvido: r } }); carregar(); } catch {}
  }
  // CRUD do recado: editar e excluir (só quem escreveu)
  const [editando, setEditando] = useState(null); // { id_recado, texto, prioridade }
  async function salvarEdicao() {
    if (!editando.texto.trim()) return setMsg("O recado não pode ficar vazio.");
    if (demo) { setEditando(null); return setMsg("✓ (demonstração) Recado editado."); }
    try {
      await api(`/plantao/${editando.id_recado}`, { metodo: "PATCH", token, corpo: { texto: editando.texto, prioridade: editando.prioridade } });
      setEditando(null); setMsg("✓ Recado atualizado."); carregar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }
  async function excluir(id) {
    if (demo) return setMsg("✓ (demonstração) Recado excluído.");
    try { await api(`/plantao/${id}`, { metodo: "DELETE", token }); setMsg("✓ Recado excluído."); carregar(); }
    catch (e) { setMsg(`Não deu (${e.message}).`); }
  }

  if (!lista) return <Cartao>Carregando o plantão…</Cartao>;
  const btn = (txt, onClick, cor, rotulo) => (
    <button onClick={onClick} aria-label={rotulo} style={{
      fontSize: 15, fontWeight: 700, padding: "8px 12px", borderRadius: 10, minHeight: 44, cursor: "pointer",
      border: `2px solid ${cor}`, background: "#FFFDF4", color: cor, fontFamily: "'Atkinson Hyperlegible', sans-serif",
    }}>{txt}</button>
  );

  return (
    <Cartao borda={CORES.anil}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
        <p style={{ fontSize: 18, fontWeight: 700, margin: 0 }}>🔄 Passagem de plantão</p>
        <button onClick={() => { setNovo(!novo); setMsg(""); }} style={{
          fontSize: 15, fontWeight: 700, padding: "8px 14px", borderRadius: 10, minHeight: 44, cursor: "pointer",
          border: "none", background: CORES.anil, color: "#fff", fontFamily: "'Atkinson Hyperlegible', sans-serif",
        }}>{novo ? "Fechar" : "+ Recado"}</button>
      </div>
      <Aviso msg={msg} />

      {novo && (
        <div style={{ background: "#F3EEE0", borderRadius: 12, padding: 12, marginBottom: 12 }}>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 8 }}>
            {TURNOS_PLANTAO.map((t) => (
              <button key={t.v} onClick={() => setF({ ...f, turno: t.v })} aria-pressed={f.turno === t.v} style={{
                fontSize: 15, fontWeight: 700, padding: "8px 10px", borderRadius: 10, cursor: "pointer",
                border: f.turno === t.v ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
                background: f.turno === t.v ? "#E7ECF8" : "#FFFDF4", fontFamily: "'Atkinson Hyperlegible', sans-serif",
              }}>{t.r}</button>
            ))}
          </div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 8 }}>
            {Object.entries(PRIO_PLANTAO).map(([v, o]) => (
              <button key={v} onClick={() => setF({ ...f, prioridade: v })} aria-pressed={f.prioridade === v} style={{
                fontSize: 15, fontWeight: 700, padding: "8px 10px", borderRadius: 10, cursor: "pointer",
                border: f.prioridade === v ? `3px solid ${o.cor}` : "2px solid #D8CFBC",
                background: f.prioridade === v ? o.fundo : "#FFFDF4", color: o.cor, fontFamily: "'Atkinson Hyperlegible', sans-serif",
              }}>{o.emoji} {o.r}</button>
            ))}
          </div>
          <select aria-label="Sobre qual residente (opcional)" value={f.id_idoso || ""} onChange={(e) => setF({ ...f, id_idoso: e.target.value ? Number(e.target.value) : null })}
            style={{ ...campoG, marginBottom: 8 }}>
            <option value="">Recado geral (sem residente específico)</option>
            {(painel || []).map((i) => <option key={i.id_idoso} value={i.id_idoso}>{i.nome}</option>)}
          </select>
          <textarea value={f.texto} onChange={(e) => setF({ ...f, texto: e.target.value })} rows={3}
            placeholder="O que o próximo turno precisa saber?" style={{ ...campoG, marginBottom: 8 }} />
          <BotaoGrande onClick={criar}>Passar recado</BotaoGrande>
        </div>
      )}

      {lista.length === 0 && <p style={{ fontSize: 16, color: CORES.nota }}>Nenhum recado em aberto. Plantão tranquilo. 🌿</p>}
      {lista.map((r) => {
        const p = PRIO_PLANTAO[r.prioridade] || PRIO_PLANTAO.rotina;
        return (
          <div key={r.id_recado} style={{
            background: r.resolvido ? "#F0EEE7" : p.fundo, border: `2px solid ${r.resolvido ? "#D8CFBC" : p.cor}`,
            borderRadius: 12, padding: "10px 14px", marginBottom: 8, opacity: r.resolvido ? 0.6 : 1,
          }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 8, marginBottom: 4 }}>
              <b style={{ fontSize: 15, color: p.cor }}>{p.emoji} {p.r}{r.idoso ? ` · ${r.idoso.split(" ")[0]}` : " · geral"}</b>
              <span style={{ fontSize: 13, color: CORES.nota, whiteSpace: "nowrap" }}>{TURNOS_PLANTAO.find(t=>t.v===r.turno)?.r} · {horaData(r.data_hora)}</span>
            </div>
            {editando && editando.id_recado === r.id_recado ? (
              <div style={{ marginBottom: 8 }}>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 6 }}>
                  {Object.entries(PRIO_PLANTAO).map(([v, o]) => (
                    <button key={v} onClick={() => setEditando({ ...editando, prioridade: v })} aria-pressed={editando.prioridade === v} style={{
                      fontSize: 14, fontWeight: 700, padding: "6px 10px", borderRadius: 10, cursor: "pointer",
                      border: editando.prioridade === v ? `3px solid ${o.cor}` : "2px solid #D8CFBC",
                      background: editando.prioridade === v ? o.fundo : "#FFFDF4", color: o.cor, fontFamily: "'Atkinson Hyperlegible', sans-serif",
                    }}>{o.emoji} {o.r}</button>
                  ))}
                </div>
                <textarea aria-label="Texto do recado" value={editando.texto} rows={3}
                  onChange={(e) => setEditando({ ...editando, texto: e.target.value })} style={{ ...campoG, marginBottom: 6 }} />
                <div style={{ display: "flex", gap: 6 }}>
                  {btn("Salvar", salvarEdicao, CORES.verde)}
                  {btn("Cancelar", () => setEditando(null), CORES.cinza)}
                </div>
              </div>
            ) : (
              <p style={{ fontSize: 17, margin: "0 0 8px" }}>
                {r.texto.startsWith("[Alerta automático]") && (
                  <span title="Criado pelo banco (trigger) a partir dos sinais vitais" style={{
                    fontSize: 13, fontWeight: 700, background: CORES.anil, color: "#fff", borderRadius: 6, padding: "1px 6px", marginRight: 6,
                  }}>🤖 automático</span>
                )}
                {r.texto.replace(/^\[Alerta automático\]\s*/, "")}
              </p>
            )}
            <div style={{ display: "flex", flexWrap: "wrap", gap: 6, alignItems: "center" }}>
              <span style={{ fontSize: 13, color: CORES.nota }}>por {r.autor?.split(" ")[0]} · {r.ciencias} ciente(s)</span>
              <div style={{ flex: 1 }} />
              {r.meu && !editando && btn("✏️", () => setEditando({ id_recado: r.id_recado, texto: r.texto, prioridade: r.prioridade }), CORES.anil, "Editar recado")}
              {r.meu && !editando && btn("🗑️", () => excluir(r.id_recado), CORES.alerta, "Excluir recado")}
              {!r.resolvido && !r.eu_ciente && btn("✓ Li", () => ciencia(r.id_recado), CORES.anil)}
              {!r.resolvido && r.eu_ciente && <span style={{ fontSize: 14, fontWeight: 700, color: CORES.verde }}>✓ você leu</span>}
              {!r.resolvido && btn("Resolver", () => resolver(r.id_recado, true), CORES.verde)}
              {r.resolvido && btn("Reabrir", () => resolver(r.id_recado, false), CORES.cinza)}
            </div>
          </div>
        );
      })}
    </Cartao>
  );
}

function ResumoDia({ token, demo }) {
  const [r, setR] = useState(null);
  useEffect(() => {
    if (demo || !token) return setR({ residentes: 4, checkins_hoje: 2, sem_checkin_3d: 1, atividades_hoje: 3, doses_pendentes: 1, prescricoes_ativas: 5 });
    api("/resumo-dia", { token }).then(setR).catch(() => setR(null));
  }, []); // eslint-disable-line
  if (!r) return null;
  const bolha = (num, rot, alerta) => (
    <div style={{
      flex: "1 1 30%", minWidth: 92, textAlign: "center", padding: "12px 8px", borderRadius: 14,
      background: alerta && Number(num) > 0 ? CORES.alertaFundo : "#F3EEE0",
      border: `2px solid ${alerta && Number(num) > 0 ? CORES.alerta : "#E4DCC9"}`,
    }}>
      <div style={{ fontSize: 30, fontWeight: 700, color: alerta && Number(num) > 0 ? CORES.alerta : CORES.tinta }}>{num}</div>
      <div style={{ fontSize: 14, color: CORES.nota, lineHeight: 1.2 }}>{rot}</div>
    </div>
  );
  return (
    <Cartao borda={CORES.anil}>
      <p style={{ fontSize: 18, fontWeight: 700, margin: "0 0 12px" }}>☀️ Hoje na casa</p>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
        {bolha(`${r.checkins_hoje}/${r.residentes}`, "check-ins hoje")}
        {bolha(r.sem_checkin_3d, "sem registro há 3 dias", true)}
        {bolha(r.doses_pendentes, "doses pendentes", true)}
        {bolha(r.atividades_hoje, "atividades hoje")}
      </div>
    </Cartao>
  );
}

function AgendaEquipe({ token, demo }) {
  const [lista, setLista] = useState(null);
  const [f, setF] = useState({ nome: "", categoria: "social", data: "", hora: "" });
  const [msg, setMsg] = useState("");

  async function carregar() {
    if (demo || !token) return setLista(DEMO.agenda);
    try { setLista(await api("/atividades", { token })); } catch { setLista([]); }
  }
  useEffect(() => { carregar(); }, []); // eslint-disable-line

  const [editId, setEditId] = useState(null); // atividade em edição (null = criando uma nova)

  async function criar() {
    if (!f.nome || !f.data || !f.hora) return setMsg("Preencha nome, data e hora.");
    if (demo) return setMsg(editId ? "✓ (demonstração) Atividade atualizada." : "✓ (demonstração) Atividade criada.");
    const corpo = { nome: f.nome, categoria: f.categoria, data_hora: new Date(`${f.data}T${f.hora}`).toISOString() };
    try {
      if (editId) {
        await api(`/atividades/${editId}`, { metodo: "PATCH", token, corpo });
        setMsg("✓ Atividade atualizada.");
      } else {
        await api("/atividades", { metodo: "POST", token, corpo });
        setMsg("✓ Atividade criada e já visível para os residentes.");
      }
      setF({ nome: "", categoria: "social", data: "", hora: "" }); setEditId(null);
      carregar();
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }
  function editar(a) {
    const d = new Date(a.data_hora), z = (n) => String(n).padStart(2, "0");
    setEditId(a.id_atividade); setMsg("");
    setF({ nome: a.nome, categoria: a.categoria,
           data: `${d.getFullYear()}-${z(d.getMonth() + 1)}-${z(d.getDate())}`, hora: `${z(d.getHours())}:${z(d.getMinutes())}` });
  }
  async function excluir(a) {
    if (demo) return setMsg("✓ (demonstração) Atividade excluída.");
    try { await api(`/atividades/${a.id_atividade}`, { metodo: "DELETE", token }); setMsg("✓ Atividade excluída."); carregar(); }
    catch (e) { setMsg(e.message); }
  }
  const mini = (txt, rotulo, cor, onClick) => (
    <button onClick={onClick} aria-label={rotulo} style={{
      minHeight: 40, minWidth: 40, fontSize: 15, borderRadius: 10, cursor: "pointer",
      border: `2px solid ${cor}`, background: "#FFFDF4", color: cor, fontFamily: "'Atkinson Hyperlegible', sans-serif",
    }}>{txt}</button>
  );

  return (
    <Cartao>
      {lista && lista.slice(0, 6).map((a) => {
        const cat = CAT_ATIV[a.categoria] || { r: a.categoria, emoji: "•" };
        return (
          <div key={a.id_atividade} style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 0", borderBottom: "1px solid #E4DCC9" }}>
            <span style={{ fontSize: 16, flex: 1 }}>{cat.emoji} {a.nome}</span>
            <span style={{ fontSize: 15, color: CORES.nota, whiteSpace: "nowrap" }}>{horaData(a.data_hora)} · {a.confirmados} conf.</span>
            {mini("✏️", `Editar ${a.nome}`, CORES.anil, () => editar(a))}
            {mini("🗑️", `Excluir ${a.nome}`, CORES.alerta, () => excluir(a))}
          </div>
        );
      })}
      <div style={{ marginTop: 12 }}>
        <p style={{ fontSize: 18, fontWeight: 700, margin: "0 0 8px" }}>{editId ? "Editar atividade" : "Nova atividade"}</p>
        <input style={campoG} placeholder="Nome (ex.: Roda de conversa)" value={f.nome} onChange={(e) => setF({ ...f, nome: e.target.value })} />
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 12 }}>
          {Object.entries(CAT_ATIV).map(([v, o]) => (
            <button key={v} onClick={() => setF({ ...f, categoria: v })} aria-pressed={f.categoria === v} style={{
              fontSize: 15, fontWeight: 700, padding: "10px 12px", borderRadius: 10,
              border: f.categoria === v ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
              background: f.categoria === v ? "#E7ECF8" : "#FFFDF4", cursor: "pointer",
              fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>{o.emoji} {o.r}</button>
          ))}
        </div>
        <div style={{ display: "flex", gap: 10, marginBottom: 12 }}>
          <input style={{ ...campoG, marginBottom: 0 }} type="date" value={f.data} onChange={(e) => setF({ ...f, data: e.target.value })} />
          <input style={{ ...campoG, marginBottom: 0 }} type="time" value={f.hora} onChange={(e) => setF({ ...f, hora: e.target.value })} />
        </div>
        {msg && <Aviso msg={msg} />}
        <div style={{ display: "flex", gap: 10 }}>
          <BotaoGrande onClick={criar}>{editId ? "Salvar alterações" : "Criar atividade"}</BotaoGrande>
          {editId && <BotaoGrande cor={CORES.cinza} onClick={() => { setEditId(null); setF({ nome: "", categoria: "social", data: "", hora: "" }); }}>Cancelar</BotaoGrande>}
        </div>
      </div>
    </Cartao>
  );
}

function EscalasEquipe({ painel, token, demo }) {
  const [idoso, setIdoso] = useState(null);
  const [instr, setInstr] = useState(null);
  const [chave, setChave] = useState(0); // reinicia a escala
  return (
    <Cartao>
      <p style={{ fontSize: 16, fontWeight: 700, margin: "0 0 8px" }}>Residente</p>
      <SeletorResidente painel={painel} selecionado={idoso} aoEscolher={(v) => { setIdoso(v); setInstr(null); }} />
      {idoso && !instr && (
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 8 }}>
          <BotaoGrande onClick={() => { setInstr("GDS15"); setChave(chave + 1); }}>Depressão (GDS-15)</BotaoGrande>
          <BotaoGrande onClick={() => { setInstr("KATZ"); setChave(chave + 1); }} cor={CORES.verde}>Autonomia (Katz)</BotaoGrande>
        </div>
      )}
      {idoso && instr && (
        <div style={{ marginTop: 12 }}>
          <EscalaGuiada key={chave} id_idoso={idoso} instrumento={instr} token={token} demo={demo} aoConcluir={() => {}} />
          <button onClick={() => setInstr(null)} style={{ marginTop: 10, fontSize: 15, fontWeight: 700, padding: "8px 14px", borderRadius: 10, border: `2px solid ${CORES.cinza}`, background: "#FFFDF4", color: CORES.cinza, cursor: "pointer", fontFamily: "'Atkinson Hyperlegible', sans-serif" }}>Escolher outra escala</button>
        </div>
      )}
    </Cartao>
  );
}

function RegistrarSinais({ painel, token, demo }) {
  const [idoso, setIdoso] = useState(null);
  const [v, setV] = useState({});
  const [msg, setMsg] = useState("");
  const campos = [
    { k: "pressao_sis", r: "Pressão máxima", u: "mmHg" }, { k: "pressao_dia", r: "Pressão mínima", u: "mmHg" },
    { k: "freq_cardiaca", r: "Batimentos", u: "bpm" }, { k: "temperatura", r: "Temperatura", u: "°C" },
    { k: "peso_kg", r: "Peso", u: "kg" }, { k: "glicemia", r: "Glicemia", u: "mg/dL" }, { k: "saturacao", r: "Saturação", u: "%" },
  ];
  async function salvar() {
    const medidas = Object.fromEntries(Object.entries(v).filter(([, x]) => x !== "" && x != null).map(([k, x]) => [k, Number(x)]));
    if (!idoso || Object.keys(medidas).length === 0) return setMsg("Escolha o residente e preencha ao menos uma medida.");
    if (demo) return setMsg("✓ (demonstração) Sinais registrados.");
    try {
      await api("/sinais", { metodo: "POST", token, corpo: { id_idoso: idoso, ...medidas } });
      setMsg("✓ Sinais vitais registrados.");
      setV({});
    } catch (e) { setMsg(`Não deu (${e.message}).`); }
  }
  return (
    <Cartao>
      <p style={{ fontSize: 18, fontWeight: 700, margin: "0 0 8px" }}>Residente</p>
      <SeletorResidente painel={painel} selecionado={idoso} aoEscolher={setIdoso} />
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginBottom: 12 }}>
        {campos.map((c) => (
          <div key={c.k}>
            <label style={{ fontSize: 15, fontWeight: 700, display: "block", marginBottom: 4 }}>{c.r} <span style={{ color: CORES.nota, fontWeight: 400 }}>({c.u})</span></label>
            <input inputMode="decimal" value={v[c.k] || ""} onChange={(e) => setV({ ...v, [c.k]: e.target.value })}
              style={{ ...campoG, marginBottom: 0 }} />
          </div>
        ))}
      </div>
      {msg && <Aviso msg={msg} />}
      <BotaoGrande onClick={salvar}>Registrar sinais</BotaoGrande>
    </Cartao>
  );
}

function VisaoEquipe({ painel, alertas, historicos, carregar, enviar, token, demo, funcao }) {
  const [selecionado, setSelecionado] = useState(null);
  const [humor, setHumor] = useState(null);
  const [conforto, setConforto] = useState(null);
  const [dor, setDor] = useState(null);
  const [msg, setMsg] = useState("");

  async function lancar() {
    if (!selecionado || humor == null || conforto == null || dor == null)
      return setMsg("Escolha o residente e responda as três escalas.");
    try {
      await enviar({ id_idoso: selecionado, humor, conforto, dor });
      setMsg("✓ Check-in registrado.");
      setHumor(null); setConforto(null); setDor(null);
    } catch (e) {
      setMsg(`Não consegui registrar (${e.message}).`);
    }
  }

  return (
    <main style={{ maxWidth: 640, margin: "0 auto", padding: 22 }}>
      <ResumoDia token={token} demo={demo} />
      <PlantaoEquipe token={token} demo={demo} painel={painel} />
      <h2 style={{ fontSize: 24, margin: "6px 0 12px" }}>⚠ Precisam de atenção</h2>
      {alertas.length === 0 && <Cartao borda={CORES.verde}>Ninguém sem check-in há mais de 3 dias. 🎉</Cartao>}
      {alertas.map((a) => (
        <Cartao key={a.nome} borda={CORES.alerta}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10 }}>
            <div>
              <b style={{ fontSize: 19 }}>{a.nome}</b>
              <div style={{ fontSize: 16, color: CORES.nota }}>
                Último check-in: {a.ultimo_checkin ? dataCurta(a.ultimo_checkin) : "nunca registrou"}
              </div>
            </div>
            <span style={{
              background: CORES.alertaFundo, color: CORES.alerta, fontWeight: 700,
              borderRadius: 10, padding: "8px 12px", fontSize: 17, whiteSpace: "nowrap",
            }}>
              {a.dias_sem_checkin} dias
            </span>
          </div>
          {a.telefone_responsavel && (
            <a target="_blank" rel="noreferrer"
              href={`https://wa.me/55${String(a.telefone_responsavel).replace(/\D/g, "")}?text=${encodeURIComponent(
                `Olá${a.responsavel ? ", " + a.responsavel.split(" ")[0] : ""}! Aqui é da equipe do lar. Notamos que ${a.nome.split(" ")[0]} está há ${a.dias_sem_checkin} dia(s) sem registro de bem-estar. Uma visitinha ou uma ligação faria bem. 💛`)}`}
              style={{
                display: "inline-block", marginTop: 10, fontSize: 16, fontWeight: 700,
                padding: "10px 14px", borderRadius: 12, background: "#1B8A4B", color: "#fff",
                textDecoration: "none", fontFamily: "'Atkinson Hyperlegible', sans-serif",
              }}>
              💬 Avisar {a.responsavel ? a.responsavel.split(" ")[0] : "o responsável"} no WhatsApp
            </a>
          )}
        </Cartao>
      ))}

      <h2 style={{ fontSize: 24, margin: "24px 0 12px" }}>📅 Agenda de atividades</h2>
      <AgendaEquipe token={token} demo={demo} />

      <h2 style={{ fontSize: 24, margin: "24px 0 12px" }}>💊 Medicação de hoje</h2>
      <Medicacao painel={painel} token={token} demo={demo} funcao={funcao} />

      <h2 style={{ fontSize: 24, margin: "24px 0 12px" }}>Residentes da sua ILPI</h2>
      {painel.map((i) => (
        <CartaoIdoso key={i.id_idoso} i={i} historicos={historicos} carregar={carregar}
          token={token} demo={demo} podeRelatorio />
      ))}

      <h2 style={{ fontSize: 24, margin: "24px 0 12px" }}>Registrar check-in por um residente</h2>
      <Cartao>
        <p style={{ fontSize: 18, fontWeight: 700, margin: "0 0 8px" }}>Residente</p>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 16 }}>
          {painel.map((i) => (
            <button key={i.id_idoso} onClick={() => setSelecionado(i.id_idoso)} aria-pressed={selecionado === i.id_idoso} style={{
              fontSize: 17, fontWeight: 700, padding: "10px 14px", borderRadius: 12,
              border: selecionado === i.id_idoso ? `3px solid ${CORES.anil}` : "2px solid #D8CFBC",
              background: selecionado === i.id_idoso ? "#E7ECF8" : CORES.cartao, cursor: "pointer",
              fontFamily: "'Atkinson Hyperlegible', sans-serif",
            }}>{i.nome.split(" ")[0]}</button>
          ))}
        </div>
        <Escala rotulo="Ânimo" opcoes={OP_HUMOR} valor={humor} aoEscolher={setHumor} />
        <Escala rotulo="Conforto (1-5)" opcoes={OP_CONFORTO} valor={conforto} aoEscolher={setConforto} />
        <Escala rotulo="Dor (0-10)" opcoes={OP_DOR} valor={dor} aoEscolher={setDor} />
        {msg && (
          <p role="status" style={{
            fontSize: 18, fontWeight: 700, borderRadius: 12, padding: "10px 14px",
            background: msg.startsWith("✓") ? CORES.verdeFundo : CORES.aviso,
            border: `2px solid ${msg.startsWith("✓") ? CORES.verde : CORES.destaque}`,
          }}>{msg}</p>
        )}
        <BotaoGrande onClick={lancar}>Registrar check-in</BotaoGrande>
      </Cartao>

      <h2 style={{ fontSize: 24, margin: "24px 0 12px" }}>❤️ Registrar sinais vitais</h2>
      <RegistrarSinais painel={painel} token={token} demo={demo} />

      <h2 style={{ fontSize: 24, margin: "24px 0 12px" }}>📋 Escalas guiadas</h2>
      <EscalasEquipe painel={painel} token={token} demo={demo} />

      <h2 style={{ fontSize: 24, margin: "24px 0 12px" }}>Lançar avaliação clínica</h2>
      <LancarAvaliacao painel={painel} token={token} demo={demo} />

      {funcao === "psicologo" && (
        <>
          <h2 style={{ fontSize: 24, margin: "24px 0 12px" }}>Evolução psicológica</h2>
          <EvolucaoPsico painel={painel} token={token} demo={demo} />
        </>
      )}
    </main>
  );
}
