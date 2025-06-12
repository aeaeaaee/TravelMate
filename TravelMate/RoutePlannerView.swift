import SwiftUI
import MapKit

// This view allows the user to plan a route with custom start and end points.
struct RoutePlannerView: View {
    
    // ViewModel to manage the state and logic for this view.
    @StateObject private var viewModel = RoutePlannerViewModel()
    
    // Binding to control the visibility of this sheet.
    @Binding var isShowing: Bool
    
    // The callback now correctly expects two MKMapItem arguments.
    var onGetDirections: (MKMapItem, MKMapItem) -> Void
    
    // The user's current location, passed in from the main view.
    var userLocation: CLLocation?

    // An enum to define the focusable fields.
    private enum Field: Hashable {
        case from, to
    }
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary)
                .frame(width: 40, height: 5)
                .padding(.vertical, 8)
            
            // Use a ZStack to allow the dropdown to overlay other content.
            ZStack(alignment: .top) {
                // This VStack holds the main content (input fields and button).
                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        Grid(alignment: .leading, horizontalSpacing: 12) {
                            GridRow(alignment: .center) {
                                Text("From:")
                                    .font(.headline)
                                
                                ZStack(alignment: .trailing) {
                                    TextField("Search or use current location", text: $viewModel.fromText)
                                        .textFieldStyle(.roundedBorder)
                                        .focused($focusedField, equals: .from)
                                        .foregroundColor(viewModel.isFromLocationSelected ? .blue : .primary)
                                    
                                    HStack(spacing: 12) {
                                        if !viewModel.fromText.isEmpty {
                                            Button(action: { viewModel.fromText = "" }) {
                                                Image(systemName: "xmark.circle.fill")
                                            }
                                        }
                                        Button(action: { viewModel.useCurrentLocation(location: userLocation) }) {
                                            Image(systemName: "location.circle.fill")
                                                .foregroundColor(userLocation == nil ? .gray : .accentColor)
                                        }
                                        .disabled(userLocation == nil)
                                    }
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    .padding(.trailing, 8)
                                }
                            }
                            
                            GridRow(alignment: .center) {
                                Text("To:")
                                    .font(.headline)
                                
                                ZStack(alignment: .trailing) {
                                    TextField("Search for a destination", text: $viewModel.toText)
                                        .textFieldStyle(.roundedBorder)
                                        .focused($focusedField, equals: .to)
                                        .foregroundColor(viewModel.isToLocationSelected ? .blue : .primary)

                                    if !viewModel.toText.isEmpty {
                                        Button(action: { viewModel.toText = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.trailing, 8)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    
                    Spacer() // Pushes the button to the bottom
                }
                .zIndex(0) // Ensure the main content is on the bottom layer.
                
                // --- Search Results Dropdown for "From" Field ---
                let fromResults = viewModel.fromSearchService.searchResults
                if focusedField == .from && !fromResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(fromResults) { result in
                            Button(action: { viewModel.handleResultSelection(result.completion, forFromField: true) }) {
                                resultRow(result: result)
                            }
                            .buttonStyle(.plain)
                            
                            if result.id != fromResults.last?.id {
                                Divider().padding(.leading)
                            }
                        }
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 5, y: 3)
                    .padding(.horizontal)
                    .offset(y: 65)
                    .zIndex(1)
                }
                
                // --- Search Results Dropdown for "To" Field ---
                let toResults = viewModel.toSearchService.searchResults
                if focusedField == .to && !toResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(toResults) { result in
                            Button(action: { viewModel.handleResultSelection(result.completion, forFromField: false) }) {
                                resultRow(result: result)
                            }
                            .buttonStyle(.plain)
                            
                            if result.id != toResults.last?.id {
                                Divider().padding(.leading)
                            }
                        }
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 5, y: 3)
                    .padding(.horizontal)
                    .offset(y: 110)
                    .zIndex(1)
                }
            }
            
            // "Get Directions" button
            VStack {
                Spacer()
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
        }
        .background(Color(UIColor.systemGroupedBackground))
        //<--START-->
        // Make the entire background area tappable.
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss the keyboard, which removes focus from the text field.
            focusedField = nil
        }
        //<--END-->
        .onAppear {
            viewModel.fromSearchService.currentLocation = userLocation
            viewModel.toSearchService.currentLocation = userLocation
            focusedField = .from
        }
    }
    
    // Helper view for a single search result row.
    private func resultRow(result: SearchResult) -> some View {
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
}

#Preview {
    ContentView()
}
