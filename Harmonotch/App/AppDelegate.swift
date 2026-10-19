//
//  AppDelegate.swift
//  Harmonotch
//

import AppKit
import SwiftUI
import Combine

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
    }

    private func updateStatusBarButton() {
        guard let button = statusItem?.button else { return }

        let isHidden = NotchWindowController.shared.isNotchHidden
        let isPlaying = AdzanPlayer.shared.isPlaying
        let selectedTab = NotchViewModel.shared.selectedTab

        // 1. Icon: Gunakan monitor/MacBook saat mode baterai aktif agar tidak duplikasi icon baterai macOS
        if isPlaying {
            button.image = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: "Adzan")
        } else if selectedTab == .battery {
            button.image = NSImage(systemSymbolName: "macbook", accessibilityDescription: "Harmonotch Hardware")
        } else {
            button.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Harmonotch Prayer")
        }
        button.image?.isTemplate = true

        // 2. Teks waktu/siklus: Hanya muncul jika Notch sedang di-hide
        if isHidden {
            if isPlaying {
                button.title = " Adzan \(AdzanPlayer.shared.playingPrayerName)"
            } else if selectedTab == .prayer, let next = PrayerManager.shared.nextPrayerItem {
                button.title = " \(next.name) \(next.timeString)"
            } else if selectedTab == .battery {
                button.title = " \(BatteryMonitor.shared.cycleCount) Siklus"
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

        let titleItem = NSMenuItem(title: "Harmonotch — Islamic Notch", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle Notch Drawer
        let toggleItem = NSMenuItem(
            title: NotchViewModel.shared.isExpanded ? "Tutup Drawer Notch" : "Buka Drawer Notch",
            action: #selector(toggleNotchDrawer),
            keyEquivalent: "n"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        // Opsi Sembunyikan / Tampilkan Notch di Layar
        let isHidden = NotchWindowController.shared.isNotchHidden
        let hideTitle = isHidden ? "Tampilkan Notch di Layar" : "Sembunyikan Notch di Layar"
        let hideItem = NSMenuItem(title: hideTitle, action: #selector(toggleNotchVisibility), keyEquivalent: "h")
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(NSMenuItem.separator())

        // Info Lokasi
        let locItem = NSMenuItem(title: "📍 Wilayah: \(PrayerManager.shared.currentLocationName)", action: nil, keyEquivalent: "")
        locItem.isEnabled = false
        menu.addItem(locItem)

        // Daftar 5 Waktu Sholat di Menu
        for prayer in PrayerManager.shared.prayerItems {
            let indicator = prayer.isNext ? " 🟢 (Berikutnya)" : (prayer.isCurrent ? " 🟡 (Sekarang)" : "")
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
        let adzanText = AdzanPlayer.shared.isPlaying ? "⏹ Hentikan Adzan" : "▶️ Uji Coba Audio Adzan"
        let testAdzanItem = NSMenuItem(title: adzanText, action: #selector(toggleTestAdzan), keyEquivalent: "t")
        testAdzanItem.target = self
        menu.addItem(testAdzanItem)

        menu.addItem(NSMenuItem.separator())

        // Keluar
        let quitItem = NSMenuItem(title: "Keluar Harmonotch", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
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
