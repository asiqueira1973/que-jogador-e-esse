---
Documento: spec.md
Produto: Que Jogador É Esse?
Versão: 1.0
Responsável de produto: Alexandre Siqueira
Status: rascunho
Data: 2026-09-03
---

# Que Jogador É Esse? — Jogo de festa para Apple TV (MVP: Perfil de Jogador de Futebol)

## Como usar este documento

Este é o `spec.md` — a fonte única de verdade deste produto. Um agente de código (Claude Code) deve implementar a partir dele sem inventar decisões de arquitetura, modelagem ou regra de negócio. Antes de gerar qualquer código, revise a **seção 24 (Assunções declaradas)** — cada assunção não corrigida vira verdade definitiva no momento em que a implementação começa. A **seção 25 (Perguntas abertas)** lista o que só Alexandre pode decidir; o agente deve perguntar em vez de assumir sempre que cruzar com um item dela.

---

### 0. Princípios não-negociáveis

1. **Ninguém instala nada além do anfitrião.** Os convidados jogam pelo navegador do próprio celular, sem app, sem conta, sem cadastro. Qualquer decisão de UX que exija instalação para um convidado está errada.
2. **O controle remoto da Apple TV nunca é usado para jogar.** Toda interação de jogador (responder, votar, comprar pista) acontece no celular. O Siri Remote só serve para o anfitrião navegar menus antes/depois da partida.
3. **A TV é o palco, não o placar.** Toda tela da Apple TV precisa ser visualmente interessante por si só — pistas reveladas, silhueta, tensão do buzz-in — porque é ela que todo mundo está olhando durante o jogo.
4. **Simplicidade antes de complexidade prematura.** O MVP entrega um único modo de jogo (Perfil de Jogador de Futebol) bem feito, não um framework genérico de minijogos. Extensibilidade para outros temas/formatos é desejável na arquitetura, mas não é requisito de entrega do MVP.
5. **Conteúdo real, mas sem risco de imagem.** Jogadores reais, dados factuais, mas nenhuma foto real de atleta — apenas ilustração estilizada (ver seção 20).

---

### 1. Visão e problema

Um jogo de festa para Apple TV, jogado em família: a TV mostra pistas progressivas sobre um jogador de futebol brasileiro (silhueta, clube, posição, Copas disputadas), e cada pessoa usa o próprio celular como "controle" para tentar adivinhar primeiro, sem precisar instalar nada. Resolve a maior fricção de jogos de festa em Apple TV — a interação pelo Siri Remote é ruim — ao tirar toda a interação do controle remoto e colocar no celular.

**Anti-escopo:** este não é um app de trivia genérico, não é um agregador de conteúdo de terceiros, não depende de licenciamento de mídia (fotos reais, música), e não tem ambição de conta de usuário, ranking online ou monetização no MVP.

---

### 2. Personas e cenários de uso

- **Anfitrião**: dono ou responsável pela Apple TV, geralmente adulto, abre o app e cria a sala. Só ele interage com o Siri Remote.
- **Convidados**: qualquer idade (o público-alvo inclui crianças), jogam pelo navegador do celular. Não podem depender de digitação longa nem de UI complexa — o cenário de uso é uma sala de estar barulhenta, em pé ou sentado, com atenção dividida entre o próprio celular e a TV.

O momento mais difícil de uso é a **entrada na sala**: uma criança ou um convidado menos familiarizado com tecnologia precisa conseguir entrar jogando em menos de 15 segundos, sem ajuda. Isso define a arquitetura de entrada (seção 9.1).

---

### 3. Escopo do MVP

**Dentro do MVP:**
- Um único modo de jogo: Perfil de Jogador de Futebol (pistas progressivas + buzz-in).
- App nativo tvOS (anfitrião) e página web (PWA leve) para convidados.
- Banco de conteúdo pré-curado de jogadores (via pipeline de dados já validado — ver seção 27), carregado no Firebase antes do lançamento, não coletado em tempo real durante o jogo.
- Pontuação por rodada, placar ao vivo, dentro de uma única sessão de jogo (sem persistência entre sessões).
- Sem contas, sem login, sem servidor de aplicação além do Firebase.

