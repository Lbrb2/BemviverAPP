# Guia de Hospedagem — Bem Viver ILPI

Este guia leva o sistema do seu computador para a internet, em três serviços
gratuitos. Ao final, você terá um link público (ex.: `bemviver.vercel.app`)
para acessar de qualquer lugar e mostrar no pitch.

**Tempo estimado:** 1 a 2 horas, sem pressa.
**Custo:** gratuito (planos free são suficientes para o protótipo).

---

## Visão geral: as três partes

Hoje tudo roda no seu PC. Na internet, cada parte vai para um lugar:

| Parte | O que é | Serviço sugerido | Alternativa |
|-------|---------|------------------|-------------|
| Banco de dados | PostgreSQL (guarda tudo) | **Neon** | Supabase |
| API | `server.js` em Node (o motor) | **Render** | Railway |
| App | React/Vite (as telas) | **Vercel** | Netlify |

A ordem importa: **banco → API → app**. Cada um precisa do anterior pronto.

---

## Antes de começar: coloque o código no GitHub

Render e Vercel puxam o código do GitHub. Se ainda não tem o projeto lá:

1. Crie uma conta em github.com (se não tiver).
2. Crie um repositório novo, ex.: `bemviver-ilpi` (pode ser privado).
3. Suba os arquivos do projeto. Pelo site dá para arrastar os arquivos,
   mas o ideal é usar o Git. Estrutura recomendada no repositório:
   ```
   bemviver-ilpi/
   ├── api/              (a pasta da API: server.js, package.json)
   ├── bemviver/         (o projeto Vite do app — já vem pronto no repositório)
   ├── schema_ilpi.sql
   ├── seed_ilpi.sql
   ├── rls_ilpi.sql
   └── ...
   ```

> **Cuidado importante:** nunca suba senhas para o GitHub. O `JWT_SECRET` e a
> senha do banco vão nas configurações dos serviços (variáveis de ambiente),
> nunca no código. Confira que não há senha escrita nos arquivos.

---

## ETAPA 1 — Banco de dados (Neon)

1. Acesse **neon.tech** e crie conta (pode usar login do GitHub/Google).
2. Clique em **Create Project**. Dê um nome (ex.: `bemviver`), escolha a
   região mais próxima (ex.: São Paulo / South America, se disponível).
3. O Neon cria um banco vazio e te mostra uma **connection string**, algo como:
   ```
   postgresql://usuario:senha@ep-xxx.sa-east-1.aws.neon.tech/bemviver?sslmode=require
   ```
   **Guarde essa string** — dela saem host, usuário, senha e nome do banco.

4. Agora rode nossos scripts no banco. No painel do Neon há um **SQL Editor**.
   Cole e execute, **nesta ordem**, o conteúdo de cada arquivo:
   1. `schema_ilpi.sql` (cria as tabelas)
   2. `seed_ilpi.sql` (dados de demonstração)
   3. `rls_ilpi.sql` (segurança + papel app_user)
   4. `api/setup_api.sql` (ajustes da API)
   5. `entregas_bd/etapa04/etapa04_indices_e_visoes.sql` (índices e visões)
   6. `entregas_bd/etapa05/etapa05_funcoes_procedimentos_triggers.sql` (funções, procedimentos e triggers)
   7. `migracao_014_etapa06.sql` (exclusão de atividades e recados de plantão)

   > No `rls_ilpi.sql` há uma linha `CREATE ROLE app_user NOLOGIN;`. Para a
   > nuvem, o app_user precisa poder logar. Depois de rodar tudo, execute:
   > ```sql
   > ALTER ROLE app_user LOGIN PASSWORD 'escolha_uma_senha_forte';
   > ```
   > Guarde essa senha — a API vai usá-la.

5. Confira que deu certo: no SQL Editor rode `SELECT count(*) FROM idoso;`
   Deve retornar um número (os idosos de demonstração).

---

## ETAPA 2 — API (Render)

