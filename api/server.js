// ============================================================
// API — Plataforma de Acompanhamento de Idosos em ILPIs (PE)
//
// A peça central é a integração com o Row-Level Security:
// a API conecta ao PostgreSQL como o papel `app_user` e, a cada
// requisição, abre uma transação e executa
//     SET LOCAL app.id_usuario = '<id do usuário do token>'
// A partir daí, TODA consulta já vem filtrada pelo banco.
// A API não escreve um único WHERE de permissão: quem decide
// o que cada perfil enxerga são as políticas de RLS.
// ============================================================

import express from "express";
import cors from "cors";
import jwt from "jsonwebtoken";
import pg from "pg";
import PDFDocument from "pdfkit";
import { CONSULTAS, GRUPOS } from "./consultas.js";
import { DASHBOARD, MEDIDAS } from "./dashboard.js";

const { Pool } = pg;

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || "troque-isto-em-producao";
if (process.env.NODE_ENV === "production" && JWT_SECRET === "troque-isto-em-producao") {
  console.error("ERRO: em produção, defina JWT_SECRET por variável de ambiente. Encerrando.");
  process.exit(1);
}
if (JWT_SECRET === "troque-isto-em-producao")
  console.warn("⚠ AVISO: JWT_SECRET padrão em uso. Antes de uso real, defina a variável de ambiente JWT_SECRET com um valor longo e aleatório.");

// Limite de tentativas de login: 10 por identidade a cada 15 minutos (em memória)
const tentativasLogin = new Map();
function loginPermitido(chave) {
  const agora = Date.now();
  const reg = tentativasLogin.get(chave) || { n: 0, ate: agora + 15 * 60_000 };
  if (agora > reg.ate) { reg.n = 0; reg.ate = agora + 15 * 60_000; }
  reg.n += 1;
  tentativasLogin.set(chave, reg);
  return reg.n <= 10;
}

const pool = new Pool({
  host: process.env.PGHOST || "localhost",
  database: process.env.PGDATABASE || "ilpi",
  user: process.env.PGUSER || "app_user",
  password: process.env.PGPASSWORD || "app_secret_dev",
  port: process.env.PGPORT ? Number(process.env.PGPORT) : 5432,
  max: 10,
  // Bancos na nuvem (Neon, Supabase, Render) exigem SSL. Local não usa.
  // Defina PGSSL=true no ambiente de produção para ativar.
  ssl: process.env.PGSSL === "true" ? { rejectUnauthorized: false } : false,
});

const app = express();
app.disable("x-powered-by");
app.use((req, res, next) => {
  res.set({ "X-Content-Type-Options": "nosniff", "X-Frame-Options": "DENY", "Referrer-Policy": "no-referrer" });
  next();
});
app.use(cors());

// Endpoint de saúde: confirma que a API está no ar (usado no deploy e monitoramento)
app.get("/health", async (req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ status: "ok", banco: "conectado" });
  } catch (e) {
    res.status(503).json({ status: "erro", banco: "sem conexão" });
  }
});
app.use(express.json());

// ---------- Helper: executar consultas "como" o usuário logado ----------
// set_config(..., true) equivale a SET LOCAL: vale só até o fim da
// transação. Essencial com pool de conexões — a identidade nunca
// "vaza" de uma requisição para outra.
const FUSO = process.env.APP_TZ || "America/Recife";

async function comUsuario(idUsuario, fn) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    // Identidade + fuso das ILPIs (horários de medicação são hora local de PE).
    // Ambos com escopo da transação: funciona com pool e com PgBouncer (Neon).
    await client.query("SELECT set_config('app.id_usuario', $1, true), set_config('TimeZone', $2, true)",
      [String(idUsuario), FUSO]);
    const resultado = await fn(client);
    await client.query("COMMIT");
    return resultado;
  } catch (erro) {
    await client.query("ROLLBACK");
    throw erro;
  } finally {
    client.release();
  }
}

// Coleta as mensagens RAISE NOTICE que um procedimento emite durante fn()
// (o driver pg entrega cada uma como um evento "notice" da conexão).
async function comAvisos(client, fn) {
  const avisos = [];
  const ouvir = (msg) => avisos.push(msg.message);
  client.on("notice", ouvir);
  try { await fn(); } finally { client.removeListener("notice", ouvir); }
  return avisos;
}

// ---------- Middleware de autenticação ----------
function autenticar(req, res, next) {
  const cabecalho = req.headers.authorization || "";
  const token = cabecalho.startsWith("Bearer ") ? cabecalho.slice(7) : null;
  if (!token) return res.status(401).json({ erro: "Token não informado. Faça login em POST /auth/login." });
  try {
    req.usuario = jwt.verify(token, JWT_SECRET); // { id_usuario, perfil }
    next();
  } catch {
    return res.status(401).json({ erro: "Token inválido ou expirado." });
  }
}

// Auditoria: feita por TRIGGERS no banco (fn_trigger_auditoria).
// A trilha existe mesmo que a escrita não passe por esta API.

// ============================================================
// ROTAS
// ============================================================

// ---------- Login ----------
// A verificação da senha acontece DENTRO do banco, via pgcrypto:
// crypt(senha_digitada, hash_armazenado) só bate se a senha confere.
app.post("/auth/login", async (req, res) => {
  const { email, senha } = req.body || {};
  if (!email || !senha) return res.status(400).json({ erro: "Informe email e senha." });
  if (!loginPermitido(`${req.ip}|${email}`))
    return res.status(429).json({ erro: "Muitas tentativas. Aguarde 15 minutos e tente de novo." });
  try {
    // fn_autenticar roda como dono da tabela: a aplicação não tem
    // permissão de ler senha_hash (RLS + privilégio por coluna).
    const { rows } = await pool.query(
      "SELECT id_usuario, perfil, funcao FROM fn_autenticar($1, $2)",
      [email, senha]
    );
    if (rows.length === 0) return res.status(401).json({ erro: "Email ou senha incorretos." });
    const { id_usuario, perfil, funcao } = rows[0];
    const token = jwt.sign({ id_usuario, perfil }, JWT_SECRET, { expiresIn: "8h" });
    res.json({ token, perfil, funcao });
  } catch (e) {
    console.error(e);
    res.status(500).json({ erro: "Falha ao autenticar." });
  }
});

// ---------- Painel ----------
// Mesma rota para todos os perfis: o RLS decide o recorte.
// Responsável vê seus idosos; equipe vê a ILPI; idoso vê a si.
app.get("/painel", autenticar, async (req, res) => {
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `SELECT id_idoso, nome, grau_dependencia, ilpi, idade,
                ultimo_humor, ultimo_conforto, ultima_dor, ultimo_checkin,
                ultima_avaliacao, ultima_pontuacao, data_ultima_avaliacao,
                pet, nivel_pet, pontos_pet, atividades_30d
           FROM vw_painel_idoso
          ORDER BY nome`);
      return rows;
    });
    res.json(linhas);
  } catch (e) {
    console.error(e);
    res.status(500).json({ erro: "Falha ao carregar o painel." });
  }
});

// ---------- Check-in de bem-estar ----------
// Idoso registra o próprio (id_profissional fica nulo) e o pet
// ganha pontos na MESMA transação: ou grava tudo, ou nada.
app.post("/checkins", autenticar, async (req, res) => {
  const { id_idoso, humor, conforto, dor, observacoes } = req.body || {};
  if (![id_idoso, humor, conforto, dor].every((v) => Number.isInteger(v)))
    return res.status(400).json({ erro: "Campos obrigatórios: id_idoso, humor (1-5), conforto (1-5), dor (0-10)." });
  try {
    const resultado = await comUsuario(req.usuario.id_usuario, async (c) => {
      const ehIdoso = req.usuario.perfil === "idoso";
      const { rows: prof } = ehIdoso
        ? { rows: [{ id: null }] }
        : await c.query("SELECT fn_meu_id_profissional() AS id");
      const { rows } = await c.query(
        `INSERT INTO registro_bem_estar (id_idoso, id_profissional, humor, conforto, dor, observacoes)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING id_registro`,
        [id_idoso, prof[0].id, humor, conforto, dor, observacoes || null]
      );
      // pontos para o pet (vale também quando a equipe registra pelo idoso)
      const { rows: ganho } = await c.query(
        "SELECT pet, pontos, nivel, subiu_nivel FROM fn_pontuar_pet($1, 'checkin_bem_estar', 10)", [id_idoso]);
      return { id_registro: rows[0].id_registro, pontos_pet: ganho.length ? 10 : 0, pet: ganho[0] || null };
    });
    res.status(201).json(resultado);
  } catch (e) {
    // 42501 = violação de política RLS: usuário tentou algo fora do seu recorte
    if (e.code === "42501" || e.message.includes("row-level security"))
      return res.status(403).json({ erro: "Você não tem permissão para registrar por este idoso." });
    console.error(e);
    res.status(500).json({ erro: "Falha ao registrar o check-in." });
  }
});

// ---------- Partida de dominó ----------
// Grava a partida + eventos dos pets dos DOIS jogadores numa
// transação só. jogador2 nulo = partida contra o Seu Biu.
app.post("/partidas", autenticar, async (req, res) => {
  const { id_jogador2, vencedor, motivo } = req.body || {};
  if (![1, 2].includes(vencedor) || !["bateu", "fechado", "abandono"].includes(motivo))
    return res.status(400).json({ erro: "Informe vencedor (1 ou 2) e motivo (bateu | fechado | abandono)." });
  try {
    const resultado = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows: eu } = await c.query("SELECT fn_meu_id_idoso() AS id, fn_ilpi_do_idoso(fn_meu_id_idoso()) AS ilpi");
      if (!eu[0].id) throw Object.assign(new Error("Apenas idosos registram partidas neste endpoint."), { status: 403 });

      const { rows: partida } = await c.query(
        `INSERT INTO partida_domino (id_ilpi, id_jogador1, id_jogador2, vencedor, motivo)
         VALUES ($1, $2, $3, $4, $5) RETURNING id_partida`,
        [eu[0].ilpi, eu[0].id, id_jogador2 || null, vencedor, motivo]
      );

      const jogadores = [
        { id_idoso: eu[0].id, pontos: vencedor === 1 ? 40 : 10 },
        ...(id_jogador2 ? [{ id_idoso: id_jogador2, pontos: vencedor === 2 ? 40 : 10 }] : []),
      ];
      const ganhos = [];
      for (const j of jogadores) {
        const { rows: g } = await c.query(
          "SELECT pet, nivel, subiu_nivel FROM fn_pontuar_pet($1, 'partida_domino', $2)", [j.id_idoso, j.pontos]);
        if (g.length) ganhos.push({ pet: g[0].pet, pontos: j.pontos, nivel: g[0].nivel, subiu_nivel: g[0].subiu_nivel });
      }
      return { id_partida: partida[0].id_partida, ganhos };
    });
    res.status(201).json(resultado);
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    if (e.code === "42501" || e.message.includes("row-level security"))
      return res.status(403).json({ erro: "Partida fora do seu recorte de permissão." });
    console.error(e);
    res.status(500).json({ erro: "Falha ao registrar a partida." });
  }
});

