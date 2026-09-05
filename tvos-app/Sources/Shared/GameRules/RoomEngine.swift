import Foundation
import FirebaseDatabase

/// Motor da sessao de jogo no app tvOS: guarda o estado da sala e executa as transicoes.
///
/// A secao 7 do spec determina que "a logica de negocio vive inteiramente no app tvOS, que e o
/// unico cliente com permissao de avancar o estado do jogo". Cada metodo abaixo diz qual regra
/// da secao 11 implementa.
@MainActor
final class RoomEngine: ObservableObject {

    /// Sub-estado apenas visual da TV. Nao existe na arvore do Firebase (secao 7) porque so
    /// interessa ao palco: o celular do convidado nao muda de tela por causa dele.
    enum Stage: Equatable {
        case creatingRoom
        case room
        case clue
        case reveal
        case scoreboard
        case closed
        case failure(String)
    }

    @Published private(set) var stage: Stage = .creatingRoom
    @Published private(set) var code: String = ""
    @Published private(set) var room: Room?
    @Published private(set) var currentPlayer: FootballPlayer?
    @Published private(set) var secondsUntilNextClue: Int = 0

    private var playerBank: [FootballPlayer] = []
    private var clueTimer: Task<Void, Never>?
    private let client = FirebaseClient.shared

    /// Tempo que uma pista fica no ar antes de a proxima ser liberada automaticamente.
    ///
    /// A secao 5 do spec diz que avancar pista e "automatico por regra, sem toque" do anfitriao,
    /// mas a tabela da secao 11 nao define a duracao. Este valor NAO vem do spec — e o unico
    /// numero do jogo arbitrado na implementacao (registrado como divergencia).
    static let secondsPerClue = 20

    // MARK: - Abertura

    /// Epico 8.1: ao abrir o app, cria a sala e comeca a escutar `salas/{codigo}`.
    /// O criterio de aceite pede sala criada em ate 2 segundos — por isso a tela de sala aparece
    /// assim que o codigo existe, e o banco de conteudo termina de carregar em seguida.
    func open() async {
        do {
            code = try await client.createRoom()
            client.observeRoom(code: code) { [weak self] room in
                self?.apply(room)
            }
            stage = .room
            playerBank = try await client.loadPlayerBank()
        } catch {
            stage = .failure(error.localizedDescription)
        }
    }

    /// Reage a cada mudanca vinda do Realtime Database e mantem o palco coerente com o estado.
    private func apply(_ newRoom: Room) {
        room = newRoom
        currentPlayer = newRoom.currentFootballPlayerID.flatMap { id in
            playerBank.first { $0.id == id }
        }

        switch newRoom.state {
        case .waiting:
            if stage == .creatingRoom { stage = .room }
        case .roundActive:
            if stage != .clue { stage = .clue }
            // Regra da secao 8.3: quando alguem compra a resposta, o relogio para —
            // ninguem perde pista enquanto o anfitriao julga.
            if newRoom.currentBuzz != nil { stopClueTimer() }
        case .revealed:
            stopClueTimer()
            if stage != .reveal && stage != .scoreboard { stage = .reveal }
        case .closed:
            stopClueTimer()
            stage = .closed
        }
    }

    // MARK: - Rodada

    /// Epico 8.3 + regra da secao 11 "jogador nao repetido na mesma sessao".
    ///
    /// PEGADINHA CRITICA DO PROJETO (secao 18 do spec): esta e a unica funcao que sorteia um novo
    /// `jogador_futebol_atual_id`, e por isso e obrigada a ZERAR `tentativas_bloqueadas`. Se o
    /// reset sumir daqui, todo mundo que ja errou uma vez fica bloqueado para sempre e o jogo
    /// trava em silencio — sem erro, sem log, so o botao "EU SEI!" que nunca mais funciona.
    func startRound() async {
        guard let room else { return }
        guard let drawn = GameRules.drawNextPlayer(
            from: playerBank,
            alreadyUsed: room.usedFootballPlayers
        ) else {
            stage = .failure("O banco de jogadores acabou nesta sessão. Encerre a sala para recomeçar.")
            return
        }

        do {
            try await client.updateRoom(code: code, values: [
                Keys.state: RoomState.roundActive.rawValue,
                Keys.currentFootballPlayerID: drawn.id,
                Keys.currentClueIndex: 0,
                Keys.roundNumber: room.roundNumber + 1,
                Keys.currentBuzz: nil,
                Keys.blockedAttempts: nil,   // <- o reset da pegadinha acima
                Keys.lastRound: nil,
                "\(Keys.usedFootballPlayers)/\(drawn.id)": true,
            ])
            currentPlayer = drawn
            stage = .clue
            startClueTimer()
        } catch {
            stage = .failure(error.localizedDescription)
        }
    }

