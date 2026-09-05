# Que Jogador É Esse?

Jogo de festa para Apple TV: a TV mostra pistas progressivas sobre um jogador de futebol
brasileiro, e cada convidado usa o próprio celular como controle — sem instalar nada, sem conta,
sem cadastro.

<p align="center">
  <img src="docs/telas/tv-01-sala.png" width="49%" alt="Tela de sala na Apple TV, com código e QR Code">
  <img src="docs/telas/tv-02-pista.png" width="49%" alt="Tela de pista, com a ilustração ainda borrada">
</p>

## Como funciona

O anfitrião abre o app na Apple TV, que cria uma sala e mostra um código de 4 caracteres e um QR
Code. Os convidados apontam a câmera do celular, caem numa página web com o código já preenchido e
só escolhem um apelido. A TV revela uma pista por vez, da mais difícil para a mais fácil, e a
ilustração do jogador vai perdendo o borrão. Quem souber aperta **EU SEI!** e trava o botão de
todo mundo — o empate é resolvido por transação no servidor, não no grito.

Quanto antes se arrisca, mais vale: **100, 80, 60, 40** pontos conforme a pista revelada.

## Arquitetura

| Camada | Tecnologia |
|---|---|
| App do anfitrião | Swift + SwiftUI, tvOS nativo (`tvos-app/`) |
| App do convidado | PWA em JS vanilla, sem framework (`pwa-convidado/`) |
| Estado em tempo real | Firebase Realtime Database (`firebase/database.rules.json`) |
| Autenticação | nenhuma — a segurança vive nas regras do banco |
| Conteúdo | 399 jogadores curados, com ilustrações estilizadas |

A lógica de negócio vive inteiramente no app tvOS: ele é o único cliente com permissão de avançar
o estado do jogo. A PWA só entra na sala e compra a resposta.

## Documentação

- [`docs/spec.md`](docs/spec.md) — a especificação, fonte única de verdade
- [`DOCUMENTACAO-TECNICA.md`](DOCUMENTACAO-TECNICA.md) — árvore de dados, máquina de estados, onde cada regra vive no código e as divergências em relação ao spec
- [`CLAUDE.md`](CLAUDE.md) — convenções, comandos e a pegadinha do projeto
- [`docs/telas/`](docs/telas/) — as 14 telas, de TV e de celular

## Rodando

```bash
npm install
npm run emu                                    # emulador do Firebase
node scripts/baixar-conteudo.mjs --emulador    # carrega o conteúdo real no emulador
cd tvos-app && xcodegen generate && open QueJogadorEEsse.xcodeproj
```

## Testes

```bash
npm run test:regras           # regras de segurança do Realtime Database
npm run test:buzz             # 12 toques simultâneos, 1 vencedor só
npm run test:motor            # o RoomEngine real contra o banco
npm run test:swift            # tabela de pontos e leitura do modelo
```

## Estado

Versão 1.0 submetida à App Store em 04/09/2026. A PWA está publicada em
[que-jogador-e-esse.web.app](https://que-jogador-e-esse.web.app).
