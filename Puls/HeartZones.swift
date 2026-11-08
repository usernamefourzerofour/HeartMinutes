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

enum ZoneKind: Int, CaseIterable, Identifiable {
    case light, moderate, vigorous

    var id: Int { rawValue }

    /// Zonerne der vises i graf, forklaring og indstillinger.
    static let shown: [ZoneKind] = allCases

    var name: String {
        switch self {
        case .light: "Let"
        case .moderate: "Moderat"
        case .vigorous: "Hård"
        }
    }

    /// Nedre grænse som andel af maks-puls.
    var lowerFraction: Double {
        switch self {
        case .light: 0
        case .moderate: 0.50
        case .vigorous: 0.70
        }
    }
}

/// Hvordan zonegrænserne bestemmes.
enum ZoneMode: String, CaseIterable, Identifiable {
    case age, maxHR, manual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .age: "Alder"
        case .maxHR: "Maks-puls"
        case .manual: "Manuelt"
        }
    }
}

/// Nedre grænser (bpm) for zonerne moderat og hård. Hård fortsætter opad uden loft.
struct HeartZones: Equatable {
    let moderate: Double
    let vigorous: Double
    /// Maks-puls (bruges som top, når man zoomer helt ud).
    let maxHR: Double

    init(moderate: Double, vigorous: Double, maxHR: Double? = nil) {
        self.moderate = moderate
        self.vigorous = vigorous
        self.maxHR = maxHR ?? vigorous / ZoneKind.vigorous.lowerFraction
    }

    init(age: Int) { self.init(maxHR: Self.maxHR(age: age)) }

    init(maxHR: Double) {
        self.init(moderate: maxHR * ZoneKind.moderate.lowerFraction,
                  vigorous: maxHR * ZoneKind.vigorous.lowerFraction,
                  maxHR: maxHR)
    }

    /// AHA's tabel (Target Heart Rates Chart): aldersgruppe → maks-puls (bpm).
    /// "In the age category closest to yours, read across to find your target heart rates."
    static let ahaTable: [(age: Int, maxHR: Int)] = [
        (20, 200), (30, 190), (35, 185), (40, 180), (45, 175),
        (50, 170), (55, 165), (60, 160), (65, 155), (70, 150),
    ]

    /// Aldersgruppen i AHA-tabellen tættest på `age` (ved lige afstand: den yngste).
    static func ahaCategory(for age: Int) -> (age: Int, maxHR: Int) {
        ahaTable.min { abs($0.age - age) < abs($1.age - age) }!
    }

    // TODO: Find en mere præcis formel for maks-puls pr. år (fx Tanaka 208 − 0,7 × alder
    // eller Nes/HUNT 211 − 0,64 × alder). Se TODO.md.
    static func maxHR(age: Int) -> Double { Double(ahaCategory(for: age).maxHR) }

    func lowerBound(_ kind: ZoneKind) -> Double {
        switch kind {
        case .light: 0
        case .moderate: moderate
        case .vigorous: vigorous
        }
    }

    /// Hård har intet loft (.infinity).
    func bpmRange(_ kind: ZoneKind) -> ClosedRange<Double> {
        switch kind {
        case .light: 0...moderate
        case .moderate: moderate...max(vigorous, moderate)
        case .vigorous: vigorous...Double.infinity
        }
    }

    func zone(for bpm: Double) -> ZoneKind {
        ZoneKind.allCases.last { bpm >= lowerBound($0) } ?? .light
    }
}