**Fora do MVP (com destino):**
| Item | Destino | Motivo / dependência |
|---|---|---|
| Outros temas de Perfil (novela, música, história do Brasil) | Adiado p/ v2 | Depende do motor de conteúdo genérico já estar estável (seção 28) |
| Modo "Imagem & Ação" (desenho no celular) | Adiado p/ v2 | Exige canvas de desenho em tempo real, escopo técnico maior |
| Placar persistente entre sessões / perfis de jogador | Descartado no MVP | Contraria o Princípio 1 (zero fricção de conta) |
| Fotos reais de jogadores | Descartado | Risco de direito de imagem (ver seção 20) |
| Compra de pista com botão de "desistir"/pular jogador | Adiado p/ v2 | Não essencial para validar o formato |
| Multi-sala simultânea no mesmo Apple TV | Descartado | Um Apple TV = uma sala ativa por vez, suficiente para uma casa |

---

### 4. Arquitetura

| Camada | Tecnologia | Por quê | Alternativa descartada |
|---|---|---|---|
| App do anfitrião (tvOS) | Swift + SwiftUI, nativo | FlutterFlow/Glide (stack padrão do Alexandre) não têm suporte a tvOS — confirmado em pesquisa nesta sessão. tvOS exige app nativo. | FlutterFlow (sem suporte a tvOS) |
| App do convidado | PWA (HTML/CSS/JS vanilla, sem framework) | Zero instalação é o Princípio 1; uma página web é a única forma de cumprir isso. | App nativo iOS/Android para convidado (quebra o princípio de zero fricção) |
| Backend / estado em tempo real | Firebase Realtime Database (Spark — free tier) | Modelo de dados é naturalmente uma árvore de documentos efêmeros (sala → jogadores → estado da rodada), sem necessidade de query relacional. RTDB tem latência mais baixa que Firestore para esse padrão de escrita frequente e pequena, e o free tier cobre um MVP de baixo tráfego. | Supabase (Postgres) — descartado para este projeto específico por gerar mais um banco pago a manter, quando o padrão de dados não pede relacional |
| Autenticação | Nenhuma (ver seção 6) | Convidados não têm conta; anfitrião não precisa de conta no MVP. | Firebase Auth anônimo — desnecessário para o escopo atual |
| Geração de imagem (produção de conteúdo, não runtime) | Gemini API — "Nano Banana" (Gemini 2.5/3.1 Flash Image) | Boa consistência visual entre gerações em série, essencial para os ~100+ jogadores do banco de conteúdo terem a mesma linguagem visual. | Ilustração manual (não escala) |
| Coleta de dados de conteúdo (offline, produção) | n8n + Firecrawl → Firebase | Pipeline já validado nesta sessão (3 fontes, dedupe por proximidade de ano). Roda **antes** do lançamento, não em runtime do app. | — |
| Deploy da PWA | Vercel (já no stack padrão do Alexandre) | Reaproveita infraestrutura já usada em outros projetos. | — |

**Premissas técnicas a validar antes de codar:**
- Confirmar limites reais do free tier do Firebase Realtime Database (conexões simultâneas, banda) contra o volume esperado (seção 17) — validado nesta sessão como "provavelmente suficiente para MVP", mas não com números oficiais atualizados.
- Confirmar que o SDK do Firebase para tvOS (via SDK iOS) segue funcionando na versão do Xcode/tvOS que Alexandre for usar no momento da implementação — o suporte foi confirmado nesta sessão, mas pode mudar entre versões do SDK.

---

### 5. Perfis de usuário e matriz de permissões

Não há perfis com permissões diferenciadas de dados no sentido tradicional (não há dado sensível por perfil). A distinção é apenas de **capacidade de interação**:

| Ação | Anfitrião (tvOS) | Convidado (PWA) |
|---|---|---|
| Criar sala | ✅ | ❌ |
| Ver código da sala | ✅ | — (recebe por quem já está na sala, verbalmente) |
| Entrar na sala com código | ❌ (já está nela) | ✅ |
| Avançar pista | ✅ (automático por regra, sem toque — ver 11) | ❌ |
| Buzz-in (responder) | ❌ | ✅ |
| Ver placar | ✅ | ✅ |
| Encerrar sala | ✅ | ❌ |

