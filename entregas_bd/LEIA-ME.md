# Entregas — Projeto de Banco de Dados (Bem Viver ILPI)

Modelagem e Projeto de Banco de Dados · Prof. Eduardo Nascimento de Arruda · Lucas Barreto Rodrigues de Barros e Vítor Lima

Cada pasta reúne o que foi pedido naquela etapa. O banco que o app usa é criado pelos scripts da pasta `banco/` (na raiz do projeto), que o instalador roda em ordem; os arquivos das Etapas 04 e 05 aqui são cópias idênticas dos de `banco/`.

## Etapa 01 — Minimundo, modelo conceitual e lógico

| O que o enunciado pede | Arquivo |
|---|---|
| Definição do minimundo | `etapa01/etapa01_minimundo_modelos_dicionario.pdf` (seção 1) |
| Imagem do esquema conceitual | `esquema_conceitual_visao_geral.png` + os 5 módulos com atributos (`esquema_conceitual_moduloN_*.png`); versão única com tudo: `esquema_conceitual_completo.png` |
| Imagem do esquema lógico | `esquema_logico_completo.png` + os 5 módulos (`esquema_logico_moduloN_*.png`) |
| Esquema relacional | PDF, seção 4 |
| Tabela do dicionário de dados | PDF, seção 5 (30 tabelas, 194 atributos, gerado do catálogo do PostgreSQL) |

Os diagramas seguem a notação do brModelo (Chen no conceitual; tabelas com PK/FK no lógico), mas foram gerados por script a partir do banco, não dentro do brModelo. Se o professor exigir o arquivo do próprio brModelo, use estas imagens como gabarito para redesenhar.

## Etapa 02 — Criação das tabelas e inserção de dados

Rodar nesta ordem num banco vazio:

```
psql -U postgres -d NOME_DO_BANCO -f etapa02/etapa02_criacao_tabelas.sql
psql -U postgres -d NOME_DO_BANCO -f etapa02/etapa02_insercao_dados.sql
```

- CHECK, DEFAULT e UNIQUE em todas as tabelas principais — inclusive CPF e CNPJ com dígito verificador (funções `fn_cpf_valido` / `fn_cnpj_valido` dentro do CHECK), e-mail, telefone e UF.
- Coluna gerada: `pet_virtual.nivel` = 1 + pontos / 100.
- Índice em todas as 49 chaves estrangeiras.
- **ON UPDATE CASCADE**: `vinculo_responsavel` e `participacao`.
- **ON DELETE SET NULL**: `idoso.id_usuario`, `registro_bem_estar.id_profissional`, `recado_plantao.id_idoso`.
- Inserção com sequências (`nextval` / `currval`), **mínimo de 30 tuplas em cada uma das 30 tabelas** (o próprio script confere e aborta se faltar).
- `etapa02_demonstracao_acoes_referenciais.sql` mostra o CASCADE e o SET NULL funcionando e desfaz tudo no final (ROLLBACK).

## Etapa 03 — Primeira versão da aplicação + consultas

