import SwiftUI

/// Tela de sala do anfitriao (epico 8.1, telas 1a/1b do canvas).
///
/// Le `salas/{codigo}` e mostra o codigo em tela cheia, a URL da PWA e a lista de convidados que
/// vai crescendo em tempo real. O botao "Iniciar" e o unico toque de Siri Remote antes do jogo
/// (secao 5: iniciar rodada e exclusivo do anfitriao).
struct RoomView: View {
    @ObservedObject var engine: RoomEngine
    var onStart: () -> Void

    /// Sem foco inicial explicito, a Apple TV abre a tela com NADA selecionado e o Select do
    /// Siri Remote nao aciona coisa alguma — o anfitriao fica preso sem entender por que.
    /// O botao de iniciar e a unica acao da tela, entao ele nasce focado.
    @FocusState private var startButtonFocused: Bool

    private var guests: [RoomPlayer] { engine.room?.players ?? [] }

    var body: some View {
        ZStack {
            StageBackground()
            if guests.isEmpty {
                emptyRoom
            } else {
                roomWithGuests
            }
        }
    }

    // MARK: - Estado vazio (canvas 1b)

    /// Criterio de aceite da secao 8.1: com zero convidados a tela nao pode parecer quebrada,
    /// e o anfitriao pode aguardar indefinidamente.
    private var emptyRoom: some View {
        VStack(spacing: 26) {
            brand(size: 38)
            StageLabel(text: "Código da sala", size: 34, spacing: 6)
            giantCode(size: 200)
            StageCard(radius: 20, padding: 34) {
                HStack(spacing: 34) {
                    QRCodeView(content: AppConfig.guestAppLink(roomCode: engine.code), size: 240)
                    VStack(alignment: .leading, spacing: 12) {
                        StageLabel(text: "Aponte a câmera", color: Palette.spotlight, size: 28, spacing: 4)
                        Text("ou abra no celular")
                            .font(Typography.barlow(28)).foregroundStyle(Palette.secondaryText)
                        Text(AppConfig.guestAppURL)
                            .font(Typography.anton(44)).foregroundStyle(Palette.primaryText)
                    }
                }
            }
            HStack(spacing: 16) {
                PulsingDot()
                Text("Esperando o primeiro convidado entrar")
                    .font(Typography.barlow(30)).foregroundStyle(Palette.tertiaryText)
            }
            startButton
        }
        .padding(80)
    }

    // MARK: - Estado com convidados (canvas 1a)

    private var roomWithGuests: some View {
        HStack(alignment: .top, spacing: 72) {
            VStack(alignment: .leading, spacing: 34) {
                brand(size: 42)
                VStack(alignment: .leading, spacing: 12) {
                    StageLabel(text: "Código da sala", size: 34, spacing: 6)
                    giantCode(size: 176)
                }
                StageCard(radius: 18, padding: 30) {
                    HStack(spacing: 30) {
                        // O QR já carrega o código da sala; quem escaneia só digita o apelido.
                        QRCodeView(content: AppConfig.guestAppLink(roomCode: engine.code), size: 200)
                        VStack(alignment: .leading, spacing: 10) {
                            StageLabel(text: "Aponte a câmera", color: Palette.spotlight, size: 26, spacing: 4)
                            Text("ou abra no celular")
                                .font(Typography.barlow(26)).foregroundStyle(Palette.secondaryText)
                            Text(AppConfig.guestAppURL)
                                .font(Typography.anton(36)).foregroundStyle(Palette.primaryText)
                                .lineLimit(1).minimumScaleFactor(0.6)
                            Text("e digite o código acima")
                                .font(Typography.barlow(24)).foregroundStyle(Palette.tertiaryText)
                        }
                    }
                }
                Spacer(minLength: 0)
                startButton
            }

            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    StageLabel(text: "Na sala", size: 34, spacing: 6)
                    Spacer()
                    Text("\(guests.count)")
                        .font(Typography.anton(40)).foregroundStyle(Palette.correct)
                }
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(guests.enumerated()), id: \.element.id) { index, guest in
                            guestRow(guest, index: index)
                        }
                    }
                }
            }
            .frame(width: 620)
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 60)
    }

    private func guestRow(_ guest: RoomPlayer, index: Int) -> some View {
        HStack(spacing: 22) {
            GuestAvatar(nickname: guest.nickname, index: index)
            Text(guest.nickname)
                .font(Typography.barlowSemibold(38)).foregroundStyle(Palette.primaryText)
            Spacer()
            // Caminho de excecao da secao 9: quem caiu fica cinza, mas nao some da lista.
            Circle()
                .fill(guest.active ? Palette.correct : Palette.mutedText)
                .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.strongCard))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.border, lineWidth: 1))
    }

    // MARK: - Pecas comuns

    private func brand(size: CGFloat) -> some View {
        HStack(spacing: 18) {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(Palette.spotlight)
                .frame(width: size * 1.2, height: size * 1.2)
                .overlay(Text("?").font(Typography.anton(size * 0.72)).foregroundStyle(Palette.darkInk))
            Text("QUE JOGADOR É ESSE?")
                .font(Typography.anton(size)).foregroundStyle(Palette.primaryText)
        }
    }

    private func giantCode(size: CGFloat) -> some View {
        Text(engine.code)
            .font(Typography.anton(size))
            .tracking(size * 0.07)
            .foregroundStyle(Palette.spotlight)
            .shadow(color: Palette.spotlight.opacity(0.35), radius: 60)
    }

    /// Secao 11: nao ha minimo de jogadores forcado pelo sistema — o botao nunca fica desabilitado,
    /// nem com zero convidados na sala.
    private var startButton: some View {
        Button(action: onStart) {
            Text(guests.isEmpty ? "INICIAR MESMO ASSIM" : "INICIAR JOGO")
                .font(Typography.anton(34))
                .tracking(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.card)
        .frame(maxWidth: 620)
        .focused($startButtonFocused)
        .onAppear { startButtonFocused = true }
    }
}
