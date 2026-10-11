# Bem Viver ILPI — Plataforma de Acompanhamento de Idosos em Pernambuco

Projeto acadêmico de banco de dados aplicado a um problema social real: o acompanhamento do bem-estar de idosos residentes em Instituições de Longa Permanência (ILPIs, os "asilos") de Pernambuco. A plataforma conecta três perfis — o idoso, o responsável familiar e a equipe da instituição — em torno de registros de bem-estar, avaliações clínicas padronizadas, atividades de lazer e uma gamificação afetiva (o pet virtual) que dobra como sinal clínico de engajamento.

## Arquitetura

```
┌─────────────────────┐        ┌──────────────────┐        ┌─────────────────────────┐
│  Dominó do Lar      │  HTTP  │  API (Express)   │  SQL   │  PostgreSQL 15+         │
│  React (JSX)        │ ─────► │  server.js       │ ─────► │  papel app_user + RLS   │
│  UX p/ maior idade  │  JWT   │  SET LOCAL       │        │  pgcrypto, auditoria    │
└─────────────────────┘        │  app.id_usuario  │        │  vw_painel_idoso        │
                               └──────────────────┘        └─────────────────────────┘
```

O princípio central do projeto: **a permissão mora no banco, não na aplicação**. A API não escreve cláusulas WHERE de autorização. Ela conecta como o papel `app_user`, abre uma transação por requisição e executa `SET LOCAL app.id_usuario = '<id do token>'`. As políticas de Row-Level Security decidem, linha a linha, o que cada perfil enxerga e grava. Um bug na API não fura a permissão — defesa em profundidade.

## Padrões e normas adotados

O acompanhamento segue instrumentos internacionalmente reconhecidos, todos com versão validada em português brasileiro. O modelo de avaliações é genérico (`avaliacao` + `item_avaliacao`), então novos instrumentos entram sem alterar o schema.

| Referência | Papel no projeto |
|---|---|
| WHO ICOPE | Domínios de capacidade funcional (mobilidade, cognição, humor, nutrição…) estruturam os itens de avaliação |
| interRAI LTCF | Referência de avaliação em instituições de longa permanência |
| Katz e Lawton | Independência em atividades básicas e instrumentais da vida diária |
| GDS-15 | Rastreio de depressão geriátrica |
| WHOQOL-OLD | Qualidade de vida; junto ao ICOPE, fundamenta o registro de interação social |
| RDC 502/2021 (ANVISA) | Regulação das ILPIs; origem do campo `grau_dependencia` (I, II, III) |
| LGPD | Dados de saúde são sensíveis: consentimento por categoria, com revogação que esconde o prontuário da família; RLS e trilha de auditoria |
| Resolução CFP 01/2009 | Sigilo do registro psicológico: a evolução é legível apenas por psicólogos |

## Arquivos do projeto

Os scripts SQL formam uma sequência: instalação nova roda apenas `schema_ilpi.sql` (que já incorpora as migrações); um banco existente aplica as migrações em ordem.

```
schema_ilpi.sql                  Schema canônico completo (tabelas, constraints, índices, view)
seed_ilpi.sql                    Dados de exemplo: ≥ 30 tuplas em cada tabela (30 ILPIs,
                                 32 idosos, 30 profissionais...), contas demo preservadas
consultas_ilpi.sql               8 consultas analíticas e de alerta (versão original)
consultas_etapa03.sql            As 10 consultas da tela "📊 Consultas" (gerado de api/consultas.js)
demonstracao_acoes_referenciais.sql  Mostra ON UPDATE CASCADE e ON DELETE SET NULL (com ROLLBACK)
entregas_bd/                     Entregas da disciplina de Banco de Dados (Etapas 01, 02 e 03)
rls_ilpi.sql                     Papel app_user, funções auxiliares e políticas de RLS
migracao_001_domino.sql          Tabela partida_domino + RLS (para bancos existentes)
migracao_002_painel_pontos.sql   Pontos do pet na view do painel (para bancos existentes)
migracao_003_medicacao_mural.sql Medicação, Mural da Família e auditoria por trigger
migracao_004_consentimento.sql   Fluxo e RLS do consentimento LGPD
migracao_005_gestor.sql          Perfil de gestor e cadastro de usuários
migracao_006_gestao_edicao.sql   Edição e desativação de usuários pelo gestor
migracao_007_pet.sql             Xodó personalizável e fases de crescimento
migracao_008_agenda.sql          Agenda de atividades com confirmação de presença
novos_usuarios_exemplo.sql       Cadastro manual de usuários (via SQL, para testes)
backup_windows.bat / _mac_linux  Backup do banco com data no nome (agende diariamente!)
pwa/                             Manifesto, service worker, ícone e guia para instalar como app
app_ilpi.jsx                     App completo: check-in e Dominó do Lar (idoso), painel
                                 do responsável, e área da equipe com alertas, lançamento
                                 de check-ins, avaliações clínicas e evolução psicológica
                                 (esta última visível apenas para psicólogos)
api/setup_api.sql                pgcrypto, senhas demo e LOGIN do app_user
api/server.js                    API Express com integração RLS por transação
api/consultas.js                 SQL das consultas analíticas (fonte única: API e .sql)
api/gerar_sql_consultas.js       Regera consultas_etapa03.sql a partir de consultas.js
api/package.json                 Dependências (express, pg, jsonwebtoken, cors)
```