Não há "criação do primeiro administrador" — não existe conceito de administrador neste produto.

---

### 6. Autenticação e identidade

**Decisão: não há autenticação no MVP.**

- O anfitrião é simplesmente quem abre o app tvOS — nenhum login, nenhuma conta Apple TV vinculada ao produto.
- O convidado se identifica só por um **apelido de exibição** digitado ao entrar na sala (texto livre, sem verificação, sem unicidade forçada — se dois convidados digitarem "João", o sistema distingue por um ID interno gerado na hora, não pelo apelido).
- A sala em si é o único "objeto" com identidade: um código curto (ex.: 4-5 caracteres alfanuméricos, gerado pelo app) que funciona como a chave de acesso.
- Sem recuperação de senha (não existe senha). Sem sessão persistente entre partidas — sair da sala (fechar a aba, ou o anfitrião encerrar) apaga o estado.
- Regras de segurança do Firebase Realtime Database: escrita em `salas/{codigo}/jogadores/{id}` liberada para qualquer cliente que conheça o código da sala (não há como restringir mais sem introduzir conta, o que contraria o Princípio 1). Isso é uma **decisão de trade-off consciente**: qualquer pessoa com o código pode entrar ou escrever na sala — aceitável porque o código é efêmero, curto-prazo, e compartilhado apenas verbalmente dentro de uma sala física.

---

### 7. Modelo de dados

**Nota de convenção:** o backend é Firebase Realtime Database — um banco de documentos em árvore, não relacional. A convenção "banco em português, `snake_case`" desta especificação se aplica aos **nomes de chave** da árvore JSON. Como não há tabelas relacionais, **não é gerado `.dbml`** para este projeto (o `.dbml` é uma ferramenta de ERD relacional; a estrutura de árvore abaixo já é a documentação estrutural completa).

**Árvore de dados (Firebase Realtime Database):**

```
salas/
  {codigo_sala}/                      // ex: "BREJO4"
    estado: "aguardando" | "rodada_ativa" | "revelado" | "encerrada"
    criado_em: timestamp
    jogador_futebol_atual_id: string | null   // aponta para jogadores_futebol/{id}
    pista_atual_index: number         // 0-based, qual pista está revelada agora
    buzz_atual: {                     // quem "comprou" a resposta nesta pista
      jogador_sala_id: string | null
      timestamp: number | null
    } | null
    tentativas_bloqueadas/            // regra da secao 11: quem ja errou o jogador_futebol_atual_id
      {jogador_sala_id}: true         // RESETADO a cada novo jogador_futebol_atual_id sorteado
    rodada_numero: number             // 1-based, quantas rodadas ja comecaram nesta sessao
    jogadores_futebol_usados/         // regra da secao 11: nao repetir jogador na mesma sessao
      {jogador_futebol_id}: true
    ultima_rodada/                    // resultado da rodada recem-encerrada, para a tela de revelacao
      jogador_futebol_id: string
      vencedor_jogador_sala_id: string | null
      pontos_ganhos: number
      pistas_reveladas: number
    jogadores/
      {jogador_sala_id}/              // ID gerado pelo cliente ao entrar
        apelido: string
        pontos: number
        conectado_em: timestamp
        ativo: boolean                // false se desconectou

rodadas_historico/
  {codigo_sala}/
    {rodada_id}/
      jogador_futebol_id: string
      pistas_reveladas: number
      vencedor_jogador_sala_id: string | null   // null = ninguém acertou
      pontos_ganhos: number
      encerrada_em: timestamp

jogadores_futebol/                    // banco de conteúdo, populado ANTES do lançamento
  {id}/
    nome: string
    nome_exibicao: string             // nome completo para a revelação final (curadoria manual resolve abreviações — ver seção 24)
    posicao: string                   // valor normalizado — ver enum abaixo
    clube_atual: string | null
    copas_disputadas: array<string>   // anos, ex: ["2018", "2022"]
    nivel_dificuldade: "facil" | "medio" | "dificil"
    pistas: array<string>             // pistas em ordem de revelação, da mais difícil pra mais fácil
    imagem_url: string                // ilustração estilizada (Nano Banana), não foto real
```

**Enum `posicao` (normalizado na curadoria, ver seção 24):** `goleiro`, `zagueiro`, `lateral`, `meio-campista`, `atacante`.

