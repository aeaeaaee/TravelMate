import SwiftUI
import MapKit

// This view allows the user to plan a route with custom start and end points.
struct RoutePlannerView: View {
    
    // ViewModel to manage the state and logic for this view.
    @StateObject private var viewModel = RoutePlannerViewModel()
    
    // Binding to control the visibility of this sheet.
    @Binding var isShowing: Bool
    
    // A callback to pass the selected route back to the main content view.
    var onGetDirections: (MKMapItem, MKMapItem) -> Void
    
    // The user's current location, passed in from the main view.
    var userLocation: CLLocation?

    var body: some View {
        VStack(spacing: 0) {
            //<--START-->
            // Main container for all content. The Spacer at the end will push
            // the "Get Directions" button to the bottom.
            VStack(spacing: 10) {
                // The input fields container.
                VStack(spacing: 10) {
                    Grid(alignment: .leading, horizontalSpacing: 12) {
                        GridRow(alignment: .center) {
                            Text("From:")
                                .font(.headline)
                            
                            ZStack(alignment: .trailing) {
                                TextField("Search or use current location", text: $viewModel.fromText)
                                    .textFieldStyle(.roundedBorder)
                                    .onTapGesture { viewModel.isFromFieldActive = true }
                                
                                Button(action: { viewModel.useCurrentLocation(location: userLocation) }) {
                                    Image(systemName: "location.circle.fill").font(.title2)
                                }
                                .disabled(userLocation == nil)
                                .padding(.trailing, 8)
                            }
                            .gridCellColumns(2)
                        }
                        
                        GridRow(alignment: .center) {
                            Text("To:")
                                .font(.headline)
                            
                            TextField("Search for a destination", text: $viewModel.toText)
                                .textFieldStyle(.roundedBorder)
                                .onTapGesture { viewModel.isFromFieldActive = false }
                                .gridCellColumns(2)
                        }
                    }
                }
                .padding()

                // Display search results directly below the inputs.
                // This replaces the complex overlay logic with a much simpler layout.
                let results = viewModel.isFromFieldActive ? viewModel.fromSearchService.searchResults : viewModel.toSearchService.searchResults
                if !results.isEmpty {
                    List(results) { result in
                        Button(action: { viewModel.handleResultSelection(result.completion) }) {
                            VStack(alignment: .leading) {
                                Text(result.completion.title).font(.headline)
                                HStack {
                                    Text(result.completion.subtitle).font(.subheadline).foregroundColor(.secondary)
                                    Spacer()
                                    Text(result.distance).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 250) // Give the list a max height so it doesn't take over the screen.
                }
            }
            //<--END-->
            
            Spacer() // Pushes the button to the bottom
            
            // "Get Directions" button
            Button(action: {
                if let from = viewModel.fromItem, let to = viewModel.toItem {
                    onGetDirections(from, to)
                    isShowing = false
                }
            }) {
                Text("Get Directions")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.fromItem == nil || viewModel.toItem == nil)
        }
        // A semi-transparent background for the frosted glass effect.
        .background(.thinMaterial)
        .onAppear {
            // Pass the user's location to the search services when the view appears.
            viewModel.fromSearchService.currentLocation = userLocation
            viewModel.toSearchService.currentLocation = userLocation
        }
    }
}
