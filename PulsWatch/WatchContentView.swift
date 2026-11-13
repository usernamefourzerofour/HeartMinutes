import Charts
import SwiftUI

/// Ur-appen (åbnes også ved tryk på komplikationen): ugens minutgraf med målet.
struct WatchContentView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        let d = model.data.current(for: model.period)
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                // Hero: den store hjerte-ring med tallet i midten (som komplikationen).
                VStack(spacing: 2) {
                    // Tæller op ligesom på iPhone (fra 0 ved åbning og ny periode).
                    CountingHeartRing(total: d.minutes, goal: d.goal, resetKey: model.period.rawValue)
                        .frame(width: 96, height: 96)
                    Text("af \(Int(d.goal.rounded())) min · \(d.percent) %")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                WatchMinutesChart(data: d, period: model.period)
                    .frame(height: 90)
                HStack {
                    Text(model.period.title)
                    Spacer()
                    if model.isLoading {
                        ProgressView().frame(width: 16, height: 16)
                    } else {
                        Text(model.data.updated, format: .dateTime.hour().minute())
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            // Luft til skærmens runde hjørner, så teksten nederst ikke skæres af.
            .padding(.horizontal, 10)
            .padding(.bottom, 14)
        }
        .navigationTitle("Heart Minutes")
    }
}

/// Kumulative Heart Minutes over urets periode med målet som grå stiplet linje.
struct WatchMinutesChart: View {
    let data: ComplicationData
    let period: SummaryPeriod

    var body: some View {
        let domain = period.chartDomain(now: data.updated)
        let points = ComplicationData.spanning(data.points ?? [], from: domain.lowerBound,
                                              to: min(.now, domain.upperBound))
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Tid", p.t), y: .value("Minutter", p.v))
                    .foregroundStyle(Brand.area())
                LineMark(x: .value("Tid", p.t), y: .value("Minutter", p.v))
                    .foregroundStyle(Brand.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            RuleMark(y: .value("Mål", data.goal))
                .foregroundStyle(Color.gray)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...max(data.goal, data.minutes, 1) * 1.08)
        .chartXAxis {
            let daily = period != .today && period.goalDays() <= 7
            AxisMarks(values: Self.ticks(for: period, in: domain)) { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.35))
                AxisValueLabel(centered: daily) {
                    if let date = value.as(Date.self) { Text(Self.label(date, period: period)) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, data.goal]) { _ in
                AxisValueLabel()
            }
        }
    }

    /// Streger på x-aksen: hver 6. time (I dag), hver dag (op til en uge) eller hver uge.
    static func ticks(for period: SummaryPeriod, in domain: ClosedRange<Date>) -> [Date] {
        let cal = Calendar.current
        let (unit, step): (Calendar.Component, Int) =
            period == .today ? (.hour, 6) : period.goalDays() <= 7 ? (.day, 1) : (.day, 7)
        var dates: [Date] = []
        var d = cal.startOfDay(for: domain.lowerBound)
        while d <= domain.upperBound {
            if d >= domain.lowerBound { dates.append(d) }
            guard let next = cal.date(byAdding: unit, value: step, to: d) else { break }
            d = next
        }
        return dates
    }

    static func label(_ date: Date, period: SummaryPeriod) -> String {
        if period == .today { return date.formatted(.dateTime.hour()) }
        if period.goalDays() <= 7 { return date.formatted(.dateTime.weekday(.narrow)) }
        return date.formatted(.dateTime.day().month(.defaultDigits))
    }
}
