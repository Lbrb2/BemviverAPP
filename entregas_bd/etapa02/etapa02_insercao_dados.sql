-- ============================================================
-- ENTREGA ETAPA 02 — SQL DE INSERÇÃO DE DADOS
-- Projeto: Bem Viver ILPI · SGBD: PostgreSQL 16
-- Executar depois de etapa02_criacao_tabelas.sql.
-- * No mínimo 30 tuplas em CADA uma das 30 tabelas — o bloco final
--   "Conferência" aborta a transação se alguma tabela ficar abaixo disso.
-- * Ids gerados por sequência: nextval('<tabela>_<coluna>_seq') nas linhas
--   novas e currval(...) para as tabelas filhas apontarem ao registro
--   recém-criado (idoso -> pet, avaliação -> itens, prescrição -> doses...).
-- ============================================================

-- ============================================================
-- Seed: dados de exemplo para testes e para a disciplina de BD
-- Plataforma de Acompanhamento de Idosos em ILPIs (PE)
-- Executar após schema_ilpi.sql
--
-- PARTE 1 — cenário original com ids explícitos (contas de demonstração).
-- PARTE 2 — dados complementares: no mínimo 30 tuplas em CADA tabela.
--           Os ids vêm das sequências (nextval/DEFAULT) e as tabelas
--           filhas usam currval() para apontar ao registro recém-criado.
-- Todos os dados pessoais são fictícios (CPFs e CNPJs gerados com
-- dígito verificador válido, mas não pertencem a ninguém).
-- ============================================================

BEGIN;
SET LOCAL TIME ZONE 'America/Recife';  -- horários de medicação em hora local

-- ---------- ILPIs ----------
INSERT INTO ilpi (id_ilpi, cnpj, nome, municipio, licenca_anvisa) VALUES
 (1, '11222333000181', 'Lar Recanto da Paz',        'Recife',  'LIC-PE-2024-0117'),
 (2, '44555666000181', 'Casa de Repouso Boa Vista', 'Caruaru', 'LIC-PE-2023-0842');

-- ---------- Usuários ----------
INSERT INTO usuario (id_usuario, email, senha_hash, perfil) VALUES
 (1,  'dona.severina@email.com',   'hash_exemplo', 'idoso'),
 (2,  'seu.expedito@email.com',    'hash_exemplo', 'idoso'),
 (3,  'mariana.filha@email.com',   'hash_exemplo', 'responsavel'),
 (4,  'carlos.sobrinho@email.com', 'hash_exemplo', 'responsavel'),
 (5,  'joana.neta@email.com',      'hash_exemplo', 'responsavel'),
 (6,  'enf.patricia@larpaz.com',   'hash_exemplo', 'profissional'),
 (7,  'psic.rodrigo@larpaz.com',   'hash_exemplo', 'profissional'),
 (8,  'cuid.marcos@larpaz.com',    'hash_exemplo', 'profissional'),
 (9,  'enf.lucia@boavista.com',    'hash_exemplo', 'profissional'),
 (10, 'gestor@larpaz.com',         'hash_exemplo', 'profissional');

-- ---------- Idosos ----------
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia) VALUES
 (1, 1, 1,    'Severina Maria da Conceição', '11144477735', '1942-03-15', '2023-06-10', 'II'),
 (2, 1, 2,    'Expedito José dos Santos',    '22255588846', '1950-11-02', '2024-01-20', 'I'),
 (3, 1, NULL, 'Terezinha Alves Barbosa',     '33366699957', '1938-07-25', '2022-09-05', 'III'),
 (4, 2, NULL, 'Manoel Ferreira Lima',        '44477700083', '1947-01-30', '2024-08-12', 'I');

-- ---------- Responsáveis e vínculos ----------
INSERT INTO responsavel (id_responsavel, id_usuario, nome, telefone) VALUES
 (1, 3, 'Mariana Conceição Silva', '81988887777'),
 (2, 4, 'Carlos Eduardo Santos',   '81977776666'),
 (3, 5, 'Joana Barbosa Freire',    '81966665555');

INSERT INTO vinculo_responsavel (id_idoso, id_responsavel, parentesco, responsavel_legal) VALUES
 (1, 1, 'filha',    TRUE),
 (2, 2, 'sobrinho', TRUE),
 (3, 3, 'neta',     TRUE),
 (1, 3, 'amiga da família', FALSE); -- um idoso pode ter mais de um acompanhante

-- ---------- Profissionais ----------
INSERT INTO profissional (id_profissional, id_ilpi, id_usuario, nome, funcao, registro_conselho) VALUES
 (1, 1, 6, 'Patrícia Andrade',  'enfermeiro', 'COREN-PE 123456'),
 (2, 1, 7, 'Rodrigo Cavalcanti','psicologo',  'CRP-02/45678'),
 (3, 1, 8, 'Marcos Vinícius',   'cuidador',   NULL),
 (4, 2, 9, 'Lúcia Bezerra',     'enfermeiro', 'COREN-PE 654321'),
 (5, 1, 10,'Antônio Gestor',   'gestor',     NULL);

-- ---------- Avaliações padronizadas ----------
-- Katz (0-6): independência em atividades básicas
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, observacoes) VALUES
 (1, 1, 1, 'KATZ',  now() - INTERVAL '90 days', 4, 'Dependência parcial para banho e vestir-se'),
 (2, 1, 1, 'KATZ',  now() - INTERVAL '10 days', 4, 'Quadro estável'),
 (3, 1, 2, 'GDS15', now() - INTERVAL '30 days', 6, 'Sugestivo de depressão leve; iniciar acompanhamento'),
 (4, 2, 1, 'KATZ',  now() - INTERVAL '60 days', 6, 'Totalmente independente'),
 (5, 3, 1, 'ICOPE', now() - INTERVAL '15 days', NULL, 'Triagem ICOPE: declínio em mobilidade e cognição');

INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
 (3, 'humor',      'Sente-se triste com frequência',        1),
 (3, 'humor',      'Abandonou muitas atividades',           1),
 (5, 'mobilidade', 'Não conseguiu levantar da cadeira 5x',  0),
 (5, 'cognicao',   'Dificuldade em lembrar 3 palavras',     0),
 (5, 'nutricao',   'Sem perda de peso relevante',           1);

-- ---------- Check-ins de bem-estar (últimos dias) ----------
INSERT INTO registro_bem_estar (id_idoso, id_profissional, data_hora, humor, conforto, dor, observacoes) VALUES
 (1, NULL, now() - INTERVAL '6 days', 2, 3, 4, 'Sentiu falta da visita da filha'),
 (1, NULL, now() - INTERVAL '4 days', 3, 4, 2, NULL),
 (1, NULL, now() - INTERVAL '2 days', 4, 4, 1, 'Participou do forró e adorou'),
 (1, NULL, now() - INTERVAL '1 day',  4, 5, 1, NULL),
 (2, NULL, now() - INTERVAL '3 days', 5, 5, 0, NULL),
 (2, NULL, now() - INTERVAL '1 day',  4, 4, 0, NULL),
 (3, 3,    now() - INTERVAL '8 days', 3, 3, 5, 'Registro feito pelo cuidador; dor no joelho');
 -- Terezinha (3) está há 8 dias sem check-in: deve aparecer no alerta
 -- Manoel (4) nunca registrou: também deve aparecer

-- ---------- Registros de saúde ----------
INSERT INTO registro_saude (id_idoso, id_profissional, tipo, data_hora, descricao) VALUES
 (1, 1, 'sinais_vitais',  now() - INTERVAL '1 day',  'PA 130x85, FC 78, afebril'),
 (3, 1, 'intercorrencia', now() - INTERVAL '8 days', 'Queixa de dor no joelho direito; comunicado ao médico'),
 (3, 1, 'consulta',       now() - INTERVAL '5 days', 'Avaliação ortopédica; prescrito analgésico');

-- ---------- Acompanhamento psicológico ----------
INSERT INTO atendimento_psicologico (id_idoso, id_profissional, data_hora, evolucao) VALUES
 (1, 2, now() - INTERVAL '20 days', 'Sessão inicial após GDS-15. Paciente receptiva.'),
 (1, 2, now() - INTERVAL '7 days',  'Humor em melhora; vínculo com atividades sociais fortalecido.');

-- ---------- Atividades de lazer ----------
INSERT INTO atividade_lazer (id_atividade, id_ilpi, nome, categoria, data_hora) VALUES
 (1, 1, 'Forró da tarde',          'social',    now() - INTERVAL '2 days'),
 (2, 1, 'Oficina de memória',      'cognitiva', now() - INTERVAL '5 days'),
 (3, 1, 'Alongamento matinal',     'fisica',    now() - INTERVAL '1 day'),
 (4, 2, 'Roda de conversa',        'social',    now() - INTERVAL '3 days'),
 (5, 1, 'Pintura em tela',         'artistica', now() + INTERVAL '2 days'); -- atividade futura

INSERT INTO participacao (id_idoso, id_atividade, nivel_engajamento) VALUES
 (1, 1, 5),
 (1, 2, 3),
 (2, 1, 4),
 (2, 3, 5),
 (4, 4, 3);

-- ---------- Pets virtuais e eventos ----------
-- nivel é coluna gerada (1 + pontos / 100): Xodó fica no nível 3, Fubá no 2
INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos) VALUES
 (1, 1, 'Xodó',    'passarinho', 260),
 (2, 2, 'Fubá',    'gato',       140);

INSERT INTO evento_pet (id_pet, origem, pontos_ganhos, data_hora) VALUES
 (1, 'checkin_bem_estar',      10, now() - INTERVAL '6 days'),
 (1, 'checkin_bem_estar',      10, now() - INTERVAL '4 days'),
 (1, 'participacao_atividade', 30, now() - INTERVAL '2 days'),
 (1, 'checkin_bem_estar',      10, now() - INTERVAL '1 day'),
 (2, 'participacao_atividade', 30, now() - INTERVAL '2 days'),
 (2, 'checkin_bem_estar',      10, now() - INTERVAL '1 day');

-- ---------- LGPD ----------
INSERT INTO consentimento_lgpd (id_idoso, finalidade, data_concessao) VALUES
 (1, 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '1 year'),
 (2, 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '6 months'),
 (3, 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '2 years'),
 (4, 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '10 months');

INSERT INTO log_auditoria (id_usuario, acao, tabela_afetada, id_registro) VALUES
 (6, 'criacao', 'registro_saude', 1),
 (3, 'leitura', 'vw_painel_idoso', 1),
 (7, 'criacao', 'atendimento_psicologico', 1);

-- ---------- Ajustar sequências após inserts com id explícito ----------
-- (a partir daqui, nextval() continua do maior id já usado)
DO $$
BEGIN
    PERFORM setval('ilpi_id_ilpi_seq',                 (SELECT max(id_ilpi) FROM ilpi));
    PERFORM setval('usuario_id_usuario_seq',           (SELECT max(id_usuario) FROM usuario));
    PERFORM setval('idoso_id_idoso_seq',               (SELECT max(id_idoso) FROM idoso));
    PERFORM setval('responsavel_id_responsavel_seq',   (SELECT max(id_responsavel) FROM responsavel));
    PERFORM setval('profissional_id_profissional_seq', (SELECT max(id_profissional) FROM profissional));
    PERFORM setval('avaliacao_id_avaliacao_seq',       (SELECT max(id_avaliacao) FROM avaliacao));
    PERFORM setval('atividade_lazer_id_atividade_seq', (SELECT max(id_atividade) FROM atividade_lazer));
    PERFORM setval('pet_virtual_id_pet_seq',           (SELECT max(id_pet) FROM pet_virtual));
END $$;

-- ############################################################
-- PARTE 2 — DADOS COMPLEMENTARES (>= 30 tuplas por tabela)
-- ############################################################
-- ---------- ILPIs complementares (id gerado pela sequência) ----------
INSERT INTO ilpi (id_ilpi, cnpj, nome, municipio, licenca_anvisa) VALUES
 (nextval('ilpi_id_ilpi_seq'), '25988000000172', 'Lar Sol Nascente', 'Olinda', 'LIC-PE-2024-8333'),
 (nextval('ilpi_id_ilpi_seq'), '78695681000147', 'Casa de Repouso Bom Pastor', 'Jaboatão dos Guararapes', 'LIC-PE-2022-3758'),
 (nextval('ilpi_id_ilpi_seq'), '90668968000183', 'Residencial Flor do Mandacaru', 'Paulista', 'LIC-PE-2025-9480'),
 (nextval('ilpi_id_ilpi_seq'), '83526008000113', 'Lar de Idosos Recanto Feliz', 'Petrolina', 'LIC-PE-2025-9709'),
 (nextval('ilpi_id_ilpi_seq'), '69202768000144', 'Instituto Vovó Amélia', 'Garanhuns', 'LIC-PE-2023-0141'),
 (nextval('ilpi_id_ilpi_seq'), '92437103000131', 'Casa de Acolhida Nossa Senhora das Graças', 'Vitória de Santo Antão', 'LIC-PE-2022-1914'),
 (nextval('ilpi_id_ilpi_seq'), '48552728000152', 'Lar Raio de Luz', 'Cabo de Santo Agostinho', NULL),
 (nextval('ilpi_id_ilpi_seq'), '23160265000152', 'Casa de Repouso Santa Luzia', 'Camaragibe', 'LIC-PE-2025-0288'),
 (nextval('ilpi_id_ilpi_seq'), '75805171000197', 'Residencial Jardim da Saudade', 'Igarassu', 'LIC-PE-2024-3544'),
 (nextval('ilpi_id_ilpi_seq'), '63313617000187', 'Lar de Idosos Novo Amanhecer', 'Gravatá', 'LIC-PE-2024-5796'),
 (nextval('ilpi_id_ilpi_seq'), '57866880000109', 'Instituto Mãos Dadas', 'Serra Talhada', 'LIC-PE-2025-8514'),
 (nextval('ilpi_id_ilpi_seq'), '95592988000131', 'Casa de Acolhida São Vicente de Paulo', 'Arcoverde', 'LIC-PE-2022-5677'),
 (nextval('ilpi_id_ilpi_seq'), '22034628000140', 'Lar Esperança', 'Goiana', 'LIC-PE-2024-4812'),
 (nextval('ilpi_id_ilpi_seq'), '71397604000161', 'Casa de Repouso Sombra e Água Fresca', 'Carpina', 'LIC-PE-2023-9560'),
 (nextval('ilpi_id_ilpi_seq'), '51473104000154', 'Residencial Cantinho do Sertão', 'Belo Jardim', 'LIC-PE-2022-6143'),
 (nextval('ilpi_id_ilpi_seq'), '58793812000111', 'Lar de Idosos Pôr do Sol', 'Santa Cruz do Capibaribe', 'LIC-PE-2025-7017'),
 (nextval('ilpi_id_ilpi_seq'), '22171427000195', 'Instituto Morada da Paz', 'Pesqueira', 'LIC-PE-2025-9696'),
 (nextval('ilpi_id_ilpi_seq'), '84416889000182', 'Casa de Acolhida Asa Branca', 'Limoeiro', 'LIC-PE-2025-2007'),
 (nextval('ilpi_id_ilpi_seq'), '67102035000102', 'Lar Coração de Maria', 'Surubim', 'LIC-PE-2025-6623'),
 (nextval('ilpi_id_ilpi_seq'), '80417695000140', 'Casa de Repouso Beira-Rio', 'Bezerros', NULL),
 (nextval('ilpi_id_ilpi_seq'), '44714533000100', 'Residencial Frei Damião', 'Palmares', 'LIC-PE-2025-9340'),
 (nextval('ilpi_id_ilpi_seq'), '74315788000161', 'Lar de Idosos Primavera', 'Escada', 'LIC-PE-2022-9529'),
 (nextval('ilpi_id_ilpi_seq'), '40135217000123', 'Instituto Monte Sião', 'Ipojuca', 'LIC-PE-2023-0900'),
 (nextval('ilpi_id_ilpi_seq'), '80224935000190', 'Casa de Acolhida Luar do Sertão', 'São Lourenço da Mata', 'LIC-PE-2022-7135'),
 (nextval('ilpi_id_ilpi_seq'), '73087744000169', 'Lar Bem-Querer', 'Abreu e Lima', 'LIC-PE-2023-7998'),
 (nextval('ilpi_id_ilpi_seq'), '40726097000139', 'Casa de Repouso Santa Clara', 'Salgueiro', 'LIC-PE-2022-7584'),
 (nextval('ilpi_id_ilpi_seq'), '73002611000142', 'Residencial Girassol', 'Ouricuri', 'LIC-PE-2024-9271'),
 (nextval('ilpi_id_ilpi_seq'), '63966306000117', 'Lar de Idosos Acalanto', 'Timbaúba', 'LIC-PE-2024-9080');

-- ---------- Usuários complementares: idosos com acesso ao app, responsáveis e equipe ----------
-- Todos recebem a senha de demonstração 'demo123' em api/setup_api.sql.
INSERT INTO usuario (id_usuario, email, senha_hash, perfil) VALUES
 (nextval('usuario_id_usuario_seq'), 'manoel.lins@email.com', 'hash_exemplo', 'idoso'),
 (nextval('usuario_id_usuario_seq'), 'sebastiao.santos@email.com', 'hash_exemplo', 'idoso'),
 (nextval('usuario_id_usuario_seq'), 'iracema.monteiro@email.com', 'hash_exemplo', 'idoso'),
 (nextval('usuario_id_usuario_seq'), 'raimundo.nascimento@email.com', 'hash_exemplo', 'idoso'),
 (nextval('usuario_id_usuario_seq'), 'joao.bezerra@email.com', 'hash_exemplo', 'idoso'),
 (nextval('usuario_id_usuario_seq'), 'dalva.tavares@email.com', 'hash_exemplo', 'idoso'),
 (nextval('usuario_id_usuario_seq'), 'antonio.vasconcelos@email.com', 'hash_exemplo', 'idoso'),
 (nextval('usuario_id_usuario_seq'), 'benedito.rego@email.com', 'hash_exemplo', 'idoso'),
 (nextval('usuario_id_usuario_seq'), 'quiteria.lins@email.com', 'hash_exemplo', 'idoso'),
 (nextval('usuario_id_usuario_seq'), 'katia.freitas@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'fabio.correia@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'larissa.melo@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'fabio.brandao@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'juliana.bezerra@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'camila.nascimento@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'carla.vasconcelos@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'camila.barbosa@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'debora.melo@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'aline.wanderley@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'danilo.ferreira@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'katia.lins@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'rafael.silva@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'patricia.pereira@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'rafaela.galvao@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'carla.aragao@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'gustavo.ferreira@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'eduardo.albuquerque@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'vinicius.vasconcelos@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'fabio.tavares@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'marcelo.freitas@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'simone.albuquerque@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'ricardo.brandao@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'vanessa.nascimento@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'leonardo.silva@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'aline.gomes@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'aline.aragao@email.com', 'hash_exemplo', 'responsavel'),
 (nextval('usuario_id_usuario_seq'), 'luana.santos@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'ricardo.lima@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'katia.rego@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'camila.silva@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'luana.nascimento@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'bruno.monteiro@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'camila.monteiro@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'fernanda.rego@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'katia.brandao@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'larissa.lima@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'patricia.tavares@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'rodrigo.tavares@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'tatiane.cavalcanti@larpaz.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'gestor@boavista.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'carla.bezerra@boavista.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'bruna.siqueira@boavista.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'camila.ferreira@boavista.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'vanessa.melo@boavista.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'larissa.ferreira@boavista.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'rafaela.lins@boavista.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'thiago.santos@boavista.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'gestor@solnascente.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'vanessa.monteiro@solnascente.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'aline.aragao@solnascente.com', 'hash_exemplo', 'profissional'),
 (nextval('usuario_id_usuario_seq'), 'vinicius.rego@solnascente.com', 'hash_exemplo', 'profissional');

-- ---------- Idosos complementares + Xodó de cada um (currval reaproveita o id recém-gerado) ----------
-- Cada idoso ativo ganha seu pet virtual logo em seguida: pet_virtual.id_idoso
-- usa currval('idoso_id_idoso_seq'), o valor que a sequência acabou de entregar.
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, 11, 'Manoel Messias Brandão Lins', '96424867333', (CURRENT_DATE - INTERVAL '89 years' - INTERVAL '250 days')::date, CURRENT_DATE - 1833, 'I', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Bolinha', 'peixe', 640, 'chapeu', 'laranja');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, 12, 'Sebastião da Silva dos Santos', '80399099611', (CURRENT_DATE - INTERVAL '93 years' - INTERVAL '173 days')::date, CURRENT_DATE - 2065, 'I', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Jabuti', 'passarinho', 670, 'chapeu', 'amarelo');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, 13, 'Iracema Lins Monteiro', '64896852052', (CURRENT_DATE - INTERVAL '95 years' - INTERVAL '39 days')::date, CURRENT_DATE - 1838, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Cuscuz', 'gato', 740, 'oculos', 'amarelo');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, 14, 'Raimundo Queiroz Nascimento', '59140393470', (CURRENT_DATE - INTERVAL '70 years' - INTERVAL '131 days')::date, CURRENT_DATE - 1855, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Sanfona', 'cachorro', 650, 'flor', 'rosa');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, NULL, 'Manoel Messias Brandão Araújo', '29654718472', (CURRENT_DATE - INTERVAL '91 years' - INTERVAL '266 days')::date, CURRENT_DATE - 2022, 'III', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Fubá', 'coelho', 260, 'flor', 'verde');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, 15, 'João Batista Monteiro Bezerra', '30893578363', (CURRENT_DATE - INTERVAL '90 years' - INTERVAL '322 days')::date, CURRENT_DATE - 659, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Canjica', 'tartaruga', 730, NULL, 'rosa');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, 16, 'Dalva da Silva Tavares', '68689711333', (CURRENT_DATE - INTERVAL '69 years' - INTERVAL '109 days')::date, CURRENT_DATE - 874, 'I', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Lulu', 'peixe', 870, NULL, 'verde');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, 17, 'Antônio Carlos Rêgo Vasconcelos', '81777184878', (CURRENT_DATE - INTERVAL '86 years' - INTERVAL '123 days')::date, CURRENT_DATE - 693, 'I', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Baião', 'passarinho', 860, NULL, 'verde');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, 18, 'Benedito Siqueira Rêgo', '62826907816', (CURRENT_DATE - INTERVAL '72 years' - INTERVAL '260 days')::date, CURRENT_DATE - 973, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Pipoca', 'gato', 530, 'flor', 'rosa');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, 19, 'Quitéria Melo Lins', '41211543633', (CURRENT_DATE - INTERVAL '69 years' - INTERVAL '64 days')::date, CURRENT_DATE - 1771, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Mel', 'cachorro', 770, 'oculos', 'amarelo');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, NULL, 'Antônio Carlos Maciel Siqueira', '64514075426', (CURRENT_DATE - INTERVAL '90 years' - INTERVAL '138 days')::date, CURRENT_DATE - 1659, 'III', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Rapadura', 'coelho', 270, 'flor', 'laranja');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, NULL, 'Maria das Dores Lima Gomes', '21396045120', (CURRENT_DATE - INTERVAL '88 years' - INTERVAL '250 days')::date, CURRENT_DATE - 360, 'I', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Zé', 'tartaruga', 150, NULL, 'rosa');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, NULL, 'Maria das Dores Bezerra Rêgo', '12746877210', (CURRENT_DATE - INTERVAL '96 years' - INTERVAL '347 days')::date, CURRENT_DATE - 2009, 'I', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Luar', 'peixe', 310, 'flor', 'azul');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, NULL, 'Amara Pereira Cavalcanti', '60098947788', (CURRENT_DATE - INTERVAL '74 years' - INTERVAL '186 days')::date, CURRENT_DATE - 690, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Cocada', 'passarinho', 140, 'gravata', 'verde');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, NULL, 'Iracema Melo Pereira', '74233341033', (CURRENT_DATE - INTERVAL '78 years' - INTERVAL '272 days')::date, CURRENT_DATE - 344, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Nego', 'gato', 310, 'oculos', 'laranja');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, NULL, 'Josefa Correia Barbosa', '79603251895', (CURRENT_DATE - INTERVAL '67 years' - INTERVAL '276 days')::date, CURRENT_DATE - 1910, 'III', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Pirulito', 'cachorro', 260, NULL, 'amarelo');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, NULL, 'Biu Monteiro Lins', '12197931407', (CURRENT_DATE - INTERVAL '72 years' - INTERVAL '310 days')::date, CURRENT_DATE - 955, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Caju', 'coelho', 390, 'oculos', 'laranja');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, NULL, 'Raimunda Albuquerque Barbosa', '51872864473', (CURRENT_DATE - INTERVAL '81 years' - INTERVAL '78 days')::date, CURRENT_DATE - 1802, 'II', FALSE);
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 1, NULL, 'Sebastião Gomes Nascimento', '46943803115', (CURRENT_DATE - INTERVAL '75 years' - INTERVAL '73 days')::date, CURRENT_DATE - 1139, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Sabiá', 'peixe', 410, NULL, 'laranja');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 2, NULL, 'Antônio Carlos Queiroz Wanderley', '60218946180', (CURRENT_DATE - INTERVAL '75 years' - INTERVAL '293 days')::date, CURRENT_DATE - 1394, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Biscoito', 'passarinho', 170, NULL, 'laranja');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 2, NULL, 'Quitéria Brandão Maciel', '95546299584', (CURRENT_DATE - INTERVAL '81 years' - INTERVAL '17 days')::date, CURRENT_DATE - 447, 'III', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Forrozinho', 'gato', 140, 'chapeu', 'azul');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 2, NULL, 'Zuleide de Oliveira Tavares', '53808930667', (CURRENT_DATE - INTERVAL '75 years' - INTERVAL '91 days')::date, CURRENT_DATE - 171, 'I', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Chiquinho', 'cachorro', 80, NULL, 'azul');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 2, NULL, 'Dalva Vasconcelos Freitas', '95019200115', (CURRENT_DATE - INTERVAL '77 years' - INTERVAL '276 days')::date, CURRENT_DATE - 509, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Pingo', 'coelho', 70, 'gravata', 'azul');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 2, NULL, 'Severina Rêgo Siqueira', '71185569472', (CURRENT_DATE - INTERVAL '82 years' - INTERVAL '65 days')::date, CURRENT_DATE - 1158, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Branquinha', 'tartaruga', 160, 'laco', 'amarelo');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 2, NULL, 'Francisca Maciel Araújo', '56820820950', (CURRENT_DATE - INTERVAL '74 years' - INTERVAL '95 days')::date, CURRENT_DATE - 494, 'II', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Mimosa', 'peixe', 160, 'gravata', NULL);
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 2, NULL, 'Sebastião Aragão Maciel', '79357750797', (CURRENT_DATE - INTERVAL '70 years' - INTERVAL '95 days')::date, CURRENT_DATE - 2135, 'I', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Xodó', 'passarinho', 120, 'gravata', 'amarelo');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 3, NULL, 'Zuleide de Oliveira Nascimento', '27329213942', (CURRENT_DATE - INTERVAL '80 years' - INTERVAL '211 days')::date, CURRENT_DATE - 1109, 'I', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Tico', 'gato', 60, 'gravata', 'rosa');
INSERT INTO idoso (id_idoso, id_ilpi, id_usuario, nome, cpf, data_nascimento, data_admissao, grau_dependencia, ativo) VALUES
 (nextval('idoso_id_idoso_seq'), 3, NULL, 'Socorro Rêgo Araújo', '11656782847', (CURRENT_DATE - INTERVAL '67 years' - INTERVAL '250 days')::date, CURRENT_DATE - 455, 'I', TRUE);
  INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos, acessorio, cor) VALUES
   (nextval('pet_virtual_id_pet_seq'), currval('idoso_id_idoso_seq'), 'Pitoco', 'cachorro', 80, 'oculos', NULL);
INSERT INTO pet_virtual (id_pet, id_idoso, nome, especie, pontos) VALUES
 (nextval('pet_virtual_id_pet_seq'), 3, 'Sabiá', 'passarinho', 380);

-- ---------- Profissionais complementares ----------
INSERT INTO profissional (id_profissional, id_ilpi, id_usuario, nome, funcao, registro_conselho) VALUES
 (nextval('profissional_id_profissional_seq'), 1, 47, 'Luana dos Santos', 'cuidador', NULL),
 (nextval('profissional_id_profissional_seq'), 1, 48, 'Ricardo Lima', 'cuidador', NULL),
 (nextval('profissional_id_profissional_seq'), 1, 49, 'Kátia Rêgo', 'cuidador', NULL),
 (nextval('profissional_id_profissional_seq'), 1, 50, 'Camila da Silva', 'cuidador', NULL),
 (nextval('profissional_id_profissional_seq'), 1, 51, 'Luana Nascimento', 'tecnico_enfermagem', 'COREN-PE 261717-TE'),
 (nextval('profissional_id_profissional_seq'), 1, 52, 'Bruno Monteiro', 'tecnico_enfermagem', 'COREN-PE 861920-TE'),
 (nextval('profissional_id_profissional_seq'), 1, 53, 'Camila Monteiro', 'enfermeiro', 'COREN-PE 682581'),
 (nextval('profissional_id_profissional_seq'), 1, 54, 'Fernanda Rêgo', 'medico', 'CRM-PE 35492'),
 (nextval('profissional_id_profissional_seq'), 1, 55, 'Kátia Brandão', 'fisioterapeuta', 'CREFITO-1/289752-F'),
 (nextval('profissional_id_profissional_seq'), 1, 56, 'Larissa Lima', 'nutricionista', 'CRN-6/23425'),
 (nextval('profissional_id_profissional_seq'), 1, 57, 'Patrícia Tavares', 'assistente_social', 'CRESS-4/5365'),
 (nextval('profissional_id_profissional_seq'), 1, 58, 'Rodrigo Tavares', 'cuidador', NULL),
 (nextval('profissional_id_profissional_seq'), 1, 59, 'Tatiane Cavalcanti', 'tecnico_enfermagem', 'COREN-PE 702289-TE'),
 (nextval('profissional_id_profissional_seq'), 2, 60, 'Bruna Pereira', 'gestor', NULL),
 (nextval('profissional_id_profissional_seq'), 2, 61, 'Carla Bezerra', 'psicologo', 'CRP-02/15667'),
 (nextval('profissional_id_profissional_seq'), 2, 62, 'Bruna Siqueira', 'cuidador', NULL),
 (nextval('profissional_id_profissional_seq'), 2, 63, 'Camila Ferreira', 'cuidador', NULL),
 (nextval('profissional_id_profissional_seq'), 2, 64, 'Vanessa Melo', 'tecnico_enfermagem', 'COREN-PE 682761-TE'),
 (nextval('profissional_id_profissional_seq'), 2, 65, 'Larissa Ferreira', 'medico', 'CRM-PE 32057'),
 (nextval('profissional_id_profissional_seq'), 2, 66, 'Rafaela Lins', 'nutricionista', 'CRN-6/10927'),
 (nextval('profissional_id_profissional_seq'), 2, 67, 'Thiago dos Santos', 'fisioterapeuta', 'CREFITO-1/223409-F'),
 (nextval('profissional_id_profissional_seq'), 3, 68, 'Simone Melo', 'gestor', NULL),
 (nextval('profissional_id_profissional_seq'), 3, 69, 'Vanessa Monteiro', 'enfermeiro', 'COREN-PE 366183'),
 (nextval('profissional_id_profissional_seq'), 3, 70, 'Aline Aragão', 'cuidador', NULL),
 (nextval('profissional_id_profissional_seq'), 3, 71, 'Vinícius Rêgo', 'medico', 'CRM-PE 30198');

-- ---------- Responsáveis complementares e vínculos ----------
INSERT INTO responsavel (id_responsavel, id_usuario, nome, telefone) VALUES
 (nextval('responsavel_id_responsavel_seq'), 20, 'Kátia Cavalcanti Freitas', '81952275152'),
 (nextval('responsavel_id_responsavel_seq'), 21, 'Fábio Melo Correia', '81964249537'),
 (nextval('responsavel_id_responsavel_seq'), 22, 'Larissa Lima Melo', '81926030999'),
 (nextval('responsavel_id_responsavel_seq'), 23, 'Fábio Galvão Brandão', '81962217045'),
 (nextval('responsavel_id_responsavel_seq'), 24, 'Juliana Queiroz Bezerra', '81913176036'),
 (nextval('responsavel_id_responsavel_seq'), 25, 'Camila Pereira Nascimento', '81965920005'),
 (nextval('responsavel_id_responsavel_seq'), 26, 'Carla da Silva Vasconcelos', '81985277736'),
 (nextval('responsavel_id_responsavel_seq'), 27, 'Camila Cavalcanti Barbosa', '81915008835'),
 (nextval('responsavel_id_responsavel_seq'), 28, 'Débora Bezerra Melo', '81967011675'),
 (nextval('responsavel_id_responsavel_seq'), 29, 'Aline Bezerra Wanderley', '81942119104'),
 (nextval('responsavel_id_responsavel_seq'), 30, 'Danilo Freitas Ferreira', '81934624539'),
 (nextval('responsavel_id_responsavel_seq'), 31, 'Kátia Freitas Lins', '81944222072'),
 (nextval('responsavel_id_responsavel_seq'), 32, 'Rafael Ferreira da Silva', '81982631920'),
 (nextval('responsavel_id_responsavel_seq'), 33, 'Patrícia Araújo Pereira', '81934065539'),
 (nextval('responsavel_id_responsavel_seq'), 34, 'Rafaela Correia Galvão', '81955729726'),
 (nextval('responsavel_id_responsavel_seq'), 35, 'Carla Rêgo Aragão', '81998297510'),
 (nextval('responsavel_id_responsavel_seq'), 36, 'Gustavo Correia Ferreira', '81939774682'),
 (nextval('responsavel_id_responsavel_seq'), 37, 'Eduardo Galvão Albuquerque', '81958309143'),
 (nextval('responsavel_id_responsavel_seq'), 38, 'Vinícius Ferreira Vasconcelos', '81956129015'),
 (nextval('responsavel_id_responsavel_seq'), 39, 'Fábio Bezerra Tavares', '81983658086'),
 (nextval('responsavel_id_responsavel_seq'), 40, 'Marcelo Maciel Freitas', '81935219816'),
 (nextval('responsavel_id_responsavel_seq'), 41, 'Simone Wanderley Albuquerque', '81957571095'),
 (nextval('responsavel_id_responsavel_seq'), 42, 'Ricardo Queiroz Brandão', '81915034008'),
 (nextval('responsavel_id_responsavel_seq'), 43, 'Vanessa de Oliveira Nascimento', '81928516756'),
 (nextval('responsavel_id_responsavel_seq'), 44, 'Leonardo Cavalcanti da Silva', '81988166830'),
 (nextval('responsavel_id_responsavel_seq'), 45, 'Aline dos Santos Gomes', '81978284809'),
 (nextval('responsavel_id_responsavel_seq'), 46, 'Aline Albuquerque Aragão', '81983482912');
