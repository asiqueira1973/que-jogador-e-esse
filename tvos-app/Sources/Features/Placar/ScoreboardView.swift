import SwiftUI

/// Tela de placar do anfitriao (epico 8.4, tela 1g do canvas).
///
/// Le `salas/{codigo}/jogadores` e mostra o ranking da sessao. Como a leitura e por listener do
/// Realtime Database, o placar reflete a soma exata sem recarregar a tela (criterio de aceite 8.4).
/// Daqui o anfitriao decide, pelo Siri Remote, entre nova rodada e encerrar o jogo.
struct ScoreboardView: View {
    @ObservedObject var engine: RoomEngine
    var isFinalScoreboard: Bool
    var onStartNextRound: () -> Void
    var onClose: () -> Void

    /// A acao mais provavel depois de uma rodada e comecar a proxima, entao e ela que nasce focada.
    @FocusState private var nextRoundFocused: Bool

    private var ranking: [RoomPlayer] { engine.room?.ranking ?? [] }

    var body: some View {
        ZStack {
            StageBackground()
            VStack(alignment: .leading, spacing: 24) {
                header
                if ranking.isEmpty {
                    Spacer()
                    Text("Ninguém entrou nesta sala.")
                        .font(Typography.barlow(34)).foregroundStyle(Palette.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(Array(ranking.enumerated()), id: \.element.id) { position, guest in
                                rankingRow(guest, position: position)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 44)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 24) {
            Text(isFinalScoreboard ? "PLACAR FINAL" : "PLACAR")
                .font(Typography.anton(64)).foregroundStyle(Palette.primaryText)
            StageLabel(text: "Depois de \(engine.room?.roundNumber ?? 0) rodadas", size: 32, spacing: 4)
            Spacer()
            StageLabel(text: "Sala \(engine.code)", color: Palette.spotlight, size: 32, spacing: 4)
        }
    }

    private func rankingRow(_ guest: RoomPlayer, position: Int) -> some View {
        let isLeader = position == 0
        return HStack(spacing: 26) {
            Text("\(position + 1)")
                .font(Typography.anton(isLeader ? 54 : 44))
                .foregroundStyle(isLeader ? Palette.spotlight : Palette.tertiaryText)
                .frame(minWidth: 72, alignment: .leading)
            GuestAvatar(
                nickname: guest.nickname,
                index: engine.room?.players.firstIndex(where: { $0.id == guest.id }) ?? position,
                size: isLeader ? 68 : 60
            )
            Text(isLeader ? guest.nickname.uppercased() : guest.nickname)
                .font(isLeader ? Typography.anton(50) : Typography.barlowBold(40))
                .foregroundStyle(Palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(guest.points)")
                    .font(Typography.anton(isLeader ? 58 : 48))
                    .foregroundStyle(isLeader ? Palette.spotlight : Palette.primaryText)
                StageLabel(text: "pts", size: 28, spacing: 3)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, isLeader ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: isLeader ? 20 : 18).fill(
                isLeader
                    ? AnyShapeStyle(LinearGradient(colors: [Palette.spotlight.opacity(0.22), Palette.spotlight.opacity(0.04)],
                                                   startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Palette.card)
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: isLeader ? 20 : 18)
                .stroke(isLeader ? Palette.spotlight.opacity(0.55) : Palette.border, lineWidth: isLeader ? 2 : 1)
        )
    }

    /// Secao 5: iniciar nova rodada e encerrar a sala sao acoes exclusivas do anfitriao.
    private var footer: some View {
        HStack(spacing: 24) {
            if isFinalScoreboard {
                Text("Jogo encerrado. Obrigado por jogar!")
                    .font(Typography.barlow(30)).foregroundStyle(Palette.tertiaryText)
                Spacer()
            } else {
                Button(action: onStartNextRound) {
                    Text("PRÓXIMA RODADA")
                        .font(Typography.anton(30)).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.card)
                .focused($nextRoundFocused)
                .onAppear { nextRoundFocused = true }

                Button(action: onClose) {
                    Text("ENCERRAR JOGO")
                        .font(Typography.anton(30)).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.card)
            }
        }
    }
}
