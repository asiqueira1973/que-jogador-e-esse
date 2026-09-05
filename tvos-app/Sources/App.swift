import SwiftUI

/// Ponto de entrada do app do anfitriao (tvOS).
///
/// A navegacao e sequencial — uma tela por estado do jogo, como define a secao 16 do spec
/// ("nao e um painel/back-office; a navegacao da tvOS e sequencial, nao um menu").
@main
struct QueJogadorEEsseApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Escolhe a tela conforme o palco do `RoomEngine`, que por sua vez segue o campo
/// `salas/{codigo}/estado` da secao 7: aguardando -> rodada_ativa -> revelado -> repete/encerrada.
struct RootView: View {
    @StateObject private var engine = RoomEngine()

    var body: some View {
        ZStack {
            switch engine.stage {
            case .creatingRoom:
                openingScreen
            case .room:
                RoomView(engine: engine) { Task { await engine.startRound() } }
            case .clue:
                ClueView(
                    engine: engine,
                    onJudgeCorrect: { Task { await engine.confirmCorrectAnswer() } },
                    onJudgeWrong: { Task { await engine.confirmWrongAnswer() } }
                )
            case .reveal:
                RevealView(engine: engine) { engine.showScoreboard() }
            case .scoreboard:
                ScoreboardView(
                    engine: engine,
                    isFinalScoreboard: false,
                    onStartNextRound: { Task { await engine.startRound() } },
                    onClose: { Task { await engine.closeRoom() } }
                )
            case .closed:
                ScoreboardView(engine: engine, isFinalScoreboard: true, onStartNextRound: {}, onClose: {})
            case .failure(let message):
                failureScreen(message)
            }
        }
        .task { await engine.open() }
        .onDisappear { engine.endSession() }
    }

    /// Aparece por no maximo os ~2 segundos de criacao de sala exigidos pelo criterio da secao 8.1.
    private var openingScreen: some View {
        ZStack {
            StageBackground()
            VStack(spacing: 34) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Palette.spotlight)
                    .frame(width: 90, height: 90)
                    .overlay(Text("?").font(Typography.anton(56)).foregroundStyle(Palette.darkInk))
                Text("QUE JOGADOR É ESSE?")
                    .font(Typography.anton(56)).foregroundStyle(Palette.primaryText)
                HStack(spacing: 16) {
                    PulsingDot()
                    Text("Abrindo a sala…")
                        .font(Typography.barlow(30)).foregroundStyle(Palette.tertiaryText)
                }
            }
        }
    }

    private func failureScreen(_ message: String) -> some View {
        ZStack {
            StageBackground(tint: Color(hex: 0x3A1522),
                            topBar: LinearGradient(colors: [Palette.wrong],
                                                   startPoint: .leading, endPoint: .trailing))
            VStack(spacing: 26) {
                StageLabel(text: "Algo deu errado", color: Palette.lightWrong, size: 34, spacing: 6)
                Text(message)
                    .font(Typography.barlow(34))
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 1000)
                Button("TENTAR DE NOVO") { Task { await engine.open() } }
                    .buttonStyle(.card)
                    .font(Typography.anton(30))
            }
            .padding(80)
        }
    }
}
