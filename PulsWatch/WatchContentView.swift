import Charts
import SwiftUI

/// Ur-appen (åbnes også ved tryk på komplikationen): ugens minutgraf med målet.
struct WatchContentView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        let d = model.data.current()
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    // Hjerte-ringen (som komplikationen); tallene står ved siden af.
                    ShapeProgressRing(shape: HeartOutlineShape(), fraction: d.fraction, value: "",
                                      thickness: 0.13, miterLimit: 4)
                        .frame(width: 44, height: 40)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(Int(d.minutes.rounded())) min").font(.headline)
                        Text("af \(Int(d.goal)) · \(d.percent) %")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                WatchMinutesChart(data: d)
                    .frame(height: 90)
                HStack {
                    Text("Denne uge")
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

/// Ugens kumulative Heart Minutes (mandag–søndag) med målet som grå stiplet linje.
struct WatchMinutesChart: View {
    let data: ComplicationData

    var body: some View {
        let period = SummaryPeriod.thisWeek
        let domain = period.chartDomain(now: data.updated)
        let points = ComplicationData.spanning(data.points ?? [], from: domain.lowerBound,
                                              to: min(.now, domain.upperBound))
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Tid", p.t), y: .value("Minutter", p.v))
                    .foregroundStyle(Color.pink.opacity(0.25))
                LineMark(x: .value("Tid", p.t), y: .value("Minutter", p.v))
                    .foregroundStyle(Color.pink)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            RuleMark(y: .value("Mål", data.goal))
                .foregroundStyle(Color.gray)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...max(data.goal, data.minutes, 1) * 1.08)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.35))
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, data.goal]) { _ in
                AxisValueLabel()
            }
        }
    }
}
