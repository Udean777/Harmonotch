import Foundation

/// Pure helpers for the self-update installer: script formatting, download bounding,
/// and bundle swap logic.
enum UpdateInstallerSupport {
    static let downloadCeilingBytes: Int64 = 200 * 1024 * 1024 // 200 MB

    static func progressStepAdvanced(from current: Double?, to fraction: Double) -> Bool {
        guard let current else { return true }
        return Int(fraction * 100) > Int(current * 100)
    }

    static func downloadByteLimit(expectedBytes: Int64?, ceiling: Int64 = downloadCeilingBytes) -> Int64 {
        guard let expectedBytes, expectedBytes > 0, expectedBytes <= ceiling else {
            return ceiling
        }
        return expectedBytes
    }

    static func downloadIsUsable(status: Int, receivedBytes: Int64, expectedBytes: Int64?, ceiling: Int64 = downloadCeilingBytes) -> Bool {
        guard status == 200, receivedBytes > 0, receivedBytes <= ceiling else { return false }
        guard let expectedBytes, expectedBytes > 0 else { return true }
        return receivedBytes == expectedBytes
    }

    static func runsFromImmutableLocation(appPath: String, volumeIsReadOnly: (String) -> Bool) -> Bool {
        appPath.contains("/AppTranslocation/") || volumeIsReadOnly(appPath)
    }

    static func shellSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Generates shell script that mounts the DMG silently, extracts Harmonotch.app,
    /// strips quarantine via xattr -cr, verifies bundle ID & version,
    /// swaps it in /Applications (or current folder), and unmounts the DMG.
    static func installScript(appPath: String, dmgPath: String, expectedVersion: String) -> String {
        """
        #!/bin/sh
        APP=\(shellSingleQuoted(appPath))
        DMG=\(shellSingleQuoted(dmgPath))
        EXPECTED_VERSION=\(shellSingleQuoted(expectedVersion))
        EXPECTED_BUNDLE_ID="com.ssajudn.Harmonotch"

        MNT="$(/usr/bin/mktemp -d /tmp/harmonotch-update-mnt.XXXXXX)" || exit 10
        if ! /usr/bin/hdiutil attach "$DMG" -nobrowse -quiet -mountpoint "$MNT"; then
            /bin/rmdir "$MNT" 2>/dev/null
            /bin/rm -f "$DMG"
            exit 11
        fi

        SRC="$(/usr/bin/find "$MNT" -maxdepth 1 -name '*.app' -print -quit)"
        if [ -z "$SRC" ]; then
            /usr/bin/hdiutil detach "$MNT" -quiet 2>/dev/null || /usr/bin/hdiutil detach "$MNT" -force -quiet 2>/dev/null || true
            /bin/rmdir "$MNT" 2>/dev/null
            /bin/rm -f "$DMG"
            exit 12
        fi

        DIR="$(/usr/bin/dirname "$APP")"
        NAME="$(/usr/bin/basename "$SRC")"
        DEST="$DIR/$NAME"
        STAGE="$DIR/.$NAME.update-new.$$"
        BACKUP="$DIR/.$NAME.update-old.$$"

        /bin/rm -rf "$STAGE" "$BACKUP"

        if ! /usr/bin/ditto "$SRC" "$STAGE"; then
            /usr/bin/hdiutil detach "$MNT" -quiet 2>/dev/null || true
            /bin/rmdir "$MNT" 2>/dev/null
            /bin/rm -rf "$STAGE" "$DMG"
            exit 13
        fi

        # Clear Gatekeeper quarantine attributes from downloaded files
        /usr/bin/xattr -cr "$STAGE" 2>/dev/null

        # Verify bundle identifier
        BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$STAGE/Contents/Info.plist" 2>/dev/null)"
        if [ "$BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]; then
            /usr/bin/hdiutil detach "$MNT" -quiet 2>/dev/null || true
            /bin/rmdir "$MNT" 2>/dev/null
            /bin/rm -rf "$STAGE" "$DMG"
            exit 14
        fi

        # Verify code sign structure if codesign is available
        if ! /usr/bin/codesign -v --deep --strict "$STAGE" 2>/dev/null; then
            /usr/bin/hdiutil detach "$MNT" -quiet 2>/dev/null || true
            /bin/rmdir "$MNT" 2>/dev/null
            /bin/rm -rf "$STAGE" "$DMG"
            exit 15
        fi

        # Swap in place
        if [ -d "$DEST" ]; then
            if ! /bin/mv "$DEST" "$BACKUP"; then
                /usr/bin/hdiutil detach "$MNT" -quiet 2>/dev/null || true
                /bin/rmdir "$MNT" 2>/dev/null
                /bin/rm -rf "$STAGE" "$DMG"
                exit 16
            fi
        fi

        if ! /bin/mv "$STAGE" "$DEST"; then
            [ -d "$BACKUP" ] && /bin/mv "$BACKUP" "$DEST"
            /usr/bin/hdiutil detach "$MNT" -quiet 2>/dev/null || true
            /bin/rmdir "$MNT" 2>/dev/null
            /bin/rm -rf "$STAGE" "$DMG"
            exit 17
        fi

        /bin/rm -rf "$BACKUP"
        /usr/bin/hdiutil detach "$MNT" -quiet 2>/dev/null || /usr/bin/hdiutil detach "$MNT" -force -quiet 2>/dev/null || true
        /bin/rmdir "$MNT" 2>/dev/null
        /bin/rm -f "$DMG"
        exit 0
        """
    }
}
