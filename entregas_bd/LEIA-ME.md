# Entregas — Projeto de Banco de Dados (Bem Viver ILPI)

Modelagem e Projeto de Banco de Dados · Prof. Eduardo Nascimento de Arruda · Lucas Barreto Rodrigues de Barros

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

**Aplicação:** `aplicacao_bemviver_ilpi.zip` traz o projeto inteiro. Se o professor preferir o GitHub, envie um .txt com o link do repositório. Para rodar: siga a seção "Instalação" do `README.md` dentro do zip.

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
