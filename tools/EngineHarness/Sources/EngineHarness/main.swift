// Roda o RoomEngine real do app tvOS contra o emulador do Firebase e confere, no proprio banco,
// que cada regra da secao 11 do spec acontece de verdade — inclusive a pegadinha do reset de
// `tentativas_bloqueadas`, que nao aparece em teste de unidade puro.
//
// Uso: npm run test:motor  (sobe o emulador e executa este binario)
import Foundation
import FirebaseDatabase

@MainActor
final class Harness {
    private var failures = 0

    /// So pode ser tocado DEPOIS de `FirebaseClient.shared`, que e quem chama `FirebaseApp.configure`
    /// e aponta o SDK para o emulador (`AppConfig.useEmulator`).
    private lazy var db = Database.database()

    func check(_ condition: Bool, _ description: String) {
        if condition { print("ok   \(description)") } else { print("FALHA \(description)"); failures += 1 }
    }

    /// Le um no cru do emulador POR REST, de proposito.
    ///
    /// Nao da para conferir pelo SDK: como o `FirebaseClient` mantem um listener em `salas/{codigo}`,
    /// um `getData()` num filho e servido do cache do listener e devolve o no pai. O REST le a
    /// verdade que esta no servidor — e ainda passa pelas regras de seguranca, como um cliente real.
    func read(_ path: String) async -> Any? {
        let base = AppConfig.useEmulator
            ? "http://\(AppConfig.emulatorHost):\(AppConfig.emulatorPort)/\(path).json?ns=que-jogador-e-esse-default-rtdb"
            : "\(AppConfig.databaseURL)/\(path).json"
        let url = URL(string: base)!
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              !(value is NSNull)
        else { return nil }
        return value
    }