INSERT INTO vinculo_responsavel (id_idoso, id_responsavel, parentesco, responsavel_legal) VALUES
 (5, 4, 'sobrinha', TRUE),
 (6, 5, 'neto', TRUE),
 (7, 6, 'irmã', TRUE),
 (8, 7, 'sobrinho', TRUE),
 (9, 8, 'irmã', TRUE),
 (10, 9, 'filho', TRUE),
 (11, 10, 'genro', TRUE),
 (12, 11, 'nora', TRUE),
 (13, 12, 'neta', TRUE),
 (14, 13, 'sobrinho', TRUE),
 (15, 14, 'neta', TRUE),
 (16, 15, 'irmã', TRUE),
 (17, 16, 'filha', TRUE),
 (18, 17, 'genro', TRUE),
 (19, 18, 'filha', TRUE),
 (20, 19, 'filha', TRUE),
 (21, 20, 'filho', TRUE),
 (22, 21, 'sobrinho', TRUE),
 (23, 22, 'irmão', TRUE),
 (24, 23, 'sobrinha', TRUE),
 (25, 24, 'sobrinho', TRUE),
 (26, 25, 'filha', TRUE),
 (27, 26, 'neta', TRUE),
 (28, 27, 'irmã', TRUE),
 (29, 28, 'neto', TRUE),
 (30, 29, 'filho', TRUE),
 (31, 30, 'nora', TRUE),
 (18, 25, 'afilhada', FALSE),
 (12, 9, 'afilhada', FALSE),
 (20, 25, 'afilhada', FALSE),
 (10, 15, 'cunhada', FALSE),
 (28, 17, 'prima', FALSE),
 (16, 18, 'afilhada', FALSE);

-- ---------- Check-ins de bem-estar complementares (histórico de 45 dias) ----------
-- Mantém os cenários do seed original: Terezinha (3) segue sem check-in
-- recente e Manoel (4) segue sem nenhum, para os alertas continuarem visíveis.
INSERT INTO registro_bem_estar (id_idoso, id_profissional, data_hora, humor, conforto, dor, observacoes) VALUES
 (1, NULL, now() - INTERVAL '7 days 2 hours', 4, 5, 2, 'Animada com o forró'),
 (1, 8, now() - INTERVAL '11 days 7 hours', 3, 3, 3, NULL),
 (1, NULL, now() - INTERVAL '12 days 2 hours', 4, 3, 0, 'Participou da missa'),
 (1, NULL, now() - INTERVAL '13 days 4 hours', 4, 3, 4, 'Dormiu bem'),
 (1, NULL, now() - INTERVAL '15 days 10 hours', 4, 3, 3, NULL),
 (1, NULL, now() - INTERVAL '16 days 10 hours', 3, 4, 2, NULL),
 (1, 8, now() - INTERVAL '20 days 4 hours', 4, 2, 3, NULL),
 (1, 6, now() - INTERVAL '21 days 5 hours', 3, 4, 1, NULL),
 (1, NULL, now() - INTERVAL '23 days 1 hours', 3, 2, 2, NULL),
 (1, 8, now() - INTERVAL '28 days 8 hours', 3, 5, 1, NULL),
 (1, NULL, now() - INTERVAL '29 days 8 hours', 4, 4, 3, NULL),
 (1, NULL, now() - INTERVAL '30 days 9 hours', 4, 3, 1, 'Participou da missa'),
 (1, NULL, now() - INTERVAL '31 days 4 hours', 3, 3, 1, NULL),
 (1, NULL, now() - INTERVAL '32 days 3 hours', 4, 3, 3, NULL),
 (1, NULL, now() - INTERVAL '33 days 3 hours', 3, 3, 2, 'Reclamou do calor'),
 (1, NULL, now() - INTERVAL '34 days 10 hours', 4, 3, 5, 'Dor nas costas pela manhã'),
 (1, NULL, now() - INTERVAL '35 days 3 hours', 3, 5, 3, 'Reclamou do calor'),
 (1, NULL, now() - INTERVAL '37 days 7 hours', 3, 4, 2, 'Pouco apetite no almoço'),
 (1, NULL, now() - INTERVAL '39 days 7 hours', 3, 4, 1, NULL),
 (1, NULL, now() - INTERVAL '44 days 3 hours', 3, 3, 2, 'Animada com o forró'),
 (2, 17, now() - INTERVAL '4 days 2 hours', 5, 5, 1, NULL),
 (2, NULL, now() - INTERVAL '5 days 5 hours', 4, 4, 0, NULL),
 (2, NULL, now() - INTERVAL '6 days 2 hours', 5, 5, 0, NULL),
 (2, NULL, now() - INTERVAL '8 days 8 hours', 5, 5, 1, 'Animada com o forró'),
 (2, 6, now() - INTERVAL '10 days 10 hours', 4, 5, 0, 'Recebeu visita'),
 (2, NULL, now() - INTERVAL '11 days 7 hours', 5, 5, 3, NULL),
 (2, NULL, now() - INTERVAL '14 days 10 hours', 5, 5, 0, 'Recebeu visita'),
 (2, NULL, now() - INTERVAL '15 days 6 hours', 4, 3, 0, 'Dor nas costas pela manhã'),
 (2, NULL, now() - INTERVAL '17 days 7 hours', 4, 4, 0, 'Pouco apetite no almoço'),
 (2, NULL, now() - INTERVAL '19 days 5 hours', 4, 4, 2, 'Animada com o forró'),
 (2, 18, now() - INTERVAL '20 days 9 hours', 4, 4, 0, NULL),
 (2, NULL, now() - INTERVAL '24 days 1 hours', 5, 5, 0, 'Dormiu bem'),
 (2, NULL, now() - INTERVAL '25 days 10 hours', 3, 5, 0, 'Dormiu bem'),
 (2, NULL, now() - INTERVAL '26 days 4 hours', 5, 4, 0, NULL),
 (2, NULL, now() - INTERVAL '27 days 9 hours', 2, 5, 2, NULL),
 (2, NULL, now() - INTERVAL '29 days 9 hours', 5, 4, 2, 'Pouco apetite no almoço'),
 (2, NULL, now() - INTERVAL '30 days 3 hours', 5, 5, 4, 'Reclamou do calor'),
 (2, 18, now() - INTERVAL '32 days 8 hours', 5, 5, 2, NULL),
 (2, NULL, now() - INTERVAL '34 days 9 hours', 4, 5, 0, 'Saudades da família'),
 (2, 6, now() - INTERVAL '37 days 8 hours', 5, 5, 1, 'Reclamou do calor'),
 (2, NULL, now() - INTERVAL '38 days 2 hours', 3, 5, 2, NULL),
 (2, NULL, now() - INTERVAL '40 days 3 hours', 4, 4, 1, 'Participou da missa'),
 (2, 6, now() - INTERVAL '42 days 7 hours', 5, 4, 1, 'Pouco apetite no almoço'),
 (2, NULL, now() - INTERVAL '43 days 10 hours', 5, 5, 0, 'Dor nas costas pela manhã'),
 (3, 18, now() - INTERVAL '9 days 10 hours', 4, 2, 3, NULL),
 (3, 8, now() - INTERVAL '11 days 10 hours', 3, 3, 1, 'Reclamou do calor'),
 (3, 8, now() - INTERVAL '12 days 1 hours', 4, 2, 4, NULL),
 (3, 10, now() - INTERVAL '15 days 7 hours', 3, 4, 3, 'Pouco apetite no almoço'),
 (3, 10, now() - INTERVAL '19 days 10 hours', 2, 4, 2, 'Dormiu bem'),
 (3, 17, now() - INTERVAL '24 days 1 hours', 4, 2, 5, 'Participou da missa'),
 (3, 10, now() - INTERVAL '25 days 7 hours', 3, 2, 4, NULL),
 (3, 8, now() - INTERVAL '29 days 3 hours', 3, 3, 5, NULL),
 (3, 6, now() - INTERVAL '34 days 7 hours', 2, 2, 4, NULL),
 (3, 6, now() - INTERVAL '35 days 10 hours', 3, 5, 4, 'Dor nas costas pela manhã'),
 (3, 9, now() - INTERVAL '38 days 7 hours', 4, 3, 7, NULL),
 (3, 7, now() - INTERVAL '44 days 10 hours', 3, 2, 1, 'Dormiu bem'),
 (5, NULL, now() - INTERVAL '3 hours', 5, 4, 0, 'Saudades da família'),
 (5, NULL, now() - INTERVAL '1 days 4 hours', 4, 3, 0, NULL),
 (5, NULL, now() - INTERVAL '3 days 2 hours', 3, 3, 2, NULL),
 (5, NULL, now() - INTERVAL '4 days 1 hours', 4, 3, 2, NULL),
 (5, NULL, now() - INTERVAL '6 days 9 hours', 3, 3, 1, NULL),
 (5, NULL, now() - INTERVAL '8 days 3 hours', 4, 2, 3, NULL),
 (5, 17, now() - INTERVAL '11 days 2 hours', 2, 2, 2, 'Pouco apetite no almoço'),
 (5, 10, now() - INTERVAL '14 days 4 hours', 4, 4, 1, 'Animada com o forró'),
 (5, NULL, now() - INTERVAL '15 days 2 hours', 3, 3, 0, NULL),
 (5, NULL, now() - INTERVAL '16 days 8 hours', 3, 3, 3, NULL),
 (5, NULL, now() - INTERVAL '17 days 7 hours', 4, 4, 1, NULL),
 (5, NULL, now() - INTERVAL '21 days 6 hours', 3, 3, 1, NULL),
 (5, NULL, now() - INTERVAL '22 days 1 hours', 4, 3, 0, NULL),
 (5, NULL, now() - INTERVAL '25 days 6 hours', 2, 2, 0, 'Dor nas costas pela manhã'),
 (5, NULL, now() - INTERVAL '26 days 2 hours', 2, 3, 0, 'Pouco apetite no almoço'),
 (5, NULL, now() - INTERVAL '29 days 1 hours', 2, 2, 1, 'Reclamou do calor'),
 (5, NULL, now() - INTERVAL '30 days 2 hours', 2, 2, 0, NULL),
 (5, NULL, now() - INTERVAL '31 days 4 hours', 2, 2, 2, 'Reclamou do calor'),
 (5, 7, now() - INTERVAL '33 days 4 hours', 5, 3, 0, 'Animada com o forró'),
 (5, 18, now() - INTERVAL '35 days 7 hours', 3, 3, 0, NULL),
 (5, NULL, now() - INTERVAL '36 days 8 hours', 2, 3, 1, NULL),
 (5, NULL, now() - INTERVAL '39 days 9 hours', 4, 4, 0, NULL),
 (5, NULL, now() - INTERVAL '42 days 8 hours', 2, 3, 1, 'Dor nas costas pela manhã'),
 (5, NULL, now() - INTERVAL '43 days 5 hours', 1, 4, 0, 'Animada com o forró'),
 (5, 11, now() - INTERVAL '44 days 9 hours', 4, 3, 1, 'Recebeu visita'),
 (6, NULL, now() - INTERVAL '5 hours', 4, 4, 4, NULL),
 (6, 9, now() - INTERVAL '2 days 10 hours', 5, 5, 5, 'Pouco apetite no almoço'),
 (6, NULL, now() - INTERVAL '3 days 5 hours', 3, 3, 0, 'Saudades da família'),
 (6, NULL, now() - INTERVAL '4 days 3 hours', 3, 4, 3, NULL),
 (6, NULL, now() - INTERVAL '6 days 7 hours', 3, 5, 7, 'Saudades da família'),
 (6, NULL, now() - INTERVAL '8 days 6 hours', 4, 4, 7, 'Pouco apetite no almoço'),
 (6, NULL, now() - INTERVAL '9 days 2 hours', 3, 4, 4, 'Reclamou do calor'),
 (6, NULL, now() - INTERVAL '11 days 1 hours', 4, 4, 4, NULL),
 (6, NULL, now() - INTERVAL '12 days 9 hours', 5, 3, 3, 'Animada com o forró'),
 (6, NULL, now() - INTERVAL '16 days 3 hours', 4, 4, 2, NULL),
 (6, 3, now() - INTERVAL '17 days 4 hours', 4, 4, 4, NULL),
 (6, NULL, now() - INTERVAL '19 days 6 hours', 3, 5, 7, NULL),
 (6, NULL, now() - INTERVAL '20 days 3 hours', 4, 3, 2, 'Dormiu bem'),
 (6, 17, now() - INTERVAL '21 days 1 hours', 4, 4, 5, 'Dor nas costas pela manhã'),
 (6, NULL, now() - INTERVAL '22 days 10 hours', 5, 3, 4, NULL),
 (6, NULL, now() - INTERVAL '23 days 3 hours', 4, 4, 4, 'Reclamou do calor'),
 (6, 7, now() - INTERVAL '25 days 10 hours', 4, 3, 4, 'Dor nas costas pela manhã'),
 (6, NULL, now() - INTERVAL '32 days 4 hours', 4, 4, 4, 'Dor nas costas pela manhã'),
 (6, 7, now() - INTERVAL '33 days 6 hours', 4, 3, 5, 'Participou da missa'),
 (6, 7, now() - INTERVAL '34 days 7 hours', 4, 5, 4, NULL),
 (6, NULL, now() - INTERVAL '35 days 3 hours', 4, 5, 3, 'Recebeu visita'),
 (6, NULL, now() - INTERVAL '41 days 3 hours', 2, 4, 6, NULL),
 (6, NULL, now() - INTERVAL '43 days 1 hours', 4, 4, 5, 'Saudades da família'),
 (7, NULL, now() - INTERVAL '9 hours', 3, 2, 0, 'Recebeu visita'),
 (7, 3, now() - INTERVAL '3 days 2 hours', 4, 3, 2, NULL),
 (7, 11, now() - INTERVAL '4 days 4 hours', 3, 2, 2, 'Pouco apetite no almoço'),
 (7, 11, now() - INTERVAL '5 days 1 hours', 4, 4, 0, 'Pouco apetite no almoço'),
 (7, NULL, now() - INTERVAL '6 days 9 hours', 5, 4, 1, NULL),
 (7, NULL, now() - INTERVAL '7 days 9 hours', 3, 3, 1, 'Dormiu bem'),
 (7, NULL, now() - INTERVAL '10 days 6 hours', 4, 3, 2, 'Dor nas costas pela manhã'),
 (7, NULL, now() - INTERVAL '11 days 2 hours', 4, 4, 3, NULL),
 (7, NULL, now() - INTERVAL '14 days 8 hours', 3, 4, 1, NULL),
 (7, NULL, now() - INTERVAL '16 days 6 hours', 3, 3, 0, NULL),
 (7, 3, now() - INTERVAL '17 days 2 hours', 3, 3, 3, NULL),
 (7, NULL, now() - INTERVAL '18 days 1 hours', 2, 3, 2, NULL),
 (7, 6, now() - INTERVAL '19 days 2 hours', 3, 3, 1, NULL),
 (7, 18, now() - INTERVAL '20 days 4 hours', 3, 4, 3, NULL),
 (7, NULL, now() - INTERVAL '21 days 2 hours', 4, 3, 3, 'Dor nas costas pela manhã'),
 (7, 7, now() - INTERVAL '22 days 3 hours', 1, 3, 0, NULL),
 (7, NULL, now() - INTERVAL '28 days 1 hours', 3, 1, 0, NULL),
 (7, NULL, now() - INTERVAL '29 days 6 hours', 3, 4, 4, NULL),
 (7, NULL, now() - INTERVAL '31 days 10 hours', 3, 2, 2, 'Saudades da família'),
 (7, NULL, now() - INTERVAL '34 days 1 hours', 3, 3, 4, NULL),
 (7, NULL, now() - INTERVAL '37 days 5 hours', 3, 3, 1, 'Participou da missa'),
 (7, NULL, now() - INTERVAL '38 days 6 hours', 2, 3, 1, 'Dormiu bem'),
 (7, NULL, now() - INTERVAL '39 days 3 hours', 3, 3, 0, 'Dormiu bem'),
 (7, NULL, now() - INTERVAL '40 days 10 hours', 3, 3, 1, 'Dormiu bem'),
 (7, 17, now() - INTERVAL '41 days 3 hours', 3, 4, 0, NULL),
 (7, 11, now() - INTERVAL '42 days 7 hours', 4, 2, 1, 'Pouco apetite no almoço'),
 (7, NULL, now() - INTERVAL '44 days 9 hours', 2, 4, 1, NULL),
 (8, 8, now() - INTERVAL '10 hours', 4, 4, 1, 'Dormiu bem'),
 (8, NULL, now() - INTERVAL '1 days 4 hours', 5, 5, 0, 'Animada com o forró'),
 (8, NULL, now() - INTERVAL '4 days 10 hours', 4, 4, 2, 'Saudades da família'),
 (8, NULL, now() - INTERVAL '5 days 1 hours', 4, 4, 2, 'Dor nas costas pela manhã'),
 (8, 7, now() - INTERVAL '6 days 10 hours', 3, 5, 1, 'Recebeu visita'),
 (8, NULL, now() - INTERVAL '7 days 3 hours', 5, 5, 3, NULL),
 (8, NULL, now() - INTERVAL '9 days 7 hours', 5, 5, 0, NULL),
 (8, NULL, now() - INTERVAL '10 days 3 hours', 4, 4, 0, NULL),
 (8, NULL, now() - INTERVAL '11 days 5 hours', 3, 3, 0, NULL),
 (8, NULL, now() - INTERVAL '12 days 3 hours', 5, 2, 1, NULL),
 (8, NULL, now() - INTERVAL '13 days 3 hours', 4, 4, 1, NULL),
 (8, 7, now() - INTERVAL '14 days 8 hours', 3, 4, 0, 'Dor nas costas pela manhã'),
 (8, NULL, now() - INTERVAL '15 days 10 hours', 4, 2, 1, NULL),
 (8, NULL, now() - INTERVAL '17 days 10 hours', 4, 4, 2, NULL),
 (8, NULL, now() - INTERVAL '18 days 7 hours', 4, 4, 3, NULL),
 (8, NULL, now() - INTERVAL '19 days 3 hours', 3, 4, 0, 'Dormiu bem'),
 (8, NULL, now() - INTERVAL '21 days 2 hours', 4, 3, 3, NULL),
 (8, NULL, now() - INTERVAL '22 days 6 hours', 3, 3, 0, 'Dor nas costas pela manhã'),
 (8, NULL, now() - INTERVAL '24 days 5 hours', 5, 4, 0, 'Animada com o forró'),
 (8, NULL, now() - INTERVAL '25 days 4 hours', 4, 4, 1, NULL),
 (8, NULL, now() - INTERVAL '27 days 4 hours', 4, 5, 2, 'Reclamou do calor'),
 (8, 11, now() - INTERVAL '28 days 2 hours', 5, 3, 3, NULL),
 (8, 10, now() - INTERVAL '29 days 5 hours', 3, 5, 3, NULL),
 (8, NULL, now() - INTERVAL '30 days 4 hours', 4, 4, 0, 'Participou da missa'),
 (8, NULL, now() - INTERVAL '32 days 10 hours', 5, 5, 2, 'Dor nas costas pela manhã'),
 (8, NULL, now() - INTERVAL '40 days 2 hours', 4, 3, 1, 'Saudades da família'),
 (8, NULL, now() - INTERVAL '41 days 7 hours', 5, 4, 4, 'Pouco apetite no almoço'),
 (8, 7, now() - INTERVAL '43 days 5 hours', 3, 5, 0, 'Reclamou do calor'),
 (8, NULL, now() - INTERVAL '44 days 5 hours', 4, 5, 0, 'Participou da missa'),
 (9, 11, now() - INTERVAL '5 days 3 hours', 5, 4, 4, 'Saudades da família'),
 (9, 8, now() - INTERVAL '10 days 5 hours', 5, 3, 5, NULL),
 (9, 7, now() - INTERVAL '13 days 7 hours', 4, 5, 3, 'Pouco apetite no almoço'),
 (9, 6, now() - INTERVAL '19 days 5 hours', 5, 3, 6, NULL),
 (9, 6, now() - INTERVAL '24 days 9 hours', 5, 4, 4, NULL),
 (9, 6, now() - INTERVAL '25 days 9 hours', 4, 5, 3, 'Dormiu bem'),
 (9, 10, now() - INTERVAL '28 days 7 hours', 5, 4, 8, NULL),
 (9, 10, now() - INTERVAL '29 days 5 hours', 4, 4, 8, 'Animada com o forró'),
 (9, 9, now() - INTERVAL '37 days 2 hours', 2, 5, 5, NULL),
 (9, 10, now() - INTERVAL '41 days 3 hours', 5, 4, 5, 'Pouco apetite no almoço'),
 (9, 17, now() - INTERVAL '44 days 9 hours', 5, 5, 3, NULL),
 (10, NULL, now() - INTERVAL '10 hours', 2, 2, 7, 'Participou da missa'),
 (10, NULL, now() - INTERVAL '2 days 6 hours', 2, 2, 2, 'Reclamou do calor'),
 (10, NULL, now() - INTERVAL '3 days 5 hours', 3, 2, 7, 'Pouco apetite no almoço'),
 (10, NULL, now() - INTERVAL '4 days 7 hours', 4, 2, 4, 'Reclamou do calor'),
 (10, NULL, now() - INTERVAL '5 days 2 hours', 2, 2, 5, 'Dormiu bem'),
 (10, NULL, now() - INTERVAL '7 days 4 hours', 3, 3, 7, 'Dormiu bem'),
 (10, NULL, now() - INTERVAL '9 days 8 hours', 3, 3, 6, NULL),
 (10, 17, now() - INTERVAL '12 days 9 hours', 3, 3, 5, 'Saudades da família'),
 (10, NULL, now() - INTERVAL '13 days 2 hours', 3, 2, 7, 'Dor nas costas pela manhã'),
 (10, 8, now() - INTERVAL '14 days 3 hours', 3, 2, 3, 'Reclamou do calor'),
 (10, NULL, now() - INTERVAL '15 days 2 hours', 2, 1, 6, 'Animada com o forró'),
 (10, NULL, now() - INTERVAL '16 days 8 hours', 2, 3, 5, NULL),
 (10, NULL, now() - INTERVAL '17 days 5 hours', 3, 1, 6, 'Reclamou do calor'),
 (10, NULL, now() - INTERVAL '18 days 6 hours', 3, 3, 6, NULL),
 (10, NULL, now() - INTERVAL '23 days 5 hours', 3, 3, 6, 'Dor nas costas pela manhã'),
 (10, NULL, now() - INTERVAL '25 days 5 hours', 3, 3, 6, 'Dor nas costas pela manhã'),
 (10, NULL, now() - INTERVAL '26 days 6 hours', 2, 3, 6, 'Participou da missa'),
 (10, NULL, now() - INTERVAL '27 days 10 hours', 3, 1, 6, NULL),
 (10, NULL, now() - INTERVAL '29 days 6 hours', 4, 3, 4, 'Recebeu visita'),
 (10, NULL, now() - INTERVAL '30 days 3 hours', 3, 4, 6, NULL),
 (10, NULL, now() - INTERVAL '34 days 7 hours', 3, 3, 5, NULL),
 (10, 3, now() - INTERVAL '35 days 3 hours', 4, 1, 5, 'Reclamou do calor'),
 (10, 11, now() - INTERVAL '37 days 6 hours', 3, 3, 4, 'Animada com o forró'),
 (10, NULL, now() - INTERVAL '39 days 1 hours', 3, 3, 6, 'Reclamou do calor'),
 (10, NULL, now() - INTERVAL '40 days 6 hours', 2, 3, 4, 'Reclamou do calor'),
 (10, NULL, now() - INTERVAL '43 days 3 hours', 3, 4, 6, 'Dormiu bem'),
 (11, NULL, now() - INTERVAL '4 hours', 4, 4, 3, NULL),
 (11, NULL, now() - INTERVAL '1 days 1 hours', 4, 4, 8, 'Animada com o forró'),
 (11, 10, now() - INTERVAL '2 days 6 hours', 4, 4, 5, NULL),
 (11, NULL, now() - INTERVAL '4 days 2 hours', 5, 3, 5, 'Participou da missa'),
 (11, 18, now() - INTERVAL '11 days 2 hours', 5, 4, 4, 'Reclamou do calor'),
 (11, NULL, now() - INTERVAL '12 days 4 hours', 4, 3, 6, NULL),
 (11, NULL, now() - INTERVAL '14 days 6 hours', 4, 5, 8, 'Reclamou do calor'),
 (11, 18, now() - INTERVAL '15 days 4 hours', 3, 4, 5, 'Saudades da família'),
 (11, 7, now() - INTERVAL '18 days 6 hours', 2, 4, 6, 'Reclamou do calor'),
 (11, NULL, now() - INTERVAL '19 days 10 hours', 4, 4, 5, NULL),
 (11, NULL, now() - INTERVAL '20 days 7 hours', 3, 5, 5, NULL),
 (11, NULL, now() - INTERVAL '22 days 4 hours', 2, 4, 3, NULL),
 (11, NULL, now() - INTERVAL '23 days 2 hours', 4, 4, 4, NULL),
 (11, NULL, now() - INTERVAL '25 days 6 hours', 3, 5, 6, 'Reclamou do calor'),
 (11, 7, now() - INTERVAL '26 days 7 hours', 4, 4, 4, NULL),
 (11, NULL, now() - INTERVAL '27 days 10 hours', 3, 3, 3, 'Saudades da família'),
 (11, NULL, now() - INTERVAL '28 days 1 hours', 4, 4, 6, 'Reclamou do calor'),
 (11, NULL, now() - INTERVAL '29 days 7 hours', 3, 4, 6, NULL),
 (11, 9, now() - INTERVAL '30 days 5 hours', 4, 3, 3, 'Reclamou do calor'),
 (11, NULL, now() - INTERVAL '33 days 7 hours', 3, 4, 5, 'Animada com o forró'),
 (11, NULL, now() - INTERVAL '34 days 6 hours', 3, 5, 3, 'Animada com o forró'),
 (11, NULL, now() - INTERVAL '37 days 8 hours', 4, 5, 5, NULL),
 (11, NULL, now() - INTERVAL '38 days 4 hours', 5, 5, 5, 'Pouco apetite no almoço'),
 (11, NULL, now() - INTERVAL '39 days 4 hours', 4, 5, 5, NULL),
 (11, NULL, now() - INTERVAL '42 days 9 hours', 5, 5, 7, 'Dor nas costas pela manhã'),
 (11, NULL, now() - INTERVAL '44 days 5 hours', 3, 4, 6, 'Participou da missa'),
 (12, NULL, now() - INTERVAL '8 hours', 5, 4, 3, NULL),
 (12, 6, now() - INTERVAL '1 days 8 hours', 4, 4, 1, NULL),
 (12, NULL, now() - INTERVAL '2 days 8 hours', 3, 4, 2, 'Pouco apetite no almoço'),
 (12, NULL, now() - INTERVAL '3 days 5 hours', 4, 5, 4, 'Saudades da família'),
 (12, NULL, now() - INTERVAL '4 days 2 hours', 4, 4, 0, NULL),
 (12, NULL, now() - INTERVAL '5 days 7 hours', 5, 4, 4, 'Reclamou do calor'),
 (12, 17, now() - INTERVAL '7 days 4 hours', 4, 3, 3, NULL),
 (12, 3, now() - INTERVAL '8 days 10 hours', 3, 4, 0, 'Dor nas costas pela manhã'),
 (12, NULL, now() - INTERVAL '12 days 10 hours', 4, 4, 0, 'Dormiu bem'),
 (12, NULL, now() - INTERVAL '14 days 9 hours', 3, 5, 3, NULL),
 (12, NULL, now() - INTERVAL '17 days 10 hours', 4, 3, 2, NULL),
 (12, NULL, now() - INTERVAL '20 days 3 hours', 3, 3, 5, NULL),
 (12, NULL, now() - INTERVAL '21 days 4 hours', 4, 4, 2, 'Recebeu visita'),
 (12, NULL, now() - INTERVAL '23 days 8 hours', 3, 5, 3, 'Dormiu bem'),
 (12, NULL, now() - INTERVAL '26 days 10 hours', 4, 5, 3, 'Reclamou do calor'),
 (12, NULL, now() - INTERVAL '29 days 2 hours', 5, 4, 1, 'Pouco apetite no almoço'),
 (12, 17, now() - INTERVAL '30 days 5 hours', 5, 4, 1, NULL),
 (12, NULL, now() - INTERVAL '34 days 3 hours', 4, 3, 3, NULL),
 (12, NULL, now() - INTERVAL '36 days 6 hours', 4, 5, 2, NULL),
 (12, NULL, now() - INTERVAL '39 days 2 hours', 5, 4, 2, 'Dormiu bem'),
 (12, NULL, now() - INTERVAL '41 days 2 hours', 5, 4, 1, 'Saudades da família'),
 (12, NULL, now() - INTERVAL '43 days 6 hours', 5, 5, 2, 'Dor nas costas pela manhã'),
 (12, NULL, now() - INTERVAL '44 days 1 hours', 5, 3, 2, NULL),
 (13, NULL, now() - INTERVAL '6 hours', 4, 3, 3, 'Reclamou do calor'),
 (13, NULL, now() - INTERVAL '1 days 2 hours', 2, 2, 0, NULL),
 (13, NULL, now() - INTERVAL '2 days 1 hours', 5, 4, 2, 'Dormiu bem'),
 (13, 17, now() - INTERVAL '3 days 2 hours', 4, 3, 4, NULL),
 (13, 7, now() - INTERVAL '5 days 1 hours', 2, 4, 3, 'Animada com o forró'),
 (13, 6, now() - INTERVAL '6 days 7 hours', 3, 4, 0, NULL),
 (13, NULL, now() - INTERVAL '7 days 1 hours', 5, 4, 0, NULL),
 (13, NULL, now() - INTERVAL '10 days 7 hours', 4, 4, 0, NULL),
 (13, NULL, now() - INTERVAL '11 days 4 hours', 4, 3, 0, 'Animada com o forró'),
 (13, NULL, now() - INTERVAL '12 days 1 hours', 5, 5, 4, NULL),
 (13, NULL, now() - INTERVAL '13 days 3 hours', 3, 4, 3, NULL),
 (13, NULL, now() - INTERVAL '15 days 7 hours', 5, 3, 0, 'Pouco apetite no almoço'),
 (13, NULL, now() - INTERVAL '18 days 4 hours', 4, 5, 1, 'Pouco apetite no almoço'),
 (13, NULL, now() - INTERVAL '19 days 4 hours', 1, 5, 3, NULL),
 (13, NULL, now() - INTERVAL '21 days 3 hours', 3, 4, 3, NULL),
 (13, NULL, now() - INTERVAL '22 days 4 hours', 4, 5, 0, NULL),
 (13, NULL, now() - INTERVAL '25 days 6 hours', 5, 3, 2, 'Reclamou do calor'),
 (13, NULL, now() - INTERVAL '30 days 1 hours', 3, 5, 0, 'Participou da missa'),
 (13, NULL, now() - INTERVAL '32 days 9 hours', 5, 3, 1, 'Reclamou do calor'),
 (13, 17, now() - INTERVAL '35 days 3 hours', 4, 4, 1, NULL),
 (13, 11, now() - INTERVAL '38 days 9 hours', 4, 2, 3, NULL),
 (13, NULL, now() - INTERVAL '39 days 5 hours', 3, 3, 2, 'Pouco apetite no almoço'),
 (13, NULL, now() - INTERVAL '40 days 9 hours', 3, 4, 1, NULL),
 (13, 6, now() - INTERVAL '44 days 2 hours', 3, 3, 0, 'Participou da missa'),
 (14, NULL, now() - INTERVAL '3 hours', 5, 4, 4, NULL),
 (14, NULL, now() - INTERVAL '2 days 10 hours', 4, 5, 6, NULL),
 (14, NULL, now() - INTERVAL '4 days 10 hours', 4, 3, 5, 'Saudades da família'),
 (14, NULL, now() - INTERVAL '5 days 7 hours', 4, 4, 5, 'Recebeu visita'),
 (14, NULL, now() - INTERVAL '6 days 6 hours', 4, 4, 7, NULL),
 (14, NULL, now() - INTERVAL '7 days 4 hours', 4, 3, 5, 'Dormiu bem'),
 (14, 3, now() - INTERVAL '8 days 9 hours', 5, 4, 5, 'Dor nas costas pela manhã'),
 (14, 3, now() - INTERVAL '9 days 2 hours', 4, 4, 5, NULL),
 (14, 6, now() - INTERVAL '11 days 8 hours', 5, 3, 7, NULL),
 (14, 9, now() - INTERVAL '12 days 10 hours', 4, 4, 2, 'Dor nas costas pela manhã'),
 (14, NULL, now() - INTERVAL '14 days 10 hours', 4, 5, 3, NULL),
 (14, NULL, now() - INTERVAL '15 days 5 hours', 2, 3, 4, NULL),
 (14, NULL, now() - INTERVAL '17 days 7 hours', 3, 4, 5, 'Saudades da família'),
 (14, 11, now() - INTERVAL '19 days 6 hours', 4, 4, 3, 'Animada com o forró'),
 (14, NULL, now() - INTERVAL '24 days 1 hours', 4, 4, 4, 'Reclamou do calor'),
 (14, NULL, now() - INTERVAL '27 days 6 hours', 4, 4, 2, 'Pouco apetite no almoço'),
 (14, NULL, now() - INTERVAL '28 days 6 hours', 5, 4, 5, NULL),
 (14, 3, now() - INTERVAL '30 days 8 hours', 4, 2, 2, 'Reclamou do calor'),
 (14, NULL, now() - INTERVAL '31 days 4 hours', 4, 3, 5, 'Recebeu visita'),
 (14, NULL, now() - INTERVAL '32 days 2 hours', 3, 3, 4, NULL),
 (14, NULL, now() - INTERVAL '33 days 9 hours', 3, 5, 4, 'Pouco apetite no almoço'),
 (14, NULL, now() - INTERVAL '34 days 10 hours', 4, 3, 1, 'Dor nas costas pela manhã'),
 (14, NULL, now() - INTERVAL '35 days 3 hours', 5, 3, 5, 'Pouco apetite no almoço'),
 (14, 17, now() - INTERVAL '36 days 3 hours', 4, 4, 5, NULL),
 (14, NULL, now() - INTERVAL '37 days 7 hours', 3, 4, 7, 'Dor nas costas pela manhã'),
 (14, NULL, now() - INTERVAL '38 days 2 hours', 3, 3, 6, 'Animada com o forró'),
 (14, NULL, now() - INTERVAL '39 days 6 hours', 4, 5, 3, NULL),
 (14, NULL, now() - INTERVAL '40 days 7 hours', 4, 4, 6, 'Recebeu visita'),
 (14, NULL, now() - INTERVAL '41 days 6 hours', 2, 3, 5, 'Dormiu bem'),
 (14, NULL, now() - INTERVAL '42 days 7 hours', 4, 3, 2, 'Dor nas costas pela manhã'),
 (14, NULL, now() - INTERVAL '44 days 7 hours', 4, 3, 7, 'Dor nas costas pela manhã'),
 (15, 10, now() - INTERVAL '8 hours', 4, 4, 5, NULL),
 (15, 10, now() - INTERVAL '3 days 3 hours', 4, 4, 3, 'Saudades da família'),
 (15, 10, now() - INTERVAL '7 days 10 hours', 5, 3, 2, 'Recebeu visita'),
 (15, 6, now() - INTERVAL '9 days 1 hours', 4, 4, 1, 'Participou da missa'),
 (15, 10, now() - INTERVAL '14 days 3 hours', 5, 5, 4, NULL),
 (15, 8, now() - INTERVAL '17 days 10 hours', 5, 4, 4, 'Animada com o forró'),
 (15, 10, now() - INTERVAL '27 days 9 hours', 5, 4, 4, 'Dormiu bem'),
 (15, 11, now() - INTERVAL '28 days 3 hours', 5, 5, 3, NULL),
 (15, 3, now() - INTERVAL '32 days 8 hours', 3, 4, 2, 'Saudades da família'),
 (15, 11, now() - INTERVAL '33 days 9 hours', 3, 5, 2, 'Dormiu bem'),
 (15, 18, now() - INTERVAL '34 days 1 hours', 5, 4, 1, NULL),
 (15, 10, now() - INTERVAL '36 days 3 hours', 4, 5, 2, 'Dormiu bem'),
 (15, 9, now() - INTERVAL '41 days 2 hours', 4, 5, 3, 'Participou da missa'),
 (15, 3, now() - INTERVAL '44 days 1 hours', 5, 4, 4, 'Reclamou do calor'),
 (16, 7, now() - INTERVAL '10 hours', 3, 4, 6, NULL),
 (16, 9, now() - INTERVAL '1 days 1 hours', 2, 2, 6, NULL),
 (16, 18, now() - INTERVAL '3 days 7 hours', 4, 3, 7, NULL),
 (16, 6, now() - INTERVAL '11 days 5 hours', 3, 3, 5, NULL),
 (16, 9, now() - INTERVAL '12 days 2 hours', 4, 4, 5, 'Pouco apetite no almoço'),
 (16, 10, now() - INTERVAL '13 days 5 hours', 3, 2, 4, NULL),
 (16, 3, now() - INTERVAL '15 days 5 hours', 3, 3, 5, 'Dormiu bem'),
 (16, 18, now() - INTERVAL '19 days 10 hours', 3, 3, 4, 'Reclamou do calor'),
 (16, 18, now() - INTERVAL '25 days 7 hours', 2, 3, 3, 'Recebeu visita'),
 (16, 11, now() - INTERVAL '26 days 10 hours', 4, 3, 1, 'Animada com o forró'),
 (16, 6, now() - INTERVAL '28 days 10 hours', 3, 3, 4, 'Reclamou do calor'),
 (16, 18, now() - INTERVAL '30 days 7 hours', 4, 3, 3, NULL),
 (16, 10, now() - INTERVAL '32 days 8 hours', 3, 3, 3, NULL),
 (16, 7, now() - INTERVAL '35 days 10 hours', 1, 3, 5, 'Dormiu bem'),
 (16, 11, now() - INTERVAL '37 days 1 hours', 3, 2, 6, NULL),
 (16, 18, now() - INTERVAL '38 days 7 hours', 2, 2, 6, 'Animada com o forró'),
 (16, 6, now() - INTERVAL '39 days 6 hours', 2, 3, 3, 'Saudades da família'),
 (16, 8, now() - INTERVAL '41 days 3 hours', 4, 1, 4, 'Dor nas costas pela manhã'),
 (16, 6, now() - INTERVAL '43 days 10 hours', 2, 3, 4, NULL),
 (16, 17, now() - INTERVAL '44 days 3 hours', 3, 3, 6, 'Dor nas costas pela manhã'),
 (17, 18, now() - INTERVAL '4 days 10 hours', 3, 4, 8, 'Dormiu bem'),
 (17, 17, now() - INTERVAL '9 days 6 hours', 4, 3, 5, NULL),
 (17, 10, now() - INTERVAL '10 days 1 hours', 4, 2, 4, 'Reclamou do calor'),
 (17, 6, now() - INTERVAL '11 days 2 hours', 4, 3, 6, NULL),
 (17, 10, now() - INTERVAL '14 days 8 hours', 4, 4, 5, 'Dor nas costas pela manhã'),
 (17, 18, now() - INTERVAL '18 days 6 hours', 3, 4, 6, NULL),
 (17, 9, now() - INTERVAL '21 days 1 hours', 4, 4, 6, NULL),
 (17, 18, now() - INTERVAL '22 days 5 hours', 3, 4, 6, 'Dormiu bem'),
 (17, 17, now() - INTERVAL '23 days 8 hours', 5, 4, 8, 'Participou da missa'),
 (17, 9, now() - INTERVAL '24 days 5 hours', 4, 4, 7, 'Dormiu bem'),
 (17, 10, now() - INTERVAL '26 days 8 hours', 4, 3, 3, 'Participou da missa'),
 (17, 9, now() - INTERVAL '27 days 2 hours', 4, 4, 5, 'Saudades da família'),
 (17, 7, now() - INTERVAL '34 days 3 hours', 4, 3, 5, 'Saudades da família'),
 (17, 3, now() - INTERVAL '37 days 6 hours', 4, 5, 5, NULL),
 (17, 8, now() - INTERVAL '38 days 2 hours', 4, 4, 6, 'Saudades da família'),
 (17, 9, now() - INTERVAL '40 days 4 hours', 5, 4, 5, NULL),
 (17, 8, now() - INTERVAL '43 days 9 hours', 3, 4, 4, NULL),
 (17, 17, now() - INTERVAL '44 days 8 hours', 4, 3, 9, NULL),
 (18, 6, now() - INTERVAL '3 hours', 3, 3, 4, NULL),
 (18, 8, now() - INTERVAL '2 days 1 hours', 4, 3, 2, NULL),
 (18, 3, now() - INTERVAL '6 days 9 hours', 4, 4, 4, NULL),
 (18, 8, now() - INTERVAL '8 days 9 hours', 3, 3, 3, 'Pouco apetite no almoço'),
 (18, 9, now() - INTERVAL '9 days 2 hours', 4, 3, 3, 'Dormiu bem'),
 (18, 7, now() - INTERVAL '10 days 1 hours', 4, 2, 5, 'Reclamou do calor'),
 (18, 6, now() - INTERVAL '15 days 8 hours', 4, 2, 3, 'Dor nas costas pela manhã'),
 (18, 3, now() - INTERVAL '17 days 7 hours', 5, 4, 3, NULL),
 (18, 17, now() - INTERVAL '18 days 4 hours', 3, 3, 4, NULL),
 (18, 6, now() - INTERVAL '19 days 2 hours', 4, 2, 4, 'Saudades da família'),
 (18, 6, now() - INTERVAL '21 days 4 hours', 2, 4, 3, NULL),
 (18, 10, now() - INTERVAL '22 days 10 hours', 4, 4, 3, 'Saudades da família'),
 (18, 9, now() - INTERVAL '28 days 4 hours', 5, 4, 4, NULL),
 (18, 3, now() - INTERVAL '31 days 1 hours', 3, 4, 4, 'Dor nas costas pela manhã'),
 (18, 8, now() - INTERVAL '33 days 10 hours', 4, 5, 2, 'Animada com o forró'),
 (18, 6, now() - INTERVAL '35 days 8 hours', 4, 4, 2, 'Recebeu visita'),
 (18, 8, now() - INTERVAL '36 days 4 hours', 2, 4, 7, 'Animada com o forró'),
 (19, 9, now() - INTERVAL '3 hours', 3, 4, 6, NULL),
 (19, 7, now() - INTERVAL '6 days 9 hours', 4, 3, 6, NULL),
 (19, 8, now() - INTERVAL '13 days 10 hours', 5, 4, 5, 'Saudades da família'),
 (19, 18, now() - INTERVAL '14 days 7 hours', 4, 4, 3, NULL),
 (19, 9, now() - INTERVAL '17 days 4 hours', 4, 5, 7, 'Animada com o forró'),
 (19, 9, now() - INTERVAL '18 days 2 hours', 5, 5, 6, 'Dor nas costas pela manhã'),
 (19, 3, now() - INTERVAL '20 days 8 hours', 5, 2, 6, NULL),
 (19, 7, now() - INTERVAL '21 days 8 hours', 3, 4, 4, NULL),
 (19, 18, now() - INTERVAL '25 days 7 hours', 4, 3, 5, 'Dormiu bem'),
 (19, 8, now() - INTERVAL '27 days 7 hours', 2, 3, 8, 'Saudades da família'),
 (19, 10, now() - INTERVAL '33 days 5 hours', 3, 4, 7, 'Reclamou do calor'),
 (19, 11, now() - INTERVAL '37 days 3 hours', 3, 3, 5, NULL),
 (19, 18, now() - INTERVAL '39 days 9 hours', 5, 3, 6, 'Recebeu visita'),
 (19, 7, now() - INTERVAL '42 days 6 hours', 2, 3, 5, 'Saudades da família'),
 (19, 10, now() - INTERVAL '44 days 5 hours', 5, 3, 5, 'Participou da missa'),
 (20, 10, now() - INTERVAL '9 hours', 5, 3, 3, NULL),
 (20, 9, now() - INTERVAL '1 days 8 hours', 5, 3, 2, 'Saudades da família'),
 (20, 18, now() - INTERVAL '5 days 9 hours', 5, 3, 1, 'Animada com o forró'),
 (20, 11, now() - INTERVAL '6 days 4 hours', 2, 3, 6, 'Pouco apetite no almoço'),
 (20, 9, now() - INTERVAL '9 days 3 hours', 4, 3, 3, NULL),
 (20, 11, now() - INTERVAL '11 days 3 hours', 4, 4, 4, NULL),
 (20, 7, now() - INTERVAL '21 days 6 hours', 4, 4, 1, 'Recebeu visita'),
 (20, 18, now() - INTERVAL '22 days 3 hours', 4, 4, 3, 'Recebeu visita'),
 (20, 18, now() - INTERVAL '25 days 10 hours', 4, 5, 1, NULL),
 (20, 8, now() - INTERVAL '26 days 4 hours', 5, 3, 4, 'Recebeu visita'),
 (20, 3, now() - INTERVAL '27 days 3 hours', 3, 3, 4, NULL),
 (20, 10, now() - INTERVAL '30 days 5 hours', 4, 3, 0, 'Reclamou do calor'),
 (20, 3, now() - INTERVAL '32 days 4 hours', 4, 4, 3, 'Reclamou do calor'),
 (20, 3, now() - INTERVAL '36 days 2 hours', 3, 3, 0, 'Pouco apetite no almoço'),
 (20, 18, now() - INTERVAL '40 days 4 hours', 4, 5, 0, NULL),
 (20, 7, now() - INTERVAL '43 days 5 hours', 4, 4, 1, NULL),
 (21, 17, now() - INTERVAL '5 hours', 3, 3, 4, 'Animada com o forró'),
 (21, 3, now() - INTERVAL '4 days 4 hours', 2, 3, 4, 'Dor nas costas pela manhã'),
 (21, 9, now() - INTERVAL '5 days 10 hours', 4, 2, 5, 'Dor nas costas pela manhã'),
 (21, 10, now() - INTERVAL '7 days 8 hours', 2, 2, 5, 'Dormiu bem'),
 (21, 10, now() - INTERVAL '10 days 8 hours', 4, 4, 3, 'Recebeu visita'),
 (21, 7, now() - INTERVAL '13 days 5 hours', 3, 4, 4, 'Recebeu visita'),
 (21, 3, now() - INTERVAL '14 days 8 hours', 3, 4, 4, 'Recebeu visita'),
 (21, 18, now() - INTERVAL '16 days 3 hours', 3, 3, 3, 'Reclamou do calor'),
 (21, 8, now() - INTERVAL '18 days 8 hours', 4, 3, 4, NULL),
 (21, 9, now() - INTERVAL '22 days 5 hours', 4, 3, 6, NULL),
 (21, 9, now() - INTERVAL '25 days 2 hours', 2, 4, 5, NULL),
 (21, 17, now() - INTERVAL '28 days 7 hours', 4, 3, 5, NULL),
 (21, 9, now() - INTERVAL '32 days 3 hours', 3, 4, 5, NULL),
 (21, 18, now() - INTERVAL '38 days 4 hours', 3, 3, 1, 'Participou da missa'),
 (21, 7, now() - INTERVAL '41 days 9 hours', 3, 2, 2, NULL),
 (23, 17, now() - INTERVAL '1 hours', 4, 4, 4, 'Saudades da família'),
 (23, 8, now() - INTERVAL '1 days 3 hours', 4, 4, 2, NULL),
 (23, 11, now() - INTERVAL '3 days 5 hours', 3, 5, 6, 'Dor nas costas pela manhã'),
 (23, 17, now() - INTERVAL '10 days 5 hours', 5, 5, 4, 'Reclamou do calor'),
 (23, 18, now() - INTERVAL '17 days 4 hours', 5, 5, 2, NULL),
 (23, 7, now() - INTERVAL '18 days 4 hours', 4, 4, 6, 'Recebeu visita'),
 (23, 3, now() - INTERVAL '25 days 3 hours', 4, 5, 4, 'Saudades da família'),
 (23, 17, now() - INTERVAL '26 days 10 hours', 4, 4, 2, 'Reclamou do calor'),
 (23, 17, now() - INTERVAL '31 days 3 hours', 4, 4, 3, NULL),
 (23, 3, now() - INTERVAL '36 days 3 hours', 3, 5, 4, 'Dor nas costas pela manhã'),
 (23, 17, now() - INTERVAL '38 days 7 hours', 4, 4, 4, 'Recebeu visita'),
 (23, 17, now() - INTERVAL '44 days 7 hours', 4, 5, 4, 'Participou da missa'),
 (24, 21, now() - INTERVAL '3 hours', 3, 3, 2, 'Reclamou do calor'),
 (24, 21, now() - INTERVAL '2 days 4 hours', 4, 3, 0, NULL),
 (24, 21, now() - INTERVAL '9 days 5 hours', 5, 4, 2, NULL),
 (24, 21, now() - INTERVAL '14 days 6 hours', 5, 4, 1, 'Saudades da família'),
 (24, 21, now() - INTERVAL '19 days 9 hours', 4, 4, 0, NULL),
 (24, 21, now() - INTERVAL '23 days 3 hours', 3, 3, 0, NULL),
 (24, 22, now() - INTERVAL '26 days 7 hours', 4, 4, 3, 'Recebeu visita'),
 (24, 21, now() - INTERVAL '30 days 6 hours', 3, 3, 2, 'Reclamou do calor'),
 (24, 22, now() - INTERVAL '33 days 7 hours', 4, 4, 0, 'Saudades da família'),
 (24, 22, now() - INTERVAL '38 days 1 hours', 5, 3, 2, 'Animada com o forró'),
 (24, 23, now() - INTERVAL '41 days 7 hours', 3, 4, 0, 'Reclamou do calor'),
 (24, 23, now() - INTERVAL '42 days 7 hours', 5, 4, 1, 'Reclamou do calor'),
 (24, 22, now() - INTERVAL '43 days 7 hours', 4, 4, 1, 'Animada com o forró'),
 (24, 23, now() - INTERVAL '44 days 8 hours', 4, 3, 0, NULL),
 (25, 21, now() - INTERVAL '8 hours', 4, 3, 3, 'Animada com o forró'),
 (25, 22, now() - INTERVAL '4 days 3 hours', 2, 3, 2, NULL),
 (25, 23, now() - INTERVAL '7 days 6 hours', 4, 2, 1, NULL),
 (25, 23, now() - INTERVAL '9 days 4 hours', 4, 3, 2, 'Recebeu visita'),
 (25, 23, now() - INTERVAL '11 days 3 hours', 3, 3, 2, NULL),
 (25, 21, now() - INTERVAL '13 days 1 hours', 2, 4, 1, 'Recebeu visita'),
 (25, 22, now() - INTERVAL '14 days 3 hours', 4, 3, 0, 'Dormiu bem'),
 (25, 21, now() - INTERVAL '18 days 9 hours', 4, 4, 4, NULL),
 (25, 21, now() - INTERVAL '21 days 8 hours', 4, 3, 1, 'Dormiu bem'),
 (25, 21, now() - INTERVAL '24 days 7 hours', 3, 3, 0, NULL),
 (25, 23, now() - INTERVAL '28 days 2 hours', 3, 4, 0, NULL),
 (25, 23, now() - INTERVAL '31 days 10 hours', 4, 4, 0, NULL),
 (25, 21, now() - INTERVAL '34 days 3 hours', 2, 2, 4, 'Participou da missa'),
 (25, 22, now() - INTERVAL '40 days 3 hours', 3, 3, 1, NULL),
 (25, 21, now() - INTERVAL '42 days 3 hours', 4, 3, 0, NULL),
 (25, 21, now() - INTERVAL '44 days 6 hours', 3, 3, 2, NULL),
 (26, 21, now() - INTERVAL '4 hours', 4, 4, 4, 'Saudades da família'),
 (26, 22, now() - INTERVAL '1 days 8 hours', 5, 4, 1, NULL),
 (26, 23, now() - INTERVAL '3 days 6 hours', 5, 3, 3, 'Participou da missa'),
 (26, 23, now() - INTERVAL '9 days 3 hours', 4, 3, 0, 'Animada com o forró'),
 (26, 23, now() - INTERVAL '18 days 8 hours', 4, 4, 1, 'Pouco apetite no almoço'),
 (26, 21, now() - INTERVAL '20 days 6 hours', 3, 5, 0, 'Participou da missa'),
 (26, 23, now() - INTERVAL '21 days 6 hours', 3, 4, 2, 'Dor nas costas pela manhã'),
 (26, 21, now() - INTERVAL '24 days 8 hours', 4, 5, 0, NULL),
 (26, 21, now() - INTERVAL '25 days 3 hours', 3, 3, 1, NULL),
 (26, 21, now() - INTERVAL '27 days 7 hours', 4, 5, 1, 'Dormiu bem'),
 (26, 23, now() - INTERVAL '28 days 5 hours', 4, 4, 0, 'Animada com o forró'),
 (26, 22, now() - INTERVAL '29 days 2 hours', 5, 5, 1, 'Pouco apetite no almoço'),
 (26, 23, now() - INTERVAL '31 days 2 hours', 3, 5, 3, 'Saudades da família'),
 (26, 22, now() - INTERVAL '35 days 3 hours', 5, 5, 0, 'Saudades da família'),
 (27, 23, now() - INTERVAL '6 days 2 hours', 5, 5, 5, 'Animada com o forró'),
 (27, 23, now() - INTERVAL '7 days 6 hours', 4, 5, 3, 'Pouco apetite no almoço'),
 (27, 21, now() - INTERVAL '10 days 6 hours', 4, 5, 2, NULL),
 (27, 21, now() - INTERVAL '12 days 7 hours', 5, 5, 0, 'Pouco apetite no almoço'),
 (27, 23, now() - INTERVAL '16 days 10 hours', 4, 4, 4, NULL),
 (27, 21, now() - INTERVAL '17 days 1 hours', 4, 3, 7, NULL),
 (27, 21, now() - INTERVAL '18 days 9 hours', 4, 3, 1, NULL),
 (27, 23, now() - INTERVAL '19 days 8 hours', 3, 4, 2, NULL),
 (27, 21, now() - INTERVAL '22 days 2 hours', 4, 4, 5, 'Reclamou do calor'),
 (27, 22, now() - INTERVAL '23 days 7 hours', 5, 5, 1, 'Pouco apetite no almoço'),
 (27, 23, now() - INTERVAL '24 days 7 hours', 4, 4, 4, 'Participou da missa'),
 (27, 21, now() - INTERVAL '25 days 8 hours', 5, 5, 2, 'Dor nas costas pela manhã'),
 (27, 22, now() - INTERVAL '28 days 2 hours', 5, 3, 3, 'Recebeu visita'),
 (27, 23, now() - INTERVAL '29 days 4 hours', 4, 5, 4, 'Saudades da família'),
 (27, 21, now() - INTERVAL '30 days 7 hours', 4, 5, 2, NULL),
 (27, 23, now() - INTERVAL '34 days 2 hours', 5, 5, 0, NULL),
 (27, 22, now() - INTERVAL '35 days 6 hours', 4, 5, 2, 'Reclamou do calor'),
 (27, 21, now() - INTERVAL '38 days 10 hours', 4, 4, 2, 'Animada com o forró'),
 (27, 22, now() - INTERVAL '40 days 2 hours', 5, 4, 7, NULL),
 (27, 21, now() - INTERVAL '41 days 2 hours', 4, 4, 3, NULL),
 (28, 23, now() - INTERVAL '2 hours', 4, 3, 4, 'Dor nas costas pela manhã'),
 (28, 21, now() - INTERVAL '1 days 9 hours', 3, 3, 4, 'Participou da missa'),
 (28, 21, now() - INTERVAL '3 days 5 hours', 5, 4, 2, 'Recebeu visita'),
 (28, 22, now() - INTERVAL '5 days 7 hours', 5, 3, 2, NULL),
 (28, 23, now() - INTERVAL '13 days 5 hours', 3, 2, 5, 'Participou da missa'),
 (28, 22, now() - INTERVAL '18 days 7 hours', 4, 3, 5, NULL),
 (28, 22, now() - INTERVAL '23 days 6 hours', 4, 3, 5, 'Reclamou do calor'),
 (28, 22, now() - INTERVAL '24 days 6 hours', 4, 4, 6, NULL),
 (28, 23, now() - INTERVAL '25 days 7 hours', 5, 4, 4, NULL),
 (28, 23, now() - INTERVAL '26 days 2 hours', 2, 4, 4, 'Dormiu bem'),
 (28, 23, now() - INTERVAL '27 days 2 hours', 2, 3, 0, NULL),
 (28, 22, now() - INTERVAL '32 days 5 hours', 3, 3, 6, NULL),
 (28, 21, now() - INTERVAL '34 days 6 hours', 4, 3, 2, NULL),
 (28, 21, now() - INTERVAL '35 days 6 hours', 5, 3, 3, 'Participou da missa'),
 (28, 23, now() - INTERVAL '37 days 6 hours', 4, 2, 2, NULL),
 (28, 21, now() - INTERVAL '38 days 4 hours', 5, 3, 1, NULL),
 (28, 21, now() - INTERVAL '44 days 4 hours', 4, 3, 3, 'Animada com o forró'),
 (29, 21, now() - INTERVAL '5 hours', 5, 3, 4, 'Pouco apetite no almoço'),
 (29, 23, now() - INTERVAL '1 days 5 hours', 3, 3, 3, NULL),
 (29, 22, now() - INTERVAL '4 days 8 hours', 4, 4, 2, 'Dormiu bem'),
 (29, 23, now() - INTERVAL '6 days 2 hours', 3, 4, 4, 'Dormiu bem'),
 (29, 21, now() - INTERVAL '12 days 5 hours', 3, 4, 4, 'Dor nas costas pela manhã'),
 (29, 22, now() - INTERVAL '14 days 4 hours', 4, 5, 3, 'Saudades da família'),
 (29, 23, now() - INTERVAL '15 days 10 hours', 5, 2, 1, 'Pouco apetite no almoço'),
 (29, 23, now() - INTERVAL '22 days 10 hours', 4, 3, 4, 'Animada com o forró'),
 (29, 22, now() - INTERVAL '27 days 8 hours', 4, 3, 3, NULL),
 (29, 23, now() - INTERVAL '29 days 1 hours', 4, 5, 0, 'Reclamou do calor'),
 (29, 23, now() - INTERVAL '30 days 2 hours', 4, 4, 2, 'Dor nas costas pela manhã'),
 (29, 21, now() - INTERVAL '31 days 2 hours', 5, 4, 4, NULL),
 (29, 21, now() - INTERVAL '33 days 8 hours', 4, 4, 2, NULL),
 (29, 23, now() - INTERVAL '34 days 2 hours', 5, 4, 1, 'Saudades da família'),
 (29, 22, now() - INTERVAL '38 days 5 hours', 4, 3, 1, NULL),
 (29, 21, now() - INTERVAL '41 days 9 hours', 4, 4, 5, 'Pouco apetite no almoço'),
 (29, 22, now() - INTERVAL '44 days 2 hours', 4, 3, 4, 'Animada com o forró'),
 (30, 22, now() - INTERVAL '10 hours', 5, 3, 2, 'Saudades da família'),
 (30, 23, now() - INTERVAL '1 days 10 hours', 3, 4, 2, 'Animada com o forró'),
 (30, 21, now() - INTERVAL '2 days 10 hours', 4, 4, 1, 'Dor nas costas pela manhã'),
 (30, 22, now() - INTERVAL '4 days 1 hours', 4, 4, 3, NULL),
 (30, 21, now() - INTERVAL '6 days 8 hours', 4, 4, 0, NULL),
 (30, 23, now() - INTERVAL '12 days 2 hours', 4, 3, 1, 'Saudades da família'),
 (30, 22, now() - INTERVAL '18 days 6 hours', 4, 5, 0, NULL),
 (30, 21, now() - INTERVAL '21 days 1 hours', 5, 4, 3, 'Participou da missa'),
 (30, 21, now() - INTERVAL '26 days 1 hours', 4, 3, 1, 'Dor nas costas pela manhã'),
 (30, 22, now() - INTERVAL '33 days 4 hours', 4, 4, 2, NULL),
 (30, 22, now() - INTERVAL '37 days 3 hours', 4, 2, 3, 'Saudades da família'),
 (30, 23, now() - INTERVAL '43 days 7 hours', 3, 3, 1, NULL),
 (31, 29, now() - INTERVAL '2 hours', 5, 5, 0, 'Participou da missa'),
 (31, 29, now() - INTERVAL '1 days 2 hours', 4, 5, 0, 'Recebeu visita'),
 (31, 29, now() - INTERVAL '4 days 2 hours', 5, 4, 0, NULL),
 (31, 29, now() - INTERVAL '7 days 5 hours', 5, 5, 0, 'Dor nas costas pela manhã'),
 (31, 29, now() - INTERVAL '8 days 5 hours', 3, 4, 2, 'Pouco apetite no almoço'),
 (31, 29, now() - INTERVAL '10 days 9 hours', 5, 5, 1, 'Dormiu bem'),
 (31, 29, now() - INTERVAL '11 days 5 hours', 5, 4, 2, NULL),
 (31, 29, now() - INTERVAL '14 days 6 hours', 4, 5, 1, 'Reclamou do calor'),
 (31, 29, now() - INTERVAL '21 days 3 hours', 5, 4, 0, 'Dor nas costas pela manhã'),
 (31, 29, now() - INTERVAL '22 days 10 hours', 5, 5, 1, 'Saudades da família'),
 (31, 29, now() - INTERVAL '23 days 5 hours', 5, 5, 3, NULL),
 (31, 29, now() - INTERVAL '25 days 4 hours', 3, 3, 2, 'Pouco apetite no almoço'),
 (31, 29, now() - INTERVAL '27 days 10 hours', 3, 5, 1, 'Saudades da família'),
 (31, 29, now() - INTERVAL '29 days 2 hours', 2, 4, 0, 'Reclamou do calor'),
 (31, 29, now() - INTERVAL '35 days 1 hours', 4, 4, 4, 'Dor nas costas pela manhã'),
 (31, 29, now() - INTERVAL '40 days 5 hours', 5, 5, 1, 'Participou da missa'),
 (31, 29, now() - INTERVAL '44 days 6 hours', 5, 4, 3, NULL),
 (32, 29, now() - INTERVAL '10 hours', 4, 3, 1, NULL),
 (32, 29, now() - INTERVAL '2 days 1 hours', 4, 4, 4, 'Recebeu visita'),
 (32, 29, now() - INTERVAL '6 days 9 hours', 4, 3, 2, 'Pouco apetite no almoço'),
 (32, 29, now() - INTERVAL '8 days 4 hours', 4, 5, 1, 'Reclamou do calor'),
 (32, 29, now() - INTERVAL '9 days 2 hours', 4, 3, 3, NULL),
 (32, 29, now() - INTERVAL '11 days 5 hours', 2, 2, 0, NULL),
 (32, 29, now() - INTERVAL '13 days 9 hours', 4, 3, 1, 'Reclamou do calor'),
 (32, 29, now() - INTERVAL '15 days 5 hours', 3, 2, 5, 'Recebeu visita'),
 (32, 29, now() - INTERVAL '19 days 4 hours', 3, 3, 0, 'Recebeu visita'),
 (32, 29, now() - INTERVAL '21 days 9 hours', 2, 2, 4, NULL),
 (32, 29, now() - INTERVAL '23 days 3 hours', 4, 3, 3, 'Recebeu visita'),
 (32, 29, now() - INTERVAL '26 days 9 hours', 3, 4, 2, 'Dormiu bem'),
 (32, 29, now() - INTERVAL '29 days 4 hours', 4, 3, 3, 'Dormiu bem'),
 (32, 29, now() - INTERVAL '33 days 10 hours', 3, 3, 1, 'Recebeu visita'),
 (32, 29, now() - INTERVAL '36 days 8 hours', 4, 4, 0, 'Participou da missa'),
 (32, 29, now() - INTERVAL '40 days 6 hours', 3, 3, 1, 'Reclamou do calor'),
 (32, 29, now() - INTERVAL '41 days 5 hours', 3, 2, 2, NULL),
 (32, 29, now() - INTERVAL '43 days 5 hours', 4, 3, 1, NULL);