// ---------- Outros jogos (Memória, Buraco, Paciência, Cuidar do Xodó) ----------
const JOGOS = ["memoria", "buraco", "paciencia", "cuidar_xodo"];
const PONTOS_RESULTADO = { vitoria: 30, concluido: 30, derrota: 10, abandono: 0 };
app.post("/jogos", autenticar, async (req, res) => {
  const { jogo, resultado, pontuacao, jogadas } = req.body || {};
  if (!JOGOS.includes(jogo) || !(resultado in PONTOS_RESULTADO))
    return res.status(400).json({ erro: `Informe jogo (${JOGOS.join(" | ")}) e resultado (vitoria | derrota | concluido | abandono).` });
  const inteiroOuNulo = (v) => (Number.isInteger(v) && v >= 0 ? v : null);
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows: eu } = await c.query("SELECT fn_meu_id_idoso() AS id");
      if (!eu[0].id) throw Object.assign(new Error("Apenas idosos registram partidas."), { status: 403 });
      const { rows } = await c.query(
        `INSERT INTO partida_jogo (id_idoso, jogo, resultado, pontuacao, jogadas)
         VALUES ($1, $2, $3, $4, $5) RETURNING id_partida_jogo`,
        [eu[0].id, jogo, resultado, inteiroOuNulo(pontuacao), inteiroOuNulo(jogadas)]);
      const pontos = PONTOS_RESULTADO[resultado];
      let ganho = null;
      if (pontos > 0) {
        const { rows: g } = await c.query(
          "SELECT pet, pontos, nivel, subiu_nivel FROM fn_pontuar_pet($1, 'partida_jogo', $2)", [eu[0].id, pontos]);
        if (g.length) ganho = { ...g[0], pontos_ganhos: pontos };
      }
      return { id_partida_jogo: rows[0].id_partida_jogo, ganho };
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    console.error(e); res.status(500).json({ erro: "Falha ao registrar a partida." });
  }
});

// ---------- Histórico de bem-estar ----------
// Últimos 30 registros de um idoso. O RLS decide o recorte:
// consultar um idoso fora dele simplesmente retorna vazio.
app.get("/idosos/:id/bem-estar", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `SELECT data_hora, humor, conforto, dor, observacoes
           FROM registro_bem_estar
          WHERE id_idoso = $1
          ORDER BY data_hora DESC
          LIMIT 30`,
        [id]
      );
      return rows;
    });
    res.json(linhas.reverse()); // ordem cronológica, pronto para gráfico
  } catch (e) {
    console.error(e);
    res.status(500).json({ erro: "Falha ao carregar o histórico." });
  }
});

// ---------- Avaliações clínicas padronizadas ----------
// Lançamento pela equipe (Katz, Lawton, GDS-15, WHOQOL-OLD, ICOPE).
// O RLS exige que o profissional seja da ILPI do idoso.
app.post("/avaliacoes", autenticar, async (req, res) => {
  const { id_idoso, instrumento, pontuacao_total, observacoes } = req.body || {};
  const INSTRUMENTOS = ["KATZ", "LAWTON", "GDS15", "WHOQOL_OLD", "ICOPE"];
  if (!Number.isInteger(id_idoso) || !INSTRUMENTOS.includes(instrumento))
    return res.status(400).json({ erro: `Informe id_idoso e instrumento (${INSTRUMENTOS.join(", ")}).` });
  try {
    const resultado = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO avaliacao (id_idoso, id_profissional, instrumento, pontuacao_total, observacoes)
         VALUES ($1, fn_meu_id_profissional(), $2, $3, $4) RETURNING id_avaliacao`,
        [id_idoso, instrumento, Number.isInteger(pontuacao_total) ? pontuacao_total : null, observacoes || null]
      );
      return rows[0];
    });
    res.status(201).json(resultado);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Você não pode lançar avaliações para este idoso." });
    console.error(e);
    res.status(500).json({ erro: "Falha ao lançar a avaliação." });
  }
});

app.get("/idosos/:id/avaliacoes", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `SELECT a.id_avaliacao, a.instrumento, a.pontuacao_total, a.observacoes, a.data_hora, p.nome AS profissional
           FROM avaliacao a JOIN profissional p USING (id_profissional)
          WHERE a.id_idoso = $1
          ORDER BY a.data_hora DESC LIMIT 20`,
        [id]
      );
      return rows;
    });
    res.json(linhas);
  } catch (e) {
    console.error(e);
    res.status(500).json({ erro: "Falha ao carregar as avaliações." });
  }
});

// ---------- Evolução psicológica (sigilo profissional) ----------
// O RLS garante: apenas psicólogos da ILPI do idoso leem ou gravam.
// Para qualquer outro perfil, a lista volta vazia e a gravação dá 403.
app.post("/atendimentos-psicologicos", autenticar, async (req, res) => {
  const { id_idoso, evolucao } = req.body || {};
  if (!Number.isInteger(id_idoso) || !evolucao || !evolucao.trim())
    return res.status(400).json({ erro: "Informe id_idoso e o texto da evolução." });
  try {
    const resultado = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO atendimento_psicologico (id_idoso, id_profissional, evolucao)
         VALUES ($1, fn_meu_id_profissional(), $2) RETURNING id_atendimento`,
        [id_idoso, evolucao.trim()]
      );
      return rows[0];
    });
    res.status(201).json(resultado);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Somente psicólogos da ILPI do idoso registram evoluções." });
    console.error(e);
    res.status(500).json({ erro: "Falha ao registrar o atendimento." });
  }
});

app.get("/idosos/:id/atendimentos-psicologicos", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `SELECT id_atendimento, evolucao, data_hora
           FROM atendimento_psicologico
          WHERE id_idoso = $1
          ORDER BY data_hora DESC LIMIT 20`,
        [id]
      );
      return rows;
    });
    res.json(linhas);
  } catch (e) {
    console.error(e);
    res.status(500).json({ erro: "Falha ao carregar os atendimentos." });
  }
});

// ---------- Meu pet ----------
// O pet do idoso logado + extrato dos últimos pontos ganhos.
// Escopado no banco por fn_meu_id_idoso(): cada um só vê o seu.
app.get("/meu-pet", autenticar, async (req, res) => {
  try {
    const resultado = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows: pet } = await c.query(
        `SELECT id_pet, nome, especie, nivel, pontos, acessorio, cor, fase
           FROM vw_pet_completo WHERE id_idoso = fn_meu_id_idoso()`
      );
      if (!pet.length) return null;
      const { rows: eventos } = await c.query(
        `SELECT origem, pontos_ganhos, data_hora
           FROM evento_pet WHERE id_pet = $1
          ORDER BY data_hora DESC LIMIT 12`,
        [pet[0].id_pet]
      );
      return { ...pet[0], eventos };
    });
    if (!resultado) return res.status(404).json({ erro: "Você ainda não tem um bichinho." });
    res.json(resultado);
  } catch (e) {
    console.error(e);
    res.status(500).json({ erro: "Falha ao carregar o pet." });
  }
});

// ============================================================
// AGENDA DE ATIVIDADES
// ============================================================
// Próximas atividades da ILPI (e se o idoso logado já confirmou).
app.get("/atividades", autenticar, async (req, res) => {
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(`
        SELECT a.id_atividade, a.nome, a.categoria, a.data_hora,
               (SELECT count(*)::int FROM participacao p WHERE p.id_atividade = a.id_atividade) AS confirmados,
               EXISTS (SELECT 1 FROM participacao p
                        WHERE p.id_atividade = a.id_atividade AND p.id_idoso = fn_meu_id_idoso()) AS eu_confirmei
          FROM atividade_lazer a
         WHERE a.data_hora >= now() - INTERVAL '12 hours'
         ORDER BY a.data_hora
         LIMIT 40`);
      return rows;
    });
    res.json(linhas);
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao carregar a agenda." }); }
});

// Criar atividade (equipe)
app.post("/atividades", autenticar, async (req, res) => {
  const { nome, categoria, data_hora } = req.body || {};
  const CATS = ["fisica", "social", "cognitiva", "artistica", "espiritual"];
  if (!nome || !CATS.includes(categoria) || !data_hora)
    return res.status(400).json({ erro: `Informe nome, categoria (${CATS.join(", ")}) e data_hora.` });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO atividade_lazer (id_ilpi, nome, categoria, data_hora)
         VALUES (fn_minha_ilpi_profissional(), $1, $2, $3) RETURNING id_atividade`,
        [nome, categoria, data_hora]);
      return rows[0];
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Só a equipe da ILPI cria atividades." });
    console.error(e); res.status(500).json({ erro: "Falha ao criar a atividade." });
  }
});

// Confirmar presença (idoso na própria; equipe por um residente)
app.post("/atividades/:id/confirmar", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  const { id_idoso, nivel_engajamento } = req.body || {};
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      // idoso confirma a si; equipe informa id_idoso
      const alvo = req.usuario.perfil === "idoso"
        ? (await c.query("SELECT fn_meu_id_idoso() AS id")).rows[0].id
        : id_idoso;
      if (!alvo) throw Object.assign(new Error("Informe o residente."), { status: 400 });
      // xmax = 0 => a linha foi inserida agora (e não atualizada pelo ON CONFLICT)
      const { rows: ins } = await c.query(
        `INSERT INTO participacao (id_idoso, id_atividade, nivel_engajamento)
         VALUES ($1, $2, $3)
         ON CONFLICT (id_idoso, id_atividade) DO UPDATE SET nivel_engajamento = EXCLUDED.nivel_engajamento
         RETURNING (xmax = 0) AS nova`,
        [alvo, id, Number.isInteger(nivel_engajamento) ? nivel_engajamento : 4]);
      // pontos para o pet (participação = +30), só na primeira confirmação
      let pontos = 0;
      if (ins[0].nova) {
        const { rows: g } = await c.query(
          "SELECT pet FROM fn_pontuar_pet($1, 'participacao_atividade', 30)", [alvo]);
        if (g.length) pontos = 30;
      }
      return { pontos_pet: pontos };
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Você não pode confirmar por este residente." });
    console.error(e); res.status(500).json({ erro: "Falha ao confirmar presença." });
  }
});

// Editar atividade da agenda (equipe da ILPI)
app.patch("/atividades/:id", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  const { nome, categoria, data_hora } = req.body || {};
  const CATS = ["fisica", "social", "cognitiva", "artistica", "espiritual"];
  if (!Number.isInteger(id) || (categoria !== undefined && !CATS.includes(categoria)) || (nome !== undefined && !String(nome).trim()))
    return res.status(400).json({ erro: `Informe nome, categoria (${CATS.join(", ")}) e/ou data_hora.` });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `UPDATE atividade_lazer SET
           nome      = COALESCE($2, nome),
           categoria = COALESCE($3::categoria_atividade, categoria),
           data_hora = COALESCE($4::timestamptz, data_hora)
         WHERE id_atividade = $1
         RETURNING id_atividade`,
        [id, nome ? String(nome).trim().slice(0, 120) : null, categoria || null, data_hora || null]);
      return rows[0] || null;
    });
    if (!r) return res.status(404).json({ erro: "Atividade não encontrada na sua ILPI." });
    res.json(r);
  } catch (e) {
    if (e.code === "22007" || e.code === "22008") return res.status(400).json({ erro: "Data/hora inválida." });
    console.error(e); res.status(500).json({ erro: "Falha ao editar a atividade." });
  }
});

// Excluir atividade (equipe da ILPI). Só se ninguém confirmou presença:
// a presença já deu pontos ao Xodó e faz parte do histórico do residente.
app.delete("/atividades/:id", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows: p } = await c.query("SELECT count(*)::int AS n FROM participacao WHERE id_atividade = $1", [id]);
      if (p[0].n > 0)
        throw Object.assign(new Error(`Esta atividade já tem ${p[0].n} presença(s) confirmada(s) e fica no histórico. Edite em vez de excluir.`), { status: 409 });
      const { rows } = await c.query("DELETE FROM atividade_lazer WHERE id_atividade = $1 RETURNING id_atividade", [id]);
      return rows[0] || null;
    });
    if (!r) return res.status(404).json({ erro: "Atividade não encontrada na sua ILPI." });
    res.json({ ok: true });
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    console.error(e); res.status(500).json({ erro: "Falha ao excluir a atividade." });
  }
});

// ============================================================
// PASSAGEM DE PLANTÃO (comunicação interna da equipe)
// ============================================================
// Lista recados recentes, com quem já deu ciência e o nome do autor.
app.get("/plantao", autenticar, async (req, res) => {
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(`
        SELECT r.id_recado, r.turno, r.prioridade, r.texto, r.resolvido, r.data_hora,
               pr.nome AS autor, i.nome AS idoso,
               (r.id_profissional = fn_meu_id_profissional()) AS meu,
               (SELECT count(*)::int FROM ciencia_plantao cp WHERE cp.id_recado = r.id_recado) AS ciencias,
               EXISTS (SELECT 1 FROM ciencia_plantao cp
                        WHERE cp.id_recado = r.id_recado AND cp.id_profissional = fn_meu_id_profissional()) AS eu_ciente
          FROM recado_plantao r
          JOIN profissional pr ON pr.id_profissional = r.id_profissional
          LEFT JOIN idoso i ON i.id_idoso = r.id_idoso
         WHERE r.id_ilpi = fn_minha_ilpi_profissional()
           AND (NOT r.resolvido OR r.data_hora > now() - INTERVAL '2 days')
         ORDER BY r.resolvido, 
                  CASE r.prioridade WHEN 'urgente' THEN 0 WHEN 'atencao' THEN 1 ELSE 2 END,
                  r.data_hora DESC
         LIMIT 60`);
      return rows;
    });
    res.json(linhas);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "A passagem de plantão é só para a equipe da ILPI." });
    console.error(e); res.status(500).json({ erro: "Falha ao carregar o plantão." });
  }
});

// Novo recado de plantão
app.post("/plantao", autenticar, async (req, res) => {
  const { turno, prioridade, texto, id_idoso } = req.body || {};
  const TURNOS = ["manha", "tarde", "noite"], PRIOS = ["rotina", "atencao", "urgente"];
  if (!TURNOS.includes(turno) || !PRIOS.includes(prioridade || "rotina") || !texto || !texto.trim())
    return res.status(400).json({ erro: "Informe turno, prioridade e texto." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO recado_plantao (id_ilpi, id_profissional, id_idoso, turno, prioridade, texto)
         VALUES (fn_minha_ilpi_profissional(), fn_meu_id_profissional(), $1, $2, $3, $4)
         RETURNING id_recado`,
        [Number.isInteger(id_idoso) ? id_idoso : null, turno, prioridade || "rotina", texto.trim().slice(0, 1000)]);
      return rows[0];
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Só a equipe da ILPI escreve na passagem de plantão." });
    console.error(e); res.status(500).json({ erro: "Falha ao registrar o recado." });
  }
});

