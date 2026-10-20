//
//  AppDelegate.swift
//  Harmonotch
//

import AppKit
import SwiftUI
import Combine
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Inisialisasi floating window di notch
        NotchWindowController.shared.setupAndShowWindow()

        // Buat Menu Bar icon pendukung
        setupStatusBarItem()

        // Amati perubahan untuk update tampilan status bar item
        observeUpdates()
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Harmonotch")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading // Standar Apple HIG: Icon di KIRI, Teks di KANAN
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu

        updateStatusBarButton()
    }

    // MARK: - Reactive Menu Bar Update
    private func observeUpdates() {
        Publishers.CombineLatest4(
            PrayerManager.shared.$nextPrayerItem,
            AdzanPlayer.shared.$isPlaying,
            NotchWindowController.shared.$isNotchHidden,
            NotchViewModel.shared.$selectedTab
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateStatusBarButton()
        }
        .store(in: &cancellables)

        BatteryMonitor.shared.$cycleCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarButton()
            }
            .store(in: &cancellables)

        LanguageManager.shared.$currentLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarButton()
            }
            .store(in: &cancellables)

        MediaManager.shared.$trackTitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarButton()
            }
            .store(in: &cancellables)

        MediaManager.shared.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarButton()
            }
            .store(in: &cancellables)

        ThemeManager.shared.$currentMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarButton()
            }
            .store(in: &cancellables)

        ThemeManager.shared.$currentStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarButton()
            }
            .store(in: &cancellables)
    }

    private func updateStatusBarButton() {
        guard let button = statusItem?.button else { return }

        let isHidden = NotchWindowController.shared.isNotchHidden
        let isPlaying = AdzanPlayer.shared.isPlaying
        let selectedTab = NotchViewModel.shared.selectedTab

        // 1. Icon: Gunakan monitor/MacBook saat mode baterai aktif, waveform/music saat mode media aktif
        if isPlaying {
            button.image = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: "Adzan")
        } else if selectedTab == .battery {
            button.image = NSImage(systemSymbolName: "macbook", accessibilityDescription: "Harmonotch Hardware")
        } else if selectedTab == .media {
            let isMediaPlaying = MediaManager.shared.isPlaying
            button.image = NSImage(systemSymbolName: isMediaPlaying ? "waveform" : "music.note", accessibilityDescription: "Harmonotch Media")
        } else {
            button.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Harmonotch Prayer")
        }
        button.image?.isTemplate = true

        // 2. Teks waktu/siklus/lagu: Hanya muncul jika Notch sedang di-hide
        if isHidden {
            if isPlaying {
                button.title = " Adzan \(L10n.Prayer.localizedPrayerName(AdzanPlayer.shared.playingPrayerName))"
            } else if selectedTab == .prayer, let next = PrayerManager.shared.nextPrayerItem {
                button.title = " \(next.name) \(next.timeString)"
            } else if selectedTab == .battery {
                button.title = " \(BatteryMonitor.shared.cycleCount) \(L10n.Menu.cyclesSuffix)"
            } else if selectedTab == .media {
                let track = MediaManager.shared.trackTitle
                button.title = track.isEmpty ? "" : " \(track)"
            } else {
                button.title = ""
            }
        } else {
            // Ketika notch muncul di layar, tampilkan ICON SAJA
            button.title = ""
        }
    }

    // MARK: - NSMenuDelegate (Dynamic Menu Construction)
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let titleItem = NSMenuItem(title: L10n.Menu.appTitle, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle Notch Drawer
        let toggleItem = NSMenuItem(
            title: NotchViewModel.shared.isExpanded ? L10n.Menu.closeDrawer : L10n.Menu.openDrawer,
            action: #selector(toggleNotchDrawer),
            keyEquivalent: "n"
        )
        toggleItem.target = self
        toggleItem.image = NSImage(systemSymbolName: "menubar.dock.rectangle", accessibilityDescription: nil)
        menu.addItem(toggleItem)

        // Opsi Sembunyikan / Tampilkan Notch di Layar
        let isHidden = NotchWindowController.shared.isNotchHidden
        let hideTitle = isHidden ? L10n.Menu.showNotch : L10n.Menu.hideNotch
        let hideItem = NSMenuItem(title: hideTitle, action: #selector(toggleNotchVisibility), keyEquivalent: "h")
        hideItem.target = self
        hideItem.image = NSImage(systemSymbolName: isHidden ? "eye" : "eye.slash", accessibilityDescription: nil)
        menu.addItem(hideItem)

        // Submenu Ganti Bahasa
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

        // Submenu Pilihan Tema
        let themeItem = NSMenuItem(title: L10n.Theme.themeMenu, action: nil, keyEquivalent: "")
        themeItem.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)
        let themeSubmenu = NSMenu()

        // 1. Seksi Gaya Desain (Design Style)
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

        // 2. Seksi Mode Tampilan (Appearance Mode)
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

        // Launch at Login Toggle
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

        menu.addItem(NSMenuItem.separator())

        // Info Lokasi
        let locItem = NSMenuItem(title: "\(L10n.Menu.locationPrefix)\(PrayerManager.shared.currentLocationName)", action: nil, keyEquivalent: "")
        locItem.isEnabled = false
        locItem.image = NSImage(systemSymbolName: "mappin.and.ellipse", accessibilityDescription: nil)
        menu.addItem(locItem)

        // Daftar 5 Waktu Sholat di Menu
        for prayer in PrayerManager.shared.prayerItems {
            let indicator = prayer.isNext ? L10n.Menu.nextTag : (prayer.isCurrent ? L10n.Menu.nowTag : "")
            let pItem = NSMenuItem(
                title: "\(prayer.name) — \(prayer.timeString)\(indicator)",
                action: nil,
                keyEquivalent: ""
            )
            pItem.isEnabled = false
            menu.addItem(pItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Test / Stop Adzan
        let adzanText = AdzanPlayer.shared.isPlaying ? L10n.Menu.stopAdzan : L10n.Menu.testAdzan
        let testAdzanItem = NSMenuItem(title: adzanText, action: #selector(toggleTestAdzan), keyEquivalent: "t")
        testAdzanItem.target = self
        testAdzanItem.image = NSImage(systemSymbolName: AdzanPlayer.shared.isPlaying ? "stop.fill" : "play.fill", accessibilityDescription: nil)
        menu.addItem(testAdzanItem)

        menu.addItem(NSMenuItem.separator())

        // About Harmonotch & Open Source Credits
        let aboutItem = NSMenuItem(title: L10n.Menu.aboutHarmonotch, action: #selector(showAboutWindow), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        menu.addItem(aboutItem)

        // Keluar
        let quitItem = NSMenuItem(title: L10n.Menu.quit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)
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

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
