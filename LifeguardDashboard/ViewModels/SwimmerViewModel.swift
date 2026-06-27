  import Foundation
import Combine
import CoreLocation
import SwiftUI

struct TacticalZone: Identifiable {
    var id: String { name }
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    let fillColor: Color
    let strokeColor: Color
}

@MainActor
class SwimmerViewModel: ObservableObject {
    @Published var sortedSwimmers: [Swimmer] = []
    @Published var activeRedAlert: Bool = false
    @Published var activeYellowAlert: Bool = false
    @Published var stations: [LifeguardStation] = []
    @Published var selectedStation: LifeguardStation? = nil
    @Published var activeFilter: SwimmerFilterType? = nil
    @Published var mapFocusCoordinate: FocusCoordinate? = nil
    @Published var selectedSwimmerId: String? = nil
    
    // MARK: - Zone Boundary Manager
    @Published var zoneBoundaryManager = ZoneBoundaryManager()
    
    // MARK: - Simulation Mode
    @Published var isSimulationModeEnabled: Bool = false {
        didSet {
            if isSimulationModeEnabled {
                if mockSwimmers.isEmpty {
                    spawnMockSwimmers()
                }
                generateGhostAnnotations()
            } else {
                cleanupSimulation()
            }
            processSwimmers(self.rawSwimmers)
        }
    }
    @Published var mockSwimmers: [Swimmer] = []
    @Published var ghostSwimmers: [Swimmer] = []
    
    @Published var currentUser: UserProfile? = nil {
        didSet {
            generateGhostAnnotations()
            processSwimmers(self.rawSwimmers)
        }
    }
    
    let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()
    private var rawSwimmers: [Swimmer] = []
    
    private var lastGhostGenerationTime: Date = .distantPast
    private var ghostPositions: [String: CLLocationCoordinate2D] = [:]
    
    var tacticalZones: [TacticalZone] {
        guard let _ = currentUser else { return [] }
        
        // Use custom zones if the user has drawn and saved them
        if zoneBoundaryManager.hasCustomZones {
            return customTacticalZones
        }
        
        return defaultTacticalZones
    }
    
    /// Builds TacticalZone array from the user's custom polygon vertices.
    private var customTacticalZones: [TacticalZone] {
        var zones: [TacticalZone] = []
        
        let beachVerts = zoneBoundaryManager.beachVertices
        if beachVerts.count >= 3 {
            zones.append(TacticalZone(
                name: "Zone 1 (Beach)",
                coordinates: beachVerts,
                fillColor: Color.green.opacity(0.2),
                strokeColor: Color.green
            ))
        }
        
        let shallowsVerts = zoneBoundaryManager.shallowsVertices
        if shallowsVerts.count >= 3 {
            zones.append(TacticalZone(
                name: "Zone 2 (Shallows)",
                coordinates: shallowsVerts,
                fillColor: Color.yellow.opacity(0.2),
                strokeColor: Color.yellow
            ))
        }
        
        let deepVerts = zoneBoundaryManager.deepVertices
        if deepVerts.count >= 3 {
            zones.append(TacticalZone(
                name: "Zone 3 (Deep Water)",
                coordinates: deepVerts,
                fillColor: Color.red.opacity(0.2),
                strokeColor: Color.red
            ))
        }
        
        return zones
    }
    