-- ---------- Avaliações padronizadas complementares ----------
-- Para cada Katz, os 6 itens são inseridos logo depois com
-- currval('avaliacao_id_avaliacao_seq'): a soma dos itens bate com o total.
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 11, 2, 'WHOQOL_OLD', now() - INTERVAL '13 days 4 hours', 85, NULL, 'Qualidade de vida — módulo para idosos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 28, 24, 'KATZ', now() - INTERVAL '78 days 4 hours', 4, 'Dependência parcial', 'Avaliação de atividades básicas de vida diária');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'banho', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'vestir-se', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'higiene pessoal', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'transferência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'continência', 'Necessita ajuda', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'alimentação', 'Necessita ajuda', 0);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 15, 2, 'WHOQOL_OLD', now() - INTERVAL '122 days 8 hours', 78, NULL, 'Qualidade de vida — módulo para idosos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 15, 12, 'LAWTON', now() - INTERVAL '99 days 3 hours', 11, 'Dependência importante', 'Atividades instrumentais (telefone, compras, medicação)');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 10, 2, 'WHOQOL_OLD', now() - INTERVAL '184 days 3 hours', 62, NULL, 'Qualidade de vida — módulo para idosos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 10, 2, 'WHOQOL_OLD', now() - INTERVAL '173 days 7 hours', 96, NULL, 'Qualidade de vida — módulo para idosos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 16, 2, 'WHOQOL_OLD', now() - INTERVAL '165 days 1 hours', 77, NULL, 'Qualidade de vida — módulo para idosos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 16, 1, 'LAWTON', now() - INTERVAL '82 days 4 hours', 21, 'Independente', 'Atividades instrumentais (telefone, compras, medicação)');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 6, 12, 'KATZ', now() - INTERVAL '175 days 1 hours', 5, 'Independente', 'Avaliação de atividades básicas de vida diária');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'banho', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'vestir-se', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'higiene pessoal', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'transferência', 'Necessita ajuda', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'continência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'alimentação', 'Independente', 1);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 6, 13, 'KATZ', now() - INTERVAL '149 days 3 hours', 5, 'Independente', 'Avaliação de atividades básicas de vida diária');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'banho', 'Necessita ajuda', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'vestir-se', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'higiene pessoal', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'transferência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'continência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'alimentação', 'Independente', 1);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 14, 2, 'GDS15', now() - INTERVAL '111 days 4 hours', 6, 'Sugestivo de depressão leve', 'Rastreio de sintomas depressivos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 14, 2, 'GDS15', now() - INTERVAL '75 days 6 hours', 6, 'Sugestivo de depressão leve', 'Rastreio de sintomas depressivos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 14, 12, 'ICOPE', now() - INTERVAL '156 days 5 hours', NULL, NULL, 'Triagem ICOPE de capacidade intrínseca');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'cognicao', 'Lembrou as 3 palavras', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'mobilidade', 'Levantou 5x da cadeira em 12s', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'visao', 'Sem queixas visuais', 0);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 32, 30, 'ICOPE', now() - INTERVAL '12 days 2 hours', NULL, NULL, 'Triagem ICOPE de capacidade intrínseca');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'cognicao', 'Lembrou 1 de 3 palavras', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'mobilidade', 'Não completou o teste da cadeira', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'visao', 'Sem queixas visuais', 0);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 32, 30, 'LAWTON', now() - INTERVAL '184 days 3 hours', 20, 'Dependência parcial', 'Atividades instrumentais (telefone, compras, medicação)');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 32, 28, 'LAWTON', now() - INTERVAL '80 days 5 hours', 19, 'Dependência parcial', 'Atividades instrumentais (telefone, compras, medicação)');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 8, 12, 'LAWTON', now() - INTERVAL '61 days 8 hours', 16, 'Dependência parcial', 'Atividades instrumentais (telefone, compras, medicação)');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 3, 12, 'KATZ', now() - INTERVAL '106 days 7 hours', 3, 'Dependência parcial', 'Avaliação de atividades básicas de vida diária');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'banho', 'Necessita ajuda', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'vestir-se', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'higiene pessoal', 'Necessita ajuda', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'transferência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'continência', 'Necessita ajuda', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'alimentação', 'Independente', 1);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 3, 2, 'GDS15', now() - INTERVAL '172 days 1 hours', 5, 'Sugestivo de depressão leve', 'Rastreio de sintomas depressivos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 3, 2, 'GDS15', now() - INTERVAL '132 days 4 hours', 2, 'Normal', 'Rastreio de sintomas depressivos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 29, 24, 'ICOPE', now() - INTERVAL '12 days 5 hours', NULL, NULL, 'Triagem ICOPE de capacidade intrínseca');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'cognicao', 'Lembrou as 3 palavras', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'mobilidade', 'Não completou o teste da cadeira', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'visao', 'Sem queixas visuais', 1);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 19, 2, 'WHOQOL_OLD', now() - INTERVAL '190 days 2 hours', 82, NULL, 'Qualidade de vida — módulo para idosos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 13, 2, 'GDS15', now() - INTERVAL '145 days 2 hours', 3, 'Normal', 'Rastreio de sintomas depressivos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 30, 20, 'WHOQOL_OLD', now() - INTERVAL '187 days 7 hours', 73, NULL, 'Qualidade de vida — módulo para idosos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 30, 20, 'WHOQOL_OLD', now() - INTERVAL '132 days 4 hours', 100, NULL, 'Qualidade de vida — módulo para idosos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 20, 12, 'LAWTON', now() - INTERVAL '27 days 8 hours', 12, 'Dependência importante', 'Atividades instrumentais (telefone, compras, medicação)');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 20, 1, 'ICOPE', now() - INTERVAL '167 days 6 hours', NULL, NULL, 'Triagem ICOPE de capacidade intrínseca');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'cognicao', 'Lembrou 1 de 3 palavras', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'mobilidade', 'Não completou o teste da cadeira', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'visao', 'Sem queixas visuais', 1);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 20, 1, 'ICOPE', now() - INTERVAL '61 days 6 hours', NULL, NULL, 'Triagem ICOPE de capacidade intrínseca');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'cognicao', 'Lembrou 1 de 3 palavras', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'mobilidade', 'Não completou o teste da cadeira', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'visao', 'Sem queixas visuais', 0);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 17, 13, 'KATZ', now() - INTERVAL '176 days 5 hours', 6, 'Independente', 'Avaliação de atividades básicas de vida diária');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'banho', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'vestir-se', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'higiene pessoal', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'transferência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'continência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'alimentação', 'Independente', 1);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 31, 28, 'LAWTON', now() - INTERVAL '159 days 1 hours', 20, 'Dependência parcial', 'Atividades instrumentais (telefone, compras, medicação)');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 31, 28, 'WHOQOL_OLD', now() - INTERVAL '115 days 6 hours', 71, NULL, 'Qualidade de vida — módulo para idosos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 5, 13, 'KATZ', now() - INTERVAL '142 days 5 hours', 6, 'Independente', 'Avaliação de atividades básicas de vida diária');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'banho', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'vestir-se', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'higiene pessoal', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'transferência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'continência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'alimentação', 'Independente', 1);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 5, 13, 'KATZ', now() - INTERVAL '95 days 8 hours', 5, 'Independente', 'Avaliação de atividades básicas de vida diária');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'banho', 'Necessita ajuda', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'vestir-se', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'higiene pessoal', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'transferência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'continência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'alimentação', 'Independente', 1);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 12, 13, 'KATZ', now() - INTERVAL '187 days 5 hours', 6, 'Independente', 'Avaliação de atividades básicas de vida diária');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'banho', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'vestir-se', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'higiene pessoal', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'transferência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'continência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'alimentação', 'Independente', 1);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 12, 13, 'ICOPE', now() - INTERVAL '76 days 1 hours', NULL, NULL, 'Triagem ICOPE de capacidade intrínseca');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'cognicao', 'Lembrou as 3 palavras', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'mobilidade', 'Levantou 5x da cadeira em 12s', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'visao', 'Dificuldade para ler de perto', 1);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 7, 12, 'KATZ', now() - INTERVAL '132 days 7 hours', 5, 'Independente', 'Avaliação de atividades básicas de vida diária');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'banho', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'vestir-se', 'Necessita ajuda', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'higiene pessoal', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'transferência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'continência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'alimentação', 'Independente', 1);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 4, 20, 'GDS15', now() - INTERVAL '112 days 1 hours', 5, 'Sugestivo de depressão leve', 'Rastreio de sintomas depressivos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 4, 4, 'ICOPE', now() - INTERVAL '61 days 2 hours', NULL, NULL, 'Triagem ICOPE de capacidade intrínseca');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'cognicao', 'Lembrou 1 de 3 palavras', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'mobilidade', 'Levantou 5x da cadeira em 12s', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'visao', 'Sem queixas visuais', 0);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 27, 4, 'LAWTON', now() - INTERVAL '135 days 2 hours', 15, 'Dependência importante', 'Atividades instrumentais (telefone, compras, medicação)');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 21, 13, 'KATZ', now() - INTERVAL '122 days 5 hours', 5, 'Independente', 'Avaliação de atividades básicas de vida diária');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'banho', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'vestir-se', 'Necessita ajuda', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'higiene pessoal', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'transferência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'continência', 'Independente', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'alimentação', 'Independente', 1);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 21, 13, 'ICOPE', now() - INTERVAL '65 days 6 hours', NULL, NULL, 'Triagem ICOPE de capacidade intrínseca');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'cognicao', 'Lembrou as 3 palavras', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'mobilidade', 'Levantou 5x da cadeira em 12s', 1),
   (currval('avaliacao_id_avaliacao_seq'), 'visao', 'Dificuldade para ler de perto', 0);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 23, 2, 'WHOQOL_OLD', now() - INTERVAL '79 days 3 hours', 61, NULL, 'Qualidade de vida — módulo para idosos');
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 23, 13, 'ICOPE', now() - INTERVAL '47 days 4 hours', NULL, NULL, 'Triagem ICOPE de capacidade intrínseca');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'cognicao', 'Lembrou as 3 palavras', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'mobilidade', 'Levantou 5x da cadeira em 12s', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'visao', 'Sem queixas visuais', 0);
INSERT INTO avaliacao (id_avaliacao, id_idoso, id_profissional, instrumento, data_hora, pontuacao_total, interpretacao, observacoes) VALUES
 (nextval('avaliacao_id_avaliacao_seq'), 23, 1, 'ICOPE', now() - INTERVAL '25 days 1 hours', NULL, NULL, 'Triagem ICOPE de capacidade intrínseca');
  INSERT INTO item_avaliacao (id_avaliacao, dominio, resposta, pontuacao) VALUES
   (currval('avaliacao_id_avaliacao_seq'), 'cognicao', 'Lembrou 1 de 3 palavras', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'mobilidade', 'Não completou o teste da cadeira', 0),
   (currval('avaliacao_id_avaliacao_seq'), 'visao', 'Sem queixas visuais', 0);