    /// Regra da secao 5: "avancar pista — automatico por regra, sem toque".
    /// O cronometro para sozinho quando alguem compra a resposta ou quando as pistas acabam.
    private func startClueTimer() {
        stopClueTimer()
        secondsUntilNextClue = Self.secondsPerClue
        clueTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                secondsUntilNextClue -= 1
                if secondsUntilNextClue <= 0 {
                    await advanceClueAutomatically()
                    return
                }
            }
        }
    }

    private func stopClueTimer() {
        clueTimer?.cancel()
        clueTimer = nil
        secondsUntilNextClue = 0
    }

    /// Regra da secao 8.3: esgotadas todas as pistas sem ninguem acertar, a TV revela o jogador
    /// e ninguem pontua (secao 11, "0 pontos para todos").
    private func advanceClueAutomatically() async {
        guard let room, let currentPlayer, room.currentBuzz == nil else { return }

        if let next = GameRules.nextClueIndex(
            after: room.currentClueIndex,
            totalClues: currentPlayer.clues.count
        ) {
            try? await client.updateRoom(code: code, values: [
                Keys.currentClueIndex: next,
                Keys.currentBuzz: nil,
            ])
            startClueTimer()
        } else {
            await finishRoundWithoutWinner()
        }
    }

    // MARK: - Julgamento do anfitriao

    /// Regra da secao 11 — "Pontos por pista usada ate o acerto: 1a 100 · 2a 80 · 3a 60 · 4a 40 ·
    /// 5a ou mais 20". Chamada quando o anfitriao confirma o acerto pelo Siri Remote (secao 8.3).
    func confirmCorrectAnswer() async {
        guard let room, let currentPlayer, let buzz = room.currentBuzz else { return }
        let points = GameRules.points(forClueIndex: room.currentClueIndex)
        let cluesRevealed = room.currentClueIndex + 1

        do {
            try await client.addPoints(code: code, roomPlayerID: buzz.roomPlayerID, points: points)
            try await client.updateRoom(code: code, values: [
                Keys.state: RoomState.revealed.rawValue,
                Keys.currentBuzz: nil,
                Keys.lastRound: [
                    Keys.footballPlayerID: currentPlayer.id,
                    Keys.winnerRoomPlayerID: buzz.roomPlayerID,
                    Keys.pointsAwarded: points,
                    Keys.cluesRevealed: cluesRevealed,
                ],
            ])
            try await client.recordRound(code: code, round: [
                Keys.footballPlayerID: currentPlayer.id,
                Keys.cluesRevealed: cluesRevealed,
                Keys.winnerRoomPlayerID: buzz.roomPlayerID,
                Keys.pointsAwarded: points,
                Keys.closedAt: ServerValue.timestamp(),
            ])
            stage = .reveal
        } catch {
            stage = .failure(error.localizedDescription)
        }
    }

    /// Regra da secao 11 — "Jogador que erra fica bloqueado de comprar novamente apenas para
    /// aquele `jogador_futebol` da rodada atual". Marca o convidado em `tentativas_bloqueadas`,
    /// libera o buzz e passa a proxima pista (secao 8.3).
    func confirmWrongAnswer() async {
        guard let room, let currentPlayer, let buzz = room.currentBuzz else { return }

        var values: [String: Any?] = [
            "\(Keys.blockedAttempts)/\(buzz.roomPlayerID)": true,
            Keys.currentBuzz: nil,
        ]

        if let next = GameRules.nextClueIndex(
            after: room.currentClueIndex,
            totalClues: currentPlayer.clues.count
        ) {
            values[Keys.currentClueIndex] = next
            try? await client.updateRoom(code: code, values: values)
            startClueTimer()
        } else {
            try? await client.updateRoom(code: code, values: values)
            await finishRoundWithoutWinner()
        }
    }

    /// Regra da secao 11 — "Ninguem acerta depois de todas as pistas: 0 pontos para todos,
    /// jogador e revelado mesmo assim".
    private func finishRoundWithoutWinner() async {
        guard let currentPlayer else { return }
        let cluesRevealed = currentPlayer.clues.count

        try? await client.updateRoom(code: code, values: [
            Keys.state: RoomState.revealed.rawValue,
            Keys.currentBuzz: nil,
            Keys.lastRound: [
                Keys.footballPlayerID: currentPlayer.id,
                Keys.pointsAwarded: GameRules.pointsWhenNobodyAnswers,
                Keys.cluesRevealed: cluesRevealed,
            ],
        ])
        try? await client.recordRound(code: code, round: [
            Keys.footballPlayerID: currentPlayer.id,
            Keys.cluesRevealed: cluesRevealed,
            Keys.pointsAwarded: GameRules.pointsWhenNobodyAnswers,
            Keys.closedAt: ServerValue.timestamp(),
        ])
        stage = .reveal
    }

    // MARK: - Placar e encerramento (epico 8.4)

    func showScoreboard() { stage = .scoreboard }

    /// Epico 8.4: encerrar marca `estado: "encerrada"`, o que faz os celulares dos convidados
    /// caírem na tela de "jogo encerrado" (a PWA escuta o mesmo no).
    func closeRoom() async {
        try? await client.updateRoom(code: code, values: [
            Keys.state: RoomState.closed.rawValue,
            Keys.currentBuzz: nil,
        ])
        stopClueTimer()
        stage = .closed
    }

    func endSession() {
        stopClueTimer()
        client.stopObservingRoom()
    }

    // MARK: - Derivados para as telas

    /// Pistas ja reveladas nesta rodada, na ordem em que sairam.
    var revealedClues: [String] {
        guard let currentPlayer, let room, !currentPlayer.clues.isEmpty else { return [] }
        let upTo = min(room.currentClueIndex, currentPlayer.clues.count - 1)
        return Array(currentPlayer.clues.prefix(upTo + 1))
    }

    /// Valor em pontos da pista no ar agora — a TV mostra isso como "VALE X PTS" (canvas 1c).
    var pointsForCurrentClue: Int {
        GameRules.points(forClueIndex: room?.currentClueIndex ?? 0)
    }

    /// Regra visual do canvas: "a cada pista, a imagem fica mais nitida".
    /// Vai de 0 (totalmente borrada) a 1 (nitida) conforme as pistas somem.
    var sharpness: Double {
        guard let currentPlayer, let room, currentPlayer.clues.count > 1 else { return 0 }
        return Double(room.currentClueIndex) / Double(currentPlayer.clues.count - 1)
    }
}