// Dar ciência (li e estou a par)
app.post("/plantao/:id/ciencia", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    await comUsuario(req.usuario.id_usuario, async (c) => {
      await c.query(
        `INSERT INTO ciencia_plantao (id_recado, id_profissional)
         VALUES ($1, fn_meu_id_profissional()) ON CONFLICT DO NOTHING`, [id]);
    });
    res.status(201).json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao dar ciência." }); }
});

// Marcar resolvido / reabrir
app.post("/plantao/:id/resolvido", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  const { resolvido } = req.body || {};
  if (!Number.isInteger(id) || typeof resolvido !== "boolean")
    return res.status(400).json({ erro: "Informe resolvido (true/false)." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        "UPDATE recado_plantao SET resolvido = $2 WHERE id_recado = $1 RETURNING id_recado", [id, resolvido]);
      return rows[0] || null;
    });
    if (!r) return res.status(404).json({ erro: "Recado não encontrado na sua ILPI." });
    res.json({ id_recado: id, resolvido });
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao atualizar." }); }
});

// Editar recado (só quem escreveu): texto e prioridade
app.patch("/plantao/:id", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  const { texto, prioridade } = req.body || {};
  const PRIOS = ["rotina", "atencao", "urgente"];
  if (!Number.isInteger(id) || (texto !== undefined && !String(texto).trim()) || (prioridade !== undefined && !PRIOS.includes(prioridade)))
    return res.status(400).json({ erro: "Informe o texto e/ou a prioridade (rotina, atencao, urgente)." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `UPDATE recado_plantao SET
           texto      = COALESCE($2, texto),
           prioridade = COALESCE($3::prioridade_plantao, prioridade)
         WHERE id_recado = $1 AND id_profissional = fn_meu_id_profissional()
         RETURNING id_recado`,
        [id, texto ? String(texto).trim().slice(0, 1000) : null, prioridade || null]);
      return rows[0] || null;
    });
    if (!r) return res.status(404).json({ erro: "Recado não encontrado, ou não foi você quem escreveu." });
    res.json(r);
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao editar o recado." }); }
});

// Excluir recado (quem escreveu ou o gestor; o RLS confere). As ciências
// saem junto (ON DELETE CASCADE).
app.delete("/plantao/:id", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query("DELETE FROM recado_plantao WHERE id_recado = $1 RETURNING id_recado", [id]);
      return rows[0] || null;
    });
    if (!r) return res.status(404).json({ erro: "Recado não encontrado, ou não foi você quem escreveu." });
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao excluir o recado." }); }
});

// ============================================================
// ESCALAS GUIADAS (GDS-15, Katz) — cálculo no servidor
// ============================================================
const ESCALAS = {
  GDS15: { interpretar: (t) => t <= 4 ? "Normal" : t <= 9 ? "Sugestivo de depressão leve" : "Sugestivo de depressão grave" },
  KATZ: { interpretar: (t) => t >= 5 ? "Independente" : t >= 3 ? "Dependência parcial" : "Dependência importante" },
  LAWTON: { interpretar: (t) => t >= 21 ? "Independente" : t >= 16 ? "Dependência parcial" : "Dependência importante" },
};

app.post("/escalas", autenticar, async (req, res) => {
  const { id_idoso, instrumento, itens } = req.body || {};
  if (!Number.isInteger(id_idoso) || !ESCALAS[instrumento] || !Array.isArray(itens) || itens.length === 0)
    return res.status(400).json({ erro: "Informe id_idoso, instrumento (GDS15, KATZ, LAWTON) e itens." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const total = itens.reduce((sum, it) => sum + (Number(it.pontuacao) || 0), 0);
      const interpretacao = ESCALAS[instrumento].interpretar(total);
      const { rows } = await c.query(
        `INSERT INTO avaliacao (id_idoso, id_profissional, instrumento, pontuacao_total, interpretacao)
         VALUES ($1, fn_meu_id_profissional(), $2, $3, $4) RETURNING id_avaliacao`,
        [id_idoso, instrumento, total, interpretacao]);
      const idAval = rows[0].id_avaliacao;
      for (const it of itens)
        await c.query(
          `INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES ($1, $2, $3, $4)`,
          [idAval, String(it.dominio).slice(0, 60), String(it.resposta).slice(0, 200), Number(it.pontuacao) || 0]);
      return { id_avaliacao: idAval, pontuacao_total: total, interpretacao };
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Só a equipe da ILPI aplica escalas." });
    console.error(e); res.status(500).json({ erro: "Falha ao registrar a escala." });
  }
});

app.get("/avaliacoes/:id/itens", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const d = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows: av } = await c.query(
        `SELECT a.instrumento, a.pontuacao_total, a.interpretacao, a.data_hora, p.nome AS profissional
           FROM avaliacao a JOIN profissional p USING (id_profissional) WHERE a.id_avaliacao = $1`, [id]);
      if (!av.length) return null;
      const { rows: itens } = await c.query(
        `SELECT dominio, resposta, pontuacao FROM item_avaliacao WHERE id_avaliacao = $1 ORDER BY id_item`, [id]);
      return { ...av[0], itens };
    });
    if (!d) return res.status(404).json({ erro: "Avaliação não encontrada." });
    res.json(d);
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao carregar." }); }
});

// ============================================================
// SINAIS VITAIS
// ============================================================
// Faixas de referência (adulto idoso) para sinalizar fora do normal.
// Não é diagnóstico — é um alerta visual para a equipe conferir.
const FAIXAS = {
  pressao_sis: [90, 140], pressao_dia: [60, 90], freq_cardiaca: [50, 100],
  temperatura: [35.5, 37.5], glicemia: [70, 140], saturacao: [94, 100],
};

app.get("/idosos/:id/sinais", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `SELECT id_sinal, data_hora, pressao_sis, pressao_dia, freq_cardiaca,
                temperatura, peso_kg, glicemia, saturacao, observacoes,
                fn_classificar_pressao(pressao_sis, pressao_dia) AS classificacao_pa   -- FUNÇÃO da Etapa 05
           FROM sinal_vital WHERE id_idoso = $1 ORDER BY data_hora DESC LIMIT 60`, [id]);
      return rows;
    });
    res.json({ faixas: FAIXAS, registros: linhas.reverse() });
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao carregar os sinais." }); }
});

app.post("/sinais", autenticar, async (req, res) => {
  const b = req.body || {};
  const campos = ["pressao_sis", "pressao_dia", "freq_cardiaca", "temperatura", "peso_kg", "glicemia", "saturacao"];
  const informados = campos.filter((k) => b[k] !== undefined && b[k] !== null && b[k] !== "");
  if (!Number.isInteger(b.id_idoso) || informados.length === 0)
    return res.status(400).json({ erro: "Informe id_idoso e ao menos uma medida." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO sinal_vital
           (id_idoso, id_profissional, pressao_sis, pressao_dia, freq_cardiaca, temperatura, peso_kg, glicemia, saturacao, observacoes)
         VALUES ($1, fn_meu_id_profissional(), $2,$3,$4,$5,$6,$7,$8,$9) RETURNING id_sinal`,
        [b.id_idoso,
         b.pressao_sis || null, b.pressao_dia || null, b.freq_cardiaca || null,
         b.temperatura || null, b.peso_kg || null, b.glicemia || null, b.saturacao || null,
         b.observacoes || null]);
      return rows[0];
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Só a equipe da ILPI registra sinais vitais." });
    if (e.code === "23514") return res.status(400).json({ erro: "Algum valor está fora da faixa fisiológica possível. Confira a medida." });
    console.error(e); res.status(500).json({ erro: "Falha ao registrar os sinais." });
  }
});

// ============================================================
// PLANO DE CUIDADO INDIVIDUAL (metas)
// ============================================================
app.get("/idosos/:id/metas", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `SELECT m.id_meta, m.categoria, m.descricao, m.status, m.data_criacao, m.data_revisao, m.data_conclusao,
                pr.nome AS autor,
                (SELECT count(*)::int FROM evolucao_meta e WHERE e.id_meta = m.id_meta) AS evolucoes
           FROM meta_cuidado m JOIN profissional pr ON pr.id_profissional = m.id_profissional
          WHERE m.id_idoso = $1
          ORDER BY (m.status = 'ativa') DESC, m.data_criacao DESC`, [id]);
      return rows;
    });
    res.json(linhas);
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao carregar o plano." }); }
});

app.post("/metas", autenticar, async (req, res) => {
  const { id_idoso, categoria, descricao, data_revisao } = req.body || {};
  const CATS = ["saude", "mobilidade", "nutricao", "social", "cognitiva", "emocional", "autonomia"];
  if (!Number.isInteger(id_idoso) || !CATS.includes(categoria) || !descricao || !descricao.trim())
    return res.status(400).json({ erro: "Informe id_idoso, categoria e descrição." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO meta_cuidado (id_idoso, id_profissional, categoria, descricao, data_revisao)
         VALUES ($1, fn_meu_id_profissional(), $2, $3, $4) RETURNING id_meta`,
        [id_idoso, categoria, descricao.trim().slice(0, 300), data_revisao || null]);
      return rows[0];
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Só a equipe da ILPI define metas de cuidado." });
    console.error(e); res.status(500).json({ erro: "Falha ao criar a meta." });
  }
});