-- ---------- Registros de saúde complementares ----------
INSERT INTO registro_saude (id_idoso, id_profissional, tipo, data_hora, descricao) VALUES
 (14, 10, 'consulta', now() - INTERVAL '58 days 6 hours', 'Consulta odontológica: ajuste da prótese'),
 (29, 23, 'sinais_vitais', now() - INTERVAL '13 days 9 hours', 'PA 124x74, FC 66, afebril'),
 (6, 12, 'consulta', now() - INTERVAL '53 days 3 hours', 'Consulta de rotina com clínico geral'),
 (32, 28, 'medicacao', now() - INTERVAL '14 days 8 hours', 'Ajuste de dose do anti-hipertensivo'),
 (28, 4, 'sinais_vitais', now() - INTERVAL '20 days 1 hours', 'PA 134x83, saturação 96%, sem queixas'),
 (11, 10, 'intercorrencia', now() - INTERVAL '47 days 1 hours', 'Queixa de dor abdominal leve; observação por 24h'),
 (32, 28, 'intercorrencia', now() - INTERVAL '39 days 9 hours', 'Episódio de tontura ao levantar; orientado repouso'),
 (16, 13, 'sinais_vitais', now() - INTERVAL '34 days 7 hours', 'PA 116x71, saturação 96%, sem queixas'),
 (10, 11, 'intercorrencia', now() - INTERVAL '1 days 8 hours', 'Queixa de dor abdominal leve; observação por 24h'),
 (23, 13, 'consulta', now() - INTERVAL '22 days 6 hours', 'Consulta odontológica: ajuste da prótese'),
 (23, 11, 'sinais_vitais', now() - INTERVAL '36 days 6 hours', 'PA 117x70, saturação 96%, sem queixas'),
 (26, 23, 'sinais_vitais', now() - INTERVAL '47 days 6 hours', 'PA 126x76, saturação 96%, sem queixas'),
 (18, 18, 'medicacao', now() - INTERVAL '19 days 6 hours', 'Suspenso AINE por queixa gástrica'),
 (26, 23, 'medicacao', now() - INTERVAL '48 days 4 hours', 'Suspenso AINE por queixa gástrica'),
 (29, 4, 'medicacao', now() - INTERVAL '20 days 3 hours', 'Iniciada suplementação de vitamina D'),
 (16, 11, 'medicacao', now() - INTERVAL '7 days 2 hours', 'Iniciada suplementação de vitamina D'),
 (30, 4, 'intercorrencia', now() - INTERVAL '17 days 7 hours', 'Queixa de dor abdominal leve; observação por 24h'),
 (5, 10, 'intercorrencia', now() - INTERVAL '50 days 10 hours', 'Episódio de tontura ao levantar; orientado repouso'),
 (12, 11, 'consulta', now() - INTERVAL '8 days 4 hours', 'Consulta de rotina com clínico geral'),
 (32, 30, 'intercorrencia', now() - INTERVAL '39 days 2 hours', 'Queixa de dor abdominal leve; observação por 24h'),
 (11, 12, 'consulta', now() - INTERVAL '32 days 8 hours', 'Consulta de rotina com clínico geral'),
 (25, 24, 'intercorrencia', now() - INTERVAL '38 days 1 hours', 'Queixa de dor abdominal leve; observação por 24h'),
 (12, 10, 'medicacao', now() - INTERVAL '14 days 6 hours', 'Iniciada suplementação de vitamina D'),
 (13, 12, 'medicacao', now() - INTERVAL '31 days 7 hours', 'Ajuste de dose do anti-hipertensivo'),
 (8, 1, 'sinais_vitais', now() - INTERVAL '37 days 10 hours', 'PA 114x73, FC 65, afebril'),
 (6, 1, 'sinais_vitais', now() - INTERVAL '6 days 10 hours', 'PA 111x85, saturação 96%, sem queixas'),
 (8, 13, 'medicacao', now() - INTERVAL '4 days 4 hours', 'Suspenso AINE por queixa gástrica'),
 (9, 18, 'consulta', now() - INTERVAL '33 days 5 hours', 'Consulta odontológica: ajuste da prótese'),
 (32, 30, 'consulta', now() - INTERVAL '5 days 3 hours', 'Consulta de rotina com clínico geral'),
 (4, 4, 'medicacao', now() - INTERVAL '19 days 4 hours', 'Suspenso AINE por queixa gástrica'),
 (6, 10, 'medicacao', now() - INTERVAL '24 days 7 hours', 'Suspenso AINE por queixa gástrica'),
 (6, 12, 'medicacao', now() - INTERVAL '48 days 4 hours', 'Ajuste de dose do anti-hipertensivo');

-- ---------- Atendimentos psicológicos complementares (sigilo: só o psicólogo lê, via RLS) ----------
INSERT INTO atendimento_psicologico (id_idoso, id_profissional, data_hora, evolucao) VALUES
 (15, 2, now() - INTERVAL '28 days 6 hours', 'Luto pela perda do cônjuge; manter acompanhamento semanal.'),
 (15, 2, now() - INTERVAL '16 days 5 hours', 'Sessão breve; paciente sonolento após medicação.'),
 (5, 2, now() - INTERVAL '13 days 7 hours', 'Ansiedade relacionada a consultas médicas; técnicas de respiração.'),
 (3, 2, now() - INTERVAL '62 days 3 hours', 'Sessão breve; paciente sonolento após medicação.'),
 (3, 2, now() - INTERVAL '82 days 2 hours', 'Melhora do sono relatada; segue engajado no dominó.'),
 (18, 2, now() - INTERVAL '14 days 5 hours', 'Queixas de solidão; combinado contato mais frequente com a família.'),
 (7, 2, now() - INTERVAL '43 days 7 hours', 'Acolhimento; relata saudade de casa e da rotina antiga.'),
 (12, 2, now() - INTERVAL '16 days 3 hours', 'Trabalhadas memórias afetivas com fotografias trazidas pela família.'),
 (21, 2, now() - INTERVAL '58 days 4 hours', 'Queixas de solidão; combinado contato mais frequente com a família.'),
 (5, 2, now() - INTERVAL '56 days 2 hours', 'Acolhimento; relata saudade de casa e da rotina antiga.'),
 (3, 2, now() - INTERVAL '73 days 5 hours', 'Melhora do sono relatada; segue engajado no dominó.'),
 (1, 2, now() - INTERVAL '88 days 5 hours', 'Melhora do sono relatada; segue engajado no dominó.'),
 (23, 2, now() - INTERVAL '30 days 5 hours', 'Sessão breve; paciente sonolento após medicação.'),
 (15, 2, now() - INTERVAL '88 days 7 hours', 'Queixas de solidão; combinado contato mais frequente com a família.'),
 (19, 2, now() - INTERVAL '12 days 3 hours', 'Acolhimento; relata saudade de casa e da rotina antiga.'),
 (9, 2, now() - INTERVAL '79 days 5 hours', 'Luto pela perda do cônjuge; manter acompanhamento semanal.'),
 (14, 2, now() - INTERVAL '15 days 2 hours', 'Acolhimento; relata saudade de casa e da rotina antiga.'),
 (10, 2, now() - INTERVAL '30 days 2 hours', 'Humor estável; boa adesão às atividades em grupo.'),
 (13, 2, now() - INTERVAL '66 days 8 hours', 'Queixas de solidão; combinado contato mais frequente com a família.'),
 (19, 2, now() - INTERVAL '1 days 2 hours', 'Queixas de solidão; combinado contato mais frequente com a família.'),
 (29, 20, now() - INTERVAL '16 days 1 hours', 'Queixas de solidão; combinado contato mais frequente com a família.'),
 (24, 20, now() - INTERVAL '78 days 3 hours', 'Queixas de solidão; combinado contato mais frequente com a família.'),
 (28, 20, now() - INTERVAL '55 days 1 hours', 'Queixas de solidão; combinado contato mais frequente com a família.'),
 (4, 20, now() - INTERVAL '16 days 2 hours', 'Ansiedade relacionada a consultas médicas; técnicas de respiração.'),
 (25, 20, now() - INTERVAL '73 days 4 hours', 'Acolhimento; relata saudade de casa e da rotina antiga.'),
 (29, 20, now() - INTERVAL '43 days 8 hours', 'Trabalhadas memórias afetivas com fotografias trazidas pela família.'),
 (24, 20, now() - INTERVAL '87 days 6 hours', 'Sessão breve; paciente sonolento após medicação.'),
 (29, 20, now() - INTERVAL '58 days 4 hours', 'Humor estável; boa adesão às atividades em grupo.'),
 (24, 20, now() - INTERVAL '21 days 3 hours', 'Melhora do sono relatada; segue engajado no dominó.'),
 (4, 20, now() - INTERVAL '88 days 4 hours', 'Sessão breve; paciente sonolento após medicação.');

-- ---------- Atividades de lazer complementares e participações ----------
INSERT INTO atividade_lazer (id_atividade, id_ilpi, nome, categoria, data_hora) VALUES
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Hidroginástica', 'fisica', now() - INTERVAL '32 days 3 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Jogo da memória em grupo', 'cognitiva', now() - INTERVAL '33 days 3 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Forró pé de serra', 'social', now() - INTERVAL '27 days 4 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Missa', 'espiritual', now() - INTERVAL '14 days 2 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Caminhada no jardim', 'fisica', now() - INTERVAL '26 days 2 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Missa', 'espiritual', now() - INTERVAL '13 days 3 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Cinema com pipoca', 'social', now() - INTERVAL '25 days 2 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Missa', 'espiritual', now() - INTERVAL '6 days 3 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Cinema com pipoca', 'social', now() - INTERVAL '17 days 4 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Jogo da memória em grupo', 'cognitiva', now() - INTERVAL '28 days 2 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Terço comunitário', 'espiritual', now() - INTERVAL '18 days 2 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Missa', 'espiritual', now() - INTERVAL '20 days 3 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Contação de causos', 'social', now() - INTERVAL '31 days 4 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Forró pé de serra', 'social', now() - INTERVAL '16 days 2 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Forró pé de serra', 'social', now() - INTERVAL '26 days 2 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 1, 'Caminhada no jardim', 'fisica', now() - INTERVAL '4 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 2, 'Yoga na cadeira', 'fisica', now() - INTERVAL '7 days 3 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 2, 'Cinema com pipoca', 'social', now() - INTERVAL '6 days 2 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 2, 'Jogo da memória em grupo', 'cognitiva', now() - INTERVAL '38 days 2 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 2, 'Jogo da memória em grupo', 'cognitiva', now() - INTERVAL '37 days 4 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 2, 'Caminhada no jardim', 'fisica', now() - INTERVAL '38 days 3 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 2, 'Missa', 'espiritual', now() - INTERVAL '18 days 2 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 2, 'Coral da casa', 'artistica', now() - INTERVAL '22 days 3 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 2, 'Coral da casa', 'artistica', now() + INTERVAL '7 days'),
 (nextval('atividade_lazer_id_atividade_seq'), 3, 'Hidroginástica', 'fisica', now() - INTERVAL '13 days 3 hours'),
 (nextval('atividade_lazer_id_atividade_seq'), 3, 'Jogo da memória em grupo', 'cognitiva', now() + INTERVAL '8 days'),
 (nextval('atividade_lazer_id_atividade_seq'), 3, 'Cinema com pipoca', 'social', now() - INTERVAL '14 days 3 hours');
INSERT INTO participacao (id_idoso, id_atividade, nivel_engajamento) VALUES
 (1, 6, 2),
 (3, 6, 2),
 (6, 6, 4),
 (7, 6, 2),
 (10, 6, 4),
 (11, 6, 2),
 (14, 6, 2),
 (17, 6, 4),
 (19, 6, 5),
 (20, 6, 3),
 (21, 6, 1),
 (23, 6, 4),
 (5, 7, 3),
 (6, 7, 4),
 (7, 7, 4),
 (8, 7, 3),
 (9, 7, 4),
 (11, 7, 1),
 (12, 7, 3),
 (15, 7, 5),
 (16, 7, 5),
 (19, 7, 4),
 (20, 7, 2),
 (21, 7, 3),
 (3, 8, 3),
 (5, 8, 5),
 (6, 8, 5),
 (11, 8, 3),
 (12, 8, 5),
 (15, 8, 5),
 (17, 8, 3),
 (18, 8, 1),
 (21, 8, 5),
 (23, 8, 3),
 (1, 9, 4),
 (2, 9, 4),
 (3, 9, 5),
 (5, 9, 5),
 (6, 9, 5),
 (12, 9, 5),
 (13, 9, 3),
 (14, 9, 3),
 (15, 9, 3),
 (17, 9, 4),
 (19, 9, 3),
 (21, 9, 3),
 (23, 9, 4),
 (2, 10, 3),
 (3, 10, 5),
 (6, 10, 4),
 (7, 10, 3),
 (10, 10, 5),
 (11, 10, 3),
 (23, 10, 5),
 (1, 11, 4),
 (5, 11, 4),
 (6, 11, 5),
 (8, 11, 5),
 (9, 11, 3),
 (10, 11, 1),
 (11, 11, 2),
 (14, 11, 4),
 (17, 11, 5),
 (19, 11, 1),
 (21, 11, 3),
 (8, 12, 3),
 (13, 12, 5),
 (14, 12, 2),
 (17, 12, 4),
 (19, 12, 3),
 (21, 12, 5),
 (1, 13, 3),
 (3, 13, 4),
 (5, 13, 3),
 (6, 13, 5),
 (7, 13, 5),
 (8, 13, 4),
 (9, 13, 4),
 (12, 13, 5),
 (16, 13, 3),
 (19, 13, 4),
 (20, 13, 5),
 (21, 13, 3),
 (23, 13, 4),
 (5, 14, 3),
 (8, 14, 4),
 (9, 14, 4),
 (10, 14, 4),
 (16, 14, 2),
 (18, 14, 5),
 (19, 14, 2),
 (21, 14, 5),
 (23, 14, 5),
 (8, 15, 2),
 (9, 15, 5),
 (11, 15, 3),
 (14, 15, 5),
 (15, 15, 3),
 (17, 15, 2),
 (23, 15, 3),
 (2, 16, 4),
 (3, 16, 1),
 (10, 16, 2),
 (11, 16, 3),
 (12, 16, 5),
 (13, 16, 4),
 (14, 16, 4),
 (20, 16, 4),
 (1, 17, 3),
 (3, 17, 5),
 (8, 17, 3),
 (9, 17, 3),
 (11, 17, 5),
 (14, 17, 5),
 (15, 17, 4),
 (18, 17, 1),
 (21, 17, 3),
 (23, 17, 2),
 (1, 18, 5),
 (3, 18, 1),
 (5, 18, 3),
 (6, 18, 3),
 (7, 18, 1),
 (14, 18, 3),
 (17, 18, 4),
 (19, 18, 5),
 (21, 18, 4),
 (1, 19, 4),
 (2, 19, 3),
 (3, 19, 4),
 (5, 19, 4),
 (7, 19, 5),
 (9, 19, 4),
 (10, 19, 4),
 (12, 19, 3),
 (13, 19, 3),
 (14, 19, 4),
 (15, 19, 2),
 (17, 19, 4),
 (20, 19, 1),
 (21, 19, 4),
 (23, 19, 2),
 (1, 20, 5),
 (2, 20, 4),
 (3, 20, 4),
 (5, 20, 4),
 (7, 20, 2),
 (11, 20, 4),
 (14, 20, 1),
 (18, 20, 4),
 (19, 20, 5),
 (20, 20, 2),
 (23, 20, 5),
 (1, 21, 5),
 (2, 21, 1),
 (5, 21, 1),
 (8, 21, 3),
 (9, 21, 5),
 (10, 21, 3),
 (12, 21, 4),
 (14, 21, 5),
 (15, 21, 3),
 (17, 21, 5),
 (23, 21, 4),
 (24, 22, 5),
 (25, 22, 3),
 (29, 22, 3),
 (4, 23, 3),
 (28, 23, 5),
 (29, 23, 5),
 (4, 24, 3),
 (24, 24, 4),
 (26, 24, 5),
 (4, 25, 4),
 (24, 25, 5),
 (26, 25, 5),
 (28, 25, 3),
 (4, 26, 5),
 (24, 26, 2),
 (25, 26, 4),
 (27, 26, 3),
 (28, 26, 4),
 (29, 26, 4),
 (30, 26, 3),
 (4, 27, 4),
 (25, 27, 5),
 (28, 27, 4),
 (24, 28, 4),
 (25, 28, 4),
 (29, 28, 5),
 (30, 28, 3);

-- ---------- Partidas do Dominó do Lar (NULL no jogador 2 = contra o computador) ----------
INSERT INTO partida_domino (id_ilpi, id_jogador1, id_jogador2, vencedor, motivo, data_hora) VALUES
 (1, 6, 11, 2, 'bateu', now() - INTERVAL '13 days 8 hours'),
 (1, 8, 13, 1, 'fechado', now() - INTERVAL '21 days 8 hours'),
 (1, 2, 1, 1, 'bateu', now() - INTERVAL '1 days 2 hours'),
 (1, 5, 7, 2, 'bateu', now() - INTERVAL '17 days 1 hours'),
 (1, 12, 13, 1, 'bateu', now() - INTERVAL '22 days 9 hours'),
 (1, 11, 13, 1, 'bateu', now() - INTERVAL '26 days 9 hours'),
 (1, 10, 11, 1, 'bateu', now() - INTERVAL '29 days 5 hours'),
 (1, 13, 10, NULL, 'abandono', now() - INTERVAL '1 days 5 hours'),
 (1, 12, NULL, 1, 'fechado', now() - INTERVAL '8 days 1 hours'),
 (1, 13, 7, 2, 'bateu', now() - INTERVAL '25 days 7 hours'),
 (1, 1, 7, 2, 'bateu', now() - INTERVAL '23 days 1 hours'),
 (1, 14, NULL, 1, 'bateu', now() - INTERVAL '4 days 1 hours'),
 (1, 5, 12, 1, 'bateu', now() - INTERVAL '15 days 3 hours'),
 (1, 1, 7, 2, 'fechado', now() - INTERVAL '26 days 9 hours'),
 (1, 6, 13, 1, 'bateu', now() - INTERVAL '6 hours'),
 (1, 14, 13, 2, 'bateu', now() - INTERVAL '4 days 8 hours'),
 (1, 11, 7, 1, 'bateu', now() - INTERVAL '15 days 7 hours'),
 (1, 10, 12, 2, 'fechado', now() - INTERVAL '21 days 8 hours'),
 (1, 8, 2, 1, 'bateu', now() - INTERVAL '10 days 8 hours'),
 (1, 1, 13, 1, 'bateu', now() - INTERVAL '10 days 3 hours'),
 (1, 14, 12, 2, 'fechado', now() - INTERVAL '1 days 3 hours'),
 (1, 12, 14, 1, 'bateu', now() - INTERVAL '9 hours'),
 (1, 13, 7, NULL, 'abandono', now() - INTERVAL '16 days 1 hours'),
 (1, 14, 2, 2, 'bateu', now() - INTERVAL '25 days 1 hours'),
 (1, 7, NULL, 1, 'bateu', now() - INTERVAL '27 days 4 hours'),
 (1, 6, 8, 2, 'bateu', now() - INTERVAL '24 days 4 hours'),
 (1, 2, 11, 2, 'bateu', now() - INTERVAL '25 days 7 hours'),
 (1, 8, 13, 2, 'bateu', now() - INTERVAL '3 days 9 hours'),
 (1, 2, 7, 1, 'fechado', now() - INTERVAL '26 days 1 hours'),
 (1, 13, 11, 2, 'fechado', now() - INTERVAL '28 days 1 hours'),
 (1, 10, 1, 1, 'bateu', now() - INTERVAL '15 days 7 hours'),
 (1, 6, 2, 2, 'bateu', now() - INTERVAL '25 days 6 hours'),
 (1, 14, 1, 2, 'bateu', now() - INTERVAL '26 days 7 hours'),
 (1, 8, 7, 2, 'bateu', now() - INTERVAL '15 days 2 hours'),
 (1, 7, 2, 2, 'bateu', now() - INTERVAL '1 hours'),
 (1, 13, 6, 2, 'bateu', now() - INTERVAL '15 days 3 hours');

