import SwiftUI

struct RouteView: View {
    var body: some View {
        // A placeholder for the new full-screen route planner.
        VStack {
            Image(systemName: "tram.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("Route Planner")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            Text("This view will replace the route planner pop-up.")
                .foregroundColor(.secondary)
        }
    }
}
