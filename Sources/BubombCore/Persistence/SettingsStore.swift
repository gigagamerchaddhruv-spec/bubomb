import Foundation
import Combine

/// Manages persistence and state observation for Bubomb settings.
public final class SettingsStore: ObservableObject, @unchecked Sendable {
    public static let shared = SettingsStore()

    private let userDefaults: UserDefaults
    private let storageKey = "com.bubomb.settings.v1"
    private let fileManager = FileManager.default
    private let lock = NSLock()

    @Published public private(set) var settings: AppSettings

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Load initial settings
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else if let diskSettings = Self.loadFromDisk() {
            self.settings = diskSettings
        } else {
            self.settings = AppSettings.defaultSettings
        }
    }

    /// Update full settings object.
    public func update(_ newSettings: AppSettings) {
        lock.lock()
        defer { lock.unlock() }
        
        self.settings = newSettings
        persist(newSettings)
    }

    /// Sets or updates the active payload.
    public func setActivePayload(_ payload: Payload?) {
        lock.lock()
        defer { lock.unlock() }

        var updated = self.settings
        updated.activePayload = payload
        
        // Also ensure it is in savedPayloads list if non-nil
        if let payload = payload {
            if let index = updated.savedPayloads.firstIndex(where: { $0.id == payload.id }) {
                updated.savedPayloads[index] = payload
            } else {
                updated.savedPayloads.append(payload)
            }
        }
        
        self.settings = updated
        persist(updated)
    }

    /// Appends a new execution record (caps at 30 entries).
    public func addExecutionRecord(_ record: ExecutionRecord) {
        lock.lock()
        defer { lock.unlock() }

        var updated = self.settings
        var history = updated.recentExecutions
        history.insert(record, at: 0)
        if history.count > 30 {
            history = Array(history.prefix(30))
        }
        updated.recentExecutions = history
        
        self.settings = updated
        persist(updated)
    }

    /// Clears execution history.
    public func clearHistory() {
        lock.lock()
        defer { lock.unlock() }

        var updated = self.settings
        updated.recentExecutions = []
        self.settings = updated
        persist(updated)
    }

    /// Resets all settings to defaults.
    public func resetToDefaults() {
        lock.lock()
        defer { lock.unlock() }

        let defaults = AppSettings.defaultSettings
        self.settings = defaults
        persist(defaults)
    }

    // MARK: - Internal Persistence

    private func persist(_ settingsToSave: AppSettings) {
        guard let data = try? JSONEncoder().encode(settingsToSave) else { return }
        userDefaults.set(data, forKey: storageKey)
        Self.saveToDisk(data: data)
        
        // Notify observers on main queue
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    private static var diskURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let bubombDir = appSupport.appendingPathComponent("Bubomb", isDirectory: true)
        if !FileManager.default.fileExists(atPath: bubombDir.path) {
            try? FileManager.default.createDirectory(at: bubombDir, withIntermediateDirectories: true)
        }
        return bubombDir.appendingPathComponent("settings.json")
    }

    private static func saveToDisk(data: Data) {
        guard let url = diskURL else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func loadFromDisk() -> AppSettings? {
        guard let url = diskURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return nil
        }
        return decoded
    }
}
