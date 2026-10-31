import Foundation
import AVFoundation
import Combine

final class AdzanPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AdzanPlayer()

    @Published var isPlaying: Bool = false
    @Published var playingPrayerName: String = ""
    @Published var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: UserDefaultsKeys.adzanMuted)
            if isMuted && isPlaying {
                stop()
            }
        }
    }
    @Published var volume: Float {
        didSet {
            audioPlayer?.volume = volume
            UserDefaults.standard.set(volume, forKey: UserDefaultsKeys.adzanVolume)
        }
    }

    private var audioPlayer: AVAudioPlayer?

    override init() {
        self.isMuted = UserDefaults.standard.bool(forKey: UserDefaultsKeys.adzanMuted)
        // float(forKey:) cannot tell "unset" from a saved 0, so check the key explicitly.
        self.volume = UserDefaults.standard.object(forKey: UserDefaultsKeys.adzanVolume) == nil
            ? 0.85
            : UserDefaults.standard.float(forKey: UserDefaultsKeys.adzanVolume)
        super.init()
    }

    func play(prayerName: String) {
        guard !isMuted else { return }

        // Fajr uses its own recording, which includes "As-shalatu khairum minan naum"
        let isSubuh = prayerName.lowercased().contains("subuh") || prayerName.lowercased().contains("fajr")
        let resourceName = isSubuh ? "adzan_subuh" : "adzan"

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "m4a")
            ?? Bundle.main.url(forResource: "adzan", withExtension: "m4a")
            ?? Bundle.main.url(forResource: "adzan", withExtension: "mp3") else {
            NSLog("[Harmonotch:Adzan] Adzan audio file not found in bundle.")
            return
        }

        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            DispatchQueue.main.async {
                self.isPlaying = true
                self.playingPrayerName = prayerName
            }
        } catch {
            NSLog("[Harmonotch:Adzan] Failed to play adzan audio: %@", error.localizedDescription)
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playingPrayerName = ""
        }
    }

    func testPlay() {
        if isPlaying {
            stop()
        } else {
            play(prayerName: L10n.Prayer.testPrayer)
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playingPrayerName = ""
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playingPrayerName = ""
        }
    }
}