-- ---------- Prescrições e administração de doses ----------
-- As doses dos 7 últimos dias completos entram logo após a prescrição,
-- com id_prescricao = currval('prescricao_id_prescricao_seq').
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 1, 13, 'AAS', '100 mg', ARRAY['12:00'::time], CURRENT_DATE - 112, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 1) + TIME '12:00', (CURRENT_DATE - 1) + TIME '12:00' + INTERVAL '29 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 2) + TIME '12:00', (CURRENT_DATE - 2) + TIME '12:00' + INTERVAL '27 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 3) + TIME '12:00', (CURRENT_DATE - 3) + TIME '12:00' + INTERVAL '0 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 4) + TIME '12:00', (CURRENT_DATE - 4) + TIME '12:00' + INTERVAL '32 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 5) + TIME '12:00', (CURRENT_DATE - 5) + TIME '12:00' + INTERVAL '21 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 6) + TIME '12:00', (CURRENT_DATE - 6) + TIME '12:00' + INTERVAL '36 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 7) + TIME '12:00', (CURRENT_DATE - 7) + TIME '12:00' + INTERVAL '35 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 2, 13, 'Omeprazol', '20 mg', ARRAY['07:00'::time], CURRENT_DATE - 276, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 1) + TIME '07:00', (CURRENT_DATE - 1) + TIME '07:00' + INTERVAL '25 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 2) + TIME '07:00', (CURRENT_DATE - 2) + TIME '07:00' + INTERVAL '21 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 3) + TIME '07:00', (CURRENT_DATE - 3) + TIME '07:00' + INTERVAL '4 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 4) + TIME '07:00', (CURRENT_DATE - 4) + TIME '07:00' + INTERVAL '18 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 5) + TIME '07:00', (CURRENT_DATE - 5) + TIME '07:00' + INTERVAL '10 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 7) + TIME '07:00', (CURRENT_DATE - 7) + TIME '07:00' + INTERVAL '23 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 3, 13, 'Paracetamol', '750 mg', ARRAY['08:00'::time, '14:00'::time, '20:00'::time], CURRENT_DATE - 250, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 1) + TIME '08:00', (CURRENT_DATE - 1) + TIME '08:00' + INTERVAL '7 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 1) + TIME '14:00', (CURRENT_DATE - 1) + TIME '14:00' + INTERVAL '15 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 1) + TIME '20:00', (CURRENT_DATE - 1) + TIME '20:00' + INTERVAL '17 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 2) + TIME '08:00', (CURRENT_DATE - 2) + TIME '08:00' + INTERVAL '36 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 2) + TIME '14:00', (CURRENT_DATE - 2) + TIME '14:00' + INTERVAL '5 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 2) + TIME '20:00', (CURRENT_DATE - 2) + TIME '20:00' + INTERVAL '35 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 3) + TIME '08:00', (CURRENT_DATE - 3) + TIME '08:00' + INTERVAL '24 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 3) + TIME '14:00', (CURRENT_DATE - 3) + TIME '14:00' + INTERVAL '1 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 3) + TIME '20:00', (CURRENT_DATE - 3) + TIME '20:00' + INTERVAL '13 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 4) + TIME '08:00', (CURRENT_DATE - 4) + TIME '08:00' + INTERVAL '40 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 4) + TIME '14:00', (CURRENT_DATE - 4) + TIME '14:00' + INTERVAL '22 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 4) + TIME '20:00', (CURRENT_DATE - 4) + TIME '20:00' + INTERVAL '26 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 5) + TIME '08:00', (CURRENT_DATE - 5) + TIME '08:00' + INTERVAL '14 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 5) + TIME '14:00', (CURRENT_DATE - 5) + TIME '14:00' + INTERVAL '10 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 5) + TIME '20:00', (CURRENT_DATE - 5) + TIME '20:00' + INTERVAL '15 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 6) + TIME '08:00', (CURRENT_DATE - 6) + TIME '08:00' + INTERVAL '22 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 6) + TIME '14:00', (CURRENT_DATE - 6) + TIME '14:00' + INTERVAL '25 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 6) + TIME '20:00', (CURRENT_DATE - 6) + TIME '20:00' + INTERVAL '33 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 7) + TIME '08:00', (CURRENT_DATE - 7) + TIME '08:00' + INTERVAL '20 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 7) + TIME '14:00', (CURRENT_DATE - 7) + TIME '14:00' + INTERVAL '18 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 7) + TIME '20:00', (CURRENT_DATE - 7) + TIME '20:00' + INTERVAL '16 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 4, 24, 'Paracetamol', '750 mg', ARRAY['08:00'::time, '14:00'::time, '20:00'::time], CURRENT_DATE - 271, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 1) + TIME '08:00', (CURRENT_DATE - 1) + TIME '08:00' + INTERVAL '8 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 1) + TIME '14:00', (CURRENT_DATE - 1) + TIME '14:00' + INTERVAL '20 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 1) + TIME '20:00', (CURRENT_DATE - 1) + TIME '20:00' + INTERVAL '2 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 2) + TIME '08:00', (CURRENT_DATE - 2) + TIME '08:00' + INTERVAL '40 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 2) + TIME '14:00', (CURRENT_DATE - 2) + TIME '14:00' + INTERVAL '15 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 2) + TIME '20:00', (CURRENT_DATE - 2) + TIME '20:00' + INTERVAL '2 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 3) + TIME '08:00', (CURRENT_DATE - 3) + TIME '08:00' + INTERVAL '21 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 3) + TIME '14:00', (CURRENT_DATE - 3) + TIME '14:00' + INTERVAL '12 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 3) + TIME '20:00', (CURRENT_DATE - 3) + TIME '20:00' + INTERVAL '2 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 4) + TIME '08:00', (CURRENT_DATE - 4) + TIME '08:00' + INTERVAL '40 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 5) + TIME '08:00', (CURRENT_DATE - 5) + TIME '08:00' + INTERVAL '36 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 5) + TIME '14:00', (CURRENT_DATE - 5) + TIME '14:00' + INTERVAL '29 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 5) + TIME '20:00', (CURRENT_DATE - 5) + TIME '20:00' + INTERVAL '38 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 6) + TIME '08:00', (CURRENT_DATE - 6) + TIME '08:00' + INTERVAL '8 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 6) + TIME '14:00', (CURRENT_DATE - 6) + TIME '14:00' + INTERVAL '13 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 6) + TIME '20:00', (CURRENT_DATE - 6) + TIME '20:00' + INTERVAL '8 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 7) + TIME '08:00', (CURRENT_DATE - 7) + TIME '08:00' + INTERVAL '24 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 7) + TIME '14:00', (CURRENT_DATE - 7) + TIME '14:00' + INTERVAL '17 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 7) + TIME '20:00', (CURRENT_DATE - 7) + TIME '20:00' + INTERVAL '7 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 5, 13, 'Metformina', '850 mg', ARRAY['07:00'::time, '19:00'::time], CURRENT_DATE - 323, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 1) + TIME '07:00', (CURRENT_DATE - 1) + TIME '07:00' + INTERVAL '8 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 1) + TIME '19:00', (CURRENT_DATE - 1) + TIME '19:00' + INTERVAL '9 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 2) + TIME '07:00', (CURRENT_DATE - 2) + TIME '07:00' + INTERVAL '24 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 2) + TIME '19:00', (CURRENT_DATE - 2) + TIME '19:00' + INTERVAL '13 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 3) + TIME '07:00', (CURRENT_DATE - 3) + TIME '07:00' + INTERVAL '30 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 3) + TIME '19:00', (CURRENT_DATE - 3) + TIME '19:00' + INTERVAL '16 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 4) + TIME '07:00', (CURRENT_DATE - 4) + TIME '07:00' + INTERVAL '33 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 4) + TIME '19:00', (CURRENT_DATE - 4) + TIME '19:00' + INTERVAL '38 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 5) + TIME '07:00', (CURRENT_DATE - 5) + TIME '07:00' + INTERVAL '7 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 5) + TIME '19:00', (CURRENT_DATE - 5) + TIME '19:00' + INTERVAL '25 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 6) + TIME '07:00', (CURRENT_DATE - 6) + TIME '07:00' + INTERVAL '20 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 6) + TIME '19:00', (CURRENT_DATE - 6) + TIME '19:00' + INTERVAL '13 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 7) + TIME '07:00', (CURRENT_DATE - 7) + TIME '07:00' + INTERVAL '11 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 7) + TIME '19:00', (CURRENT_DATE - 7) + TIME '19:00' + INTERVAL '33 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 6, 13, 'Omeprazol', '20 mg', ARRAY['07:00'::time], CURRENT_DATE - 75, CURRENT_DATE - 11, FALSE);
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 7, 13, 'Levotiroxina', '50 mcg', ARRAY['06:00'::time], CURRENT_DATE - 207, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 1) + TIME '06:00', (CURRENT_DATE - 1) + TIME '06:00' + INTERVAL '36 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 2) + TIME '06:00', (CURRENT_DATE - 2) + TIME '06:00' + INTERVAL '17 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 4) + TIME '06:00', (CURRENT_DATE - 4) + TIME '06:00' + INTERVAL '7 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 5) + TIME '06:00', (CURRENT_DATE - 5) + TIME '06:00' + INTERVAL '37 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 6) + TIME '06:00', (CURRENT_DATE - 6) + TIME '06:00' + INTERVAL '38 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 7) + TIME '06:00', (CURRENT_DATE - 7) + TIME '06:00' + INTERVAL '29 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 8, 13, 'Donepezila', '10 mg', ARRAY['20:00'::time], CURRENT_DATE - 36, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 1) + TIME '20:00', (CURRENT_DATE - 1) + TIME '20:00' + INTERVAL '25 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 2) + TIME '20:00', (CURRENT_DATE - 2) + TIME '20:00' + INTERVAL '13 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 3) + TIME '20:00', (CURRENT_DATE - 3) + TIME '20:00' + INTERVAL '20 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 4) + TIME '20:00', (CURRENT_DATE - 4) + TIME '20:00' + INTERVAL '13 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 5) + TIME '20:00', (CURRENT_DATE - 5) + TIME '20:00' + INTERVAL '31 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 6) + TIME '20:00', (CURRENT_DATE - 6) + TIME '20:00' + INTERVAL '3 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 9, 13, 'AAS', '100 mg', ARRAY['12:00'::time], CURRENT_DATE - 118, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 1) + TIME '12:00', (CURRENT_DATE - 1) + TIME '12:00' + INTERVAL '8 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 2) + TIME '12:00', (CURRENT_DATE - 2) + TIME '12:00' + INTERVAL '26 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 4) + TIME '12:00', (CURRENT_DATE - 4) + TIME '12:00' + INTERVAL '22 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 5) + TIME '12:00', (CURRENT_DATE - 5) + TIME '12:00' + INTERVAL '19 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 6) + TIME '12:00', (CURRENT_DATE - 6) + TIME '12:00' + INTERVAL '9 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 7) + TIME '12:00', (CURRENT_DATE - 7) + TIME '12:00' + INTERVAL '18 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 10, 13, 'Sertralina', '50 mg', ARRAY['08:00'::time], CURRENT_DATE - 376, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 1) + TIME '08:00', (CURRENT_DATE - 1) + TIME '08:00' + INTERVAL '37 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 2) + TIME '08:00', (CURRENT_DATE - 2) + TIME '08:00' + INTERVAL '23 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 3) + TIME '08:00', (CURRENT_DATE - 3) + TIME '08:00' + INTERVAL '11 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 4) + TIME '08:00', (CURRENT_DATE - 4) + TIME '08:00' + INTERVAL '18 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 5) + TIME '08:00', (CURRENT_DATE - 5) + TIME '08:00' + INTERVAL '30 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 6) + TIME '08:00', (CURRENT_DATE - 6) + TIME '08:00' + INTERVAL '25 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 7) + TIME '08:00', (CURRENT_DATE - 7) + TIME '08:00' + INTERVAL '24 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 11, 13, 'Metformina', '850 mg', ARRAY['07:00'::time, '19:00'::time], CURRENT_DATE - 237, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 1) + TIME '07:00', (CURRENT_DATE - 1) + TIME '07:00' + INTERVAL '16 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 1) + TIME '19:00', (CURRENT_DATE - 1) + TIME '19:00' + INTERVAL '36 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 2) + TIME '07:00', (CURRENT_DATE - 2) + TIME '07:00' + INTERVAL '36 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 2) + TIME '19:00', (CURRENT_DATE - 2) + TIME '19:00' + INTERVAL '32 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 3) + TIME '07:00', (CURRENT_DATE - 3) + TIME '07:00' + INTERVAL '29 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 3) + TIME '19:00', (CURRENT_DATE - 3) + TIME '19:00' + INTERVAL '40 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 4) + TIME '07:00', (CURRENT_DATE - 4) + TIME '07:00' + INTERVAL '37 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 4) + TIME '19:00', (CURRENT_DATE - 4) + TIME '19:00' + INTERVAL '6 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 5) + TIME '07:00', (CURRENT_DATE - 5) + TIME '07:00' + INTERVAL '24 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 5) + TIME '19:00', (CURRENT_DATE - 5) + TIME '19:00' + INTERVAL '5 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 6) + TIME '07:00', (CURRENT_DATE - 6) + TIME '07:00' + INTERVAL '4 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 6) + TIME '19:00', (CURRENT_DATE - 6) + TIME '19:00' + INTERVAL '24 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 7) + TIME '07:00', (CURRENT_DATE - 7) + TIME '07:00' + INTERVAL '30 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 7) + TIME '19:00', (CURRENT_DATE - 7) + TIME '19:00' + INTERVAL '0 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 12, 13, 'Losartana', '50 mg', ARRAY['08:00'::time, '20:00'::time], CURRENT_DATE - 232, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 1) + TIME '20:00', (CURRENT_DATE - 1) + TIME '20:00' + INTERVAL '28 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 2) + TIME '08:00', (CURRENT_DATE - 2) + TIME '08:00' + INTERVAL '29 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 2) + TIME '20:00', (CURRENT_DATE - 2) + TIME '20:00' + INTERVAL '31 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 3) + TIME '08:00', (CURRENT_DATE - 3) + TIME '08:00' + INTERVAL '28 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 4) + TIME '08:00', (CURRENT_DATE - 4) + TIME '08:00' + INTERVAL '30 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 4) + TIME '20:00', (CURRENT_DATE - 4) + TIME '20:00' + INTERVAL '29 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 5) + TIME '20:00', (CURRENT_DATE - 5) + TIME '20:00' + INTERVAL '33 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 6) + TIME '08:00', (CURRENT_DATE - 6) + TIME '08:00' + INTERVAL '29 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 7) + TIME '08:00', (CURRENT_DATE - 7) + TIME '08:00' + INTERVAL '23 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 7) + TIME '20:00', (CURRENT_DATE - 7) + TIME '20:00' + INTERVAL '40 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 13, 13, 'Vitamina D', '2000 UI', ARRAY['12:00'::time], CURRENT_DATE - 329, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 1) + TIME '12:00', (CURRENT_DATE - 1) + TIME '12:00' + INTERVAL '16 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 2) + TIME '12:00', (CURRENT_DATE - 2) + TIME '12:00' + INTERVAL '22 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 3) + TIME '12:00', (CURRENT_DATE - 3) + TIME '12:00' + INTERVAL '28 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 4) + TIME '12:00', (CURRENT_DATE - 4) + TIME '12:00' + INTERVAL '14 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 5) + TIME '12:00', (CURRENT_DATE - 5) + TIME '12:00' + INTERVAL '7 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 6) + TIME '12:00', (CURRENT_DATE - 6) + TIME '12:00' + INTERVAL '18 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 14, 13, 'Vitamina D', '2000 UI', ARRAY['12:00'::time], CURRENT_DATE - 237, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 2) + TIME '12:00', (CURRENT_DATE - 2) + TIME '12:00' + INTERVAL '3 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 3) + TIME '12:00', (CURRENT_DATE - 3) + TIME '12:00' + INTERVAL '11 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 4) + TIME '12:00', (CURRENT_DATE - 4) + TIME '12:00' + INTERVAL '15 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 5) + TIME '12:00', (CURRENT_DATE - 5) + TIME '12:00' + INTERVAL '4 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 6) + TIME '12:00', (CURRENT_DATE - 6) + TIME '12:00' + INTERVAL '27 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 7) + TIME '12:00', (CURRENT_DATE - 7) + TIME '12:00' + INTERVAL '23 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 15, 13, 'Donepezila', '10 mg', ARRAY['20:00'::time], CURRENT_DATE - 97, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 1) + TIME '20:00', (CURRENT_DATE - 1) + TIME '20:00' + INTERVAL '8 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 2) + TIME '20:00', (CURRENT_DATE - 2) + TIME '20:00' + INTERVAL '17 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 3) + TIME '20:00', (CURRENT_DATE - 3) + TIME '20:00' + INTERVAL '30 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 4) + TIME '20:00', (CURRENT_DATE - 4) + TIME '20:00' + INTERVAL '10 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 5) + TIME '20:00', (CURRENT_DATE - 5) + TIME '20:00' + INTERVAL '23 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 6) + TIME '20:00', (CURRENT_DATE - 6) + TIME '20:00' + INTERVAL '16 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 7) + TIME '20:00', (CURRENT_DATE - 7) + TIME '20:00' + INTERVAL '2 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 16, 13, 'Sertralina', '50 mg', ARRAY['08:00'::time], CURRENT_DATE - 349, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 1) + TIME '08:00', (CURRENT_DATE - 1) + TIME '08:00' + INTERVAL '24 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 2) + TIME '08:00', (CURRENT_DATE - 2) + TIME '08:00' + INTERVAL '15 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 3) + TIME '08:00', (CURRENT_DATE - 3) + TIME '08:00' + INTERVAL '10 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 4) + TIME '08:00', (CURRENT_DATE - 4) + TIME '08:00' + INTERVAL '7 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 5) + TIME '08:00', (CURRENT_DATE - 5) + TIME '08:00' + INTERVAL '40 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 6) + TIME '08:00', (CURRENT_DATE - 6) + TIME '08:00' + INTERVAL '38 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 7) + TIME '08:00', (CURRENT_DATE - 7) + TIME '08:00' + INTERVAL '12 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 17, 13, 'Omeprazol', '20 mg', ARRAY['07:00'::time], CURRENT_DATE - 289, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 1) + TIME '07:00', (CURRENT_DATE - 1) + TIME '07:00' + INTERVAL '34 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 2) + TIME '07:00', (CURRENT_DATE - 2) + TIME '07:00' + INTERVAL '12 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 3) + TIME '07:00', (CURRENT_DATE - 3) + TIME '07:00' + INTERVAL '9 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 4) + TIME '07:00', (CURRENT_DATE - 4) + TIME '07:00' + INTERVAL '18 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 5) + TIME '07:00', (CURRENT_DATE - 5) + TIME '07:00' + INTERVAL '6 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 7) + TIME '07:00', (CURRENT_DATE - 7) + TIME '07:00' + INTERVAL '21 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 18, 13, 'Furosemida', '40 mg', ARRAY['08:00'::time], CURRENT_DATE - 236, CURRENT_DATE - 5, FALSE);
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 19, 13, 'Levotiroxina', '50 mcg', ARRAY['06:00'::time], CURRENT_DATE - 246, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 1) + TIME '06:00', (CURRENT_DATE - 1) + TIME '06:00' + INTERVAL '0 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 2) + TIME '06:00', (CURRENT_DATE - 2) + TIME '06:00' + INTERVAL '20 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 3) + TIME '06:00', (CURRENT_DATE - 3) + TIME '06:00' + INTERVAL '26 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 4) + TIME '06:00', (CURRENT_DATE - 4) + TIME '06:00' + INTERVAL '34 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 5) + TIME '06:00', (CURRENT_DATE - 5) + TIME '06:00' + INTERVAL '27 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 6) + TIME '06:00', (CURRENT_DATE - 6) + TIME '06:00' + INTERVAL '34 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 7) + TIME '06:00', (CURRENT_DATE - 7) + TIME '06:00' + INTERVAL '15 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 20, 13, 'Sertralina', '50 mg', ARRAY['08:00'::time], CURRENT_DATE - 356, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 1) + TIME '08:00', (CURRENT_DATE - 1) + TIME '08:00' + INTERVAL '6 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 2) + TIME '08:00', (CURRENT_DATE - 2) + TIME '08:00' + INTERVAL '17 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 3) + TIME '08:00', (CURRENT_DATE - 3) + TIME '08:00' + INTERVAL '9 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 4) + TIME '08:00', (CURRENT_DATE - 4) + TIME '08:00' + INTERVAL '23 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 5) + TIME '08:00', (CURRENT_DATE - 5) + TIME '08:00' + INTERVAL '25 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 6) + TIME '08:00', (CURRENT_DATE - 6) + TIME '08:00' + INTERVAL '15 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 7) + TIME '08:00', (CURRENT_DATE - 7) + TIME '08:00' + INTERVAL '18 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 21, 13, 'Sertralina', '50 mg', ARRAY['08:00'::time], CURRENT_DATE - 31, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 1) + TIME '08:00', (CURRENT_DATE - 1) + TIME '08:00' + INTERVAL '39 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 2) + TIME '08:00', (CURRENT_DATE - 2) + TIME '08:00' + INTERVAL '19 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 3) + TIME '08:00', (CURRENT_DATE - 3) + TIME '08:00' + INTERVAL '21 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 4) + TIME '08:00', (CURRENT_DATE - 4) + TIME '08:00' + INTERVAL '13 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 5) + TIME '08:00', (CURRENT_DATE - 5) + TIME '08:00' + INTERVAL '12 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 6) + TIME '08:00', (CURRENT_DATE - 6) + TIME '08:00' + INTERVAL '26 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 7) + TIME '08:00', (CURRENT_DATE - 7) + TIME '08:00' + INTERVAL '17 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 23, 13, 'Vitamina D', '2000 UI', ARRAY['12:00'::time], CURRENT_DATE - 302, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 1) + TIME '12:00', (CURRENT_DATE - 1) + TIME '12:00' + INTERVAL '23 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 2) + TIME '12:00', (CURRENT_DATE - 2) + TIME '12:00' + INTERVAL '31 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 3) + TIME '12:00', (CURRENT_DATE - 3) + TIME '12:00' + INTERVAL '13 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 4) + TIME '12:00', (CURRENT_DATE - 4) + TIME '12:00' + INTERVAL '20 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 5) + TIME '12:00', (CURRENT_DATE - 5) + TIME '12:00' + INTERVAL '25 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 6) + TIME '12:00', (CURRENT_DATE - 6) + TIME '12:00' + INTERVAL '21 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 7) + TIME '12:00', (CURRENT_DATE - 7) + TIME '12:00' + INTERVAL '16 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 24, 24, 'Paracetamol', '750 mg', ARRAY['08:00'::time, '14:00'::time, '20:00'::time], CURRENT_DATE - 373, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 1) + TIME '08:00', (CURRENT_DATE - 1) + TIME '08:00' + INTERVAL '15 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 1) + TIME '14:00', (CURRENT_DATE - 1) + TIME '14:00' + INTERVAL '6 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 1) + TIME '20:00', (CURRENT_DATE - 1) + TIME '20:00' + INTERVAL '5 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 2) + TIME '08:00', (CURRENT_DATE - 2) + TIME '08:00' + INTERVAL '5 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 2) + TIME '14:00', (CURRENT_DATE - 2) + TIME '14:00' + INTERVAL '23 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 2) + TIME '20:00', (CURRENT_DATE - 2) + TIME '20:00' + INTERVAL '10 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 3) + TIME '08:00', (CURRENT_DATE - 3) + TIME '08:00' + INTERVAL '19 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 3) + TIME '14:00', (CURRENT_DATE - 3) + TIME '14:00' + INTERVAL '28 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 3) + TIME '20:00', (CURRENT_DATE - 3) + TIME '20:00' + INTERVAL '5 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 4) + TIME '08:00', (CURRENT_DATE - 4) + TIME '08:00' + INTERVAL '7 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 4) + TIME '14:00', (CURRENT_DATE - 4) + TIME '14:00' + INTERVAL '40 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 4) + TIME '20:00', (CURRENT_DATE - 4) + TIME '20:00' + INTERVAL '37 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 5) + TIME '14:00', (CURRENT_DATE - 5) + TIME '14:00' + INTERVAL '27 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 5) + TIME '20:00', (CURRENT_DATE - 5) + TIME '20:00' + INTERVAL '1 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 6) + TIME '08:00', (CURRENT_DATE - 6) + TIME '08:00' + INTERVAL '29 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 6) + TIME '14:00', (CURRENT_DATE - 6) + TIME '14:00' + INTERVAL '4 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 6) + TIME '20:00', (CURRENT_DATE - 6) + TIME '20:00' + INTERVAL '15 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 7) + TIME '08:00', (CURRENT_DATE - 7) + TIME '08:00' + INTERVAL '14 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 7) + TIME '20:00', (CURRENT_DATE - 7) + TIME '20:00' + INTERVAL '33 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 25, 24, 'Donepezila', '10 mg', ARRAY['20:00'::time], CURRENT_DATE - 182, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 1) + TIME '20:00', (CURRENT_DATE - 1) + TIME '20:00' + INTERVAL '28 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 2) + TIME '20:00', (CURRENT_DATE - 2) + TIME '20:00' + INTERVAL '11 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 3) + TIME '20:00', (CURRENT_DATE - 3) + TIME '20:00' + INTERVAL '40 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 4) + TIME '20:00', (CURRENT_DATE - 4) + TIME '20:00' + INTERVAL '22 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 5) + TIME '20:00', (CURRENT_DATE - 5) + TIME '20:00' + INTERVAL '40 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 6) + TIME '20:00', (CURRENT_DATE - 6) + TIME '20:00' + INTERVAL '17 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 7) + TIME '20:00', (CURRENT_DATE - 7) + TIME '20:00' + INTERVAL '2 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 26, 24, 'Metformina', '850 mg', ARRAY['07:00'::time, '19:00'::time], CURRENT_DATE - 217, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 1) + TIME '07:00', (CURRENT_DATE - 1) + TIME '07:00' + INTERVAL '32 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 1) + TIME '19:00', (CURRENT_DATE - 1) + TIME '19:00' + INTERVAL '39 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 2) + TIME '07:00', (CURRENT_DATE - 2) + TIME '07:00' + INTERVAL '14 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 2) + TIME '19:00', (CURRENT_DATE - 2) + TIME '19:00' + INTERVAL '16 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 3) + TIME '07:00', (CURRENT_DATE - 3) + TIME '07:00' + INTERVAL '0 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 3) + TIME '19:00', (CURRENT_DATE - 3) + TIME '19:00' + INTERVAL '8 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 4) + TIME '07:00', (CURRENT_DATE - 4) + TIME '07:00' + INTERVAL '5 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 4) + TIME '19:00', (CURRENT_DATE - 4) + TIME '19:00' + INTERVAL '4 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 5) + TIME '07:00', (CURRENT_DATE - 5) + TIME '07:00' + INTERVAL '36 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 6) + TIME '07:00', (CURRENT_DATE - 6) + TIME '07:00' + INTERVAL '30 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 7) + TIME '07:00', (CURRENT_DATE - 7) + TIME '07:00' + INTERVAL '15 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 7) + TIME '19:00', (CURRENT_DATE - 7) + TIME '19:00' + INTERVAL '39 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 27, 24, 'Sertralina', '50 mg', ARRAY['08:00'::time], CURRENT_DATE - 256, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 1) + TIME '08:00', (CURRENT_DATE - 1) + TIME '08:00' + INTERVAL '2 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 2) + TIME '08:00', (CURRENT_DATE - 2) + TIME '08:00' + INTERVAL '11 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 3) + TIME '08:00', (CURRENT_DATE - 3) + TIME '08:00' + INTERVAL '3 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 4) + TIME '08:00', (CURRENT_DATE - 4) + TIME '08:00' + INTERVAL '26 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 5) + TIME '08:00', (CURRENT_DATE - 5) + TIME '08:00' + INTERVAL '20 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 6) + TIME '08:00', (CURRENT_DATE - 6) + TIME '08:00' + INTERVAL '13 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 7) + TIME '08:00', (CURRENT_DATE - 7) + TIME '08:00' + INTERVAL '6 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 28, 24, 'Vitamina D', '2000 UI', ARRAY['12:00'::time], CURRENT_DATE - 177, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 1) + TIME '12:00', (CURRENT_DATE - 1) + TIME '12:00' + INTERVAL '30 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 2) + TIME '12:00', (CURRENT_DATE - 2) + TIME '12:00' + INTERVAL '31 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 3) + TIME '12:00', (CURRENT_DATE - 3) + TIME '12:00' + INTERVAL '10 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 4) + TIME '12:00', (CURRENT_DATE - 4) + TIME '12:00' + INTERVAL '23 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 5) + TIME '12:00', (CURRENT_DATE - 5) + TIME '12:00' + INTERVAL '32 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 6) + TIME '12:00', (CURRENT_DATE - 6) + TIME '12:00' + INTERVAL '22 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 7) + TIME '12:00', (CURRENT_DATE - 7) + TIME '12:00' + INTERVAL '39 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 29, 24, 'Furosemida', '40 mg', ARRAY['08:00'::time], CURRENT_DATE - 72, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 1) + TIME '08:00', (CURRENT_DATE - 1) + TIME '08:00' + INTERVAL '3 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 2) + TIME '08:00', (CURRENT_DATE - 2) + TIME '08:00' + INTERVAL '3 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 3) + TIME '08:00', (CURRENT_DATE - 3) + TIME '08:00' + INTERVAL '19 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 4) + TIME '08:00', (CURRENT_DATE - 4) + TIME '08:00' + INTERVAL '34 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 5) + TIME '08:00', (CURRENT_DATE - 5) + TIME '08:00' + INTERVAL '40 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 6) + TIME '08:00', (CURRENT_DATE - 6) + TIME '08:00' + INTERVAL '21 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 7) + TIME '08:00', (CURRENT_DATE - 7) + TIME '08:00' + INTERVAL '21 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 30, 24, 'AAS', '100 mg', ARRAY['12:00'::time], CURRENT_DATE - 148, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 1) + TIME '12:00', (CURRENT_DATE - 1) + TIME '12:00' + INTERVAL '10 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 2) + TIME '12:00', (CURRENT_DATE - 2) + TIME '12:00' + INTERVAL '19 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 4) + TIME '12:00', (CURRENT_DATE - 4) + TIME '12:00' + INTERVAL '25 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 5) + TIME '12:00', (CURRENT_DATE - 5) + TIME '12:00' + INTERVAL '14 minutes'),
   (currval('prescricao_id_prescricao_seq'), 23, (CURRENT_DATE - 6) + TIME '12:00', (CURRENT_DATE - 6) + TIME '12:00' + INTERVAL '28 minutes'),
   (currval('prescricao_id_prescricao_seq'), 4, (CURRENT_DATE - 7) + TIME '12:00', (CURRENT_DATE - 7) + TIME '12:00' + INTERVAL '13 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 31, 30, 'Losartana', '50 mg', ARRAY['08:00'::time, '20:00'::time], CURRENT_DATE - 274, CURRENT_DATE - 4, FALSE);
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 32, 30, 'Vitamina D', '2000 UI', ARRAY['12:00'::time], CURRENT_DATE - 65, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 28, (CURRENT_DATE - 2) + TIME '12:00', (CURRENT_DATE - 2) + TIME '12:00' + INTERVAL '40 minutes'),
   (currval('prescricao_id_prescricao_seq'), 28, (CURRENT_DATE - 3) + TIME '12:00', (CURRENT_DATE - 3) + TIME '12:00' + INTERVAL '38 minutes'),
   (currval('prescricao_id_prescricao_seq'), 28, (CURRENT_DATE - 4) + TIME '12:00', (CURRENT_DATE - 4) + TIME '12:00' + INTERVAL '24 minutes'),
   (currval('prescricao_id_prescricao_seq'), 28, (CURRENT_DATE - 5) + TIME '12:00', (CURRENT_DATE - 5) + TIME '12:00' + INTERVAL '25 minutes'),
   (currval('prescricao_id_prescricao_seq'), 28, (CURRENT_DATE - 6) + TIME '12:00', (CURRENT_DATE - 6) + TIME '12:00' + INTERVAL '30 minutes'),
   (currval('prescricao_id_prescricao_seq'), 28, (CURRENT_DATE - 7) + TIME '12:00', (CURRENT_DATE - 7) + TIME '12:00' + INTERVAL '32 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 1, 13, 'Vitamina D', '2000 UI', ARRAY['12:00'::time], CURRENT_DATE - 154, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 1) + TIME '12:00', (CURRENT_DATE - 1) + TIME '12:00' + INTERVAL '18 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 2) + TIME '12:00', (CURRENT_DATE - 2) + TIME '12:00' + INTERVAL '27 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 3) + TIME '12:00', (CURRENT_DATE - 3) + TIME '12:00' + INTERVAL '8 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 4) + TIME '12:00', (CURRENT_DATE - 4) + TIME '12:00' + INTERVAL '28 minutes'),
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 5) + TIME '12:00', (CURRENT_DATE - 5) + TIME '12:00' + INTERVAL '18 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 6) + TIME '12:00', (CURRENT_DATE - 6) + TIME '12:00' + INTERVAL '39 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 7) + TIME '12:00', (CURRENT_DATE - 7) + TIME '12:00' + INTERVAL '38 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 2, 13, 'Quetiapina', '25 mg', ARRAY['21:00'::time], CURRENT_DATE - 142, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 1) + TIME '21:00', (CURRENT_DATE - 1) + TIME '21:00' + INTERVAL '39 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 2) + TIME '21:00', (CURRENT_DATE - 2) + TIME '21:00' + INTERVAL '18 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 3) + TIME '21:00', (CURRENT_DATE - 3) + TIME '21:00' + INTERVAL '39 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 4) + TIME '21:00', (CURRENT_DATE - 4) + TIME '21:00' + INTERVAL '16 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 5) + TIME '21:00', (CURRENT_DATE - 5) + TIME '21:00' + INTERVAL '39 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 6) + TIME '21:00', (CURRENT_DATE - 6) + TIME '21:00' + INTERVAL '21 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 7) + TIME '21:00', (CURRENT_DATE - 7) + TIME '21:00' + INTERVAL '18 minutes');
INSERT INTO prescricao (id_prescricao, id_idoso, id_profissional, medicamento, dose, horarios, inicio, fim, ativo) VALUES
 (nextval('prescricao_id_prescricao_seq'), 3, 13, 'Losartana', '50 mg', ARRAY['08:00'::time, '20:00'::time], CURRENT_DATE - 124, NULL, TRUE);
  INSERT INTO administracao_medicacao (id_prescricao, id_profissional, horario_previsto, administrado_em) VALUES
   (currval('prescricao_id_prescricao_seq'), 12, (CURRENT_DATE - 1) + TIME '08:00', (CURRENT_DATE - 1) + TIME '08:00' + INTERVAL '34 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 1) + TIME '20:00', (CURRENT_DATE - 1) + TIME '20:00' + INTERVAL '32 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 2) + TIME '08:00', (CURRENT_DATE - 2) + TIME '08:00' + INTERVAL '32 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 2) + TIME '20:00', (CURRENT_DATE - 2) + TIME '20:00' + INTERVAL '7 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 3) + TIME '08:00', (CURRENT_DATE - 3) + TIME '08:00' + INTERVAL '4 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 3) + TIME '20:00', (CURRENT_DATE - 3) + TIME '20:00' + INTERVAL '26 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 4) + TIME '08:00', (CURRENT_DATE - 4) + TIME '08:00' + INTERVAL '13 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 4) + TIME '20:00', (CURRENT_DATE - 4) + TIME '20:00' + INTERVAL '36 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 5) + TIME '08:00', (CURRENT_DATE - 5) + TIME '08:00' + INTERVAL '35 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 5) + TIME '20:00', (CURRENT_DATE - 5) + TIME '20:00' + INTERVAL '6 minutes'),
   (currval('prescricao_id_prescricao_seq'), 11, (CURRENT_DATE - 6) + TIME '08:00', (CURRENT_DATE - 6) + TIME '08:00' + INTERVAL '29 minutes'),
   (currval('prescricao_id_prescricao_seq'), 18, (CURRENT_DATE - 6) + TIME '20:00', (CURRENT_DATE - 6) + TIME '20:00' + INTERVAL '32 minutes'),
   (currval('prescricao_id_prescricao_seq'), 1, (CURRENT_DATE - 7) + TIME '08:00', (CURRENT_DATE - 7) + TIME '08:00' + INTERVAL '23 minutes'),
   (currval('prescricao_id_prescricao_seq'), 10, (CURRENT_DATE - 7) + TIME '20:00', (CURRENT_DATE - 7) + TIME '20:00' + INTERVAL '31 minutes');

-- ---------- Recados do Mural da Família ----------
INSERT INTO recado_mural (id_idoso, id_responsavel, texto, data_hora, editado_em) VALUES
 (7, 6, 'Não esqueça de usar os óculos novos!', now() - INTERVAL '10 hours', NULL),
 (15, 14, 'Não esqueça de usar os óculos novos!', now() - INTERVAL '1 days 4 hours', NULL),
 (17, 16, 'Vô, mandei as fotos do batizado pela enfermeira.', now() - INTERVAL '5 days 9 hours', NULL),
 (27, 26, 'Não esqueça de usar os óculos novos!', now() - INTERVAL '24 days 8 hours', NULL),
 (24, 23, 'Saudade do seu cuscuz. Te amo!', now() - INTERVAL '14 days 1 hours', NULL),
 (24, 23, 'Hoje faz 50 anos do casamento de vocês. Um beijo!', now() - INTERVAL '19 days 5 hours', NULL),
 (31, 30, 'Pai, a consulta do oftalmo ficou para terça.', now() - INTERVAL '27 days 7 hours', NULL),
 (31, 30, 'Chegou a sua revista de palavras cruzadas, levo sábado.', now() - INTERVAL '8 days 9 hours', now() - INTERVAL '7 days 5 minutes'),
 (28, 17, 'Saudade do seu cuscuz. Te amo!', now() - INTERVAL '29 days 4 hours', now() - INTERVAL '28 days 5 minutes'),
 (6, 5, 'Saudade do seu cuscuz. Te amo!', now() - INTERVAL '19 days 2 hours', NULL),
 (17, 16, 'Chegou a sua revista de palavras cruzadas, levo sábado.', now() - INTERVAL '6 days 5 hours', NULL),
 (9, 8, 'Mainha, já já é São João. Vamos à quadrilha?', now() - INTERVAL '8 days 8 hours', now() - INTERVAL '7 days 5 minutes'),
 (13, 12, 'Saudade do seu cuscuz. Te amo!', now() - INTERVAL '22 days 10 hours', now() - INTERVAL '21 days 5 minutes'),
 (11, 10, 'Chegou a sua revista de palavras cruzadas, levo sábado.', now() - INTERVAL '20 days 6 hours', NULL),
 (29, 28, 'Mainha, já já é São João. Vamos à quadrilha?', now() - INTERVAL '29 days 1 hours', NULL),
 (7, 6, 'Hoje faz 50 anos do casamento de vocês. Um beijo!', now() - INTERVAL '2 days 8 hours', now() - INTERVAL '1 days 5 minutes'),
 (8, 7, 'Hoje faz 50 anos do casamento de vocês. Um beijo!', now() - INTERVAL '13 days 3 hours', NULL),
 (24, 23, 'Mainha, já já é São João. Vamos à quadrilha?', now() - INTERVAL '8 hours', NULL),
 (7, 6, 'Vó, o time ganhou ontem! Lembrei da senhora.', now() - INTERVAL '18 days 9 hours', now() - INTERVAL '17 days 5 minutes'),
 (20, 25, 'Pai, a consulta do oftalmo ficou para terça.', now() - INTERVAL '25 days 6 hours', NULL),
 (29, 28, 'Saudade do seu cuscuz. Te amo!', now() - INTERVAL '29 days 2 hours', NULL),
 (31, 30, 'Mainha, já já é São João. Vamos à quadrilha?', now() - INTERVAL '22 days 9 hours', NULL),
 (10, 9, 'Tia, a prima Lúcia mandou um abraço de São Paulo.', now() - INTERVAL '19 days 5 hours', NULL),
 (29, 28, 'Mainha, já já é São João. Vamos à quadrilha?', now() - INTERVAL '14 days 10 hours', NULL),
 (25, 24, 'Tia, a prima Lúcia mandou um abraço de São Paulo.', now() - INTERVAL '19 days 1 hours', NULL),
 (18, 17, 'Vó, o time ganhou ontem! Lembrei da senhora.', now() - INTERVAL '24 days 9 hours', NULL),
 (29, 28, 'Pai, a consulta do oftalmo ficou para terça.', now() - INTERVAL '10 days 10 hours', NULL),
 (10, 9, 'Vó, o time ganhou ontem! Lembrei da senhora.', now() - INTERVAL '25 days 3 hours', NULL),
 (23, 22, 'Melhoras da gripe, viu? Beba bastante água.', now() - INTERVAL '7 days 10 hours', NULL),
 (10, 15, 'Hoje faz 50 anos do casamento de vocês. Um beijo!', now() - INTERVAL '29 days 2 hours', NULL),
 (12, 9, 'Chegou a sua revista de palavras cruzadas, levo sábado.', now() - INTERVAL '13 days 5 hours', now() - INTERVAL '12 days 5 minutes'),
 (1, 3, 'Vô, mandei as fotos do batizado pela enfermeira.', now() - INTERVAL '16 days 6 hours', NULL),
 (11, 10, 'Chegou a sua revista de palavras cruzadas, levo sábado.', now() - INTERVAL '17 days 8 hours', now() - INTERVAL '16 days 5 minutes'),
 (15, 14, 'Estou orgulhosa da senhora no forró!', now() - INTERVAL '12 days 1 hours', NULL),
 (15, 14, 'Não esqueça de usar os óculos novos!', now() - INTERVAL '13 days 1 hours', NULL),
 (2, 2, 'Bom dia, mainha! Domingo eu passo aí com as crianças.', now() - INTERVAL '6 days 2 hours', NULL);

