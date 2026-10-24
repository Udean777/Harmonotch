import AppKit
import SwiftUI
import Combine
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotchWindowController.shared.setupAndShowWindow()
        setupStatusBarItem()
        observeUpdates()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            UpdateManager.shared.checkForUpdates(isUserInitiated: false)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClamshellManager.shared.prepareForTermination()
    }

    private lazy var appLogoStatusBarImage: NSImage? = {
        guard let logo = NSImage(named: "AppLogo") ?? NSImage(named: NSImage.applicationIconName) ?? NSApplication.shared.applicationIconImage else { return nil }
        let targetSize = NSSize(width: 18, height: 18)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: targetSize), xRadius: 4, yRadius: 4)
        path.addClip()

        logo.draw(in: NSRect(origin: .zero, size: targetSize),
                  from: NSRect(origin: .zero, size: logo.size),
                  operation: .copy,
                  fraction: 1.0)
        resized.unlockFocus()
        resized.isTemplate = false
        return resized
    }()

    private func setupStatusBarItem() {
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

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
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

    private func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.delegate = self
        menuNeedsUpdate(menu)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

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
            ClamshellManager.shared.$isArmed.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(inputs)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarButton()
            }
            .store(in: &cancellables)
    }

    private func updateStatusBarButton() {
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

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

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
        toggleItem.image = NSImage(systemSymbolName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill", accessibilityDescription: nil)
        menu.addItem(toggleItem)

        let isHidden = NotchWindowController.shared.isNotchHidden
        let hideTitle = isHidden ? L10n.Menu.showNotch : L10n.Menu.hideNotch
        let hideItem = NSMenuItem(title: hideTitle, action: #selector(toggleNotchVisibility), keyEquivalent: "h")
        hideItem.target = self
        hideItem.image = NSImage(systemSymbolName: isHidden ? "eye.fill" : "eye.slash.fill", accessibilityDescription: nil)
        menu.addItem(hideItem)

        let tabsItem = NSMenuItem(title: L10n.Menu.tabsMenu, action: nil, keyEquivalent: "")
        tabsItem.image = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: nil)
        let tabsSubmenu = NSMenu()

        let currentTab = NotchViewModel.shared.selectedTab

        let prayerTabItem = NSMenuItem(title: L10n.Drawer.prayerTab, action: #selector(selectTabPrayer), keyEquivalent: "1")
        prayerTabItem.target = self
        prayerTabItem.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: nil)
        prayerTabItem.state = (currentTab == .prayer) ? .on : .off
        tabsSubmenu.addItem(prayerTabItem)

        let batteryTabItem = NSMenuItem(title: L10n.Drawer.batteryTab, action: #selector(selectTabBattery), keyEquivalent: "2")
        batteryTabItem.target = self
        batteryTabItem.image = NSImage(systemSymbolName: "bolt.batteryblock.fill", accessibilityDescription: nil)
        batteryTabItem.state = (currentTab == .battery) ? .on : .off
        tabsSubmenu.addItem(batteryTabItem)

        let mediaTabItem = NSMenuItem(title: L10n.Drawer.mediaTab, action: #selector(selectTabMedia), keyEquivalent: "3")
        mediaTabItem.target = self
        mediaTabItem.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        mediaTabItem.state = (currentTab == .media) ? .on : .off
        tabsSubmenu.addItem(mediaTabItem)

        tabsItem.submenu = tabsSubmenu
        menu.addItem(tabsItem)

        menu.addItem(NSMenuItem.separator())

        let muteTitle = AdzanPlayer.shared.isMuted ? L10n.Menu.unmuteAdzan : L10n.Menu.muteAdzan
        let muteItem = NSMenuItem(title: muteTitle, action: #selector(toggleAdzanMute), keyEquivalent: "m")
        muteItem.target = self
        muteItem.image = NSImage(systemSymbolName: AdzanPlayer.shared.isMuted ? "bell.slash.fill" : "bell.fill", accessibilityDescription: nil)
        menu.addItem(muteItem)

        let adzanText = AdzanPlayer.shared.isPlaying ? L10n.Menu.stopAdzan : L10n.Menu.testAdzan
        let testAdzanItem = NSMenuItem(title: adzanText, action: #selector(toggleTestAdzan), keyEquivalent: "t")
        testAdzanItem.target = self
        testAdzanItem.image = NSImage(systemSymbolName: AdzanPlayer.shared.isPlaying ? "stop.fill" : "play.fill", accessibilityDescription: nil)
        menu.addItem(testAdzanItem)

        menu.addItem(NSMenuItem.separator())

        let langItem = NSMenuItem(title: L10n.Menu.languageMenu, action: nil, keyEquivalent: "")
        langItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        let langSubmenu = NSMenu()
        for lang in AppLanguage.allCases {
            let item = NSMenuItem(
                title: lang.displayName,
                action: #selector(AppDelegate.switchLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = lang
            item.state = (LanguageManager.shared.currentLanguage == lang) ? NSControl.StateValue.on : NSControl.StateValue.off
            langSubmenu.addItem(item)
        }
        langItem.submenu = langSubmenu
        menu.addItem(langItem)

        let themeItem = NSMenuItem(title: L10n.Theme.themeMenu, action: nil, keyEquivalent: "")
        themeItem.image = NSImage(systemSymbolName: "paintpalette.fill", accessibilityDescription: nil)
        let themeSubmenu = NSMenu()

        let styleHeader = NSMenuItem(title: L10n.Theme.designStyleSection, action: nil, keyEquivalent: "")
        styleHeader.isEnabled = false
        themeSubmenu.addItem(styleHeader)

        for style in ThemeStyle.allCases {
            let title: String
            switch style {
            case .liquidGlass:
                title = L10n.Theme.liquidGlass
            case .zenSerenity:
                title = L10n.Theme.zenSerenity
            }
            let item = NSMenuItem(
                title: title,
                action: #selector(AppDelegate.switchThemeStyle(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = style
            item.image = NSImage(systemSymbolName: style.icon, accessibilityDescription: nil)
            item.state = (ThemeManager.shared.currentStyle == style) ? NSControl.StateValue.on : NSControl.StateValue.off
            themeSubmenu.addItem(item)
        }

        themeSubmenu.addItem(NSMenuItem.separator())

        let appearanceHeader = NSMenuItem(title: L10n.Theme.appearanceSection, action: nil, keyEquivalent: "")
        appearanceHeader.isEnabled = false
        themeSubmenu.addItem(appearanceHeader)

        for mode in AppThemeMode.allCases {
            let title: String
            switch mode {
            case .system:
                title = L10n.Theme.system
            case .dark:
                title = L10n.Theme.dark
            case .light:
                title = L10n.Theme.light
            }
            let item = NSMenuItem(
                title: title,
                action: #selector(AppDelegate.switchTheme(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode
            item.image = NSImage(systemSymbolName: mode.icon, accessibilityDescription: nil)
            item.state = (ThemeManager.shared.currentMode == mode) ? NSControl.StateValue.on : NSControl.StateValue.off
            themeSubmenu.addItem(item)
        }
        themeItem.submenu = themeSubmenu
        menu.addItem(themeItem)

        let isLaunchAtLogin = SMAppService.mainApp.status == .enabled
        let launchItem = NSMenuItem(
            title: L10n.Menu.launchAtLogin,
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.image = NSImage(systemSymbolName: "arrow.up.forward.app", accessibilityDescription: nil)
        launchItem.state = isLaunchAtLogin ? .on : .off
        menu.addItem(launchItem)

        let clamshellState = ClamshellManager.shared.currentState
        let clamshellTitle: String
        let clamshellIcon: String
        switch clamshellState {
        case .active:
            clamshellTitle = "\(L10n.Menu.clamshellToggle) (\(L10n.Clamshell.active))"
            clamshellIcon = "display.2"
        case .standby:
            clamshellTitle = "\(L10n.Menu.clamshellToggle) (\(L10n.Clamshell.standby))"
            clamshellIcon = "display.trianglebadge.exclamationmark"
        case .pausedLowBattery:
            clamshellTitle = "\(L10n.Menu.clamshellToggle) (\(L10n.Clamshell.pausedLowBattery))"
            clamshellIcon = "bolt.slash"
        case .off:
            clamshellTitle = L10n.Menu.clamshellToggle
            clamshellIcon = "display"
        }

        let clamshellItem = NSMenuItem(
            title: clamshellTitle,
            action: #selector(toggleClamshellStayAwake),
            keyEquivalent: ""
        )
        clamshellItem.target = self
        clamshellItem.image = NSImage(systemSymbolName: clamshellIcon, accessibilityDescription: nil)
        clamshellItem.state = ClamshellManager.shared.isArmed ? .on : .off
        menu.addItem(clamshellItem)

        menu.addItem(NSMenuItem.separator())

        if UpdateManager.shared.hasUpdate {
            let updateItem = NSMenuItem(
                title: L10n.Menu.updateAvailable(version: UpdateManager.shared.latestVersion),
                action: nil,
                keyEquivalent: ""
            )
            updateItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)

            let updateSubmenu = NSMenu()
            let downloadItem = NSMenuItem(
                title: L10n.Menu.downloadDMGAction,
                action: #selector(downloadUpdateDMG),
                keyEquivalent: ""
            )
            downloadItem.target = self
            downloadItem.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
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
            checkUpdateItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
            checkUpdateItem.isEnabled = !UpdateManager.shared.isChecking
            menu.addItem(checkUpdateItem)
        }

        let aboutItem = NSMenuItem(title: L10n.Menu.aboutHarmonotch, action: #selector(showAboutWindow), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: L10n.Menu.quit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)
    }

    @objc private func selectTabPrayer() {
        NotchViewModel.shared.selectedTab = .prayer
        NotchViewModel.shared.isExpanded = true
        updateStatusBarButton()
    }

    @objc private func selectTabBattery() {
        NotchViewModel.shared.selectedTab = .battery
        NotchViewModel.shared.isExpanded = true
        updateStatusBarButton()
    }

    @objc private func selectTabMedia() {
        NotchViewModel.shared.selectedTab = .media
        NotchViewModel.shared.isExpanded = true
        updateStatusBarButton()
    }

    @objc private func toggleAdzanMute() {
        AdzanPlayer.shared.isMuted.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("[Harmonotch] Failed to toggle launch at login: \(error)")
        }
    }

    @objc private func showAboutWindow() {
        AboutWindowController.shared.show()
    }

    @objc func switchLanguage(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? AppLanguage else { return }
        LanguageManager.shared.setLanguage(lang)
        updateStatusBarButton()
    }

    @objc func switchTheme(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? AppThemeMode else { return }
        ThemeManager.shared.setTheme(mode)
        updateStatusBarButton()
    }

    @objc func switchThemeStyle(_ sender: NSMenuItem) {
        guard let style = sender.representedObject as? ThemeStyle else { return }
        ThemeManager.shared.setThemeStyle(style)
        updateStatusBarButton()
    }

    @objc private func toggleNotchDrawer() {
        NotchViewModel.shared.toggleExpanded()
    }

    @objc private func toggleNotchVisibility() {
        NotchWindowController.shared.toggleNotchHidden()
    }

    @objc private func toggleTestAdzan() {
        AdzanPlayer.shared.testPlay()
    }

    @objc private func checkForUpdatesManual() {
        UpdateManager.shared.checkForUpdates(isUserInitiated: true)
    }

    @objc private func downloadUpdateDMG() {
        UpdateManager.shared.downloadLatestDMG()
    }

    @objc private func openReleaseNotes() {
        UpdateManager.shared.openReleasePage()
    }

    @objc private func toggleClamshellStayAwake() {
        ClamshellManager.shared.isArmed.toggle()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

private struct MenuBarHeaderView: View {
    @ObservedObject var adzanPlayer = AdzanPlayer.shared
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var updateManager = UpdateManager.shared

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let nsImage = NSImage(named: "AppLogo") ?? NSImage(named: NSImage.applicationIconName) ?? NSApplication.shared.applicationIconImage {
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
                    .stroke(AppTheme.accentAmber.opacity(0.3), lineWidth: 0.8)
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Harmonotch")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)

                    if updateManager.hasUpdate {
                        Text("v\(updateManager.latestVersion)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppTheme.accentAmber)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppTheme.accentAmber.opacity(0.15))
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
                    .foregroundColor(AppTheme.accentGreen)
                } else if mediaManager.isPlaying && !mediaManager.trackTitle.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: 8))
                        Text(mediaManager.trackTitle)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(AppTheme.accentAmber)
                } else if updateManager.hasUpdate {
                    Text(L10n.Update.available)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.accentAmber)
                } else {
                    Text(themeManager.currentStyle == .liquidGlass ? "Liquid Glass" : "Zen Serenity")
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
