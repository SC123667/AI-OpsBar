import Foundation

enum SettingsStore {
    static func load() -> MonitorSettings {
        guard let data = UserDefaults.standard.data(forKey: AppConfig.settingsKey),
              let settings = try? JSONDecoder().decode(MonitorSettings.self, from: data) else {
            return MonitorSettings()
        }

        return settings
    }

    static func save(_ settings: MonitorSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        UserDefaults.standard.set(data, forKey: AppConfig.settingsKey)
    }
}
