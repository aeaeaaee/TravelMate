import SwiftUI
import MapKit

// This view allows the user to plan a route with custom start and end points.
struct RoutePlannerView: View {
    
    // ViewModel to manage the state and logic for this view.
    @StateObject private var viewModel = RoutePlannerViewModel()
    
    // Binding to control the visibility of this sheet.
    @Binding var isShowing: Bool
    
    //<--START-->
    // The callback now correctly expects two MKMapItem arguments.
    var onGetDirections: (MKMapItem, MKMapItem) -> Void
    //<--END-->
    
    // The user's current location, passed in from the main view.
    var userLocation: CLLocation?

    // An enum to define the focusable fields.
    private enum Field: Hashable {
        case from, to
    }
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
                                    Button(action: { viewModel.useCurrentLocation(location: userLocation) }) {
                                        Image(systemName: "location.circle.fill")
                                    }.disabled(userLocation == nil)
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
                .padding()

                // The 3-row box for quick search results.
                VStack(spacing: 0) {
                    Text("Top Results").font(.headline).padding(.top)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(UIColor.systemGray4))
                        .padding(.vertical, 4)
                    
                    let results = (focusedField == .from) ? viewModel.fromSearchService.searchResults : viewModel.toSearchService.searchResults
                    
                    if results.isEmpty {
                        Spacer()
                        Text("Start typing to see suggestions.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Spacer()
                    } else {
                        List {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                Button(action: { viewModel.handleResultSelection(result.completion, forFromField: focusedField == .from) }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(result.completion.title), \(result.completion.subtitle)")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(result.distance)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(index % 2 == 0 ? Color.clear : Color.black.opacity(0.05))
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(width: 350, height: 300)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 5, y: 3)
                .padding(.horizontal)
            }
            
            Spacer()
            
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
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            viewModel.fromSearchService.currentLocation = userLocation
            viewModel.toSearchService.currentLocation = userLocation
            focusedField = .from
        }
    }
}

#Preview {
    ContentView()
}
