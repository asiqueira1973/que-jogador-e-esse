import Foundation

/// Implementa, em um unico lugar, a tabela de regras de negocio da secao 11 do spec.
///
/// A secao 7 do spec determina que "a logica de negocio vive inteiramente no app tvOS, que e o
/// unico cliente com permissao de avancar o estado do jogo" — este arquivo e esse lugar.
/// Nenhum valor aqui e inventado: todos saem literalmente da tabela da secao 11.
enum GameRules {

    // MARK: - Pontuacao

    /// Tabela literal da secao 11: "1a pista: 100 · 2a: 80 · 3a: 60 · 4a: 40 · 5a ou mais: 20".
    /// O indice e 0-based (`pista_atual_index` da secao 7); o texto do spec e 1-based.
    static let pointsTable: [Int] = [100, 80, 60, 40]
    static let pointsFromFifthClueOn = 20

    /// Regra da secao 11 — "Pontos por pista usada ate o acerto".
    /// Recebe o indice 0-based da pista revelada no momento do acerto e devolve os pontos.
    static func points(forClueIndex index: Int) -> Int {
        guard index >= 0 else { return pointsTable[0] }
        if index < pointsTable.count { return pointsTable[index] }
        return pointsFromFifthClueOn
    }

    /// Regra da secao 11 — "Ninguem acerta depois de todas as pistas: 0 pontos para todos".
    static let pointsWhenNobodyAnswers = 0

    // MARK: - Sorteio de jogador

    /// Regra da secao 11 — "Jogador nao repetido na mesma sessao": um `jogador_futebol_id` ja
    /// sorteado nao volta a ser sorteado ate a sala ser encerrada.
    ///
    /// Devolve `nil` quando o banco de conteudo acabou para esta sessao — nesse caso a TV nao
    /// inicia nova rodada e o anfitriao so tem a opcao de encerrar.
    static func drawNextPlayer(
        from candidates: [FootballPlayer],
        alreadyUsed: Set<String>,
        randomIndex: (Int) -> Int = { Int.random(in: 0..<$0) }
    ) -> FootballPlayer? {
        let available = candidates.filter { !alreadyUsed.contains($0.id) }
        guard !available.isEmpty else { return nil }
        return available[randomIndex(available.count)]
    }

    // MARK: - Bloqueio por erro

    /// Regra da secao 11 — "Jogador que erra fica bloqueado de comprar novamente apenas para
    /// aquele `jogador_futebol` da rodada atual; libera de novo na proxima rodada".
    ///
    /// PEGADINHA DO PROJETO: o conjunto `tentativas_bloqueadas` precisa ser zerado toda vez que
    /// um novo `jogador_futebol_atual_id` e sorteado. Sem isso o jogo trava silenciosamente —
    /// todo mundo fica bloqueado para sempre. Ver `RoomEngine.startRound`.
    static func canBuzz(roomPlayerID: String, blockedAttempts: Set<String>) -> Bool {
        !blockedAttempts.contains(roomPlayerID)
    }

    // MARK: - Avanco de pista

    /// Regra da secao 8.3 — "se errado, esse jogador fica bloqueado ... e o jogo libera nova pista";
    /// combinada com "depois de esgotadas todas as pistas sem ninguem acertar, a TV revela o jogador".
    ///
    /// Devolve o proximo indice de pista, ou `nil` quando as pistas acabaram (hora de revelar).
    static func nextClueIndex(after currentIndex: Int, totalClues: Int) -> Int? {
        let next = currentIndex + 1
        return next < totalClues ? next : nil
    }

    // MARK: - Jogadores por sala

    /// Regra da secao 11 — "Minimo de jogadores para iniciar: nenhum minimo forcado pelo sistema".
    /// Existe como constante nomeada para deixar explicito que o zero e uma decisao, nao um esquecimento.
    static let minimumPlayersToStart = 0

    /// Decisao da pergunta aberta 25.3, respondida pelo Alexandre: nao ha teto de jogadores por sala.
    static let maximumPlayersPerRoom: Int? = nil
}
