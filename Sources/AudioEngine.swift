import Foundation
import AVFoundation
import AppKit

// Study audio:
//  • If the user provides a real track (bundle "study-music.*" or ~/Music/TKTMaster-study.*), loop it.
//  • Otherwise play a calm, evolving generated ambient (fully offline, no copyright issues).
final class StudyAudio {
    static let shared = StudyAudio()
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var player: AVAudioPlayer?
    private var sampleTime: Double = 0
    private var lpf: Double = 0
    private(set) var running = false

    // Calm C-major progression: Cmaj7 · Am7 · Fmaj7 · G
    private let chords: [[Double]] = [
        [261.63, 329.63, 392.00, 493.88],
        [220.00, 261.63, 329.63, 392.00],
        [174.61, 220.00, 261.63, 329.63],
        [196.00, 246.94, 293.66, 392.00]
    ]

    /// True when looping a real user-provided audio file rather than the generated ambient.
    var usingRealTrack: Bool { player != nil }

    private func userMusicURL() -> URL? {
        let fm = FileManager.default
        for ext in ["m4a", "mp3", "wav", "aif", "aiff"] {
            if let u = Bundle.main.url(forResource: "study-music", withExtension: ext) { return u }
        }
        let music = fm.homeDirectoryForCurrentUser.appendingPathComponent("Music")
        for name in ["TKTMaster-study", "study-music", "tkt-study"] {
            for ext in ["m4a", "mp3", "wav", "aif", "aiff"] {
                let u = music.appendingPathComponent("\(name).\(ext)")
                if fm.fileExists(atPath: u.path) { return u }
            }
        }
        return nil
    }

    func start() {
        guard !running else { return }
        if let url = userMusicURL(), let p = try? AVAudioPlayer(contentsOf: url) {
            p.numberOfLoops = -1
            p.volume = 0.45
            p.prepareToPlay()
            p.play()
            player = p
            running = true
            return
        }
        startGenerative()
    }

    private func startGenerative() {
        let format = engine.outputNode.inputFormat(forBus: 0)
        let sr = format.sampleRate > 0 ? format.sampleRate : 44100.0
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, abl -> OSStatus in
            guard let self = self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            let amp = 0.045
            let chordLen = 13.0
            let xf = 0.35
            for frame in 0..<Int(frameCount) {
                let t = self.sampleTime / sr
                let phase = t / chordLen
                let i = Int(floor(phase)) % self.chords.count
                let j = (i + 1) % self.chords.count
                let frac = phase - floor(phase)
                let wNext = frac > (1 - xf) ? (frac - (1 - xf)) / xf : 0.0
                let wCur = 1.0 - wNext
                func voice(_ fr: [Double]) -> Double {
                    var s = 0.0
                    // soft sine + gentle sub-octave for warmth + slow chorus shimmer
                    for f in fr { s += sin(2 * Double.pi * f * t) + 0.30 * sin(Double.pi * f * t) + 0.22 * sin(2 * Double.pi * f * 1.0035 * t) }
                    return s / Double(fr.count) / 1.52
                }
                let swell = 0.74 + 0.26 * sin(2 * Double.pi * 0.035 * t)
                let raw = (voice(self.chords[i]) * wCur + voice(self.chords[j]) * wNext) * amp * swell
                // one-pole low-pass: rounds off harsh edges for a calmer, focusing tone
                self.lpf += 0.10 * (raw - self.lpf)
                let value = Float(self.lpf)
                for buffer in buffers {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    if frame < buf.count { buf[frame] = value }
                }
                self.sampleTime += 1
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        source = node
        do { try engine.start(); running = true } catch { running = false }
    }

    func stop() {
        guard running else { return }
        player?.stop(); player = nil
        if engine.isRunning { engine.stop() }
        if let n = source { engine.detach(n) }
        source = nil
        sampleTime = 0
        running = false
    }
}

// Soft UI sound effects using built-in macOS system sounds (no bundled assets).
enum SFX {
    static func play(_ name: String) {
        guard UserDefaults.standard.bool(forKey: "sfxOn") else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
    static func correct() { play("Glass") }
    static func wrong()   { play("Tink") }
    static func tap()     { play("Pop") }
}
