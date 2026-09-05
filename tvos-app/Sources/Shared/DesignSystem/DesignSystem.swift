import SwiftUI

/// Tokens visuais do produto, extraidos do canvas "Perfil FC — Telas do jogo"
/// (direcao "noite de estadio sob refletores", confirmada pelo Alexandre — pergunta aberta 25.1).
///
/// Toda cor e tipografia do app sai daqui; nenhuma tela define cor solta.
enum Palette {
    // Fundo e superficies
    static let deepBackground = Color(hex: 0x070A22)
    static let midBackground = Color(hex: 0x0C1038)
    static let highBackground = Color(hex: 0x1B2470)
    static let card = Color.white.opacity(0.06)
    static let strongCard = Color.white.opacity(0.07)
    static let border = Color.white.opacity(0.10)

    // Marca
    static let spotlight = Color(hex: 0xFFD84D)      // amarelo de refletor, cor de marca
    static let lightSpotlight = Color(hex: 0xFFE585)
    static let darkInk = Color(hex: 0x10112A)        // texto sobre o amarelo
    static let purple = Color(hex: 0x7C5CFF)

    // Semantica (secao 16 do spec: verde = acerto, vermelho = erro/bloqueio)
    static let correct = Color(hex: 0x34D399)
    static let wrong = Color(hex: 0xFF4D5E)
    static let lightWrong = Color(hex: 0xFF8A96)

    // Texto
    static let primaryText = Color(hex: 0xF2F4FF)
    static let secondaryText = Color(hex: 0xC7CCEC)
    static let tertiaryText = Color(hex: 0x8E96BF)
    static let mutedText = Color(hex: 0x6E76A0)

    /// Paleta ciclica dos avatares dos convidados, na ordem usada no canvas.
    static let avatars: [Color] = [spotlight, purple, correct, wrong, .white]
}

/// Tipografia do canvas: Anton para numeros e titulos de palco, Barlow para texto corrido,
/// Barlow Condensed para rotulos de placar eletronico.
enum Typography {
    static func anton(_ size: CGFloat) -> Font { .custom("Anton-Regular", size: size) }
    static func barlow(_ size: CGFloat) -> Font { .custom("Barlow-Regular", size: size) }
    static func barlowSemibold(_ size: CGFloat) -> Font { .custom("Barlow-SemiBold", size: size) }
    static func barlowBold(_ size: CGFloat) -> Font { .custom("Barlow-Bold", size: size) }
    static func condensedSemibold(_ size: CGFloat) -> Font { .custom("BarlowCondensed-SemiBold", size: size) }
    static func condensedBold(_ size: CGFloat) -> Font { .custom("BarlowCondensed-Bold", size: size) }
}

/// Rotulo de placar eletronico — caixa alta, espacado, cinza-azulado (padrao repetido no canvas).
struct StageLabel: View {
    let text: String
    var color: Color = Palette.tertiaryText
    var size: CGFloat = 30
    var spacing: CGFloat = 5

    var body: some View {
        Text(text.uppercased())
            .font(Typography.condensedBold(size))
            .tracking(spacing)
            .foregroundStyle(color)
    }
}

/// Avatar circular com a inicial do apelido — usado na sala, na compra da resposta e no placar.
struct GuestAvatar: View {
    let nickname: String
    let index: Int
    var size: CGFloat = 62

    private var color: Color { Palette.avatars[index % Palette.avatars.count] }

    /// Texto escuro sobre os fundos claros da paleta, branco sobre os escuros.
    private var textColor: Color {
        color == Palette.purple || color == Palette.wrong ? .white : Palette.darkInk
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Text(String(nickname.prefix(1)).uppercased())
                    .font(Typography.anton(size * 0.48))
                    .foregroundStyle(textColor)
            )
    }
}

/// Fundo padrao das telas de TV: gradiente radial de "noite de estadio" + faixa de cor no topo.
struct StageBackground: View {
    var tint: Color = Palette.highBackground
    var topBar: LinearGradient = LinearGradient(
        colors: [Palette.spotlight, Palette.purple, Palette.correct],
        startPoint: .leading, endPoint: .trailing
    )

    var body: some View {
        ZStack(alignment: .top) {
            RadialGradient(
                colors: [tint, Palette.midBackground, Palette.deepBackground],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: 1400
            )
            topBar.frame(height: 8)
        }
        .ignoresSafeArea()
    }
}

/// Cartao translucido reutilizado em quase toda tela do canvas.
struct StageCard<Content: View>: View {
    var fill: Color = Palette.card
    var borderColor: Color = Palette.border
    var borderWidth: CGFloat = 1
    var radius: CGFloat = 18
    var padding: CGFloat = 30
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(borderColor, lineWidth: borderWidth))
    }
}

/// Ponto pulsante usado nos estados de espera do canvas ("esperando o primeiro convidado").
struct PulsingDot: View {
    var color: Color = Palette.spotlight
    var size: CGFloat = 16
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .background(
                // Onda que cresce e some. Fica sempre na cor da marca: um anel cinza-claro
                // no meio da animacao lia como falha de renderizacao na TV.
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .scaleEffect(pulsing ? 2.6 : 1)
                    .opacity(pulsing ? 0 : 0.4)
                    .animation(.easeOut(duration: 2).repeatForever(autoreverses: false), value: pulsing)
            )
            .onAppear { pulsing = true }
    }
}

extension Color {
    /// Constroi a cor a partir do hexadecimal usado no canvas de design (ex.: 0xFFD84D).
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
