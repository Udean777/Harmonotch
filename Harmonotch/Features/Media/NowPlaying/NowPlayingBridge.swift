import Foundation

/// Owns the `/usr/bin/perl` child that loads the MediaRemote adapter and speaks
/// newline-delimited JSON with it. Restarts it if it dies; stays quiet (and
/// unavailable) when the resources are missing so AppleScript keeps working.
final class NowPlayingBridge {
  /// Called on a private queue for every state line.
  var onState: ((NowPlayingState) -> Void)?

  private let queue = DispatchQueue(label: "com.harmonotch.nowplaying.bridge")
  private var process: Process?
  private var stdinHandle: FileHandle?
  private var buffer = Data()
  private var pending: [String: (Bool) -> Void] = [:]
  private var restartDelay: TimeInterval = 0.5
  private var stopped = false

  var isAvailable: Bool {
    queue.sync { process?.isRunning == true }
  }

  func start() {
    queue.async { [weak self] in self?.startLocked() }
  }

  private func startLocked() {
    guard !stopped, process == nil else { return }
    guard
      let script = Bundle.main.url(forResource: "nowplaying", withExtension: "pl"),
      let dylib = Bundle.main.privateFrameworksURL?
        .appendingPathComponent("libHarmonotchNowPlaying.dylib"),
      FileManager.default.fileExists(atPath: dylib.path)
    else {
      NSLog("[Harmonotch:NowPlaying] bridge resources missing; using AppleScript")
      return
    }

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
    proc.arguments = [script.path, dylib.path]

    let input = Pipe()
    let output = Pipe()
    let errors = Pipe()
    proc.standardInput = input
    proc.standardOutput = output
    proc.standardError = errors

    output.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard let self = self, !data.isEmpty else { return }
      self.queue.async { self.consume(data) }
    }
    errors.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      guard let text = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty
      else { return }
      NSLog("[Harmonotch:NowPlaying] %@", text)
    }
    proc.terminationHandler = { [weak self] _ in
      self?.queue.async { self?.handleTermination() }
    }

    do {
      try proc.run()
    } catch {
      NSLog("[Harmonotch:NowPlaying] cannot start bridge: %@", error.localizedDescription)
      return
    }

    process = proc
    stdinHandle = input.fileHandleForWriting
    buffer.removeAll()
  }

  private func handleTermination() {
    process = nil
    stdinHandle = nil
    buffer.removeAll()
    let waiting = Array(pending.values)
    pending.removeAll()
    for callback in waiting { callback(false) }

    guard !stopped else { return }
    let delay = restartDelay
    restartDelay = min(restartDelay * 2, 5)
    queue.asyncAfter(deadline: .now() + delay) { [weak self] in
      self?.startLocked()
    }
  }

  private func consume(_ data: Data) {
    buffer.append(data)
    while let newline = buffer.firstIndex(of: 0x0A) {
      let line = buffer[buffer.startIndex..<newline]
      buffer.removeSubrange(buffer.startIndex...newline)
      guard !line.isEmpty,
        let event = try? JSONDecoder().decode(NowPlayingEvent.self, from: Data(line))
      else { continue }

      switch event {
      case .state(let state):
        restartDelay = 0.5
        onState?(state)
      case .result(let id, let ok):
        pending.removeValue(forKey: id)?(ok)
      case .error(let message):
        NSLog("[Harmonotch:NowPlaying] adapter error: %@", message)
      }
    }
  }

  /// Sends one command and calls `completion` with the adapter's answer, or
  /// `false` after 400 ms or when the process is not running.
  func send(_ command: [String: Any], completion: ((Bool) -> Void)? = nil) {
    queue.async { [weak self] in
      guard let self = self else {
        completion?(false)
        return
      }
      guard let payload = try? JSONSerialization.data(withJSONObject: command),
        self.process?.isRunning == true, let stdinHandle = self.stdinHandle
      else {
        completion?(false)
        return
      }

      var line = payload
      line.append(0x0A)
      do {
        try stdinHandle.write(contentsOf: line)
      } catch {
        completion?(false)
        return
      }

      guard let id = command["id"] as? String, let completion = completion else { return }
      self.pending[id] = completion
      self.queue.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard let self = self, let callback = self.pending.removeValue(forKey: id) else { return }
        callback(false)
      }
    }
  }

  /// Stops the child so it does not outlive the app.
  func stop() {
    queue.sync {
      stopped = true
      process?.terminationHandler = nil
      if process?.isRunning == true { process?.terminate() }
      process = nil
      stdinHandle = nil
      for callback in pending.values { callback(false) }
      pending.removeAll()
    }
  }
}
