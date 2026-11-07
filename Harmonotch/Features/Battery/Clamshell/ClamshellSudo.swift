import Foundation

extension ClamshellManager {
    // MARK: - Sudo Probe & Setup

    var sudoersInstaller: SudoersRuleInstaller {
        let uid = getuid()
        let ruleContent = "#\(uid) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
        return SudoersRuleInstaller(
            filePath: Self.sudoersFilePath,
            ruleContent: ruleContent,
            probe: {
                Self.probeSudoConfigurationSync()
            }
        )
    }

    static func probeSudoConfigurationSync() -> Bool {
        guard let currentDisabled = PmsetController.sleepDisabled() else {
            return false
        }
        return PmsetController.setDisableSleep(currentDisabled)
    }

    func checkSudoConfiguration() {
        let installer = sudoersInstaller
        clamshellQueue.async { [weak self] in
            guard let self, !self.isTerminating else { return }
            let configured = installer.isConfigured()
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isTerminating else { return }
                self.isSudoConfigured = configured
                if configured {
                    self.setupFailed = false
                }
            }
        }
    }

    func setupPasswordlessSudo(completion: @escaping (Bool) -> Void) {
        isPerformingSetup = true
        setupFailed = false
        let installer = sudoersInstaller
        clamshellQueue.async { [weak self] in
            guard let self, !self.isTerminating else {
                DispatchQueue.main.async {
                    self?.isPerformingSetup = false
                    self?.setupFailed = true
                    completion(false)
                }
                return
            }

            let verified = installer.install()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isPerformingSetup = false
                self.isSudoConfigured = verified
                self.setupFailed = !verified
                if verified {
                    self.recalculateState()
                }
                completion(verified)
            }
        }
    }

    func removePasswordlessSudo(completion: ((Bool) -> Void)? = nil) {
        let installer = sudoersInstaller
        clamshellQueue.async { [weak self] in
            let removed = installer.remove()
            let stillConfigured = Self.probeSudoConfigurationSync()
            DispatchQueue.main.async { [weak self] in
                self?.isSudoConfigured = stillConfigured
                completion?(removed && !stillConfigured)
            }
        }
    }
}