**Aplicação:** `aplicacao_bemviver_ilpi.zip` traz o projeto inteiro. Se o professor preferir o GitHub, envie um .txt com o link do repositório. Para rodar no Windows (com PostgreSQL e Node.js instalados), três duplos cliques na pasta do projeto: `instalar_windows.bat` (cria o banco), `iniciar_api_windows.bat` (liga a API) e, com a API aberta, `iniciar_app_windows.bat` (abre o app no navegador em http://localhost:5173). Detalhes na seção "Instalação" do `README.md`.

**SQL das consultas:** `etapa03_consultas.sql` — 10 consultas (o mínimo é 4), 9 com JOIN, incluindo CTEs, funções de janela (RANK, PERCENT_RANK, LAG e SUM OVER), LEFT JOIN com generate_series, auto-junção, UNION ALL, NOT EXISTS, subconsulta escalar, COUNT … FILTER e CROSS JOIN LATERAL unnest. Oito delas recebem o período em dias como parâmetro (`$1`): na tela, o gestor escolhe 7, 30 ou 90 dias; no arquivo .sql, cada uma aparece como `PREPARE` + `EXECUTE` com o período padrão.

**Interface**

| Requisito | Onde ver (senha de todas as contas: `demo123`) |
|---|---|
| Inserir, remover e atualizar em pelo menos 2 tabelas | **recado_mural**: entrar como `mariana.filha@email.com` → cartão da Dona Severina → enviar, ✏️ editar e 🗑️ apagar recado. **restricao_alimentar**: entrar como `enf.patricia@larpaz.com` → 🍎 Nutrição de um residente → adicionar, ✏️ renomear e × remover |
| Visualização de dados com gráficos e resultado das consultas | entrar como `gestor@larpaz.com` → aba **📊 Consultas**: cada consulta mostra gráfico (barras ou linhas), tabela do resultado, botão "Ver o SQL" e "Baixar CSV" |
| Pelo menos 4 consultas, 1 com JOIN | as 10 da aba 📊 Consultas (com seletor de período) |

**Backend: linguagem de programação integrada ao SGBD, com SQL explícito**

- Linguagem: **JavaScript (Node.js)** com o driver oficial do PostgreSQL, **`pg` (node-postgres)** — o equivalente do JDBC no Node. Não há ORM.
- Todo comando SQL está escrito por extenso no código: `api/server.js` (cerca de 95 chamadas `query(...)` com INSERT, SELECT, UPDATE e DELETE) e `api/consultas.js` (as 10 consultas).
- Parâmetros sempre passados separados do SQL (`$1, $2…`), o que impede injeção de SQL — o mesmo papel do `PreparedStatement` no JDBC.
- Transações explícitas: cada requisição roda entre `BEGIN` e `COMMIT` (ou `ROLLBACK` em erro), com a identidade do usuário passada ao banco (`set_config('app.id_usuario', …)`). As permissões são aplicadas pelo próprio PostgreSQL (Row-Level Security em todas as 30 tabelas).

Exemplo do código (`api/server.js`, cadastro de partida):

```js
const { rows } = await c.query(
  `INSERT INTO partida_jogo (id_idoso, jogo, resultado, pontuacao, jogadas)
   VALUES ($1, $2, $3, $4, $5) RETURNING id_partida_jogo`,
  [eu[0].id, jogo, resultado, inteiroOuNulo(pontuacao), inteiroOuNulo(jogadas)]);
```

## Etapa 04 — Consultas avançadas, visões e índices

Rodar num banco já instalado (o `instalar_*` faz isso sozinho, no passo 6):

```
psql -U postgres -d ilpi -f etapa04/etapa04_indices_e_visoes.sql
psql -U postgres -d ilpi -f etapa04/etapa04_consultas.sql
```

| O que o enunciado pede | Onde está |
|---|---|
| 2 índices novos, usados nas consultas/visões | `ix_intercorrencia_data` (intercorrências por período, sem filtrar residente — usado na consulta 12 e na visão 2) e `ix_meta_ativa_revisao` (índice parcial só das metas ativas, por data de revisão — usado na consulta 14). O final de `etapa04_consultas.sql` mostra os dois no `EXPLAIN` |
| 1 consulta com anti join | Consulta 11: residentes sem aferição de sinais vitais em 7 dias (`LEFT JOIN ... WHERE s.id_sinal IS NULL`) |
| 1 consulta com full outer join | Consulta 12: intercorrências × recados de plantão por residente (mostra as falhas de comunicação entre turnos) |
| 2 consultas com subconsultas | Consulta 13: dor acima da média da própria ILPI (subconsulta correlacionada no SELECT e no HAVING). Consulta 14: agenda de revisão do plano de cuidado (subconsultas escalares + IN) |
| 2 visões com pelo menos 3 joins e justificativa | `vw_mapa_medicacao` (5 tabelas: prescrição, residente, ILPI, prescritor, administrações) e `vw_intercorrencia_contato` (6 tabelas: intercorrência, residente, ILPI, profissional, vínculo e responsável legal). A justificativa está no comentário acima de cada uma |

As mesmas consultas e visões aparecem na aba **📊 Consultas** do gestor, pelo título (com período e filtro escolhidos na tela). O SQL exato que a interface executa, com os parâmetros, está em `etapa04/etapa04_consultas_na_interface.sql` (gerado de `api/consultas.js`).

## Etapa 05 — Funções, procedimentos e triggers

```
psql -U postgres -d ilpi -f etapa05/etapa05_funcoes_procedimentos_triggers.sql
psql -U postgres -d ilpi -f etapa05/etapa05_demonstracao.sql
```

O primeiro arquivo cria os objetos (o instalador já roda); o segundo testa cada um entre `BEGIN` e `ROLLBACK`, então pode ser executado várias vezes sem alterar os dados.

| O que o enunciado pede | Objeto | Para que serve |
|---|---|---|
| Função com estrutura condicional | `fn_classificar_pressao(sis, dia)` | Classifica a pressão pelas faixas da Diretriz Brasileira de Hipertensão (IF/ELSIF) |
| Segunda função | `fn_cuidadores_necessarios(id_ilpi)` | Quantos cuidadores por turno a ILPI precisa, pelas proporções da RDC 502/2021 (1 para 20, 10 ou 6 residentes, conforme o grau) |
| Procedimento de atualização | `sp_desligar_residente(id_idoso)` | Alta/óbito: inativa o residente e a conta, encerra as prescrições ativas e suspende as metas, tudo na mesma transação |
| Procedimento com cursor | `sp_distribuir_cuidadores(id_ilpi, refazer)` | Distribui os residentes entre os cuidadores pela carga de trabalho (grau I = 3, II = 6, III = 10 pontos). Precisa de cursor porque cada escolha depende das anteriores; a demonstração mostra que um UPDATE único mandaria todos para o mesmo cuidador |
| Trigger | `trg_alerta_sinal_vital` | Depois de cada aferição, se algum sinal estiver fora da faixa, cria sozinho um recado urgente/atenção na passagem de plantão |
| Trigger que atualiza tabela de log | `trg_log_grau_dependencia` → `log_grau_dependencia` | Guarda cada mudança de grau de dependência: grau anterior, novo, quem mudou, quando e quantos cuidadores a ILPI passou a precisar |

Para o procedimento com cursor, o residente ganhou a coluna `id_cuidador_referencia` (cuidador de referência). Os dois triggers já funcionam pela aplicação atual: registrar sinais vitais alterados faz o alerta aparecer na tela do plantão, e o gestor mudar o grau de um residente grava o log.

## Etapa 06 — Interface funcional com dashboard (versão final)

Instalação igual à da Etapa 03 (`instalar_windows.bat` → `iniciar_api_windows.bat` → `iniciar_app_windows.bat`); o instalador já aplica as Etapas 04 e 05 e as permissões de exclusão do CRUD (`banco/etapa06_exclusao_crud.sql`). Senha de todas as contas: `demo123`. Backend em Node.js (liberado pelo professor), sem ORM: todo comando é SQL escrito no código e enviado ao banco com parâmetros.

| O que o enunciado pede | Onde ver |
|---|---|
| CRUD em pelo menos 4 tabelas | **recado_mural** (responsável `mariana.filha@email.com`: enviar, ✏️ editar, 🗑️ apagar recado) · **restricao_alimentar** (`enf.patricia@larpaz.com` → 🍎 Nutrição: adicionar, renomear, remover) · **recado_plantao** (`enf.patricia@larpaz.com` → Passagem de plantão: + Recado, ✏️ editar e 🗑️ excluir os seus) · **atividade_lazer** (equipe → Agenda: criar, ✏️ editar, 🗑️ excluir atividade sem presenças). Além disso, idoso e profissional têm cadastro, edição e desligamento na aba 👥 Pessoas do gestor |
| Executar ou ver os efeitos de funções, procedimentos e triggers | `fn_classificar_pressao`: classificação da última pressão nos sinais vitais do residente e gráfico 8 do dashboard · `fn_cuidadores_necessarios`: indicador "Cuidadores por turno (RDC 502)" e aba 🤝 Cuidadores · `sp_desligar_residente`: botão Desativar de um residente (aba 👥 Pessoas), com a explicação e as mensagens do procedimento · `sp_distribuir_cuidadores` (cursor): aba 🤝 Cuidadores, botões de distribuir/refazer, com o passo a passo devolvido pelo banco; também roda sozinho quando um cuidador é desativado · `trg_alerta_sinal_vital`: registrar sinais muito alterados gera o recado "🤖 automático" no plantão · `trg_log_grau_dependencia`: ✏️ editar residente mostra o histórico do grau |
| Consultas e visões das Etapas 03 e 04 na interface, com filtros/parâmetros | aba **📊 Consultas** (gestor): as 16 perguntas aparecem agrupadas por assunto (Bem-estar; Saúde e medicação; Ocorrências e comunicação; Rotina, convivência e plano de cuidado), sem referência às etapas. As da Etapa 04 são: *Residentes sem aferição de sinais vitais* (anti join), *Intercorrências × recados de plantão* (full outer join), *Dor acima da média da própria ILPI* e *Agenda de revisão do plano de cuidado* (subconsultas), *Mapa de medicação da semana* (visão `vw_mapa_medicacao`) e *Intercorrências e quem avisar* (visão `vw_intercorrencia_contato`). Cada uma tem período e filtros quando faz sentido (grau, categoria da meta, só prescrições abaixo do previsto, só família não avisada), gráfico (barras, linhas ou pizza), tabela, "Ver o SQL" e CSV |
| Dashboard estatístico com dados do banco | aba **📈 Dashboard** (gestor `gestor@larpaz.com`, abre por padrão) |
| Indicadores resumidos | residentes, check-ins, % com check-in, humor e dor médios com a variação em relação ao período anterior, intercorrências (com variação), adesão à medicação, aceitação alimentar e cuidadores na equipe × exigidos |
| Pelo menos 6 gráficos dinâmicos | 8 gráficos: (1) histograma com média, mediana, moda, variância, desvio padrão e coeficiente de variação; (2) tendência no tempo com reta de regressão (`regr_slope`); (3) rosca de residentes por grau; (4) pizza de intercorrências por tipo; (5) radar de participação por categoria de atividade, atual × anterior; (6) dispersão atividades × humor com correlação de Pearson (`corr`) e reta de regressão; (7) colunas de aceitação alimentar por refeição; (8) barras da pressão arterial por classificação |
| Visualizações interativas com filtros | período (7, 30, 90, 180 dias), grau de dependência (botões ou clicando na fatia da rosca) e medida analisada (humor, conforto, dor). Cada gráfico tem o botão "🧾 SQL" com o comando que o gerou |

Todos os cálculos estatísticos são feitos pelo PostgreSQL (`avg`, `percentile_cont`, `mode()`, `var_samp`, `stddev_samp`, `corr`, `regr_slope`, `regr_intercept`, `regr_r2`). Os SQLs ficam em `api/dashboard.js`; o arquivo `etapa06/etapa06_sql_dashboard.sql` traz os mesmos comandos prontos para rodar no psql/pgAdmin.
