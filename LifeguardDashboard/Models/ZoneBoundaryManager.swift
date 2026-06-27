import Foundation
import Combine
import CoreLocation
import SwiftUI
import FirebaseAuth

// MARK: - Editable Zone Enum

enum EditableZone: String, CaseIterable, Identifiable {
    case beach = "Beach"
    case shallows = "Shallows"
    case deep = "Deep Water"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .beach: return .green
        case .shallows: return .yellow
        case .deep: return .red
        }
    }
    
    var fillColor: Color {
        switch self {
        case .beach: return .green.opacity(0.2)
        case .shallows: return .yellow.opacity(0.2)
        case .deep: return .red.opacity(0.2)
        }
    }
    
    var icon: String {
        switch self {
        case .beach: return "beach.umbrella.fill"
        case .shallows: return "water.waves"
        case .deep: return "water.waves.and.arrow.down"
        }
    }
    
    var firebaseKey: String {
        switch self {
        case .beach: return "beach"
        case .shallows: return "shallows"
        case .deep: return "deep"
        }
    }
    
    var operationalZone: OperationalZone {
        switch self {
        case .beach: return .beach
        case .shallows: return .shallows
        case .deep: return .deepWater
        }
    }
}

// MARK: - Zone Boundary Manager

@MainActor
class ZoneBoundaryManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isEditModeActive: Bool = false
    @Published var activeEditingZone: EditableZone = .beach
    
    @Published var beachVertices: [CLLocationCoordinate2D] = []
    @Published var shallowsVertices: [CLLocationCoordinate2D] = []
    @Published var deepVertices: [CLLocationCoordinate2D] = []
    
    @Published var hasCustomZones: Bool = false
    @Published var isSaving: Bool = false
    
    // MARK: - Vertex Management
    
    /// Adds a vertex to the currently active zone.
    func addVertex(_ coordinate: CLLocationCoordinate2D) {
        switch activeEditingZone {
        case .beach:
            beachVertices.append(coordinate)
        case .shallows:
            shallowsVertices.append(coordinate)
        case .deep:
            deepVertices.append(coordinate)
        }
    }
    
    /// Removes the last vertex from the currently active zone.
    func undoLastVertex() {
        switch activeEditingZone {
        case .beach:
            if !beachVertices.isEmpty { beachVertices.removeLast() }
        case .shallows:
            if !shallowsVertices.isEmpty { shallowsVertices.removeLast() }
        case .deep:
            if !deepVertices.isEmpty { deepVertices.removeLast() }
        }
    }
    
    /// Clears all vertices for the currently active zone.
    func clearActiveZone() {
        switch activeEditingZone {
        case .beach:
            beachVertices.removeAll()
        case .shallows:
            shallowsVertices.removeAll()
        case .deep:
            deepVertices.removeAll()
        }
    }
    
    /// Returns the vertex array for a given zone.
    func verticesFor(_ zone: EditableZone) -> [CLLocationCoordinate2D] {
        switch zone {
        case .beach: return beachVertices
        case .shallows: return shallowsVertices
        case .deep: return deepVertices
        }
    }
    
    /// Returns the vertex count for the currently active zone.
    var activeVertexCount: Int {
        verticesFor(activeEditingZone).count
    }
    
    // MARK: - Firebase Persistence
    
    /// Saves all 3 zone boundaries to Firebase under the current user's profile.
    func saveToFirebase() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ Cannot save custom zones: No authenticated user.")
            return
        }
        
        isSaving = true
        defer { isSaving = false }
        
        var zonesData: [String: [[Double]]] = [:]
        
        for zone in EditableZone.allCases {
            let vertices = verticesFor(zone)
            let coordArrays = vertices.map { [$0.latitude, $0.longitude] }
            zonesData[zone.firebaseKey] = coordArrays
        }
        
        do {
            try await FirebaseManager.shared.saveCustomZones(userId: uid, zones: zonesData)
            hasCustomZones = true
            isEditModeActive = false
            print("✅ Custom zone boundaries saved successfully.")
        } catch {
            print("❌ Failed to save custom zones: \(error.localizedDescription)")
        }
    }
    
    /// Loads custom zone boundaries from Firebase for the current user.
    func loadFromFirebase() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("ℹ️ No authenticated user – skipping custom zone load.")
            return
        }
        
        do {
            guard let zonesData = try await FirebaseManager.shared.loadCustomZones(userId: uid) else {
                print("ℹ️ No custom zones found in Firebase. Using default auto-generated zones.")
                hasCustomZones = false
                return
            }
            
            // Parse each zone's coordinate arrays
            for zone in EditableZone.allCases {
                if let coordArrays = zonesData[zone.firebaseKey] {
                    let coordinates = coordArrays.compactMap { arr -> CLLocationCoordinate2D? in
                        guard arr.count == 2 else { return nil }
                        return CLLocationCoordinate2D(latitude: arr[0], longitude: arr[1])
                    }
                    
                    switch zone {
                    case .beach: beachVertices = coordinates
                    case .shallows: shallowsVertices = coordinates
                    case .deep: deepVertices = coordinates
                    }
                }
            }
            
            // Only mark as having custom zones if at least one zone has ≥3 vertices
            let hasAnyPolygon = EditableZone.allCases.contains { verticesFor($0).count >= 3 }
            hasCustomZones = hasAnyPolygon
            
            if hasCustomZones {
                print("✅ Custom zones loaded from Firebase.")
            } else {
                print("ℹ️ Custom zone data found but insufficient vertices. Using defaults.")
            }
        } catch {
            print("❌ Failed to load custom zones: \(error.localizedDescription)")
            hasCustomZones = false
        }
    }
    
    // MARK: - Point-in-Polygon Zone Detection
    
    /// Determines which custom zone a coordinate falls into.
    /// Tests in priority order: Deep → Shallows → Beach → outOfBounds.
    func determineCustomZone(for coordinate: CLLocationCoordinate2D) -> OperationalZone {
        // Check deep water first (highest priority / most dangerous)
        if deepVertices.count >= 3 && containsPoint(coordinate, inPolygon: deepVertices) {
            return .deepWater
        }
        if shallowsVertices.count >= 3 && containsPoint(coordinate, inPolygon: shallowsVertices) {
            return .shallows
        }
        if beachVertices.count >= 3 && containsPoint(coordinate, inPolygon: beachVertices) {
            return .beach
        }
        return .outOfBounds
    }
    
    /// Ray-casting algorithm for point-in-polygon test.
    /// Returns true if the given point is inside the polygon defined by the vertex array.
    func containsPoint(_ point: CLLocationCoordinate2D, inPolygon polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }
        
        let x = point.longitude
        let y = point.latitude
        var inside = false
        
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude
            
            let intersects = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
            if intersects {
                inside.toggle()
            }
            j = i
        }
        
        return inside
    }
}
