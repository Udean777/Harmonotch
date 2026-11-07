import AppKit
import ServiceManagement
import SwiftUI

extension AppDelegate {
  func setupStatusBarItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
      button.image = appLogoStatusBarImage
      button.imagePosition = .imageLeading
      button.target = self
      button.action = #selector(statusBarButtonClicked(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    updateStatusBarButton()
  }

  func showContextMenu(for button: NSStatusBarButton) {
    let menu = NSMenu()
    menu.delegate = self
    menuNeedsUpdate(menu)
    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    VolumeHUDController.shared.syncWithPreferences()
    menu.removeAllItems()
    addDrawerSection(to: menu)
    menu.addItem(NSMenuItem.separator())
    addAdzanSection(to: menu)
    menu.addItem(NSMenuItem.separator())
    addSettingsSection(to: menu)
    menu.addItem(NSMenuItem.separator())
    addUpdateSection(to: menu)
    addFooterSection(to: menu)
  }

  func addDrawerSection(to menu: NSMenu) {
    let headerItem = NSMenuItem()
    let hostingView = NSHostingView(rootView: MenuBarHeaderView())
    hostingView.frame = NSRect(x: 0, y: 0, width: 250, height: 44)
    headerItem.view = hostingView
    menu.addItem(headerItem)

    menu.addItem(NSMenuItem.separator())

    let isExpanded = NotchViewModel.shared.isExpanded
    let toggleItem = NSMenuItem(
      title: isExpanded ? L10n.Menu.closeDrawer : L10n.Menu.openDrawer,
      action: #selector(toggleNotchDrawer),
      keyEquivalent: "n"
    )
    toggleItem.target = self
    toggleItem.image = NSImage(
      systemSymbolName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill",
      accessibilityDescription: nil)
    menu.addItem(toggleItem)

    let isHidden = NotchWindowController.shared.isNotchHidden
    let hideTitle = isHidden ? L10n.Menu.showNotch : L10n.Menu.hideNotch
    let hideItem = NSMenuItem(
      title: hideTitle, action: #selector(toggleNotchVisibility), keyEquivalent: "h")
    hideItem.target = self
    hideItem.image = NSImage(
      systemSymbolName: isHidden ? "eye.fill" : "eye.slash.fill", accessibilityDescription: nil)
    menu.addItem(hideItem)

    let tabsItem = NSMenuItem(title: L10n.Menu.tabsMenu, action: nil, keyEquivalent: "")
    tabsItem.image = NSImage(
      systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: nil)
    tabsItem.submenu = buildTabsSubmenu()
    menu.addItem(tabsItem)
  }

  func buildTabsSubmenu() -> NSMenu {
    let tabsSubmenu = NSMenu()
    let currentTab = NotchViewModel.shared.selectedTab

    let prayerTabItem = NSMenuItem(
      title: L10n.Drawer.prayerTab, action: #selector(selectTabPrayer), keyEquivalent: "1")
    prayerTabItem.target = self
    prayerTabItem.image = NSImage(
      systemSymbolName: "moon.stars.fill", accessibilityDescription: nil)
    prayerTabItem.state = (currentTab == .prayer) ? .on : .off
    tabsSubmenu.addItem(prayerTabItem)

    let batteryTabItem = NSMenuItem(
      title: L10n.Drawer.batteryTab, action: #selector(selectTabBattery), keyEquivalent: "2")
    batteryTabItem.target = self
    batteryTabItem.image = NSImage(
      systemSymbolName: "bolt.batteryblock.fill", accessibilityDescription: nil)
    batteryTabItem.state = (currentTab == .battery) ? .on : .off
    tabsSubmenu.addItem(batteryTabItem)

    let mediaTabItem = NSMenuItem(
      title: L10n.Drawer.mediaTab, action: #selector(selectTabMedia), keyEquivalent: "3")
    mediaTabItem.target = self
    mediaTabItem.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
    mediaTabItem.state = (currentTab == .media) ? .on : .off
    tabsSubmenu.addItem(mediaTabItem)

    return tabsSubmenu
  }

  func addAdzanSection(to menu: NSMenu) {
    let muteTitle = AdzanPlayer.shared.isMuted ? L10n.Menu.unmuteAdzan : L10n.Menu.muteAdzan
    let muteItem = NSMenuItem(
      title: muteTitle, action: #selector(toggleAdzanMute), keyEquivalent: "m")
    muteItem.target = self
    muteItem.image = NSImage(
      systemSymbolName: AdzanPlayer.shared.isMuted ? "bell.slash.fill" : "bell.fill",
      accessibilityDescription: nil)
    menu.addItem(muteItem)

    let adzanText = AdzanPlayer.shared.isPlaying ? L10n.Menu.stopAdzan : L10n.Menu.testAdzan
    let testAdzanItem = NSMenuItem(
      title: adzanText, action: #selector(toggleTestAdzan), keyEquivalent: "t")
    testAdzanItem.target = self
    testAdzanItem.image = NSImage(
      systemSymbolName: AdzanPlayer.shared.isPlaying ? "stop.fill" : "play.fill",
      accessibilityDescription: nil)
    menu.addItem(testAdzanItem)
  }

  func addSettingsSection(to menu: NSMenu) {
    let langItem = NSMenuItem(title: L10n.Menu.languageMenu, action: nil, keyEquivalent: "")
    langItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
    langItem.submenu = buildLanguageSubmenu()
    menu.addItem(langItem)

    let isLaunchAtLogin = SMAppService.mainApp.status == .enabled
    let launchItem = NSMenuItem(
      title: L10n.Menu.launchAtLogin,
      action: #selector(toggleLaunchAtLogin),
      keyEquivalent: ""
    )
    launchItem.target = self
    launchItem.image = NSImage(
      systemSymbolName: "arrow.up.forward.app", accessibilityDescription: nil)
    launchItem.state = isLaunchAtLogin ? .on : .off
    menu.addItem(launchItem)

    let isVolumeHUDEnabled = UserDefaults.standard[UserDefaultsKeys.volumeHUDEnabled]
    let volumeHUDItem = NSMenuItem(
      title: L10n.Menu.volumeHUDToggle,
      action: #selector(toggleVolumeHUD),
      keyEquivalent: ""
    )
    volumeHUDItem.target = self
    volumeHUDItem.image = NSImage(
      systemSymbolName: isVolumeHUDEnabled ? "speaker.wave.2.fill" : "speaker.wave.2",
      accessibilityDescription: nil
    )
    volumeHUDItem.state = isVolumeHUDEnabled ? .on : .off
    menu.addItem(volumeHUDItem)

    let isIncludeOther = MediaManager.shared.includeOtherAudioApps
    let includeOtherItem = NSMenuItem(
      title: L10n.Media.includeOtherAudioApps,
      action: #selector(toggleIncludeOtherAudioApps),
      keyEquivalent: ""
    )
    includeOtherItem.target = self
    includeOtherItem.image = NSImage(
      systemSymbolName: isIncludeOther ? "waveform.badge.plus" : "waveform",
      accessibilityDescription: nil
    )
    includeOtherItem.state = isIncludeOther ? .on : .off
    menu.addItem(includeOtherItem)

    let clamshellState = ClamshellManager.shared.currentState
    let clamshellTitle: String = clamshellState == .off
      ? L10n.Menu.clamshellToggle
      : "\(L10n.Menu.clamshellToggle) (\(ClamshellPresentation.statusLabel(for: clamshellState)))"
    let clamshellIcon = ClamshellPresentation.iconName(for: clamshellState)

    let clamshellItem = NSMenuItem(
      title: clamshellTitle,
      action: #selector(toggleClamshellStayAwake),
      keyEquivalent: ""
    )
    clamshellItem.target = self
    clamshellItem.image = NSImage(systemSymbolName: clamshellIcon, accessibilityDescription: nil)
    clamshellItem.state = ClamshellManager.shared.isArmed ? .on : .off
    clamshellItem.isEnabled = !ClamshellManager.shared.isPerformingSetup
    menu.addItem(clamshellItem)

    if !ClamshellManager.shared.isSudoConfigured {
      let setupTitle = ClamshellManager.shared.isPerformingSetup
        ? L10n.Clamshell.authorizing
        : L10n.Clamshell.menuSetupAction
      let setupItem = NSMenuItem(
        title: setupTitle,
        action: #selector(setupClamshellPermissionFromMenu),
        keyEquivalent: ""
      )
      setupItem.target = self
      setupItem.image = NSImage(
        systemSymbolName: "lock.open.fill", accessibilityDescription: nil)
      setupItem.isEnabled = !ClamshellManager.shared.isPerformingSetup
      menu.addItem(setupItem)
    }
  }

  func buildLanguageSubmenu() -> NSMenu {
    let langSubmenu = NSMenu()
    for lang in AppLanguage.allCases {
      let item = NSMenuItem(
        title: lang.displayName,
        action: #selector(AppDelegate.switchLanguage(_:)),
        keyEquivalent: ""
      )
      item.target = self
      item.representedObject = lang
      item.state =
        (LanguageManager.shared.currentLanguage == lang)
        ? NSControl.StateValue.on : NSControl.StateValue.off
      langSubmenu.addItem(item)
    }
    return langSubmenu
  }

  func addUpdateSection(to menu: NSMenu) {
    if case .readyToQuit(let version) = UpdateManager.shared.state {
      let readyItem = NSMenuItem(
        title: "\(L10n.Update.readyToQuitTitle(version: version)) - \(L10n.Update.restartApp)",
        action: #selector(restartAfterUpdate),
        keyEquivalent: ""
      )
      readyItem.target = self
      readyItem.image = NSImage(
        systemSymbolName: "arrow.clockwise.circle.fill", accessibilityDescription: nil)
      menu.addItem(readyItem)
    } else if UpdateManager.shared.hasUpdate {
      let updateItem = NSMenuItem(
        title: L10n.Menu.updateAvailable(version: UpdateManager.shared.latestVersion),
        action: nil,
        keyEquivalent: ""
      )
      updateItem.image = NSImage(
        systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)

      let updateSubmenu = NSMenu()
      let downloadItem = NSMenuItem(
        title: L10n.Update.updateNow,
        action: #selector(downloadUpdateDMG),
        keyEquivalent: ""
      )
      downloadItem.target = self
      downloadItem.image = NSImage(
        systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
      updateSubmenu.addItem(downloadItem)

      let notesItem = NSMenuItem(
        title: L10n.Menu.viewReleaseNotesAction,
        action: #selector(openReleaseNotes),
        keyEquivalent: ""
      )
      notesItem.target = self
      notesItem.image = NSImage(systemSymbolName: "safari.fill", accessibilityDescription: nil)
      updateSubmenu.addItem(notesItem)

      updateItem.submenu = updateSubmenu
      menu.addItem(updateItem)
    } else {
      let checkUpdateItem = NSMenuItem(
        title: UpdateManager.shared.isChecking ? L10n.Update.checking : L10n.Menu.checkForUpdates,
        action: #selector(checkForUpdatesManual),
        keyEquivalent: "u"
      )
      checkUpdateItem.target = self
      checkUpdateItem.image = NSImage(
        systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
      checkUpdateItem.isEnabled = !UpdateManager.shared.isChecking
      menu.addItem(checkUpdateItem)
    }
  }

  func addFooterSection(to menu: NSMenu) {
    let aboutItem = NSMenuItem(
      title: L10n.Menu.aboutHarmonotch, action: #selector(showAboutWindow), keyEquivalent: "")
    aboutItem.target = self
    aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
    menu.addItem(aboutItem)

    let quitItem = NSMenuItem(title: L10n.Menu.quit, action: #selector(quitApp), keyEquivalent: "q")
    quitItem.target = self
    quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
    menu.addItem(quitItem)
  }
}

private struct MenuBarHeaderView: View {
  @ObservedObject var adzanPlayer = AdzanPlayer.shared
  @ObservedObject var mediaManager = MediaManager.shared
  @ObservedObject var updateManager = UpdateManager.shared

  var body: some View {
    HStack(spacing: 10) {
      Group {
        if let nsImage = NSImage(named: "AppLogo") ?? NSImage(named: NSImage.applicationIconName)
          ?? NSApplication.shared.applicationIconImage
        {
          Image(nsImage: nsImage)
            .resizable()
        } else {
          Image("AppLogo")
            .resizable()
        }
      }
      .aspectRatio(contentMode: .fit)
      .frame(width: 30, height: 30)
      .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
      )

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Text("Harmonotch")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)

          if updateManager.hasUpdate {
            Text("v\(updateManager.latestVersion)")
              .font(.system(size: 9, weight: .semibold))
              .foregroundColor(.white)
              .padding(.horizontal, 4)
              .padding(.vertical, 1)
              .background(Color.white.opacity(0.15))
              .clipShape(Capsule())
          }
        }

        if adzanPlayer.isPlaying {
          HStack(spacing: 4) {
            Image(systemName: "speaker.wave.3.fill")
              .font(.system(size: 8))
            Text(L10n.Prayer.adzanActive)
              .font(.system(size: 10, weight: .medium))
          }
          .foregroundColor(.white)
        } else if mediaManager.isPlaying && !mediaManager.trackTitle.isEmpty {
          HStack(spacing: 4) {
            Image(systemName: "waveform")
              .font(.system(size: 8))
            Text(mediaManager.trackTitle)
              .font(.system(size: 10, weight: .medium))
              .lineLimit(1)
          }
          .foregroundColor(.white)
        } else if updateManager.hasUpdate {
          Text(L10n.Update.available)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
        } else {
          Text(L10n.Menu.headerSubtitle)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textTertiary)
        }
      }

      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .frame(width: 250, height: 44)
  }
}