**Estratégia de exclusão:** não aplicável a `salas/` e `rodadas_historico/` — esses dados são efêmeros por natureza; uma rotina de limpeza (Firebase Function agendada, ou TTL manual) remove salas com `estado: "encerrada"` há mais de 24h. `jogadores_futebol/` é conteúdo permanente, sem exclusão automática.

**Lógica que vive no banco:** nenhuma neste MVP — o Realtime Database não tem triggers/funções nativas equivalentes a Postgres; a lógica de negócio (seção 11) vive inteiramente no app tvOS, que é o único cliente com permissão de avançar o estado do jogo.

**Dados de seed:** o conteúdo de `jogadores_futebol/` é o output do pipeline n8n já validado (seção 27), exportado para JSON e importado via Firebase CLI ou console antes do lançamento — não via app.

---

### 8. Épicos e critérios de aceite

#### 8.1 Criar e exibir sala (tvOS)
Objetivo: o anfitrião abre o app e tem uma sala pronta para receber convidados em poucos segundos.

Fluxo: abrir app → app gera código de sala → tela mostra o código em destaque + instrução curta de como entrar (URL da PWA) → lista de apelidos aparece em tempo real conforme convidados entram.

Critérios de aceite:
- Ao abrir o app, uma sala é criada em até 2 segundos e o código aparece em tela cheia, legível a 3 metros de distância.
- Cada convidado que entra pelo celular aparece na lista da TV em até 1 segundo (latência do Realtime Database).
- O app não trava nem exige nova ação se zero convidados entrarem — o anfitrião pode aguardar indefinidamente na tela de sala.

#### 8.2 Entrar na sala (PWA)
Objetivo: um convidado entra jogando em menos de 15 segundos, sem app.

Fluxo: abre a URL no navegador do celular → digita o código de 4-5 caracteres → digita apelido → toca em "Entrar" → vê tela de espera ("aguardando o jogo começar").

Critérios de aceite:
- Formulário tem exatamente dois campos (código, apelido) — nenhum outro dado é pedido.
- Código inválido mostra mensagem de erro clara sem recarregar a página.
- Depois de entrar, o apelido aparece na TV em até 1 segundo.

#### 8.3 Rodada de jogo — revelação de pistas e buzz-in
Objetivo: o núcleo do jogo — pistas aparecem, jogadores tentam comprar a resposta primeiro.

Fluxo: anfitrião inicia a rodada pelo Siri Remote (único toque de controle do jogo inteiro) → app sorteia um `jogador_futebol` ainda não usado na sessão → primeira pista aparece na TV → celulares mostram um botão grande "EU SEI!" → ao ser tocado, o Realtime Database resolve por transação quem chegou primeiro → TV mostra "Fulano está respondendo" → anfitrião (verbalmente, sem UI) julga certo/errado e usa o Siri Remote para confirmar → se certo, pontos são atribuídos conforme a tabela da seção 11 e a TV revela o jogador; se errado, esse jogador fica bloqueado de comprar de novo nesta rodada e o jogo libera nova pista.

Critérios de aceite:
- O botão "EU SEI!" no celular fica desabilitado assim que qualquer jogador compra a resposta, para todos os outros, em até 500ms.
- Dois toques simultâneos (ou próximos) resolvem de forma determinística para um único vencedor — nunca dois jogadores "ganham" a mesma pista.
- Errar uma resposta bloqueia apenas aquele jogador para aquela pista/jogador_futebol, não para a rodada seguinte.
- Depois de esgotadas todas as pistas sem ninguém acertar, a TV revela o jogador e ninguém pontua.

#### 8.4 Placar e encerramento
Objetivo: mostrar o resultado acumulado e permitir reiniciar.

Fluxo: após cada rodada, TV mostra brevemente o placar atualizado → anfitrião decide (Siri Remote) se inicia nova rodada ou encerra o jogo → ao encerrar, TV mostra o placar final.

Critérios de aceite:
- O placar reflete a soma exata dos pontos de todas as rodadas da sessão, sem depender de recarregar a tela.
- Encerrar a sala remove os dados de `salas/{codigo}` (ou marca `estado: "encerrada"`) e os celulares dos convidados mostram uma tela de "jogo encerrado, obrigado por jogar".