## Instalação

Requisitos: PostgreSQL 15 ou superior (a view usa `security_invoker`) e Node.js 18+.

```bash
createdb ilpi
psql -d ilpi -f schema_ilpi.sql
psql -d ilpi -f seed_ilpi.sql
psql -d ilpi -f rls_ilpi.sql
psql -d ilpi -f api/setup_api.sql

cd api
npm install
PGDATABASE=ilpi npm start        # API em http://localhost:3000
```

Para o app, abra `app_ilpi.jsx` num ambiente React (Vite, por exemplo) com o componente como rota principal — ele contém as três áreas (idoso com o Dominó do Lar, responsável e equipe), roteadas pelo perfil de quem loga. Ajuste `API_URL` no topo do arquivo se a API não estiver em `localhost:3000`. Sem a API no ar, o botão "Ver demonstração" mantém o app navegável.

Todos os usuários do seed autenticam com a senha `demo123`:

```
dona.severina@email.com    idoso (Lar Recanto da Paz, Recife)
mariana.filha@email.com    responsável legal da Severina
enf.patricia@larpaz.com    enfermeira do Recife
psic.rodrigo@larpaz.com    psicólogo do Recife
enf.lucia@boavista.com     enfermeira de Caruaru (outra ILPI)
```

## Modelo de segurança

A autenticação verifica a senha dentro do próprio banco, pela função `fn_autenticar` (`pgcrypto`: `senha_hash = crypt(senha, senha_hash)`), e emite um JWT de 8 horas. A aplicação não tem permissão de ler a coluna `senha_hash`: a função roda como dono da tabela e devolve apenas quem é o usuário. A cada requisição autenticada, a API executa a consulta dentro de uma transação com `set_config('app.id_usuario', ..., true)` — o equivalente parametrizado de `SET LOCAL`, cujo efeito morre no COMMIT. Com pool de conexões, isso garante que a identidade de uma requisição jamais vaza para a seguinte.

As políticas produzem os recortes: o profissional enxerga os idosos da própria ILPI; o responsável, apenas os idosos vinculados a ele — e os registros clínicos (bem-estar, sinais, medicação, avaliações, plano de cuidado, intercorrências, nutrição) só enquanto houver consentimento LGPD de dados de saúde vigente; sem ele, a família continua vendo o cartão, o Xodó, o mural e as atividades; o idoso, a si mesmo. A evolução psicológica tem a política mais dura — somente psicólogos da ILPI do idoso, excluindo até o gestor. As 30 tabelas têm RLS ligado — inclusive as de apoio (ILPI, contas, profissionais, responsáveis, vínculos, itens de avaliação, eventos do pet, partidas e auditoria), que herdam o recorte das tabelas principais. `FORCE ROW LEVEL SECURITY` impede que o dono da tabela escape das políticas, e `security_invoker = true` faz a view do painel respeitar o RLS de quem consulta. Toda escrita via API alimenta `log_auditoria`, atendendo à trilha exigida pela LGPD. Todas as funções `SECURITY DEFINER` fixam `search_path = public, pg_temp`, e o script do RLS aborta a instalação se alguma ficar sem.

## Integridade no banco

