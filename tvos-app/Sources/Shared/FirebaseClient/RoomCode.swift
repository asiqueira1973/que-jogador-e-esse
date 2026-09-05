import Foundation

/// Gera e valida o codigo curto de sala — o unico "objeto com identidade" do produto (secao 6).
enum RoomCode {
    /// Alfabeto sem caracteres que se confundem a 3 metros de distancia (0/O, 1/I),
    /// porque o codigo e lido na TV e digitado no celular (criterio de aceite da secao 8.1).
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    /// A secao 6 permite 4 ou 5 caracteres; o canvas de design usa 4 e a copy de erro da PWA
    /// diz "sao 4 caracteres", entao 4 e o tamanho adotado.
    static let length = 4

    static func generate() -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }

    /// Mesma expressao usada nas regras do Realtime Database (`firebase/database.rules.json`).
    static func isValid(_ code: String) -> Bool {
        code.range(of: "^[A-Z0-9]{4,5}$", options: .regularExpression) != nil
    }
}