1. Acesse **render.com** e crie conta (login do GitHub facilita).
2. **New → Web Service**, conecte seu repositório do GitHub.
3. Configure:
   - **Root Directory:** `api` (a API está nessa subpasta)
   - **Build Command:** `npm install`
   - **Start Command:** `node server.js`
   - **Instance Type:** Free
4. Em **Environment** (variáveis de ambiente), adicione — usando os dados do
   Neon da Etapa 1:

   | Variável | Valor |
   |----------|-------|
   | `PGHOST` | o host do Neon (ex.: `ep-xxx.sa-east-1.aws.neon.tech`) |
   | `PGDATABASE` | `bemviver` (o nome do banco) |
   | `PGUSER` | `app_user` |
   | `PGPASSWORD` | a senha que você definiu para o app_user |
   | `PGSSL` | `true` |
   | `JWT_SECRET` | uma frase longa e aleatória (invente uma bem grande) |
   | `NODE_ENV` | `production` |

   > O `PGSSL=true` ativa a conexão segura que o Neon exige — já deixamos o
   > código preparado para isso.

5. Clique em **Create Web Service**. O Render instala e liga a API.
   Quando terminar, ele te dá uma URL pública, ex.:
   `https://bemviver-api.onrender.com`
6. Teste: abra `https://bemviver-api.onrender.com/health` no navegador
   (ou a raiz — "Cannot GET /" também indica que está no ar, como no localhost).

   > **Sobre o plano free do Render:** a API "dorme" após ~15 min sem uso e
   > demora ~30 segundos para acordar na próxima visita. Normal no plano
   > gratuito. Para o pitch, acesse alguns minutos antes para "acordá-la".

---

## ETAPA 3 — App (Vercel)

1. Acesse **vercel.com** e crie conta (login do GitHub).
2. **Add New → Project**, importe seu repositório.
3. Configure:
   - **Root Directory:** `bemviver` (a pasta do projeto Vite)
   - **Framework Preset:** Vite (deve detectar sozinho)
4. Em **Environment Variables**, adicione uma só:

   | Variável | Valor |
   |----------|-------|
   | `VITE_API_URL` | a URL da API no Render (ex.: `https://bemviver-api.onrender.com`) |

   > Já deixamos o app preparado para ler essa variável. Sem ela, ele tentaria
   > o localhost e não acharia a API.

5. Clique em **Deploy**. Em um minuto, a Vercel te dá o link público:
   `https://bemviver-ilpi.vercel.app`
6. Abra o link, entre com `dona.severina@email.com` / `demo123`. Se logar e
   mostrar o painel, **está tudo no ar!** 🎉

---

## Ordem de acionamento no dia do pitch

1. O banco (Neon) está sempre ligado.
2. Acesse a URL da API (Render) uns 2 min antes, para acordá-la do sono.
3. Abra o link do app (Vercel) e faça login.

---

## Depois que estiver no ar

- **Trocar o JWT_SECRET:** já feito na Etapa 2. Aquele aviso amarelo some.
- **Dados reais = responsabilidade real:** enquanto for demonstração com dados
  fictícios, tudo bem. No dia que entrar dado real de idoso, é obrigatório
  revisar LGPD (consentimento, contrato com os serviços, backup, criptografia).
  Não pule essa conversa antes de uso real.
- **Domínio próprio:** a Vercel permite ligar um domínio (ex.:
  `bemviver.com.br`) depois, se quiser.

---

## O que isto destranca

Com o sistema na internet, ficam viáveis as ideias que registramos:
- **Multiplayer dos jogos** (buraco entre pessoas de verdade)
- **A floresta comunitária dos Xodós** (todos os bichinhos juntos)
- Uma **ILPI real testando** de qualquer lugar — o passo que valida o projeto

Esses recursos precisam de mais trabalho (WebSockets, estado no servidor), mas
a hospedagem é o alicerce que torna tudo possível.