app.post("/metas/:id/status", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  const { status } = req.body || {};
  if (!Number.isInteger(id) || !["ativa", "atingida", "suspensa"].includes(status))
    return res.status(400).json({ erro: "Informe status (ativa, atingida, suspensa)." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `UPDATE meta_cuidado SET status = $2::status_meta,
           data_conclusao = CASE WHEN $2::status_meta = 'atingida' THEN CURRENT_DATE ELSE NULL END
         WHERE id_meta = $1 RETURNING id_meta`, [id, status]);
      return rows[0] || null;
    });
    if (!r) return res.status(404).json({ erro: "Meta não encontrada na sua ILPI." });
    res.json({ id_meta: id, status });
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao atualizar." }); }
});

app.post("/metas/:id/evolucao", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  const { nota } = req.body || {};
  if (!Number.isInteger(id) || !nota || !nota.trim())
    return res.status(400).json({ erro: "Escreva a nota de evolução." });
  try {
    await comUsuario(req.usuario.id_usuario, async (c) => {
      await c.query(
        `INSERT INTO evolucao_meta (id_meta, id_profissional, nota)
         VALUES ($1, fn_meu_id_profissional(), $2)`, [id, nota.trim().slice(0, 500)]);
    });
    res.status(201).json({ ok: true });
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Só a equipe registra evolução da meta." });
    console.error(e); res.status(500).json({ erro: "Falha ao registrar evolução." });
  }
});

// ============================================================
// INTERCORRÊNCIAS E QUEDAS
// ============================================================
app.get("/idosos/:id/intercorrencias", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `SELECT ic.id_intercorrencia, ic.tipo, ic.gravidade, ic.local_evento, ic.descricao,
                ic.conduta, ic.familia_avisada, ic.data_hora, pr.nome AS autor
           FROM intercorrencia ic JOIN profissional pr ON pr.id_profissional = ic.id_profissional
          WHERE ic.id_idoso = $1 ORDER BY ic.data_hora DESC LIMIT 50`, [id]);
      return rows;
    });
    res.json(linhas);
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao carregar as intercorrências." }); }
});

app.post("/intercorrencias", autenticar, async (req, res) => {
  const { id_idoso, tipo, gravidade, local_evento, descricao, conduta, familia_avisada } = req.body || {};
  const TIPOS = ["queda", "lesao", "mal_estar", "comportamento", "fuga", "obito", "outro"];
  const GRAVS = ["leve", "moderada", "grave"];
  if (!Number.isInteger(id_idoso) || !TIPOS.includes(tipo) || !GRAVS.includes(gravidade || "leve") || !descricao || !descricao.trim())
    return res.status(400).json({ erro: "Informe id_idoso, tipo, gravidade e descrição." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO intercorrencia (id_idoso, id_profissional, tipo, gravidade, local_evento, descricao, conduta, familia_avisada)
         VALUES ($1, fn_meu_id_profissional(), $2, $3, $4, $5, $6, $7) RETURNING id_intercorrencia`,
        [id_idoso, tipo, gravidade || "leve", (local_evento || "").slice(0, 80) || null,
         descricao.trim().slice(0, 500), (conduta || "").slice(0, 500) || null, !!familia_avisada]);
      return rows[0];
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Só a equipe da ILPI registra intercorrências." });
    console.error(e); res.status(500).json({ erro: "Falha ao registrar a intercorrência." });
  }
});

// ============================================================
// CONTROLE NUTRICIONAL
// ============================================================
// Restrições alimentares do idoso
app.get("/idosos/:id/restricoes", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        "SELECT id_restricao, descricao FROM restricao_alimentar WHERE id_idoso = $1 ORDER BY descricao", [id]);
      return rows;
    });
    res.json(linhas);
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao carregar as restrições." }); }
});

app.post("/restricoes", autenticar, async (req, res) => {
  const { id_idoso, descricao } = req.body || {};
  if (!Number.isInteger(id_idoso) || !descricao || !descricao.trim())
    return res.status(400).json({ erro: "Informe id_idoso e descrição." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO restricao_alimentar (id_idoso, descricao) VALUES ($1, $2)
         ON CONFLICT (id_idoso, descricao) DO NOTHING RETURNING id_restricao`,
        [id_idoso, descricao.trim().slice(0, 120)]);
      return rows[0] || { ja_existia: true };
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Só a equipe da ILPI gerencia restrições." });
    console.error(e); res.status(500).json({ erro: "Falha ao adicionar a restrição." });
  }
});

app.delete("/restricoes/:id", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const n = await comUsuario(req.usuario.id_usuario, async (c) =>
      (await c.query("DELETE FROM restricao_alimentar WHERE id_restricao = $1", [id])).rowCount);
    if (!n) return res.status(404).json({ erro: "Restrição não encontrada ou fora da sua ILPI." });
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao remover." }); }
});

app.patch("/restricoes/:id", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  const { descricao } = req.body || {};
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  if (!descricao || !descricao.trim()) return res.status(400).json({ erro: "Informe a nova descrição." });
  try {
    const n = await comUsuario(req.usuario.id_usuario, async (c) =>
      (await c.query("UPDATE restricao_alimentar SET descricao = $2 WHERE id_restricao = $1",
        [id, descricao.trim().slice(0, 120)])).rowCount);
    if (!n) return res.status(404).json({ erro: "Restrição não encontrada ou fora da sua ILPI." });
    res.json({ ok: true });
  } catch (e) {
    if (e.code === "23505") return res.status(409).json({ erro: "Este idoso já tem essa restrição." });
    console.error(e); res.status(500).json({ erro: "Falha ao editar a restrição." });
  }
});

// Registro de refeições (aceitação e hidratação)
app.get("/idosos/:id/refeicoes", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const d = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `SELECT id_refeicao, tipo, aceitacao, hidratacao_ml, observacoes, data_hora
           FROM registro_refeicao WHERE id_idoso = $1 ORDER BY data_hora DESC LIMIT 40`, [id]);
      // média de aceitação nos últimos 7 dias e hidratação de hoje
      const { rows: resumo } = await c.query(
        `SELECT round(avg(aceitacao))::int AS media_aceitacao_7d,
                coalesce(sum(hidratacao_ml) FILTER (WHERE data_hora >= CURRENT_DATE), 0)::int AS hidratacao_hoje
           FROM registro_refeicao
          WHERE id_idoso = $1 AND data_hora >= now() - INTERVAL '7 days'`, [id]);
      return { registros: rows, resumo: resumo[0] };
    });
    res.json(d);
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao carregar as refeições." }); }
});

