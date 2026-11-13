import Foundation

/// Source for max heart rate and zone limits (American Heart Association, "Target Heart Rates Chart"): "Target heart
/// rate during moderate-intensity activities is about 50-70% of maximum heart rate. During vigorous physical activity,
/// it's about 70-85% of maximum." Max heart rate ≈ 220 − age. The page only defines moderate and vigorous, so only
/// those two are coloured; "Light" is grey. Choice in the app: vigorous continues upward without the 85 % ceiling.
enum AHA {
    static let targetHeartRatesURL =
        URL(string: "https://www.heart.org/en/healthy-living/exercise-and-physical-activity/fitness-basics/target-heart-rates")!
}

/// Zone model: AHA's two zones (moderate/vigorous) or the common five zones (Garmin/Polar and others).
enum ZoneModel: String, CaseIterable, Identifiable, Sendable {
    case two, five
    var id: String { rawValue }

    var title: String {
        switch self {
        case .two: String(localized: "2 zones")
        case .five: String(localized: "5 zones")
        }
    }

    /// Names of the zones, lowest first. The lowest doesn't count by default (× 0).
    var names: [String] {
        switch self {
        case .two: [String(localized: "Light"), String(localized: "Moderate"), String(localized: "Vigorous")]
        case .five: ["Z0", "Z1", "Z2", "Z3", "Z4", "Z5"]
        }
    }

    /// Lower limit of each zone as a fraction of max heart rate (the first is always 0). Two zones: AHA (moderate 50 %,
    /// vigorous 70 %). Five zones: Z1–Z5 from 50/60/70/80/90 %; Z0 is below 50 %.
    var defaultPercents: [Double] {
        switch self {
        case .two: [0, 0.50, 0.70]
        case .five: [0, 0.50, 0.60, 0.70, 0.80, 0.90]
        }
    }

    /// How much one minute in each zone counts. AHA: moderate × 1, vigorous × 2.
    var defaultWeights: [Double] {
        switch self {
        case .two: [0, 1, 2]
        case .five: [0, 1, 1, 2, 2, 2]
        }
    }
}

/// How the max heart rate is determined.
enum MaxHRSource: String, CaseIterable, Identifiable, Sendable {
    case age, manual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .age: String(localized: "Age")
        case .manual: String(localized: "Enter")
        }
    }
}

/// The heart rate zones: lower limits as a percentage of max heart rate and a factor per zone. The top zone has no
/// ceiling.
struct HeartZones: Equatable, Sendable {
    let maxHR: Double
    let model: ZoneModel
    /// Lower limit per zone as a fraction of max heart rate (the first is 0).
    let percents: [Double]
    /// Factor per zone.
    let weights: [Double]

    init(maxHR: Double, model: ZoneModel = .two, percents: [Double]? = nil, weights: [Double]? = nil) {
        self.maxHR = maxHR
        self.model = model
        let p = percents ?? model.defaultPercents
        let w = weights ?? model.defaultWeights
        let n = model.names.count
        self.percents = p.count == n ? p : model.defaultPercents
        self.weights = w.count == n ? w : model.defaultWeights
    }

    init(age: Int) { self.init(maxHR: Self.maxHR(age: age)) }

    /// Two zones with fixed limits in bpm (used in the tests).
    init(moderate: Double, vigorous: Double, maxHR: Double? = nil) {
        let m = maxHR ?? vigorous / 0.70
        self.init(maxHR: m, model: .two, percents: [0, moderate / m, vigorous / m])
    }

    /// The same zones with other factors.
    func withWeights(_ weights: [Double]) -> HeartZones {
        HeartZones(maxHR: maxHR, model: model, percents: percents, weights: weights)
    }

    /// Max heart rate from age: 220 − age (what AHA's table is based on; the most widely used formula).
    static func maxHR(age: Int) -> Double { Double(220 - age) }

    var count: Int { percents.count }
    var indices: Range<Int> { 0..<count }
    func name(_ i: Int) -> String { model.names[i] }

    func lowerBound(_ i: Int) -> Double { i == 0 ? 0 : percents[i] * maxHR }

    /// The top zone has no ceiling (.infinity).
    func bpmRange(_ i: Int) -> ClosedRange<Double> {
        let lo = lowerBound(i)
        let hi = i + 1 < count ? lowerBound(i + 1) : .infinity
        return lo...max(lo, hi)
    }

    /// The zone (index) for a heart rate.
    func zone(for bpm: Double) -> Int {
        indices.last { bpm >= lowerBound($0) } ?? 0
    }

    /// The zone's colour as red/green/blue (0…1). Zones that don't count (× 0) are grey. Muted versions of the common
    /// zone colours: blue, olive green, mustard yellow, orange, dark red.
    func rgb(_ i: Int) -> [Double] {
        let gray = [0.56, 0.56, 0.58]
        if weights[i] == 0 { return gray }
        let blue = [0.42, 0.65, 0.95], green = [0.47, 0.62, 0.24], yellow = [0.84, 0.71, 0.24]
        let orange = [0.92, 0.53, 0.22], red = [0.66, 0.17, 0.17]
        let palette = model == .two ? [gray, green, orange] : [gray, blue, green, yellow, orange, red]
        return palette[min(i, palette.count - 1)]
    }

    /// The minutes per zone as pieces for the zone bar (only zones that count and have minutes).
    func slices(_ minutes: [Double]) -> [ZoneSlice] {
        indices.compactMap { i in
            let m = i < minutes.count ? minutes[i] : 0
            guard weights[i] > 0, m > 0 else { return nil }
            let c = rgb(i)
            return ZoneSlice(name: name(i), minutes: m, r: c[0], g: c[1], b: c[2])
        }
    }

    /// The limits between the zones (bpm).
    var thresholds: [Double] { (1..<count).map(lowerBound) }

    /// Two zones: where moderate and vigorous start.
    var moderate: Double { lowerBound(1) }
    var vigorous: Double { lowerBound(min(2, count - 1)) }
}