    /// The original auto-generated tactical zone polygons based on arbour position.
    private var defaultTacticalZones: [TacticalZone] {
        guard let user = currentUser else { return [] }
        
        let latOffset = 0.0003
        let topLat = user.arbourLatitude + latOffset
        let bottomLat = user.arbourLatitude - latOffset
        
        // Base longitudes for zone boundaries
        let arbourLon = user.arbourLongitude
        let zone1Base = arbourLon - 0.0008  // Beach/Shallows (waterline)
        let zone2Base = arbourLon - 0.0013  // Shallows/Deep Water
        let zone3Base = arbourLon - 0.0020  // Deep Water outer
        
        // Coastline angle compensation:
        // At topLat (north), water reaches further east → boundaries shift east (+skew)
        // At bottomLat (south), more sand → boundaries shift west (-skew)
        let coastSkew = 0.0004
        
        // Compute skewed boundary longitudes for top and bottom rows
        let arbourTopLon  = arbourLon + coastSkew
        let arbourBotLon  = arbourLon - coastSkew
        let zone1TopLon   = zone1Base + coastSkew
        let zone1BotLon   = zone1Base - coastSkew
        let zone2TopLon   = zone2Base + coastSkew
        let zone2BotLon   = zone2Base - coastSkew
        let zone3TopLon   = zone3Base + coastSkew
        let zone3BotLon   = zone3Base - coastSkew
        
        return [
            TacticalZone(
                name: "Zone 1 (Beach)",
                coordinates: [
                    CLLocationCoordinate2D(latitude: topLat, longitude: arbourTopLon),
                    CLLocationCoordinate2D(latitude: bottomLat, longitude: arbourBotLon),
                    CLLocationCoordinate2D(latitude: bottomLat, longitude: zone1BotLon),
                    CLLocationCoordinate2D(latitude: topLat, longitude: zone1TopLon)
                ],
                fillColor: Color.green.opacity(0.2),
                strokeColor: Color.green
            ),
            TacticalZone(
                name: "Zone 2 (Shallows)",
                coordinates: [
                    CLLocationCoordinate2D(latitude: topLat, longitude: zone1TopLon),
                    CLLocationCoordinate2D(latitude: bottomLat, longitude: zone1BotLon),
                    CLLocationCoordinate2D(latitude: bottomLat, longitude: zone2BotLon),
                    CLLocationCoordinate2D(latitude: topLat, longitude: zone2TopLon)
                ],
                fillColor: Color.yellow.opacity(0.2),
                strokeColor: Color.yellow
            ),
            TacticalZone(
                name: "Zone 3 (Deep Water)",
                coordinates: [
                    CLLocationCoordinate2D(latitude: topLat, longitude: zone2TopLon),
                    CLLocationCoordinate2D(latitude: bottomLat, longitude: zone2BotLon),
                    CLLocationCoordinate2D(latitude: bottomLat, longitude: zone3BotLon),
                    CLLocationCoordinate2D(latitude: topLat, longitude: zone3TopLon)
                ],
                fillColor: Color.red.opacity(0.2),
                strokeColor: Color.red
            )
        ]
    }
    
