import SwiftUI
import MapKit

// MARK: - MapSelection helpers




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
    let highlightItem: MKMapItem?
    // External selection binding (optional). If nil, an internal state is used.
    var selection: Binding<MapKit.MapSelection<MKMapItem>?>? = nil
    // Optional binding for built-in POI feature selection. If nil, we manage it internally.
    var featureSelection: Binding<MapFeature?>? = nil

    @Binding var position: MapCameraPosition

    var onSelectionChange: ((MapKit.MapSelection<MKMapItem>?) -> Void)? = nil
    // Callback for taps on native POI features
    var onFeatureTap: ((MapFeature) -> Void)? = nil

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
                         annotationItems: annotationItems,
                         overlayPolyline: overlayPolyline,
                         highlightItem: highlightItem,
                         externalSelection: selection,
                         onSelectionChange: onSelectionChange,
                         featureSelection: featureSelection,
                         onFeatureTap: onFeatureTap)
            
            .onMapCameraChange(frequency: .continuous) { context in
                onRegionChange(context.region)
            }

    }

    // MARK: ‑ Helpers

    /// The core map view, isolated to help the compiler.
    private struct MapViewContent: View {
        @Binding var position: MapCameraPosition
        let annotationItems: [AnnotationItem]
        let overlayPolyline: MKPolyline?
        let highlightItem: MKMapItem?
        // External selection binding (optional). If nil, use internal state.
        let externalSelection: Binding<MapKit.MapSelection<MKMapItem>?>?
        let onSelectionChange: ((MapKit.MapSelection<MKMapItem>?) -> Void)?
        let featureSelection: Binding<MapFeature?>?
        let onFeatureTap: ((MapFeature) -> Void)?

        @State private var internalSelection: MapKit.MapSelection<MKMapItem>?
        @State private var internalFeatureSelection: MapFeature?

        // Extracted annotation and overlay content for compiler clarity
        @MapContentBuilder
        private var annotationLayer: some MapContent {
            defaultContent
        }

        // Single marker wrapped to reduce generic depth
        private struct PinMarker: MapContent {
            let data: AnnotationItem
            let isSelected: Bool

            @MapContentBuilder
            var body: some MapContent {
                let iconName = POINameAndIcon.POIIconName(for: data.item.pointOfInterestCategory)
                let bg = POINameAndIcon.POIIconBackgroundColor(for: data.item.pointOfInterestCategory)
                Annotation(data.item.name ?? "", coordinate: data.coord) {
                    ZStack {
                        // Main bubble positioned slightly above the exact coordinate
                        Circle()
                            .fill(bg)
                            .frame(width: 46, height: 46)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.6), lineWidth: 1)
                            )
                            .overlay(
                                Image(systemName: iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(.white)
                            )
                            .offset(y: -30)

                        // Tiny anchor dot exactly at the coordinate
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.8), lineWidth: 1)
                            )
                    }
                }
                .tag(data.item)
            }
        }

        // Marker layer split for compiler performance
        @MapContentBuilder
        private var markersContent: some MapContent {
            ForEach(annotationItems) { data in
                PinMarker(data: data, isSelected: highlightItem?.identifier == data.id)
            }
        }

        // Wrap polyline overlay to further reduce generic complexity
        private struct RouteOverlay: MapContent {
            let polyline: MKPolyline
            var body: some MapContent {
                MapPolyline(polyline)
                    .stroke(.blue, lineWidth: 5)
            }
        }

        @MapContentBuilder
        private var overlayContent: some MapContent {
            if let polyline = overlayPolyline {
                RouteOverlay(polyline: polyline)
            }
        }

        @MapContentBuilder
        private var defaultContent: some MapContent {
            UserAnnotation()
            markersContent
            overlayContent
        }

        var body: some View {
            let content = defaultContent
            let selectionBinding = externalSelection ?? $internalSelection
            let featureBinding = featureSelection ?? $internalFeatureSelection
            let baseMap = Map(position: $position, selection: selectionBinding) {
                content
            }
            
            if let extSel = externalSelection {
                baseMap
                    .mapStyle(.standard)
                    .onChange(of: extSel.wrappedValue) { _, newSel in
                        onSelectionChange?(newSel)
                    }
                    // Propagate feature taps (always listen)
                    .onChange(of: featureBinding.wrappedValue) { _, newFeat in
                        if let feat = newFeat {
                            onFeatureTap?(feat)
                        }
                    }
            } else {
                baseMap
                    .mapStyle(.standard)
                    .onChange(of: internalSelection) { _, newSel in
                        onSelectionChange?(newSel)
                    }
                    .onChange(of: featureBinding.wrappedValue) { _, newFeat in
                        if let feat = newFeat {
                            onFeatureTap?(feat)
                        }
                    }
            }
        }

        private func categoryColor(for category: MKPointOfInterestCategory?) -> Color {
            POINameAndIcon.POIIconBackgroundColor(for: category)
        }

        private func iconName(for category: MKPointOfInterestCategory?) -> String {
            POINameAndIcon.POIIconName(for: category)
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
                highlightItem: nil,
                position: $position,
                onRegionChange: { _ in })
        }
    }

    static var previews: some View { Demo() }
}
#endif
