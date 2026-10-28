import { criarBaralho, distribuir, validarJogo, ehCanastra, pontosCarta, pontuarJogos, pontuarMao } from "./motor.mjs";

let ok = 0, fail = 0;
const t = (nome, cond) => { console.log((cond?"✓":"✗ FALHOU:")+" "+nome); cond?ok++:fail++; };

// baralho
const b = criarBaralho();
t("baralho tem 108 cartas", b.length === 108);
t("baralho tem 4 coringas", b.filter(c=>c.v==="Joker").length === 4);
t("baralho tem 8 setes (2 baralhos x 4 naipes)", b.filter(c=>c.v==="7").length === 8);

// distribuição
const j = distribuir();
t("cada mão tem 11 cartas", j.maos[0].length===11 && j.maos[1].length===11);
t("2 mortos de 11", j.mortos[0].length===11 && j.mortos[1].length===11);
t("descarte começa com 1", j.descarte.length===1);
const totalDist = j.maos[0].length+j.maos[1].length+j.mortos[0].length+j.mortos[1].length+j.monte.length+j.descarte.length;
t("nenhuma carta perdida (108)", totalDist === 108);

// pontos de carta
t("Joker vale 20", pontosCarta("Joker")===20);
t("2 vale 20", pontosCarta("2")===20);
t("A vale 15", pontosCarta("A")===15);
t("K vale 10", pontosCarta("K")===10);
t("5 vale 5", pontosCarta("5")===5);

// trinca natural
t("trinca de 3 reis é válida e limpa", (() => { const r=validarJogo([{v:"K",n:"♠"},{v:"K",n:"♥"},{v:"K",n:"♦"}]); return r.valido&&r.tipo==="trinca"&&r.limpa; })());
// trinca com curinga = suja
t("trinca com joker é suja", (() => { const r=validarJogo([{v:"K",n:"♠"},{v:"K",n:"♥"},{v:"Joker",n:"★"}]); return r.valido&&!r.limpa; })());
// sequência natural
t("sequência 4-5-6 mesmo naipe é válida limpa", (() => { const r=validarJogo([{v:"4",n:"♠"},{v:"5",n:"♠"},{v:"6",n:"♠"}]); return r.valido&&r.tipo==="sequencia"&&r.limpa; })());
// sequência com buraco preenchido por curinga
t("sequência 4-_-6 com joker no meio é válida suja", (() => { const r=validarJogo([{v:"4",n:"♠"},{v:"6",n:"♠"},{v:"Joker",n:"★"}]); return r.valido&&!r.limpa; })());
// sequência inválida (naipes diferentes)
t("4♠-5♥-6♦ NÃO é sequência", (() => { const r=validarJogo([{v:"4",n:"♠"},{v:"5",n:"♥"},{v:"6",n:"♦"}]); return !r.valido; })());
// menos de 3 cartas
t("2 cartas não formam jogo", !validarJogo([{v:"K",n:"♠"},{v:"K",n:"♥"}]).valido);

// canastra limpa (7 cartas sem curinga)
const canLimpa = [{v:"4",n:"♠"},{v:"5",n:"♠"},{v:"6",n:"♠"},{v:"7",n:"♠"},{v:"8",n:"♠"},{v:"9",n:"♠"},{v:"10",n:"♠"}];
t("canastra limpa de 7 = 200 pts", (() => { const c=ehCanastra(canLimpa); return c&&c.limpa&&c.pontos===200; })());
// canastra suja (com curinga)
const canSuja = [{v:"4",n:"♥"},{v:"5",n:"♥"},{v:"6",n:"♥"},{v:"Joker",n:"★"},{v:"8",n:"♥"},{v:"9",n:"♥"},{v:"10",n:"♥"}];
t("canastra suja de 7 = 100 pts", (() => { const c=ehCanastra(canSuja); return c&&!c.limpa&&c.pontos===100; })());

// pontuação total: canastra limpa de 7 espadas (4+5+6+7+8+9+10 = 5+5+5+5+10+10+10=50) + 200 = 250
t("pontuar canastra limpa = 250", pontuarJogos([canLimpa]) === 250);
// mão residual
t("mão com A+K = 25 pontos negativos", pontuarMao([{v:"A"},{v:"K"}]) === 25);

console.log(`\n═══ MOTOR: ${ok} passaram, ${fail} falharam ═══`);
