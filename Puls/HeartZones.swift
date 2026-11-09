import Foundation

/// Kilde for maks-puls og zonegrænser (American Heart Association, "Target Heart Rates Chart"):
/// "Target heart rate during moderate-intensity activities is about 50-70% of maximum heart rate.
///  During vigorous physical activity, it's about 70-85% of maximum."  Maks-puls ≈ 220 − alder.
/// Siden definerer kun moderate og vigorous, så kun de to farves; "Let" vises gråt.
/// Valg i appen: hård (vigorous) fortsætter opad uden 85 %-loft.
enum AHA {
    static let targetHeartRatesURL =
        URL(string: "https://www.heart.org/en/healthy-living/exercise-and-physical-activity/fitness-basics/target-heart-rates")!
}

/// Zonemodel: AHA's to zoner (moderat/hård) eller de gængse fem zoner (Garmin/Polar m.fl.).
enum ZoneModel: String, CaseIterable, Identifiable, Sendable {
    case two, five
    var id: String { rawValue }

    var title: String {
        switch self {
        case .two: "2 zoner"
        case .five: "5 zoner"
        }
    }

    /// Navne på zonerne, nederst først. Den nederste tæller som udgangspunkt ikke (× 0).
    var names: [String] {
        switch self {
        case .two: ["Let", "Moderat", "Hård"]
        case .five: ["Z0", "Z1", "Z2", "Z3", "Z4", "Z5"]
        }
    }

    /// Nedre grænse for hver zone som andel af maks-puls (første er altid 0).
    /// To zoner: AHA (moderat 50 %, hård 70 %). Fem zoner: Z1–Z5 fra 50/60/70/80/90 %; Z0 er under 50 %.
    var defaultPercents: [Double] {
        switch self {
        case .two: [0, 0.50, 0.70]
        case .five: [0, 0.50, 0.60, 0.70, 0.80, 0.90]
        }
    }

    /// Hvor meget ét minut i hver zone tæller. AHA: moderat × 1, hård × 2.
    var defaultWeights: [Double] {
        switch self {
        case .two: [0, 1, 2]
        case .five: [0, 0, 1, 2, 2, 2]
        }
    }
}

/// Hvordan maks-pulsen findes.
enum MaxHRSource: String, CaseIterable, Identifiable, Sendable {
    case age, manual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .age: "Alder"
        case .manual: "Indtast"
        }
    }
}

/// Pulszonerne: nedre grænser i procent af maks-puls og en faktor pr. zone. Den øverste zone har intet loft.
struct HeartZones: Equatable, Sendable {
    let maxHR: Double
    let model: ZoneModel
    /// Nedre grænse pr. zone som andel af maks-puls (første er 0).
    let percents: [Double]
    /// Faktor pr. zone.
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

    /// To zoner med faste grænser i bpm (bruges i testene).
    init(moderate: Double, vigorous: Double, maxHR: Double? = nil) {
        let m = maxHR ?? vigorous / 0.70
        self.init(maxHR: m, model: .two, percents: [0, moderate / m, vigorous / m])
    }

    /// Samme zoner med andre faktorer.
    func withWeights(_ weights: [Double]) -> HeartZones {
        HeartZones(maxHR: maxHR, model: model, percents: percents, weights: weights)
    }

    /// Maks-puls ud fra alder: 220 − alder (det AHA's tabel bygger på; den mest udbredte formel).
    static func maxHR(age: Int) -> Double { Double(220 - age) }

    var count: Int { percents.count }
    var indices: Range<Int> { 0..<count }
    func name(_ i: Int) -> String { model.names[i] }

    func lowerBound(_ i: Int) -> Double { i == 0 ? 0 : percents[i] * maxHR }

    /// Den øverste zone har intet loft (.infinity).
    func bpmRange(_ i: Int) -> ClosedRange<Double> {
        let lo = lowerBound(i)
        let hi = i + 1 < count ? lowerBound(i + 1) : .infinity
        return lo...max(lo, hi)
    }

    /// Zonen (indeks) for en puls.
    func zone(for bpm: Double) -> Int {
        indices.last { bpm >= lowerBound($0) } ?? 0
    }

    /// Grænserne mellem zonerne (bpm).
    var thresholds: [Double] { (1..<count).map(lowerBound) }

    /// To zoner: hvor moderat og hård starter.
    var moderate: Double { lowerBound(1) }
    var vigorous: Double { lowerBound(min(2, count - 1)) }
}