O banco não confia no formato que chega: CPF e CNPJ são conferidos pelos dígitos verificadores (funções `IMMUTABLE` usadas em `CHECK`), o e-mail é guardado em minúsculas (o UNIQUE vale sem diferenciar maiúsculas, e o login aceita qualquer caixa), o telefone é só dígitos com DDD e a UF é uma das 27 siglas. O nível do Xodó é uma coluna gerada (`1 + pontos / 100`), então nunca discorda dos pontos. Um índice único parcial garante um só consentimento vigente por idoso e categoria. Todas as 49 chaves estrangeiras têm índice, para que JOINs, `ON DELETE SET NULL` e `ON UPDATE CASCADE` não varram tabelas inteiras.

## Gamificação como sinal clínico

Cada idoso tem um bichinho único: escolhe a espécie (passarinho, gato, cachorro, coelho, tartaruga, peixinho), a cor e um enfeite, tudo desenhado em SVG na hora. O pet cresce por fases visuais conforme o nível — filhote, jovem, adulto e sábio — e o idoso vê a trilha inteira do crescimento. Ele ganha pontos por check-ins de bem-estar, participação em atividades e partidas (dominó e os demais jogos) — sempre por transação atômica junto ao registro que o originou, pela função `fn_pontuar_pet`. Por decisão de design, o pet nunca sofre por inatividade: em vez de punir o idoso, a queda no fluxo de `evento_pet` vira um alerta para a equipe. A consulta #6 compara os pontos da última semana com a anterior justamente para isso.

O Dominó do Lar estende a ideia: partidas contra o computador ("Seu Biu") exercitam cognição; partidas na "mesa a dois" entre residentes geram dados de interação social — a rede de quem joga com quem, cuja rarefação é sinal precoce de isolamento, domínio que o ICOPE e o WHOQOL-OLD mandam observar.

## Jogos

Além do Dominó do Lar, a aba de jogos agora tem um menu com o Jogo da Memória: pares de figuras grandes (frutas, animais, flores), em três níveis (4, 6 ou 8 pares), sem cronômetro nem punição — o ritmo é do jogador. Cada carta é falada em voz alta ao ser virada (Web Speech API), e completar o jogo alimenta o Xodó. A estrutura já está pronta para, no futuro, usar fotos enviadas pela família no lugar das figuras. Também há o Buraco 1×1 contra o computador: baralho duplo (108 cartas), trincas e sequências com curingas (Joker e o 2), canastras limpa (200) e suja (100). A inteligência do computador foi validada em 300 partidas simuladas (planeja canastras, joga de forma equilibrada). Interface acessível com cartas grandes e seleção por toque. Multiplayer online entre pessoas fica para quando o sistema estiver hospedado.

Há ainda dois jogos: "Cuidar do Xodó", em que o bichinho pede comida, água, carinho, soneca, banho ou brincadeira e a pessoa escolhe o que ele precisa (afetivo e simples, o pet vira protagonista); e o Paciência (Klondike) clássico, com as sete colunas, quatro fundações por naipe e a interface de tocar-origem-tocar-destino. Ambos alimentam o pet. O motor do paciência tem 18 testes de regras validados.

Memória, Buraco, Paciência e Cuidar do Xodó gravam cada partida em `partida_jogo` (rota `POST /jogos`) — vitória ou jogo concluído vale 30 pontos, derrota 10, abandono 0 — e mostram os pontos no fim. Todo ponto do Xodó passa pela função `fn_pontuar_pet`, que confere quem pode pontuar (o próprio idoso, a equipe da ILPI dele ou o adversário do dominó), grava o evento e atualiza pontos e nível (um nível a cada 100 pontos) na mesma transação. Isso corrigiu três falhas antigas: Memória, Buraco, Paciência e Cuidar do Xodó não davam pontos, check-ins e presenças registrados pela equipe não chegavam ao pet, e o nível nunca subia.

## Prontuário unificado

Uma linha do tempo que reúne, num só lugar, tudo o que foi registrado sobre o residente: check-ins de bem-estar, sinais vitais, intercorrências, refeições, escalas, medicação e metas de cuidado. Os eventos vêm de várias tabelas, são padronizados no servidor e ordenados do mais recente ao mais antigo, agrupados por dia e filtráveis por tipo. Como cada fonte respeita o seu próprio RLS, o prontuário mostra exatamente o que o solicitante tem direito de ver — a equipe da ILPI e a família enxergam o histórico; quem não tem vínculo não vê nem o cabeçalho. É a visão que consolida toda a jornada de cuidado da pessoa.

