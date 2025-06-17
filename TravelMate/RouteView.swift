import SwiftUI
import MapKit

// This is now the main view for the "Route" tab.
struct RouteView: View {
    
    // ViewModel to manage the state and logic for this view.
    @ObservedObject var viewModel: RouteViewModel
    @EnvironmentObject private var locationManager: LocationManager

    // Closure to be called when the user taps 'Get Directions'.
    var onGetDirections: () -> Void
    
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

                    // Picker for selecting the mode of transport.
                    Picker("Transport Type", selection: $viewModel.transportType) {
                        ForEach(TransportType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)

                    // Section to display calculated route options
                    if !viewModel.routes.isEmpty {
                        routeOptionsSection
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
                
                // "Get Directions" / "Show Selected Route" button
                Button(action: {
                    if viewModel.selectedRoute == nil {
                        // If no route is selected yet, calculate routes
                        viewModel.calculateRoutes { success in
                            if !success {
                                // Optionally, handle route calculation failure (e.g., show an alert)
                                print("Route calculation failed or no routes found.")
                            }
                            // The routeOptionsSection will appear if routes are found.
                        }
                    } else {
                        // If a route IS selected, trigger navigation to the map
                        onGetDirections()
                    }
                }) {
                    Text(viewModel.selectedRoute == nil ? "Get Directions" : "Show Selected Route on Map")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .buttonStyle(.borderedProminent)
                // Disable button if 'From' or 'To' is not set, OR if calculating routes (selectedRoute is nil) and already tried.
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

    // MARK: - Route Options View
    @ViewBuilder
    private var routeOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))

                if viewModel.routes.isEmpty {
                    Text("Route options will appear here.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(Array(viewModel.routes.enumerated()), id: \.offset) { index, route in
                            Button(action: { viewModel.selectedRoute = route }) {
                                HStack(alignment: .center) {
                                    // Icon part (or placeholder for alignment)
                                    Group {
                                        if index == 0 {
                                            Image(systemName: viewModel.transportType.systemImageName)
                                                .font(.title)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                    .frame(width: 30, height: 30, alignment: .center)
                                    .padding(.trailing, 12) // Widened space

                                    // Route Name on the left
                                    VStack(alignment: .leading) {
                                        let routeName = (viewModel.transportType == .car || viewModel.transportType == .walking) ? "Along \(route.name)" : route.name
                                        Text(routeName)
                                            .font(.body)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    // ETA and Distance on the right
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(viewModel.formattedTravelTime(time: route.expectedTravelTime))
                                            .font(.headline)
                                            .fontWeight(.bold)
                                        Text(String(format: "%.1f km", route.distance / 1000))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(minWidth: 70, alignment: .trailing)

                                    // Vertical Divider
                                    Divider()
                                        .frame(height: 30)
                                        .padding(.horizontal, 8)

                                    // Checkmark, now on the far right
                                    Group {
                                        if viewModel.selectedRoute == route {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.title2)
                                        } else {
                                            // Placeholder to prevent layout shifts
                                            Color.clear
                                        }
                                    }
                                    .frame(width: 28, height: 28)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle()) // Make the whole area tappable
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .background(.clear)
                }
            }
            .frame(minHeight: viewModel.routes.isEmpty ? 100 : 0)
            .animation(.default, value: viewModel.routes)
        }
        .padding(.top)
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
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 5, y: 3)
        .padding(.all)
    }
}

#Preview {
    // For the preview, we pass a dummy view model and an empty closure.
    RouteView(viewModel: RouteViewModel()) {
        print("Preview: Get Directions tapped.")
    }
    .environmentObject(LocationManager())
}
