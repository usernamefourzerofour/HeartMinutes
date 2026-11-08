import SwiftUI

struct WatchContentView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        let d = model.data.current()
        ScrollView {
            VStack(spacing: 8) {
                ZStack {
                    HeartProgress(fraction: d.fraction, color: .pink)
                        .frame(width: 110, height: 96)
                    VStack(spacing: 0) {
                        Text("\(Int(d.minutes.rounded()))").font(.title2.bold())
                        Text("min").font(.caption2).opacity(0.8)
                    }
                    .foregroundStyle(.white)
                }
                Text("\(d.percent) % af \(Int(d.goal)) min")
                    .font(.footnote)
                Text("Denne uge").font(.caption2).foregroundStyle(.secondary)
                if model.isLoading {
                    ProgressView()
                } else {
                    Text("Opdateret \(model.data.updated, format: .dateTime.hour().minute())")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Heart Minutes")
    }
}