---

### 9. Fluxos principais ponta a ponta

**9.1 Do zero até a primeira pergunta (caminho crítico do produto):**
1. Anfitrião abre o app tvOS → sala criada, código exibido.
2. Convidados, um a um, abrem a URL no celular, digitam código + apelido.
3. Anfitrião aguarda até ter pessoas suficientes (decisão dele, sem mínimo forçado pelo sistema).
4. Anfitrião aperta "Iniciar" no Siri Remote.
5. Primeira pista aparece.

**Caminho de exceção — convidado sem celular ou sem conseguir entrar:** o produto não tem solução para isso no MVP (a pessoa assiste sem jogar) — isso é uma limitação aceita, não um bug; não há modo "assistir sem participar" formalizado, mas também não há nada que bloqueie alguém de simplesmente não interagir.

**Caminho de exceção — convidado perde conexão no meio da rodada:** o app marca `ativo: false` (não remove o registro, para não zerar os pontos já ganhos); se ele voltar a entrar com o mesmo código antes do fim da sessão, precisa digitar o apelido de novo e entra como jogador novo (não há recuperação de sessão no MVP — ver seção 25).

---

### 10. Inventário de telas

**[Anfitrião] Tela de sala (tvOS)** — mostra código, lista de convidados conectados, botão "Iniciar" (Siri Remote). Lê: `salas/{codigo}`. Escreve: cria `salas/{codigo}` ao abrir.

**[Anfitrião] Tela de pista (tvOS)** — mostra a pista atual, avatar/silhueta do jogador (progressivamente menos borrada conforme mais pistas somem), indicador de quem comprou a resposta. Lê: `salas/{codigo}`, `jogadores_futebol/{id}`. Escreve: `salas/{codigo}/pista_atual_index`, `salas/{codigo}/estado`.

**[Anfitrião] Tela de revelação** — mostra nome completo, ilustração, clube e Copas do jogador revelado, pontos ganhos e por quem. Lê: `jogadores_futebol/{id}`, `salas/{codigo}/jogadores`.

**[Anfitrião] Tela de placar** — ranking dos convidados por pontos. Lê: `salas/{codigo}/jogadores`.

**[Convidado] Tela de entrada (PWA)** — campo código + apelido. Escreve: `salas/{codigo}/jogadores/{novo_id}`.

**[Convidado] Tela de espera (PWA)** — "aguardando o jogo começar", mostra os outros convidados já na sala. Lê: `salas/{codigo}`.

**[Convidado] Tela de jogo (PWA)** — botão grande "EU SEI!", desabilitado quando outro já comprou a pista; mostra pontuação própria. Lê/Escreve: `salas/{codigo}/buzz_atual`.

---

### 11. Regras de negócio

| Regra | Valor / condição | Onde se aplica |
|---|---|---|
| Pontos por pista usada até o acerto | 1ª pista: 100 · 2ª: 80 · 3ª: 60 · 4ª: 40 · 5ª ou mais: 20 | App tvOS, ao confirmar acerto |
| Jogador que erra fica bloqueado | Bloqueado de comprar novamente **apenas para aquele `jogador_futebol` da rodada atual** — libera de novo na próxima rodada | App tvOS + regra do Realtime Database (campo `jogadores_ja_tentaram` por rodada, não persistido na árvore acima — **assunção a revisar, ver seção 24**) |
| Empate no buzz-in | Resolvido pela primeira escrita aceita na transação do Realtime Database — sem lógica adicional de desempate por app | Firebase, via transação atômica |
| Jogador não repetido na mesma sessão | Um `jogador_futebol_id` já sorteado não é sorteado de novo até a sala ser encerrada | App tvOS, na hora do sorteio |
| Ninguém acerta depois de todas as pistas | 0 pontos para todos, jogador é revelado mesmo assim | App tvOS |
| Mínimo de jogadores para iniciar | Nenhum mínimo forçado pelo sistema — decisão do anfitrião | — |

