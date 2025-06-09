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

    // An enum to define the focusable fields. This is a more robust way to track state.
    private enum Field: Hashable {
        case from, to
    }
    // A state property that SwiftUI uses to track which field is currently focused.
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // The input fields container.
                VStack(spacing: 10) {
                    Grid(alignment: .leading, horizontalSpacing: 12) {
                        GridRow(alignment: .center) {
                            Text("From:")
                                .font(.headline)
                            
                            //<--START-->
                            ZStack(alignment: .trailing) {
                                TextField("Search or use current location", text: $viewModel.fromText)
                                    .textFieldStyle(.roundedBorder)
                                    // Binds this TextField's focus state to our state variable.
                                    .focused($focusedField, equals: .from)
                                
                                HStack {
                                    // The clear button appears only when there is text.
                                    if !viewModel.fromText.isEmpty {
                                        Button(action: { viewModel.fromText = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Button(action: { viewModel.useCurrentLocation(location: userLocation) }) {
                                        Image(systemName: "location.circle.fill")
                                    }.disabled(userLocation == nil)
                                }
                                .padding(.trailing, 8)
                                .font(.title2)
                            }
                            .gridCellColumns(2)
                            //<--END-->
                        }
                        
                        GridRow(alignment: .center) {
                            Text("To:")
                                .font(.headline)
                            
                            //<--START-->
                            ZStack(alignment: .trailing) {
                                TextField("Search for a destination", text: $viewModel.toText)
                                    .textFieldStyle(.roundedBorder)
                                    // Binds this TextField's focus state to our state variable.
                                    .focused($focusedField, equals: .to)
                                
                                // The clear button appears only when there is text.
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
                            //<--END-->
                        }
                    }
                }
                .padding()

                // The 3-row box for quick search results is now always visible.
                VStack(spacing: 0) {
                    Text("Top Results").font(.headline).padding(.top)
                    Rectangle()
                        .frame(height: 3.0)
                        .foregroundColor(Color(UIColor.black))
                        .padding(.top, 10.0)
                    
                    let results = (focusedField == .from) ? viewModel.fromSearchService.searchResults : viewModel.toSearchService.searchResults
                    
                    // Show a placeholder if there are no results, otherwise show the list.
                    if results.isEmpty {
                        Spacer()
                        Text("Start typing to see suggestions.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Spacer()
                    } else {
                        List {
                            // We use enumerated() to get the index of each result.
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                Button(action: { viewModel.handleResultSelection(result.completion, forFromField: focusedField == .from) }) {
                                    VStack(alignment: .leading) {
                                        Text(result.completion.title).font(.headline).foregroundColor(.primary)
                                        HStack {
                                            Text(result.completion.subtitle).font(.subheadline).foregroundColor(.secondary)
                                            Spacer()
                                            Text(result.distance).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                // Use the index to set an alternating background color.
                                .listRowBackground(index % 2 == 0 ? Color.clear : Color.black.opacity(0.05))
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(width: 350, height: 300) // Give the box a fixed height.
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 5, y: 3)
                .padding(.horizontal)
            }
            
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
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            // Pass the user's location to the search services when the view appears.
            viewModel.fromSearchService.currentLocation = userLocation
            viewModel.toSearchService.currentLocation = userLocation
            // Default focus to the "From" field when the view appears.
            focusedField = .from
        }
    }
}

#Preview {
    ContentView()
}