## Escalas, intercorrências e nutrição

Escalas clínicas guiadas: a equipe aplica GDS-15 (depressão) e Katz (autonomia) pergunta a pergunta, com botões grandes; o servidor soma, interpreta a faixa (ex.: "sugestivo de depressão leve", "dependência parcial") e grava avaliação e itens numa transação. Intercorrências e quedas: registro rápido por tipo (queda, lesão, mal-estar, comportamento, evasão, óbito, outro) e gravidade, com local, conduta e marcação de família avisada — a família visualiza as ocorrências do seu familiar. Controle nutricional: restrições alimentares por residente, registro de aceitação de cada refeição (0–100%) e hidratação, com média de 7 dias e total do dia destacados. Todos entram no histórico com auditoria e seguem o mesmo RLS dos demais dados de saúde.

## Sinais vitais e plano de cuidado

A equipe registra sinais vitais estruturados (pressão, batimentos, temperatura, peso, glicemia, saturação), com validação de faixa fisiológica no banco. Nos cartões de cada residente, gráficos de linha mostram a evolução e destacam em vermelho os pontos fora da faixa de referência — um alerta visual, não um diagnóstico. O plano de cuidado individual (PDI, previsto na RDC 502) reúne metas por categoria (saúde, mobilidade, nutrição, social, cognitiva, emocional, autonomia) com data de revisão e status (em andamento, atingida, suspensa); a família também visualiza as metas, dando transparência ao cuidado. Ambos entram no histórico com auditoria.

## Passagem de plantão

A comunicação interna da equipe entre turnos: recados marcados por turno (manhã/tarde/noite) e prioridade (🟢 rotina, 🟡 atenção, 🔴 urgente), gerais ou sobre um residente. A lista se ordena sozinha pela urgência, cada profissional dá "✓ Li" (ciência registrada para accountability) e recados resolvidos saem da frente. Conteúdo estritamente interno: o RLS garante que nem idosos nem responsáveis o vejam, só a equipe da ILPI. É onde o cuidado deixa de se perder na troca de turno.

## Painel do dia (equipe)

A área da equipe abre com um resumo do dia — check-ins feitos, quem está há 3 dias sem registro, doses de medicação pendentes e atividades marcadas — em bolhas grandes que ficam vermelhas quando algo precisa de ação. Cada residente traz um botão de relatório mensal em PDF, e a agenda mostra a presença confirmada por atividade. É a visão de comando que uma coordenação de ILPI usaria no início do plantão.

## Agenda de atividades

A equipe cria atividades (física, social, cognitiva, artística, espiritual) com data e hora; elas aparecem na aba "📅 Agenda" de cada residente da ILPI. O idoso confirma presença com um toque — o que alimenta o Xodó (+30) e alimenta também os dados de engajamento que a consulta de lazer já consolidava. Presença é registrada em `participacao`, reaproveitando o modelo original.

## Medicação e Mural da Família

O controle de medicação segue o registro exigido pela RDC 502: prescrições com horários (ato restrito a médicos e enfermeiros, imposto por RLS), e a tela "Medicação de hoje" onde a equipe marca cada dose com um toque — doses atrasadas ganham destaque vermelho, e uma constraint UNIQUE no banco impede fisicamente a administração dupla. O Mural da Família liga as pontas afetivas: o responsável escreve um recado no cartão do seu idoso, e ele aparece na aba "💌 Recados" do idoso com um botão "🔊 Ouvir" que lê a mensagem em voz alta — matando saudade mesmo para quem não enxerga bem.

## Consultas analíticas (gestor)

Na área do gestor, a aba "📊 Consultas" lista 8 perguntas — bem-estar médio por residente, quem está sem check-in, histograma da dor, evolução semanal, aceitação alimentar por grau de dependência, intercorrências por tipo e gravidade, adesão à medicação e ranking de engajamento. Cada uma é um SQL executado na hora (`GET /consultas/:id`), com gráfico (barras ou linhas), tabela do resultado, botão para ver o SQL e exportação em CSV. As consultas rodam com a identidade do gestor, então o RLS já limita tudo à ILPI dele. Os SQLs ficam em `api/consultas.js`; `node api/gerar_sql_consultas.js` regera `consultas_etapa03.sql`, garantindo que o arquivo entregue é idêntico ao que a interface executa.