app.post("/refeicoes", autenticar, async (req, res) => {
  const { id_idoso, tipo, aceitacao, hidratacao_ml, observacoes } = req.body || {};
  const TIPOS = ["cafe", "almoco", "lanche", "jantar", "ceia"];
  if (!Number.isInteger(id_idoso) || !TIPOS.includes(tipo) || !Number.isInteger(aceitacao) || aceitacao < 0 || aceitacao > 100)
    return res.status(400).json({ erro: "Informe id_idoso, tipo e aceitação (0 a 100)." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO registro_refeicao (id_idoso, id_profissional, tipo, aceitacao, hidratacao_ml, observacoes)
         VALUES ($1, fn_meu_id_profissional(), $2, $3, $4, $5) RETURNING id_refeicao`,
        [id_idoso, tipo, aceitacao, Number.isInteger(hidratacao_ml) ? hidratacao_ml : null, (observacoes || "").slice(0, 300) || null]);
      return rows[0];
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Só a equipe da ILPI registra refeições." });
    console.error(e); res.status(500).json({ erro: "Falha ao registrar a refeição." });
  }
});

// ============================================================
// PRONTUÁRIO UNIFICADO — linha do tempo de tudo do idoso
// ============================================================
// Reúne, em ordem cronológica, os eventos de cuidado do idoso:
// bem-estar, sinais vitais, avaliações, intercorrências, refeições,
// medicação, metas e atividades. Cada fonte vira um "evento" com
// tipo, data e um resumo. A visibilidade de cada fonte já é imposta
// pelo RLS na consulta correspondente; aqui juntamos o que a pessoa
// pode ver. Nota: atendimento psicológico NÃO entra (sigilo próprio).
app.get("/idosos/:id/prontuario", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  const desde = req.query.desde || null;
  try {
    const dados = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows: cab } = await c.query(
        `SELECT i.nome, i.data_nascimento, i.grau_dependencia,
                date_part('year', age(i.data_nascimento))::int AS idade
           FROM idoso i WHERE i.id_idoso = $1`, [id]);
      if (!cab.length) return null;

      const f = desde ? "AND data_hora >= $2" : "";
      const args = desde ? [id, desde] : [id];
      // Funções, não promessas: as consultas rodam uma de cada vez na mesma
      // conexão (dentro da transação). Erro não é mais engolido: antes, uma
      // consulta com coluna errada abortava a transação e as seguintes
      // voltavam vazias em silêncio.
      const consultas = [
        () => c.query(`SELECT 'bem_estar' AS tipo, data_hora, 'Check-in de bem-estar' AS titulo,
                    ('Humor ' || coalesce(humor::text,'-') || '/5 · conforto ' || coalesce(conforto::text,'-') || '/5' ||
                     CASE WHEN dor IS NOT NULL THEN ' · dor ' || dor || '/10' ELSE '' END) AS detalhe
                 FROM registro_bem_estar WHERE id_idoso = $1 ${f}`, args),
        () => c.query(`SELECT 'sinal_vital' AS tipo, data_hora, 'Sinais vitais' AS titulo,
                    concat_ws(' · ',
                      CASE WHEN pressao_sis IS NOT NULL THEN 'PA ' || pressao_sis || '/' || coalesce(pressao_dia::text,'?') END,
                      CASE WHEN freq_cardiaca IS NOT NULL THEN 'FC ' || freq_cardiaca END,
                      CASE WHEN temperatura IS NOT NULL THEN 'T ' || temperatura || '°C' END,
                      CASE WHEN peso_kg IS NOT NULL THEN peso_kg || 'kg' END,
                      CASE WHEN glicemia IS NOT NULL THEN 'Gli ' || glicemia END,
                      CASE WHEN saturacao IS NOT NULL THEN 'SpO2 ' || saturacao || '%' END) AS detalhe
                 FROM sinal_vital WHERE id_idoso = $1 ${f}`, args),
        () => c.query(`SELECT 'intercorrencia' AS tipo, data_hora,
                    ('Intercorrência: ' || tipo || ' (' || gravidade || ')') AS titulo, descricao AS detalhe
                 FROM intercorrencia WHERE id_idoso = $1 ${f}`, args),
        () => c.query(`SELECT 'refeicao' AS tipo, data_hora, ('Refeição: ' || tipo) AS titulo,
                    ('Aceitação ' || aceitacao || '%' || CASE WHEN hidratacao_ml IS NOT NULL THEN ' · ' || hidratacao_ml || 'ml' ELSE '' END) AS detalhe
                 FROM registro_refeicao WHERE id_idoso = $1 ${f}`, args),
        () => c.query(`SELECT 'avaliacao' AS tipo, data_hora, ('Escala: ' || instrumento) AS titulo,
                    (coalesce(pontuacao_total::text,'?') || ' pontos' || CASE WHEN interpretacao IS NOT NULL THEN ' — ' || interpretacao ELSE '' END) AS detalhe
                 FROM avaliacao WHERE id_idoso = $1 ${f}`, args),
        () => c.query(`SELECT 'medicacao' AS tipo, a.administrado_em AS data_hora, ('Medicação: ' || p.medicamento) AS titulo,
                    (p.dose || ' · dose das ' || to_char(a.horario_previsto, 'HH24:MI')) AS detalhe
                 FROM administracao_medicacao a JOIN prescricao p USING (id_prescricao)
                 WHERE p.id_idoso = $1 ${desde ? "AND a.administrado_em >= $2" : ""}`, args),
        () => c.query(`SELECT 'meta' AS tipo, data_criacao::timestamptz AS data_hora,
                    ('Meta de cuidado: ' || categoria) AS titulo, descricao AS detalhe
                 FROM meta_cuidado WHERE id_idoso = $1 ${desde ? "AND data_criacao >= $2::date" : ""}`, args),
      ];
      const resultados = [];
      for (const consulta of consultas) resultados.push(await consulta());
      let eventos = [];
      for (const r of resultados) eventos = eventos.concat(r.rows);
      eventos.sort((a, b) => new Date(b.data_hora) - new Date(a.data_hora));
      return { idoso: cab[0], eventos: eventos.slice(0, 200) };
    });
    if (!dados) return res.status(404).json({ erro: "Residente não encontrado." });
    res.json(dados);
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao montar o prontuário." }); }
});

// ---------- Resumo do dia (equipe) ----------
// Um retrato rápido da ILPI hoje: check-ins, doses, atividades, alertas.
app.get("/resumo-dia", autenticar, async (req, res) => {
  try {
    const d = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows: r } = await c.query(`
        WITH meus_idosos AS (
          SELECT id_idoso FROM idoso
           WHERE id_ilpi = fn_minha_ilpi_profissional() AND ativo
        )
        SELECT
          (SELECT count(*) FROM meus_idosos) AS residentes,
          (SELECT count(DISTINCT id_idoso) FROM registro_bem_estar
             WHERE id_idoso IN (SELECT id_idoso FROM meus_idosos)
               AND data_hora >= CURRENT_DATE) AS checkins_hoje,
          (SELECT count(*) FROM idoso i
             WHERE i.id_idoso IN (SELECT id_idoso FROM meus_idosos)
               AND NOT EXISTS (SELECT 1 FROM registro_bem_estar r
                                WHERE r.id_idoso = i.id_idoso
                                  AND r.data_hora > now() - INTERVAL '3 days')) AS sem_checkin_3d,
          (SELECT count(*) FROM atividade_lazer
             WHERE id_ilpi = fn_minha_ilpi_profissional()
               AND data_hora >= CURRENT_DATE AND data_hora < CURRENT_DATE + 1) AS atividades_hoje,
          (SELECT count(*) FROM prescricao p
             JOIN meus_idosos m USING (id_idoso)
            WHERE p.ativo AND p.inicio <= CURRENT_DATE
              AND (p.fim IS NULL OR p.fim >= CURRENT_DATE)) AS prescricoes_ativas
      `);
      // doses pendentes de hoje (previstas cujo horário já passou e não foram dadas)
      const { rows: dp } = await c.query(`
        SELECT count(*)::int AS pendentes FROM (
          SELECT p.id_prescricao, (CURRENT_DATE + h)::timestamptz AS prev
            FROM prescricao p
            JOIN idoso i USING (id_idoso)
           CROSS JOIN LATERAL unnest(p.horarios) AS h
           WHERE p.ativo AND i.id_ilpi = fn_minha_ilpi_profissional()
             AND p.inicio <= CURRENT_DATE AND (p.fim IS NULL OR p.fim >= CURRENT_DATE)
        ) prev
        LEFT JOIN administracao_medicacao a
          ON a.id_prescricao = prev.id_prescricao AND a.horario_previsto = prev.prev
        WHERE a.id_adm IS NULL AND prev.prev < now()`);
      return { ...r[0], doses_pendentes: dp[0].pendentes };
    });
    res.json(d);
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao carregar o resumo." }); }
});

// ---------- Presença de uma atividade (equipe) ----------
app.get("/atividades/:id/presenca", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(`
        SELECT i.id_idoso, i.nome,
               EXISTS (SELECT 1 FROM participacao p
                        WHERE p.id_atividade = $1 AND p.id_idoso = i.id_idoso) AS confirmou
          FROM idoso i
         WHERE i.id_ilpi = fn_minha_ilpi_profissional() AND i.ativo
         ORDER BY i.nome`, [id]);
      return rows;
    });
    res.json(linhas);
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao carregar a presença." }); }
});

// ---------- Personalizar o meu pet (nome, espécie, cor, acessório) ----------
app.patch("/meu-pet", autenticar, async (req, res) => {
  const { nome, especie, cor, acessorio } = req.body || {};
  const ESPECIES = ["passarinho", "gato", "cachorro", "peixe", "tartaruga", "coelho"];
  const ACESSORIOS = [null, "chapeu", "laco", "oculos", "gravata", "flor"];
  if (especie && !ESPECIES.includes(especie)) return res.status(400).json({ erro: "Espécie inválida." });
  if (acessorio !== undefined && !ACESSORIOS.includes(acessorio)) return res.status(400).json({ erro: "Acessório inválido." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `UPDATE pet_virtual SET
           nome = COALESCE($1, nome),
           especie = COALESCE($2, especie),
           cor = COALESCE($3, cor),
           acessorio = $4
         WHERE id_idoso = fn_meu_id_idoso()
         RETURNING id_pet`,
        [nome || null, especie || null, cor || null, acessorio === undefined ? null : acessorio]
      );
      return rows[0] || null;
    });
    if (!r) return res.status(404).json({ erro: "Você ainda não tem um bichinho." });
    res.json({ ok: true });
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Você só personaliza o seu próprio bichinho." });
    console.error(e); res.status(500).json({ erro: "Falha ao personalizar." });
  }
});

// ---------- Medicação: doses do dia ----------
// Cruza as prescrições ativas com o que já foi administrado hoje.
// O RLS recorta pela ILPI de quem consulta.
app.get("/medicacoes/hoje", autenticar, async (req, res) => {
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(`
        SELECT p.id_prescricao, i.nome AS idoso, p.medicamento, p.dose,
               (CURRENT_DATE + h)::timestamptz AS horario_previsto,
               a.administrado_em, pr.nome AS quem_deu
          FROM prescricao p
          JOIN idoso i USING (id_idoso)
         CROSS JOIN LATERAL unnest(p.horarios) AS h
          LEFT JOIN administracao_medicacao a
            ON a.id_prescricao = p.id_prescricao
           AND a.horario_previsto = (CURRENT_DATE + h)::timestamptz
          LEFT JOIN profissional pr ON pr.id_profissional = a.id_profissional
         WHERE p.ativo AND p.inicio <= CURRENT_DATE
           AND (p.fim IS NULL OR p.fim >= CURRENT_DATE)
         ORDER BY horario_previsto, idoso`);
      return rows;
    });
    res.json(linhas);
  } catch (e) {
    console.error(e);
    res.status(500).json({ erro: "Falha ao carregar as doses do dia." });
  }
});

// ---------- Medicação: registrar dose dada ----------
app.post("/medicacoes/administrar", autenticar, async (req, res) => {
  const { id_prescricao, horario_previsto } = req.body || {};
  if (!Number.isInteger(id_prescricao) || !horario_previsto)
    return res.status(400).json({ erro: "Informe id_prescricao e horario_previsto." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto)
         VALUES ($1, fn_meu_id_profissional(), $2) RETURNING id_adm, administrado_em`,
        [id_prescricao, horario_previsto]
      );
      return rows[0];
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.code === "23505")
      return res.status(409).json({ erro: "Esta dose já foi registrada — evita administração dupla." });
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Você não pode registrar doses para esta prescrição." });
    console.error(e);
    res.status(500).json({ erro: "Falha ao registrar a dose." });
  }
});

// ---------- Medicação: nova prescrição (médico/enfermeiro) ----------
app.post("/prescricoes", autenticar, async (req, res) => {
  const { id_idoso, medicamento, dose, horarios } = req.body || {};
  if (!Number.isInteger(id_idoso) || !medicamento || !dose || !Array.isArray(horarios) || !horarios.length)
    return res.status(400).json({ erro: "Informe id_idoso, medicamento, dose e horarios (ex.: [\"08:00\",\"20:00\"])." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO prescricao (id_idoso, id_profissional, medicamento, dose, horarios)
         VALUES ($1, fn_meu_id_profissional(), $2, $3, $4::time[]) RETURNING id_prescricao`,
        [id_idoso, medicamento, dose, horarios]
      );
      return rows[0];
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Prescrever é restrito a médicos e enfermeiros da ILPI do idoso." });
    console.error(e);
    res.status(500).json({ erro: "Falha ao criar a prescrição." });
  }
});

// ---------- Mural da Família ----------
app.get("/idosos/:id/recados", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `SELECT m.id_recado, m.texto, m.data_hora, m.editado_em, r.nome AS de,
                (m.id_responsavel = fn_meu_id_responsavel()) AS meu
           FROM recado_mural m JOIN responsavel r USING (id_responsavel)
          WHERE m.id_idoso = $1 ORDER BY m.data_hora DESC LIMIT 30`,
        [id]
      );
      return rows;
    });
    res.json(linhas);
  } catch (e) {
    console.error(e);
    res.status(500).json({ erro: "Falha ao carregar o mural." });
  }
});

app.post("/recados", autenticar, async (req, res) => {
  const { id_idoso, texto } = req.body || {};
  if (!Number.isInteger(id_idoso) || !texto || !texto.trim())
    return res.status(400).json({ erro: "Informe id_idoso e o texto do recado." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO recado_mural (id_idoso, id_responsavel, texto)
         VALUES ($1, fn_meu_id_responsavel(), $2) RETURNING id_recado`,
        [id_idoso, texto.trim().slice(0, 500)]
      );
      return rows[0];
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Só responsáveis vinculados escrevem no mural deste idoso." });
    console.error(e);
    res.status(500).json({ erro: "Falha ao enviar o recado." });
  }
});

