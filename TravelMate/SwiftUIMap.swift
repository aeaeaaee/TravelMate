import SwiftUI
import MapKit

/// SwiftUI-native replacement for `UIKitMapView`.
///
/// It mimics the same public API so that `MapView` can adopt it with minimal
/// changes.  Features implemented in this first phase:
///   • Shows an array of `MKMapItem` as `Marker`s (blue "from", red "to", grey others).
///   • Optional route / transit polyline overlay displayed via `MapPolyline`.
///   • Built-in POI selection using `Map`’s `selection` binding (Hashable).
///   • Propagates selection and region changes back to the parent via callbacks.
///   • Ignores user-location taps (they never change `selection`).
struct SwiftUIMap: View {
    // MARK: ‑ Public inputs
    let mapItems: [MKMapItem]
    let overlayPolyline: MKPolyline?

    @Binding var position: MapCameraPosition
    @Binding var selection: MapKit.MapSelection<MKMapItem>?

    // Closure equivalent of UIKitMapView’s delegate callback
    let onRegionChange: (MKCoordinateRegion) -> Void

    // Pre-filter items once to reduce work in Map's ViewBuilder
    /// Lightweight wrapper so each annotation is Identifiable and the `ForEach` stays trivial.
    private struct AnnotationItem: Identifiable {
        let id: MKMapItem.Identifier
        let item: MKMapItem
        let coord: CLLocationCoordinate2D
        let tint: Color
    }
    private var annotationItems: [AnnotationItem] {
        mapItems.compactMap { itm in
            guard let coord = itm.placemark.location?.coordinate,
                  let id = itm.identifier else { return nil }
            return AnnotationItem(id: id, item: itm, coord: coord, tint: pinTint(for: itm))
        }
    }

    // MARK: ‑ Body
    var body: some View {
        MapViewContent(position: $position,
                         selection: $selection,
                         annotationItems: annotationItems,
                         overlayPolyline: overlayPolyline)
            
            .onMapCameraChange { context in
                onRegionChange(context.region)
            }
    }

    // MARK: ‑ Helpers

    /// The core map view, isolated to help the compiler.
    private struct MapViewContent: View {
        @Binding var position: MapCameraPosition
        @Binding var selection: MapKit.MapSelection<MKMapItem>?
        let annotationItems: [AnnotationItem]
        let overlayPolyline: MKPolyline?

        var body: some View {
            let aMap = Map(position: $position, selection: $selection) {
                // Built-in annotation that shows the user’s current location (blue dot)
                UserAnnotation()
                
                ForEach(annotationItems) { data in
                    marker(for: data)
                }

                if let polyline = overlayPolyline {
                    MapPolyline(polyline)
                        .stroke(.blue, lineWidth: 5)
                }
            }

            aMap
                .mapStyle(.standard)
        }

        /// Helper function to build the marker, isolating it for the type-checker.
        private func marker(for data: AnnotationItem) -> some MapContent {
            Marker(data.item.name ?? "Location",
                   systemImage: iconName(for: data.item.pointOfInterestCategory),
                   coordinate: data.coord)
                .tint(data.tint)
                .tag(data.item)
                
        }

        private func iconName(for category: MKPointOfInterestCategory?) -> String {
            switch category {
            case .cafe: return "cup.and.saucer.fill"
            case .restaurant: return "fork.knife"
            case .hotel: return "bed.double.fill"
            case .bank: return "building.columns.fill"
            case .airport: return "airplane"
            case .publicTransport: return "bus.fill"
            default: return "mappin"
            }
        }
    }

    private func pinTint(for item: MKMapItem) -> Color {
        guard let first = mapItems.first, let last = mapItems.last else { return .red }
        if item.identifier == first.identifier { return .blue }    // "From"
        if item.identifier == last.identifier { return .red }      // "To"
        return .gray
    }
}

// MARK: ‑ Preview
#if DEBUG
struct SwiftUIMap_Previews: PreviewProvider {
    struct Demo: View {
        @State private var position: MapCameraPosition = .automatic
        @State private var selection: MapKit.MapSelection<MKMapItem>? = nil

        // Sample items for preview
        private var sampleItems: [MKMapItem] {
            let start = MKMapItem(placemark: .init(coordinate: .init(latitude: 22.317, longitude: 114.181)))
            start.name = "Olympic"
            let end = MKMapItem(placemark: .init(coordinate: .init(latitude: 22.336, longitude: 114.173)))
            end.name = "Kowloon"
            return [start, end]
        }

        var body: some View {
            SwiftUIMap(
                mapItems: sampleItems,
                overlayPolyline: nil,
                position: $position,
                selection: $selection,

                onRegionChange: { _ in }
            )
        }
    }

    static var previews: some View { Demo() }
}
#endif
