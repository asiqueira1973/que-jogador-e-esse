# App Store Connect — conteúdo pronto para colar (Que Jogador É Esse?)

Gerado a partir de `docs/spec.md`. Plataforma: **tvOS (Apple TV)**.
Bundle ID: `com.dablab.quejogadoreesse`.

Leia o resumo de decisões no fim do arquivo antes de submeter — três respostas exigem
confirmação sua.

---

## 1. App Information

| Campo | Valor |
|---|---|
| **Nome** | Que Jogador É Esse? |
| **Subtítulo** | Jogo de festa de futebol |
| **Categoria primária** | Games — subcategorias: **Trivia** e **Family** |
| **Categoria secundária** | Entertainment |
| **Copyright** | © 2026 Alexandre Siqueira |
| **Idioma primário** | Português (Brasil) |

Sobre a categoria: os apps anteriores da Dab Lab são utilitários (Photo & Video, Utilities), então
não há precedente aqui. Games é a categoria certa — a Apple pede duas subcategorias para jogos, e
Trivia + Family descrevem exatamente o formato (perguntas e respostas, jogado em grupo na sala).

---

## 2. Version Information

### Texto promocional (145/170)

```
Futebol na tela grande e o celular de cada um vira o controle. Um jogo de festa brasileiro para a sala de estar: quem descobre o craque primeiro?
```

### Descrição (1.631/4.000)

```
Um jogo de festa para a sala de estar: a Apple TV mostra pistas sobre um jogador de futebol brasileiro, e cada pessoa usa o próprio celular para tentar adivinhar primeiro.

NINGUÉM PRECISA INSTALAR NADA
Só quem tem a Apple TV abre o app. Os convidados apontam a câmera do celular para o QR Code na tela e já entram jogando. Sem baixar aplicativo, sem criar conta, sem cadastro, sem senha.

COMO FUNCIONA
• A TV revela uma pista por vez, da mais difícil para a mais fácil
• A ilustração do jogador começa borrada e vai ficando nítida
• Quem souber aperta EU SEI! no celular e trava o botão de todo mundo
• Quanto antes você arrisca, mais pontos vale: 100, 80, 60, 40
• Errou? Você fica de fora só daquele jogador, e a próxima pista aparece
• No fim, o placar da sala decide quem manda no assunto

O CELULAR É O CONTROLE
O Siri Remote não é usado para jogar. Ele serve só para o anfitrião começar a rodada e dizer se a resposta valeu. Todo o resto acontece no celular de cada um — inclusive quem chegou primeiro, resolvido no servidor, não no grito.

CENTENAS DE JOGADORES
O banco reúne craques que vestiram a camisa da Seleção Brasileira em Copas do Mundo e artilheiros do Brasileirão, com ilustrações estilizadas feitas para o jogo. Nenhum jogador se repete na mesma partida.

FEITO PARA A FAMÍLIA
Funciona com uma pessoa ou com a casa cheia. Criança entra sozinha: é só apontar a câmera e escrever um apelido. Quem chegar no meio da partida entra na rodada seguinte.

O QUE VOCÊ PRECISA
Uma Apple TV conectada à internet e um celular com câmera e navegador para cada convidado. Os celulares não precisam estar na mesma rede da TV.
```

### Keywords (96/100 bytes)

```
quiz,adivinhar,craque,copa,selecao,brasileirao,trivia,familia,amigos,multiplayer,celular,palpite
```

Nenhuma palavra do Nome ou do Subtítulo se repete aqui — "jogador", "jogo", "festa" e "futebol"
já são indexados por aqueles campos, e repeti-los gastaria bytes à toa. Escrevi `selecao` e
`brasileirao` sem acento de propósito: cada acento custa 2 bytes em UTF-8 e a busca da Apple é
tolerante a acentuação.

### Notas da versão (What's New)

```
Primeira versão.

Um modo de jogo: Perfil de Jogador de Futebol, com pistas progressivas e disputa de quem responde primeiro. Entrada dos convidados por QR Code, sem instalar nada no celular.
```

---

## 3. App Privacy (questionário)

**Resposta: o app coleta um único tipo de dado.**

| Pergunta | Resposta |
|---|---|
| Categoria | **User Content → Other User Content** (o apelido de exibição) |
| Vinculado à identidade do usuário? | **Não** (Not Linked to You) |
| Usado para rastreamento? | **Não** (No Tracking) |
| Finalidade | **App Functionality**, apenas |