// Editar e apagar o PRÓPRIO recado. Quem pode é decidido pelo RLS
// (políticas upd_recado_autor / del_recado_autor): se a linha não é
// do autor, o UPDATE/DELETE simplesmente não a enxerga (rowCount = 0).
app.patch("/recados/:id", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  const { texto } = req.body || {};
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  if (!texto || !texto.trim()) return res.status(400).json({ erro: "O recado não pode ficar vazio." });
  try {
    const n = await comUsuario(req.usuario.id_usuario, async (c) => {
      const r = await c.query(
        "UPDATE recado_mural SET texto = $2, editado_em = now() WHERE id_recado = $1",
        [id, texto.trim().slice(0, 500)]);
      return r.rowCount;
    });
    if (!n) return res.status(404).json({ erro: "Recado não encontrado ou escrito por outra pessoa." });
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao editar o recado." }); }
});

app.delete("/recados/:id", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const n = await comUsuario(req.usuario.id_usuario, async (c) =>
      (await c.query("DELETE FROM recado_mural WHERE id_recado = $1", [id])).rowCount);
    if (!n) return res.status(404).json({ erro: "Recado não encontrado ou escrito por outra pessoa." });
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao apagar o recado." }); }
});

// ============================================================
// GESTÃO DE USUÁRIOS (somente gestor da ILPI)
// ============================================================
// Helper: exige que o solicitante seja gestor; devolve a ILPI dele.
async function exigirGestor(client) {
  const { rows } = await client.query(
    "SELECT fn_sou_gestor() AS ok, fn_minha_ilpi_profissional() AS ilpi");
  if (!rows[0].ok) throw Object.assign(new Error("Apenas o gestor da ILPI faz isto."), { status: 403 });
  return rows[0].ilpi;
}

// Quem valida CPF, e-mail e telefone é o próprio banco (restrições CHECK
// do schema); aqui só se traduz o nome da restrição violada (erro 23514)
// para uma mensagem que o gestor entenda.
const MSG_RESTRICAO = {
  ck_idoso_cpf: "CPF inválido: confira os dígitos.",
  ck_email_formato: "E-mail em formato inválido.",
  ck_telefone: "Telefone inválido: use DDD + número, só dígitos (ex.: 81988887777).",
  ck_idoso_60mais: "O cadastro de residente exige 60 anos ou mais.",
  ck_admissao_valida: "A data de admissão não pode ser anterior ao nascimento.",
};
function mensagemRestricao(e) {
  return e && e.code === "23514" ? MSG_RESTRICAO[e.constraint] || null : null;
}
const normalizarEmail = (s) => String(s).trim().toLowerCase();

// Listar as pessoas da minha ILPI (idosos e equipe)
app.get("/gestao/pessoas", autenticar, async (req, res) => {
  try {
    const dados = await comUsuario(req.usuario.id_usuario, async (c) => {
      await exigirGestor(c);
      const { rows: idosos } = await c.query(
        `SELECT i.id_idoso, i.id_usuario, i.nome, i.cpf, i.grau_dependencia, i.ativo, u.email,
                cr.nome AS cuidador_referencia
           FROM idoso i
           LEFT JOIN usuario u       ON u.id_usuario = i.id_usuario
           LEFT JOIN profissional cr ON cr.id_profissional = i.id_cuidador_referencia
          WHERE i.id_ilpi = fn_minha_ilpi_profissional() ORDER BY i.ativo DESC, i.nome`);
      const { rows: equipe } = await c.query(
        `SELECT p.id_profissional, p.id_usuario, p.nome, p.funcao, p.registro_conselho, p.ativo, u.email
           FROM profissional p JOIN usuario u USING (id_usuario)
          WHERE p.id_ilpi = fn_minha_ilpi_profissional() ORDER BY p.ativo DESC, p.nome`);
      return { idosos, equipe };
    });
    res.json(dados);
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    console.error(e); res.status(500).json({ erro: "Falha ao listar." });
  }
});

// Cadastrar um novo IDOSO (com login opcional e pet opcional)
app.post("/gestao/idosos", autenticar, async (req, res) => {
  const { nome, cpf, data_nascimento, grau_dependencia, email, senha, pet } = req.body || {};
  if (!nome || !cpf || !data_nascimento || !["I", "II", "III"].includes(grau_dependencia))
    return res.status(400).json({ erro: "Informe nome, cpf, data_nascimento e grau_dependencia (I, II ou III)." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const ilpi = await exigirGestor(c);
      let idUsuario = null;
      if (email && senha) {
        const { rows } = await c.query(
          `INSERT INTO usuario (email, senha_hash, perfil)
           VALUES ($1, crypt($2, gen_salt('bf', 10)), 'idoso') RETURNING id_usuario`, [normalizarEmail(email), senha]);
        idUsuario = rows[0].id_usuario;
      }
      const { rows: idoso } = await c.query(
        `INSERT INTO idoso (id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia)
         VALUES ($1, $2, $3, $4, $5, CURRENT_DATE, $6) RETURNING id_idoso`,
        [ilpi, idUsuario, nome, cpf.replace(/\D/g, ""), data_nascimento, grau_dependencia]);
      if (pet && pet.nome)
        await c.query("INSERT INTO pet_virtual (id_idoso, nome, especie) VALUES ($1, $2, $3)",
          [idoso[0].id_idoso, pet.nome, pet.especie || "passarinho"]);
      return { id_idoso: idoso[0].id_idoso };
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    if (e.code === "23505") return res.status(409).json({ erro: "Já existe cadastro com esse email ou CPF." });
    if (mensagemRestricao(e)) return res.status(400).json({ erro: mensagemRestricao(e) });
    console.error(e); res.status(500).json({ erro: "Falha ao cadastrar o idoso." });
  }
});

// Cadastrar um novo PROFISSIONAL
app.post("/gestao/profissionais", autenticar, async (req, res) => {
  const FUNCOES = ["cuidador", "tecnico_enfermagem", "enfermeiro", "medico", "psicologo", "fisioterapeuta", "nutricionista", "assistente_social", "gestor"];
  const { nome, funcao, email, senha, registro_conselho } = req.body || {};
  if (!nome || !FUNCOES.includes(funcao) || !email || !senha)
    return res.status(400).json({ erro: "Informe nome, funcao válida, email e senha." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const ilpi = await exigirGestor(c);
      const { rows: u } = await c.query(
        `INSERT INTO usuario (email, senha_hash, perfil)
         VALUES ($1, crypt($2, gen_salt('bf', 10)), 'profissional') RETURNING id_usuario`, [normalizarEmail(email), senha]);
      const { rows: p } = await c.query(
        `INSERT INTO profissional (id_ilpi, id_usuario, nome, funcao, registro_conselho)
         VALUES ($1, $2, $3, $4, $5) RETURNING id_profissional`,
        [ilpi, u[0].id_usuario, nome, funcao, registro_conselho || null]);
      return { id_profissional: p[0].id_profissional };
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    if (e.code === "23505") return res.status(409).json({ erro: "Já existe uma conta com esse email." });
    if (mensagemRestricao(e)) return res.status(400).json({ erro: mensagemRestricao(e) });
    console.error(e); res.status(500).json({ erro: "Falha ao cadastrar o profissional." });
  }
});

// Cadastrar um RESPONSÁVEL e vinculá-lo a um idoso
app.post("/gestao/responsaveis", autenticar, async (req, res) => {
  const { nome, telefone, email, senha, id_idoso, parentesco, responsavel_legal } = req.body || {};
  if (!nome || !telefone || !email || !senha || !Number.isInteger(id_idoso) || !parentesco)
    return res.status(400).json({ erro: "Informe nome, telefone, email, senha, id_idoso e parentesco." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      await exigirGestor(c);
      const { rows: u } = await c.query(
        `INSERT INTO usuario (email, senha_hash, perfil)
         VALUES ($1, crypt($2, gen_salt('bf', 10)), 'responsavel') RETURNING id_usuario`, [normalizarEmail(email), senha]);
      const { rows: resp } = await c.query(
        `INSERT INTO responsavel (id_usuario, nome, telefone) VALUES ($1, $2, $3) RETURNING id_responsavel`,
        [u[0].id_usuario, nome, String(telefone).replace(/\D/g, "")]);
      await c.query(
        `INSERT INTO vinculo_responsavel (id_idoso, id_responsavel, parentesco, responsavel_legal)
         VALUES ($1, $2, $3, $4)`,
        [id_idoso, resp[0].id_responsavel, parentesco, !!responsavel_legal]);
      return { id_responsavel: resp[0].id_responsavel };
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    if (e.code === "23505") return res.status(409).json({ erro: "Email já cadastrado, ou já existe responsável legal para este idoso." });
    if (mensagemRestricao(e)) return res.status(400).json({ erro: mensagemRestricao(e) });
    console.error(e); res.status(500).json({ erro: "Falha ao cadastrar o responsável." });
  }
});

// Editar dados de um idoso (nome, grau; não mexe em CPF/histórico)
app.patch("/gestao/idosos/:id", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  const { nome, grau_dependencia } = req.body || {};
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      await exigirGestor(c);
      const { rows } = await c.query(
        `UPDATE idoso SET
           nome = COALESCE($2, nome),
           grau_dependencia = COALESCE($3, grau_dependencia)
         WHERE id_idoso = $1 RETURNING id_idoso`,
        [id, nome || null, grau_dependencia || null]);
      return rows[0] || null;
    });
    if (!r) return res.status(404).json({ erro: "Residente não encontrado na sua ILPI." });
    res.json(r);
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    console.error(e); res.status(500).json({ erro: "Falha ao editar." });
  }
});

// Ativar/desativar idoso (alta ou retorno). Desativar preserva histórico.
// Desligar chama o PROCEDIMENTO sp_desligar_residente (Etapa 05), que na
// mesma transação inativa o residente e a conta, encerra as prescrições
// ativas e suspende as metas do plano de cuidado. As mensagens que o
// procedimento emite (RAISE NOTICE) voltam para a tela.
app.post("/gestao/idosos/:id/ativo", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  const { ativo } = req.body || {};
  if (!Number.isInteger(id) || typeof ativo !== "boolean")
    return res.status(400).json({ erro: "Informe ativo (true/false)." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      await exigirGestor(c);
      const { rows } = await c.query("SELECT id_usuario, ativo FROM idoso WHERE id_idoso = $1", [id]);
      if (!rows[0]) return null;
      if (!ativo) {
        if (!rows[0].ativo) return { id_idoso: id, mensagens: ["O residente já estava desligado."] };
        const mensagens = await comAvisos(c, () => c.query("CALL sp_desligar_residente($1)", [id]));
        return { id_idoso: id, mensagens };
      }
      await c.query("UPDATE idoso SET ativo = true WHERE id_idoso = $1", [id]);
      if (rows[0].id_usuario)
        await c.query("UPDATE usuario SET ativo = true WHERE id_usuario = $1", [rows[0].id_usuario]);
      return { id_idoso: id, mensagens: [] };
    });
    if (!r) return res.status(404).json({ erro: "Residente não encontrado." });
    res.json({ id_idoso: r.id_idoso, ativo, mensagens: r.mensagens });
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    if (e.code === "P0001") return res.status(403).json({ erro: e.message });   // RAISE EXCEPTION do procedimento
    console.error(e); res.status(500).json({ erro: "Falha ao atualizar." });
  }
});

