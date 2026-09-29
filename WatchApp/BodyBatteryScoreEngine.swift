import Foundation

struct HealthMetrics {
    let sleepHours: Double
    let deepSleepHours: Double
    let remSleepHours: Double
    let currentHRV: Double?
    let baselineHRV: Double?
    let currentRestingHeartRate: Double?
    let baselineRestingHeartRate: Double?
    let activeEnergy: Double
    let exerciseMinutes: Double
}

struct BodyBatteryScoreEngine {
    func calculate(from metrics: HealthMetrics, previous: EnergySnapshot?) -> EnergySnapshot {
        let sleepBase = min(45.0, max(0, metrics.sleepHours / 8.0 * 42.0))
        let stageBonus = min(8.0, metrics.deepSleepHours * 2.5 + metrics.remSleepHours * 1.2)

        let hrvAdjustment: Double = {
            guard let current = metrics.currentHRV,
                  let baseline = metrics.baselineHRV,
                  baseline > 0 else { return 0 }
            return clamp(((current / baseline) - 1.0) * 35.0, min: -12, max: 12)
        }()

        let restingHRAdjustment: Double = {
            guard let current = metrics.currentRestingHeartRate,
                  let baseline = metrics.baselineRestingHeartRate,
                  baseline > 0 else { return 0 }
            return clamp(((baseline - current) / baseline) * 70.0, min: -10, max: 10)
        }()

        let recharge = clampInt(Int((sleepBase + stageBonus + max(0, hrvAdjustment) + max(0, restingHRAdjustment)).rounded()), 0, 70)

        let activeDrain = min(24.0, metrics.activeEnergy / 32.0)
        let exerciseDrain = min(16.0, metrics.exerciseMinutes / 4.5)
        let physiologyPenalty = abs(min(0, hrvAdjustment)) + abs(min(0, restingHRAdjustment))
        let drain = clampInt(Int((activeDrain + exerciseDrain + physiologyPenalty).rounded()), 0, 55)

        let score = clampInt(25 + recharge - drain, 0, 100)

        let trend: EnergySnapshot.Trend = {
            guard let previous else { return .stable }
            if score >= previous.score + 4 { return .rising }
            if score <= previous.score - 4 { return .falling }
            return .stable
        }()

        return EnergySnapshot(
            score: score,
            recharge: recharge,
            drain: drain,
            trend: trend,
            updatedAt: .now,
            sleepHours: metrics.sleepHours,
            hrvMilliseconds: metrics.currentHRV,
            restingHeartRate: metrics.currentRestingHeartRate,
            activeEnergyKilocalories: metrics.activeEnergy,
            exerciseMinutes: metrics.exerciseMinutes
        )
    }

    private func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }

    private func clampInt(_ value: Int, _ minimum: Int, _ maximum: Int) -> Int {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}
