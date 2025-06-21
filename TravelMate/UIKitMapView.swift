import SwiftUI
import MapKit
import CoreLocation

// MARK: - Custom Annotation Wrapping MKMapItem
final class CustomPointAnnotation: MKPointAnnotation {
    let mapItem: MKMapItem
    init(mapItem: MKMapItem) {
        self.mapItem = mapItem
        super.init()
        self.coordinate = mapItem.placemark.coordinate
        self.title = mapItem.name
    }
}

// MARK: - UIViewRepresentable Wrapper
struct UIKitMapView: UIViewRepresentable {
    // Data from SwiftUI side
    let annotations: [CustomPointAnnotation]
    let route: MKRoute?
    @Binding var position: MapCameraPosition
    let onSelect: (MKMapItem) -> Void
    let onRegionChange: (MKCoordinateRegion) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        mapView.pointOfInterestFilter = .includingAll // show all POIs
        mapView.showsTraffic = true
        if #available(iOS 17.0, *) {
            mapView.selectableMapFeatures = [.pointsOfInterest] // allow POI taps
        }
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        syncAnnotations(on: uiView)
        syncRoute(on: uiView)
        syncCamera(on: uiView)
    }

    // MARK: - Private helpers
    private func syncAnnotations(on mapView: MKMapView) {
        // Current custom annotations already on map
        let existing = mapView.annotations.compactMap { $0 as? CustomPointAnnotation }
        let existingSet = Set(existing.map { $0.mapItem })
        let newSet = Set(annotations.map { $0.mapItem })

        // Remove outdated
        let toRemove = existing.filter { !newSet.contains($0.mapItem) }
        mapView.removeAnnotations(toRemove)

        // Add new ones
        let toAddItems = annotations.filter { !existingSet.contains($0.mapItem) }
        mapView.addAnnotations(toAddItems)
    }

    private func syncRoute(on mapView: MKMapView) {
        // Remove any existing polylines
        mapView.overlays.forEach { overlay in
            if overlay is MKPolyline { mapView.removeOverlay(overlay) }
        }
        if let route {
            mapView.addOverlay(route.polyline)
        }
    }

    private func syncCamera(on mapView: MKMapView) {
        // Only drive the camera from SwiftUI -> UIKit (not the other way around)
        if let region = position.region {
            if mapView.region.center.distance(to: region.center) > 10 || abs(mapView.region.span.latitudeDelta - region.span.latitudeDelta) > 0.001 {
                mapView.setRegion(region, animated: true)
            }
        }
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: UIKitMapView
        init(_ parent: UIKitMapView) { self.parent = parent }

        // Provide views for our custom annotations so they are selectable
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Keep default system handling for user location & Apple POIs
            if annotation is MKUserLocation || !(annotation is CustomPointAnnotation) {
                return nil
            }
            let identifier = "customPin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.markerTintColor = .systemRed
            view.canShowCallout = false
            return view
        }

        // POI / Annotation selection
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation else { return }
            #if DEBUG
            print("DEBUG: didSelect annotation \(annotation.title ?? "") – custom: \(annotation is CustomPointAnnotation)")
            #endif
            // Center map on the tapped annotation while keeping current zoom span
            let currentSpan = mapView.region.span
            let newRegion = MKCoordinateRegion(center: annotation.coordinate, span: currentSpan)
            DispatchQueue.main.async {
                mapView.setRegion(newRegion, animated: true)

            }

            if let custom = annotation as? CustomPointAnnotation {
                parent.onSelect(custom.mapItem)
            } else {
                // Native POI – create a basic MKMapItem from coordinate & title
                let placemark = MKPlacemark(coordinate: annotation.coordinate)
                let item = MKMapItem(placemark: placemark)
                item.name = annotation.title ?? ""
                parent.onSelect(item)
            }
        }

        // Overlay renderer (for route polyline)
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange(mapView.region)
        }
    }
}

// MARK: - Utility
private extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: latitude, longitude: longitude)
        let loc2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return loc1.distance(from: loc2)
    }
}
