import CoreLocation
import Foundation

struct SightTarget: Identifiable {
    let id = UUID()
    let locationNumber: String
    let coordinate: CLLocationCoordinate2D
    let compassBearing: CLLocationDirection
    let isClear: Bool
}

struct SightTargetMatch {
    let target: SightTarget
    let distance: CLLocationDistance
    let headingDelta: CLLocationDirection
    let signedHeadingDelta: CLLocationDirection
    let isAligned: Bool
}

final class SightTargetStore: ObservableObject {
    @Published private(set) var targets: [SightTarget] = []

    private let maxDistanceMeters: CLLocationDistance = 75
    private let headingTolerance: CLLocationDirection = 18

    init() {
        loadTargets()
    }

    func loadTargets() {
        guard let url = Bundle.main.url(forResource: "SightTargets", withExtension: "csv") else {
            print("⚠️ SightTargets.csv not found in bundle")
            targets = []
            return
        }

        do {
            let contents = try String(contentsOf: url)
            targets = parseCSV(contents)
        } catch {
            print("❌ Failed to load SightTargets.csv: \(error)")
            targets = []
        }
    }

    func match(for location: CLLocation, heading: CLLocationDirection?) -> SightTargetMatch? {
        guard !targets.isEmpty else { return nil }

        let nearest = targets
            .map { target -> (SightTarget, CLLocationDistance) in
                let targetLocation = CLLocation(latitude: target.coordinate.latitude, longitude: target.coordinate.longitude)
                return (target, location.distance(from: targetLocation))
            }
            .min(by: { $0.1 < $1.1 })

        guard let (target, distance) = nearest, distance <= maxDistanceMeters else {
            return nil
        }

        let headingValue = heading ?? 0
        let signedDelta = signedHeadingDelta(headingValue, target.compassBearing)
        let delta = abs(signedDelta)
        let isAligned = delta <= headingTolerance

        return SightTargetMatch(
            target: target,
            distance: distance,
            headingDelta: delta,
            signedHeadingDelta: signedDelta,
            isAligned: isAligned
        )
    }

    private func parseCSV(_ text: String) -> [SightTarget] {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0) }

        guard !lines.isEmpty else { return [] }

        return lines.dropFirst().compactMap { line in
            let columns = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard columns.count >= 5,
                  let latitude = Double(columns[1]),
                  let longitude = Double(columns[2]),
                  let bearing = Double(columns[3]) else {
                return nil
            }

            let clearValue = columns[4].lowercased()
            let isClear = clearValue == "true" || clearValue == "1" || clearValue == "yes"

            return SightTarget(
                locationNumber: String(columns[0]),
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                compassBearing: bearing,
                isClear: isClear
            )
        }
    }

    private func signedHeadingDelta(_ heading: CLLocationDirection, _ targetBearing: CLLocationDirection) -> CLLocationDirection {
        let rawDelta = (targetBearing - heading).truncatingRemainder(dividingBy: 360)
        if rawDelta > 180 {
            return rawDelta - 360
        }
        if rawDelta < -180 {
            return rawDelta + 360
        }
        return rawDelta
    }
}
