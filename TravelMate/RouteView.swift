import SwiftUI
import MapKit

// This is now the main view for the "Route" tab.
struct RouteView: View {
    
    // ViewModel to manage the state and logic for this view.
    @StateObject private var viewModel = RouteViewModel()
    
    // This view now has its own location manager to be self-contained.
    @StateObject private var locationManager = LocationManager()
    
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
            Map(position: $position) {
                // Draw the calculated route if it exists.
                if let route = viewModel.route {
                    MapPolyline(route)
                        .stroke(.blue, lineWidth: 5)
                }
            }
            .ignoresSafeArea()
            
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
                    viewModel.getDirections()
                }) {
                    Text("Get Directions")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.fromItem == nil || viewModel.toItem == nil)
            }
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
        .onChange(of: viewModel.route) {
            if let route = viewModel.route {
                // Correctly access the boundingMapRect directly from the route object.
                let rect = route.boundingMapRect.insetBy(dx: -500, dy: -500)
                let region = MKCoordinateRegion(rect)
                withAnimation {
                    self.position = .region(region)
                }
            }
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
                                .foregroundColor(.primary)
                            Text(result.completion.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(result.distance)
                            .font(.caption)
                            .foregroundColor(.secondary)
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
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
}