    /// Escreve como ADMIN (token `owner` do emulador), do jeito que o Firebase CLI escreve.
    ///
    /// Precisa ser admin porque `jogadores_futebol/` tem `.write: false` nas regras da secao 6 —
    /// conteudo so entra por fora do app. Se este helper virar escrita comum, o teste passa a
    /// falhar exatamente como falharia em producao, o que ja aconteceu uma vez aqui.
    @discardableResult
    func adminWrite(_ path: String, json: String?) async -> Bool {
        var request = URLRequest(url: URL(string: "http://\(AppConfig.emulatorHost):\(AppConfig.emulatorPort)/\(path).json?ns=que-jogador-e-esse-default-rtdb")!)
        // Só existe no emulador: em produção o conteúdo entra por Service Account, fora do app.
        request.httpMethod = json == nil ? "DELETE" : "PUT"
        request.setValue("Bearer owner", forHTTPHeaderField: "Authorization")
        request.httpBody = json?.data(using: .utf8)
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    func dict(_ path: String) async -> [String: Any] {
        (await read(path)) as? [String: Any] ?? [:]
    }

    /// Espera o listener do engine assentar antes de conferir o estado.
    func settle(_ seconds: Double = 0.6) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Modo de conferencia SOMENTE LEITURA contra o Firebase real: carrega o banco de conteudo
    /// pelo mesmo caminho do app tvOS e nao escreve absolutamente nada. Serve para responder se o
    /// app consegue falar com producao sem `GoogleService-Info.plist` e sem apiKey de verdade.
    func runReadOnly() async {
        let client = FirebaseClient.shared
        let bank = (try? await client.loadPlayerBank()) ?? []
        let playable = bank.filter { $0.clues.count >= 3 }
        let withImage = bank.filter { !$0.imageURL.isEmpty }

        check(!bank.isEmpty, "o app leu o banco de conteudo de producao (\(bank.count) jogadores)")
        check(playable.count == bank.count, "todos os jogadores lidos tem pistas suficientes (\(playable.count))")
        check(withImage.count == bank.count, "todos os jogadores lidos tem ilustracao (\(withImage.count))")
        if let sample = bank.first(where: { !$0.imageURL.isEmpty }) {
            print("     exemplo: \(sample.displayName) — \(sample.clues.count) pistas — \(sample.imageURL)")
        }
        let semPosicaoValida = bank.filter { $0.position == nil }
        check(semPosicaoValida.isEmpty,
              "todas as posicoes batem com o enum da secao 7 (fora do enum: \(semPosicaoValida.count))")

        print(failures == 0 ? "\nLEITURA DE PRODUCAO OK" : "\n\(failures) PROBLEMA(S) na leitura de producao")
        exit(failures == 0 ? 0 : 1)
    }

    func run() async {
        // Inicializa o mesmo cliente que o app tvOS usa — e ele quem configura o Firebase.
        _ = FirebaseClient.shared
        if CommandLine.arguments.contains("--somente-leitura") {
            await runReadOnly()
        }

        // Contra o banco REAL nao se semeia nada: o conteudo ja existe e `jogadores_futebol/` e
        // somente leitura para clientes (regras da secao 6). O sorteio usa o banco de verdade.
        // Contra o emulador, semeia um conteudo minimo como admin, igual ao Firebase CLI faria.
        for letra in AppConfig.useEmulator ? ["a", "b", "c"] : [] {
            let seeded = await adminWrite("jogadores_futebol/harness-\(letra)", json: """
            {"nome":"Jogador \(letra.uppercased())","nome_exibicao":"Jogador \(letra.uppercased())",
             "posicao":"atacante","clube_atual":"Clube \(letra.uppercased())",
             "copas_disputadas":["2018"],"nivel_dificuldade":"medio",
             "pistas":["pista 1","pista 2","pista 3"],"imagem_url":""}
            """)
            check(seeded, "secao 7: conteudo de teste semeado como admin (harness-\(letra))")
        }

        let engine = RoomEngine()
        let openedAt = Date()
        await engine.open()
        let secondsToCreate = Date().timeIntervalSince(openedAt)
        let code = engine.code
        check(!code.isEmpty && RoomCode.isValid(code), "epico 8.1: sala criada com codigo valido (\(code))")
        // Criterio de aceite da secao 8.1: "uma sala e criada em ate 2 segundos".
        check(secondsToCreate <= 2.0,
              String(format: "epico 8.1: sala criada em %.2fs (limite de 2s)", secondsToCreate))
        check(await read("salas/\(code)/estado") as? String == "aguardando",
              "epico 8.1: sala nasce em estado aguardando")

        // Dois convidados entram, como a PWA faria.
        let joinedAt = Date()
        for (id, nick, t) in [("h1", "Duda", 1000.0), ("h2", "Marina", 2000.0)] {
            try? await db.reference(withPath: "salas/\(code)/jogadores/\(id)").setValue([
                "apelido": nick, "pontos": 0, "conectado_em": t, "ativo": true,
            ])
        }
        // Criterio de aceite da secao 8.1: o apelido aparece na TV em ate 1 segundo.
        var secondsToAppear = 0.0
        while engine.room?.players.count != 2 && Date().timeIntervalSince(joinedAt) < 5 {
            try? await Task.sleep(for: .milliseconds(20))
            secondsToAppear = Date().timeIntervalSince(joinedAt)
        }
        check(engine.room?.players.count == 2, "epico 8.1: convidados aparecem para a TV pelo listener")
        check(secondsToAppear <= 1.0,
              String(format: "epico 8.1: convidado aparece na TV em %.2fs (limite de 1s)", secondsToAppear))

        // ---------------------------------------------------------------
        // Rodada 1 — acerto na 1a pista
        // ---------------------------------------------------------------
        await engine.startRound()
        await settle()
        let firstPlayerID = await read("salas/\(code)/jogador_futebol_atual_id") as? String
        check(firstPlayerID != nil, "epico 8.3: rodada sorteou um jogador de futebol")
        check(await read("salas/\(code)/pista_atual_index") as? Int == 0, "epico 8.3: rodada comeca na pista 1")
        check(await read("salas/\(code)/rodada_numero") as? Int == 1, "epico 8.3: contador de rodada em 1")

        // Duda compra a resposta (a PWA escreve buzz_atual).
        try? await db.reference(withPath: "salas/\(code)/buzz_atual")
            .setValue(["jogador_sala_id": "h1", "timestamp": 1.0])
        await settle()
        check(engine.room?.currentBuzz?.roomPlayerID == "h1", "epico 8.3: a TV enxerga quem comprou")
        check(engine.pointsForCurrentClue == 100, "secao 11: pista 1 vale 100")

        await engine.confirmCorrectAnswer()
        await settle()
        check(await read("salas/\(code)/jogadores/h1/pontos") as? Int == 100,
              "secao 11: acerto na pista 1 credita exatamente 100 pontos")
        check(await read("salas/\(code)/estado") as? String == "revelado",
              "epico 8.3: acerto leva a sala para o estado revelado")
        let last = await dict("salas/\(code)/ultima_rodada")
        check(last["vencedor_jogador_sala_id"] as? String == "h1" && last["pontos_ganhos"] as? Int == 100,
              "epico 8.4: ultima_rodada guarda vencedor e pontos")
        let history = await dict("rodadas_historico/\(code)")
        check(history.count == 1, "secao 7: rodada gravada em rodadas_historico")

        // ---------------------------------------------------------------
        // Rodada 2 — erro, bloqueio, avanco de pista e reset da pegadinha
        // ---------------------------------------------------------------
        await engine.startRound()
        await settle()
        let secondPlayerID = await read("salas/\(code)/jogador_futebol_atual_id") as? String
        check(secondPlayerID != nil && secondPlayerID != firstPlayerID,
              "secao 11: jogador de futebol nao se repete na mesma sessao")
        check(await read("salas/\(code)/tentativas_bloqueadas") == nil,
              "PEGADINHA: novo sorteio zera tentativas_bloqueadas")

        try? await db.reference(withPath: "salas/\(code)/buzz_atual")
            .setValue(["jogador_sala_id": "h2", "timestamp": 2.0])
        await settle()
        await engine.confirmWrongAnswer()
        await settle()

        check(await read("salas/\(code)/tentativas_bloqueadas/h2") as? Bool == true,
              "secao 11: quem erra entra em tentativas_bloqueadas")
        check(await read("salas/\(code)/pista_atual_index") as? Int == 1,
              "epico 8.3: erro libera a proxima pista")
        check(await read("salas/\(code)/buzz_atual") == nil, "epico 8.3: erro libera o buzz")
        check(engine.pointsForCurrentClue == 80, "secao 11: pista 2 vale 80")

        // Duda acerta na 2a pista.
        try? await db.reference(withPath: "salas/\(code)/buzz_atual")
            .setValue(["jogador_sala_id": "h1", "timestamp": 3.0])
        await settle()
        await engine.confirmCorrectAnswer()
        await settle()
        check(await read("salas/\(code)/jogadores/h1/pontos") as? Int == 180,
              "secao 11: pontos somam entre rodadas (100 + 80 = 180)")

        // ---------------------------------------------------------------
        // Rodada 3 — confirma que o "nao repetir" vale para a sessao inteira
        // ---------------------------------------------------------------
        await engine.startRound()
        await settle()
        let thirdPlayerID = await read("salas/\(code)/jogador_futebol_atual_id") as? String
        check(thirdPlayerID != nil && thirdPlayerID != firstPlayerID && thirdPlayerID != secondPlayerID,
              "secao 11: 3a rodada sorteia um jogador ainda nao usado nesta sessao")
        let used = await dict("salas/\(code)/jogadores_futebol_usados")
        check(used.count == 3, "secao 11: jogadores_futebol_usados acumula os 3 sorteados da sessao")
        // O caso de banco ESGOTADO nao cabe aqui (o banco real tem centenas de jogadores);
        // ele e coberto em tvos-app/Tests/main.swift, no teste de `GameRules.drawNextPlayer`.

        // ---------------------------------------------------------------
        // Encerramento (epico 8.4)
        // ---------------------------------------------------------------
        await engine.closeRoom()
        await settle()
        check(await read("salas/\(code)/estado") as? String == "encerrada",
              "epico 8.4: encerrar marca estado encerrada (a PWA cai na tela de fim)")

        // Limpeza do que o harness criou.
        try? await db.reference(withPath: "salas/\(code)").removeValue()
        try? await db.reference(withPath: "rodadas_historico/\(code)").removeValue()
        for letra in AppConfig.useEmulator ? ["a", "b", "c"] : [] {
            await adminWrite("jogadores_futebol/harness-\(letra)", json: nil)
        }
        engine.endSession()

        print(failures == 0
              ? "\nMOTOR OK: todas as regras conferem contra o banco real"
              : "\n\(failures) FALHA(S) no motor")
        exit(failures == 0 ? 0 : 1)
    }
}

await Harness().run()
