# CLAUDE.md — Que Jogador É Esse?

Jogo de festa para Apple TV. A TV é o palco (app tvOS nativo, anfitrião); os convidados jogam
pelo navegador do próprio celular (PWA), sem instalar nada. Backend: Firebase Realtime Database.

A fonte única de verdade é [`docs/spec.md`](docs/spec.md). Este arquivo é o resumo operacional.

---

## ⚠️ A pegadinha mais importante do projeto

O campo **`tentativas_bloqueadas`** (regra da seção 11 do spec) **precisa ser zerado toda vez que
um novo `jogador_futebol_atual_id` é sorteado**. Se esse reset sumir, todo convidado que errar uma
vez fica bloqueado para sempre: o botão "EU SEI!" simplesmente para de funcionar para ele, **sem
erro, sem log e sem crash** — o jogo trava em silêncio e parece um bug de rede.

O reset vive num único lugar:
[`RoomEngine.iniciarRodada()`](tvos-app/Sources/Shared/GameRules/RoomEngine.swift) — na chamada
`atualizarSala` que grava `Chaves.tentativasBloqueadas: nil`.

Se você mexer no sorteio de jogador, confira esse `nil` antes de commitar.

---

## Arquitetura (seção 4 do spec)

| Camada | Onde |
|---|---|
| App do anfitrião (tvOS, SwiftUI) | `tvos-app/` — projeto Xcode gerado por XcodeGen a partir de `project.yml` |
| App do convidado (PWA, JS vanilla) | `pwa-convidado/` — deploy na Vercel ou no Firebase Hosting |
| Estado em tempo real | Firebase Realtime Database — regras em `firebase/database.rules.json` |
| Ilustrações | Cloud Storage — regras em `firebase/storage.rules` |
| Banco de conteúdo | `content/jogadores_futebol.json`, importado antes do lançamento |
| Autenticação | **Nenhuma** (seção 6) — a segurança vem das regras do banco |

A lógica de negócio vive **inteiramente no app tvOS** (seção 7): ele é o único cliente com
permissão de avançar o estado do jogo. A PWA só entra na sala e compra a resposta.

## Estrutura de pastas

```
tvos-app/
  project.yml                 spec do XcodeGen (regenerar o .xcodeproj a partir daqui)
  Sources/
    App.swift                 entrada; escolhe a tela pelo palco do RoomEngine
    Features/Sala|Pista|Revelacao|Placar
    Shared/DesignSystem       cores, tipografia e o QR code da tela de sala
    Shared/Models             DataModel.swift — espelha a árvore da seção 7
    Shared/GameRules          GameRules.swift (tabela da seção 11) + RoomEngine.swift (transições)
    Shared/FirebaseClient     FirebaseClient.swift, AppConfig.swift, RoomCode.swift
    Shared/DesignSystem       cores e tipografia do canvas de design
  Resources/                  Info.plist, FirebaseConfig.plist, fontes .ttf
  Tests/main.swift            confere a tabela da seção 11 sem precisar de tvOS
pwa-convidado/                index.html, app.js, styles.css, vendor/firebase.js, fonts/
firebase/                     database.rules.json + testes das regras
tools/EngineHarness/          roda o RoomEngine real contra o emulador (regras da §11 no banco)
scripts/                      pipeline de conteúdo, gerador de pistas e ativos de marca
content/                      conteúdo curado e a lista de pendências de curadoria
docs/spec.md                  fonte única de verdade
```

## Convenções (seção 18 do spec)

- **Chaves do Firebase em português, `snake_case`** (`jogador_sala_id`, `pista_atual_index`).
  Em Swift elas ficam centralizadas no enum `Chaves`; nunca escreva a string solta numa tela.
- **Código, variáveis e nomes de arquivo em inglês** — padrão de mercado.
- **Toda função/rotina relevante leva comentário de cabeçalho em português** dizendo o que faz e
  **qual regra da seção 11 implementa**. Isso não é decoração: é o que liga o código ao spec.
- Nenhum valor de regra é inventado. Pontos, bloqueios e sorteio saem literalmente da seção 11.

## Comandos

Conteúdo:
```bash
npm run seed:build      # content/raw/jogadores.rtf -> content/jogadores_futebol.json + pendências
npm run seed:validar    # valida o JSON contra o schema da seção 7 antes de importar
npm run seed:importar   # firebase database:set /jogadores_futebol (projeto real)
npm run seed:baixar     # baixa o conteúdo de produção e diagnostica o que falta
node scripts/gerar-pistas.mjs             # regera as pistas (dry-run); --aplicar publica
python3 scripts/gerar-icones.py           # gera o ícone em camadas e as Top Shelf images
python3 scripts/montar-catalogo.py        # monta o Assets.xcassets a partir dos PNGs acima
node scripts/baixar-conteudo.mjs --emulador   # ... e carrega no emulador, para testar com dado real
```