-- ---------- Passagem de plantão e ciência da equipe (currval amarra a ciência ao recado) ----------
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 7, 8, 'noite', 'atencao', 'Trocar curativo do calcanhar no turno da manhã.', TRUE, now() - INTERVAL '11 days 5 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 9, now() - INTERVAL '10 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 10, now() - INTERVAL '10 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 18, NULL, 'tarde', 'rotina', 'Aniversário de residente amanhã: bolo às 16h.', TRUE, now() - INTERVAL '5 days 12 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 10, now() - INTERVAL '4 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 1, 15, 'noite', 'rotina', 'Família vem visitar amanhã às 15h.', TRUE, now() - INTERVAL '13 days 2 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 7, now() - INTERVAL '12 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 12, 20, 'manha', 'rotina', 'Família vem visitar amanhã às 15h.', FALSE, now() - INTERVAL '3 days 7 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 6, now() - INTERVAL '2 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 3, now() - INTERVAL '2 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 7, 21, 'noite', 'urgente', 'Glicemia alterada às 22h (250 mg/dL); médico avisado.', TRUE, now() - INTERVAL '6 days 8 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 8, now() - INTERVAL '5 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 18, NULL, 'noite', 'rotina', 'Ar-condicionado do quarto 4 com defeito.', TRUE, now() - INTERVAL '6 days 10 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 1, now() - INTERVAL '5 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 12, now() - INTERVAL '5 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 7, NULL, 'noite', 'rotina', 'Aniversário de residente amanhã: bolo às 16h.', TRUE, now() - INTERVAL '8 days 7 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 3, now() - INTERVAL '7 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 17, now() - INTERVAL '7 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 17, NULL, 'manha', 'rotina', 'Faltam fraldas G no estoque; gestor avisado.', TRUE, now() - INTERVAL '19 days 2 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 9, now() - INTERVAL '18 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 8, 7, 'manha', 'atencao', 'Trocar curativo do calcanhar no turno da manhã.', TRUE, now() - INTERVAL '11 days 7 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 11, now() - INTERVAL '10 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 9, NULL, 'manha', 'rotina', 'Ar-condicionado do quarto 4 com defeito.', TRUE, now() - INTERVAL '5 days 10 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 3, now() - INTERVAL '4 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 1, 10, 'tarde', 'atencao', 'Dormiu mal, chamou várias vezes durante a noite.', TRUE, now() - INTERVAL '12 days 9 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 5, now() - INTERVAL '11 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 3, now() - INTERVAL '11 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 17, 11, 'tarde', 'rotina', 'Família vem visitar amanhã às 15h.', TRUE, now() - INTERVAL '14 days 9 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 1, now() - INTERVAL '13 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 3, NULL, 'manha', 'rotina', 'Aniversário de residente amanhã: bolo às 16h.', FALSE, now() - INTERVAL '2 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 7, now());
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 7, 12, 'manha', 'atencao', 'Recusou o jantar; oferecer lanche reforçado.', TRUE, now() - INTERVAL '13 days 4 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 9, now() - INTERVAL '12 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 1, 3, 'manha', 'atencao', 'Dormiu mal, chamou várias vezes durante a noite.', FALSE, now() - INTERVAL '9 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 5, now());
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 12, 11, 'manha', 'rotina', 'Família vem visitar amanhã às 15h.', TRUE, now() - INTERVAL '17 days 5 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 6, now() - INTERVAL '16 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 7, now() - INTERVAL '16 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 18, 19, 'manha', 'atencao', 'Recusou o jantar; oferecer lanche reforçado.', TRUE, now() - INTERVAL '7 days 5 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 3, now() - INTERVAL '6 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 10, 7, 'noite', 'atencao', 'Trocar curativo do calcanhar no turno da manhã.', TRUE, now() - INTERVAL '18 days 4 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 7, now() - INTERVAL '17 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 3, now() - INTERVAL '17 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 7, NULL, 'tarde', 'rotina', 'Aniversário de residente amanhã: bolo às 16h.', TRUE, now() - INTERVAL '15 days 8 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 8, now() - INTERVAL '14 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 3, now() - INTERVAL '14 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 6, NULL, 'noite', 'rotina', 'Aniversário de residente amanhã: bolo às 16h.', TRUE, now() - INTERVAL '18 days 12 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 5, now() - INTERVAL '17 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 17, 6, 'tarde', 'urgente', 'Queda sem lesão no banheiro; observar.', TRUE, now() - INTERVAL '15 days 2 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 18, now() - INTERVAL '14 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 1, 8, 'noite', 'atencao', 'Trocar curativo do calcanhar no turno da manhã.', TRUE, now() - INTERVAL '11 days 9 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 11, now() - INTERVAL '10 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 1, 14, 'manha', 'atencao', 'Trocar curativo do calcanhar no turno da manhã.', TRUE, now() - INTERVAL '6 days 2 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 8, now() - INTERVAL '5 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 1, 9, 6, 'noite', 'atencao', 'Trocar curativo do calcanhar no turno da manhã.', TRUE, now() - INTERVAL '8 days 12 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 12, now() - INTERVAL '7 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 2, 21, 29, 'manha', 'atencao', 'Recusou o jantar; oferecer lanche reforçado.', TRUE, now() - INTERVAL '9 days 5 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 4, now() - INTERVAL '8 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 2, 4, NULL, 'tarde', 'rotina', 'Faltam fraldas G no estoque; gestor avisado.', TRUE, now() - INTERVAL '14 days 9 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 19, now() - INTERVAL '13 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 21, now() - INTERVAL '13 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 2, 23, 29, 'tarde', 'atencao', 'Trocar curativo do calcanhar no turno da manhã.', TRUE, now() - INTERVAL '16 days 12 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 21, now() - INTERVAL '15 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 2, 21, 24, 'tarde', 'atencao', 'Trocar curativo do calcanhar no turno da manhã.', TRUE, now() - INTERVAL '17 days 5 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 22, now() - INTERVAL '16 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 23, now() - INTERVAL '16 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 2, 21, 28, 'manha', 'atencao', 'Recusou o jantar; oferecer lanche reforçado.', TRUE, now() - INTERVAL '19 days 11 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 23, now() - INTERVAL '18 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 22, now() - INTERVAL '18 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 2, 22, 30, 'tarde', 'urgente', 'Queda sem lesão no banheiro; observar.', TRUE, now() - INTERVAL '7 days 12 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 19, now() - INTERVAL '6 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 2, 23, NULL, 'tarde', 'rotina', 'Ar-condicionado do quarto 4 com defeito.', TRUE, now() - INTERVAL '5 days 2 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 4, now() - INTERVAL '4 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 22, now() - INTERVAL '4 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 3, 29, 31, 'manha', 'rotina', 'Família vem visitar amanhã às 15h.', TRUE, now() - INTERVAL '17 days 7 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 27, now() - INTERVAL '16 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 28, now() - INTERVAL '16 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 3, 28, 31, 'noite', 'atencao', 'Dormiu mal, chamou várias vezes durante a noite.', TRUE, now() - INTERVAL '8 days 5 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 27, now() - INTERVAL '7 days 30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 29, now() - INTERVAL '7 days 30 minutes');
INSERT INTO recado_plantao (id_recado, id_ilpi, id_profissional, id_idoso, turno, prioridade, texto, resolvido, data_hora) VALUES
 (nextval('recado_plantao_id_recado_seq'), 3, 28, 32, 'tarde', 'rotina', 'Família vem visitar amanhã às 15h.', FALSE, now() - INTERVAL '1 days 12 hours');
  INSERT INTO ciencia_plantao (id_recado, id_profissional, data_hora) VALUES
   (currval('recado_plantao_id_recado_seq'), 29, now() - INTERVAL '30 minutes'),
   (currval('recado_plantao_id_recado_seq'), 27, now() - INTERVAL '30 minutes');

-- ---------- Sinais vitais ----------
INSERT INTO sinal_vital (id_idoso, id_profissional, data_hora, pressao_sis, pressao_dia, freq_cardiaca, temperatura, peso_kg, glicemia, saturacao, observacoes) VALUES
 (1, 11, now() - INTERVAL '51 days 10 hours', 133, 95, 60, 36.1, NULL, NULL, 93, NULL),
 (1, 11, now() - INTERVAL '48 days 7 hours', 163, 86, 64, 37.4, NULL, 111, 97, NULL),
 (1, 11, now() - INTERVAL '42 days 9 hours', 163, 85, 94, 37.1, NULL, 101, 94, NULL),
 (1, 18, now() - INTERVAL '20 days 5 hours', 150, 72, 66, 36.1, NULL, 238, 96, NULL),
 (1, 1, now() - INTERVAL '18 days 7 hours', 145, 72, 73, 36.7, 52.5, NULL, 97, NULL),
 (1, 10, now() - INTERVAL '10 days 3 hours', 157, 97, 84, 37.4, NULL, NULL, 91, NULL),
 (2, 12, now() - INTERVAL '53 days 9 hours', 121, 74, 72, 37.1, 53.3, 202, 92, NULL),
 (2, 10, now() - INTERVAL '23 days 5 hours', 122, 85, 80, 36.1, NULL, 204, 98, NULL),
 (2, 10, now() - INTERVAL '17 days 9 hours', 130, 74, 94, 36.2, 53.8, 165, 98, NULL),
 (2, 11, now() - INTERVAL '16 days 2 hours', 111, 79, 98, 36.2, NULL, 117, 97, NULL),
 (2, 18, now() - INTERVAL '8 days 1 hours', 122, 72, 80, 37.2, NULL, 131, 96, NULL),
 (3, 1, now() - INTERVAL '47 days 6 hours', 146, 93, 77, 36.3, NULL, NULL, 93, NULL),
 (3, 10, now() - INTERVAL '36 days 7 hours', 126, 72, 91, 36.0, NULL, 250, 99, NULL),
 (3, 18, now() - INTERVAL '35 days 3 hours', 135, 81, 68, 36.9, 78.2, NULL, 91, NULL),
 (3, 12, now() - INTERVAL '21 days 2 hours', 136, 76, 63, 36.2, 79.9, 101, 99, NULL),
 (3, 1, now() - INTERVAL '3 days 6 hours', 154, 97, 70, 36.6, NULL, 247, 98, NULL),
 (4, 4, now() - INTERVAL '40 days 8 hours', 140, 82, 77, 35.9, NULL, NULL, 95, NULL),
 (4, 23, now() - INTERVAL '11 days 8 hours', 126, 72, 61, 36.5, NULL, NULL, 96, NULL),
 (4, 23, now() - INTERVAL '7 days 3 hours', 132, 74, 81, 36.5, NULL, NULL, 99, NULL),
 (5, 18, now() - INTERVAL '53 days 8 hours', 156, 90, 73, 37.2, NULL, 112, 92, NULL),
 (5, 12, now() - INTERVAL '45 days 6 hours', 141, 75, 87, 36.6, NULL, NULL, 94, NULL),
 (5, 18, now() - INTERVAL '13 days 8 hours', 157, 82, 71, 37.4, NULL, NULL, 99, NULL),
 (5, 10, now() - INTERVAL '4 days 2 hours', 160, 94, 75, 37.3, 57.3, NULL, 94, NULL),
 (6, 11, now() - INTERVAL '54 days 6 hours', 109, 65, 58, 36.0, NULL, 120, 94, NULL),
 (6, 10, now() - INTERVAL '28 days 7 hours', 132, 62, 59, 37.4, NULL, 85, 91, NULL),
 (6, 18, now() - INTERVAL '20 days 4 hours', 128, 74, 83, 37.0, NULL, 122, 91, NULL),
 (6, 11, now() - INTERVAL '12 days 1 hours', 116, 73, 71, 37.1, 60.7, NULL, 96, NULL),
 (7, 1, now() - INTERVAL '50 days 5 hours', 148, 85, 81, 36.7, 80.3, NULL, 97, NULL),
 (7, 10, now() - INTERVAL '38 days 9 hours', 130, 78, 89, 36.9, NULL, 98, 96, NULL),
 (7, 1, now() - INTERVAL '27 days 2 hours', 131, 73, 80, 36.3, 80.3, 93, 94, NULL),
 (7, 11, now() - INTERVAL '7 days 1 hours', 146, 72, 83, 36.8, NULL, 103, 91, NULL),
 (8, 1, now() - INTERVAL '51 days 3 hours', 125, 91, 95, 37.2, 52.0, 100, 94, NULL),
 (8, 1, now() - INTERVAL '43 days 6 hours', 127, 75, 62, 37.4, 52.8, 258, 94, NULL),
 (8, 10, now() - INTERVAL '27 days 2 hours', 143, 77, 85, 36.0, NULL, 104, 95, NULL),
 (8, 12, now() - INTERVAL '18 days 2 hours', 162, 94, 65, 37.2, NULL, 162, 99, NULL),
 (8, 1, now() - INTERVAL '12 days 5 hours', 133, 88, 74, 36.1, NULL, 137, 92, NULL),
 (8, 1, now() - INTERVAL '2 days 2 hours', 135, 95, 97, 36.5, NULL, NULL, 94, NULL),
 (9, 18, now() - INTERVAL '17 days 6 hours', 139, 97, 92, 37.1, NULL, NULL, 98, NULL),
 (9, 12, now() - INTERVAL '15 days 10 hours', 155, 80, 87, 35.8, NULL, 77, 92, NULL),
 (9, 11, now() - INTERVAL '10 days 9 hours', 150, 82, 90, 36.0, NULL, NULL, 98, NULL),
 (10, 12, now() - INTERVAL '29 days 1 hours', 137, 89, 87, 36.6, 64.6, NULL, 92, NULL),
 (10, 10, now() - INTERVAL '26 days 2 hours', 147, 78, 70, 36.1, NULL, NULL, 92, NULL),
 (10, 11, now() - INTERVAL '11 days 5 hours', 132, 85, 93, 37.3, 65.1, 98, 99, NULL),
 (10, 11, now() - INTERVAL '6 days 5 hours', 138, 74, 87, 37.0, NULL, NULL, 96, NULL),
 (10, 10, now() - INTERVAL '3 days 7 hours', 146, 78, 60, 37.3, NULL, 111, 96, NULL),
 (11, 11, now() - INTERVAL '30 days 4 hours', 144, 84, 98, 37.3, 70.7, 104, 92, NULL),
 (11, 1, now() - INTERVAL '28 days 5 hours', 150, 70, 85, 37.5, 70.7, NULL, 99, NULL),
 (11, 10, now() - INTERVAL '9 days 2 hours', 125, 70, 86, 36.9, NULL, 83, 94, NULL),
 (11, 11, now() - INTERVAL '3 days 2 hours', 132, 72, 69, 35.8, NULL, 91, 95, NULL),
 (12, 11, now() - INTERVAL '49 days 9 hours', 127, 94, 82, 36.1, NULL, 125, 98, NULL),
 (12, 11, now() - INTERVAL '48 days 5 hours', 146, 73, 97, 35.8, 87.9, 98, 98, NULL),
 (12, 12, now() - INTERVAL '33 days 8 hours', 139, 87, 92, 36.7, NULL, NULL, 99, NULL),
 (12, 11, now() - INTERVAL '30 days 4 hours', 132, 95, 63, 37.2, 86.5, 89, 99, NULL),
 (12, 12, now() - INTERVAL '1 days 6 hours', 157, 84, 67, 36.5, NULL, 99, 97, NULL),
 (13, 10, now() - INTERVAL '51 days 1 hours', 106, 67, 91, 37.4, NULL, NULL, 93, NULL),
 (13, 11, now() - INTERVAL '34 days 5 hours', 127, 74, 91, 36.6, 57.6, NULL, 96, NULL),
 (13, 11, now() - INTERVAL '9 days 9 hours', 117, 80, 88, 37.1, NULL, 116, 91, NULL),
 (14, 18, now() - INTERVAL '43 days 1 hours', 158, 79, 94, 35.8, NULL, NULL, 99, NULL),
 (14, 11, now() - INTERVAL '39 days 2 hours', 149, 74, 67, 37.2, NULL, 168, 99, NULL),
 (14, 11, now() - INTERVAL '17 days 2 hours', 165, 93, 74, 37.1, 59.4, 249, 93, NULL),
 (14, 18, now() - INTERVAL '14 days 4 hours', 148, 86, 72, 35.9, NULL, 245, 99, NULL),
 (14, 1, now() - INTERVAL '10 days 6 hours', 145, 92, 59, 37.5, 59.0, NULL, 95, NULL),
 (15, 1, now() - INTERVAL '48 days 10 hours', 148, 88, 65, 36.6, 53.5, 124, 91, NULL),
 (15, 12, now() - INTERVAL '22 days 4 hours', 151, 77, 95, 36.7, 53.4, NULL, 98, NULL),
 (15, 12, now() - INTERVAL '14 days 8 hours', 158, 93, 96, 36.9, NULL, NULL, 94, NULL),
 (16, 18, now() - INTERVAL '51 days 10 hours', 121, 64, 74, 36.2, NULL, 78, 93, NULL),
 (16, 12, now() - INTERVAL '35 days 6 hours', 119, 70, 93, 36.1, NULL, NULL, 93, NULL),
 (16, 11, now() - INTERVAL '17 days 5 hours', 106, 80, 90, 35.9, 81.9, NULL, 91, NULL),
 (16, 11, now() - INTERVAL '14 days 9 hours', 126, 78, 74, 36.3, 82.4, NULL, 98, NULL),
 (17, 12, now() - INTERVAL '37 days 1 hours', 161, 95, 69, 37.4, 59.8, 107, 99, NULL),
 (17, 12, now() - INTERVAL '22 days 10 hours', 140, 73, 65, 36.7, NULL, NULL, 95, NULL),
 (17, 10, now() - INTERVAL '4 days 5 hours', 149, 97, 82, 36.3, NULL, NULL, 98, NULL),
 (18, 18, now() - INTERVAL '47 days 4 hours', 131, 74, 87, 36.0, NULL, NULL, 91, NULL),
 (18, 12, now() - INTERVAL '45 days 9 hours', 131, 97, 92, 37.1, NULL, 103, 95, NULL),
 (18, 18, now() - INTERVAL '36 days 2 hours', 136, 78, 69, 36.2, 56.2, NULL, 92, NULL),
 (18, 18, now() - INTERVAL '27 days 10 hours', 161, 95, 58, 37.1, NULL, 89, 91, NULL),
 (18, 12, now() - INTERVAL '2 days 5 hours', 155, 78, 97, 36.0, 54.4, 77, 93, NULL),
 (19, 18, now() - INTERVAL '52 days 2 hours', 136, 76, 84, 36.1, NULL, NULL, 95, NULL),
 (19, 1, now() - INTERVAL '40 days 9 hours', 153, 81, 70, 37.5, NULL, NULL, 99, NULL),
 (19, 10, now() - INTERVAL '32 days 5 hours', 146, 88, 85, 37.3, NULL, NULL, 91, NULL),
 (20, 10, now() - INTERVAL '44 days 4 hours', 146, 72, 82, 36.1, NULL, 105, 97, NULL),
 (20, 12, now() - INTERVAL '41 days 6 hours', 139, 85, 95, 36.7, 69.4, NULL, 99, NULL),
 (20, 18, now() - INTERVAL '33 days 6 hours', 128, 93, 81, 37.3, NULL, NULL, 95, NULL),
 (20, 18, now() - INTERVAL '28 days 6 hours', 138, 74, 63, 36.5, NULL, NULL, 99, NULL),
 (20, 11, now() - INTERVAL '25 days 2 hours', 132, 82, 98, 36.3, 69.7, 98, 97, NULL),
 (20, 12, now() - INTERVAL '16 days 8 hours', 142, 93, 87, 36.3, NULL, 87, 98, NULL),
 (21, 11, now() - INTERVAL '26 days 3 hours', 135, 94, 92, 36.2, 49.7, NULL, 93, NULL),
 (21, 10, now() - INTERVAL '24 days 1 hours', 128, 79, 63, 37.4, NULL, 161, 97, NULL),
 (21, 10, now() - INTERVAL '17 days 1 hours', 153, 97, 81, 37.2, NULL, 92, 97, NULL),
 (21, 1, now() - INTERVAL '7 days 3 hours', 136, 95, 89, 37.5, NULL, NULL, 99, NULL),
 (23, 10, now() - INTERVAL '54 days 10 hours', 138, 70, 64, 37.4, NULL, 77, 96, NULL),
 (23, 12, now() - INTERVAL '52 days 6 hours', 126, 90, 85, 36.2, NULL, 122, 95, NULL),
 (23, 18, now() - INTERVAL '37 days 2 hours', 164, 87, 93, 37.2, NULL, 124, 99, NULL),
 (23, 11, now() - INTERVAL '34 days 10 hours', 146, 84, 62, 36.4, NULL, NULL, 97, NULL),
 (23, 10, now() - INTERVAL '17 days 2 hours', 155, 86, 81, 36.0, NULL, 112, 95, NULL),
 (24, 23, now() - INTERVAL '54 days 7 hours', 135, 83, 90, 36.2, 86.7, NULL, 97, NULL),
 (24, 4, now() - INTERVAL '26 days 1 hours', 124, 83, 61, 37.4, 86.0, 82, 98, NULL),
 (24, 23, now() - INTERVAL '22 days 4 hours', 135, 67, 96, 36.1, NULL, NULL, 97, NULL),
 (24, 23, now() - INTERVAL '18 days 9 hours', 130, 73, 98, 36.6, NULL, NULL, 92, NULL),
 (24, 4, now() - INTERVAL '14 days 5 hours', 110, 71, 72, 36.4, 84.7, 100, 93, NULL),
 (24, 4, now() - INTERVAL '4 days 1 hours', 107, 76, 87, 37.5, 85.9, 124, 99, NULL),
 (25, 4, now() - INTERVAL '40 days 5 hours', 118, 68, 60, 37.1, NULL, NULL, 91, NULL),
 (25, 4, now() - INTERVAL '34 days 2 hours', 127, 79, 96, 36.1, 75.9, NULL, 96, NULL),
 (25, 4, now() - INTERVAL '30 days 5 hours', 105, 71, 73, 37.1, NULL, NULL, 99, NULL),
 (25, 4, now() - INTERVAL '23 days 1 hours', 126, 65, 90, 36.6, 77.3, NULL, 97, NULL),
 (25, 23, now() - INTERVAL '15 days 5 hours', 112, 71, 59, 35.9, NULL, 121, 93, NULL),
 (25, 23, now() - INTERVAL '2 days 4 hours', 134, 65, 79, 37.5, NULL, 77, 94, NULL),
 (26, 4, now() - INTERVAL '39 days 1 hours', 117, 72, 86, 35.9, NULL, NULL, 94, NULL),
 (26, 23, now() - INTERVAL '36 days 1 hours', 105, 65, 95, 36.9, NULL, 84, 91, NULL),
 (26, 23, now() - INTERVAL '22 days 4 hours', 119, 85, 97, 36.1, NULL, NULL, 98, NULL),
 (26, 4, now() - INTERVAL '18 days 1 hours', 129, 62, 59, 37.3, 53.6, 101, 98, NULL),
 (26, 4, now() - INTERVAL '16 days 7 hours', 126, 83, 67, 36.3, 53.6, NULL, 91, NULL),
 (26, 4, now() - INTERVAL '10 days 2 hours', 119, 67, 79, 36.7, NULL, NULL, 92, NULL),
 (27, 4, now() - INTERVAL '49 days 4 hours', 148, 74, 61, 36.0, NULL, NULL, 97, NULL),
 (27, 4, now() - INTERVAL '46 days 4 hours', 131, 85, 81, 36.1, 82.5, 219, 96, NULL),
 (27, 23, now() - INTERVAL '36 days 7 hours', 131, 72, 65, 37.5, NULL, 251, 92, NULL),
 (27, 23, now() - INTERVAL '20 days 3 hours', 163, 77, 73, 36.3, 83.7, 121, 94, NULL),
 (27, 4, now() - INTERVAL '10 days 2 hours', 134, 87, 87, 37.1, NULL, 137, 91, NULL),
 (27, 23, now() - INTERVAL '7 days 9 hours', 152, 98, 78, 36.4, NULL, 250, 94, NULL),
 (28, 23, now() - INTERVAL '37 days 4 hours', 114, 75, 94, 36.5, 74.5, 110, 91, NULL),
 (28, 4, now() - INTERVAL '33 days 1 hours', 109, 85, 95, 35.8, NULL, 123, 94, NULL),
 (28, 23, now() - INTERVAL '32 days 4 hours', 123, 68, 82, 36.8, NULL, NULL, 97, NULL),
 (28, 23, now() - INTERVAL '22 days 9 hours', 106, 79, 97, 36.0, NULL, NULL, 97, NULL),
 (28, 23, now() - INTERVAL '20 days 4 hours', 134, 78, 65, 35.9, NULL, 124, 92, NULL),
 (29, 23, now() - INTERVAL '52 days 5 hours', 159, 71, 88, 37.2, NULL, NULL, 97, NULL),
 (29, 4, now() - INTERVAL '46 days 4 hours', 158, 98, 93, 36.7, 74.1, NULL, 99, NULL),
 (29, 23, now() - INTERVAL '21 days 4 hours', 147, 74, 73, 37.6, NULL, 133, 93, NULL),
 (30, 4, now() - INTERVAL '54 days 6 hours', 133, 73, 97, 36.3, 56.2, NULL, 96, NULL),
 (30, 23, now() - INTERVAL '52 days 5 hours', 109, 75, 80, 36.8, NULL, 96, 99, NULL),
 (30, 4, now() - INTERVAL '46 days 3 hours', 129, 79, 81, 37.2, 56.1, NULL, 99, NULL),
 (30, 4, now() - INTERVAL '31 days 2 hours', 114, 65, 77, 37.0, NULL, NULL, 99, NULL),
 (30, 23, now() - INTERVAL '16 days 6 hours', 120, 69, 58, 36.2, NULL, 120, 93, NULL),
 (31, 28, now() - INTERVAL '49 days 3 hours', 109, 73, 73, 36.2, NULL, NULL, 92, NULL),
 (31, 28, now() - INTERVAL '42 days 4 hours', 112, 81, 62, 35.9, NULL, NULL, 95, NULL),
 (31, 28, now() - INTERVAL '41 days 2 hours', 118, 81, 62, 36.9, NULL, NULL, 93, NULL),
 (31, 28, now() - INTERVAL '13 days 7 hours', 131, 66, 96, 36.5, 50.9, NULL, 95, NULL),
 (31, 28, now() - INTERVAL '6 days 8 hours', 129, 85, 58, 37.0, NULL, NULL, 94, NULL),
 (31, 28, now() - INTERVAL '5 days 8 hours', 126, 81, 74, 37.1, NULL, NULL, 94, NULL),
 (32, 28, now() - INTERVAL '47 days 4 hours', 135, 84, 93, 36.8, 60.9, NULL, 99, NULL),
 (32, 28, now() - INTERVAL '42 days 8 hours', 108, 64, 70, 36.7, NULL, NULL, 97, NULL),
 (32, 28, now() - INTERVAL '39 days 6 hours', 107, 78, 80, 37.0, NULL, 105, 99, NULL),
 (32, 28, now() - INTERVAL '10 days 7 hours', 105, 80, 62, 36.2, NULL, 134, 96, NULL);

-- ---------- Plano de cuidado: metas e evolução ----------
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 1, 2, 'saude', 'Manter pressão abaixo de 140x90', 'ativa', CURRENT_DATE - 143, CURRENT_DATE + 37, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 2, 'Boa evolução nesta semana.', now() - INTERVAL '91 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 2, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '14 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 2, 'Boa evolução nesta semana.', now() - INTERVAL '9 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 4, 25, 'emocional', 'Reduzir episódios de choro relatados', 'atingida', CURRENT_DATE - 128, CURRENT_DATE + 45, CURRENT_DATE - 18);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 25, 'Meta parcialmente atingida.', now() - INTERVAL '119 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 25, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '27 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 7, 15, 'emocional', 'Reduzir episódios de choro relatados', 'ativa', CURRENT_DATE - 128, CURRENT_DATE + 43, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 15, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '106 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 15, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '76 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 10, 13, 'emocional', 'Reduzir episódios de choro relatados', 'ativa', CURRENT_DATE - 126, CURRENT_DATE + 24, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 13, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '85 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 13, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '80 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 13, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '73 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 13, 12, 'social', 'Participar de 2 atividades em grupo por semana', 'atingida', CURRENT_DATE - 118, CURRENT_DATE + 56, CURRENT_DATE - 51);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 12, 'Meta parcialmente atingida.', now() - INTERVAL '115 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 12, 'Boa evolução nesta semana.', now() - INTERVAL '93 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 16, 1, 'nutricao', 'Recuperar 2 kg em 60 dias', 'ativa', CURRENT_DATE - 114, CURRENT_DATE + 53, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 1, 'Recusou a atividade dois dias; reforçar motivação.', now() - INTERVAL '60 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 1, 'Família colaborando em casa nas visitas.', now() - INTERVAL '4 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 19, 14, 'cognitiva', 'Fazer palavras cruzadas 3x por semana', 'suspensa', CURRENT_DATE - 126, CURRENT_DATE + 55, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 14, 'Boa evolução nesta semana.', now() - INTERVAL '93 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 14, 'Meta parcialmente atingida.', now() - INTERVAL '81 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 23, 15, 'saude', 'Glicemia de jejum abaixo de 130 mg/dL', 'atingida', CURRENT_DATE - 125, CURRENT_DATE + 36, CURRENT_DATE - 119);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 15, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '110 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 26, 4, 'mobilidade', 'Caminhar 10 minutos por dia com andador', 'atingida', CURRENT_DATE - 146, CURRENT_DATE + 51, CURRENT_DATE - 16);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 4, 'Recusou a atividade dois dias; reforçar motivação.', now() - INTERVAL '126 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 4, 'Recusou a atividade dois dias; reforçar motivação.', now() - INTERVAL '114 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 4, 'Meta parcialmente atingida.', now() - INTERVAL '72 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 29, 26, 'mobilidade', 'Caminhar 10 minutos por dia com andador', 'suspensa', CURRENT_DATE - 50, CURRENT_DATE + 16, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 26, 'Recusou a atividade dois dias; reforçar motivação.', now() - INTERVAL '11 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 32, 28, 'emocional', 'Reduzir episódios de choro relatados', 'ativa', CURRENT_DATE - 46, CURRENT_DATE + 15, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 28, 'Família colaborando em casa nas visitas.', now() - INTERVAL '29 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 3, 12, 'saude', 'Manter pressão abaixo de 140x90', 'atingida', CURRENT_DATE - 80, CURRENT_DATE + 52, CURRENT_DATE - 2);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 12, 'Boa evolução nesta semana.', now() - INTERVAL '72 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 12, 'Recusou a atividade dois dias; reforçar motivação.', now() - INTERVAL '64 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 6, 14, 'autonomia', 'Vestir-se sozinho com supervisão', 'atingida', CURRENT_DATE - 97, CURRENT_DATE + 56, CURRENT_DATE - 74);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 14, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '73 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 14, 'Meta parcialmente atingida.', now() - INTERVAL '23 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 9, 2, 'autonomia', 'Vestir-se sozinho com supervisão', 'ativa', CURRENT_DATE - 97, CURRENT_DATE + 14, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 2, 'Meta parcialmente atingida.', now() - INTERVAL '76 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 2, 'Meta parcialmente atingida.', now() - INTERVAL '64 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 2, 'Meta parcialmente atingida.', now() - INTERVAL '29 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 12, 14, 'emocional', 'Reduzir episódios de choro relatados', 'atingida', CURRENT_DATE - 87, CURRENT_DATE + 45, CURRENT_DATE - 38);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 14, 'Boa evolução nesta semana.', now() - INTERVAL '75 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 14, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '60 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 15, 12, 'social', 'Participar de 2 atividades em grupo por semana', 'atingida', CURRENT_DATE - 109, CURRENT_DATE + 35, CURRENT_DATE - 77);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 12, 'Família colaborando em casa nas visitas.', now() - INTERVAL '42 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 18, 2, 'mobilidade', 'Caminhar 10 minutos por dia com andador', 'atingida', CURRENT_DATE - 101, CURRENT_DATE + 44, CURRENT_DATE - 14);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 2, 'Boa evolução nesta semana.', now() - INTERVAL '58 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 2, 'Boa evolução nesta semana.', now() - INTERVAL '47 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 2, 'Recusou a atividade dois dias; reforçar motivação.', now() - INTERVAL '19 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 21, 12, 'autonomia', 'Vestir-se sozinho com supervisão', 'ativa', CURRENT_DATE - 54, CURRENT_DATE + 47, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 12, 'Boa evolução nesta semana.', now() - INTERVAL '49 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 12, 'Família colaborando em casa nas visitas.', now() - INTERVAL '28 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 12, 'Meta parcialmente atingida.', now() - INTERVAL '1 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 25, 20, 'saude', 'Manter pressão abaixo de 140x90', 'atingida', CURRENT_DATE - 130, CURRENT_DATE + 43, CURRENT_DATE - 38);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 20, 'Família colaborando em casa nas visitas.', now() - INTERVAL '128 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 20, 'Recusou a atividade dois dias; reforçar motivação.', now() - INTERVAL '45 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 28, 20, 'autonomia', 'Vestir-se sozinho com supervisão', 'ativa', CURRENT_DATE - 108, CURRENT_DATE + 34, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 20, 'Boa evolução nesta semana.', now() - INTERVAL '82 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 31, 30, 'mobilidade', 'Caminhar 10 minutos por dia com andador', 'ativa', CURRENT_DATE - 68, CURRENT_DATE + 53, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 30, 'Meta parcialmente atingida.', now() - INTERVAL '37 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 30, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '18 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 2, 15, 'saude', 'Glicemia de jejum abaixo de 130 mg/dL', 'atingida', CURRENT_DATE - 76, CURRENT_DATE + 31, CURRENT_DATE - 11);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 15, 'Família colaborando em casa nas visitas.', now() - INTERVAL '40 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 15, 'Recusou a atividade dois dias; reforçar motivação.', now() - INTERVAL '25 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 15, 'Família colaborando em casa nas visitas.', now() - INTERVAL '9 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 5, 12, 'cognitiva', 'Fazer palavras cruzadas 3x por semana', 'ativa', CURRENT_DATE - 87, CURRENT_DATE + 5, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 12, 'Meta parcialmente atingida.', now() - INTERVAL '35 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 12, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '21 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 12, 'Recusou a atividade dois dias; reforçar motivação.', now() - INTERVAL '10 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 8, 12, 'social', 'Participar de 2 atividades em grupo por semana', 'atingida', CURRENT_DATE - 148, CURRENT_DATE + 60, CURRENT_DATE - 96);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 12, 'Meta parcialmente atingida.', now() - INTERVAL '108 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 12, 'Família colaborando em casa nas visitas.', now() - INTERVAL '50 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 12, 'Meta parcialmente atingida.', now() - INTERVAL '28 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 11, 13, 'autonomia', 'Vestir-se sozinho com supervisão', 'ativa', CURRENT_DATE - 50, CURRENT_DATE + 15, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 13, 'Meta parcialmente atingida.', now() - INTERVAL '41 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 13, 'Meta parcialmente atingida.', now() - INTERVAL '14 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 14, 14, 'emocional', 'Reduzir episódios de choro relatados', 'ativa', CURRENT_DATE - 125, CURRENT_DATE + 50, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 14, 'Recusou a atividade dois dias; reforçar motivação.', now() - INTERVAL '57 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 14, 'Recusou a atividade dois dias; reforçar motivação.', now() - INTERVAL '47 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 17, 13, 'saude', 'Manter pressão abaixo de 140x90', 'atingida', CURRENT_DATE - 128, CURRENT_DATE + 47, CURRENT_DATE - 95);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 13, 'Boa evolução nesta semana.', now() - INTERVAL '123 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 13, 'Boa evolução nesta semana.', now() - INTERVAL '105 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 13, 'Família colaborando em casa nas visitas.', now() - INTERVAL '91 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 20, 14, 'autonomia', 'Vestir-se sozinho com supervisão', 'ativa', CURRENT_DATE - 140, CURRENT_DATE + 7, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 14, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '64 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 24, 24, 'emocional', 'Reduzir episódios de choro relatados', 'atingida', CURRENT_DATE - 49, CURRENT_DATE + 43, CURRENT_DATE - 29);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 24, 'Família colaborando em casa nas visitas.', now() - INTERVAL '28 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 24, 'Família colaborando em casa nas visitas.', now() - INTERVAL '10 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 27, 4, 'cognitiva', 'Fazer palavras cruzadas 3x por semana', 'atingida', CURRENT_DATE - 140, CURRENT_DATE + 47, CURRENT_DATE - 36);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 4, 'Recusou a atividade dois dias; reforçar motivação.', now() - INTERVAL '128 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 4, 'Meta parcialmente atingida.', now() - INTERVAL '35 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 4, 'Meta parcialmente atingida.', now() - INTERVAL '32 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 30, 26, 'saude', 'Glicemia de jejum abaixo de 130 mg/dL', 'ativa', CURRENT_DATE - 120, CURRENT_DATE + 21, NULL);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 26, 'Família colaborando em casa nas visitas.', now() - INTERVAL '12 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 26, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '2 days 2 hours');
INSERT INTO meta_cuidado (id_meta, id_idoso, id_profissional, categoria, descricao, status, data_criacao, data_revisao, data_conclusao) VALUES
 (nextval('meta_cuidado_id_meta_seq'), 1, 2, 'social', 'Participar de 2 atividades em grupo por semana', 'atingida', CURRENT_DATE - 48, CURRENT_DATE + 12, CURRENT_DATE - 15);
  INSERT INTO evolucao_meta (id_meta, id_profissional, nota, data_hora) VALUES
   (currval('meta_cuidado_id_meta_seq'), 2, 'Sem mudança; reavaliar estratégia.', now() - INTERVAL '26 days 2 hours'),
   (currval('meta_cuidado_id_meta_seq'), 2, 'Boa evolução nesta semana.', now() - INTERVAL '13 days 2 hours');

