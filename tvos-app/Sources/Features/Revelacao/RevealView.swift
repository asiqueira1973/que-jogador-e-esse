import SwiftUI

/// Tela de revelacao do anfitriao (epicos 8.3/8.4, telas 1e e 1f do canvas).
///
/// Le `jogadores_futebol/{id}` e `salas/{codigo}/jogadores`. Mostra nome completo, clube, Copas,
/// e quem ganhou quantos pontos — ou "ninguem acertou" com 0 pontos, como manda a secao 11.
struct RevealView: View {
    @ObservedObject var engine: RoomEngine
    var onContinue: () -> Void

    /// Mesma razao da tela de sala: sem foco inicial, o Siri Remote nao tem o que acionar.
    @FocusState private var continueFocused: Bool

    private var player: FootballPlayer? { engine.currentPlayer }
    private var result: LastRound? { engine.room?.lastRound }
    private var winner: RoomPlayer? { engine.room?.player(id: result?.winnerRoomPlayerID) }

    var body: some View {
        ZStack {
            StageBackground(
                tint: winner == nil ? Color(hex: 0x3A1522) : Color(hex: 0x123F32),
                topBar: LinearGradient(colors: winner == nil ? [Palette.wrong] : [Palette.correct],
                                       startPoint: .leading, endPoint: .trailing)
            )

            HStack(spacing: 60) {
                illustration
                VStack(alignment: .leading, spacing: 26) {
                    StageLabel(
                        text: winner == nil ? "A resposta era" : "A resposta é",
                        color: winner == nil ? Palette.lightWrong : Palette.correct,
                        size: 32, spacing: 8
                    )
                    Text((player?.displayName ?? "").uppercased())
                        .font(Typography.anton(104))
                        .foregroundStyle(Palette.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                    factSheet
                    if let winner { correctBlock(winner) } else { nobodyAnsweredBlock }
                    continueButton
                }
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 48)
        }
    }

    /// A ilustracao final, agora nitida — e a recompensa visual da rodada.
    /// Vem de `jogadores_futebol/{id}/imagem_url`; quem ainda nao tem arte cai na inicial do nome,
    /// sem quebrar o layout.
    private var illustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26).fill(Palette.midBackground)

            if let raw = player?.imageURL, !raw.isEmpty, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        initialMark
                    }
                }
            } else {
                initialMark
            }
        }
        .frame(width: 520, height: 660)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: (winner == nil ? Palette.wrong : Palette.correct).opacity(0.25), radius: 90)
    }

    private var initialMark: some View {
        Text(String(player?.displayName.prefix(1) ?? "?").uppercased())
            .font(Typography.anton(260))
            .foregroundStyle(Palette.spotlight.opacity(0.5))
    }

    private var factSheet: some View {
        HStack(spacing: 20) {
            fact(label: "Clube atual", value: player?.currentClub ?? "Sem clube")
            fact(
                label: "Copas disputadas",
                value: (player?.worldCups.isEmpty ?? true)
                    ? "Nenhuma"
                    : (player?.worldCups.joined(separator: " · ") ?? "Nenhuma")
            )
        }
    }

    private func fact(label: String, value: String) -> some View {
        StageCard(fill: Palette.strongCard, padding: 28) {
            VStack(alignment: .leading, spacing: 10) {
                StageLabel(text: label, size: 26, spacing: 4)
                Text(value)
                    .font(Typography.barlowBold(40))
                    .foregroundStyle(Palette.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Mostra os pontos exatamente como vieram de `ultima_rodada.pontos_ganhos`, que o motor
    /// calculou com a tabela da secao 11 — a tela nao recalcula nada.
    private func correctBlock(_ winner: RoomPlayer) -> some View {
        HStack(spacing: 26) {
            GuestAvatar(
                nickname: winner.nickname,
                index: engine.room?.players.firstIndex(where: { $0.id == winner.id }) ?? 0,
                size: 88
            )
            VStack(alignment: .leading, spacing: 6) {
                StageLabel(text: "Acertou", color: Palette.correct, size: 28, spacing: 4)
                Text(winner.nickname.uppercased())
                    .font(Typography.anton(52)).foregroundStyle(Palette.primaryText).lineLimit(1)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("+\(result?.pointsAwarded ?? 0)")
                    .font(Typography.anton(76)).foregroundStyle(Palette.correct)
                StageLabel(text: "pts", size: 32, spacing: 3)
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 26)
        .background(
            RoundedRectangle(cornerRadius: 22).fill(
                LinearGradient(colors: [Palette.correct.opacity(0.24), Palette.correct.opacity(0.06)],
                               startPoint: .leading, endPoint: .trailing)
            )
        )
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.correct.opacity(0.6), lineWidth: 2))
    }

    /// Regra da secao 11: "Ninguem acerta depois de todas as pistas — 0 pontos para todos".
    private var nobodyAnsweredBlock: some View {
        HStack(spacing: 26) {
            Text("NINGUÉM ACERTOU")
                .font(Typography.anton(52)).foregroundStyle(Palette.lightWrong)
            Spacer()
            StageLabel(text: "\(GameRules.pointsWhenNobodyAnswers) pts", size: 32, spacing: 3)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 30)
        .background(RoundedRectangle(cornerRadius: 22).fill(Palette.wrong.opacity(0.12)))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                .foregroundStyle(Palette.wrong.opacity(0.5))
        )
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("VER PLACAR").font(Typography.anton(32)).frame(maxWidth: .infinity).padding(.vertical, 8)
        }
        .buttonStyle(.card)
        .focused($continueFocused)
        .onAppear { continueFocused = true }
    }
}
