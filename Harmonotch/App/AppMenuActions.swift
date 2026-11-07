import AppKit
import ServiceManagement

extension AppDelegate {
  @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else {
      MenuBarPanelController.shared.toggle(relativeTo: sender)
      return
    }

    if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
      showContextMenu(for: sender)
    } else {
      MenuBarPanelController.shared.toggle(relativeTo: sender)
    }
  }

  @objc func selectTabPrayer() {
    NotchViewModel.shared.selectedTab = .prayer
    NotchViewModel.shared.isExpanded = true
    updateStatusBarButton()
  }

  @objc func selectTabBattery() {
    NotchViewModel.shared.selectedTab = .battery
    NotchViewModel.shared.isExpanded = true
    updateStatusBarButton()
  }

  @objc func selectTabMedia() {
    NotchViewModel.shared.selectedTab = .media
    NotchViewModel.shared.isExpanded = true
    updateStatusBarButton()
  }

  @objc func selectTabAgents() {
    NotchViewModel.shared.selectedTab = .agents
    NotchViewModel.shared.isExpanded = true
    updateStatusBarButton()
  }

  @objc func switchNotchAIAgent(_ sender: NSMenuItem) {
    guard let raw = sender.representedObject as? String else { return }
    UserDefaults.standard[UserDefaultsKeys.selectedNotchAIAgent] = raw
    NotificationCenter.default.post(name: .notchAIAgentChanged, object: raw)
    updateStatusBarButton()
  }

  @objc func toggleAdzanMute() {
    AdzanPlayer.shared.isMuted.toggle()
  }

  @objc func toggleLaunchAtLogin() {
    do {
      if SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
      } else {
        try SMAppService.mainApp.register()
      }
    } catch {
      NSLog("[Harmonotch:App] Failed to toggle launch at login: %@", error.localizedDescription)
    }
  }

  @objc func showAboutWindow() {
    AboutWindowController.shared.show()
  }

  @objc func switchLanguage(_ sender: NSMenuItem) {
    guard let lang = sender.representedObject as? AppLanguage else { return }
    LanguageManager.shared.setLanguage(lang)
    updateStatusBarButton()
  }

  @objc func toggleNotchDrawer() {
    NotchViewModel.shared.toggleExpanded()
  }

  @objc func toggleNotchVisibility() {
    NotchWindowController.shared.toggleNotchHidden()
    if NotchWindowController.shared.isNotchHidden {
      NotchViewModel.shared.dismissVolumeNotice()
    }
  }

  @objc func toggleVolumeHUD() {
    let nextEnabled = !UserDefaults.standard[UserDefaultsKeys.volumeHUDEnabled]
    VolumeHUDController.shared.setEnabled(nextEnabled, promptIfUntrusted: true)
  }

  @objc func toggleIncludeOtherAudioApps() {
    MediaManager.shared.includeOtherAudioApps.toggle()
  }

  @objc func toggleTestAdzan() {
    AdzanPlayer.shared.testPlay()
  }

  @objc func checkForUpdatesManual() {
    UpdateManager.shared.checkForUpdates(isUserInitiated: true)
  }

  @objc func downloadUpdateDMG() {
    UpdateManager.shared.downloadAndInstallUpdate()
  }

  @objc func restartAfterUpdate() {
    UpdateManager.shared.quitAfterUpdate(relaunch: true)
  }

  @objc func openReleaseNotes() {
    UpdateManager.shared.openReleasePage()
  }

  @objc func toggleClamshellStayAwake() {
    ClamshellManager.shared.isArmed.toggle()
  }

  @objc func setupClamshellPermissionFromMenu() {
    NotchViewModel.shared.selectedTab = .battery
    NotchViewModel.shared.isExpanded = true
    ClamshellManager.shared.setupPasswordlessSudo { _ in }
  }

  @objc func quitApp() {
    NSApplication.shared.terminate(nil)
  }
}