// Histórico de grau de dependência do residente (tabela de log gravada
// pelo TRIGGER trg_log_grau_dependencia, Etapa 05)
app.get("/gestao/idosos/:id/historico-grau", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      await exigirGestor(c);
      const { rows } = await c.query(
        `SELECT l.id_log, l.grau_anterior, l.grau_novo, l.cuidadores_necessarios, l.data_hora,
                COALESCE(p.nome, u.email, 'administrador do banco') AS alterado_por
           FROM log_grau_dependencia l
           LEFT JOIN usuario u      ON u.id_usuario = l.id_usuario
           LEFT JOIN profissional p ON p.id_usuario = l.id_usuario
          WHERE l.id_idoso = $1
          ORDER BY l.data_hora DESC`, [id]);
      return rows;
    });
    res.json(linhas);
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    console.error(e); res.status(500).json({ erro: "Falha ao carregar o histórico." });
  }
});

// ---------- Cuidadores de referência (procedimento com cursor, Etapa 05) ----------
// Situação atual: cada cuidador ativo, seus residentes e a carga em pontos
// (grau I = 3, II = 6, III = 10), mais quem está sem referência e quantos
// cuidadores a RDC 502 exige (FUNÇÃO fn_cuidadores_necessarios).
app.get("/gestao/cuidadores", autenticar, async (req, res) => {
  try {
    const d = await comUsuario(req.usuario.id_usuario, async (c) => {
      await exigirGestor(c);
      const { rows: cuidadores } = await c.query(
        `SELECT p.id_profissional, p.nome,
                count(i.id_idoso)::int AS residentes,
                COALESCE(sum(CASE i.grau_dependencia WHEN 'I' THEN 3 WHEN 'II' THEN 6 WHEN 'III' THEN 10 END), 0)::int
                                       AS pontos_de_carga,
                COALESCE(string_agg(i.nome || ' (' || i.grau_dependencia || ')', ', ' ORDER BY i.grau_dependencia DESC, i.nome), '')
                                       AS lista
           FROM profissional p
           LEFT JOIN idoso i ON i.id_cuidador_referencia = p.id_profissional AND i.ativo
          WHERE p.id_ilpi = fn_minha_ilpi_profissional()
            AND p.funcao = 'cuidador' AND p.ativo
          GROUP BY p.id_profissional, p.nome
          ORDER BY pontos_de_carga DESC, p.nome`);
      const { rows: sem } = await c.query(
        `SELECT i.id_idoso, i.nome, i.grau_dependencia
           FROM idoso i
           LEFT JOIN profissional p
                  ON p.id_profissional = i.id_cuidador_referencia AND p.ativo AND p.funcao = 'cuidador'
          WHERE i.id_ilpi = fn_minha_ilpi_profissional() AND i.ativo AND p.id_profissional IS NULL
          ORDER BY i.grau_dependencia DESC, i.nome`);
      const { rows: n } = await c.query(
        "SELECT fn_cuidadores_necessarios(fn_minha_ilpi_profissional()) AS necessarios");
      return { cuidadores, sem_referencia: sem, necessarios: n[0].necessarios };
    });
    res.json(d);
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    console.error(e); res.status(500).json({ erro: "Falha ao carregar os cuidadores." });
  }
});

// Executa o PROCEDIMENTO sp_distribuir_cuidadores. refazer = true apaga a
// divisão atual e distribui todos de novo; false só atribui quem está sem
// referência. Devolve as mensagens do procedimento (uma por residente).
app.post("/gestao/cuidadores/distribuir", autenticar, async (req, res) => {
  const refazer = (req.body || {}).refazer === true;
  try {
    const mensagens = await comUsuario(req.usuario.id_usuario, async (c) => {
      await exigirGestor(c);
      return comAvisos(c, () =>
        c.query("CALL sp_distribuir_cuidadores(fn_minha_ilpi_profissional(), $1)", [refazer]));
    });
    res.json({ mensagens });
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    if (e.code === "P0001") return res.status(409).json({ erro: e.message });
    console.error(e); res.status(500).json({ erro: "Falha ao distribuir." });
  }
});

// Editar profissional (nome, função, registro)
app.patch("/gestao/profissionais/:id", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  const FUNCOES = ["cuidador", "tecnico_enfermagem", "enfermeiro", "medico", "psicologo", "fisioterapeuta", "nutricionista", "assistente_social", "gestor"];
  const { nome, funcao, registro_conselho } = req.body || {};
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  if (funcao && !FUNCOES.includes(funcao)) return res.status(400).json({ erro: "Função inválida." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      await exigirGestor(c);
      const { rows } = await c.query(
        `UPDATE profissional SET
           nome = COALESCE($2, nome),
           funcao = COALESCE($3, funcao),
           registro_conselho = COALESCE($4, registro_conselho)
         WHERE id_profissional = $1 RETURNING id_profissional`,
        [id, nome || null, funcao || null, registro_conselho || null]);
      return rows[0] || null;
    });
    if (!r) return res.status(404).json({ erro: "Profissional não encontrado na sua ILPI." });
    res.json(r);
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    console.error(e); res.status(500).json({ erro: "Falha ao editar." });
  }
});

// Ativar/desativar profissional (saiu da equipe / voltou)
app.post("/gestao/profissionais/:id/ativo", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  const { ativo } = req.body || {};
  if (!Number.isInteger(id) || typeof ativo !== "boolean")
    return res.status(400).json({ erro: "Informe ativo (true/false)." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const ilpi = await exigirGestor(c);
      // trava de segurança: não desativar o último gestor ativo da ILPI
      if (!ativo) {
        const { rows: g } = await c.query(
          `SELECT count(*)::int AS n FROM profissional
            WHERE id_ilpi = $1 AND funcao = 'gestor' AND ativo AND id_profissional <> $2`, [ilpi, id]);
        const { rows: eu } = await c.query("SELECT funcao FROM profissional WHERE id_profissional = $1", [id]);
        if (eu[0] && eu[0].funcao === "gestor" && g[0].n === 0)
          throw Object.assign(new Error("Não é possível desativar o único gestor ativo da ILPI."), { status: 409 });
      }
      const { rows } = await c.query("UPDATE profissional SET ativo = $2 WHERE id_profissional = $1 RETURNING id_usuario, funcao", [id, ativo]);
      if (!rows[0]) return null;
      await c.query("UPDATE usuario SET ativo = $2 WHERE id_usuario = $1", [rows[0].id_usuario, ativo]);
      // Cuidador saiu da equipe: os residentes de quem ele era referência
      // são redistribuídos na hora pelo PROCEDIMENTO com cursor (refazer =
      // false: só quem ficou sem referência), se ainda houver cuidador ativo.
      let mensagens = [];
      if (!ativo && rows[0].funcao === "cuidador") {
        const { rows: x } = await c.query(
          `SELECT EXISTS (SELECT 1 FROM idoso WHERE id_cuidador_referencia = $1 AND ativo) AS tinha,
                  EXISTS (SELECT 1 FROM profissional WHERE id_ilpi = $2 AND funcao = 'cuidador' AND ativo) AS ha_outro`,
          [id, ilpi]);
        if (x[0].tinha && x[0].ha_outro)
          mensagens = await comAvisos(c, () => c.query("CALL sp_distribuir_cuidadores($1, false)", [ilpi]));
      }
      return { mensagens };
    });
    if (!r) return res.status(404).json({ erro: "Profissional não encontrado." });
    res.json({ id_profissional: id, ativo, mensagens: r.mensagens });
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    console.error(e); res.status(500).json({ erro: "Falha ao atualizar." });
  }
});

// ---------- Consentimento LGPD ----------
app.get("/idosos/:id/consentimentos", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `SELECT id_consentimento, categoria, finalidade, data_concessao, data_revogacao
           FROM consentimento_lgpd WHERE id_idoso = $1 ORDER BY data_concessao DESC`, [id]);
      return rows;
    });
    res.json(linhas);
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao consultar consentimentos." }); }
});