## Edição e remoção (CRUD completo em duas tabelas)

O sistema não apaga histórico clínico — desativa. Duas tabelas são exceções deliberadas, com inserção, edição e remoção pela interface: **recado_mural** (o familiar edita ou apaga o próprio recado; o RLS impede mexer no recado de outra pessoa) e **restricao_alimentar** (a equipe da ILPI adiciona, renomeia e remove). Toda edição e remoção entra na trilha de auditoria por trigger.

## Acessibilidade (WCAG 2.1 AA, foco em maior idade)

A interface usa a fonte Atkinson Hyperlegible (criada pelo Braille Institute para leitores de baixa visão), corpo de 19px ou mais, botões e alvos de toque com no mínimo 48px, alto contraste conferido nos textos coloridos, e nenhuma pressão de tempo em fluxo algum. O cabeçalho traz controles A− / A+ que ampliam toda a interface em até 45%, disponíveis desde a tela de login. Para navegação por teclado, todo elemento interativo tem indicador de foco visível de 4px; para leitores de tela, as mensagens de estado usam regiões `aria-live`, os grupos de escolha (carinhas de humor, escala de dor, abas, residentes, instrumentos) anunciam a seleção com `aria-pressed`/`aria-selected`, os campos têm rótulos programaticamente associados, a barra de nível do pet é um `progressbar` de verdade e o gráfico de humor tem resumo textual invisível. A cor nunca é o único indicador: as pedras jogáveis do dominó, além da borda verde, recebem um selo "✓". A interface respeita `prefers-reduced-motion` e declara o idioma do documento como pt-BR.

Além do suporte a leitores de tela do próprio aparelho (NVDA, TalkBack, VoiceOver), o app traz **leitura em voz alta embutida**: o botão 🔊 do cabeçalho ativa a Web Speech API com voz em português brasileiro e ritmo levemente reduzido, e o app passa a falar as mensagens do dominó ("Sua vez! Toque numa pedra com a borda verde"), o resultado das partidas com os pontos dos bichinhos, as opções escolhidas nas escalas de humor e dor, a troca de abas e o agradecimento do check-in. É um complemento pensado para o idoso com baixa visão que não sabe (ou não quer) configurar um leitor de tela — não um substituto das tecnologias assistivas do sistema.

## Limitações conhecidas e próximos passos

O gestor da ILPI (função `gestor`) tem uma área própria no app para cadastrar residentes, equipe e responsáveis — cada cadastro cria o login com senha via pgcrypto e, no caso do responsável, já faz o vínculo que o RLS exige. Só o gestor cadastra, e apenas na própria ILPI (imposto por RLS e pela API). O gestor também edita dados e desativa/reativa contas — desativar preserva todo o histórico (nunca apaga), bloqueia o login e some das listas operacionais; há trava que impede a ILPI ficar sem gestor. Conta de demonstração: gestor@larpaz.com / demo123.

Antes de colocar dados reais de idosos no sistema, é NECESSÁRIO: servir tudo em HTTPS; definir `JWT_SECRET` e as senhas do banco por variáveis de ambiente (a API avisa no console se o segredo padrão estiver em uso); trocar as contas e senhas de demonstração; implementar **backup automático diário** do PostgreSQL (`pg_dump` agendado) — dados de saúde perdidos são irrecuperáveis; formalizar o consentimento LGPD no fluxo de cadastro (a tabela existe, falta a tela); e validar a interface com os próprios idosos e a equipe. A prescrição registrada no app não substitui a prescrição médica formal — é o registro operacional de administração. Já implementados para uso real: auditoria por trigger (a trilha existe mesmo fora da API), limite de tentativas de login, bloqueio de dose duplicada no banco, e RLS em todas as tabelas sensíveis. Já entregues também: fluxo de consentimento LGPD com revogação (tela do responsável), relatório mensal em PDF por idoso, fila offline que reenvia check-ins e partidas quando a conexão volta, PWA instalável (pasta pwa/), scripts de backup e aviso ao responsável via link de WhatsApp nos alertas. Próximos passos: hospedagem pública (Render/Railway + Neon/Supabase), WhatsApp via API oficial (hoje é link wa.me) e empacotamento com Capacitor para as lojas.
