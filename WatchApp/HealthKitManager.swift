import Foundation
import Combine
import HealthKit
import WidgetKit

@MainActor
final class HealthKitManager: ObservableObject {
    enum HealthError: LocalizedError {
        case unavailable
        case missingTypes

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Health-Daten sind auf diesem Gerät nicht verfügbar."
            case .missingTypes: return "Benötigte HealthKit-Datentypen konnten nicht geladen werden."
            }
        }
    }

    @Published private(set) var snapshot: EnergySnapshot?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let healthStore = HKHealthStore()
    private let store = SharedScoreStore()
    private let engine = BodyBatteryScoreEngine()

    init() {
        snapshot = store.load()
    }

    func requestAuthorizationAndRefresh() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = HealthError.unavailable.localizedDescription
            return
        }

        do {
            try await requestAuthorization()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let metrics = try await loadMetrics()
            let newSnapshot = engine.calculate(from: metrics, previous: snapshot)
            snapshot = newSnapshot
            store.save(newSnapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: "BodyBatteryComplication")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestAuthorization() async throws {
        guard let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
              let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
              let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let exerciseTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
              let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthError.missingTypes
        }

        let readTypes: Set<HKObjectType> = [heartRate, restingHeartRate, hrv, activeEnergy, exerciseTime, sleep]
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    private func loadMetrics() async throws -> HealthMetrics {
        guard let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
              let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthError.missingTypes
        }

        async let sleepTask = loadLastNightSleep(type: sleepType)
        async let currentHRVTask = mostRecentQuantity(type: hrvType, unit: .secondUnit(with: .milli))
        async let baselineHRVTask = averageQuantity(type: hrvType, unit: .secondUnit(with: .milli), days: 28)
        async let currentRHRTask = mostRecentQuantity(type: restingHeartRateType, unit: HKUnit.count().unitDivided(by: .minute()))
        async let baselineRHRTask = averageQuantity(type: restingHeartRateType, unit: HKUnit.count().unitDivided(by: .minute()), days: 28)
        async let activeEnergyTask = cumulativeToday(type: activeEnergyType, unit: .kilocalorie())
        async let exerciseMinutesTask = cumulativeToday(type: exerciseType, unit: .minute())

        let sleep = try await sleepTask
        let currentHRV = try await currentHRVTask
        let baselineHRV = try await baselineHRVTask
        let currentRHR = try await currentRHRTask
        let baselineRHR = try await baselineRHRTask
        let activeEnergy = try await activeEnergyTask
        let exerciseMinutes = try await exerciseMinutesTask

        return HealthMetrics(
            sleepHours: sleep.total,
            deepSleepHours: sleep.deep,
            remSleepHours: sleep.rem,
            currentHRV: currentHRV,
            baselineHRV: baselineHRV,
            currentRestingHeartRate: currentRHR,
            baselineRestingHeartRate: baselineRHR,
            activeEnergy: activeEnergy,
            exerciseMinutes: exerciseMinutes
        )
    }

    private func mostRecentQuantity(type: HKQuantityType, unit: HKUnit) async throws -> Double? {
        let start = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictEndDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func averageQuantity(type: HKQuantityType, unit: HKUnit, days: Int) async throws -> Double? {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictEndDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: result?.averageQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func cumulativeToday(type: HKQuantityType, unit: HKUnit) async throws -> Double {
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            healthStore.execute(query)
        }
    }

    private func loadLastNightSleep(type: HKCategoryType) async throws -> (total: Double, deep: Double, rem: Double) {
        let calendar = Calendar.current
        let now = Date()
        let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        let anchor = now < todayNoon ? calendar.date(byAdding: .day, value: -1, to: todayNoon)! : todayNoon
        let start = calendar.date(byAdding: .hour, value: -18, to: anchor)!
        let end = calendar.date(byAdding: .hour, value: 6, to: anchor)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }

                var total = 0.0
                var deep = 0.0
                var rem = 0.0

                for case let sample as HKCategorySample in samples ?? [] {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600
                    guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
                    switch value {
                    case .asleepDeep:
                        total += duration
                        deep += duration
                    case .asleepREM:
                        total += duration
                        rem += duration
                    case .asleepCore, .asleepUnspecified:
                        total += duration
                    default:
                        break
                    }
                }

                continuation.resume(returning: (total, deep, rem))
            }
            healthStore.execute(query)
        }
    }
}