-- ---------- Intercorrências ----------
INSERT INTO intercorrencia (id_idoso, id_profissional, tipo, gravidade, local_evento, descricao, conduta, familia_avisada, data_hora) VALUES
 (1, 3, 'outro', 'moderada', 'Sala de TV', 'Engasgo leve com líquido', 'Manobra de desobstrução não necessária; avaliar espessante', TRUE, now() - INTERVAL '52 days 18 hours'),
 (3, 8, 'lesao', 'leve', 'Pátio', 'Escoriação no antebraço', 'Curativo simples', TRUE, now() - INTERVAL '47 days 11 hours'),
 (4, 4, 'queda', 'grave', 'Banheiro', 'Queda da própria altura ao levantar à noite', 'Avaliado pela enfermagem; sem lesão aparente', TRUE, now() - INTERVAL '28 days 7 hours'),
 (10, 12, 'queda', 'leve', 'Corredor', 'Escorregou no piso molhado', 'Gelo local; observação por 24h', FALSE, now() - INTERVAL '62 days 3 hours'),
 (19, 8, 'queda', 'leve', 'Corredor', 'Escorregou no piso molhado', 'Gelo local; observação por 24h', TRUE, now() - INTERVAL '66 days 3 hours'),
 (17, 17, 'queda', 'grave', 'Corredor', 'Escorregou no piso molhado', 'Gelo local; observação por 24h', TRUE, now() - INTERVAL '12 days 16 hours'),
 (9, 18, 'queda', 'grave', 'Banheiro', 'Queda da própria altura ao levantar à noite', 'Avaliado pela enfermagem; sem lesão aparente', TRUE, now() - INTERVAL '39 days 16 hours'),
 (27, 22, 'mal_estar', 'grave', 'Refeitório', 'Tontura e sudorese após o almoço', 'Aferida glicemia; repouso', TRUE, now() - INTERVAL '16 days 7 hours'),
 (26, 23, 'comportamento', 'leve', 'Quarto', 'Agitação noturna e confusão', 'Acolhimento; médico comunicado', FALSE, now() - INTERVAL '61 days 10 hours'),
 (5, 6, 'mal_estar', 'leve', 'Refeitório', 'Tontura e sudorese após o almoço', 'Aferida glicemia; repouso', FALSE, now() - INTERVAL '70 days 10 hours'),
 (16, 1, 'comportamento', 'leve', 'Quarto', 'Agitação noturna e confusão', 'Acolhimento; médico comunicado', TRUE, now() - INTERVAL '26 days 10 hours'),
 (12, 9, 'mal_estar', 'moderada', 'Refeitório', 'Tontura e sudorese após o almoço', 'Aferida glicemia; repouso', TRUE, now() - INTERVAL '68 days 15 hours'),
 (15, 6, 'outro', 'leve', 'Sala de TV', 'Engasgo leve com líquido', 'Manobra de desobstrução não necessária; avaliar espessante', TRUE, now() - INTERVAL '55 days 6 hours'),
 (29, 22, 'queda', 'leve', 'Corredor', 'Escorregou no piso molhado', 'Gelo local; observação por 24h', TRUE, now() - INTERVAL '41 days 1 hours'),
 (13, 7, 'mal_estar', 'moderada', 'Refeitório', 'Tontura e sudorese após o almoço', 'Aferida glicemia; repouso', TRUE, now() - INTERVAL '15 days 9 hours'),
 (6, 3, 'lesao', 'leve', 'Pátio', 'Escoriação no antebraço', 'Curativo simples', FALSE, now() - INTERVAL '80 days 10 hours'),
 (15, 1, 'lesao', 'leve', 'Pátio', 'Escoriação no antebraço', 'Curativo simples', FALSE, now() - INTERVAL '64 days 7 hours'),
 (26, 22, 'outro', 'moderada', 'Sala de TV', 'Engasgo leve com líquido', 'Manobra de desobstrução não necessária; avaliar espessante', TRUE, now() - INTERVAL '41 days 5 hours'),
 (16, 10, 'lesao', 'moderada', 'Pátio', 'Escoriação no antebraço', 'Curativo simples', TRUE, now() - INTERVAL '66 days 17 hours'),
 (29, 4, 'lesao', 'grave', 'Pátio', 'Escoriação no antebraço', 'Curativo simples', TRUE, now() - INTERVAL '54 days 2 hours'),
 (10, 11, 'outro', 'leve', 'Sala de TV', 'Engasgo leve com líquido', 'Manobra de desobstrução não necessária; avaliar espessante', FALSE, now() - INTERVAL '8 days 8 hours'),
 (30, 22, 'comportamento', 'leve', 'Quarto', 'Agitação noturna e confusão', 'Acolhimento; médico comunicado', FALSE, now() - INTERVAL '64 days 3 hours'),
 (27, 4, 'queda', 'leve', 'Banheiro', 'Queda da própria altura ao levantar à noite', 'Avaliado pela enfermagem; sem lesão aparente', FALSE, now() - INTERVAL '18 days 20 hours'),
 (20, 18, 'comportamento', 'leve', 'Quarto', 'Agitação noturna e confusão', 'Acolhimento; médico comunicado', TRUE, now() - INTERVAL '34 days 14 hours'),
 (3, 1, 'mal_estar', 'moderada', 'Refeitório', 'Tontura e sudorese após o almoço', 'Aferida glicemia; repouso', TRUE, now() - INTERVAL '22 days 5 hours'),
 (3, 9, 'queda', 'leve', 'Banheiro', 'Queda da própria altura ao levantar à noite', 'Avaliado pela enfermagem; sem lesão aparente', FALSE, now() - INTERVAL '27 days 5 hours'),
 (28, 22, 'lesao', 'moderada', 'Pátio', 'Escoriação no antebraço', 'Curativo simples', TRUE, now() - INTERVAL '23 days 5 hours'),
 (3, 17, 'mal_estar', 'leve', 'Refeitório', 'Tontura e sudorese após o almoço', 'Aferida glicemia; repouso', TRUE, now() - INTERVAL '9 days 11 hours'),
 (13, 8, 'queda', 'leve', 'Banheiro', 'Queda da própria altura ao levantar à noite', 'Avaliado pela enfermagem; sem lesão aparente', TRUE, now() - INTERVAL '24 days 9 hours'),
 (10, 8, 'outro', 'leve', 'Sala de TV', 'Engasgo leve com líquido', 'Manobra de desobstrução não necessária; avaliar espessante', FALSE, now() - INTERVAL '19 days 2 hours'),
 (29, 4, 'lesao', 'grave', 'Pátio', 'Escoriação no antebraço', 'Curativo simples', TRUE, now() - INTERVAL '71 days 14 hours'),
 (31, 29, 'queda', 'moderada', 'Corredor', 'Escorregou no piso molhado', 'Gelo local; observação por 24h', TRUE, now() - INTERVAL '87 days 17 hours'),
 (21, 1, 'mal_estar', 'leve', 'Refeitório', 'Tontura e sudorese após o almoço', 'Aferida glicemia; repouso', TRUE, now() - INTERVAL '66 days 17 hours');

-- ---------- Restrições alimentares ----------
INSERT INTO restricao_alimentar (id_idoso, descricao) VALUES
 (6, 'Diabético'),
 (5, 'Sem lactose'),
 (24, 'Sem sal'),
 (31, 'Branda'),
 (18, 'Hipossódica'),
 (3, 'Sem açúcar'),
 (7, 'Pastoso'),
 (23, 'Sem glúten'),
 (17, 'Sem açúcar'),
 (27, 'Alergia a camarão'),
 (4, 'Diabético'),
 (5, 'Hipossódica'),
 (21, 'Sem sal'),
 (31, 'Pastoso'),
 (20, 'Rica em fibras'),
 (9, 'Branda'),
 (16, 'Diabético'),
 (28, 'Sem açúcar'),
 (21, 'Pastoso'),
 (1, 'Sem sal'),
 (30, 'Alergia a camarão'),
 (24, 'Líquidos espessados'),
 (5, 'Branda'),
 (18, 'Pastoso'),
 (23, 'Hipossódica'),
 (2, 'Pastoso'),
 (29, 'Alergia a camarão'),
 (12, 'Pastoso'),
 (4, 'Sem lactose'),
 (19, 'Alergia a camarão'),
 (9, 'Pastoso'),
 (3, 'Pastoso'),
 (27, 'Branda'),
 (15, 'Sem lactose'),
 (13, 'Rica em fibras'),
 (7, 'Sem lactose');

