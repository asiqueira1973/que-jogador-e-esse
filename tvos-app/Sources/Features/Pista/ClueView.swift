import SwiftUI

/// Tela de pista do anfitriao (epico 8.3, telas 1c e 1d do canvas).
///
/// Le `salas/{codigo}` e `jogadores_futebol/{id}`. Mostra a pista atual, o historico de pistas ja
/// reveladas, a silhueta que vai perdendo o borrao e — quando alguem compra a resposta — os dois
/// botoes de julgamento do anfitriao (secao 8.3: "certo/errado ... pelo Siri Remote").
struct ClueView: View {
    @ObservedObject var engine: RoomEngine
    var onJudgeCorrect: () -> Void
    var onJudgeWrong: () -> Void

    /// Quando alguem compra a resposta, o anfitriao precisa julgar na hora — o botao de acerto
    /// nasce focado para o Select do Siri Remote resolver com um toque só.
    @FocusState private var correctFocused: Bool

    private var room: Room? { engine.room }
    private var buyer: RoomPlayer? { room?.player(id: room?.currentBuzz?.roomPlayerID) }
    private var clues: [String] { engine.revealedClues }

    var body: some View {
        ZStack {
            StageBackground(
                tint: buyer == nil ? Color(hex: 0x241C6B) : Color(hex: 0x2A1550),
                topBar: buyer == nil
                    ? LinearGradient(colors: [Palette.spotlight, Palette.purple, Palette.correct],
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Palette.wrong, Palette.wrong],
                                     startPoint: .leading, endPoint: .trailing)
            )

            HStack(alignment: .top, spacing: 56) {
                mainColumn
                sideColumn.frame(width: 470)
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 44)
        }
    }

    // MARK: - Coluna principal

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 26) {
            header
            if let buyer {
                clueInBackground
                buzzBlock(buyer)
            } else {
                clueHighlighted
                clueHistory
                Spacer(minLength: 0)
                waitingForBuzzFooter
            }
        }
    }

    private var header: some View {
        HStack(spacing: 20) {
            StageLabel(text: "Rodada \(room?.roundNumber ?? 1)", size: 30)
            if buyer == nil {
                clueMarkers
                Spacer()
                // Valor vindo direto da tabela da secao 11 via GameRules.
                StageLabel(text: "Vale \(engine.pointsForCurrentClue) pts",
                           color: Palette.spotlight, size: 32, spacing: 3)
            } else {
                Spacer()
                StageLabel(text: "Respostas bloqueadas", color: Palette.wrong, size: 32, spacing: 3)
            }
        }
    }

    /// Um tracinho por pista do jogador sorteado; acesos os que ja foram revelados.
    private var clueMarkers: some View {
        HStack(spacing: 10) {
            ForEach(0..<(engine.currentPlayer?.clues.count ?? 0), id: \.self) { index in
                Capsule()
                    .fill(index <= (room?.currentClueIndex ?? 0) ? Palette.spotlight : Color.white.opacity(0.16))
                    .frame(width: 46, height: 10)
            }
        }
    }

    private var clueHighlighted: some View {
        VStack(alignment: .leading, spacing: 16) {
            StageLabel(text: "Pista \((room?.currentClueIndex ?? 0) + 1)", color: Palette.spotlight, size: 30)
            Text(clues.last ?? "Preparando a próxima rodada…")
                .font(Typography.anton(68))
                .foregroundStyle(Palette.primaryText)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22).fill(
                LinearGradient(colors: [Palette.spotlight.opacity(0.16), Palette.spotlight.opacity(0.05)],
                               startPoint: .top, endPoint: .bottom)
            )
        )
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.spotlight.opacity(0.45), lineWidth: 2))
    }

    /// Quando alguem compra, a pista sai do foco e da lugar ao nome de quem vai responder.
    private var clueInBackground: some View {
        VStack(alignment: .leading, spacing: 14) {
            StageLabel(text: "Pista \((room?.currentClueIndex ?? 0) + 1)", size: 28)
            Text(clues.last ?? "")
                .font(Typography.anton(50))
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.border, lineWidth: 1))
    }

    /// Pistas anteriores, da mais recente para a mais antiga (como no canvas 1c).
    private var clueHistory: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(clues.dropLast().enumerated().reversed()), id: \.offset) { index, text in
                HStack(alignment: .top, spacing: 18) {
                    Text("\(index + 1)")
                        .font(Typography.anton(30)).foregroundStyle(Palette.mutedText)
                        .frame(minWidth: 34, alignment: .leading)
                    Text(text).font(Typography.barlow(32)).foregroundStyle(Palette.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
            }
        }
    }

    private var waitingForBuzzFooter: some View {
        HStack(spacing: 18) {
            PulsingDot(color: Palette.correct)
            Text("Ninguém comprou ainda — aperte EU SEI! no celular")
                .font(Typography.barlow(30)).foregroundStyle(Palette.secondaryText)
            Spacer()
            if engine.secondsUntilNextClue > 0 {
                StageLabel(text: "Próxima pista em \(engine.secondsUntilNextClue)s", size: 26, spacing: 2)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
                .foregroundStyle(Color.white.opacity(0.22))
        )
    }

    /// Canvas 1d + secao 8.3: a TV mostra quem esta respondendo e o anfitriao julga em voz alta.
    private func buzzBlock(_ buyer: RoomPlayer) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            StageLabel(text: "Comprou a resposta", color: Palette.correct, size: 32, spacing: 6)
            HStack(spacing: 30) {
                GuestAvatar(nickname: buyer.nickname, index: guestIndex(buyer), size: 96)
                Text(buyer.nickname.uppercased())
                    .font(Typography.anton(80))
                    .foregroundStyle(Palette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Text("Fale a resposta em voz alta — o anfitrião decide se valeu.")
                .font(Typography.barlow(30)).foregroundStyle(Palette.secondaryText)

            HStack(spacing: 24) {
                Button(action: onJudgeCorrect) {
                    Text("ACERTOU  +\(engine.pointsForCurrentClue)")
                        .font(Typography.anton(32)).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.card)
                .focused($correctFocused)
                .onAppear { correctFocused = true }

                Button(action: onJudgeWrong) {
                    Text("ERROU")
                        .font(Typography.anton(32)).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.card)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 38)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24).fill(
                LinearGradient(colors: [Palette.correct.opacity(0.20), Palette.correct.opacity(0.06)],
                               startPoint: .top, endPoint: .bottom)
            )
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.correct.opacity(0.55), lineWidth: 2))
    }

    // MARK: - Coluna lateral

    private var sideColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            StageLabel(text: "Quem é?", size: 30, spacing: 6)
            silhouette
            sharpnessBar
            Spacer(minLength: 0)
            partialScoreboard
        }
    }

    /// Regra visual do canvas: a ilustracao vai perdendo o borrao a cada pista revelada.
    ///
    /// A arte vem de `jogadores_futebol/{id}/imagem_url` — ilustracao estilizada, sem traços
    /// faciais, conforme a mitigacao de direito de imagem da secao 20. Quem ainda nao tem
    /// ilustracao cai no marcador "?", que borra do mesmo jeito e nao quebra o layout.
    private var silhouette: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(Palette.midBackground)

            if let url = illustrationURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            // A escala evita que as bordas borradas deixem vazar o contorno.
                            .scaleEffect(1.1)
                    } else {
                        placeholderMark
                    }
                }
            } else {
                placeholderMark
            }

            // Vinheta do canvas: escurece as bordas e casa a arte com o palco indigo.
            RoundedRectangle(cornerRadius: 24)
                .fill(RadialGradient(colors: [.clear, Palette.deepBackground.opacity(0.75)],
                                     center: .center, startRadius: 60, endRadius: 320))
        }
        .frame(width: 470, height: 390)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        // O borrao fica no ZStack inteiro para a arte e o marcador se comportarem igual.
        .blur(radius: 26 * (1 - engine.sharpness))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var illustrationURL: URL? {
        guard let raw = engine.currentPlayer?.imageURL, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    private var placeholderMark: some View {
        Text("?")
            .font(Typography.anton(220))
            .foregroundStyle(Palette.spotlight.opacity(0.28))
    }

    private var sharpnessBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StageLabel(text: "Nitidez", size: 28, spacing: 3)
                Spacer()
                StageLabel(text: "\(Int(engine.sharpness * 100))%", color: Palette.spotlight, size: 28, spacing: 3)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.spotlight, Palette.correct],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * engine.sharpness))
                }
            }
            .frame(height: 14)
            Text("A cada pista, a imagem fica mais nítida")
                .font(Typography.barlow(24)).foregroundStyle(Palette.mutedText)
        }
    }

    private var partialScoreboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageLabel(text: "Placar parcial", size: 28, spacing: 4)
            ForEach((room?.ranking ?? []).prefix(4)) { guest in
                HStack {
                    Text(guest.nickname)
                        .font(Typography.barlow(30)).foregroundStyle(Palette.secondaryText)
                    Spacer()
                    Text("\(guest.points)")
                        .font(Typography.anton(30)).foregroundStyle(Palette.primaryText)
                }
            }
        }
    }

    private func guestIndex(_ guest: RoomPlayer) -> Int {
        room?.players.firstIndex(where: { $0.id == guest.id }) ?? 0
    }
}
