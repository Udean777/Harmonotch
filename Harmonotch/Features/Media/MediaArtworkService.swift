import AppKit
import Foundation

/// Picks a readable accent color out of album artwork for media UI tinting.
enum ArtworkPalette {
  private static let sampleSize = 16

  static func accent(from image: NSImage) -> NSColor? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      return nil
    }
    var pixels = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
    guard
      let context = CGContext(
        data: &pixels,
        width: sampleSize,
        height: sampleSize,
        bitsPerComponent: 8,
        bytesPerRow: sampleSize * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else { return nil }
    context.interpolationQuality = .low
    context.draw(
      cgImage,
      in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
    return accent(fromRGBA: pixels)
  }

  /// Weighted average that favors saturated pixels, so covers with a colorful
  /// subject on a gray/black background still yield that subject's hue.
  /// Returns nil for grayscale artwork; callers fall back to white.
  static func accent(fromRGBA pixels: [UInt8]) -> NSColor? {
    var redSum = 0.0
    var greenSum = 0.0
    var blueSum = 0.0
    var weightSum = 0.0

    var index = 0
    while index + 3 < pixels.count {
      let alpha = Double(pixels[index + 3]) / 255
      if alpha > 0.1 {
        let red = Double(pixels[index]) / 255
        let green = Double(pixels[index + 1]) / 255
        let blue = Double(pixels[index + 2]) / 255
        let maxChannel = max(red, green, blue)
        let minChannel = min(red, green, blue)
        let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0
        let weight = saturation * saturation
        if weight > 0.002 {
          redSum += red * weight
          greenSum += green * weight
          blueSum += blue * weight
          weightSum += weight
        }
      }
      index += 4
    }

    guard weightSum > 0.02 else { return nil }

    let base = NSColor(
      srgbRed: redSum / weightSum,
      green: greenSum / weightSum,
      blue: blueSum / weightSum,
      alpha: 1
    )
    guard let rgb = base.usingColorSpace(.deviceRGB) else { return nil }
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    guard saturation >= 0.15 else { return nil }

    // Keep bars and controls legible on the black surface.
    return NSColor(
      hue: hue,
      saturation: max(saturation, 0.45),
      brightness: max(brightness, 0.85),
      alpha: 1
    )
  }
}

/// Builds deterministic cache keys for artwork scoped by app bundle ID.
public enum MediaArtworkCacheKey {
  public static func make(bundleID: String, title: String, artist: String, directURL: URL? = nil) -> String {
    let cleanBundle = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    if let urlStr = directURL?.absoluteString, !urlStr.isEmpty {
      return "\(cleanBundle)|\(urlStr)"
    }
    return "\(cleanBundle)|\(title)--\(artist)"
  }
}

extension MediaManager {
  func resolveBrowserArtworkURL(for candidate: MediaCandidate) -> URL? {
    if case .url(let url)? = candidate.artwork { return url }
    guard Self.isBrowserBundleID(candidate.app.bundleID) else { return nil }
    if let snapshot = activeWebTarget {
      if let url = URL(string: snapshot.artworkURL), !snapshot.artworkURL.isEmpty {
        return url
      }
      let titleToParse = snapshot.title.isEmpty ? candidate.title : snapshot.title
      if let parsed = parseWebMedia(title: titleToParse, url: snapshot.url),
         let vid = parsed.videoId {
        return URL(string: "https://img.youtube.com/vi/\(vid)/hqdefault.jpg")
      }
    }
    return nil
  }

  /// Artwork arrives on every NowPlaying push; recompute the accent only when
  /// the track changes so the palette work does not run every poll.
  func applyArtwork(_ image: NSImage?, generation: UInt64? = nil) {
    if let generation, generation != mediaGeneration {
      traceProducer(
        producer: "DropStaleArtwork",
        source: mediaSource,
        title: trackTitle,
        isPlaying: isPlaying,
        details: "gen=\(generation) currentGen=\(mediaGeneration)"
      )
      return
    }
    artworkImage = image
    guard let image else {
      artworkAccentColor = nil
      artworkAccentTrackKey = ""
      return
    }
    let bundleID = presentation?.app.bundleID ?? mediaSource.rawValue
    let key = "\(bundleID)|\(trackTitle)|\(artistName)"
    guard artworkAccentTrackKey != key else { return }
    artworkAccentTrackKey = key
    artworkAccentColor = ArtworkPalette.accent(from: image)
  }

  func fetchArtworkAsync(
    for candidate: MediaCandidate,
    directURL: URL? = nil,
    generation: UInt64
  ) {
    let source = Self.mediaSource(for: candidate.app.bundleID)
    let cacheKey = MediaArtworkCacheKey.make(
      bundleID: candidate.app.bundleID,
      title: candidate.title,
      artist: candidate.artist,
      directURL: directURL
    ) as NSString
    traceProducer(
      producer: "FetchArtwork",
      source: source,
      title: candidate.title,
      isPlaying: candidate.isPlaying,
      details: "gen=\(generation) cacheKey='\(cacheKey)' directURL=\(String(describing: directURL))"
    )
    if let cached = artworkCache.object(forKey: cacheKey) {
      traceProducer(
        producer: "FetchArtworkCacheHit",
        source: source,
        title: candidate.title,
        isPlaying: candidate.isPlaying,
        details: "gen=\(generation) cacheKey='\(cacheKey)'"
      )
      DispatchQueue.main.async { [weak self] in
        self?.applyArtwork(cached, generation: generation)
      }
      return
    }

    if let direct = directURL {
      URLSession.shared.dataTask(with: direct) { [weak self] data, _, _ in
        if let data = data, let image = NSImage(data: data) {
          self?.artworkCache.setObject(image, forKey: cacheKey)
          DispatchQueue.main.async {
            self?.applyArtwork(image, generation: generation)
          }
        }
      }.resume()
      return
    }

    let lowerBundle = candidate.app.bundleID.lowercased()
    if lowerBundle == "com.spotify.client" {
      AppleScriptRunner.queue.async { [weak self] in
        let script =
          "tell application id \"com.spotify.client\" to get artwork url of current track"
        if let urlString = AppleScriptRunner.execute(script),
          let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines))
        {
          URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let image = NSImage(data: data) {
              self?.artworkCache.setObject(image, forKey: cacheKey)
              DispatchQueue.main.async {
                self?.applyArtwork(image, generation: generation)
              }
            }
          }.resume()
        }
      }
    } else if lowerBundle == "com.apple.music" {
      AppleScriptRunner.queue.async { [weak self] in
        guard let self = self else { return }
        let script = """
          tell application id "com.apple.Music"
              try
                  return raw data of artwork 1 of current track
              on error
                  return ""
              end try
          end tell
          """
        guard let data = AppleScriptRunner.executeData(script),
          let image = NSImage(data: data)
        else { return }
        self.artworkCache.setObject(image, forKey: cacheKey)
        DispatchQueue.main.async {
          self.applyArtwork(image, generation: generation)
        }
      }
    }
  }
}