Por que não é "Data Not Collected": o produto usa um backend (Firebase Realtime Database) e o
apelido digitado pelo convidado fica armazenado no servidor enquanto a sala existe. Mesmo sendo
efêmero e sem qualquer identificador de pessoa, isso é armazenamento fora do aparelho — e
declarar a menos é uma das causas mais comuns de atrito na revisão.

Nada mais é coletado: sem e-mail, sem nome real, sem telefone, sem localização, sem identificador
de dispositivo, sem analytics, sem crash reporting, sem anúncios. O app não usa Firebase
Authentication, Analytics nem Crashlytics — apenas o Realtime Database.

---

## 4. URLs obrigatórias

| Campo | Valor |
|---|---|
| **Support URL** | https://suportedablab.carrd.co/ |
| **Privacy Policy URL** | documento Notion "Política de Privacidade — Aplicativos da Dab Lab" |
| **Marketing URL** (opcional) | https://que-jogador-e-esse.web.app |

### Seção nova para adicionar ao documento de Política de Privacidade

O texto genérico do documento compartilhado fala em Firebase Authentication anônima, Crashlytics,
Analytics e permissões de Câmera/Galeria/Notificações. **Nada disso vale para este app**, e deixar
o texto genérico valendo criaria uma contradição direta com o questionário acima. Adicione esta
seção ao documento:

---

**Que Jogador É Esse? (Apple TV)**

**1. Coleta de Dados**
Este aplicativo não solicita cadastro, login, senha, e-mail, nome real ou qualquer dado pessoal.
O único dado informado é um apelido de exibição, digitado livremente pelo convidado no navegador
do próprio celular para que os outros participantes saibam de quem é a pontuação na tela da TV.
Não há verificação, unicidade nem vínculo desse apelido com qualquer pessoa.

**2. Uso dos Dados**
O apelido é usado exclusivamente para exibir a lista de participantes e o placar durante a
partida. Não é usado para publicidade, recomendação, análise de comportamento ou qualquer
finalidade além do funcionamento do jogo.

**3. Armazenamento e Segurança**
Os dados da partida ficam no Firebase Realtime Database enquanto a sala está aberta e são
apagados quando o anfitrião encerra o jogo. Salas encerradas são removidas em até 24 horas. Toda
a comunicação usa HTTPS. O aplicativo não utiliza Firebase Authentication, Firebase Analytics nem
Crashlytics, e não coleta identificadores de dispositivo, localização, contatos ou dados de uso.

**4. Compartilhamento com Terceiros**
Nenhum dado é compartilhado, vendido ou cedido a terceiros. Não há redes de anúncios, SDKs de
rastreamento ou integrações de marketing. O único serviço de infraestrutura utilizado é o
Firebase (Google), que hospeda o banco de dados em tempo real e as imagens do jogo.

**5. Contato**
alexandre@dablab.com.br

---

## 5. Pricing and Availability

| Campo | Valor |
|---|---|
| **Preço** | Grátis (Tier 0) |
| **Disponibilidade** | All Countries or Regions |
| **In-App Purchase** | Nenhum |

O spec não descreve monetização — a seção 1 diz explicitamente que não há "ambição de conta de
usuário, ranking online ou monetização no MVP".

Vale considerar limitar a disponibilidade ao **Brasil**: todo o conteúdo é em português e sobre
futebol brasileiro. Publicar no mundo todo não prejudica, mas um app inteiramente em pt-BR
aparecendo em lojas de outros países costuma render avaliações ruins de pessoas que não entendem
do que se trata. Decisão sua.

---

## 6. App Review Information

| Campo | Valor |
|---|---|
| **Sign-in Required** | **Não** — o app não tem conta, login nem senha |
| **Contato** | Alexandre da Silva de Siqueira · alexandre@dablab.com.br |

### Notes