O agente de código deve tratar o "bloqueio de tentativa repetida" citado acima como um campo adicional a modelar dentro de `salas/{codigo}` (ex.: `tentativas_bloqueadas: array<jogador_sala_id>`, resetado a cada novo `jogador_futebol_atual_id`) — isso não estava no modelo de dados da seção 7 e precisa ser adicionado lá também, de forma consistente, no momento da implementação.

---

### 16. Direção visual / design system

Referência funcional (não visual): telas de game show de perguntas e respostas — pistas reveladas em sequência, tensão de "quem vai responder primeiro". Nenhuma marca ou produto de referência específico foi definido por Alexandre até o momento deste documento — **decisão em aberto, ver seção 25**. Não é um painel/back-office, então o padrão de menu lateral desta skill **não se aplica**; a navegação da tvOS é sequencial (uma tela por estado do jogo), não um menu.

Cor semântica sugerida (assunção, ver seção 24): verde para "certo"/pontuação, vermelho para "errado"/bloqueado, mantendo neutros (branco/preto/cinza) para o restante — mas sem paleta de marca definida.

---

### 17. Requisitos não-funcionais

- Latência de sincronização entre celular e TV: até 1 segundo, do contrário a mecânica de "buzz-in" perde a graça.
- App tvOS deve abrir e criar a sala em até 2 segundos.
- PWA deve carregar em conexão de Wi-Fi doméstico comum (não banda larga corporativa) em até 3 segundos.
- Sem suporte offline — o produto inteiramente depende de conectividade em tempo real.
- Sem requisito de acessibilidade avançada no MVP (leitor de tela, alto contraste) — registrado como corte consciente, não esquecimento (ver seção 25 se isso precisar mudar).
- Idioma: português (Brasil), único, sem internacionalização no MVP.
- Volume esperado: uma sala ativa por vez, até ~15 jogadores conectados simultaneamente — não é um produto de escala, é uso doméstico.

---

### 18. Convenções de código, documentação e estrutura do repositório

- **Idioma:** chaves da árvore do Firebase em português, `snake_case` (ver seção 7). Código Swift e JavaScript (variáveis, funções, arquivos) em inglês, padrão de mercado.
- **Comentários obrigatórios:** toda função/rotina relevante (cálculo de pontos, transação de buzz-in, sorteio de jogador) leva comentário de cabeçalho em português explicando o que faz e qual regra da seção 11 implementa.
- **Estrutura de pastas sugerida:**
  ```
  /tvos-app          (projeto Xcode, SwiftUI)
    /Features/Sala
    /Features/Pista
    /Features/Revelacao
    /Features/Placar
    /Shared/FirebaseClient
  /pwa-convidado      (HTML/CSS/JS vanilla, deploy Vercel)
  /docs
    spec.md
    DOCUMENTACAO-TECNICA.md
    CLAUDE.md
  ```
- **`CLAUDE.md` na raiz:** convenções acima, mapa de arquitetura (seção 4), comandos de build/deploy, e a pegadinha mais importante do projeto: **o campo `tentativas_bloqueadas` (regra da seção 11) precisa ser resetado a cada novo jogador sorteado, ou o bug trava o jogo silenciosamente**.
- **Variáveis de ambiente:** `FIREBASE_API_KEY`, `FIREBASE_DATABASE_URL` (públicas, como é padrão em apps cliente Firebase — a segurança vem das regras do Realtime Database, não do sigilo dessas chaves).

---

### 19. Documento de documentação técnica

Ao fim da implementação, o agente de código deve gerar `DOCUMENTACAO-TECNICA.md` na raiz, em português, contendo:
1. A árvore de dados do Firebase explicada em linguagem de negócio (o que cada nó representa).
2. O fluxo de estados da sala (`aguardando` → `rodada_ativa` → `revelado` → repete ou `encerrada`) como diagrama em texto.
3. Onde vive cada regra da seção 11 no código (arquivo e função).
4. Mapa tela → nós do Firebase lidos/escritos (a tabela da seção 10, atualizada conforme implementado).
5. Lógica de cada tela por ação principal.
6. Divergências em relação a este spec.

---

### 20. Privacidade, segurança e conformidade

