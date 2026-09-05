import Foundation

// MARK: - Estado da sala

/// Espelha o campo `salas/{codigo}/estado` da secao 7 do spec.
/// A maquina de estados e sequencial: aguardando -> rodada_ativa -> revelado -> (rodada_ativa | encerrada).
enum RoomState: String, Codable {
    case waiting = "aguardando"
    case roundActive = "rodada_ativa"
    case revealed = "revelado"
    case closed = "encerrada"
}

/// Enum `posicao` normalizado na curadoria, fixado pela secao 7 do spec.
enum FieldPosition: String, Codable {
    case goalkeeper = "goleiro"
    case centerBack = "zagueiro"
    case fullBack = "lateral"
    case midfielder = "meio-campista"
    case forward = "atacante"

    /// Texto exibido na TV, sempre em portugues (idioma unico do produto, secao 17).
    var label: String {
        switch self {
        case .goalkeeper: return "Goleiro"
        case .centerBack: return "Zagueiro"
        case .fullBack: return "Lateral"
        case .midfielder: return "Meio-campista"
        case .forward: return "Atacante"
        }
    }
}

/// Nivel de dificuldade curado, campo `nivel_dificuldade` da secao 7.
enum DifficultyLevel: String, Codable {
    case easy = "facil"
    case medium = "medio"
    case hard = "dificil"
}

// MARK: - Conteudo (jogadores_futebol/)

/// Um jogador do banco de conteudo `jogadores_futebol/{id}` (secao 7).
/// Conteudo permanente, populado ANTES do lancamento — o app so le, nunca escreve aqui.
struct FootballPlayer: Identifiable, Equatable {
    let id: String
    let name: String
    let displayName: String
    let position: FieldPosition?
    let currentClub: String?
    let worldCups: [String]
    let difficulty: DifficultyLevel
    let clues: [String]
    let imageURL: String

    /// Le um no `jogadores_futebol/{id}` cru do Realtime Database (chaves em portugues, snake_case).
    init?(id: String, node: [String: Any]) {
        guard let name = node[Keys.name] as? String,
              let clues = node[Keys.clues] as? [String], !clues.isEmpty
        else { return nil }

        self.id = id
        self.name = name
        self.displayName = (node[Keys.displayName] as? String) ?? name
        self.position = (node[Keys.position] as? String).flatMap(FieldPosition.init(rawValue:))
        self.currentClub = node[Keys.currentClub] as? String
        self.worldCups = (node[Keys.worldCups] as? [String]) ?? []
        self.difficulty = (node[Keys.difficulty] as? String)
            .flatMap(DifficultyLevel.init(rawValue:)) ?? .medium
        self.clues = clues
        self.imageURL = (node[Keys.imageURL] as? String) ?? ""
    }
}

// MARK: - Sala (salas/{codigo})

/// Um convidado conectado, no `salas/{codigo}/jogadores/{jogador_sala_id}` (secao 7).
struct RoomPlayer: Identifiable, Equatable {
    let id: String
    let nickname: String
    let points: Int
    let connectedAt: TimeInterval
    let active: Bool

    init?(id: String, node: [String: Any]) {
        guard let nickname = node[Keys.nickname] as? String else { return nil }
        self.id = id
        self.nickname = nickname
        self.points = (node[Keys.points] as? Int) ?? 0
        self.connectedAt = (node[Keys.connectedAt] as? TimeInterval) ?? 0
        self.active = (node[Keys.active] as? Bool) ?? true
    }
}

/// Quem "comprou" a resposta na pista atual — no `salas/{codigo}/buzz_atual` (secao 7).
/// Escrito exclusivamente pela PWA, por transacao (regra de empate da secao 11).
struct CurrentBuzz: Equatable {
    let roomPlayerID: String
    let timestamp: TimeInterval

    init?(node: [String: Any]?) {
        guard let node,
              let id = node[Keys.roomPlayerID] as? String, !id.isEmpty
        else { return nil }
        self.roomPlayerID = id
        self.timestamp = (node[Keys.timestamp] as? TimeInterval) ?? 0
    }
}

/// Resultado da rodada recem-encerrada, no `salas/{codigo}/ultima_rodada`.
/// Alimenta a tela de revelacao (secao 10).
struct LastRound: Equatable {
    let footballPlayerID: String
    let winnerRoomPlayerID: String?
    let pointsAwarded: Int
    let cluesRevealed: Int

