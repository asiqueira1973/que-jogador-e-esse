# Documentação técnica — Que Jogador É Esse?

Gerado ao fim da implementação do MVP, conforme exige a seção 19 do [`docs/spec.md`](docs/spec.md).
Tudo aqui descreve **o que foi realmente implementado**, não o que estava planejado.

Estado: MVP implementado e verificado contra o emulador do Firebase e o simulador de Apple TV.
O que **não** pôde ser verificado por código está listado em [7. Pendências](#7-pendências-que-só-você-pode-fechar).

---

## 1. A árvore de dados do Firebase, em linguagem de negócio

O banco tem exatamente três raízes. Duas são descartáveis, uma é permanente.

### `salas/{codigo_sala}` — a partida acontecendo agora

É o único objeto com identidade no produto. Nasce quando alguém abre o app na Apple TV e morre
quando o anfitrião encerra. O código curto (ex.: `4K7Q`) é a chave de acesso: quem sabe o código,
entra. Não existe conta, senha nem dono.

| Nó | O que significa no jogo |
|---|---|
| `estado` | Em que momento a partida está: esperando gente, rodada rolando, jogador revelado, ou acabou. É isso que decide qual tela cada aparelho mostra. |
| `criado_em` | Quando a sala foi aberta. Serve para a faxina das salas velhas. |
| `jogador_futebol_atual_id` | Qual jogador de futebol está sendo adivinhado agora. Aponta para `jogadores_futebol/`. |
| `pista_atual_index` | Quantas pistas já saíram (0 = primeira). **É esse número que define quantos pontos a rodada vale.** |
| `rodada_numero` | Quantas rodadas já começaram nesta sessão. Aparece na TV como "RODADA 3". |
| `buzz_atual` | Quem apertou "EU SEI!" primeiro e ainda não foi julgado. Enquanto existir, o botão de todo mundo fica bloqueado. Vazio = pista em disputa. |
| `tentativas_bloqueadas` | Quem já errou **este** jogador de futebol e não pode tentar de novo até o próximo sorteio. |
| `jogadores_futebol_usados` | Quais jogadores de futebol já caíram nesta sessão, para nenhum se repetir. |
| `ultima_rodada` | O resultado da rodada que acabou: quem ganhou, quantos pontos, com quantas pistas. Alimenta a tela de revelação. |
| `jogadores/{jogador_sala_id}` | Um convidado: apelido, pontos acumulados, quando entrou e se ainda está conectado. |

### `rodadas_historico/{codigo_sala}/{rodada_id}` — o extrato da partida

Uma linha por rodada encerrada: qual jogador era, quantas pistas foram, quem acertou e quanto
ganhou. Não é lido por nenhuma tela do MVP — existe para conferência e para uma futura análise.
Também é efêmero: some junto com a sala na faxina.

### `jogadores_futebol/{id}` — o banco de conteúdo

Conteúdo permanente, curado **antes** do lançamento e importado por fora do app. Nenhum cliente
escreve aqui: as regras do banco proíbem. Cada registro tem nome completo para a revelação,
posição, clube, Copas disputadas, dificuldade, a lista ordenada de pistas (da mais difícil para a
mais fácil) e a URL da ilustração.

---

## 2. O fluxo de estados da sala

```
                      app tvOS abre
                            │
                            ▼
                   ┌─────────────────┐
                   │   aguardando    │◄──── convidados entram pelo celular
                   └────────┬────────┘      (a TV lista em tempo real)
                            │
              anfitrião aperta INICIAR JOGO
              · sorteia jogador não usado
              · ZERA tentativas_bloqueadas ◄── a pegadinha do projeto
              · pista_atual_index = 0
                            │
                            ▼
    ┌──────────────► ┌─────────────────┐
    │                │  rodada_ativa   │
    │                └────────┬────────┘
    │                         │
    │          ┌──────────────┼───────────────┐
    │          │              │               │
    │   ninguém compra   alguém compra    (nada muda)
    │   por 20 segundos  (buzz_atual)
    │          │              │
    │          │       anfitrião julga
    │          │        ┌─────┴─────┐
    │          │        │           │
    │          │     ERROU       ACERTOU
    │          │        │           │
    │          │  bloqueia quem     │
    │          │  errou e libera    │
    │          │  a próxima pista   │
    │          │        │           │
    │          └────────┤           │
    │                   │           │
    │           ainda há pista?     │
    │            sim │   │ não      │
    │                │   │          │
    └────────────────┘   └────┬─────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │    revelado     │  TV mostra quem era o jogador
                    └────────┬────────┘  (+X pts para quem acertou, ou 0 pts)
                             │
                  anfitrião aperta VER PLACAR
                             │
                    ┌────────┴────────┐
                    │                 │
            PRÓXIMA RODADA      ENCERRAR JOGO
                    │                 │
                    │                 ▼
                    │        ┌─────────────────┐
                    │        │    encerrada    │  TV: placar final
                    │        └─────────────────┘  celulares: "jogo encerrado"
                    │
                    └──────► volta para rodada_ativa
```

Uma observação sobre o **placar**: ele não é um estado do banco. Enquanto a sala está `revelado`,
a TV tem um sub-estado só visual (`RoomEngine.Stage.scoreboard`) que troca a revelação pelo
ranking. Isso foi de propósito: o celular do convidado não precisa mudar de tela por causa disso,
e assim o modelo de dados da seção 7 não ganha um campo que só interessa ao palco.

---

## 3. Onde cada regra da seção 11 vive no código

| Regra da seção 11 | Arquivo | Função / símbolo |
|---|---|---|
| **Pontos por pista até o acerto** — 100 · 80 · 60 · 40 · 20 | [`GameRules.swift`](tvos-app/Sources/Shared/GameRules/GameRules.swift) | `GameRules.pointsTable`, `GameRules.pointsFromFifthClueOn`, `GameRules.points(forClueIndex:)` |
| Atribuição desses pontos ao acertar | [`RoomEngine.swift`](tvos-app/Sources/Shared/GameRules/RoomEngine.swift) | `RoomEngine.confirmCorrectAnswer()` → `FirebaseClient.addPoints(code:roomPlayerID:points:)` |
| Exibição do valor da pista na TV | [`ClueView.swift`](tvos-app/Sources/Features/Pista/ClueView.swift) | `ClueView.header` via `RoomEngine.pointsForCurrentClue` |
| Exibição do valor no celular | [`app.js`](pwa-convidado/app.js) | `pointsForClue(index)` — **só exibe**; quem credita é a TV |
| **Jogador que erra fica bloqueado** (só para o jogador de futebol atual) | `RoomEngine.swift` | `RoomEngine.confirmWrongAnswer()` grava `tentativas_bloqueadas/{id}` |
| Predicado puro do bloqueio | `GameRules.swift` | `GameRules.canBuzz(roomPlayerID:blockedAttempts:)` |
| **Reset do bloqueio a cada novo sorteio** (a pegadinha) | `RoomEngine.swift` | `RoomEngine.startRound()` — a linha `Keys.blockedAttempts: nil` |
| Reação do celular ao bloqueio | `app.js` | `blockReason()` |
| **Empate no buzz-in** — primeira escrita aceita vence | `app.js` | `buzzIn()` com `runTransaction` |
| Mesma regra reforçada no servidor | [`database.rules.json`](firebase/database.rules.json) | `.validate` de `salas/$codigo_sala/buzz_atual/jogador_sala_id` |
| **Jogador não repetido na mesma sessão** | `GameRules.swift` | `GameRules.drawNextPlayer(from:alreadyUsed:randomIndex:)` |
| Registro do que já saiu | `RoomEngine.swift` | `RoomEngine.startRound()` grava `jogadores_futebol_usados/{id}` |
| **Ninguém acerta depois de todas as pistas** — 0 pontos, revela mesmo assim | `RoomEngine.swift` | `RoomEngine.finishRoundWithoutWinner()` + `GameRules.pointsWhenNobodyAnswers` |
| Fim das pistas | `GameRules.swift` | `GameRules.nextClueIndex(after:totalClues:)` |
| **Nenhum mínimo de jogadores para iniciar** | `GameRules.swift` / [`RoomView.swift`](tvos-app/Sources/Features/Sala/RoomView.swift) | `GameRules.minimumPlayersToStart = 0`; o botão `startButton` nunca desabilita |
| Sem teto de jogadores por sala (decisão 25.3) | `GameRules.swift` | `GameRules.maximumPlayersPerRoom = nil` |

Onde os valores são **conferidos automaticamente**:
`tvos-app/Tests/main.swift` (tabela e predicados puros) e
`tools/EngineHarness/Sources/EngineHarness/main.swift` (as mesmas regras contra o banco real).

---

## 4. Mapa tela → nós do Firebase

A tabela da seção 10 do spec, atualizada com o que o código realmente lê e escreve.

### Anfitrião (tvOS)

| Tela | Arquivo | Lê | Escreve |
|---|---|---|---|
| Abertura ("abrindo a sala…") | [`App.swift`](tvos-app/Sources/App.swift) | `jogadores_futebol/` (uma vez por sessão) | cria `salas/{codigo}` com `estado`, `criado_em`, `pista_atual_index`, `rodada_numero` |
| Sala | `RoomView.swift` | `salas/{codigo}` (listener); o QR code é gerado localmente, sem rede | ao iniciar: `estado`, `jogador_futebol_atual_id`, `pista_atual_index`, `rodada_numero`, `buzz_atual`=null, `tentativas_bloqueadas`=null, `ultima_rodada`=null, `jogadores_futebol_usados/{id}` |
| Pista | `ClueView.swift` | `salas/{codigo}`, `jogadores_futebol/{id}` | avanço automático: `pista_atual_index`, `buzz_atual`=null · erro: `tentativas_bloqueadas/{id}` · acerto: `jogadores/{id}/pontos`, `estado`, `ultima_rodada`, `rodadas_historico/{codigo}/{rodada_id}` |
| Revelação | `RevealView.swift` | `jogadores_futebol/{id}` (inclusive `imagem_url`), `salas/{codigo}/ultima_rodada`, `salas/{codigo}/jogadores` | — (só lê) |
| Placar | `ScoreboardView.swift` | `salas/{codigo}/jogadores` | ao encerrar: `estado`="encerrada", `buzz_atual`=null |

### Convidado (PWA)

| Tela | Lê | Escreve |
|---|---|---|
| Entrada | `salas/{codigo}` (existe? está encerrada?) | `salas/{codigo}/jogadores/{novo_id}` com `apelido`, `pontos`, `conectado_em`, `ativo` |
| Espera | `salas/{codigo}` (listener) | `jogadores/{meu_id}/ativo` (ao voltar do segundo plano) |
| Jogo | `salas/{codigo}` (listener) | `salas/{codigo}/buzz_atual` **por transação** |
| Fim de jogo | `salas/{codigo}/jogadores/{meu_id}/pontos` | — |
| (qualquer tela, ao cair a conexão) | — | `jogadores/{meu_id}/ativo` = false, via `onDisconnect` |

Toda a TV vive de **um único listener** em `salas/{codigo}`. É isso que faz o convidado aparecer
na lista e o botão travar dentro dos limites de tempo da seção 8 — medido em 0,00 s para a lista e
0,38 s para o bloqueio do botão.

---

## 5. A lógica de cada tela, por ação principal

### Anfitrião — Sala
**Ação: abrir o app.** Gera um código de 4 caracteres num alfabeto sem `0/O/1/I` (o código é lido
a 3 metros e digitado num celular), confere que ele está livre no banco, cria a sala e assina o
listener. A tela aparece assim que o código existe; o banco de conteúdo continua carregando
atrás — é o que mantém a criação dentro dos 2 segundos.
A tela mostra um **QR code** ao lado do código. Ele leva `https://<host>/?sala=XXXX` — ou seja, já
carrega o código da sala, e quem escaneia cai na PWA precisando digitar só o apelido. É gerado na
própria Apple TV pelo CoreImage: nenhum serviço externo, nada que dependa de rede no meio da festa.
Quem preferir digitar continua tendo o endereço e o código em letra grande.
**Ação: INICIAR JOGO.** Sorteia um jogador ainda não usado, zera `tentativas_bloqueadas`, volta
para a pista 1 e conta mais uma rodada — tudo numa escrita só, para os celulares nunca verem um
estado pela metade. Com zero convidados o botão continua ativo e vira "INICIAR MESMO ASSIM".

### Anfitrião — Pista
A ilustração vem de `jogadores_futebol/{id}/imagem_url` (URL pública no Cloud Storage) e é
carregada sob demanda. O borrão é aplicado sobre a imagem inteira e vai abrindo a cada pista; quem
ainda não tem arte cai num marcador "?" que borra igual, sem quebrar o layout.

**Ação: nenhuma (o tempo passa).** A cada 20 segundos sem ninguém comprar, a pista seguinte é
liberada sozinha. Acabaram as pistas, a rodada termina sem vencedor. O relógio para no instante em
que alguém compra: ninguém perde pista enquanto o anfitrião julga.
**Ação: ACERTOU.** Lê `pista_atual_index`, converte em pontos pela tabela da seção 11, credita por
transação (para não perder pontos de escritas concorrentes), grava o resultado em `ultima_rodada`,
registra a rodada no histórico e leva a sala para `revelado`.
**Ação: ERROU.** Marca quem errou em `tentativas_bloqueadas`, limpa o buzz e libera a próxima
pista. Se não havia próxima, encerra a rodada sem vencedor.

### Anfitrião — Revelação
**Ação: nenhuma.** Só lê. Mostra nome completo, clube, Copas e o resultado que a tela de pista já
calculou — esta tela nunca recalcula ponto nenhum. Verde e "A RESPOSTA É" quando alguém acertou;
vermelho e "A RESPOSTA ERA" quando ninguém acertou.
**Ação: VER PLACAR.** Troca o sub-estado visual da TV. Não escreve no banco.

### Anfitrião — Placar
**Ação: PRÓXIMA RODADA.** Mesmo caminho do INICIAR JOGO.
**Ação: ENCERRAR JOGO.** Marca `estado: "encerrada"`. É só isso — e é o que faz todos os celulares
caírem na tela de "jogo encerrado" ao mesmo tempo, porque eles escutam o mesmo nó.

### Convidado — Entrada
**Ação: ENTRAR.** Valida o formato do código na hora, confere no banco se a sala existe e não está
encerrada e, aí sim, cria o registro do convidado com um id gerado no próprio celular. Código
errado mostra a mensagem no lugar, sem recarregar a página, e o botão vira "TENTAR DE NOVO".
**Ao abrir a página**, se houver uma sessão guardada no navegador, o convidado volta direto para o
jogo como o mesmo jogador, com os pontos intactos.

### Convidado — Espera
**Ação: nenhuma.** Lista quem já está na sala em tempo real, marcando "VOCÊ".

### Convidado — Jogo
**Ação: EU SEI!** Uma transação tenta ocupar `buzz_atual`; se já houver alguém lá, ela aborta. Dois
toques simultâneos sempre resolvem para um vencedor só — e, mesmo que o cliente tentasse forçar,
a regra do servidor recusa a sobrescrita.
**Estado bloqueado.** O botão desliga por três motivos diferentes, e a mensagem diz qual:
outra pessoa comprou, você comprou e está respondendo, ou você já errou nesta rodada.

### Convidado — Fim de jogo
**Ação: ENTRAR EM OUTRA SALA.** Limpa a sessão local e volta para a tela de entrada.

---

## 6. Divergências em relação ao spec

Nenhuma divergência é acidental — cada uma tem um motivo abaixo.

### Decisões que você tomou nesta sessão (perguntas abertas da seção 25)

1. **Identidade visual (25.1)** — adotada a direção do canvas *"Perfil FC — Telas do jogo"*: fundo
   índigo, amarelo de holofote como cor de marca, verde para acerto, vermelho para bloqueio,
   tipografia Anton + Barlow + Barlow Condensed. As fontes estão embutidas no app e servidas pela
   própria PWA (nenhuma chamada ao Google Fonts em tempo de jogo).
2. **Reconexão do convidado (25.2)** — o spec (seção 9) dizia que quem cai volta como jogador novo
   e perde os pontos. Implementado o contrário: o `jogador_sala_id` fica no `localStorage` e o
   convidado volta ao mesmo registro. **Não muda o modelo de dados da seção 7**, só a PWA.
3. **Teto de jogadores por sala (25.3)** — não há teto, como o spec já não definia. Está explícito
   no código como `GameRules.maximumPlayersPerRoom = nil`, para não parecer esquecimento.
4. **Placar entre sessões (25.4)** — mantido fora do MVP; a pontuação vive e morre com a sala.

### Modelagem acrescentada à seção 7

O próprio spec, na seção 11, mandava acrescentar o campo de bloqueio ao modelo de dados. Ao fazer
isso ficou claro que faltavam outros três. **O `docs/spec.md` foi atualizado** com a árvore
completa; os campos novos são:

| Campo | Por quê |
|---|---|
| `tentativas_bloqueadas` | Exigido pela regra de bloqueio da seção 11. Modelado como **mapa `{id: true}`, não array** — a seção 11 sugeria array ("ex.:"), mas array no Realtime Database não suporta escrita concorrente sem corrida, nem regra de validação por item. |
| `rodada_numero` | A TV e o celular mostram "RODADA 3"; sem o campo, cada aparelho contaria por conta própria. |
| `jogadores_futebol_usados` | Regra de "não repetir na mesma sessão". Ficar só na memória do app quebraria se a TV reiniciasse no meio da partida. |
| `ultima_rodada` | A tela de revelação precisa saber quem ganhou e quanto; sem isso ela teria que recalcular os pontos, e regra de negócio duplicada é regra que diverge. |

### Valores que o spec não define

5. **Duração da pista: 20 segundos.** A seção 5 diz que avançar pista é "automático por regra, sem
   toque", mas a tabela da seção 11 **não dá a duração**. Esse é o **único número do jogo que foi
   arbitrado na implementação**. Está isolado em `RoomEngine.secondsPerClue` — mudar é uma linha.
   Se você quiser outro valor (ou um valor por dificuldade), é só dizer.
6. **Código de sala com 4 caracteres.** A seção 6 permite 4 ou 5; o canvas usa 4 e a mensagem de
   erro da PWA diz "são 4 caracteres". O alfabeto exclui `0`, `O`, `1` e `I`, que se confundem a
   3 metros de distância.

### Onde o canvas de design e o spec discordavam

7. O canvas mostra **"VALE 30 PTS"** na terceira pista e marca "regra de pontos por pista" como *a
   definir*. Prevaleceu a tabela da seção 11: a terceira pista vale **60**. O canvas também desenha
   sempre 5 marcadores de pista; a TV desenha um por pista que o jogador realmente tem.
8. **Uma tela a mais no celular**, não prevista no canvas: enquanto a sala está `revelado`, o
   convidado vê "Rodada encerrada. Olhe para a TV." em vez de um botão morto sem explicação.

### Convenções

9. **Código, funções e nomes de arquivo em inglês; comentários em português; chaves do Firebase em
   português `snake_case`** — conforme a seção 18. As pastas de features ficaram em português
   (`Features/Sala`, `Features/Pista`, …) porque a própria seção 18 as nomeia assim.
10. **Ids de HTML e classes de CSS ficaram em português** (`tela-espera`, `botao-buzz`). A seção 18
    fala de "variáveis, funções e arquivos"; ids e classes são marcação, e espelham a interface,
    que é em português. Decisão consciente, não descuido.

### Conteúdo em produção (apurado em 04/09/2026)

O banco real tem **399 jogadores, todos com 4 pistas e todos com ilustração**. O conteúdo é
produzido por outro fluxo (chat de curadoria + n8n), não por este repositório. Três coisas do
conteúdo divergem do spec e afetam o que aparece na TV:

15. **`posicao` fora do enum da seção 7 em 88 registros**: 84 com `"defensor"` e 4 com `"meias"`.
    O app não quebra (o campo é opcional e vira `nil`), mas o texto da pista diz "Atuou como
    defensor", que não é uma das cinco posições que o spec fixou. `meias` → `meio-campista` é
    mecânico; `defensor` exige decidir entre zagueiro e lateral.
16. **A ordem das pistas está invertida no fim.** A seção 7 exige "da mais difícil pra mais fácil",
    e a tabela da seção 11 paga mais por acertar cedo. Hoje a pista 3 ("Joga atualmente pelo
    Santos", 60 pts) é bem mais reveladora que a pista 4 (40 pts). Ou seja: **a pista que vale
    menos ajuda menos**, o que inverte o sentido do placar.
17. **291 das 399 pistas finais vazam metadado interno**: o texto é "Nivel de dificuldade sugerido
    para esse jogador: medio". Isso não é pista — é campo de pipeline aparecendo em letra gigante
    na TV. Além disso, 794 das 1.596 pistas estão **sem acentuação** ("Nao", "Selecao", "Nivel"),
    o que fica visível a 3 metros.

Nada disso é código: são três ajustes no gerador de pistas. Ficam registrados aqui porque foram
encontrados ao rodar o app contra o conteúdo real.

18. **`posicao_inferida: true` em 44 registros** e ids com underscore (`a_barreal`) são campos e
    convenções que vieram do fluxo de conteúdo. O modelo do app ignora campos que não conhece, e o
    esquema de id está **travado** — as ~399 imagens estão nomeadas `jogadores/{id}.png`, então
    mudar o id quebraria todas.
19. **As ilustrações saem do `gpt-image-1` (OpenAI)**, não do Nano Banana / Gemini como diz a
    seção 4 do spec. O resultado cumpre a mitigação da seção 20 (sem traços faciais).

### Adição fora do spec, aprovada pelo Alexandre

20. **QR code na tela de sala.** Não está no spec nem no canvas de design. Foi acrescentado porque
    a seção 2 aponta a entrada na sala como "o momento mais difícil de uso" e a seção 8.2 exige
    entrar jogando em menos de 15 segundos — digitar `que-jogador-e-esse.web.app` num celular
    briga direto com isso, ainda mais com criança. O QR não substitui nada: o endereço e o código
    continuam na tela para quem preferir digitar, e o formulário da PWA segue com os mesmos dois
    campos que a seção 8.2 manda. Verificado decodificando o QR a partir do screenshot da TV.

### Arquitetura

11. **A PWA usa o SDK do Firebase**, empacotado localmente em `pwa-convidado/vendor/firebase.js`
    (193 KB, 51 KB comprimido). A seção 4 pede "JS vanilla, sem framework" — não há framework de
    interface, mas o SDK é uma dependência real. Ele foi escolhido porque a regra de empate da
    seção 11 pede explicitamente uma **transação do Realtime Database**, e o SDK também cuida de
    reconexão e `onDisconnect`. Está auto-hospedado para não depender de CDN no meio da festa.
12. **A faxina de salas encerradas é um script manual** (`npm run salas:limpar`), não uma Cloud
    Function agendada como a seção 7 sugeria. Foi escrita assim porque a seção 4 fixa o plano
    Spark — mas o projeto real **está no plano Blaze**, então a Function agendada passou a ser
    possível. O script continua servindo e roda por cron; migrar para Function é opcional.
13. **Firebase sem `GoogleService-Info.plist` e sem `apiKey`.** O app é configurado por código a
    partir de `Resources/FirebaseConfig.plist`. Verificado contra o projeto real: o Realtime
    Database **sem autenticação não usa a `apiKey`** — basta o `databaseURL` e um `googleAppID`
    bem formado (o SDK valida o formato `1:<número do projeto>:ios:<hash>` e derruba o app se não
    bater). Trocar de ambiente é mudar a chave `USAR_EMULADOR` no plist, sem recompilar.

### Uma correção de segurança que os testes pegaram

14. A regra de "quem chega primeiro vence" **não estava valendo no servidor** na primeira versão
    das regras: no Realtime Database, permissão de escrita concedida num nó pai **não pode ser
    revogada** num nó filho — só `.validate` restringe. Corrigido: hoje
    `buzz_atual/jogador_sala_id` só aceita escrita se ainda não existir, e há teste automatizado
    provando que uma sobrescrita direta é recusada.

---

## 7. Situação na App Store

**Submetido para revisão em 04/09/2026** — versão 1.0, build 1, estado *Waiting for Review*.
App Store Connect ID 6808813011, bundle `com.dablab.quejogadoreesse`.

O caminho até aqui teve dois obstáculos que valem ficar registrados, porque não são óbvios e vão
se repetir na próxima versão:

1. **Assinatura automática não funciona para arquivar este app.** O Xcode provisiona um perfil de
   *Development* mesmo arquivando em Release, e perfil de Development exige um aparelho registrado
   no time — não há Apple TV registrada. A solução é assinatura **manual** com um perfil de App
   Store, que não usa aparelho. Está no `project.yml`, configurável por
   `scripts/configurar-assinatura.py`, que acha o perfil instalado sozinho.
2. **O portal da Apple tem duas opções de App Store parecidas.** "App Store Connect" gera perfil
   de iOS/visionOS/watchOS; a variante com **tvOS** no nome é outra entrada da mesma lista. O
   script hoje recusa perfil sem `tvOS` na plataforma — antes ele aceitava, e o erro só aparecia
   no archive.

Verificado no dia da submissão, porque é o que o revisor vai encontrar: PWA no ar (0,5 s),
banco com 399 jogadores todos com pistas e ilustração, imagens públicas acessíveis e página de
suporte respondendo.

---

## 8. Pendências que só você pode fechar

Do Definition of Done (seção 26), estes itens **não são verificáveis por código** e continuam em
aberto:

- [x] **14 nomes abreviados** — decisão do Alexandre: ficam como estão. No futebol brasileiro o
      sobrenome costuma ser o nome pelo qual o jogador é conhecido, então "Á. Barreal" na
      revelação é aceitável. O risco da seção 23 fica registrado como assumido, não resolvido.
- [ ] **88 posições fora do enum da seção 7** (`defensor`, `meias`).
- [ ] **Teste com 3 celulares reais** na mesma rede (seção 26). O buzz-in simultâneo está provado
      com 12 clientes concorrentes contra o emulador, mas isso não substitui o teste físico.
- [ ] **Teste em Wi-Fi doméstico real**, não em rede local de desenvolvimento.
- [x] **Ilustrações.** ~~Pendente~~ — as 399 estão geradas e renderizando no app, com o borrão
      progressivo na tela de pista e a arte nítida na revelação.
- [x] **Regras de segurança publicadas em produção** (04/09/2026, pelo console). Antes disso o
      banco estava aberto: leitura e escrita anônimas na raiz funcionavam. Depois de publicar,
      verificado contra o banco real: leitura do conteúdo continua liberada (o app precisa dela),
      e ficaram bloqueadas a leitura da raiz, a listagem de salas, a escrita anônima na raiz, a
      adulteração de `imagem_url` e a criação de sala com código fora do formato. O fluxo completo
      do jogo foi rodado contra produção depois disso e passou em 24/24.
- [x] **PWA publicada** em `https://que-jogador-e-esse.web.app` (04/09/2026), que é exatamente o
      destino do QR code. Testada contra produção pelo próprio site: entrar pelo link do QR com o
      código já preenchido, comprar a resposta por transação, e cair na tela de fim quando a TV
      encerra. Página carregando em 1,6 s (limite de 3 s da seção 17).
- [x] **App tvOS apontado para produção** (`USAR_EMULADOR: false`). Verificado no simulador: o app
      criou uma sala real, um convidado entrou e apareceu na lista, e o QR code gerado apontava
      para o site publicado com o código certo. A PWA não precisa dessa chave — ela decide sozinha
      pelo endereço de onde foi servida, para não existir um passo manual que um dia sobe quebrado.
- [ ] **Instalar numa Apple TV de verdade.** Não exige publicar na App Store: instala-se direto
      pelo Xcode. Falta apenas **parear a Apple TV** (Ajustes → Controles e Dispositivos → App
      Remoto e Dispositivos, e então Xcode → Window → Devices and Simulators). O time
      `XGZW6Y6K25` ainda não tem nenhum aparelho tvOS registrado, e é isso que impede a Apple de
      emitir o perfil de provisionamento. Assinatura automática já está configurada no
      `project.yml`; depois de parear, o build é `-allowProvisioningUpdates`.
- [x] **Ícone tvOS e Top Shelf** gerados (`scripts/gerar-icones.py` + `scripts/montar-catalogo.py`).
      tvOS exige o ícone em camadas, não um PNG único: a marca é a interrogação com a bola no
      lugar do ponto, sobre o índigo de noite de estádio. Validado pelo Xcode (que rejeita
      estrutura ou tamanho errados) e conferido na tela inicial do simulador.
- [ ] **Qualidade das pistas** — ~~metadado vazando, ordem invertida, acentos~~ **corrigidos em
      04/09/2026** por `scripts/gerar-pistas.mjs`, direto no Firebase de produção, sem tocar em
      `imagem_url`. Se o fluxo de conteúdo regerar pistas por fora, sobrescreve esta correção.
- [ ] **Revisão jurídica** sobre direito de imagem antes de qualquer lançamento público
      (seção 20) — este documento não é aconselhamento jurídico.

---

## 9. Como está verificado hoje

| Suíte | Comando | O que cobre | Resultado |
|---|---|---|---|
| Regras do banco | `npm run test:regras` | Seção 6 e escrita não autorizada fora do escopo da sala | 27/27 |
| Buzz-in concorrente | `npm run test:buzz` | 12 toques simultâneos, 8 rodadas seguidas, 1 vencedor sempre | 3/3 |
| Motor do jogo | `npm run test:motor` | As regras da seção 11 aplicadas ao banco real pelo `RoomEngine` do app | 27/27 |
| Regras puras + modelo | `npm run test:swift` | Tabela de pontos, sorteio, bloqueio, leitura da árvore | 30/30 |
| Conteúdo | `npm run seed:validar` | Schema da seção 7 antes de importar | 256 válidos |
| Leitura de produção | `QJE_USAR_EMULADOR=0 npm run test:motor:producao -- --somente-leitura` | O app lê o banco real pelo mesmo caminho do tvOS | 399 jogadores, 399 com pistas e ilustração |
| Jogo em produção | `npm run test:motor:producao` | Partida inteira contra o banco real, com as regras publicadas | 24/24, sala criada em 1,44 s |
| PWA em produção | manual, no navegador | Entrar pelo link do QR, comprar a resposta e ser encerrado pela TV, tudo no site publicado | passa, página em 1,6 s |

Verificado à mão, com prova visual: as 7 telas de TV e as 5 de celular do canvas, o app tvOS
rodando no simulador de Apple TV 4K contra o emulador, e o encerramento da sala pela TV derrubando
o celular na tela de fim de jogo.

Medições contra os requisitos da seção 17: sala criada em **0,13 s** (limite 2 s), convidado
aparecendo na TV em **menos de 0,01 s** (limite 1 s), botão bloqueando em **0,38 s** (limite
0,5 s), PWA carregando **64 KB em 9 arquivos** (limite 3 s em Wi-Fi doméstico).
