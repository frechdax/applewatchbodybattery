import SwiftUI
import WidgetKit

struct BodyBatteryEntry: TimelineEntry {
    let date: Date
    let snapshot: EnergySnapshot
}

struct BodyBatteryProvider: TimelineProvider {
    private let store = SharedScoreStore()

    func placeholder(in context: Context) -> BodyBatteryEntry {
        BodyBatteryEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (BodyBatteryEntry) -> Void) {
        completion(BodyBatteryEntry(date: .now, snapshot: store.load() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BodyBatteryEntry>) -> Void) {
        let entry = BodyBatteryEntry(date: .now, snapshot: store.load() ?? .preview)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct BodyBatteryComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BodyBatteryEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(entry.snapshot.score), in: 0...100) {
                Image(systemName: "bolt.fill")
            } currentValueLabel: {
                Text("\(entry.snapshot.score)")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Gauge(value: Double(entry.snapshot.score), in: 0...100) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(entry.snapshot.score)")
                        .font(.headline)
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .frame(width: 45)

                VStack(alignment: .leading, spacing: 1) {
                    Label("Body Battery", systemImage: "bolt.heart.fill")
                        .font(.caption2)
                    Text(trendText)
                        .font(.caption2)
                    Text("+\(entry.snapshot.recharge)  −\(entry.snapshot.drain)")
                        .font(.caption2)
                        .monospacedDigit()
                }
            }
            .widgetAccentable()

        case .accessoryInline:
            Label("Body Battery \(entry.snapshot.score)", systemImage: trendSymbol)

        case .accessoryCorner:
            Text("\(entry.snapshot.score)")
                .font(.headline)
                .monospacedDigit()
                .widgetLabel {
                    Gauge(value: Double(entry.snapshot.score), in: 0...100) {
                        Text("Energie")
                    }
                }

        default:
            Text("\(entry.snapshot.score)")
        }
    }

    private var trendSymbol: String {
        switch entry.snapshot.trend {
        case .rising: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .falling: return "arrow.down.right"
        }
    }

    private var trendText: String {
        switch entry.snapshot.trend {
        case .rising: return "steigend"
        case .stable: return "stabil"
        case .falling: return "fallend"
        }
    }
}

@main
struct BodyBatteryComplication: Widget {
    let kind = "BodyBatteryComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BodyBatteryProvider()) { entry in
            BodyBatteryComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Body Battery")
        .description("Zeigt deinen aktuellen Energie- und Erholungswert.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
