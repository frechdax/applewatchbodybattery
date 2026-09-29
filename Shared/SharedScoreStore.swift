import Foundation

struct SharedScoreStore {
    private var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    func save(_ snapshot: EnergySnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: AppConstants.snapshotKey)
    }

    func load() -> EnergySnapshot? {
        guard let data = defaults.data(forKey: AppConstants.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(EnergySnapshot.self, from: data)
    }
}
