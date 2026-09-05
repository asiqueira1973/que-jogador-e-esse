import SwiftUI
import CoreImage

/// Gera o QR code que a TV mostra na tela de sala.
///
/// Serve ao ponto mais frágil do produto: a seção 2 do spec diz que "o momento mais difícil de uso
/// é a entrada na sala" e a seção 8.2 exige que um convidado entre jogando em menos de 15 segundos.
/// Digitar uma URL longa num celular briga com isso; apontar a câmera não.
///
/// O QR já leva o código da sala embutido (`?sala=XXXX`), então o convidado só digita o apelido.
/// A geração é local (CoreImage) — nenhum serviço externo, nada que dependa de rede no meio da festa.
enum QRCode {
    private static let context = CIContext()
    private static var cache: [String: CGImage] = [:]

    /// Correção de erro média: aguenta o QR meio encoberto ou a foto tremida, sem inflar o desenho.
    private static let correctionLevel = "M"

    static func image(for content: String) -> CGImage? {
        if let cached = cache[content] { return cached }

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(content.utf8), forKey: "inputMessage")
        filter.setValue(correctionLevel, forKey: "inputCorrectionLevel")

        // O QR sai minúsculo; ampliar antes de rasterizar mantém os módulos com borda dura na TV.
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cgImage = context.createCGImage(output, from: output.extent)
        else { return nil }

        cache[content] = cgImage
        return cgImage
    }
}

/// O QR desenhado como peça de palco: fundo branco com zona de silêncio, para a câmera achar rápido
/// mesmo com a TV escura por trás.
struct QRCodeView: View {
    let content: String
    var size: CGFloat = 300

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(.white)
            if let image = QRCode.image(for: content) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)   // sem suavização: módulo borrado é QR que não lê
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.09)
            }
        }
        .frame(width: size, height: size)
    }
}