- Dado coletado: apenas o apelido de exibição do convidado, efêmero, apagado ao encerrar a sala. Nenhum dado pessoal identificável, nenhuma conta, nenhum e-mail.
- **Não há dado de menor de idade coletado de forma identificável** — o apelido é livre e não verificado, mas o produto é usado por crianças no contexto familiar; nenhuma informação além do apelido é solicitada, o que mantém o risco baixo.
- **Direito de imagem dos jogadores de futebol (ponto central deste produto):** mesmo ilustração estilizada de um atleta real e reconhecível pode configurar uso de imagem no Brasil, já discutido nesta sessão. Decisão adotada: a ilustração gerada (Nano Banana) usa características físicas genéricas (porte, tom de pele, corte de cabelo, uniforme do clube) em vez de tentar replicar o rosto real — a identificação do jogador vem das pistas textuais e do uniforme/clube, não da semelhança facial. Esta é uma mitigação de risco, não uma eliminação total — **recomenda-se revisão jurídica antes de qualquer lançamento público ou monetização** (este spec não constitui aconselhamento jurídico).
- Chaves do Firebase são públicas por design (client-side); a segurança de escrita depende das regras do Realtime Database (seção 6), que são deliberadamente permissivas dentro do escopo de uma sala — trade-off aceito para um produto sem contas.

---

### 23. Riscos e mitigação

| Risco | Impacto | Probabilidade | Mitigação |
|---|---|---|---|
| Direito de imagem de jogador reconhecível mesmo em ilustração estilizada | Alto (jurídico) | Média | Estilo genérico sem replicar rosto real (seção 20); revisão jurídica antes de lançamento público |
| Latência do Realtime Database em Wi-Fi doméstico ruim quebra a mecânica de buzz-in | Médio (experiência) | Média | Testar em rede doméstica real (não corporativa) antes do lançamento, conforme já identificado na sessão anterior deste projeto |
| Nome abreviado no dado de origem (ex. "K. Viveros") aparece na revelação final, quebrando a graça do "quem é" | Médio (conteúdo) | Alta, se não curado | Curadoria manual do campo `nome_exibicao` antes de publicar cada jogador (seção 24) |
| Homônimos de épocas diferentes tratados como a mesma pessoa | Alto (conteúdo incorreto) | Baixa após correção do pipeline nesta sessão | Pipeline de dedupe já ajustado para clusterizar por proximidade de ano; itens com `revisao_manual: true` exigem checagem humana antes de entrar no banco de conteúdo |
| Free tier do Firebase estourar em uma festa maior que o esperado | Baixo | Baixa | Volume do MVP é doméstico (seção 17); reavaliar se o produto crescer para fora desse uso |

---

### 24. Assunções declaradas

- **Tabela de pontos por pista** (100/80/60/40/20) é uma proposta minha, não validada com Alexandre — fácil de ajustar, só muda a seção 11.
- **Bloqueio de resposta errada só na rodada atual** (não pro jogo inteiro) foi assumido como o comportamento mais divertido — se a intenção era bloquear até o fim da partida, avisa que ajusto a seção 11.
- **Campo `tentativas_bloqueadas`** foi acrescentado ao modelo de dados da seção 7 como decisão de modelagem minha para viabilizar a regra da seção 11 — revisar se faz sentido.
- **Direção visual em aberto** (seção 16) — segui sem paleta definida porque nenhuma referência foi discutida ainda; assim que houver decisão, gero o `prompt-design-<produto>.md` completo (hoje ele está com placeholders).

---

### 25. Perguntas abertas

O agente de código deve perguntar a Alexandre, em vez de assumir, quando cruzar com qualquer um destes pontos:

1. **Identidade visual** (paleta, tipografia, referências) — ainda não decidida (ver seção 16).
2. **O que acontece com um convidado que perde conexão no meio do jogo** — o MVP assume que ele simplesmente reentra como jogador novo (perde os pontos); se isso for inaceitável, precisa de lógica de reconexão por apelido, o que muda o modelo de dados.
3. **Existe algum limite de jogadores por sala** — o spec não define um teto; se o Firebase free tier exigir um, qual é o comportamento (bloquear entrada? avisar o anfitrião?).
4. **A pontuação apenas dentro da sessão é realmente suficiente**, ou existe intenção futura de um placar entre partidas (o que reabriria a discussão de contas, hoje descartada no Princípio 1)?

---

### 26. Definition of Done