Testes:
```bash
npm run test:regras     # regras do Realtime Database, no emulador
npm run test:buzz       # buzz-in concorrente: 12 toques simultâneos, 1 vencedor só
npm run test:swift      # tabela de pontos e modelo de dados, sem precisar de tvOS
npm run test:motor      # RoomEngine real contra o emulador, incluindo o reset da pegadinha
npm run test:motor:producao   # a mesma partida contra o Firebase REAL (cria e apaga uma sala)
```

O `tools/EngineHarness` usa **links simbólicos** para `tvos-app/Sources/Shared/*` — ele compila
exatamente os mesmos arquivos que o app tvOS, então não existe cópia para sair de sincronia.

Rodar localmente:
```bash
npm run emu             # emulador do Firebase: banco em :9000, PWA em :5055, UI em :4000
cd tvos-app && xcodegen generate && open QueJogadorEEsse.xcodeproj

# ou, direto pela linha de comando, no simulador de Apple TV:
xcodebuild -project tvos-app/QueJogadorEEsse.xcodeproj -scheme QueJogadorEEsse \
  -destination 'generic/platform=tvOS Simulator' -derivedDataPath tvos-app/build build
xcrun simctl boot 'Apple TV 4K (3rd generation)'
xcrun simctl install booted tvos-app/build/Build/Products/Debug-appletvsimulator/QueJogadorEEsse.app
xcrun simctl launch booted com.dablab.quejogadoreesse
```

Se o `xcodebuild` disser que **"tvOS não está instalado"**, falta a plataforma no Xcode:
`xcodebuild -downloadPlatform tvOS` (≈3,6 GB).

Para instalar numa **Apple TV de verdade** (não precisa App Store nem TestFlight):
1. Apple TV e Mac na mesma rede Wi-Fi.
2. Na Apple TV: Ajustes → Controles e Dispositivos → App Remoto e Dispositivos (deixe a tela aberta).
3. No Mac: Xcode → Window → Devices and Simulators → parear e digitar o código de 6 dígitos.
4. Build: acrescente `-allowProvisioningUpdates` e use `-destination 'platform=tvOS,name=<nome>'`.

A assinatura automática já está no `project.yml` (time `XGZW6Y6K25`). O erro "your team has no
devices" significa só que nenhuma Apple TV foi pareada ainda.

Deploy da PWA:
```bash
firebase deploy --only hosting         # publica em que-jogador-e-esse.web.app (destino do QR code)
firebase deploy --only database        # publica as regras do Realtime Database
firebase deploy --only storage         # publica as regras do Cloud Storage
```

O QR code da tela de sala aponta para `PWA_URL` + `/?sala=<código>`; se a PWA mudar de endereço,
troque `PWA_URL` no `FirebaseConfig.plist` — o QR acompanha sozinho.

## Ambiente

O projeto Firebase real é **`que-jogador-e-esse`** (número `884985041791`), com o Realtime Database
em `https://que-jogador-e-esse-default-rtdb.firebaseio.com`, Hosting em `que-jogador-e-esse` e as
ilustrações no bucket `que-jogador-e-esse.firebasestorage.app`. O plano é **Blaze**.

A PWA está publicada em **https://que-jogador-e-esse.web.app** — é o destino do QR code da TV.

Ambientes:
- **PWA:** decide sozinha pelo endereço de onde foi servida. `localhost`, `127.0.0.1` e IPs de rede
  local (`192.168.*`, `10.*`, `172.16-31.*`) falam com o emulador; qualquer outro endereço fala com
  o Firebase real. Não há passo manual antes do deploy.
- **App tvOS:** chave `USAR_EMULADOR` em `tvos-app/Resources/FirebaseConfig.plist` (hoje `true`).
- **Linha de comando:** `QJE_USAR_EMULADOR=0` aponta as ferramentas para produção.

**Não é preciso `apiKey` nem `GoogleService-Info.plist`**: sem autenticação, o Realtime Database
usa só o `databaseURL`. O `FIREBASE_GOOGLE_APP_ID` precisa apenas estar **no formato**
`1:<número do projeto>:ios:<hash>` — o SDK valida o formato e derruba o app se não bater.

As chaves do Firebase são **públicas por design** (seção 20) — a segurança está nas regras do
banco, não no sigilo delas.

**Quem escreve no Firebase:** ninguém, a partir do cliente. O app tvOS e a PWA só escrevem em
`salas/` e `rodadas_historico/`. O conteúdo (`jogadores_futebol/` e as ilustrações no Storage) é
gravado exclusivamente pelo fluxo do n8n, autenticado por Service Account — credencial de dono do
projeto, que ignora as regras. Por isso as regras podem fechar escrita de cliente por completo
nesses dois lugares sem quebrar o pipeline.

Testando com Apple TV e celular reais na mesma rede: troque `127.0.0.1` pelo IP do Mac na rede
doméstica, nos dois arquivos de config.

## Antes de considerar o MVP pronto

Ver o Definition of Done (seção 26 do spec). Os itens que **não podem ser verificados por código**:
curadoria manual de `content/pendencias-curadoria.md`, teste com 3 celulares reais e teste em
Wi-Fi doméstico de verdade.
