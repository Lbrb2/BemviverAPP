import { criarBaralho, distribuir, podeNaFundacao, podeNaColuna, venceu } from "./motor_pac.mjs";
let ok=0, fail=0; const t=(n,c)=>{console.log((c?"✓":"✗ FALHOU:")+" "+n);c?ok++:fail++;};

const b = criarBaralho();
t("baralho tem 52 cartas", b.length === 52);
t("13 de cada naipe", ["♠","♥","♦","♣"].every(n => b.filter(c=>c.n===n).length===13));

const e = distribuir();
t("7 colunas", e.colunas.length === 7);
t("coluna 1 tem 1 carta, coluna 7 tem 7", e.colunas[0].length===1 && e.colunas[6].length===7);
t("total no tableau = 28", e.colunas.reduce((s,c)=>s+c.length,0) === 28);
t("monte tem 24 (52-28)", e.monte.length === 24);
t("última de cada coluna está virada", e.colunas.every(col => col[col.length-1].virada));
t("cartas de baixo estão viradas p/ baixo", e.colunas[6].slice(0,-1).every(c => !c.virada));

// fundação: só aceita Ás vazia
const fund = { "♠":[], "♥":[], "♦":[], "♣":[] };
t("fundação vazia aceita Ás", podeNaFundacao(fund, {v:"A",n:"♠"}));
t("fundação vazia recusa 2", !podeNaFundacao(fund, {v:"2",n:"♠"}));
fund["♠"].push({v:"A",n:"♠"});
t("fundação com Ás aceita 2 do mesmo naipe", podeNaFundacao(fund, {v:"2",n:"♠"}));
t("fundação recusa 2 de naipe diferente", !podeNaFundacao(fund, {v:"2",n:"♥"}));

// coluna: cor alternada decrescente
t("coluna vazia só aceita Rei", podeNaColuna([], {v:"K",n:"♠"}));
t("coluna vazia recusa Dama", !podeNaColuna([], {v:"Q",n:"♠"}));
t("sobre 7♥(vermelho) aceita 6♠(preto)", podeNaColuna([{v:"7",n:"♥",virada:true}], {v:"6",n:"♠"}));
t("sobre 7♥ recusa 6♦ (mesma cor)", !podeNaColuna([{v:"7",n:"♥",virada:true}], {v:"6",n:"♦"}));
t("sobre 7♥ recusa 5♠ (não consecutivo)", !podeNaColuna([{v:"7",n:"♥",virada:true}], {v:"5",n:"♠"}));

// vitória
const cheio = { fundacoes: { "♠":Array(13), "♥":Array(13), "♦":Array(13), "♣":Array(13) } };
t("52 nas fundações = vitória", venceu(cheio));

console.log(`\n═══ PACIÊNCIA: ${ok} passaram, ${fail} falharam ═══`);
