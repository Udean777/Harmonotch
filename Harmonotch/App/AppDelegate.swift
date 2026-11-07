import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  var statusItem: NSStatusItem?
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    URLCache.shared.diskCapacity = 25 * 1024 * 1024
    URLCache.shared.memoryCapacity = 16 * 1024 * 1024
    NotchWindowController.shared.setupAndShowWindow()
    setupStatusBarItem()
    observeUpdates()
    VolumeHUDController.shared.syncWithPreferences()

    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
      UpdateManager.shared.checkForUpdates(isUserInitiated: false)
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    VolumeHUDController.shared.stop()
    SystemAudioService.shared.stopObserving()
    MediaManager.shared.stop()
    ClamshellManager.shared.prepareForTermination()
    BatteryChargeLimiter.shared.prepareForTermination()
  }

  lazy var appLogoStatusBarImage: NSImage? = {
    guard
      let logo = NSImage(named: "AppLogo") ?? NSImage(named: NSImage.applicationIconName)
        ?? NSApplication.shared.applicationIconImage
    else { return nil }
    let targetSize = NSSize(width: 18, height: 18)
    let resized = NSImage(size: targetSize)
    resized.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let path = NSBezierPath(
      roundedRect: NSRect(origin: .zero, size: targetSize), xRadius: 4, yRadius: 4)
    path.addClip()

    logo.draw(
      in: NSRect(origin: .zero, size: targetSize),
      from: NSRect(origin: .zero, size: logo.size),
      operation: .copy,
      fraction: 1.0)
    resized.unlockFocus()
    resized.isTemplate = false
    return resized
  }()

  private func observeUpdates() {
    // Every input only exists to refresh the status bar title, so they merge
    // into one pipeline instead of one subscription each.
    let inputs: [AnyPublisher<Void, Never>] = [
      PrayerManager.shared.$nextPrayerItem.map { _ in () }.eraseToAnyPublisher(),
      AdzanPlayer.shared.$isPlaying.map { _ in () }.eraseToAnyPublisher(),
      NotchWindowController.shared.$isNotchHidden.map { _ in () }.eraseToAnyPublisher(),
      NotchViewModel.shared.$selectedTab.map { _ in () }.eraseToAnyPublisher(),
      BatteryMonitor.shared.$cycleCount.map { _ in () }.eraseToAnyPublisher(),
      LanguageManager.shared.$currentLanguage.map { _ in () }.eraseToAnyPublisher(),
      MediaManager.shared.$trackTitle.map { _ in () }.eraseToAnyPublisher(),
      MediaManager.shared.$isPlaying.map { _ in () }.eraseToAnyPublisher(),
      ThemeManager.shared.$currentMode.map { _ in () }.eraseToAnyPublisher(),
      ThemeManager.shared.$currentStyle.map { _ in () }.eraseToAnyPublisher(),
      UpdateManager.shared.$hasUpdate.map { _ in () }.eraseToAnyPublisher(),
      UpdateManager.shared.$isChecking.map { _ in () }.eraseToAnyPublisher(),
      ClamshellManager.shared.$currentState.map { _ in () }.eraseToAnyPublisher(),
      ClamshellManager.shared.$isArmed.map { _ in () }.eraseToAnyPublisher(),
      ClamshellManager.shared.$isSudoConfigured.map { _ in () }.eraseToAnyPublisher(),
    ]

    Publishers.MergeMany(inputs)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateStatusBarButton()
      }
      .store(in: &cancellables)
  }

  func updateStatusBarButton() {
    guard let button = statusItem?.button else { return }

    button.image = appLogoStatusBarImage

    let isHidden = NotchWindowController.shared.isNotchHidden
    let isPlaying = AdzanPlayer.shared.isPlaying
    let selectedTab = NotchViewModel.shared.selectedTab

    if isHidden {
      if isPlaying {
        button.title = " Adzan"
      } else if selectedTab == .media {
        let track = MediaManager.shared.trackTitle
        button.title = track.isEmpty ? "" : " \(track)"
      } else {
        button.title = ""
      }
    } else {
      button.title = ""
    }
  }
}