    init?(node: [String: Any]?) {
        guard let node, let footballPlayerID = node[Keys.footballPlayerID] as? String else { return nil }
        self.footballPlayerID = footballPlayerID
        self.winnerRoomPlayerID = node[Keys.winnerRoomPlayerID] as? String
        self.pointsAwarded = (node[Keys.pointsAwarded] as? Int) ?? 0
        self.cluesRevealed = (node[Keys.cluesRevealed] as? Int) ?? 0
    }
}

/// A sala inteira — no `salas/{codigo}` (secao 7). E o unico objeto com identidade no produto (secao 6).
struct Room: Equatable {
    let code: String
    let state: RoomState
    let createdAt: TimeInterval
    let currentFootballPlayerID: String?
    let currentClueIndex: Int
    let roundNumber: Int
    let currentBuzz: CurrentBuzz?
    let lastRound: LastRound?
    /// Regra da secao 11: quem ja errou o `jogador_futebol_atual_id` desta rodada.
    let blockedAttempts: Set<String>
    /// Regra da secao 11: jogadores de futebol ja sorteados nesta sessao, nunca repetidos.
    let usedFootballPlayers: Set<String>
    let players: [RoomPlayer]

    init(code: String, node: [String: Any]) {
        self.code = code
        self.state = (node[Keys.state] as? String).flatMap(RoomState.init(rawValue:)) ?? .waiting
        self.createdAt = (node[Keys.createdAt] as? TimeInterval) ?? 0
        self.currentFootballPlayerID = node[Keys.currentFootballPlayerID] as? String
        self.currentClueIndex = (node[Keys.currentClueIndex] as? Int) ?? 0
        self.roundNumber = (node[Keys.roundNumber] as? Int) ?? 0
        self.currentBuzz = CurrentBuzz(node: node[Keys.currentBuzz] as? [String: Any])
        self.lastRound = LastRound(node: node[Keys.lastRound] as? [String: Any])
        self.blockedAttempts = Set((node[Keys.blockedAttempts] as? [String: Any])?.keys.map { $0 } ?? [])
        self.usedFootballPlayers = Set((node[Keys.usedFootballPlayers] as? [String: Any])?.keys.map { $0 } ?? [])

        let raw = (node[Keys.players] as? [String: [String: Any]]) ?? [:]
        self.players = raw
            .compactMap { RoomPlayer(id: $0.key, node: $0.value) }
            .sorted { ($0.connectedAt, $0.id) < ($1.connectedAt, $1.id) }
    }

    /// Ranking da tela de placar (secao 10): maior pontuacao primeiro, empate desfeito pela ordem de entrada.
    var ranking: [RoomPlayer] {
        players.sorted {
            $0.points != $1.points ? $0.points > $1.points : $0.connectedAt < $1.connectedAt
        }
    }

    func player(id: String?) -> RoomPlayer? {
        guard let id else { return nil }
        return players.first { $0.id == id }
    }
}

// MARK: - Chaves da arvore

/// Nomes de chave do Realtime Database. Ficam em portugues snake_case por decisao da secao 18;
/// centraliza-los aqui e o que permite manter o codigo Swift em ingles sem string solta nas telas.
enum Keys {
    static let rooms = "salas"
    static let footballPlayers = "jogadores_futebol"
    static let roundHistory = "rodadas_historico"

    static let state = "estado"
    static let createdAt = "criado_em"
    static let currentFootballPlayerID = "jogador_futebol_atual_id"
    static let currentClueIndex = "pista_atual_index"
    static let roundNumber = "rodada_numero"
    static let currentBuzz = "buzz_atual"
    static let blockedAttempts = "tentativas_bloqueadas"
    static let usedFootballPlayers = "jogadores_futebol_usados"
    static let lastRound = "ultima_rodada"
    static let players = "jogadores"

    static let roomPlayerID = "jogador_sala_id"
    static let timestamp = "timestamp"

    static let nickname = "apelido"
    static let points = "pontos"
    static let connectedAt = "conectado_em"
    static let active = "ativo"

    static let name = "nome"
    static let displayName = "nome_exibicao"
    static let position = "posicao"
    static let currentClub = "clube_atual"
    static let worldCups = "copas_disputadas"
    static let difficulty = "nivel_dificuldade"
    static let clues = "pistas"
    static let imageURL = "imagem_url"

    static let footballPlayerID = "jogador_futebol_id"
    static let cluesRevealed = "pistas_reveladas"
    static let winnerRoomPlayerID = "vencedor_jogador_sala_id"
    static let pointsAwarded = "pontos_ganhos"
    static let closedAt = "encerrada_em"
}