```
Este app precisa de um SEGUNDO APARELHO para ser testado por completo — é a mecânica central do produto: a Apple TV é o palco e o celular é o controle.

COMO TESTAR
1. Abra o app na Apple TV. Ele cria uma sala sozinho e mostra um código de 4 caracteres e um QR Code.
2. Em um celular (ou em qualquer navegador, inclusive no computador), abra https://que-jogador-e-esse.web.app e digite o código que está na TV. Apontar a câmera para o QR Code faz o mesmo, já com o código preenchido.
3. Escolha um apelido qualquer e toque em Entrar. O apelido aparece na TV em cerca de 1 segundo.
4. Na Apple TV, selecione INICIAR JOGO com o Siri Remote. A primeira pista aparece.
5. No celular, toque no botão EU SEI!. A TV mostra quem comprou a resposta.
6. Na Apple TV, escolha ACERTOU ou ERROU. Acertando, os pontos entram no placar; errando, a próxima pista é liberada.
7. Em VER PLACAR você pode iniciar outra rodada ou encerrar o jogo.

O jogo funciona com um único convidado — não é preciso reunir várias pessoas para avaliar.

SEM CONTA E SEM LOGIN
O app não tem cadastro, login, senha nem compra dentro do app. Não há nada a recuperar, excluir ou deslogar. O único dado que um convidado informa é um apelido de exibição, digitado no celular, que existe apenas enquanto a sala está aberta e é apagado quando o anfitrião encerra a partida.

SOBRE OS APELIDOS
O apelido é texto livre, mas fica visível somente para as pessoas que estão na mesma sala física, assistindo à mesma TV, durante aquela partida. Não existe feed público, perfil, histórico, busca de usuários nem qualquer forma de contato entre estranhos.

SOBRE AS ILUSTRAÇÕES
As imagens não são fotografias. São ilustrações estilizadas criadas para o app, sem traços faciais que permitam identificar uma pessoa real — a identificação do jogador vem das pistas de texto. Os dados exibidos (clube, Copas disputadas) são informações factuais de domínio público sobre atletas.

PERMISSÕES
O app não usa câmera, microfone, localização, contatos, notificações nem qualquer sensor. A câmera usada para ler o QR Code é a do celular do convidado, pelo app de câmera do próprio aparelho — não por este app.

Support website: https://suportedablab.carrd.co/
Contato: alexandre@dablab.com.br
```

---

## 7. App Encryption Documentation

**Resposta: "None of the algorithms mentioned above."**

O app só faz chamadas HTTPS pelo SDK oficial do Firebase e por `URLSession`. Não implementa
nenhum algoritmo de criptografia próprio.

---

## 8. Content Rights

**Resposta sugerida: "No, it does not contain, show, or access third-party content."**

Mas leia o alerta no resumo final: este é o campo menos mecânico deste app.

---

## 9. Classificação etária (Age Rating)

**Expectativa: 4+.**

Nenhuma das categorias que elevam a faixa se aplica: sem violência, sem conteúdo adulto, sem
apostas, sem álcool, sem IA generativa em tempo de uso, sem compras.

O ponto de atenção é a pergunta sobre **conteúdo gerado por usuário**. O app tem um campo de texto
livre (o apelido) que aparece na TV para os outros participantes. Responda com sinceridade que
existe, e a explicação está nas notas de revisão: o apelido é visto apenas por quem está na mesma
sala física durante aquela partida, e não existe feed, perfil, histórico, busca de pessoas nem
qualquer canal de contato entre desconhecidos. Se a Apple insistir, a faixa provável passa a 9+ —
não é um problema para o produto.

---

## 10. Resultado da checagem de limites

Medido com `scripts/check_limits.py`, não estimado:

```
Nome:                   19/30 caracteres    [OK]
Subtítulo:              24/30 caracteres    [OK]
Texto promocional:     145/170 caracteres   [OK]
Descrição:            1631/4000 caracteres  [OK]
Keywords:               96/100 bytes        [OK]
Notas da versão:       191/4000 caracteres  [OK]
Notas de revisão:     2230/4000 caracteres  [OK]
```

---

## 11. Screenshots

Cinco artes prontas em **1920×1080**, um dos dois tamanhos que a Apple aceita para tvOS (o outro é
3840×2160). Geradas por `scripts/gerar-artes-loja.mjs`, então dá para regerar todas se a copy
mudar.

| Ordem | Arquivo | Headline |
|---|---|---|
| 1 | `01-ninguem-instala.png` | Ninguém instala nada. |
| 2 | `02-arrisque-cedo.png` | Quem arrisca cedo ganha mais. |
| 3 | `03-toque-primeiro.png` | Quem tocar primeiro responde. |
| 4 | `04-revelacao.png` | E aí o jogo revela quem era. |
| 5 | `05-placar.png` | O placar decide a treta da família. |

A primeira é a mais importante: é a que aparece na busca, e é a que comunica o diferencial do
produto (entrar sem instalar nada).