-- ---------- Registro de refeições (aceitação e hidratação, últimos 10 dias) ----------
INSERT INTO registro_refeicao (id_idoso, id_profissional, tipo, aceitacao, hidratacao_ml, observacoes, data_hora) VALUES
 (1, 11, 'jantar', 90, 150, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (1, 17, 'almoco', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (1, 11, 'jantar', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '18 hours'),
 (1, 18, 'almoco', 50, 200, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '12 hours'),
 (1, 9, 'jantar', 80, 250, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '18 hours'),
 (1, 18, 'almoco', 90, 250, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (1, 10, 'jantar', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (1, 11, 'cafe', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '7 hours'),
 (1, 9, 'jantar', 70, NULL, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (1, 10, 'jantar', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '18 hours'),
 (1, 18, 'jantar', 90, 200, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '18 hours'),
 (1, 11, 'almoco', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '12 hours'),
 (1, 17, 'jantar', 60, NULL, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '18 hours'),
 (2, 9, 'jantar', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (2, 8, 'cafe', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (2, 10, 'almoco', 100, NULL, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (2, 11, 'cafe', 100, 300, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '7 hours'),
 (2, 18, 'almoco', 70, 150, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '12 hours'),
 (2, 6, 'cafe', 60, 200, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '7 hours'),
 (2, 6, 'almoco', 100, 150, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (2, 3, 'almoco', 90, NULL, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '12 hours'),
 (2, 11, 'almoco', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '12 hours'),
 (2, 10, 'cafe', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '7 hours'),
 (2, 18, 'almoco', 70, 150, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '12 hours'),
 (2, 9, 'cafe', 90, NULL, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '7 hours'),
 (2, 10, 'jantar', 60, 150, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '18 hours'),
 (2, 8, 'almoco', 100, 150, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '12 hours'),
 (3, 8, 'cafe', 40, 150, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (3, 6, 'cafe', 40, 200, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '7 hours'),
 (3, 3, 'almoco', 50, 300, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '12 hours'),
 (3, 10, 'jantar', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '18 hours'),
 (3, 7, 'almoco', 50, 250, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '12 hours'),
 (3, 6, 'jantar', 70, 300, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '18 hours'),
 (3, 9, 'almoco', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '12 hours'),
 (4, 22, 'almoco', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '12 hours'),
 (4, 22, 'almoco', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (4, 22, 'cafe', 100, 250, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '7 hours'),
 (4, 22, 'cafe', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '7 hours'),
 (4, 22, 'almoco', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (4, 21, 'jantar', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (4, 22, 'cafe', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '7 hours'),
 (4, 22, 'almoco', 100, 250, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '12 hours'),
 (4, 22, 'cafe', 90, NULL, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '7 hours'),
 (5, 3, 'cafe', 100, 200, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '7 hours'),
 (5, 6, 'almoco', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '12 hours'),
 (5, 18, 'cafe', 90, 150, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '7 hours'),
 (5, 8, 'cafe', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '7 hours'),
 (5, 7, 'almoco', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '12 hours'),
 (5, 8, 'cafe', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '7 hours'),
 (5, 9, 'almoco', 90, 200, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '12 hours'),
 (5, 17, 'cafe', 60, 200, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '7 hours'),
 (5, 18, 'jantar', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '18 hours'),
 (5, 8, 'almoco', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '12 hours'),
 (5, 10, 'jantar', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '18 hours'),
 (9, 8, 'cafe', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '7 hours'),
 (9, 8, 'cafe', 50, 250, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (9, 9, 'cafe', 30, 200, 'Recusou a salada', date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '7 hours'),
 (9, 6, 'jantar', 60, 200, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '18 hours'),
 (9, 10, 'cafe', 60, NULL, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '7 hours'),
 (9, 10, 'almoco', 40, 200, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (9, 10, 'jantar', 40, 300, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (9, 9, 'cafe', 50, 150, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '7 hours'),
 (9, 10, 'cafe', 70, 300, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '7 hours'),
 (9, 7, 'almoco', 20, 250, 'Recusou a salada', date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '12 hours'),
 (9, 7, 'cafe', 70, NULL, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '7 hours'),
 (9, 6, 'jantar', 40, 200, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '18 hours'),
 (9, 6, 'almoco', 60, NULL, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '12 hours'),
 (9, 10, 'almoco', 50, 200, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '12 hours'),
 (10, 17, 'jantar', 70, 200, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (10, 8, 'cafe', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (10, 11, 'almoco', 90, 150, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (10, 3, 'almoco', 60, NULL, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '12 hours'),
 (10, 17, 'almoco', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (10, 11, 'jantar', 100, 200, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (10, 17, 'jantar', 70, 200, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (10, 11, 'almoco', 70, NULL, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '12 hours'),
 (10, 7, 'jantar', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '18 hours'),
 (10, 7, 'cafe', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '7 hours'),
 (10, 7, 'almoco', 70, NULL, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '12 hours'),
 (10, 8, 'cafe', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '7 hours'),
 (10, 9, 'almoco', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '12 hours'),
 (10, 17, 'almoco', 90, 200, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '12 hours'),
 (10, 9, 'jantar', 60, NULL, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '18 hours'),
 (11, 18, 'cafe', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '7 hours'),
 (11, 9, 'jantar', 90, 150, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '18 hours'),
 (11, 17, 'cafe', 100, 150, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '7 hours'),
 (11, 3, 'jantar', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (11, 18, 'jantar', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (11, 6, 'cafe', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '7 hours'),
 (11, 6, 'jantar', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '18 hours'),
 (11, 17, 'almoco', 100, 150, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '12 hours'),
 (11, 7, 'almoco', 70, 150, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '12 hours'),
 (11, 11, 'jantar', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '18 hours'),
 (11, 3, 'jantar', 90, 200, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '18 hours'),
 (12, 10, 'almoco', 90, 250, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (12, 10, 'cafe', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '7 hours'),
 (12, 6, 'jantar', 70, 150, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '18 hours'),
 (12, 11, 'jantar', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '18 hours'),
 (12, 18, 'cafe', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '7 hours'),
 (12, 10, 'almoco', 100, 150, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '12 hours'),
 (12, 7, 'jantar', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '18 hours'),
 (12, 7, 'cafe', 70, NULL, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '7 hours'),
 (12, 8, 'jantar', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '18 hours'),
 (13, 3, 'almoco', 70, 200, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '12 hours'),
 (13, 10, 'jantar', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (13, 7, 'cafe', 70, 200, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (13, 18, 'almoco', 70, 200, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (13, 11, 'jantar', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '18 hours'),
 (13, 11, 'jantar', 40, 300, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (13, 7, 'cafe', 60, 150, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '7 hours'),
 (13, 6, 'almoco', 90, 150, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '12 hours'),
 (13, 7, 'cafe', 70, 150, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '7 hours'),
 (13, 17, 'almoco', 60, NULL, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '12 hours'),
 (13, 11, 'cafe', 70, 150, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '7 hours'),
 (13, 7, 'almoco', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '12 hours'),
 (13, 17, 'jantar', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '18 hours'),
 (14, 8, 'cafe', 70, 200, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '7 hours'),
 (14, 3, 'jantar', 50, NULL, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (14, 17, 'cafe', 100, 200, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (14, 11, 'almoco', 50, NULL, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (14, 10, 'jantar', 90, 150, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '18 hours'),
 (14, 11, 'cafe', 90, 250, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '7 hours'),
 (14, 3, 'almoco', 60, 300, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (14, 6, 'jantar', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (14, 7, 'cafe', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '7 hours'),
 (14, 6, 'jantar', 70, 200, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '18 hours'),
 (14, 10, 'jantar', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '18 hours'),
 (16, 8, 'cafe', 60, 150, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '7 hours'),
 (16, 9, 'jantar', 100, 150, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (16, 11, 'cafe', 90, 150, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (16, 7, 'jantar', 100, 150, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '18 hours'),
 (16, 7, 'cafe', 100, 300, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '7 hours'),
 (16, 8, 'almoco', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (16, 17, 'jantar', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (16, 8, 'almoco', 100, 150, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '12 hours'),
 (16, 10, 'jantar', 90, 150, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (16, 11, 'cafe', 100, NULL, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '7 hours'),
 (16, 10, 'jantar', 100, 150, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '18 hours'),
 (16, 9, 'cafe', 90, NULL, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '7 hours'),
 (17, 18, 'cafe', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '7 hours'),
 (17, 8, 'jantar', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (17, 17, 'almoco', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (17, 7, 'jantar', 100, 300, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '18 hours'),
 (17, 11, 'almoco', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '12 hours'),
 (17, 9, 'jantar', 90, NULL, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '18 hours'),
 (17, 3, 'almoco', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '12 hours'),
 (17, 7, 'almoco', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '12 hours'),
 (17, 9, 'jantar', 90, 250, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '18 hours'),
 (17, 9, 'jantar', 70, NULL, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '18 hours'),
 (17, 6, 'cafe', 70, 300, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '7 hours'),
 (17, 6, 'almoco', 50, 250, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '12 hours'),
 (17, 7, 'almoco', 70, NULL, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '12 hours'),
 (18, 7, 'jantar', 70, 150, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (18, 18, 'cafe', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (18, 17, 'almoco', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (18, 7, 'cafe', 80, 250, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '7 hours'),
 (18, 3, 'almoco', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (18, 10, 'jantar', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (18, 3, 'almoco', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '12 hours'),
 (18, 7, 'jantar', 100, 250, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (18, 11, 'almoco', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '12 hours'),
 (18, 18, 'jantar', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '18 hours'),
 (18, 8, 'almoco', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '12 hours'),
 (18, 17, 'cafe', 70, 300, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '7 hours'),
 (18, 6, 'jantar', 90, NULL, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '18 hours'),
 (18, 11, 'cafe', 100, NULL, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '7 hours'),
 (18, 6, 'almoco', 70, 200, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '12 hours'),
 (19, 18, 'cafe', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (19, 8, 'cafe', 70, 300, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '7 hours'),
 (19, 6, 'almoco', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '12 hours'),
 (19, 18, 'cafe', 50, 150, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '7 hours'),
 (19, 8, 'cafe', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '7 hours'),
 (19, 8, 'jantar', 60, 300, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '18 hours'),
 (19, 9, 'cafe', 100, 300, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '7 hours'),
 (19, 3, 'cafe', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '7 hours'),
 (20, 7, 'jantar', 60, 150, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (20, 6, 'cafe', 30, 300, 'Recusou a salada', date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (20, 18, 'almoco', 50, 300, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (20, 6, 'cafe', 40, 200, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '7 hours'),
 (20, 17, 'almoco', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '12 hours'),
 (20, 3, 'jantar', 60, NULL, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '18 hours'),
 (20, 6, 'cafe', 70, 200, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '7 hours'),
 (20, 10, 'almoco', 40, 150, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (20, 8, 'jantar', 70, 300, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (20, 6, 'cafe', 50, NULL, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '7 hours'),
 (20, 6, 'jantar', 100, 250, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '18 hours'),
 (20, 10, 'almoco', 80, 250, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '12 hours'),
 (21, 3, 'cafe', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '7 hours'),
 (21, 18, 'cafe', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (21, 3, 'jantar', 60, NULL, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '18 hours'),
 (21, 3, 'cafe', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '7 hours'),
 (21, 6, 'almoco', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '12 hours'),
 (21, 8, 'jantar', 60, 200, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '18 hours'),
 (21, 6, 'jantar', 90, 250, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (21, 6, 'cafe', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '7 hours'),
 (21, 8, 'cafe', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '7 hours'),
 (21, 10, 'jantar', 60, 300, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '18 hours'),
 (21, 11, 'jantar', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '18 hours'),
 (21, 9, 'almoco', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '12 hours'),
 (21, 6, 'cafe', 50, 200, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '7 hours'),
 (21, 6, 'almoco', 70, NULL, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '12 hours'),
 (24, 23, 'cafe', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '7 hours'),
 (24, 23, 'almoco', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '12 hours'),
 (24, 23, 'cafe', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (24, 23, 'jantar', 50, 250, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '18 hours'),
 (24, 21, 'almoco', 70, 250, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '12 hours'),
 (24, 22, 'almoco', 50, 300, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (24, 23, 'almoco', 30, 250, 'Recusou a salada', date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '12 hours'),
 (24, 23, 'jantar', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (24, 22, 'cafe', 60, 300, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '7 hours'),
 (24, 23, 'almoco', 60, 300, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '12 hours'),
 (24, 23, 'jantar', 100, 200, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '18 hours'),
 (24, 21, 'cafe', 90, 150, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '7 hours'),
 (24, 22, 'almoco', 70, 300, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '12 hours'),
 (24, 23, 'jantar', 60, NULL, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '18 hours'),
 (24, 22, 'almoco', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '12 hours'),
 (25, 23, 'almoco', 60, NULL, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '12 hours'),
 (25, 22, 'jantar', 40, 250, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (25, 23, 'almoco', 50, 200, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (25, 22, 'cafe', 30, NULL, 'Recusou a salada', date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '7 hours'),
 (25, 21, 'cafe', 30, 200, 'Recusou a salada', date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '7 hours'),
 (25, 23, 'jantar', 50, 200, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (25, 22, 'jantar', 50, 200, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (25, 23, 'cafe', 60, NULL, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '7 hours'),
 (25, 23, 'almoco', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '12 hours'),
 (25, 21, 'cafe', 60, 150, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '7 hours'),
 (25, 21, 'almoco', 50, 250, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '12 hours'),
 (25, 21, 'almoco', 70, 150, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '12 hours'),
 (25, 22, 'cafe', 70, 200, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '7 hours'),
 (26, 21, 'cafe', 70, 200, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '7 hours'),
 (26, 22, 'cafe', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (26, 23, 'almoco', 100, 200, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (26, 22, 'jantar', 90, 150, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '18 hours'),
 (26, 21, 'almoco', 90, 200, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '12 hours'),
 (26, 21, 'jantar', 90, 250, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '18 hours'),
 (26, 21, 'almoco', 60, 200, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (26, 23, 'almoco', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '12 hours'),
 (26, 22, 'jantar', 100, 150, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (26, 22, 'cafe', 100, NULL, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '7 hours'),
 (26, 23, 'jantar', 100, 250, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '18 hours'),
 (26, 21, 'almoco', 70, 300, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '12 hours'),
 (26, 21, 'cafe', 70, NULL, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '7 hours'),
 (26, 22, 'almoco', 100, 300, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '12 hours'),
 (27, 23, 'almoco', 90, NULL, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '12 hours'),
 (27, 23, 'jantar', 80, 250, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (27, 22, 'cafe', 60, 250, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (27, 21, 'almoco', 60, 300, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (27, 23, 'jantar', 90, NULL, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '18 hours'),
 (27, 21, 'cafe', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '7 hours'),
 (27, 22, 'almoco', 70, 150, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (27, 22, 'jantar', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (27, 21, 'almoco', 50, 250, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '12 hours'),
 (27, 22, 'jantar', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (27, 23, 'cafe', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '7 hours'),
 (27, 23, 'jantar', 90, 200, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '18 hours'),
 (27, 21, 'cafe', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '7 hours'),
 (27, 23, 'almoco', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '12 hours'),
 (27, 22, 'cafe', 50, NULL, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '7 hours'),
 (27, 23, 'almoco', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '12 hours'),
 (30, 22, 'jantar', 70, 300, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (30, 23, 'cafe', 80, 250, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '7 hours'),
 (30, 21, 'almoco', 100, 300, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (30, 21, 'almoco', 90, NULL, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '12 hours'),
 (30, 22, 'cafe', 100, 200, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '7 hours'),
 (30, 21, 'jantar', 70, 150, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (30, 22, 'almoco', 100, NULL, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '12 hours'),
 (30, 21, 'almoco', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '12 hours'),
 (30, 21, 'jantar', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '18 hours'),
 (30, 23, 'cafe', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '7 hours'),
 (30, 21, 'jantar', 100, 150, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '18 hours'),
 (30, 21, 'cafe', 70, NULL, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '7 hours'),
 (30, 23, 'jantar', 100, 250, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '18 hours'),
 (31, 29, 'cafe', 70, 150, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '7 hours'),
 (31, 29, 'almoco', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '12 hours'),
 (31, 29, 'almoco', 60, NULL, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (31, 29, 'jantar', 90, 200, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '18 hours'),
 (31, 29, 'cafe', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '7 hours'),
 (31, 29, 'almoco', 70, NULL, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '12 hours'),
 (31, 29, 'cafe', 90, NULL, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '7 hours'),
 (31, 29, 'jantar', 100, NULL, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (31, 29, 'almoco', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '12 hours'),
 (31, 29, 'jantar', 50, 300, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '18 hours'),
 (31, 29, 'cafe', 90, NULL, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '7 hours'),
 (31, 29, 'almoco', 80, 250, NULL, date_trunc('day', now()) - INTERVAL '7 days' + INTERVAL '12 hours'),
 (31, 29, 'cafe', 80, 200, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '7 hours'),
 (32, 29, 'cafe', 80, 250, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '7 hours'),
 (32, 29, 'jantar', 90, 300, NULL, date_trunc('day', now()) - INTERVAL '1 days' + INTERVAL '18 hours'),
 (32, 29, 'almoco', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '2 days' + INTERVAL '12 hours'),
 (32, 29, 'jantar', 100, 300, NULL, date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '18 hours'),
 (32, 29, 'cafe', 80, 250, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '7 hours'),
 (32, 29, 'almoco', 80, NULL, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '12 hours'),
 (32, 29, 'jantar', 100, 250, NULL, date_trunc('day', now()) - INTERVAL '4 days' + INTERVAL '18 hours'),
 (32, 29, 'almoco', 100, 150, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '12 hours'),
 (32, 29, 'jantar', 90, 250, NULL, date_trunc('day', now()) - INTERVAL '5 days' + INTERVAL '18 hours'),
 (32, 29, 'cafe', 90, 200, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '7 hours'),
 (32, 29, 'almoco', 90, 150, NULL, date_trunc('day', now()) - INTERVAL '6 days' + INTERVAL '12 hours'),
 (32, 29, 'almoco', 80, 150, NULL, date_trunc('day', now()) - INTERVAL '8 days' + INTERVAL '12 hours'),
 (32, 29, 'almoco', 100, 250, NULL, date_trunc('day', now()) - INTERVAL '9 days' + INTERVAL '12 hours'),
 (32, 29, 'cafe', 80, 300, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '7 hours'),
 (32, 29, 'jantar', 100, 250, NULL, date_trunc('day', now()) - INTERVAL '10 days' + INTERVAL '18 hours');

-- ---------- Consentimentos LGPD (um por idoso; inclui um revogado e renovado) ----------
INSERT INTO consentimento_lgpd (id_idoso, categoria, finalidade, data_concessao, data_revogacao) VALUES
 (5, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (6, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (7, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (8, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (9, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (10, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '659 days', NULL),
 (11, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (12, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '693 days', NULL),
 (13, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (14, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (15, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (16, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '360 days', NULL),
 (17, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (18, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '690 days', NULL),
 (19, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '344 days', NULL),
 (20, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (21, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (22, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (23, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (24, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (25, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '447 days', NULL),
 (26, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '171 days', NULL),
 (27, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '509 days', NULL),
 (28, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (29, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '494 days', NULL),
 (30, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (31, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '700 days', NULL),
 (32, 'dados_saude', 'Registro e compartilhamento de dados de saúde com responsável legal', now() - INTERVAL '455 days', NULL),
 (7, 'imagem', 'Uso de fotografias no Mural da Família', now() - INTERVAL '200 days', now() - INTERVAL '30 days'),
 (7, 'imagem', 'Uso de fotografias no Mural da Família', now() - INTERVAL '10 days', NULL);

-- ---------- Trilha de auditoria (histórico anterior aos triggers) ----------
INSERT INTO log_auditoria (id_usuario, acao, tabela_afetada, id_registro, data_hora) VALUES
 (21, 'leitura', 'intercorrencia', 23, now() - INTERVAL '29 days 5 hours'),
 (46, 'criacao', 'vw_painel_idoso', 11, now() - INTERVAL '5 days 20 hours'),
 (55, 'criacao', 'administracao_medicacao', 8, now() - INTERVAL '18 days 13 hours'),
 (60, 'criacao', 'prescricao', 30, now() - INTERVAL '58 days 19 hours'),
 (22, 'criacao', 'administracao_medicacao', 24, now() - INTERVAL '3 days 10 hours'),
 (9, 'criacao', 'administracao_medicacao', 27, now() - INTERVAL '13 days 3 hours'),
 (4, 'leitura', 'prescricao', 29, now() - INTERVAL '29 days 8 hours'),
 (36, 'leitura', 'sinal_vital', 2, now() - INTERVAL '43 days 1 hours'),
 (71, 'leitura', 'sinal_vital', 27, now() - INTERVAL '4 hours'),
 (52, 'criacao', 'intercorrencia', 11, now() - INTERVAL '36 days 13 hours'),
 (34, 'leitura', 'recado_mural', 23, now() - INTERVAL '29 days 13 hours'),
 (47, 'criacao', 'sinal_vital', 4, now() - INTERVAL '59 days 15 hours'),
 (15, 'edicao', 'administracao_medicacao', 24, now() - INTERVAL '53 days 23 hours'),
 (49, 'leitura', 'administracao_medicacao', 2, now() - INTERVAL '48 days 20 hours'),
 (15, 'edicao', 'vw_painel_idoso', 18, now() - INTERVAL '49 days 15 hours'),
 (38, 'criacao', 'administracao_medicacao', 26, now() - INTERVAL '37 days 17 hours'),
 (3, 'leitura', 'recado_mural', 28, now() - INTERVAL '55 days 11 hours'),
 (32, 'criacao', 'administracao_medicacao', 13, now() - INTERVAL '41 days 8 hours'),
 (27, 'criacao', 'registro_bem_estar', 15, now() - INTERVAL '43 days 7 hours'),
 (42, 'criacao', 'vw_painel_idoso', 10, now() - INTERVAL '37 days 3 hours'),
 (51, 'criacao', 'administracao_medicacao', 19, now() - INTERVAL '31 days 3 hours'),
 (8, 'edicao', 'recado_mural', 6, now() - INTERVAL '1 days 23 hours'),
 (15, 'criacao', 'vw_painel_idoso', 22, now() - INTERVAL '55 days 10 hours'),
 (13, 'leitura', 'administracao_medicacao', 13, now() - INTERVAL '21 days 13 hours'),
 (48, 'leitura', 'sinal_vital', 17, now() - INTERVAL '32 days 7 hours'),
 (54, 'leitura', 'recado_mural', 27, now() - INTERVAL '31 days 14 hours'),
 (43, 'criacao', 'intercorrencia', 12, now() - INTERVAL '17 days'),
 (23, 'criacao', 'registro_bem_estar', 27, now() - INTERVAL '42 days 10 hours'),
 (3, 'criacao', 'vw_painel_idoso', 10, now() - INTERVAL '9 days 22 hours'),
 (13, 'criacao', 'registro_bem_estar', 10, now() - INTERVAL '41 days 19 hours');

-- ---------- Partidas dos outros jogos: Memória, Buraco, Paciência e Cuidar do Xodó ----------
INSERT INTO partida_jogo (id_idoso, jogo, resultado, pontuacao, jogadas, data_hora) VALUES
 (7, 'buraco', 'derrota', 366, 32, now() - INTERVAL '26 days 2 hours'),
 (7, 'paciencia', 'abandono', NULL, 138, now() - INTERVAL '7 days 3 hours'),
 (12, 'cuidar_xodo', 'concluido', NULL, 6, now() - INTERVAL '5 hours'),
 (1, 'paciencia', 'vitoria', NULL, 161, now() - INTERVAL '26 days 4 hours'),
 (12, 'paciencia', 'vitoria', NULL, 102, now() - INTERVAL '10 days 2 hours'),
 (2, 'cuidar_xodo', 'concluido', NULL, 6, now() - INTERVAL '24 days 5 hours'),
 (12, 'paciencia', 'vitoria', NULL, 88, now() - INTERVAL '6 days 2 hours'),
 (2, 'memoria', 'concluido', NULL, 20, now() - INTERVAL '19 days 9 hours'),
 (2, 'memoria', 'concluido', NULL, 12, now() - INTERVAL '23 days 6 hours'),
 (2, 'memoria', 'concluido', NULL, 20, now() - INTERVAL '26 days 2 hours'),
 (12, 'memoria', 'concluido', NULL, 14, now() - INTERVAL '14 days 9 hours'),
 (2, 'buraco', 'vitoria', 533, 68, now() - INTERVAL '18 days 10 hours'),
 (12, 'memoria', 'concluido', NULL, 13, now() - INTERVAL '18 days 8 hours'),
 (10, 'memoria', 'concluido', NULL, 18, now() - INTERVAL '1 hours'),
 (1, 'paciencia', 'abandono', NULL, 65, now() - INTERVAL '23 days 6 hours'),
 (10, 'memoria', 'concluido', NULL, 14, now() - INTERVAL '16 days 10 hours'),
 (11, 'memoria', 'concluido', NULL, 21, now() - INTERVAL '26 days 2 hours'),
 (5, 'buraco', 'vitoria', 137, 51, now() - INTERVAL '29 days 6 hours'),
 (10, 'cuidar_xodo', 'concluido', NULL, 6, now() - INTERVAL '1 hours'),
 (11, 'memoria', 'concluido', NULL, 6, now() - INTERVAL '22 days 1 hours'),
 (6, 'memoria', 'concluido', NULL, 20, now() - INTERVAL '3 days 7 hours'),
 (11, 'memoria', 'concluido', NULL, 10, now() - INTERVAL '7 days 5 hours'),
 (6, 'memoria', 'concluido', NULL, 11, now() - INTERVAL '5 days 3 hours'),
 (1, 'memoria', 'concluido', NULL, 13, now() - INTERVAL '21 days 9 hours'),
 (10, 'cuidar_xodo', 'concluido', NULL, 6, now() - INTERVAL '22 days 10 hours'),
 (10, 'paciencia', 'abandono', NULL, 94, now() - INTERVAL '19 days 2 hours'),
 (11, 'cuidar_xodo', 'concluido', NULL, 6, now() - INTERVAL '13 days 5 hours'),
 (12, 'buraco', 'derrota', 584, 32, now() - INTERVAL '10 hours'),
 (11, 'memoria', 'concluido', NULL, 7, now() - INTERVAL '3 hours'),
 (1, 'memoria', 'concluido', NULL, 9, now() - INTERVAL '16 days 4 hours'),
 (14, 'memoria', 'concluido', NULL, 19, now() - INTERVAL '5 days 2 hours'),
 (14, 'paciencia', 'abandono', NULL, 118, now() - INTERVAL '28 days 8 hours'),
 (12, 'paciencia', 'vitoria', NULL, 172, now() - INTERVAL '26 days 7 hours'),
 (7, 'buraco', 'vitoria', 656, 40, now() - INTERVAL '10 days 4 hours'),
 (7, 'buraco', 'abandono', NULL, 67, now() - INTERVAL '24 days 9 hours'),
 (10, 'cuidar_xodo', 'concluido', NULL, 6, now() - INTERVAL '17 days 7 hours'),
 (7, 'paciencia', 'abandono', NULL, 172, now() - INTERVAL '17 days 5 hours'),
 (2, 'buraco', 'vitoria', 268, 28, now() - INTERVAL '11 days 1 hours'),
 (6, 'cuidar_xodo', 'concluido', NULL, 6, now() - INTERVAL '19 days 9 hours'),
 (13, 'cuidar_xodo', 'concluido', NULL, 6, now() - INTERVAL '1 days 9 hours');

-- ---------- Eventos do Xodó gerados pelas ações acima ----------
INSERT INTO evento_pet (id_pet, origem, pontos_ganhos, data_hora) VALUES
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '7 days 2 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '12 days 2 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '13 days 4 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '15 days 10 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '16 days 10 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '23 days 1 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '29 days 8 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '30 days 9 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '31 days 4 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '32 days 3 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '33 days 3 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '34 days 10 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '35 days 3 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '37 days 7 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '39 days 7 hours'),
 (1, 'checkin_bem_estar', 10, now() - INTERVAL '44 days 3 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '5 days 5 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '6 days 2 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '8 days 8 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '11 days 7 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '14 days 10 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '15 days 6 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '17 days 7 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '19 days 5 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '24 days 1 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '25 days 10 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '26 days 4 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '27 days 9 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '29 days 9 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '30 days 3 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '34 days 9 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '38 days 2 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '40 days 3 hours'),
 (2, 'checkin_bem_estar', 10, now() - INTERVAL '43 days 10 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '3 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '1 days 4 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '3 days 2 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '4 days 1 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '6 days 9 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '8 days 3 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '15 days 2 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '16 days 8 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '17 days 7 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '21 days 6 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '22 days 1 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '25 days 6 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '26 days 2 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '29 days 1 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '30 days 2 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '31 days 4 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '36 days 8 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '39 days 9 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '42 days 8 hours'),
 (3, 'checkin_bem_estar', 10, now() - INTERVAL '43 days 5 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '5 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '3 days 5 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '4 days 3 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '6 days 7 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '8 days 6 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '9 days 2 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '11 days 1 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '12 days 9 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '16 days 3 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '19 days 6 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '20 days 3 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '22 days 10 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '23 days 3 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '32 days 4 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '35 days 3 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '41 days 3 hours'),
 (4, 'checkin_bem_estar', 10, now() - INTERVAL '43 days 1 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '9 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '6 days 9 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '7 days 9 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '10 days 6 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '11 days 2 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '14 days 8 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '16 days 6 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '18 days 1 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '21 days 2 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '28 days 1 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '29 days 6 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '31 days 10 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '34 days 1 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '37 days 5 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '38 days 6 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '39 days 3 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '40 days 10 hours'),
 (5, 'checkin_bem_estar', 10, now() - INTERVAL '44 days 9 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '1 days 4 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '4 days 10 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '5 days 1 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '7 days 3 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '9 days 7 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '10 days 3 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '11 days 5 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '12 days 3 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '13 days 3 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '15 days 10 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '17 days 10 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '18 days 7 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '19 days 3 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '21 days 2 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '22 days 6 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '24 days 5 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '25 days 4 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '27 days 4 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '30 days 4 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '32 days 10 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '40 days 2 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '41 days 7 hours'),
 (6, 'checkin_bem_estar', 10, now() - INTERVAL '44 days 5 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '10 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '2 days 6 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '3 days 5 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '4 days 7 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '5 days 2 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '7 days 4 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '9 days 8 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '13 days 2 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '15 days 2 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '16 days 8 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '17 days 5 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '18 days 6 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '23 days 5 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '25 days 5 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '26 days 6 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '27 days 10 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '29 days 6 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '30 days 3 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '34 days 7 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '39 days 1 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '40 days 6 hours'),
 (8, 'checkin_bem_estar', 10, now() - INTERVAL '43 days 3 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '4 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '1 days 1 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '4 days 2 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '12 days 4 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '14 days 6 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '19 days 10 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '20 days 7 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '22 days 4 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '23 days 2 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '25 days 6 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '27 days 10 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '28 days 1 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '29 days 7 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '33 days 7 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '34 days 6 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '37 days 8 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '38 days 4 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '39 days 4 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '42 days 9 hours'),
 (9, 'checkin_bem_estar', 10, now() - INTERVAL '44 days 5 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '8 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '2 days 8 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '3 days 5 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '4 days 2 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '5 days 7 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '12 days 10 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '14 days 9 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '17 days 10 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '20 days 3 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '21 days 4 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '23 days 8 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '26 days 10 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '29 days 2 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '34 days 3 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '36 days 6 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '39 days 2 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '41 days 2 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '43 days 6 hours'),
 (10, 'checkin_bem_estar', 10, now() - INTERVAL '44 days 1 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '6 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '1 days 2 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '2 days 1 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '7 days 1 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '10 days 7 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '11 days 4 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '12 days 1 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '13 days 3 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '15 days 7 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '18 days 4 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '19 days 4 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '21 days 3 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '22 days 4 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '25 days 6 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '30 days 1 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '32 days 9 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '39 days 5 hours'),
 (11, 'checkin_bem_estar', 10, now() - INTERVAL '40 days 9 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '3 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '2 days 10 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '4 days 10 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '5 days 7 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '6 days 6 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '7 days 4 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '14 days 10 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '15 days 5 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '17 days 7 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '24 days 1 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '27 days 6 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '28 days 6 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '31 days 4 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '32 days 2 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '33 days 9 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '34 days 10 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '35 days 3 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '37 days 7 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '38 days 2 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '39 days 6 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '40 days 7 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '41 days 6 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '42 days 7 hours'),
 (12, 'checkin_bem_estar', 10, now() - INTERVAL '44 days 7 hours'),
 (9, 'avaliacao_concluida', 20, now() - INTERVAL '13 days 1 hours'),
 (25, 'avaliacao_concluida', 20, now() - INTERVAL '78 days 1 hours'),
 (13, 'avaliacao_concluida', 20, now() - INTERVAL '122 days 1 hours'),
 (13, 'avaliacao_concluida', 20, now() - INTERVAL '99 days 1 hours'),
 (8, 'avaliacao_concluida', 20, now() - INTERVAL '184 days 1 hours'),
 (8, 'avaliacao_concluida', 20, now() - INTERVAL '173 days 1 hours'),
 (14, 'avaliacao_concluida', 20, now() - INTERVAL '165 days 1 hours'),
 (14, 'avaliacao_concluida', 20, now() - INTERVAL '82 days 1 hours'),
 (4, 'avaliacao_concluida', 20, now() - INTERVAL '175 days 1 hours'),
 (4, 'avaliacao_concluida', 20, now() - INTERVAL '149 days 1 hours'),
 (12, 'avaliacao_concluida', 20, now() - INTERVAL '111 days 1 hours'),
 (12, 'avaliacao_concluida', 20, now() - INTERVAL '75 days 1 hours'),
 (12, 'avaliacao_concluida', 20, now() - INTERVAL '156 days 1 hours'),
 (29, 'avaliacao_concluida', 20, now() - INTERVAL '12 days 1 hours'),
 (29, 'avaliacao_concluida', 20, now() - INTERVAL '184 days 1 hours'),
 (29, 'avaliacao_concluida', 20, now() - INTERVAL '80 days 1 hours'),
 (6, 'avaliacao_concluida', 20, now() - INTERVAL '61 days 1 hours'),
 (30, 'avaliacao_concluida', 20, now() - INTERVAL '106 days 1 hours'),
 (30, 'avaliacao_concluida', 20, now() - INTERVAL '172 days 1 hours'),
 (30, 'avaliacao_concluida', 20, now() - INTERVAL '132 days 1 hours'),
 (26, 'avaliacao_concluida', 20, now() - INTERVAL '12 days 1 hours'),
 (17, 'avaliacao_concluida', 20, now() - INTERVAL '190 days 1 hours'),
 (11, 'avaliacao_concluida', 20, now() - INTERVAL '145 days 1 hours'),
 (27, 'avaliacao_concluida', 20, now() - INTERVAL '187 days 1 hours'),
 (27, 'avaliacao_concluida', 20, now() - INTERVAL '132 days 1 hours'),
 (18, 'avaliacao_concluida', 20, now() - INTERVAL '27 days 1 hours'),
 (18, 'avaliacao_concluida', 20, now() - INTERVAL '167 days 1 hours'),
 (18, 'avaliacao_concluida', 20, now() - INTERVAL '61 days 1 hours'),
 (15, 'avaliacao_concluida', 20, now() - INTERVAL '176 days 1 hours'),
 (28, 'avaliacao_concluida', 20, now() - INTERVAL '159 days 1 hours'),
 (28, 'avaliacao_concluida', 20, now() - INTERVAL '115 days 1 hours'),
 (3, 'avaliacao_concluida', 20, now() - INTERVAL '142 days 1 hours'),
 (3, 'avaliacao_concluida', 20, now() - INTERVAL '95 days 1 hours'),
 (10, 'avaliacao_concluida', 20, now() - INTERVAL '187 days 1 hours'),
 (10, 'avaliacao_concluida', 20, now() - INTERVAL '76 days 1 hours'),
 (5, 'avaliacao_concluida', 20, now() - INTERVAL '132 days 1 hours'),
 (24, 'avaliacao_concluida', 20, now() - INTERVAL '135 days 1 hours'),
 (19, 'avaliacao_concluida', 20, now() - INTERVAL '122 days 1 hours'),
 (19, 'avaliacao_concluida', 20, now() - INTERVAL '65 days 1 hours'),
 (20, 'avaliacao_concluida', 20, now() - INTERVAL '79 days 1 hours'),
 (20, 'avaliacao_concluida', 20, now() - INTERVAL '47 days 1 hours'),
 (20, 'avaliacao_concluida', 20, now() - INTERVAL '25 days 1 hours'),
 (1, 'participacao_atividade', 30, now() - INTERVAL '32 days 1 hours'),
 (30, 'participacao_atividade', 30, now() - INTERVAL '32 days 1 hours'),
 (4, 'participacao_atividade', 30, now() - INTERVAL '32 days 1 hours'),
 (5, 'participacao_atividade', 30, now() - INTERVAL '32 days 1 hours'),
 (8, 'participacao_atividade', 30, now() - INTERVAL '32 days 1 hours'),
 (9, 'participacao_atividade', 30, now() - INTERVAL '32 days 1 hours'),
 (12, 'participacao_atividade', 30, now() - INTERVAL '32 days 1 hours'),
 (15, 'participacao_atividade', 30, now() - INTERVAL '32 days 1 hours'),
 (17, 'participacao_atividade', 30, now() - INTERVAL '32 days 1 hours'),
 (18, 'participacao_atividade', 30, now() - INTERVAL '32 days 1 hours'),
 (19, 'participacao_atividade', 30, now() - INTERVAL '32 days 1 hours'),
 (20, 'participacao_atividade', 30, now() - INTERVAL '32 days 1 hours'),
 (3, 'participacao_atividade', 30, now() - INTERVAL '33 days 1 hours'),
 (4, 'participacao_atividade', 30, now() - INTERVAL '33 days 1 hours'),
 (5, 'participacao_atividade', 30, now() - INTERVAL '33 days 1 hours'),
 (6, 'participacao_atividade', 30, now() - INTERVAL '33 days 1 hours'),
 (7, 'participacao_atividade', 30, now() - INTERVAL '33 days 1 hours'),
 (9, 'participacao_atividade', 30, now() - INTERVAL '33 days 1 hours'),
 (10, 'participacao_atividade', 30, now() - INTERVAL '33 days 1 hours'),
 (13, 'participacao_atividade', 30, now() - INTERVAL '33 days 1 hours'),
 (14, 'participacao_atividade', 30, now() - INTERVAL '33 days 1 hours'),
 (17, 'participacao_atividade', 30, now() - INTERVAL '33 days 1 hours'),
 (18, 'participacao_atividade', 30, now() - INTERVAL '33 days 1 hours'),
 (19, 'participacao_atividade', 30, now() - INTERVAL '33 days 1 hours'),
 (30, 'participacao_atividade', 30, now() - INTERVAL '27 days 1 hours'),
 (3, 'participacao_atividade', 30, now() - INTERVAL '27 days 1 hours'),
 (4, 'participacao_atividade', 30, now() - INTERVAL '27 days 1 hours'),
 (9, 'participacao_atividade', 30, now() - INTERVAL '27 days 1 hours'),
 (10, 'participacao_atividade', 30, now() - INTERVAL '27 days 1 hours'),
 (13, 'participacao_atividade', 30, now() - INTERVAL '27 days 1 hours'),
 (15, 'participacao_atividade', 30, now() - INTERVAL '27 days 1 hours'),
 (16, 'participacao_atividade', 30, now() - INTERVAL '27 days 1 hours'),
 (19, 'participacao_atividade', 30, now() - INTERVAL '27 days 1 hours'),
 (20, 'participacao_atividade', 30, now() - INTERVAL '27 days 1 hours'),
 (1, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (2, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (30, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (3, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (4, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (10, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (11, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (12, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (13, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (15, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (17, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (19, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (20, 'participacao_atividade', 30, now() - INTERVAL '14 days 1 hours'),
 (2, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (30, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (4, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (5, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (8, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (9, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (20, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (1, 'participacao_atividade', 30, now() - INTERVAL '13 days 1 hours'),
 (3, 'participacao_atividade', 30, now() - INTERVAL '13 days 1 hours'),
 (4, 'participacao_atividade', 30, now() - INTERVAL '13 days 1 hours'),
 (6, 'participacao_atividade', 30, now() - INTERVAL '13 days 1 hours'),
 (7, 'participacao_atividade', 30, now() - INTERVAL '13 days 1 hours'),
 (8, 'participacao_atividade', 30, now() - INTERVAL '13 days 1 hours'),
 (9, 'participacao_atividade', 30, now() - INTERVAL '13 days 1 hours'),
 (12, 'participacao_atividade', 30, now() - INTERVAL '13 days 1 hours'),
 (15, 'participacao_atividade', 30, now() - INTERVAL '13 days 1 hours'),
 (17, 'participacao_atividade', 30, now() - INTERVAL '13 days 1 hours'),
 (19, 'participacao_atividade', 30, now() - INTERVAL '13 days 1 hours'),
 (6, 'participacao_atividade', 30, now() - INTERVAL '25 days 1 hours'),
 (11, 'participacao_atividade', 30, now() - INTERVAL '25 days 1 hours'),
 (12, 'participacao_atividade', 30, now() - INTERVAL '25 days 1 hours'),
 (15, 'participacao_atividade', 30, now() - INTERVAL '25 days 1 hours'),
 (17, 'participacao_atividade', 30, now() - INTERVAL '25 days 1 hours'),
 (19, 'participacao_atividade', 30, now() - INTERVAL '25 days 1 hours'),
 (1, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (30, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (3, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (4, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (5, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (6, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (7, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (10, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (14, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (17, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (18, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (19, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (20, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (3, 'participacao_atividade', 30, now() - INTERVAL '17 days 1 hours'),
 (6, 'participacao_atividade', 30, now() - INTERVAL '17 days 1 hours'),
 (7, 'participacao_atividade', 30, now() - INTERVAL '17 days 1 hours'),
 (8, 'participacao_atividade', 30, now() - INTERVAL '17 days 1 hours'),
 (14, 'participacao_atividade', 30, now() - INTERVAL '17 days 1 hours'),
 (16, 'participacao_atividade', 30, now() - INTERVAL '17 days 1 hours'),
 (17, 'participacao_atividade', 30, now() - INTERVAL '17 days 1 hours'),
 (19, 'participacao_atividade', 30, now() - INTERVAL '17 days 1 hours'),
 (20, 'participacao_atividade', 30, now() - INTERVAL '17 days 1 hours'),
 (6, 'participacao_atividade', 30, now() - INTERVAL '28 days 1 hours'),
 (7, 'participacao_atividade', 30, now() - INTERVAL '28 days 1 hours'),
 (9, 'participacao_atividade', 30, now() - INTERVAL '28 days 1 hours'),
 (12, 'participacao_atividade', 30, now() - INTERVAL '28 days 1 hours'),
 (13, 'participacao_atividade', 30, now() - INTERVAL '28 days 1 hours'),
 (15, 'participacao_atividade', 30, now() - INTERVAL '28 days 1 hours'),
 (20, 'participacao_atividade', 30, now() - INTERVAL '28 days 1 hours'),
 (2, 'participacao_atividade', 30, now() - INTERVAL '18 days 1 hours'),
 (30, 'participacao_atividade', 30, now() - INTERVAL '18 days 1 hours'),
 (8, 'participacao_atividade', 30, now() - INTERVAL '18 days 1 hours'),
 (9, 'participacao_atividade', 30, now() - INTERVAL '18 days 1 hours'),
 (10, 'participacao_atividade', 30, now() - INTERVAL '18 days 1 hours'),
 (11, 'participacao_atividade', 30, now() - INTERVAL '18 days 1 hours'),
 (12, 'participacao_atividade', 30, now() - INTERVAL '18 days 1 hours'),
 (18, 'participacao_atividade', 30, now() - INTERVAL '18 days 1 hours'),
 (1, 'participacao_atividade', 30, now() - INTERVAL '20 days 1 hours'),
 (30, 'participacao_atividade', 30, now() - INTERVAL '20 days 1 hours'),
 (6, 'participacao_atividade', 30, now() - INTERVAL '20 days 1 hours'),
 (7, 'participacao_atividade', 30, now() - INTERVAL '20 days 1 hours'),
 (9, 'participacao_atividade', 30, now() - INTERVAL '20 days 1 hours'),
 (12, 'participacao_atividade', 30, now() - INTERVAL '20 days 1 hours'),
 (13, 'participacao_atividade', 30, now() - INTERVAL '20 days 1 hours'),
 (16, 'participacao_atividade', 30, now() - INTERVAL '20 days 1 hours'),
 (19, 'participacao_atividade', 30, now() - INTERVAL '20 days 1 hours'),
 (20, 'participacao_atividade', 30, now() - INTERVAL '20 days 1 hours'),
 (1, 'participacao_atividade', 30, now() - INTERVAL '31 days 1 hours'),
 (30, 'participacao_atividade', 30, now() - INTERVAL '31 days 1 hours'),
 (3, 'participacao_atividade', 30, now() - INTERVAL '31 days 1 hours'),
 (4, 'participacao_atividade', 30, now() - INTERVAL '31 days 1 hours'),
 (5, 'participacao_atividade', 30, now() - INTERVAL '31 days 1 hours'),
 (12, 'participacao_atividade', 30, now() - INTERVAL '31 days 1 hours'),
 (15, 'participacao_atividade', 30, now() - INTERVAL '31 days 1 hours'),
 (17, 'participacao_atividade', 30, now() - INTERVAL '31 days 1 hours'),
 (19, 'participacao_atividade', 30, now() - INTERVAL '31 days 1 hours'),
 (1, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (2, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (30, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (3, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (5, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (7, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (8, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (10, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (11, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (12, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (13, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (15, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (18, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (19, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (20, 'participacao_atividade', 30, now() - INTERVAL '16 days 1 hours'),
 (1, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (2, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (30, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (3, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (5, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (9, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (12, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (16, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (17, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (18, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (20, 'participacao_atividade', 30, now() - INTERVAL '26 days 1 hours'),
 (1, 'participacao_atividade', 30, now() - INTERVAL '1 hours'),
 (2, 'participacao_atividade', 30, now() - INTERVAL '1 hours'),
 (3, 'participacao_atividade', 30, now() - INTERVAL '1 hours'),
 (6, 'participacao_atividade', 30, now() - INTERVAL '1 hours'),
 (7, 'participacao_atividade', 30, now() - INTERVAL '1 hours'),
 (8, 'participacao_atividade', 30, now() - INTERVAL '1 hours'),
 (10, 'participacao_atividade', 30, now() - INTERVAL '1 hours'),
 (12, 'participacao_atividade', 30, now() - INTERVAL '1 hours'),
 (13, 'participacao_atividade', 30, now() - INTERVAL '1 hours'),
 (15, 'participacao_atividade', 30, now() - INTERVAL '1 hours'),
 (20, 'participacao_atividade', 30, now() - INTERVAL '1 hours'),
 (21, 'participacao_atividade', 30, now() - INTERVAL '7 days 1 hours'),
 (22, 'participacao_atividade', 30, now() - INTERVAL '7 days 1 hours'),
 (26, 'participacao_atividade', 30, now() - INTERVAL '7 days 1 hours'),
 (25, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (26, 'participacao_atividade', 30, now() - INTERVAL '6 days 1 hours'),
 (21, 'participacao_atividade', 30, now() - INTERVAL '38 days 1 hours'),
 (23, 'participacao_atividade', 30, now() - INTERVAL '38 days 1 hours'),
 (21, 'participacao_atividade', 30, now() - INTERVAL '37 days 1 hours'),
 (23, 'participacao_atividade', 30, now() - INTERVAL '37 days 1 hours'),
 (25, 'participacao_atividade', 30, now() - INTERVAL '37 days 1 hours'),
 (21, 'participacao_atividade', 30, now() - INTERVAL '38 days 1 hours'),
 (22, 'participacao_atividade', 30, now() - INTERVAL '38 days 1 hours'),
 (24, 'participacao_atividade', 30, now() - INTERVAL '38 days 1 hours'),
 (25, 'participacao_atividade', 30, now() - INTERVAL '38 days 1 hours'),
 (26, 'participacao_atividade', 30, now() - INTERVAL '38 days 1 hours'),
 (27, 'participacao_atividade', 30, now() - INTERVAL '38 days 1 hours'),
 (22, 'participacao_atividade', 30, now() - INTERVAL '18 days 1 hours'),
 (25, 'participacao_atividade', 30, now() - INTERVAL '18 days 1 hours'),
 (21, 'participacao_atividade', 30, now() - INTERVAL '22 days 1 hours'),
 (22, 'participacao_atividade', 30, now() - INTERVAL '22 days 1 hours'),
 (26, 'participacao_atividade', 30, now() - INTERVAL '22 days 1 hours'),
 (27, 'participacao_atividade', 30, now() - INTERVAL '22 days 1 hours'),
 (4, 'partida_domino', 10, now() - INTERVAL '13 days 8 hours'),
 (9, 'partida_domino', 40, now() - INTERVAL '13 days 8 hours'),
 (6, 'partida_domino', 40, now() - INTERVAL '21 days 8 hours'),
 (11, 'partida_domino', 10, now() - INTERVAL '21 days 8 hours'),
 (2, 'partida_domino', 40, now() - INTERVAL '1 days 2 hours'),
 (1, 'partida_domino', 10, now() - INTERVAL '1 days 2 hours'),
 (3, 'partida_domino', 10, now() - INTERVAL '17 days 1 hours'),
 (5, 'partida_domino', 40, now() - INTERVAL '17 days 1 hours'),
 (10, 'partida_domino', 40, now() - INTERVAL '22 days 9 hours'),
 (11, 'partida_domino', 10, now() - INTERVAL '22 days 9 hours'),
 (9, 'partida_domino', 40, now() - INTERVAL '26 days 9 hours'),
 (11, 'partida_domino', 10, now() - INTERVAL '26 days 9 hours'),
 (8, 'partida_domino', 40, now() - INTERVAL '29 days 5 hours'),
 (9, 'partida_domino', 10, now() - INTERVAL '29 days 5 hours'),
 (10, 'partida_domino', 40, now() - INTERVAL '8 days 1 hours'),
 (11, 'partida_domino', 10, now() - INTERVAL '25 days 7 hours'),
 (5, 'partida_domino', 40, now() - INTERVAL '25 days 7 hours'),
 (1, 'partida_domino', 10, now() - INTERVAL '23 days 1 hours'),
 (5, 'partida_domino', 40, now() - INTERVAL '23 days 1 hours'),
 (12, 'partida_domino', 40, now() - INTERVAL '4 days 1 hours'),
 (3, 'partida_domino', 40, now() - INTERVAL '15 days 3 hours'),
 (10, 'partida_domino', 10, now() - INTERVAL '15 days 3 hours'),
 (1, 'partida_domino', 10, now() - INTERVAL '26 days 9 hours'),
 (5, 'partida_domino', 40, now() - INTERVAL '26 days 9 hours'),
 (4, 'partida_domino', 40, now() - INTERVAL '6 hours'),
 (11, 'partida_domino', 10, now() - INTERVAL '6 hours'),
 (12, 'partida_domino', 10, now() - INTERVAL '4 days 8 hours'),
 (11, 'partida_domino', 40, now() - INTERVAL '4 days 8 hours'),
 (9, 'partida_domino', 40, now() - INTERVAL '15 days 7 hours'),
 (5, 'partida_domino', 10, now() - INTERVAL '15 days 7 hours'),
 (8, 'partida_domino', 10, now() - INTERVAL '21 days 8 hours'),
 (10, 'partida_domino', 40, now() - INTERVAL '21 days 8 hours'),
 (6, 'partida_domino', 40, now() - INTERVAL '10 days 8 hours'),
 (2, 'partida_domino', 10, now() - INTERVAL '10 days 8 hours'),
 (1, 'partida_domino', 40, now() - INTERVAL '10 days 3 hours'),
 (11, 'partida_domino', 10, now() - INTERVAL '10 days 3 hours'),
 (12, 'partida_domino', 10, now() - INTERVAL '1 days 3 hours'),
 (10, 'partida_domino', 40, now() - INTERVAL '1 days 3 hours'),
 (10, 'partida_domino', 40, now() - INTERVAL '9 hours'),
 (12, 'partida_domino', 10, now() - INTERVAL '9 hours'),
 (12, 'partida_domino', 10, now() - INTERVAL '25 days 1 hours'),
 (2, 'partida_domino', 40, now() - INTERVAL '25 days 1 hours'),
 (5, 'partida_domino', 40, now() - INTERVAL '27 days 4 hours'),
 (4, 'partida_domino', 10, now() - INTERVAL '24 days 4 hours'),
 (6, 'partida_domino', 40, now() - INTERVAL '24 days 4 hours'),
 (2, 'partida_domino', 10, now() - INTERVAL '25 days 7 hours'),
 (9, 'partida_domino', 40, now() - INTERVAL '25 days 7 hours'),
 (6, 'partida_domino', 10, now() - INTERVAL '3 days 9 hours'),
 (11, 'partida_domino', 40, now() - INTERVAL '3 days 9 hours'),
 (2, 'partida_domino', 40, now() - INTERVAL '26 days 1 hours'),
 (5, 'partida_domino', 10, now() - INTERVAL '26 days 1 hours'),
 (11, 'partida_domino', 10, now() - INTERVAL '28 days 1 hours'),
 (9, 'partida_domino', 40, now() - INTERVAL '28 days 1 hours'),
 (8, 'partida_domino', 40, now() - INTERVAL '15 days 7 hours'),
 (1, 'partida_domino', 10, now() - INTERVAL '15 days 7 hours'),
 (4, 'partida_domino', 10, now() - INTERVAL '25 days 6 hours'),
 (2, 'partida_domino', 40, now() - INTERVAL '25 days 6 hours'),
 (12, 'partida_domino', 10, now() - INTERVAL '26 days 7 hours'),
 (1, 'partida_domino', 40, now() - INTERVAL '26 days 7 hours'),
 (6, 'partida_domino', 10, now() - INTERVAL '15 days 2 hours'),
 (5, 'partida_domino', 40, now() - INTERVAL '15 days 2 hours'),
 (5, 'partida_domino', 10, now() - INTERVAL '1 hours'),
 (2, 'partida_domino', 40, now() - INTERVAL '1 hours'),
 (11, 'partida_domino', 10, now() - INTERVAL '15 days 3 hours'),
 (4, 'partida_domino', 40, now() - INTERVAL '15 days 3 hours'),
 (5, 'partida_jogo', 10, now() - INTERVAL '26 days 2 hours'),
 (10, 'partida_jogo', 30, now() - INTERVAL '5 hours'),
 (1, 'partida_jogo', 30, now() - INTERVAL '26 days 4 hours'),
 (10, 'partida_jogo', 30, now() - INTERVAL '10 days 2 hours'),
 (2, 'partida_jogo', 30, now() - INTERVAL '24 days 5 hours'),
 (10, 'partida_jogo', 30, now() - INTERVAL '6 days 2 hours'),
 (2, 'partida_jogo', 30, now() - INTERVAL '19 days 9 hours'),
 (2, 'partida_jogo', 30, now() - INTERVAL '23 days 6 hours'),
 (2, 'partida_jogo', 30, now() - INTERVAL '26 days 2 hours'),
 (10, 'partida_jogo', 30, now() - INTERVAL '14 days 9 hours'),
 (2, 'partida_jogo', 30, now() - INTERVAL '18 days 10 hours'),
 (10, 'partida_jogo', 30, now() - INTERVAL '18 days 8 hours'),
 (8, 'partida_jogo', 30, now() - INTERVAL '1 hours'),
 (8, 'partida_jogo', 30, now() - INTERVAL '16 days 10 hours'),
 (9, 'partida_jogo', 30, now() - INTERVAL '26 days 2 hours'),
 (3, 'partida_jogo', 30, now() - INTERVAL '29 days 6 hours'),
 (8, 'partida_jogo', 30, now() - INTERVAL '1 hours'),
 (9, 'partida_jogo', 30, now() - INTERVAL '22 days 1 hours'),
 (4, 'partida_jogo', 30, now() - INTERVAL '3 days 7 hours'),
 (9, 'partida_jogo', 30, now() - INTERVAL '7 days 5 hours'),
 (4, 'partida_jogo', 30, now() - INTERVAL '5 days 3 hours'),
 (1, 'partida_jogo', 30, now() - INTERVAL '21 days 9 hours'),
 (8, 'partida_jogo', 30, now() - INTERVAL '22 days 10 hours'),
 (9, 'partida_jogo', 30, now() - INTERVAL '13 days 5 hours'),
 (10, 'partida_jogo', 10, now() - INTERVAL '10 hours'),
 (9, 'partida_jogo', 30, now() - INTERVAL '3 hours'),
 (1, 'partida_jogo', 30, now() - INTERVAL '16 days 4 hours'),
 (12, 'partida_jogo', 30, now() - INTERVAL '5 days 2 hours'),
 (10, 'partida_jogo', 30, now() - INTERVAL '26 days 7 hours'),
 (5, 'partida_jogo', 30, now() - INTERVAL '10 days 4 hours'),
 (8, 'partida_jogo', 30, now() - INTERVAL '17 days 7 hours'),
 (2, 'partida_jogo', 30, now() - INTERVAL '11 days 1 hours'),
 (4, 'partida_jogo', 30, now() - INTERVAL '19 days 9 hours'),
 (11, 'partida_jogo', 30, now() - INTERVAL '1 days 9 hours');

-- ============================================================
-- Conferência: aborta a carga se alguma tabela ficar com < 30 tuplas
-- ============================================================
DO $$
DECLARE t text; n bigint;
BEGIN
    FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY 1 LOOP
        EXECUTE format('SELECT count(*) FROM %I', t) INTO n;
        IF n < 30 THEN
            RAISE EXCEPTION 'Tabela % ficou com apenas % tuplas', t, n;
        END IF;
    END LOOP;
END $$;

COMMIT;
