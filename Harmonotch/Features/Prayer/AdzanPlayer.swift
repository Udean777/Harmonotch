//
//  AdzanPlayer.swift
//  Harmonotch
//

import Foundation
import AVFoundation
import Combine

final class AdzanPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AdzanPlayer()

    @Published var isPlaying: Bool = false
    @Published var playingPrayerName: String = ""
    @Published var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: "Harmonotch_AdzanMuted")
            if isMuted && isPlaying {
                stop()
            }
        }
    }
    @Published var volume: Float {
        didSet {
            audioPlayer?.volume = volume
            UserDefaults.standard.set(volume, forKey: "Harmonotch_AdzanVolume")
        }
    }

    private var audioPlayer: AVAudioPlayer?

    override init() {
        self.isMuted = UserDefaults.standard.bool(forKey: "Harmonotch_AdzanMuted")
        let savedVol = UserDefaults.standard.float(forKey: "Harmonotch_AdzanVolume")
        self.volume = savedVol == 0 ? 0.85 : savedVol
        super.init()
    }

    func play(prayerName: String) {
        guard !isMuted else { return }

        // Cari file adzan.mp3 di bundle
        guard let url = Bundle.main.url(forResource: "adzan", withExtension: "mp3") else {
            print("[AdzanPlayer] Error: adzan.mp3 not found in main bundle.")
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
            print("[AdzanPlayer] Gagal memutar adzan: \(error.localizedDescription)")
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
            play(prayerName: "Uji Coba")
        }
    }

    // MARK: - AVAudioPlayerDelegate
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