app.post("/consentimentos", autenticar, async (req, res) => {
  const { id_idoso, finalidade, categoria = "dados_saude" } = req.body || {};
  if (!Number.isInteger(id_idoso) || !finalidade || !finalidade.trim())
    return res.status(400).json({ erro: "Informe id_idoso e a finalidade." });
  if (!["dados_saude", "imagem", "outros"].includes(categoria))
    return res.status(400).json({ erro: "Categoria deve ser dados_saude, imagem ou outros." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO consentimento_lgpd (id_idoso, categoria, finalidade)
         VALUES ($1, $2, $3) RETURNING id_consentimento, categoria, data_concessao`,
        [id_idoso, categoria, finalidade.trim().slice(0, 200)]);
      return rows[0];
    });
    res.status(201).json(r);
  } catch (e) {
    if (e.code === "42501" || String(e.message).includes("row-level security"))
      return res.status(403).json({ erro: "Só o responsável legal registra o consentimento." });
    if (e.code === "23505")   // ux_consentimento_vigente
      return res.status(409).json({ erro: "Já existe um consentimento vigente desta categoria." });
    console.error(e); res.status(500).json({ erro: "Falha ao registrar o consentimento." });
  }
});

app.post("/consentimentos/:id/revogar", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(
        `UPDATE consentimento_lgpd SET data_revogacao = now()
          WHERE id_consentimento = $1 AND data_revogacao IS NULL
          RETURNING id_consentimento, data_revogacao`, [id]);
      return rows[0] || null;
    });
    if (!r) return res.status(404).json({ erro: "Consentimento não encontrado, já revogado ou fora do seu alcance." });
    res.json(r);
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao revogar." }); }
});

// ---------- Relatório mensal em PDF ----------
// Consolida o mês do idoso para a família ou para a vigilância.
// O RLS decide quem pode gerar (mesma visibilidade do painel).
app.get("/idosos/:id/relatorio", autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ erro: "Identificador inválido." });
  const mes = /^\d{4}-\d{2}$/.test(req.query.mes || "") ? req.query.mes : new Date().toISOString().slice(0, 7);
  try {
    const d = await comUsuario(req.usuario.id_usuario, async (c) => {
      const ini = `${mes}-01`;
      const { rows: p } = await c.query(
        `SELECT nome, idade, grau_dependencia, ilpi, pet, nivel_pet, pontos_pet, atividades_30d
           FROM vw_painel_idoso WHERE id_idoso = $1`, [id]);
      if (!p.length) return null;
      const { rows: bem } = await c.query(
        `SELECT count(*)::int AS registros, round(avg(humor),1) AS humor, round(avg(conforto),1) AS conforto, round(avg(dor),1) AS dor
           FROM registro_bem_estar
          WHERE id_idoso = $1 AND data_hora >= $2::date AND data_hora < ($2::date + INTERVAL '1 month')`, [id, ini]);
      const { rows: avals } = await c.query(
        `SELECT instrumento, pontuacao_total, data_hora FROM avaliacao
          WHERE id_idoso = $1 AND data_hora >= $2::date AND data_hora < ($2::date + INTERVAL '1 month')
          ORDER BY data_hora`, [id, ini]);
      const { rows: par } = await c.query(
        `SELECT count(*)::int AS n FROM partida_domino
          WHERE (id_jogador1 = $1 OR id_jogador2 = $1)
            AND data_hora >= $2::date AND data_hora < ($2::date + INTERVAL '1 month')`, [id, ini]);
      const { rows: med } = await c.query(
        `SELECT count(*)::int AS n FROM administracao_medicacao a
           JOIN prescricao p USING (id_prescricao)
          WHERE p.id_idoso = $1 AND a.administrado_em >= $2::date
            AND a.administrado_em < ($2::date + INTERVAL '1 month')`, [id, ini]);
      return { p: p[0], bem: bem[0], avals, partidas: par[0].n, doses: med[0].n };
    });
    if (!d) return res.status(404).json({ erro: "Idoso fora do seu alcance ou inexistente." });

    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", `attachment; filename="relatorio_${mes}.pdf"`);
    const doc = new PDFDocument({ margin: 54, size: "A4" });
    doc.pipe(res);
    doc.fontSize(19).fillColor("#27418F").text("Bem Viver ILPI — Relatório Mensal", { align: "center" });
    doc.moveDown(0.3).fontSize(11).fillColor("#5E564A")
       .text(`${d.p.ilpi} · competência ${mes} · gerado em ${new Date().toLocaleDateString("pt-BR")}`, { align: "center" });
    doc.moveDown(1).fillColor("#26201A").fontSize(14).text(d.p.nome, { underline: true });
    doc.fontSize(11).text(`${d.p.idade} anos · grau de dependência ${d.p.grau_dependencia} (RDC 502/2021)`);
    doc.moveDown(0.8).fontSize(13).fillColor("#27418F").text("Bem-estar no mês");
    doc.fontSize(11).fillColor("#26201A");
    if (d.bem.registros > 0)
      doc.text(`${d.bem.registros} check-in(s). Médias — humor: ${d.bem.humor}/5 · conforto: ${d.bem.conforto}/5 · dor: ${d.bem.dor}/10.`);
    else doc.text("Sem check-ins registrados neste mês.");
    doc.moveDown(0.8).fontSize(13).fillColor("#27418F").text("Avaliações clínicas");
    doc.fontSize(11).fillColor("#26201A");
    if (d.avals.length)
      d.avals.forEach((a) => doc.text(`• ${a.instrumento} em ${new Date(a.data_hora).toLocaleDateString("pt-BR")}${a.pontuacao_total != null ? ` — pontuação ${a.pontuacao_total}` : ""}`));
    else doc.text("Nenhuma avaliação no período.");
    doc.moveDown(0.8).fontSize(13).fillColor("#27418F").text("Engajamento e cuidado");
    doc.fontSize(11).fillColor("#26201A")
       .text(`Partidas de dominó: ${d.partidas} · Doses de medicação registradas: ${d.doses} · Atividades de lazer (30 dias): ${d.p.atividades_30d}.`);
    if (d.p.pet) doc.text(`Pet virtual: ${d.p.pet}, nível ${d.p.nivel_pet} (${d.p.pontos_pet} pontos) — reflexo do engajamento no autocuidado.`);
    doc.moveDown(1.2).fontSize(9).fillColor("#5E564A")
       .text("Documento gerado automaticamente a partir dos registros do sistema, com trilha de auditoria. Não substitui prontuário ou prescrição médica formal.", { align: "justify" });
    doc.end();
  } catch (e) { console.error(e); res.status(500).json({ erro: "Falha ao gerar o relatório." }); }
});

// ---------- Alertas para a equipe ----------
// Idosos sem check-in há mais de 3 dias. O RLS já limita ao
// recorte de quem consulta (a enfermeira só vê a própria ILPI).
app.get("/alertas/checkins", autenticar, async (req, res) => {
  try {
    const linhas = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query(`
        SELECT i.nome,
               max(r.data_hora) AS ultimo_checkin,
               COALESCE(extract(day FROM now() - max(r.data_hora))::int,
                        extract(day FROM now() - i.data_admissao)::int) AS dias_sem_checkin,
               resp.nome AS responsavel, resp.telefone AS telefone_responsavel
          FROM idoso i
          LEFT JOIN registro_bem_estar r USING (id_idoso)
          LEFT JOIN LATERAL (
            SELECT re.nome, re.telefone
              FROM vinculo_responsavel v JOIN responsavel re USING (id_responsavel)
             WHERE v.id_idoso = i.id_idoso AND v.responsavel_legal LIMIT 1
          ) resp ON TRUE
         WHERE i.ativo
         GROUP BY i.id_idoso, i.nome, i.data_admissao, resp.nome, resp.telefone
        HAVING max(r.data_hora) IS NULL OR max(r.data_hora) < now() - INTERVAL '3 days'
         ORDER BY dias_sem_checkin DESC`);
      return rows;
    });
    res.json(linhas);
  } catch (e) {
    console.error(e);
    res.status(500).json({ erro: "Falha ao carregar os alertas." });
  }
});

// ============================================================
// DASHBOARD ESTATÍSTICO (gestor) — os SQLs ficam em dashboard.js
// Todos os blocos são calculados no banco, agora, com o RLS da ILPI.
// ============================================================
const DIAS_DASHBOARD = [7, 30, 90, 180];
const GRAUS = ["todos", "I", "II", "III"];

app.get("/dashboard", autenticar, async (req, res) => {
  const dias = req.query.dias === undefined ? 30 : Number(req.query.dias);
  const grau = req.query.grau === undefined ? "todos" : String(req.query.grau);
  const medida = req.query.medida === undefined ? "humor" : String(req.query.medida);
  if (!DIAS_DASHBOARD.includes(dias)) return res.status(400).json({ erro: `Período inválido. Use ${DIAS_DASHBOARD.join(", ")} dias.` });
  if (!GRAUS.includes(grau)) return res.status(400).json({ erro: "Grau inválido. Use todos, I, II ou III." });
  if (!MEDIDAS[medida]) return res.status(400).json({ erro: "Medida inválida. Use humor, conforto ou dor." });
  const p = [dias, grau];
  // bloco -> [SQL, parâmetros]
  const blocos = {
    indicadores:          [DASHBOARD.indicadores, p],
    adesao:               [DASHBOARD.adesao, [grau]],
    estatisticas:         [DASHBOARD.estatisticas[medida], p],
    histograma:           [DASHBOARD.histograma[medida], p],
    tendencia:            [DASHBOARD.tendencia, p],
    regressao:            [DASHBOARD.regressao, p],
    intercorrencias_tipo: [DASHBOARD.intercorrencias_tipo, p],
    residentes_grau:      [DASHBOARD.residentes_grau, []],
    radar_atividades:     [DASHBOARD.radar_atividades, p],
    dispersao:            [DASHBOARD.dispersao, p],
    correlacao:           [DASHBOARD.correlacao, p],
    refeicoes:            [DASHBOARD.refeicoes, p],
    pressao:              [DASHBOARD.pressao, p],
  };
  try {
    const dados = await comUsuario(req.usuario.id_usuario, async (c) => {
      await exigirGestor(c);
      const r = {};
      // uma consulta de cada vez na mesma conexão (mesma transação)
      for (const [nome, [sql, params]] of Object.entries(blocos))
        r[nome] = (await c.query(sql, params)).rows;
      return r;
    });
    res.json({
      filtros: { dias, grau, medida, opcoes_dias: DIAS_DASHBOARD, medidas: MEDIDAS },
      indicadores: { ...dados.indicadores[0], ...dados.adesao[0] },
      estatisticas: dados.estatisticas[0],
      histograma: dados.histograma,
      tendencia: dados.tendencia,
      regressao: dados.regressao[0],
      intercorrencias_tipo: dados.intercorrencias_tipo,
      residentes_grau: dados.residentes_grau,
      radar_atividades: dados.radar_atividades,
      dispersao: dados.dispersao,
      correlacao: dados.correlacao[0],
      refeicoes: dados.refeicoes,
      pressao: dados.pressao,
      sql: Object.fromEntries(Object.entries(blocos).map(([k, [q]]) => [k, q])),
    });
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    console.error(e); res.status(500).json({ erro: "Falha ao montar o dashboard." });
  }
});

// ============================================================
// CONSULTAS ANALÍTICAS (tela "📊 Consultas" do gestor)
// Os SQLs vivem em consultas.js. Rodam com a identidade do usuário,
// então o RLS limita o resultado à ILPI de quem pediu.
// ============================================================
// Lista na ordem dos grupos temáticos da tela (bem-estar, saúde, ...)
app.get("/consultas", autenticar, (req, res) => {
  const ordem = (c) => GRUPOS.findIndex(([g]) => g === c.grupo);
  res.json([...CONSULTAS].sort((a, b) => ordem(a) - ordem(b)).map(({ id, grupo, etapa, visao, titulo, pergunta, tecnicas, grafico, periodo, filtro }) =>
    ({ id, grupo, rotulo_grupo: (GRUPOS.find(([g]) => g === grupo) || [])[1] || "", etapa: etapa || 3, visao: !!visao,
       titulo, pergunta, tecnicas, grafico, periodo: periodo || null, filtro: filtro || null })));
});

app.get("/consultas/:id", autenticar, async (req, res) => {
  const def = CONSULTAS.find((c) => c.id === Number(req.params.id));
  if (!def) return res.status(404).json({ erro: "Consulta não encontrada." });
  // Parâmetros, na ordem: período em dias ($1) e/ou filtro ($1 ou $2).
  // Só valem os valores oferecidos pela consulta; sem nada na URL, o padrão.
  const params = [];
  let dias = null, filtro = null;
  if (def.periodo) {
    dias = req.query.dias === undefined ? def.periodo.padrao : Number(req.query.dias);
    if (!def.periodo.opcoes.includes(dias))
      return res.status(400).json({ erro: `Período inválido. Use ${def.periodo.opcoes.join(", ")} dias.` });
    params.push(dias);
  }
  if (def.filtro) {
    filtro = req.query.filtro === undefined ? def.filtro.padrao : String(req.query.filtro);
    if (!def.filtro.opcoes.some(([v]) => v === filtro))
      return res.status(400).json({ erro: "Filtro inválido." });
    params.push(filtro);
  }
  try {
    const r = await comUsuario(req.usuario.id_usuario, async (c) => {
      const { rows } = await c.query("SELECT fn_sou_gestor() AS ok");
      if (!rows[0].ok) throw Object.assign(new Error("As consultas analíticas são do gestor da ILPI."), { status: 403 });
      return c.query(def.sql, params);   // SQL explícito; período e filtro vão como parâmetros
    });
    res.json({
      id: def.id, etapa: def.etapa || 3, visao: !!def.visao, titulo: def.titulo, sql: def.sql, grafico: def.grafico,
      periodo: def.periodo ? { ...def.periodo, dias } : null,
      filtro: def.filtro ? { ...def.filtro, valor: filtro } : null,
      colunas: r.fields.map((f) => f.name), linhas: r.rows,
    });
  } catch (e) {
    if (e.status) return res.status(e.status).json({ erro: e.message });
    console.error(e); res.status(500).json({ erro: "Falha ao executar a consulta." });
  }
});

app.listen(PORT, () => console.log(`API da ILPI ouvindo em http://localhost:${PORT}`));