- [ ] App tvOS cria sala e recebe convidados conforme épico 8.1.
- [ ] PWA permite entrada em até 15 segundos conforme épico 8.2.
- [ ] Mecânica de buzz-in resolve corretamente em caso de empate (testado com múltiplos dispositivos reais, não só simulador).
- [ ] Pontuação segue exatamente a tabela da seção 11.
- [ ] Nenhum dado de `jogadores_futebol/` publicado sem curadoria manual do campo `nome_exibicao` e sem `revisao_manual: false`.
- [ ] Regras do Firebase Realtime Database implementadas conforme seção 6, testadas contra escrita não autorizada fora do escopo da sala.
- [ ] `DOCUMENTACAO-TECNICA.md` gerado e conferido contra o app implementado.
- [ ] `CLAUDE.md` criado com a pegadinha do campo `tentativas_bloqueadas` documentada.
- [ ] Testado em Wi-Fi doméstico real, não só rede local de desenvolvimento.

---

### 27. Próximos passos operacionais

1. Revisar as seções 24 e 25 deste documento antes de qualquer linha de código.
2. Rodar em produção o pipeline n8n de coleta de jogadores (já validado nesta sessão), aplicar a curadoria manual pendente (nomes abreviados, posições normalizadas, casos `revisao_manual: true`).
3. Gerar as ilustrações estilizadas via Nano Banana para o banco de jogadores curado.
4. Importar `jogadores_futebol/` no Firebase Realtime Database.
5. Implementar o app tvOS e a PWA conforme este spec, nessa ordem: modelo de dados (seção 7) e regras do Firebase (seção 6) primeiro, telas depois (seção 10).
6. Testar o épico 8.3 (buzz-in) com pelo menos 3 celulares reais na mesma rede doméstica antes de considerar o MVP pronto.

---

### 28. Roadmap: próximas releases

- **Outros temas de Perfil** (novela, música, história do Brasil) reaproveitando o mesmo motor de pistas + buzz-in — só trocar o conteúdo de `jogadores_futebol/` por outra coleção temática.
- **Modo "Imagem & Ação"** (desenho ao vivo no celular, TV mostra o desenho) — descrito na exploração inicial deste projeto; requer canvas de desenho em tempo real, não coberto neste spec.
- **Placar entre sessões / conquistas** — depende de resolver a pergunta aberta 25.4 sobre contas.

---

### 29. Protocolo de mudanças incrementais

Depois do v1 pronto, para qualquer ajuste:

1. Fazer commit de checkpoint antes da mudança, para ter um `git diff` confiável.
2. Não colar este spec inteiro de novo — colar só o trecho alterado ou um spec adicional da feature específica.
3. Escrever a instrução como diff ("o projeto já existe e funciona, mude X sem tocar em Y"), nunca como recomeço.
4. Delimitar explicitamente o que não deve mudar.
5. Pedir a lista de arquivos que serão alterados antes de codar, e aprovar antes de prosseguir.
6. Revisar o `git diff` contra o plano aprovado.
7. Atualizar `DOCUMENTACAO-TECNICA.md` no mesmo commit.

**Modelo de prompt para mudança incremental:**
```
O projeto Perfil FC já existe e funciona (v1 implementado conforme spec.md).
Mudança pontual: [descreva o ajuste].
Não altere: [liste o que deve ficar intacto].
Antes de codar, me mostre a lista de arquivos que você vai criar/alterar.
Atualize DOCUMENTACAO-TECNICA.md no mesmo commit.
```

---

### Anexo — Fontes

- Confirmação de que FlutterFlow não suporta tvOS — pesquisa web realizada nesta sessão, 2026-09-03.
- Confirmação de suporte do SDK Firebase (Firestore/Realtime Database/Auth) a tvOS, com ressalva de que Analytics/Crashlytics/Performance não são suportados nessa plataforma — pesquisa web, 2026-09-03.
- Fontes de conteúdo do banco de jogadores: lance.com.br/brasileirao (artilheiros do Brasileirão Série A 2026), band.com.br (convocados do Brasil em todas as Copas do Mundo, 1930–2022), diariodepernambuco.com.br (convocação da Seleção para a Copa de 2026) — coletadas e validadas via pipeline n8n nesta sessão, 2026-09-03.
