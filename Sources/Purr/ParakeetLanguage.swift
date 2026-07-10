import FluidAudio

// The languages Parakeet TDT v3 can transcribe, for the Settings picker. The
// list is derived from FluidAudio's own `Language` set (v3's script-aware token
// filter) so it can't drift from what the model actually supports; only the
// human-readable names live here. An empty code is the sentinel for auto-detect
// - Parakeet v3 identifies the spoken language itself when no language is
// pinned. v2 is English-only and ignores this entirely.
struct ParakeetLanguage: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }

    static let autoDetect = ParakeetLanguage(code: "", name: "Auto-detect")

    // Display names keyed by the language code FluidAudio emits (ISO 639-1).
    // Unlisted codes fall back to the uppercased code, so a future FluidAudio
    // addition still shows up in the picker rather than being dropped.
    private static let names: [String: String] = [
        "en": "English", "es": "Spanish", "fr": "French", "de": "German",
        "it": "Italian", "pt": "Portuguese", "ro": "Romanian", "nl": "Dutch",
        "da": "Danish", "sv": "Swedish", "fi": "Finnish", "hu": "Hungarian",
        "et": "Estonian", "lv": "Latvian", "lt": "Lithuanian", "mt": "Maltese",
        "pl": "Polish", "cs": "Czech", "sk": "Slovak", "sl": "Slovenian",
        "hr": "Croatian", "bs": "Bosnian", "ru": "Russian", "uk": "Ukrainian",
        "be": "Belarusian", "bg": "Bulgarian", "sr": "Serbian", "el": "Greek",
    ]

    // Auto-detect pinned first, then every supported language alphabetical by
    // display name.
    static let all: [ParakeetLanguage] = {
        let languages =
            Language.allCases
            .map { ParakeetLanguage(code: $0.rawValue, name: names[$0.rawValue] ?? $0.rawValue.uppercased()) }
            .sorted { $0.name < $1.name }
        return [autoDetect] + languages
    }()

    static func name(forCode code: String) -> String {
        code.isEmpty ? "Auto-detect" : (names[code] ?? code.uppercased())
    }
}
