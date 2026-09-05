// Conferencia executavel da tabela de regras da secao 11 do spec e da leitura do modelo da secao 7.
// Precisa se chamar main.swift: o Swift so aceita codigo de nivel superior nesse arquivo.
// Rode com: scripts/test-regras-swift.sh
import Foundation

var failures = 0
func check(_ condition: Bool, _ description: String) {
    if condition { print("ok   \(description)") } else { print("FALHA \(description)"); failures += 1 }
}

// Regra: 1a pista 100 · 2a 80 · 3a 60 · 4a 40 · 5a ou mais 20 (indice 0-based)
check(GameRules.points(forClueIndex: 0) == 100, "pista 1 vale 100")
check(GameRules.points(forClueIndex: 1) == 80,  "pista 2 vale 80")
check(GameRules.points(forClueIndex: 2) == 60,  "pista 3 vale 60")
check(GameRules.points(forClueIndex: 3) == 40,  "pista 4 vale 40")
check(GameRules.points(forClueIndex: 4) == 20,  "pista 5 vale 20")
check(GameRules.points(forClueIndex: 9) == 20,  "pista 10 (5a ou mais) vale 20")
check(GameRules.pointsWhenNobodyAnswers == 0,   "ninguem acerta = 0 pontos")
check(GameRules.minimumPlayersToStart == 0,     "nenhum minimo de jogadores")
check(GameRules.maximumPlayersPerRoom == nil,   "sem teto de jogadores (decisao 25.3)")

// Regra: jogador nao repetido na mesma sessao
let bank = ["a", "b", "c"].map { id -> FootballPlayer in
    FootballPlayer(id: id, node: ["nome": id, "pistas": ["p1", "p2", "p3"]])!
}
let drawn = GameRules.drawNextPlayer(from: bank, alreadyUsed: ["a", "b"], randomIndex: { _ in 0 })
check(drawn?.id == "c", "sorteio pula os jogadores ja usados")
check(GameRules.drawNextPlayer(from: bank, alreadyUsed: ["a", "b", "c"]) == nil,
      "banco esgotado devolve nil em vez de repetir jogador")

// Regra: bloqueio por erro vale so para o jogador_futebol atual
check(GameRules.canBuzz(roomPlayerID: "j1", blockedAttempts: []), "sem bloqueio, pode comprar")
check(!GameRules.canBuzz(roomPlayerID: "j1", blockedAttempts: ["j1"]), "quem errou nao compra de novo")
check(GameRules.canBuzz(roomPlayerID: "j2", blockedAttempts: ["j1"]), "o bloqueio e individual")

// Regra: pistas esgotadas levam a revelacao
check(GameRules.nextClueIndex(after: 0, totalClues: 3) == 1, "avanca da pista 1 para a 2")
check(GameRules.nextClueIndex(after: 2, totalClues: 3) == nil, "sem pistas restantes devolve nil")

// Codigo de sala
check(RoomCode.generate().count == 4, "codigo tem 4 caracteres")
check(RoomCode.isValid("4K7Q"), "codigo valido aceito")
check(!RoomCode.isValid("4k7q"), "codigo minusculo recusado")
check(!RoomCode.isValid("4K7QXX"), "codigo longo recusado")
check(!RoomCode.alphabet.contains("0") && !RoomCode.alphabet.contains("O"),
      "alfabeto sem caracteres ambiguos")

// Modelo: leitura da arvore em portugues snake_case
let room = Room(code: "4K7Q", node: [
    "estado": "rodada_ativa",
    "criado_em": 1000.0,
    "pista_atual_index": 2,
    "rodada_numero": 3,
    "jogador_futebol_atual_id": "neymar",
    "buzz_atual": ["jogador_sala_id": "j1", "timestamp": 5000.0],
    "tentativas_bloqueadas": ["j2": true],
    "jogadores_futebol_usados": ["neymar": true, "pedro": true],
    "jogadores": [
        "j1": ["apelido": "Duda", "pontos": 120, "conectado_em": 1000.0, "ativo": true],
        "j2": ["apelido": "Marina", "pontos": 200, "conectado_em": 2000.0, "ativo": true],
    ],
])
check(room.state == .roundActive, "estado lido do banco")
check(room.currentBuzz?.roomPlayerID == "j1", "buzz_atual lido do banco")
check(room.blockedAttempts == ["j2"], "tentativas_bloqueadas lido do banco")
check(room.usedFootballPlayers.count == 2, "jogadores_futebol_usados lido do banco")
check(room.ranking.first?.nickname == "Marina", "ranking ordena por pontos")
check(room.players.first?.nickname == "Duda", "lista da sala ordena por entrada")
check(room.player(id: "j2")?.nickname == "Marina", "busca de convidado por id")

// Enum de posicao da secao 7
check(FieldPosition(rawValue: "meio-campista") == .midfielder, "posicao meio-campista mapeada")
check(FieldPosition(rawValue: "defensor") == nil, "posicao fora do enum e recusada")

print(failures == 0 ? "\nTODAS AS REGRAS DA SECAO 11 CONFEREM" : "\n\(failures) FALHA(S)")
exit(failures == 0 ? 0 : 1)
