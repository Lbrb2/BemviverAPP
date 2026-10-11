# Motor do Buraco — pronto e testado (falta a interface)

Estes arquivos são o MOTOR do jogo de buraco 1x1 contra o computador,
já construído e validado. Falta só transformar em tela (componente React).

## Arquivos
- motor.mjs      — baralho (108 cartas), distribuição, validação de jogos
                   (trincas/sequências com curingas), canastras (limpa=200,
                   suja=100) e pontuação. 22 testes passando.
- ia.mjs         — inteligência do computador: planeja canastras, concentra
                   curingas nos jogos maduros, descarta o que não serve.
- testa_motor.mjs — os 22 testes de regras (rode: node testa_motor.mjs)
- simula_final.mjs — simula 300 partidas (rode: node simula_final.mjs)

## Estado validado (300 partidas simuladas)
- 44% das partidas formam ao menos uma canastra
- vitórias equilibradas entre os dois lados (IA justa)
- ~62 rodadas por partida, sempre termina e pontua

## Regras decididas
- Buraco 1x1 contra o computador
- Canastra limpa 200, suja 100 (tradicional)
- Curingas: Joker e o 2
- Compra sempre do monte (pegar o lixo fica para versão futura)

## PRÓXIMO PASSO (próxima sessão)
Transformar em componente React <Buraco> na aba de jogos do app,
ao lado do Dominó e do Jogo da Memória. Interface acessível:
cartas grandes, tocar para selecionar, botões "Baixar jogo",
"Descartar", "Comprar". Alimentar o Xodó e registrar a partida
via POST /partidas (motivo: "buraco"), como os outros jogos.
