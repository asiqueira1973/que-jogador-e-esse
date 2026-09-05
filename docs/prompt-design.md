Crie as telas de um jogo de festa para Apple TV chamado "Que Jogador É Esse?" — jogo de adivinhação de jogador de futebol em família, jogado na TV com celulares como controle.

**Não há direção visual definida ainda** — proponha uma direção coerente com o produto: um jogo de festa em família, jogado na sala de estar, no estilo de um game show de perguntas e respostas. Sugestão de tom: enérgico, colorido, mas legível a 3 metros de distância (telas de TV) e em tela pequena (telas de celular). Cor semântica sugerida: verde para acerto/pontuação, vermelho para erro/bloqueio — o resto da paleta fica livre.

Este produto **não tem menu lateral nem back-office** — é um app consumer de sala de estar (TV) + companion web (celular). Não aplique o padrão de navegação lateral estilo App Store Connect.

**Telas de TV (Apple TV, tela grande, sem toque — só visualização):**

1. **Tela de sala** — mostra um código de sala em destaque (grande, legível a distância), uma lista de apelidos dos convidados conforme entram em tempo real, e uma instrução curta de como entrar (a URL da página de convidado). Estado vazio: nenhum convidado ainda — mostrar o código sozinho, sem parecer quebrado.

2. **Tela de pista** — mostra a pista atual em destaque, uma silhueta/avatar do jogador de futebol (progressivamente menos borrada conforme mais pistas aparecem), e um indicador de qual jogador (convidado) comprou a resposta, se algum já comprou. Estado de espera: nenhuma pista ainda revelada.

3. **Tela de revelação** — mostra o nome completo do jogador de futebol, a ilustração final, clube atual e Copas disputadas, e quem acertou (ou "ninguém acertou", se for o caso) com os pontos ganhos.

4. **Tela de placar** — ranking dos convidados por pontos acumulados na sessão.

**Telas de celular (PWA, tela pequena, com toque):**

5. **Tela de entrada** — dois campos apenas: código da sala, apelido. Um botão "Entrar". Estado de erro: código inválido, mensagem clara sem assustar.

6. **Tela de espera** — "aguardando o jogo começar", mostrando os outros convidados já conectados na sala.

7. **Tela de jogo** — um botão grande, dominante, "EU SEI!" ocupando a maior parte da tela (é a ação principal, tem que ser impossível de errar o toque). Estado desabilitado: quando outro jogador já comprou a resposta primeiro, mostrar isso claramente (ex.: "Fulano respondeu primeiro!") e desabilitar o botão. Mostrar a pontuação do próprio jogador em algum canto discreto.

**Fluxo entre telas (para manter a sequência coerente):**
TV: sala → pista (repete conforme pistas avançam) → revelação → placar → (nova rodada volta pra pista, ou fim de jogo).
Celular: entrada → espera → jogo (repete a cada rodada, alternando entre "esperando a pista" e "botão ativo").

Nenhuma tela tem copy final definida ainda — use texto placeholder claramente marcado como tal (ex.: `[placeholder: título]`) onde eu não tiver dado a frase exata acima.