    init() {
        
        FirebaseManager.shared.swimmersPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] swimmersDict in
                let arr = Array(swimmersDict.values)
                self?.rawSwimmers = arr
                self?.generateGhostAnnotations()
                self?.processSwimmers(arr)
            }
            .store(in: &cancellables)
            
        FirebaseManager.shared.stationsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stationsDict in
                self?.stations = Array(stationsDict.values).sorted(by: { $0.name < $1.name })
            }
            .store(in: &cancellables)
            
        // Forward locationManager updates to update views observing SwimmerViewModel
        locationManager.$lastLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        locationManager.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Re-process swimmers when custom zone boundaries change
        zoneBoundaryManager.$hasCustomZones
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.generateGhostAnnotations()
                self.processSwimmers(self.rawSwimmers)
            }
            .store(in: &cancellables)
        
        // Forward ALL ZoneBoundaryManager changes to trigger SwiftUI view updates
        // (needed because nested ObservableObjects don't auto-propagate to parent observers)
        zoneBoundaryManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func determineZone(for coordinate: CLLocationCoordinate2D) -> OperationalZone {
        // Use custom polygon-based detection when custom zones exist
        if zoneBoundaryManager.hasCustomZones {
            return zoneBoundaryManager.determineCustomZone(for: coordinate)
        }
        
        return determineZoneDefault(for: coordinate)
    }
    
    /// The original interpolation-based zone detection using auto-generated boundaries.
    private func determineZoneDefault(for coordinate: CLLocationCoordinate2D) -> OperationalZone {
        guard let user = currentUser else { return .outOfBounds }
        
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        let minLat = user.arbourLatitude - 0.0003
        let maxLat = user.arbourLatitude + 0.0003
        
        guard lat >= minLat && lat <= maxLat else {
            return .outOfBounds
        }
        
        // Interpolation factor: 0 at bottom, 1 at top
        let t = (lat - minLat) / (maxLat - minLat)
        
        // Base longitudes
        let arbourLon = user.arbourLongitude
        let zone1Base = arbourLon - 0.0008
        let zone2Base = arbourLon - 0.0013
        let zone3Base = arbourLon - 0.0020
        let coastSkew = 0.0004
        
        // Interpolate effective boundary longitudes at this latitude
        // At t=0 (bottom/south): baseLon - coastSkew
        // At t=1 (top/north):    baseLon + coastSkew
        let skewFactor = coastSkew * (2.0 * t - 1.0)
        let effectiveArbourLon = arbourLon + skewFactor
        let effectiveZone1Lon = zone1Base + skewFactor
        let effectiveZone2Lon = zone2Base + skewFactor
        let effectiveZone3Lon = zone3Base + skewFactor
        
        if lon >= effectiveZone1Lon && lon <= effectiveArbourLon {
            return .beach
        } else if lon >= effectiveZone2Lon && lon < effectiveZone1Lon {
            return .shallows
        } else if lon >= effectiveZone3Lon && lon < effectiveZone2Lon {
            return .deepWater
        } else {
            return .outOfBounds
        }
    }
    
    // MARK: - Custom Zone Loading
    
    /// Loads custom zone boundaries from Firebase for the current authenticated user.
    func loadCustomZones() {
        Task {
            await zoneBoundaryManager.loadFromFirebase()
        }
    }
    
    private func processSwimmers(_ swimmers: [Swimmer]) {
        var filteredSwimmers = swimmers
        
        // Only consider swimmers and map their calculated zone
        if let _ = currentUser {
            filteredSwimmers = swimmers.compactMap { swimmer in
                guard let coord = swimmer.coordinate else { return nil }
                let calculatedZone = self.determineZone(for: coord)
                var updatedSwimmer = swimmer
                updatedSwimmer.zone = calculatedZone
                return updatedSwimmer
            }
        }
        
        // Always include ghost annotations of real swimmers (shown twice on the map!)
        filteredSwimmers.append(contentsOf: ghostSwimmers)
        
        // Merge mock swimmers when simulation is active
        if isSimulationModeEnabled {
            filteredSwimmers.append(contentsOf: mockSwimmers)
        }
        
        self.sortedSwimmers = filteredSwimmers.sorted {
            let priority0 = priority(for: $0.flagStatus)
            let priority1 = priority(for: $1.flagStatus)
            
            if priority0 != priority1 {
                return priority0 < priority1
            }
            return $0.id < $1.id
        }
        
        let hasRedAlert = filteredSwimmers.contains { $0.flagStatus == .redFlag }
        let hasYellowAlert = filteredSwimmers.contains { $0.flagStatus == .yellowFlag }
        
        if hasRedAlert {
            if !self.activeRedAlert {
                self.activeRedAlert = true
                self.activeYellowAlert = false
                AudioService.shared.playRedAlarm()
            }
        } else if hasYellowAlert {
            self.activeRedAlert = false
            if !self.activeYellowAlert {
                self.activeYellowAlert = true
                AudioService.shared.playYellowAlarm()
            }
        } else {
            if self.activeRedAlert || self.activeYellowAlert {
                self.activeRedAlert = false
                self.activeYellowAlert = false
                AudioService.shared.stopAlarm()
            }
        }
    }
    
    private func priority(for status: SwimmerFlagStatus) -> Int {
        switch status {
        case .redFlag: return 0
        case .yellowFlag: return 1
        case .greenFlag: return 2
        case .outOfWater: return 3
        }
    }
    
    func silenceAlarm() {
        AudioService.shared.stopAlarm()
    }
    
    func resolveAlert(for swimmer: Swimmer, classification: String) {
        if swimmer.id.hasPrefix("SIM-") {
            if let index = mockSwimmers.firstIndex(where: { $0.id == swimmer.id }) {
                mockSwimmers[index].alertLevel = .none
                mockSwimmers[index].alertReason = nil
                processSwimmers(self.rawSwimmers)
            }
        } else if swimmer.id.hasPrefix("GHOST-") {
            let realId = String(swimmer.id.dropFirst("GHOST-".count))
            FirebaseManager.shared.resolveAlert(deviceId: realId, classification: classification)
        } else {
            FirebaseManager.shared.resolveAlert(deviceId: swimmer.id, classification: classification)
        }
    }
    
    func selectClosestStation() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
            return
        }
        
        // Ensure updating is started
        locationManager.startUpdating()
        
        guard let lastLoc = locationManager.lastLocation else { return }
        guard !stations.isEmpty else { return }
        
        if let closest = stations.min(by: { $0.distance(to: lastLoc) < $1.distance(to: lastLoc) }) {
            selectedStation = closest
        }
    }
    
    func isSwimmerMatchingFilter(_ swimmer: Swimmer) -> Bool {
        guard let filter = activeFilter else { return true }
        switch filter {
        case .beach:
            return swimmer.zone == .beach
        case .shallows:
            return swimmer.zone == .shallows
        case .deepWater:
            return swimmer.zone == .deepWater
        }
    }
    
    // MARK: - Simulation Mode Engine
    
    /// Generates a random CLLocationCoordinate2D strictly inside the Shallows or Deep Water zones.
    func randomCoordinateInTacticalZones() -> CLLocationCoordinate2D {
        guard let user = currentUser else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        let latOffset = 0.0003
        let minLat = user.arbourLatitude - latOffset
        let maxLat = user.arbourLatitude + latOffset
        
        let arbourLon = user.arbourLongitude
        let zone1Base = arbourLon - 0.0008
        let zone3Base = arbourLon - 0.0020
        let coastSkew = 0.0004
        
        // Random latitude first
        let randomLat = Double.random(in: minLat...maxLat)
        
        // Compute skewed boundary at this latitude
        let t = (randomLat - minLat) / (maxLat - minLat)
        let skewFactor = coastSkew * (2.0 * t - 1.0)
        let effectiveZone1Lon = zone1Base + skewFactor
        let effectiveZone3Lon = zone3Base + skewFactor
        
        // Random longitude within Shallows + Deep Water at this latitude
        let randomLon = Double.random(in: effectiveZone3Lon...effectiveZone1Lon)
        
        return CLLocationCoordinate2D(latitude: randomLat, longitude: randomLon)
    }
    
    /// Spawns mock swimmers with specific alert levels.
    func spawnMockSwimmers(withAlertLevels alertLevels: [AlertLevel]) {
        guard currentUser != nil else { return }
        
        var mocks: [Swimmer] = []
        for (index, level) in alertLevels.enumerated() {
            let id = "SIM-\(index + 1)"
            let coord = randomCoordinateInTacticalZones()
            var swimmer = Swimmer(id: id)
            swimmer.heartRate = Int.random(in: 100...120)
            swimmer.spo2 = Int.random(in: 96...99)
            swimmer.depthMeters = Double.random(in: 0.3...2.5)
            swimmer.isSubmerged = true
            swimmer.coordinate = coord
            swimmer.zone = determineZone(for: coord)
            swimmer.alertLevel = level
            
            // Adjust metrics to fit the alert severity
            switch level {
            case .none:
                break // Already healthy
            case .yellow:
                swimmer.heartRate = Int.random(in: 125...140)
                swimmer.spo2 = Int.random(in: 90...94)
                swimmer.alertReason = "Simulated: Elevated HR / Low SpO2"
            case .red:
                swimmer.heartRate = Int.random(in: 30...45)
                swimmer.spo2 = Int.random(in: 78...86)
                swimmer.depthMeters = Double.random(in: 3.0...5.0)
                swimmer.alertReason = "Simulated: Critical vitals"
            }
            mocks.append(swimmer)
        }
        self.mockSwimmers = mocks
    }
    
    /// Spawns 4 mock swimmers with healthy vitals at random positions inside the tactical zones.
    func spawnMockSwimmers() {
        spawnMockSwimmers(withAlertLevels: [.none, .none, .none, .none])
    }
    
    /// Helper to generate a random coordinate inside the default Yellow/Red tactical zones.
    private func randomCoordinateInDefaultYellowOrRed() -> CLLocationCoordinate2D {
        guard let user = currentUser else { return CLLocationCoordinate2D(latitude: 0, longitude: 0) }
        let latOffset = 0.0003
        let minLat = user.arbourLatitude - latOffset
        let maxLat = user.arbourLatitude + latOffset
        
        let arbourLon = user.arbourLongitude
        let zone1Base = arbourLon - 0.0008
        let zone3Base = arbourLon - 0.0020
        let coastSkew = 0.0004
        
        let randomLat = Double.random(in: minLat...maxLat)
        let t = (randomLat - minLat) / (maxLat - minLat)
        let skewFactor = coastSkew * (2.0 * t - 1.0)
        let effectiveZone1Lon = zone1Base + skewFactor
        let effectiveZone3Lon = zone3Base + skewFactor
        
        let randomLon = Double.random(in: effectiveZone3Lon...effectiveZone1Lon)
        return CLLocationCoordinate2D(latitude: randomLat, longitude: randomLon)
    }
    
    /// Helper to generate a random coordinate inside the custom Yellow/Red tactical zones.
    private func randomCoordinateInCustomYellowOrRed() -> CLLocationCoordinate2D {
        var availablePolygons: [[CLLocationCoordinate2D]] = []
        if zoneBoundaryManager.shallowsVertices.count >= 3 {
            availablePolygons.append(zoneBoundaryManager.shallowsVertices)
        }
        if zoneBoundaryManager.deepVertices.count >= 3 {
            availablePolygons.append(zoneBoundaryManager.deepVertices)
        }
        
        guard !availablePolygons.isEmpty else {
            return randomCoordinateInDefaultYellowOrRed()
        }
        
        let vertices = availablePolygons.randomElement()!
        
        let lats = vertices.map { $0.latitude }
        let lons = vertices.map { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return randomCoordinateInDefaultYellowOrRed()
        }
        
        for _ in 0..<100 {
            let candidate = CLLocationCoordinate2D(
                latitude: Double.random(in: minLat...maxLat),
                longitude: Double.random(in: minLon...maxLon)
            )
            if zoneBoundaryManager.containsPoint(candidate, inPolygon: vertices) {
                return candidate
            }
        }
        
        return vertices.randomElement() ?? randomCoordinateInDefaultYellowOrRed()
    }

    /// Generates ghost annotations for any currently connected real Firebase devices.
    func generateGhostAnnotations() {
        guard currentUser != nil else { return }
        
        let now = Date()
        let shouldRegenerate = now.timeIntervalSince(lastGhostGenerationTime) >= 30.0
        
        if shouldRegenerate {
            lastGhostGenerationTime = now
        }
        
        self.ghostSwimmers = rawSwimmers.compactMap { realSwimmer in
            guard realSwimmer.coordinate != nil else { return nil }
            
            let ghostId = "GHOST-\(realSwimmer.id)"
            
            // Get or generate coordinate strictly in Yellow or Red zones
            let ghostCoord: CLLocationCoordinate2D
            if shouldRegenerate || ghostPositions[ghostId] == nil {
                let newCoord = zoneBoundaryManager.hasCustomZones ? randomCoordinateInCustomYellowOrRed() : randomCoordinateInDefaultYellowOrRed()
                ghostPositions[ghostId] = newCoord
                ghostCoord = newCoord
            } else {
                ghostCoord = ghostPositions[ghostId]!
            }
            
            var ghost = Swimmer(id: ghostId)
            ghost.heartRate = realSwimmer.heartRate
            ghost.spo2 = realSwimmer.spo2
            ghost.depthMeters = realSwimmer.depthMeters
            ghost.isSubmerged = realSwimmer.isSubmerged
            ghost.coordinate = ghostCoord
            ghost.zone = determineZone(for: ghostCoord)
            ghost.alertLevel = realSwimmer.alertLevel
            ghost.alertReason = realSwimmer.alertReason
            return ghost
        }
    }
    
    /// Triggers a Yellow Alert on a random healthy mock swimmer.
    func triggerSimulatedYellowAlert() {
        guard !mockSwimmers.isEmpty else { return }
        
        // Prefer a swimmer that is currently healthy (greenFlag)
        let healthyIndices = mockSwimmers.indices.filter { mockSwimmers[$0].alertLevel == .none }
        let targetIndex: Int
        if let idx = healthyIndices.randomElement() {
            targetIndex = idx
        } else {
            targetIndex = Int.random(in: 0..<mockSwimmers.count)
        }
        
        mockSwimmers[targetIndex].heartRate = Int.random(in: 125...140)
        mockSwimmers[targetIndex].spo2 = Int.random(in: 90...94)
        mockSwimmers[targetIndex].alertLevel = .yellow
        mockSwimmers[targetIndex].alertReason = "Simulated: Elevated HR / Low SpO2"
        
        processSwimmers(self.rawSwimmers)
    }
    
    /// Triggers a Red Alert on a random healthy mock swimmer.
    func triggerSimulatedRedAlert() {
        guard !mockSwimmers.isEmpty else { return }
        
        // Prefer a swimmer that is currently healthy (greenFlag)
        let healthyIndices = mockSwimmers.indices.filter { mockSwimmers[$0].alertLevel == .none }
        let targetIndex: Int
        if let idx = healthyIndices.randomElement() {
            targetIndex = idx
        } else {
            targetIndex = Int.random(in: 0..<mockSwimmers.count)
        }
        
        mockSwimmers[targetIndex].heartRate = Int.random(in: 30...45)
        mockSwimmers[targetIndex].spo2 = Int.random(in: 78...86)
        mockSwimmers[targetIndex].depthMeters = Double.random(in: 3.0...5.0)
        mockSwimmers[targetIndex].alertLevel = .red
        mockSwimmers[targetIndex].alertReason = "Simulated: Critical vitals"
        
        processSwimmers(self.rawSwimmers)
    }
    
    /// Removes all mock swimmers, ghost annotations, and resets alert state.
    /// Removes all mock swimmers, resets alert state, and keeps ghost annotations for active real watches.
    func cleanupSimulation() {
        mockSwimmers.removeAll()
        generateGhostAnnotations()
        AudioService.shared.stopAlarm()
    }
}

enum SwimmerFilterType: String {
    case beach
    case shallows
    case deepWater
}

struct FocusCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
    let id = UUID()
}
