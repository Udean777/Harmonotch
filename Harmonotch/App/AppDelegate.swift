//
//  AppDelegate.swift
//  Harmonotch
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Tampilkan floating window di notch
        NotchWindowController.shared.setupAndShowWindow()

        // Buat Menu Bar icon pendukung
        setupStatusBarItem()
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Harmonotch")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
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

    @objc private func toggleTestAdzan() {
        AdzanPlayer.shared.testPlay()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
