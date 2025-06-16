import SwiftUI
import MapKit

// This is now the main view for the "Route" tab.
struct RouteView: View {
    
    // ViewModel to manage the state and logic for this view.
    @StateObject private var viewModel = RouteViewModel()
    @EnvironmentObject private var locationManager: LocationManager

    // Closure to pass the selected locations back to the parent view.
    var onGetDirections: (MKMapItem, MKMapItem) -> Void
    
    // State for the map's camera position within this view.
    @State private var position: MapCameraPosition = .automatic

    // An enum to define the focusable fields.
    private enum Field: Hashable {
        case from, to
    }
    @FocusState private var focusedField: Field?

    var body: some View {
        // The main ZStack allows UI elements to be layered on top of the map.
        ZStack {
            // A dedicated map for the route planning view.
            Map(position: $position)
            // Route drawing is now handled by the main map view.
            // .ignoresSafeArea() // Removed to respect safe areas, especially for bottom nav bar
            
            //<--START-->
            // The main UI is now in a single VStack for a simpler, more reliable layout.
            VStack(spacing: 0) {
                // Title and input fields container.
                VStack(spacing: 10) {
                    Text("Search for a Route")
                        .font(.title2).bold()
                        .padding(.top)
                    Divider().padding(.vertical, 8)
                    
                    Grid(alignment: .leading, horizontalSpacing: 12) {
                        GridRow(alignment: .center) {
                            Text("From:")
                                .font(.headline)
                            
                            ZStack(alignment: .trailing) {
                                TextField("Search or use current location", text: $viewModel.fromText)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundColor(viewModel.selectedFromResult != nil ? .blue : .primary)
                                    .focused($focusedField, equals: .from)
                                
                                HStack {
                                    if !viewModel.fromText.isEmpty {
                                        Button(action: { viewModel.fromText = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Button(action: { viewModel.useCurrentLocation(location: locationManager.location) }) {
                                        Image(systemName: "location.circle.fill")
                                    }.disabled(locationManager.location == nil)
                                }
                                .padding(.trailing, 8)
                                .font(.title2)
                            }
                            .gridCellColumns(2)
                        }
                        
                        GridRow(alignment: .center) {
                            Text("To:")
                                .font(.headline)
                            
                            ZStack(alignment: .trailing) {
                                TextField("Search for a destination", text: $viewModel.toText)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundColor(viewModel.selectedToResult != nil ? .blue : .primary)
                                    .focused($focusedField, equals: .to)
                                
                                if !viewModel.toText.isEmpty {
                                    Button(action: { viewModel.toText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.title2)
                                    }
                                    .padding(.trailing, 8)
                                }
                            }
                            .gridCellColumns(2)
                        }
                    }
                }
                .padding(.horizontal)
                
                // --- Search Results Dropdown ---
                // This will now correctly show results for the active field.
                let results = (focusedField == .from) ? viewModel.fromSearchService.searchResults : viewModel.toSearchService.searchResults
                if !results.isEmpty {
                    searchResultsDropdown(for: results, isFromField: focusedField == .from)
                }
                
                Spacer()
                
                // "Get Directions" button
                Button(action: {
                    if let from = viewModel.fromItem, let to = viewModel.toItem {
                        onGetDirections(from, to)
                    }
                }) {
                    Text("Get Directions")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                // .padding(.bottom, 60) // Removed as main VStack will now have bottom padding
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.fromItem == nil || viewModel.toItem == nil)
            }
            .padding(.bottom, 40) // Added padding to lift entire content above nav bar
            .background(Color(UIColor.systemGroupedBackground))
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
            //<--END-->
        }
        .onAppear {
            viewModel.fromSearchService.currentLocation = locationManager.location
            viewModel.toSearchService.currentLocation = locationManager.location
            focusedField = .from
        }

        .onChange(of: locationManager.location) {
            viewModel.fromSearchService.currentLocation = locationManager.location
            viewModel.toSearchService.currentLocation = locationManager.location
        }
    }

    // A reusable helper view for the search result dropdowns.
    private func searchResultsDropdown(for results: [SearchResult], isFromField: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(results) { result in
                Button(action: { viewModel.handleResultSelection(result.completion, forFromField: isFromField) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.completion.title)
                                .font(.headline)
                                .foregroundColor(.primary) // Reverted to default
                            Text(result.completion.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary) // Reverted to default
                        }
                        Spacer()
                        Text(result.distance)
                            .font(.caption)
                            .foregroundColor(.secondary) // Reverted to default
                    }
                    .padding()
                }
                .buttonStyle(.plain)
                
                if result.id != results.last?.id {
                    Divider().padding(.leading)
                }
            }
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 5, y: 3)
        .padding(.all)
    }
}

#Preview {
    // Provide a dummy closure for the preview and a LocationManager instance.
    RouteView { _, _ in print("Get Directions tapped in preview") }
        .environmentObject(LocationManager())
}
