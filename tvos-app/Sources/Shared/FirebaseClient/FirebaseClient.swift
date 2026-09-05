import Foundation
import FirebaseCore
import FirebaseDatabase

/// Unico ponto de contato do app tvOS com o Firebase Realtime Database.
///
/// Concentra a leitura em tempo real de `salas/{codigo}` e `jogadores_futebol/` e todas as
/// escritas que fazem o jogo avancar (a secao 5 do spec da ao anfitriao a exclusividade de
/// avancar pista, criar e encerrar a sala).
@MainActor
final class FirebaseClient {
    static let shared = FirebaseClient()

    private let database: Database
    private var roomObserver: (ref: DatabaseReference, handle: DatabaseHandle)?

    private init() {
        if FirebaseApp.app() == nil {
            FirebaseClient.configureFirebase()
        }
        database = Database.database()
        if AppConfig.useEmulator {
            database.useEmulator(withHost: AppConfig.emulatorHost, port: AppConfig.emulatorPort)
        }
        database.isPersistenceEnabled = false
    }

    /// Configura o Firebase sem `GoogleService-Info.plist`: o MVP nao usa Auth nem Analytics
    /// (secao 6), so o Realtime Database, entao bastam databaseURL, apiKey e os ids do projeto.
    private static func configureFirebase() {
        let options = FirebaseOptions(googleAppID: AppConfig.googleAppID, gcmSenderID: AppConfig.gcmSenderID)
        options.apiKey = AppConfig.apiKey
        options.projectID = AppConfig.projectID
        options.databaseURL = AppConfig.databaseURL
        FirebaseApp.configure(options: options)
    }

    // MARK: - Conteudo

    /// Carrega o banco de conteudo `jogadores_futebol/` (secao 7), lido uma unica vez por sessao:
    /// e conteudo permanente e o sorteio (regra da secao 11) precisa da lista inteira em memoria.
    func loadPlayerBank() async throws -> [FootballPlayer] {
        let snapshot = try await database.reference(withPath: Keys.footballPlayers).getData()
        guard let raw = snapshot.value as? [String: [String: Any]] else { return [] }
        return raw.compactMap { FootballPlayer(id: $0.key, node: $0.value) }
    }

    // MARK: - Ciclo de vida da sala

    /// Cria `salas/{codigo}` com o estado inicial da secao 7. Tenta ate achar um codigo livre,
    /// para nunca sequestrar a sala de outro Apple TV que esteja usando o mesmo banco.
    func createRoom(attempts: Int = 8) async throws -> String {
        for _ in 0..<attempts {
            let code = RoomCode.generate()
            let ref = database.reference(withPath: "\(Keys.rooms)/\(code)")
            let existing = try await ref.getData()
            guard !existing.exists() else { continue }

            try await ref.setValue([
                Keys.state: RoomState.waiting.rawValue,
                Keys.createdAt: ServerValue.timestamp(),
                Keys.currentClueIndex: 0,
                Keys.roundNumber: 0,
            ])
            return code
        }
        throw NSError(
            domain: "QueJogadorEEsse", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Não foi possível gerar um código de sala livre."]
        )
    }

    /// Escuta `salas/{codigo}` inteiro. Uma unica assinatura alimenta todas as telas da TV —
    /// e o que garante o criterio de aceite de "convidado aparece na lista em ate 1 segundo" (secao 8.1).
    func observeRoom(code: String, onChange: @escaping (Room) -> Void) {
        stopObservingRoom()
        let ref = database.reference(withPath: "\(Keys.rooms)/\(code)")
        let handle = ref.observe(.value) { snapshot in
            let node = (snapshot.value as? [String: Any]) ?? [:]
            Task { @MainActor in onChange(Room(code: code, node: node)) }
        }
        roomObserver = (ref, handle)
    }

    func stopObservingRoom() {
        if let roomObserver {
            roomObserver.ref.removeObserver(withHandle: roomObserver.handle)
        }
        roomObserver = nil
    }

    // MARK: - Escritas do anfitriao

    /// Aplica varias mudancas em `salas/{codigo}` de uma vez.
    /// Uma escrita unica evita estados intermediarios visiveis nos celulares dos convidados.
    func updateRoom(code: String, values: [String: Any?]) async throws {
        var payload: [String: Any] = [:]
        for (key, value) in values {
            payload[key] = value ?? NSNull()
        }
        try await database.reference(withPath: "\(Keys.rooms)/\(code)").updateChildValues(payload)
    }

    /// Soma pontos ao convidado por transacao, para nao perder pontos de escritas concorrentes.
    /// Implementa a atribuicao da tabela de pontos da secao 11.
    func addPoints(code: String, roomPlayerID: String, points: Int) async throws {
        let ref = database.reference(
            withPath: "\(Keys.rooms)/\(code)/\(Keys.players)/\(roomPlayerID)/\(Keys.points)"
        )
        _ = try await ref.runTransactionBlock { data in
            let current = (data.value as? Int) ?? 0
            data.value = current + points
            return .success(withValue: data)
        }
    }

    /// Grava a rodada encerrada em `rodadas_historico/{codigo}/{rodada_id}` (secao 7).
    func recordRound(code: String, round: [String: Any]) async throws {
        try await database
            .reference(withPath: "\(Keys.roundHistory)/\(code)")
            .childByAutoId()
            .setValue(round)
    }
}
