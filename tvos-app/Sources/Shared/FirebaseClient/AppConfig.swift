import Foundation

/// Configuracao de ambiente do app tvOS.
///
/// A secao 18 do spec define `FIREBASE_API_KEY` e `FIREBASE_DATABASE_URL` como variaveis publicas
/// (a seguranca vem das regras do Realtime Database, secao 20). Aqui elas sao lidas de
/// `tvos-app/Resources/FirebaseConfig.plist`, embutido no bundle do app.
///
/// Enquanto nao houver projeto Firebase criado, o app roda contra o emulador local
/// (`useEmulator = true`), que e o modo padrao deste repositorio.
enum AppConfig {
    /// Aponta o app para o emulador local ou para o projeto Firebase real.
    ///
    /// A ordem de precedencia existe para trocar de ambiente sem recompilar: a variavel de
    /// ambiente serve as ferramentas de linha de comando (`tools/EngineHarness`), a chave
    /// `USAR_EMULADOR` do plist serve ao app na Apple TV, e o padrao seguro e o emulador.
    static let useEmulator: Bool = {
        if let raw = ProcessInfo.processInfo.environment["QJE_USAR_EMULADOR"] {
            return raw != "0" && raw.lowercased() != "false"
        }
        if let flag = plist["USAR_EMULADOR"] as? Bool { return flag }
        return true
    }()

    /// Host e porta do emulador do Realtime Database (`firebase.json`).
    /// Em Apple TV fisica, troque `127.0.0.1` pelo IP do Mac na rede domestica.
    static let emulatorHost = "127.0.0.1"
    static let emulatorPort = 9000

    /// Endereço da PWA mostrado na TV (telas 1a/1b do canvas), sem o esquema — é o que a pessoa
    /// digita no celular quando não quiser usar o QR code.
    static var guestAppURL: String { value("PWA_URL") ?? "que-jogador-e-esse.web.app" }

    /// O mesmo endereço em forma de link, com o código da sala já embutido.
    ///
    /// É o conteúdo do QR code da tela de sala: quem escaneia cai na PWA com o campo do código
    /// preenchido e só precisa digitar o apelido — o caminho mais curto para o critério de aceite
    /// de "entrar jogando em menos de 15 segundos" (seção 8.2).
    static func guestAppLink(roomCode: String) -> String {
        let base = guestAppURL.hasPrefix("http") ? guestAppURL : "https://\(guestAppURL)"
        return "\(base)/?sala=\(roomCode)"
    }

    static var databaseURL: String {
        value("FIREBASE_DATABASE_URL") ?? "https://que-jogador-e-esse-default-rtdb.firebaseio.com"
    }

    static var apiKey: String { value("FIREBASE_API_KEY") ?? "" }

    static var projectID: String { value("FIREBASE_PROJECT_ID") ?? "que-jogador-e-esse" }

    /// O SDK do Firebase valida o FORMATO deste id ao configurar e derruba o app se ele nao bater:
    /// `1:<numero do projeto>:ios:<hash>`. O segmento de plataforma precisa ser `ios` mesmo em tvOS,
    /// porque o SDK de tvOS e o mesmo SDK do iOS. O valor abaixo e um placeholder bem formado, usado
    /// so no modo emulador — troque pelo id real ao criar o projeto Firebase.
    static var googleAppID: String { value("FIREBASE_GOOGLE_APP_ID") ?? "1:884985041791:ios:0000000000000000" }

    static var gcmSenderID: String { value("FIREBASE_GCM_SENDER_ID") ?? "884985041791" }

    /// Le uma chave de `Resources/FirebaseConfig.plist`, ignorando os placeholders do repositorio.
    private static func value(_ key: String) -> String? {
        guard let raw = plist[key] as? String,
              !raw.isEmpty,
              !raw.hasPrefix("PREENCHER")
        else { return nil }
        return raw
    }

    private static let plist: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "FirebaseConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return dict
    }()
}
