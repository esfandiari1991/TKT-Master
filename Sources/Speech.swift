import SwiftUI
import AVFoundation

// Offline pronunciation via the built-in macOS speech synthesiser.
// Accent is user-selectable (UK / US); we pick the highest-quality installed
// voice for that accent (premium > enhanced > default). Users can download
// richer "premium" voices in System Settings ▸ Accessibility ▸ Spoken Content
// for better intonation — still fully offline.
final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()

    private func bestVoice(_ lang: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == lang }
        if let p = voices.first(where: { $0.quality == .premium })  { return p }
        if let e = voices.first(where: { $0.quality == .enhanced }) { return e }
        return voices.first ?? AVSpeechSynthesisVoice(language: lang)
    }

    var accent: String { UserDefaults.standard.string(forKey: "accent") ?? "en-GB" }

    func speak(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        u.voice = bestVoice(accent)
        u.rate = 0.44                 // slightly slower than default for clarity
        u.pitchMultiplier = 1.0
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        synth.speak(u)
    }
}

struct SpeakButton: View {
    let text: String
    var font: Font = .title3
    @AppStorage("accent") private var accent = "en-GB"
    var body: some View {
        Button { Speaker.shared.speak(text) } label: {
            Image(systemName: "speaker.wave.2.circle.fill")
                .font(font).foregroundStyle(Theme.orange)
        }
        .buttonStyle(.plain)
        .help("Pronounce — \(accent == "en-US" ? "American" : "British")")
    }
}
