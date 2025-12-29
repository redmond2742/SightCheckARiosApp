import CoreLocation


class GPSLogger: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    private var gpxFileURL: URL!
    private var fileHandle: FileHandle?
    private var timer: Timer?
    @Published var totalDistance: CLLocationDistance = 0.0
    @Published var lastHeading: CLHeading?
    
    @Published var lastLocationFix: CLLocation?
    @Published var lastLocation: CLLocation?
    private var isLogging = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .otherNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.headingFilter = 1
    }

    func startTracking() {
        locationManager.requestWhenInUseAuthorization()

        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }

        locationManager.startUpdatingLocation()
    }

    func startLogging() {
        startTracking()
        isLogging = true

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy--HH-mm-ss.SSS"
        formatter.timeZone = TimeZone.current

        let dateString = formatter.string(from: Date())
        let timeZoneAbbreviation = TimeZone.current.abbreviation() ?? "UTC"

        let filename = "track_\(dateString)-\(timeZoneAbbreviation).gpx"
        gpxFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        FileManager.default.createFile(atPath: gpxFileURL.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: gpxFileURL)


        writeHeader()
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    func stopLogging() {
        isLogging = false
        writeFooter()
        fileHandle?.closeFile()
        print("Saved GPX to: \(gpxFileURL.path)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startTracking()
        case .restricted, .denied:
            print("❌ Location permission denied.")
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        lastHeading = newHeading
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last, newLocation.horizontalAccuracy >= 0 else { return }

        if let last = lastLocation {
            let distance = newLocation.distance(from: last) // in meters
            totalDistance += distance
        }

        lastLocation = newLocation
        self.lastLocationFix = newLocation
        if isLogging {
            writeLocation(newLocation)
        }
    }

    
    private func writeLocation(_ loc: CLLocation) {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = isoFormatter.string(from: loc.timestamp)
        let line = "  <trkpt lat=\"\(loc.coordinate.latitude)\" lon=\"\(loc.coordinate.longitude)\"><ele>\(loc.altitude)</ele><time>\(timestamp)</time></trkpt>\n"

        if let data = line.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }


    private func writeHeader() {
        let header = """
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<gpx version=\"1.1\" creator=\"VideoGPSRecorder\" xmlns=\"http://www.topografix.com/GPX/1/1\">
  <trk>
    <name>Track</name>
    <trkseg>
"""
        fileHandle?.write(Data(header.utf8))
    }

    private func writeFooter() {
        let footer = """
    </trkseg>
  </trk>
</gpx>
"""
        fileHandle?.write(Data(footer.utf8))
    }
}
