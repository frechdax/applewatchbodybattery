import Foundation

struct EnergySnapshot: Codable, Equatable {
    enum Trend: String, Codable {
        case rising
        case stable
        case falling
    }

    let score: Int
    let recharge: Int
    let drain: Int
    let trend: Trend
    let updatedAt: Date

    let sleepHours: Double
    let hrvMilliseconds: Double?
    let restingHeartRate: Double?
    let activeEnergyKilocalories: Double
    let exerciseMinutes: Double

    static let preview = EnergySnapshot(
        score: 68,
        recharge: 47,
        drain: 21,
        trend: .stable,
        updatedAt: .now,
        sleepHours: 7.6,
        hrvMilliseconds: 52,
        restingHeartRate: 57,
        activeEnergyKilocalories: 410,
        exerciseMinutes: 34
    )
}
