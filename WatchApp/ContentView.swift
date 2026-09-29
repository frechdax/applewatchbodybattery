import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var health: HealthKitManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let snapshot = health.snapshot {
                    ScoreRing(snapshot: snapshot)
                    HStack(spacing: 8) {
                        MetricPill(title: "Laden", value: "+\(snapshot.recharge)", symbol: "bolt.fill")
                        MetricPill(title: "Verbrauch", value: "−\(snapshot.drain)", symbol: "flame.fill")
                    }

                    VStack(spacing: 6) {
                        detailRow("Schlaf", value: String(format: "%.1f h", snapshot.sleepHours))
                        detailRow("HRV", value: snapshot.hrvMilliseconds.map { "\(Int($0.rounded())) ms" } ?? "–")
                        detailRow("Ruhepuls", value: snapshot.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "–")
                        detailRow("Aktiv", value: "\(Int(snapshot.activeEnergyKilocalories.rounded())) kcal")
                    }
                    .font(.caption2)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 42))
                        Text("Body Battery")
                            .font(.headline)
                        Text("Health-Zugriff erlauben, um deinen persönlichen Energie-Score zu berechnen.")
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                }

                if health.isLoading {
                    ProgressView()
                } else {
                    Button(health.snapshot == nil ? "Health verbinden" : "Aktualisieren") {
                        Task { await health.requestAuthorizationAndRefresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let error = health.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 8)
        }
        .task {
            if health.snapshot != nil {
                await health.refresh()
            }
        }
    }

    @ViewBuilder
    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }
}

private struct ScoreRing: View {
    let snapshot: EnergySnapshot

    private var status: String {
        switch snapshot.score {
        case 75...: return "Hohe Energie"
        case 45..<75: return "Solide Energie"
        case 20..<45: return "Energie sparen"
        default: return "Erholung sinnvoll"
        }
    }

    var body: some View {
        Gauge(value: Double(snapshot.score), in: 0...100) {
            Image(systemName: "bolt.heart.fill")
        } currentValueLabel: {
            Text("\(snapshot.score)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Gradient(colors: [.red, .orange, .yellow, .green]))
        .frame(width: 100, height: 100)
        .overlay(alignment: .bottom) {
            Text(status)
                .font(.caption2)
                .offset(y: 12)
        }
        .padding(.bottom, 8)
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
